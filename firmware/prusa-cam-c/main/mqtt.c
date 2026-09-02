/* Publishes the chamber reading to the broker, with Home Assistant discovery.
 *
 * WHY MQTT AND NOT THE ESPHOME/HA NATIVE API: Home Assistant already has the
 * mqtt integration configured against mqtt.internal.example - verified by reading its
 * config entries - so discovery messages create the entities with no clicking
 * in the HA interface at all.
 *
 * The topics and unique_ids deliberately MATCH scripts/chamber-serial-log.py,
 * which does the same job from the server end for the ESP-NOW hub. They are two
 * routes to the same entities, so exactly ONE of them may run at a time; two
 * publishers would fight over the same state topic and the entity would flicker
 * between two sources.
 */

#include "mqtt.h"

#include <stdio.h>
#include <string.h>

#include "esp_log.h"
#include "mqtt_client.h"
#include "wifi_secrets.h"

static const char *TAG = "mqtt";

#define TOPIC_STATE  "chamber/state"
#define TOPIC_AVAIL  "chamber/availability"

static esp_mqtt_client_handle_t s_client;
static volatile bool s_connected = false;

/* The device block ties both entities to one device in HA, so they appear
 * together rather than as two orphans. */
#define DEVICE_JSON \
    "\"device\":{\"identifiers\":[\"chamber_sensor\"]," \
    "\"name\":\"Print chamber\",\"manufacturer\":\"Espressif\"," \
    "\"model\":\"ESP32-S3-WROOM-1 camera node\"}"

static void publish_discovery(void)
{
    char payload[512];

    snprintf(payload, sizeof(payload),
             "{\"name\":\"Chamber temperature\",\"device_class\":\"temperature\","
             "\"unit_of_measurement\":\"\\u00b0C\",\"state_topic\":\"" TOPIC_STATE "\","
             "\"value_template\":\"{{ value_json.temp_c }}\","
             "\"availability_topic\":\"" TOPIC_AVAIL "\","
             "\"unique_id\":\"chamber_temp\"," DEVICE_JSON "}");
    /* Retained: HA must find these after a restart without the node having to
     * republish, and a sensor node may well be asleep or unplugged then. */
    esp_mqtt_client_publish(s_client,
        "homeassistant/sensor/chamber_temp/config", payload, 0, 1, 1);

    snprintf(payload, sizeof(payload),
             "{\"name\":\"Chamber humidity\",\"device_class\":\"humidity\","
             "\"unit_of_measurement\":\"%%\",\"state_topic\":\"" TOPIC_STATE "\","
             "\"value_template\":\"{{ value_json.rh_pct }}\","
             "\"availability_topic\":\"" TOPIC_AVAIL "\","
             "\"unique_id\":\"chamber_rh\"," DEVICE_JSON "}");
    esp_mqtt_client_publish(s_client,
        "homeassistant/sensor/chamber_rh/config", payload, 0, 1, 1);

    esp_mqtt_client_publish(s_client, TOPIC_AVAIL, "online", 0, 1, 1);
    ESP_LOGI(TAG, "discovery published; entities will appear in HA unaided");
}

static void on_event(void *arg, esp_event_base_t base, int32_t id, void *data)
{
    esp_mqtt_event_handle_t e = (esp_mqtt_event_handle_t) data;

    switch ((esp_mqtt_event_id_t) id) {
    case MQTT_EVENT_CONNECTED:
        s_connected = true;
        ESP_LOGI(TAG, "connected to " MQTT_HOST);
        /* Republished on every connect, not just the first. A broker that lost
         * its retained store - reinstalled, or started without persistence -
         * would otherwise leave HA with entities it can never populate. */
        publish_discovery();
        break;
    case MQTT_EVENT_DISCONNECTED:
        s_connected = false;
        ESP_LOGW(TAG, "disconnected; the client will retry on its own");
        break;
    case MQTT_EVENT_ERROR:
        /* Distinguishing a refused connection from a dropped one matters: the
         * first is credentials or topic permissions, the second is the network. */
        if (e->error_handle->error_type == MQTT_ERROR_TYPE_CONNECTION_REFUSED) {
            ESP_LOGE(TAG, "broker REFUSED the connection (return code %d) - "
                          "check the esp user's credentials and ACL",
                     e->error_handle->connect_return_code);
        } else {
            ESP_LOGW(TAG, "transport error");
        }
        break;
    default:
        break;
    }
}

esp_err_t mqtt_start(void)
{
    esp_mqtt_client_config_t cfg = {
        .broker.address.uri = "mqtt://" MQTT_HOST,
        .broker.address.port = MQTT_PORT,
        .credentials.username = MQTT_USERNAME,
        .credentials.authentication.password = MQTT_PASSWORD,
        .session.keepalive = 30,

        /* THE LAST WILL. Without it, a node that loses power leaves its last
         * reading on screen in HA indefinitely, looking current. For a sensor
         * whose entire purpose is answering "is the chamber hot", a stale value
         * that appears live is worse than a visible gap. Retained so the state
         * survives HA restarting. */
        .session.last_will = {
            .topic = TOPIC_AVAIL,
            .msg = "offline",
            .msg_len = 7,
            .qos = 1,
            .retain = 1,
        },
    };

    s_client = esp_mqtt_client_init(&cfg);
    if (!s_client) {
        ESP_LOGE(TAG, "client init failed");
        return ESP_FAIL;
    }

    ESP_ERROR_CHECK(esp_mqtt_client_register_event(
        s_client, ESP_EVENT_ANY_ID, on_event, NULL));
    ESP_ERROR_CHECK(esp_mqtt_client_start(s_client));

    ESP_LOGI(TAG, "connecting to " MQTT_HOST ":%d as " MQTT_USERNAME, MQTT_PORT);
    return ESP_OK;
}

bool mqtt_is_connected(void)
{
    return s_connected;
}

void mqtt_publish_reading(float temperature_c, float humidity_pct)
{
    if (!s_connected) {
        return;
    }

    char payload[96];
    snprintf(payload, sizeof(payload),
             "{\"temp_c\":%.1f,\"rh_pct\":%.1f}", temperature_c, humidity_pct);

    /* NOT retained, deliberately. A retained reading is replayed to HA on every
     * reconnect and shown as current, which is precisely the stale-value
     * problem the last will exists to prevent. Availability is retained; the
     * measurement is not. */
    esp_mqtt_client_publish(s_client, TOPIC_STATE, payload, 0, 0, 0);
}
