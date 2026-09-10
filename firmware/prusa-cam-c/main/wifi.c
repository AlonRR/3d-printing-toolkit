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
#include "esp_timer.h"
#include "nvs.h"
#include "nvs_flash.h"
#include "wifi_secrets.h"

static const char *TAG = "wifi";

#define BIT_GOT_IP   BIT0
#define BIT_FAILED   BIT1

static EventGroupHandle_t s_events;
static char s_ip[16] = "0.0.0.0";
static int s_retries = 0;
static esp_netif_t *s_netif = NULL;
static esp_timer_handle_t s_retry_timer = NULL;

/* Defined below, but called from the event handler above it. */
static void mdns_announce(void);
static volatile bool s_have_ip = false;
/* LIFETIME, PERSISTED IN NVS - and the persistence is the whole point.
 *
 * ⛔ This was per-boot until 9 Sep 2026, while being published with
 * state_class total_increasing. Those two cannot both be true, and the
 * contradiction was mine: total_increasing promises Home Assistant a monotonic
 * lifetime counter, so every reboot looked like a counter rollover. HA responds
 * to a decrease by treating it as a reset and ADDING the new value to the
 * running sum, which silently inflates the long-term total by disconnects that
 * never happened.
 *
 * Measured by the homelab session: the series ran 0 -> 15 -> 16 -> 17 -> 15,
 * and every one of those steps is explicable - the jumps are a genuine
 * reconnect storm (FAST_RETRIES is 8, so a burst increments this many times in
 * seconds) and the drop is a reboot. Nothing was wrong with the values; the
 * DECLARED SEMANTICS were wrong.
 *
 * It also made the counter unusable to its only consumer. Two separate attempts
 * were made to reconstruct a lifetime figure by summing across apparent resets,
 * and both produced numbers the data does not support - because a per-boot
 * series cannot be summed without knowing which decreases are reboots.
 *
 * Persisting it fixes the semantics rather than relabelling them. */
static unsigned s_disconnects = 0;
static int64_t s_last_save_us = 0;

#define NVS_NS       "wifinet"
#define NVS_KEY_DROP "drops"

static void drops_load(void)
{
    nvs_handle_t h;
    if (nvs_open(NVS_NS, NVS_READONLY, &h) != ESP_OK) {
        return;                     /* first boot: namespace does not exist yet */
    }
    uint32_t v = 0;
    if (nvs_get_u32(h, NVS_KEY_DROP, &v) == ESP_OK) {
        s_disconnects = v;
    }
    nvs_close(h);
}

/* Saved when the link is RESTORED, not on every disconnect. A burst of
 * disconnects is one outage episode, so this is one write per episode rather
 * than one per event - which matters because a pathological reconnect loop
 * would otherwise hammer the flash. */
static void drops_save(void)
{
    nvs_handle_t h;
    if (nvs_open(NVS_NS, NVS_READWRITE, &h) != ESP_OK) {
        return;
    }
    uint32_t cur = 0;
    if (nvs_get_u32(h, NVS_KEY_DROP, &cur) != ESP_OK || cur != s_disconnects) {
        if (nvs_set_u32(h, NVS_KEY_DROP, (uint32_t) s_disconnects) == ESP_OK) {
            nvs_commit(h);
        }
    }
    nvs_close(h);
    s_last_save_us = esp_timer_get_time();
}
static int64_t s_last_ip_us = 0;

/* Reconnecting from a TIMER rather than straight from the event handler, so a
 * backoff delay never blocks the event loop. */
static void retry_cb(void *arg)
{
    esp_wifi_connect();
}

/* ⛔ THIS NODE MUST NEVER STOP TRYING TO RECONNECT.
 *
 * The previous version gave up permanently after 8 consecutive disconnects: the
 * handler stopped calling esp_wifi_connect() and nothing else ever did, because
 * main() calls wifi_connect() exactly once at boot. The board kept running -
 * reading its sensor, capturing frames - with its radio idle and no way back
 * short of a power cycle.
 *
 * That is the single worst outcome for a board mounted inside a printer
 * enclosure, and it DEFEATS the mDNS and OTA work entirely: both need the node
 * on the network, so neither can recover a node that has left it. Recovery
 * meant physical access, which is exactly what all of it existed to avoid.
 *
 * It happened, 4 Sep 2026: the node dropped off the network in the chamber and
 * had to be power-cycled.
 *
 * The trigger was NOT signal, and this comment said it was until 10 Sep 2026.
 * Two later findings replaced it, and both are in docs/chamber-sensor.md:
 *
 *   - The multi-day outages were THIS BUG, not a weak link: the give-up left
 *     the radio idle until a human power-cycled it. Duration was the defect.
 *   - The disconnects themselves are a nightly event at 00:00 UTC in which the
 *     uplink re-associates this node. Routing is measurably perfect throughout,
 *     so it is the access point re-optimising, not a signal failure.
 *
 * The old sentence also blamed "band-steering", which is IMPOSSIBLE here: this
 * is an ESP32-S3, 802.11 b/g/n, 2.4 GHz only, with no 5 GHz PHY on the die. A
 * client that cannot receive 5 GHz cannot be steered onto it.
 *
 * And it set -26 dBm on the bench against -72 dBm in the enclosure, which reads
 * as a 46 dB penalty. -72 is real but it is the 0.07th percentile of 44,378
 * samples; the mean is -56, so mean-to-mean the penalty is nearer 30 dB.
 *
 * NONE OF THIS CHANGES THE DECISION BELOW. Retrying forever is right whether
 * the disconnect is a roam, a weak link or an AP reboot - only the stated
 * reason was wrong, and a stale reason in code outlives the docs that fix it.
 *
 * So: retry FOREVER. The counter now only chooses the backoff delay; it is
 * never a budget that can run out.
 */
#define FAST_RETRIES     8       /* immediate retries before backing off */
#define BACKOFF_MIN_MS   1000
#define BACKOFF_MAX_MS   30000

/* Last resort. Retrying forever fixes a lost AP, but not a supplicant wedged in
 * a state that no amount of esp_wifi_connect() escapes. A reboot does. Generous
 * enough that a router restart does not cause a reboot loop, short enough that
 * a wedged node is not lost for a whole print. */
#define REBOOT_AFTER_NO_IP_S  900

static void on_event(void *arg, esp_event_base_t base, int32_t id, void *data)
{
    if (base == WIFI_EVENT && id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED) {
        wifi_event_sta_disconnected_t *d = (wifi_event_sta_disconnected_t *) data;
        s_have_ip = false;
        s_retries++;
        s_disconnects++;

        /* The reason code is the single most useful thing in a failed join and
         * is usually thrown away. 15 = 4-way handshake timeout, 201 = AP not
         * found, 205 = connection failed. */
        if (s_retries <= FAST_RETRIES) {
            ESP_LOGW(TAG, "disconnected (reason %d), immediate retry %d",
                     d->reason, s_retries);
            esp_wifi_connect();
        } else {
            /* Backoff doubles from 1 s and is capped, so a genuinely absent AP
             * is retried about twice a minute forever rather than hammered. */
            int shift = s_retries - FAST_RETRIES - 1;
            if (shift > 5) shift = 5;
            int delay_ms = BACKOFF_MIN_MS << shift;
            if (delay_ms > BACKOFF_MAX_MS) delay_ms = BACKOFF_MAX_MS;

            int64_t down_s = (esp_timer_get_time() - s_last_ip_us) / 1000000;
            ESP_LOGW(TAG, "disconnected (reason %d), retry %d in %d ms "
                          "(no IP for %llds)",
                     d->reason, s_retries, delay_ms, (long long) down_s);

            /* The wedged-supplicant escape hatch. */
            if (down_s > REBOOT_AFTER_NO_IP_S) {
                ESP_LOGE(TAG, "no IP for %llds - rebooting to recover",
                         (long long) down_s);
                esp_restart();
            }
            esp_timer_stop(s_retry_timer);
            esp_timer_start_once(s_retry_timer, (uint64_t) delay_ms * 1000);
        }
    } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *e = (ip_event_got_ip_t *) data;
        snprintf(s_ip, sizeof(s_ip), IPSTR, IP2STR(&e->ip_info.ip));
        s_retries = 0;
        s_have_ip = true;
        s_last_ip_us = esp_timer_get_time();
        drops_save();   /* one write per outage episode, not per disconnect */
        mdns_announce();
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
 * subnet or a VLAN. It resolves today because the workstation and this board
 * sit on the same /24. Moving the IoT network behind a firewall onto its own
 * VLAN is a planned project, and that change would silently break name
 * resolution from the workstation. A DHCP reservation on the router is the
 * belt to this braces: it survives segmentation, a flash erase, and this
 * firmware being replaced entirely.
 */
static bool s_mdns_up = false;

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

    s_mdns_up = true;
    ESP_LOGI(TAG, "mDNS up: %s.local -> %s  (OTA and status on port 80)",
             WIFI_HOSTNAME, s_ip);
}

/* ⛔ RE-ANNOUNCE ON EVERY IP, not just the first - two fixes that each worked
 * alone and did not compose.
 *
 * The reconnect logic above deliberately never gives up, so the node now
 * survives a WiFi drop without rebooting. But start_mdns() used to be called
 * once, from wifi_connect(), on the FIRST successful association. After a
 * reconnect the node therefore held a new DHCP address while mDNS still
 * advertised - or had stopped advertising - the old one.
 *
 * The result was the worst shape available: a node that stays up, keeps
 * publishing, and quietly stops being reachable BY NAME. Measured 7 Sep 2026 -
 * the node was healthy at its DHCP address and publishing every few seconds while
 * prusa-cam.local failed to resolve, with prusalink.local resolving fine from the
 * same machine as a control. That defeats the entire point of giving it a name,
 * and it defeats OTA with it, since the push resolves by name.
 *
 * Announcing from the GOT_IP handler means every address the node ever holds is
 * published, including ones it acquires without a reboot. */
static void mdns_announce(void)
{
    if (!s_mdns_up) {
        start_mdns();
        return;
    }
    /* Re-setting the hostname is what triggers a fresh announcement. */
    esp_err_t err = mdns_hostname_set(WIFI_HOSTNAME);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "mDNS re-announce failed (%s) - reachable by IP only",
                 esp_err_to_name(err));
        return;
    }
    ESP_LOGI(TAG, "mDNS re-announced: %s.local -> %s", WIFI_HOSTNAME, s_ip);
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
    s_last_ip_us = esp_timer_get_time();
    drops_load();

    const esp_timer_create_args_t targs = {
        .callback = retry_cb, .name = "wifi_retry",
    };
    ESP_ERROR_CHECK(esp_timer_create(&targs, &s_retry_timer));

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
        /* mDNS is announced from the GOT_IP handler, which has already run
         * by this point and will run again on every later reconnect. */
        return ESP_OK;
    }
    /* Not terminal any more. The retry machinery above keeps running in the
     * background, so a node that misses this window still joins later and comes
     * back on its own - it simply starts without MQTT until it does. */
    ESP_LOGE(TAG, "no IP after %d ms - continuing, reconnection keeps running",
             timeout_ms);
    return ESP_FAIL;
}

bool wifi_is_connected(void)
{
    return s_have_ip;
}

unsigned wifi_uptime_s(void)
{
    return (unsigned) (esp_timer_get_time() / 1000000LL);
}

unsigned wifi_disconnect_count(void)
{
    return s_disconnects;
}

/* The BSSID is what separates a ROAM from a signal collapse: on a mesh, a
 * handoff shows as this value changing while RSSI stays healthy, whereas a weak
 * spot shows as RSSI falling with the BSSID unchanged. Without it the two are
 * indistinguishable in the history, which is exactly the question being asked of
 * the printer-area drops. */
const char *wifi_bssid_str(void)
{
    static char s_bssid[18] = "";
    wifi_ap_record_t ap;
    if (esp_wifi_sta_get_ap_info(&ap) == ESP_OK) {
        snprintf(s_bssid, sizeof(s_bssid), "%02x:%02x:%02x:%02x:%02x:%02x",
                 ap.bssid[0], ap.bssid[1], ap.bssid[2],
                 ap.bssid[3], ap.bssid[4], ap.bssid[5]);
    } else {
        s_bssid[0] = '\0';
    }
    return s_bssid;
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
