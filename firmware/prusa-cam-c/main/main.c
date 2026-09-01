/* Milestone 1: prove the hardware before building anything on it.
 *
 * WHY THIS SHAPE. The chamber-sensor work in this repo lost several days to a
 * network layer built on a radio that was never transmitting, and every symptom
 * pointed anywhere except the antenna. The lesson written down at the end of it
 * was to prove the physical layer first, with a check that can actually fail.
 * So this milestone has NO WiFi. It brings up the camera, reads the sensor PID,
 * reads the DHT, and logs both.
 *
 * The acceptance test is one line: PID 0x3660. That confirms the pin map in
 * board_pins.h, which was transcribed from Prusa's firmware for a board this
 * one merely resembles.
 *
 * Everything else - the Prusa Connect snapshot upload, and publishing the DHT
 * reading - goes on top of this once it passes, which is why camera.c and
 * dht11.c are separate from the start.
 */

#include <stdio.h>

#include "board_pins.h"
#include "camera.h"
#include "dht11.h"
#include "esp_log.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "main";

static void log_dht(void)
{
    dht_reading_t r;
    esp_err_t err = dht_read(&r);

    switch (err) {
    case ESP_OK:
        ESP_LOGI(TAG, "DHT %s: %.1f C  %.1f %%RH",
                 r.is_dht22 ? "22" : "11", r.temperature_c, r.humidity_pct);
        break;
    case ESP_ERR_TIMEOUT:
        /* The expected result until the sensor is physically moved: it is
         * currently wired to a different board entirely. Logged as a warning
         * with the pin named, so it reads as "not connected" rather than as a
         * driver failure. */
        ESP_LOGW(TAG, "DHT no response on GPIO%d - is it wired? "
                      "(- to GND, + to 3V3, S to GPIO%d)", DHT_PIN, DHT_PIN);
        break;
    case ESP_ERR_INVALID_CRC:
        /* Distinct from a timeout on purpose. A checksum failure means the
         * sensor IS there and talking, and the timing was disturbed - a very
         * different problem from no wire. */
        ESP_LOGW(TAG, "DHT checksum failed - wired and responding, frame corrupt");
        break;
    default:
        ESP_LOGW(TAG, "DHT read: %s", esp_err_to_name(err));
        break;
    }
}

void app_main(void)
{
    ESP_LOGI(TAG, "ESP32-S3 camera node - milestone 1, no network");
    ESP_LOGI(TAG, "free heap %u", (unsigned) esp_get_free_heap_size());

    dht_init(DHT_PIN);

    esp_err_t cam = camera_start();
    if (cam != ESP_OK) {
        /* Deliberately not a reboot loop. A board that reboots every few
         * seconds is far harder to diagnose over a serial console than one that
         * sits still and keeps reporting the DHT, which still proves the build
         * runs and the console is on the right USB port. */
        ESP_LOGE(TAG, "camera unavailable - continuing so the DHT half is "
                      "still testable");
    }

    unsigned n = 0;
    while (1) {
        if (cam == ESP_OK) {
            camera_capture_and_report();
        }
        log_dht();

        ESP_LOGI(TAG, "cycle %u  uptime %llu s  free heap %u",
                 n++, esp_timer_get_time() / 1000000ULL,
                 (unsigned) esp_get_free_heap_size());

        /* 3 s, above the DHT11's 2 s minimum sampling interval. Reading faster
         * returns the previous sample rather than fresh data. */
        vTaskDelay(pdMS_TO_TICKS(3000));
    }
}
