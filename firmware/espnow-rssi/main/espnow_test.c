// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: MPL-2.0

/* ESP-NOW RSSI test - firmware/espnow-c with per-packet RSSI added.
 *
 * Same symmetric design as espnow-c: one source, flashed to both boards, each
 * broadcasts a counter with jitter and logs everything it hears. The addition is
 * the receive RSSI from rx_ctrl, so every RX line is a signal-strength sample,
 * and the counter lets packet loss be computed from gaps.
 *
 * Built for two targets: the modded ESP32-C3 SuperMini and the Arduino Nano
 * ESP32 (esp32s3) as the reference radio. Both log to native USB-Serial/JTAG.
 */

#include <stdio.h>
#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "nvs_flash.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_mac.h"
#include "esp_netif.h"
#include "esp_now.h"
#include "esp_random.h"
#include "esp_wifi.h"
#include "driver/temperature_sensor.h"

static const char *TAG = "rssi";

#define ESPNOW_CHANNEL 1

#ifndef TX_QDBM
#define TX_QDBM 78
#endif

static const uint8_t BROADCAST[ESP_NOW_ETH_ALEN] = {
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
};

static temperature_sensor_handle_t tsens;

static void on_recv(const esp_now_recv_info_t *info, const uint8_t *data, int len)
{
    /* One parseable line per packet: RXR <rssi> <src> <payload> */
    ESP_LOGI(TAG, "RXR %d " MACSTR " %.*s",
             info->rx_ctrl->rssi, MAC2STR(info->src_addr), len, (const char *)data);
}

static void on_sent(const esp_now_send_info_t *tx_info, esp_now_send_status_t status)
{
    if (status != ESP_NOW_SEND_SUCCESS) {
        ESP_LOGW(TAG, "TX FAIL");
    }
}

void app_main(void)
{
    esp_err_t err = nvs_flash_init();
    if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        err = nvs_flash_init();
    }
    ESP_ERROR_CHECK(err);

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    ESP_ERROR_CHECK(esp_wifi_set_storage(WIFI_STORAGE_RAM));
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_ERROR_CHECK(esp_wifi_set_channel(ESPNOW_CHANNEL, WIFI_SECOND_CHAN_NONE));
    ESP_ERROR_CHECK(esp_wifi_set_ps(WIFI_PS_NONE));

    /* Pin TX power so both boards transmit at a known level, in 0.25 dBm units:
     * default 78 = 19.5 dBm, lowest accepted 8 = 2 dBm. Override per build with
     * -D TX_QDBM=<n>. The driver clamps to what the chip allows, so the value
     * actually in force is read back and logged. */
    ESP_ERROR_CHECK(esp_wifi_set_max_tx_power(TX_QDBM));
    int8_t txp = 0;
    ESP_ERROR_CHECK(esp_wifi_get_max_tx_power(&txp));

    uint8_t mac[ESP_NOW_ETH_ALEN];
    ESP_ERROR_CHECK(esp_wifi_get_mac(WIFI_IF_STA, mac));

    temperature_sensor_config_t tcfg = TEMPERATURE_SENSOR_CONFIG_DEFAULT(-10, 80);
    bool have_temp = temperature_sensor_install(&tcfg, &tsens) == ESP_OK &&
                     temperature_sensor_enable(tsens) == ESP_OK;

    ESP_LOGI(TAG, "BOOT own " MACSTR " channel %d txpower_quarter_dbm %d",
             MAC2STR(mac), ESPNOW_CHANNEL, txp);

    ESP_ERROR_CHECK(esp_now_init());
    ESP_ERROR_CHECK(esp_now_register_recv_cb(on_recv));
    ESP_ERROR_CHECK(esp_now_register_send_cb(on_sent));

    esp_now_peer_info_t peer = {0};
    memcpy(peer.peer_addr, BROADCAST, ESP_NOW_ETH_ALEN);
    peer.channel = ESPNOW_CHANNEL;
    peer.ifidx = WIFI_IF_STA;
    peer.encrypt = false;
    ESP_ERROR_CHECK(esp_now_add_peer(&peer));

    unsigned n = 0;
    while (1) {
        char buf[40];
        int len = snprintf(buf, sizeof(buf), "PING %u", n++);
        esp_err_t e = esp_now_send(BROADCAST, (const uint8_t *)buf, len);
        if (e != ESP_OK) {
            ESP_LOGE(TAG, "send queue failed: %s", esp_err_to_name(e));
        }
        /* Repeated, not only at boot: the boot line is gone before a host can
         * reopen the USB port after a reset, so the TX power in force would
         * otherwise never be seen. */
        if ((n % 10) == 0) {
            float c = 0;
            if (have_temp && temperature_sensor_get_celsius(tsens, &c) == ESP_OK) {
                ESP_LOGI(TAG, "TEMP %.1f txq %d sent %u", c, txp, n);
            } else {
                ESP_LOGI(TAG, "STAT txq %d sent %u", txp, n);
            }
        }
        /* Jitter so two boards never lock onto transmitting in the same slot.
         * Shorter than espnow-c's period so a run collects samples faster. */
        vTaskDelay(pdMS_TO_TICKS(300 + (esp_random() % 400)));
    }
}
