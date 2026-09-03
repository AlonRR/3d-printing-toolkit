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
#include "mdns.h"
#include "freertos/event_groups.h"
#include "nvs_flash.h"
#include "wifi_secrets.h"

static const char *TAG = "wifi";

#define BIT_GOT_IP   BIT0
#define BIT_FAILED   BIT1

static EventGroupHandle_t s_events;
static char s_ip[16] = "0.0.0.0";
static int s_retries = 0;
static esp_netif_t *s_netif = NULL;

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

/* mDNS - the reason this node has a NAME and not only an address.
 *
 * OTA here is a PUSH: the developer machine POSTs firmware to the board, so
 * something has to know where the board IS. Nothing else does. MQTT and the
 * Prusa Connect upload are both OUTBOUND, so they keep working perfectly from
 * any address and would never reveal that the lease had moved - the failure is
 * silent until the day an update is needed. The address is DHCP and it has
 * moved in practice, .120 to .127 between two checks on one day. Once the
 * board is cased and mounted on the printer there is no serial console left to
 * ask, so a moved lease would mean unscrewing it to recover.
 *
 * NOTHING HERE IS FATAL. A camera that works is worth more than a name that
 * resolves, so every failure below is logged and stepped over rather than
 * checked with ESP_ERROR_CHECK. An abort() on a printer-mounted node is the
 * one outcome worse than an unreachable one.
 *
 * LIMIT WORTH KNOWING: mDNS is link-local multicast and does NOT cross a
 * subnet or a VLAN. It resolves today because workstation (192.0.2.106) and this
 * board sit on the same /24. Moving the IoT network behind the the firewall onto
 * its own VLAN is a planned project, and that change would silently break name
 * resolution from the workstation. A DHCP reservation on the router is the
 * belt to this braces: it survives segmentation, a flash erase, and this
 * firmware being replaced entirely.
 */
static void start_mdns(void)
{
    esp_err_t err = mdns_init();
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "mDNS init failed (%s) - reachable by IP only",
                 esp_err_to_name(err));
        return;
    }

    err = mdns_hostname_set(WIFI_HOSTNAME);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "mDNS hostname: %s", esp_err_to_name(err));
        return;
    }
    mdns_instance_name_set("Prusa MK3S chamber camera");

    /* The OTA/status server is advertised as a SERVICE as well as a name, so
     * the node can be found by what it does when its name is not known. */
    mdns_txt_item_t txt[] = {
        {"board", "esp32-s3"},
        {"role", "prusa-cam"},
    };
    err = mdns_service_add(NULL, "_http", "_tcp", 80, txt,
                           sizeof(txt) / sizeof(txt[0]));
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "mDNS service: %s", esp_err_to_name(err));
    }

    ESP_LOGI(TAG, "mDNS up: %s.local -> %s  (OTA and status on port 80)",
             WIFI_HOSTNAME, s_ip);
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
    s_netif = esp_netif_create_default_wifi_sta();

    /* Set BEFORE the interface starts, because it is sent as DHCP option 12 in
     * the lease request itself - set it afterwards and the router has already
     * recorded an anonymous client. */
    ESP_ERROR_CHECK(esp_netif_set_hostname(s_netif, WIFI_HOSTNAME));

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
        start_mdns();
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
