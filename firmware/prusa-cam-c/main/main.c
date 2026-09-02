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
#include <stdlib.h>

#include "board_pins.h"
#include "camera.h"
#include "connect_cam.h"
#include "benchmark.h"
#include "dht11.h"
#include "mqtt.h"
#include "esp_log.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "wifi.h"

static const char *TAG = "main";

/* The board LISTENS here and the PC connects in. Chosen over a sink on the
 * server because the host firewall blocks arbitrary inbound ports and every
 * container firewalls are enabled - and opening one would be a change to a host for
 * the sake of a measurement. */
#define BENCH_PORT 8099

/* The benchmark is one-shot and blocks waiting for connections, so it must not
 * run in normal operation. Kept rather than deleted: it is the only way to
 * re-measure after a network change, and it took several iterations to get the
 * measurements honest. Set to 1 to run it. */
#define RUN_BENCHMARK 0

/* One snapshot per ~30 s at the 3 s loop interval. */
#define SNAPSHOT_EVERY_CYCLES 10

static void log_dht(void)
{
    dht_reading_t r;
    esp_err_t err = dht_read(&r);

    switch (err) {
    case ESP_OK:
        ESP_LOGI(TAG, "DHT %s: %.1f C  %.1f %%RH%s",
                 r.is_dht22 ? "22" : "11", r.temperature_c, r.humidity_pct,
                 mqtt_is_connected() ? "  -> mqtt" : "");
        /* Only a good reading is published. A failed read must leave the last
         * value alone rather than pushing a zero, which would show in HA as a
         * real measurement of 0 C. */
        mqtt_publish_reading(r.temperature_c, r.humidity_pct);
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

    /* THE BENCHMARK. Runs once, after the camera is up, then the node falls
     * back to the milestone-1 loop. Kept as a one-shot rather than a mode flag
     * because a benchmark that runs continuously would itself be the load. */
    bool net = (wifi_connect(30000) == ESP_OK);
    if (!net) {
        ESP_LOGE(TAG, "no WiFi - readings will be logged locally only");
    } else {
        mqtt_start();
        connect_cam_init();
    }

    if (RUN_BENCHMARK && cam == ESP_OK && net) {
        benchmark_run(BENCH_PORT);
    }

    unsigned n = 0;
    while (1) {
        if (cam == ESP_OK) {
            camera_capture_and_report();

            /* The deliverable: a real JPEG, produced without the sensor's
             * broken hardware encoder. This is the buffer the Prusa Connect
             * upload will POST once the network half exists. */
            uint8_t *jpg = NULL;
            size_t jpg_len = 0;
            if (camera_capture_jpeg(80, &jpg, &jpg_len) == ESP_OK) {
                ESP_LOGI(TAG, "JPEG %u bytes (software encoded, SOI ok)",
                         (unsigned) jpg_len);
                /* Uploaded on a slow cadence, not every cycle. Connect is for
                 * watching a print, not streaming, and the link here manages
                 * about 2 frames a second at best - hammering it would achieve
                 * nothing except keeping the radio busy. */
                if (net && (n % SNAPSHOT_EVERY_CYCLES) == 0) {
                    connect_cam_upload(jpg, jpg_len);
                }
                free(jpg);
            }
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
