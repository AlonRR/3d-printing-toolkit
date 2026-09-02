/* Station-mode WiFi, kept deliberately minimal - this exists to carry a
 * benchmark, not to be a resilient production supplicant.
 *
 * One line here decides whether the benchmark measures anything real:
 * esp_wifi_set_ps(WIFI_PS_NONE). With modem sleep active the radio dozes
 * between the AP's beacons, and a throughput test then measures the power
 * manager rather than the link. That is the same trap recorded in
 * espnow-c/main/espnow_test.c, where modem sleep silently prevented reception
 * entirely.
 */

#include "wifi.h"

#include <string.h>

#include "esp_event.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "nvs_flash.h"
#include "wifi_secrets.h"

static const char *TAG = "wifi";

#define BIT_GOT_IP   BIT0
#define BIT_FAILED   BIT1

static EventGroupHandle_t s_events;
static char s_ip[16] = "0.0.0.0";
static int s_retries = 0;

/* Retried rather than failed on first refusal. The IoT SSID here has a history
 * of rejecting a join attempt and accepting the next one. */
#define MAX_RETRIES 8

static void on_event(void *arg, esp_event_base_t base, int32_t id, void *data)
{
    if (base == WIFI_EVENT && id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED) {
        wifi_event_sta_disconnected_t *d = (wifi_event_sta_disconnected_t *) data;
        if (s_retries < MAX_RETRIES) {
            s_retries++;
            /* The reason code is the single most useful thing in a failed join
             * and is usually thrown away. 15 = 4-way handshake timeout,
             * 201 = AP not found, 205 = connection failed. */
            ESP_LOGW(TAG, "disconnected (reason %d), retry %d/%d",
                     d->reason, s_retries, MAX_RETRIES);
            esp_wifi_connect();
        } else {
            ESP_LOGE(TAG, "giving up after %d retries (reason %d)",
                     MAX_RETRIES, d->reason);
            xEventGroupSetBits(s_events, BIT_FAILED);
        }
    } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *e = (ip_event_got_ip_t *) data;
        snprintf(s_ip, sizeof(s_ip), IPSTR, IP2STR(&e->ip_info.ip));
        s_retries = 0;
        xEventGroupSetBits(s_events, BIT_GOT_IP);
    }
}

esp_err_t wifi_connect(int timeout_ms)
{
    esp_err_t err = nvs_flash_init();
    if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        err = nvs_flash_init();
    }
    ESP_ERROR_CHECK(err);

    s_events = xEventGroupCreate();

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    ESP_ERROR_CHECK(esp_event_handler_instance_register(
        WIFI_EVENT, ESP_EVENT_ANY_ID, &on_event, NULL, NULL));
    ESP_ERROR_CHECK(esp_event_handler_instance_register(
        IP_EVENT, IP_EVENT_STA_GOT_IP, &on_event, NULL, NULL));

    wifi_config_t wc = {0};
    strncpy((char *) wc.sta.ssid, WIFI_SSID, sizeof(wc.sta.ssid) - 1);
    strncpy((char *) wc.sta.password, WIFI_PASSWORD, sizeof(wc.sta.password) - 1);

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wc));
    ESP_ERROR_CHECK(esp_wifi_start());

    /* THE LINE THAT MATTERS FOR A THROUGHPUT TEST. Must come after
     * esp_wifi_start(), which is where the default power-save mode is applied. */
    ESP_ERROR_CHECK(esp_wifi_set_ps(WIFI_PS_NONE));

    ESP_LOGI(TAG, "joining \"%s\" ...", WIFI_SSID);

    EventBits_t bits = xEventGroupWaitBits(
        s_events, BIT_GOT_IP | BIT_FAILED, pdFALSE, pdFALSE,
        pdMS_TO_TICKS(timeout_ms));

    if (bits & BIT_GOT_IP) {
        ESP_LOGI(TAG, "connected, ip %s, rssi %d dBm", s_ip, wifi_rssi());
        return ESP_OK;
    }
    ESP_LOGE(TAG, "no IP after %d ms", timeout_ms);
    return ESP_FAIL;
}

const char *wifi_ip_str(void)
{
    return s_ip;
}

int wifi_rssi(void)
{
    wifi_ap_record_t ap;
    if (esp_wifi_sta_get_ap_info(&ap) == ESP_OK) {
        return ap.rssi;
    }
    return 0;
}
