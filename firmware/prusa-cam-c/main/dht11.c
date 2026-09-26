// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: MPL-2.0

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

    /* TELLING THE TWO PARTS APART, by PLAUSIBILITY rather than by zero bytes.
     *
     * An earlier version here decided "byte[1] or byte[3] nonzero means DHT22",
     * on the assumption that a DHT11 leaves its fractional bytes at zero. That
     * is false: modern DHT11s do send tenths. The real sensor on this bench
     * returned 67, 5, 29, 1 - a perfectly good 67.5 %RH and 29.1 C - and the
     * zero-byte rule read it as a DHT22 and reported 1715.7 %RH at 742.5 C.
     *
     * The checksum had passed, which is the important part: those absurd values
     * were a DECODING bug, not a wiring or timing fault. A valid checksum means
     * the 40 bits arrived intact and only their interpretation was wrong.
     *
     * So decode as a DHT22 and then ask whether the answer is physically
     * possible. The two encodings are far apart: at 67.5 %RH a real DHT22 sends
     * 675, so byte[0] is 2; a DHT11 sends 67 in byte[0]. Reading a DHT11 as a
     * DHT22 therefore always overshoots wildly and fails the range test, while
     * a genuine DHT22 always passes it. */
    float h22 = (float) ((bytes[0] << 8) | bytes[1]) * 0.1f;
    float t22 = (float) (((bytes[2] & 0x7F) << 8) | bytes[3]) * 0.1f;
    if (bytes[2] & 0x80) {
        t22 = -t22;
    }

    /* Datasheet ranges, generously bounded: DHT22 covers 0-100 %RH and
     * -40 to +80 C. Anything outside that is not a reading. */
    bool dht22 = (h22 >= 0.0f && h22 <= 100.0f && t22 >= -40.0f && t22 <= 80.0f);

    if (dht22) {
        out->humidity_pct = h22;
        out->temperature_c = t22;
    } else {
        /* DHT11: whole units in bytes 0 and 2, tenths in 1 and 3 on the parts
         * that send them. The guard keeps a garbage fractional byte from
         * corrupting an otherwise sound whole number. */
        out->humidity_pct = (float) bytes[0] + (bytes[1] < 10 ? bytes[1] * 0.1f : 0.0f);
        out->temperature_c = (float) bytes[2] + (bytes[3] < 10 ? bytes[3] * 0.1f : 0.0f);
    }
    out->is_dht22 = dht22;

    return ESP_OK;
}
