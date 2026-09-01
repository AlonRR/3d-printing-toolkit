/* Minimal ESP-NOW peer test, plain ESP-IDF.
 *
 * WHY THIS EXISTS. ESPHome 2026.8.1's espnow component would not pass a single
 * frame between two ESP32-C3 Super Minis 5 cm apart, with both ends reporting
 * healthy: same channel, same protocol version, peers registered, all three
 * receive triggers wired at DEBUG, and espnow.broadcast returning cleanly in
 * ~6 ms. Fourteen flash cycles produced no packet and no error. This strips
 * ESPHome out to find whether the radios themselves can talk.
 *
 * SYMMETRIC BY DESIGN: one binary, flashed to BOTH boards. Each broadcasts a
 * counter every two seconds and logs anything it receives. That halves the
 * build work and removes "which side is broken" from the question - if either
 * board hears the other, the link works.
 *
 * The thing ESPHome never gave us is the send callback. esp_now_send() returning
 * ESP_OK only means the frame was queued; the callback reports what the MAC
 * layer actually did with it. A link that fails silently looks completely
 * different from one that reports SEND_FAIL, and until now we could not tell
 * those apart.
 */

#include <stdio.h>
#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "nvs_flash.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_mac.h"   /* MACSTR / MAC2STR */
#include "esp_netif.h"
#include "esp_now.h"
#include "esp_random.h"
#include "esp_wifi.h"

static const char *TAG = "espnow_test";

/* Channel is pinned so both boards agree without any access point involved. */
#define ESPNOW_CHANNEL 1

static const uint8_t BROADCAST[ESP_NOW_ETH_ALEN] = {
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
};

static void on_recv(const esp_now_recv_info_t *info, const uint8_t *data, int len)
{
    ESP_LOGI(TAG, "RX %d bytes from " MACSTR " : %.*s",
             len, MAC2STR(info->src_addr), len, (const char *)data);
}

static void on_sent(const esp_now_send_info_t *tx_info, esp_now_send_status_t status)
{
    /* The diagnostic that was missing all along. SEND_FAIL here means the frame
     * left and nothing acknowledged it; SEND_SUCCESS on a broadcast means it was
     * transmitted. Either way it is evidence rather than inference. */
    ESP_LOGI(TAG, "TX to " MACSTR " : %s", MAC2STR(tx_info->des_addr),
             status == ESP_NOW_SEND_SUCCESS ? "SUCCESS" : "FAIL");
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
    /* esp_wifi_start() is what actually powers the radio. Not calling it - or
     * having it not called on your behalf - produces exactly the symptom this
     * test exists to investigate: everything reports ready, nothing is on air. */
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_ERROR_CHECK(esp_wifi_set_channel(ESPNOW_CHANNEL, WIFI_SECOND_CHAN_NONE));

    /* THE RECEIVE FIX. In STA mode the radio uses modem sleep, dozing between
     * an access point's beacons. With no AP associated there are no beacons to
     * sync to, so it is simply not listening when a frame arrives - which looks
     * exactly like this: both boards report TX SUCCESS every two seconds and
     * neither ever logs an RX.
     *
     * Note also that SUCCESS on a BROADCAST is weak evidence. Broadcasts are
     * unacknowledged, so the status only says the frame was transmitted, never
     * that anything heard it. */
    ESP_ERROR_CHECK(esp_wifi_set_ps(WIFI_PS_NONE));

    uint8_t mac[ESP_NOW_ETH_ALEN];
    ESP_ERROR_CHECK(esp_wifi_get_mac(WIFI_IF_STA, mac));

    uint8_t primary = 0;
    wifi_second_chan_t second = WIFI_SECOND_CHAN_NONE;
    ESP_ERROR_CHECK(esp_wifi_get_channel(&primary, &second));

    ESP_LOGI(TAG, "own MAC " MACSTR ", channel %d", MAC2STR(mac), primary);

    ESP_ERROR_CHECK(esp_now_init());
    ESP_ERROR_CHECK(esp_now_register_recv_cb(on_recv));
    ESP_ERROR_CHECK(esp_now_register_send_cb(on_sent));

    esp_now_peer_info_t peer = {0};
    memcpy(peer.peer_addr, BROADCAST, ESP_NOW_ETH_ALEN);
    peer.channel = ESPNOW_CHANNEL;
    peer.ifidx = WIFI_IF_STA;
    peer.encrypt = false;
    ESP_ERROR_CHECK(esp_now_add_peer(&peer));

    ESP_LOGI(TAG, "ready - broadcasting every 2s, listening always");

    unsigned n = 0;
    while (1) {
        char buf[40];
        int len = snprintf(buf, sizeof(buf), "PING %u from " MACSTR,
                           n++, MAC2STR(mac));
        esp_err_t e = esp_now_send(BROADCAST, (const uint8_t *)buf, len);
        if (e != ESP_OK) {
            ESP_LOGE(TAG, "esp_now_send queue failed: %s", esp_err_to_name(e));
        }
        /* JITTER, and it is not cosmetic. Both boards run this same binary and
         * were reset seconds apart, so a fixed 2000 ms period left them
         * transmitting on the same millisecond every single cycle - and a radio
         * cannot receive while it transmits. Each was therefore deaf at exactly
         * the moment the other spoke, forever. The logs made it obvious in
         * hindsight: identical uptimes on both boards, cycle after cycle.
         *
         * A symmetric test needs asymmetric timing. */
        vTaskDelay(pdMS_TO_TICKS(1200 + (esp_random() % 1600)));
    }
}
