/* DHT11 / DHT22 single-wire protocol.
 *
 * THE TIMING, since every bug in this driver is a timing bug. The host pulls
 * the line low for at least 18 ms, releases it, and the sensor answers with an
 * 80 us low then an 80 us high. Forty bits follow. Every bit begins with a
 * ~50 us low; the length of the HIGH that follows is the data - roughly 27 us
 * means 0 and roughly 70 us means 1. So the decode is "measure the high, not
 * the low", and the threshold sits between them at 50 us.
 *
 * The read runs inside a critical section. Each bit is tens of microseconds and
 * a single preempting task destroys the frame, which surfaces as an occasional
 * checksum failure rather than an obvious fault. The whole exchange is under
 * 6 ms, which is an acceptable time to hold a core.
 */

#include "dht11.h"

#include <stdbool.h>
#include <string.h>

#include "driver/gpio.h"
#include "esp_log.h"
#include "esp_rom_sys.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "dht";

static int s_gpio = -1;
static int64_t s_last_read_us = 0;

/* Datasheet minimum is 1 s for the DHT22 and 2 s for the DHT11. Reading faster
 * does not return fresh data - it returns the previous sample or a corrupt
 * frame, which is worse than refusing. */
#define DHT_MIN_INTERVAL_US 2000000

static portMUX_TYPE s_mux = portMUX_INITIALIZER_UNLOCKED;

/* Waits for the pin to reach `level`, up to `timeout_us`. Returns how long the
 * wait took, or -1 on timeout. The elapsed time IS the measurement for data
 * bits, so this returns it rather than just succeeding. */
static int32_t wait_for_level(int level, int32_t timeout_us)
{
    int64_t start = esp_timer_get_time();
    while (gpio_get_level(s_gpio) != level) {
        if (esp_timer_get_time() - start > timeout_us) {
            return -1;
        }
    }
    return (int32_t) (esp_timer_get_time() - start);
}

void dht_init(int gpio)
{
    s_gpio = gpio;

    gpio_config_t cfg = {
        .pin_bit_mask = 1ULL << gpio,
        .mode = GPIO_MODE_INPUT_OUTPUT_OD,   /* open drain: the sensor also drives it */
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    ESP_ERROR_CHECK(gpio_config(&cfg));
    gpio_set_level(gpio, 1);

    /* The KY-015 carries its own pull-up resistor on the module, so the
     * internal one above is belt and braces rather than required. Enabling both
     * is harmless - they parallel to a slightly stiffer pull-up. */
    ESP_LOGI(TAG, "init on GPIO%d", gpio);

    /* The sensor needs a moment after power-up before it will answer. */
    vTaskDelay(pdMS_TO_TICKS(1100));
}

esp_err_t dht_read(dht_reading_t *out)
{
    if (s_gpio < 0) {
        return ESP_ERR_INVALID_STATE;
    }

    int64_t now = esp_timer_get_time();
    if (s_last_read_us != 0 && (now - s_last_read_us) < DHT_MIN_INTERVAL_US) {
        return ESP_ERR_INVALID_STATE;
    }
    s_last_read_us = now;

    uint8_t bytes[5] = {0};
    esp_err_t result = ESP_OK;

    /* START. Held outside the critical section: 20 ms with interrupts disabled
     * would trip the task watchdog, and the start pulse only has a minimum, so
     * being preempted here is harmless. */
    gpio_set_level(s_gpio, 0);
    esp_rom_delay_us(20000);
    gpio_set_level(s_gpio, 1);

    taskENTER_CRITICAL(&s_mux);
    do {
        /* The sensor takes the line low within ~40 us to acknowledge. */
        if (wait_for_level(0, 100) < 0) { result = ESP_ERR_TIMEOUT; break; }
        /* Its 80 us low, then its 80 us high. */
        if (wait_for_level(1, 120) < 0) { result = ESP_ERR_TIMEOUT; break; }
        if (wait_for_level(0, 120) < 0) { result = ESP_ERR_TIMEOUT; break; }

        for (int i = 0; i < 40; i++) {
            /* Each bit: a ~50 us low, then a high whose LENGTH is the value. */
            if (wait_for_level(1, 90) < 0)  { result = ESP_ERR_TIMEOUT; break; }
            int32_t high_us = wait_for_level(0, 120);
            if (high_us < 0) { result = ESP_ERR_TIMEOUT; break; }

            /* 27 us vs 70 us; 50 sits between them with margin on both sides. */
            bytes[i / 8] <<= 1;
            if (high_us > 50) {
                bytes[i / 8] |= 1;
            }
        }
    } while (0);
    taskEXIT_CRITICAL(&s_mux);

    if (result != ESP_OK) {
        return result;
    }

    if (((bytes[0] + bytes[1] + bytes[2] + bytes[3]) & 0xFF) != bytes[4]) {
        return ESP_ERR_INVALID_CRC;
    }

    /* TELLING THE TWO PARTS APART. Both send 5 bytes with the same checksum, but
     * they encode differently: the DHT11 puts whole units in bytes 0 and 2 and
     * leaves the fractional bytes at zero, while the DHT22 sends a 16-bit
     * tenths value spanning both bytes of each pair. So a nonzero byte[1] or
     * byte[3] means DHT22 - and a DHT11 reading 20 C / 40 %RH would otherwise
     * decode as 522.4 C if treated as a DHT22. */
    bool dht22 = (bytes[1] != 0) || (bytes[3] != 0);

    if (dht22) {
        out->humidity_pct = ((bytes[0] << 8) | bytes[1]) * 0.1f;
        int16_t raw = ((bytes[2] & 0x7F) << 8) | bytes[3];
        out->temperature_c = raw * 0.1f;
        if (bytes[2] & 0x80) {
            out->temperature_c = -out->temperature_c;
        }
    } else {
        out->humidity_pct = (float) bytes[0];
        out->temperature_c = (float) bytes[2];
    }
    out->is_dht22 = dht22;

    return ESP_OK;
}
