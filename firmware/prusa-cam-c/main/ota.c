/* Over-the-air update, PUSH model: the board listens and the PC uploads.
 *
 * WHY PUSH RATHER THAN PULL. The usual OTA has the device fetch a binary from a
 * server. That needs a reachable HTTP server on the LAN, and this network does
 * not have one available: the host firewall blocks arbitrary inbound ports
 * and per-container firewalls are enabled, while the desktop has its own firewall on for
 * all profiles. Opening a hole on somebody's host to serve a file is a bigger
 * change than the feature is worth.
 *
 * Inverting it removes the problem entirely - the same reasoning that made the
 * throughput benchmark listen instead of connect. The board is the server, the
 * developer machine connects out, and nothing needs a firewall change.
 *
 * Two OTA slots are defined in partitions.csv, so a bad image can be rolled
 * back rather than bricking the node. The default single-app partition layout
 * has no ota partitions at all - OTA is impossible with it no matter how the
 * firmware is written, which is a silent trap.
 */

#include "ota.h"

#include <string.h>

#include "esp_app_desc.h"
#include "esp_http_server.h"
#include "esp_log.h"
#include "esp_ota_ops.h"
#include "esp_system.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "wifi_secrets.h"

static const char *TAG = "ota";

#define OTA_BUF_SIZE 4096

static esp_err_t status_handler(httpd_req_t *req)
{
    const esp_partition_t *running = esp_ota_get_running_partition();
    const esp_app_desc_t *app = esp_app_get_description();

    char body[256];
    int n = snprintf(body, sizeof(body),
                     "partition: %s\nversion:   %s\nbuilt:     %s %s\nidf:       %s\n",
                     running->label, app->version, app->date, app->time,
                     app->idf_ver);
    httpd_resp_set_type(req, "text/plain");
    return httpd_resp_send(req, body, n);
}

static esp_err_t ota_handler(httpd_req_t *req)
{
    /* A shared key, because this endpoint replaces the firmware. Without it,
     * anything on the IoT network could flash this board. It is not strong
     * authentication - the transport is plain HTTP on a LAN - but it prevents
     * an accidental or casual overwrite, which is the realistic risk here. */
    char key[64] = {0};
    if (httpd_req_get_hdr_value_str(req, "X-OTA-Key", key, sizeof(key)) != ESP_OK
        || strcmp(key, OTA_PASSWORD) != 0) {
        ESP_LOGW(TAG, "rejected an update with a missing or wrong X-OTA-Key");
        httpd_resp_send_err(req, HTTPD_401_UNAUTHORIZED, "bad or missing X-OTA-Key");
        return ESP_FAIL;
    }

    const esp_partition_t *target = esp_ota_get_next_update_partition(NULL);
    if (!target) {
        httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR,
                            "no OTA partition - check partitions.csv");
        return ESP_FAIL;
    }

    ESP_LOGI(TAG, "update starting: %d bytes into %s",
             req->content_len, target->label);

    esp_ota_handle_t handle = 0;
    esp_err_t err = esp_ota_begin(target, req->content_len, &handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "esp_ota_begin: %s", esp_err_to_name(err));
        httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR, "ota_begin failed");
        return ESP_FAIL;
    }

    char *buf = malloc(OTA_BUF_SIZE);
    if (!buf) {
        esp_ota_abort(handle);
        httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR, "out of memory");
        return ESP_FAIL;
    }

    int remaining = req->content_len;
    int written = 0;
    while (remaining > 0) {
        int n = httpd_req_recv(req, buf, remaining < OTA_BUF_SIZE ? remaining : OTA_BUF_SIZE);
        if (n == HTTPD_SOCK_ERR_TIMEOUT) {
            continue;
        }
        if (n <= 0) {
            ESP_LOGE(TAG, "receive failed after %d of %d bytes",
                     written, req->content_len);
            free(buf);
            /* Aborted rather than left dangling: an unfinished OTA handle keeps
             * the partition marked in-progress and blocks the next attempt. */
            esp_ota_abort(handle);
            httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR, "upload truncated");
            return ESP_FAIL;
        }
        err = esp_ota_write(handle, buf, n);
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "esp_ota_write: %s", esp_err_to_name(err));
            free(buf);
            esp_ota_abort(handle);
            httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR, "ota_write failed");
            return ESP_FAIL;
        }
        written += n;
        remaining -= n;
    }
    free(buf);

    /* esp_ota_end validates the image. A truncated or corrupt upload is caught
     * HERE, before anything is made bootable - which is the whole reason not to
     * set the boot partition first and hope. */
    err = esp_ota_end(handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "image rejected: %s", esp_err_to_name(err));
        httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "image failed validation");
        return ESP_FAIL;
    }

    err = esp_ota_set_boot_partition(target);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "set_boot_partition: %s", esp_err_to_name(err));
        httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR, "could not set boot");
        return ESP_FAIL;
    }

    ESP_LOGI(TAG, "update accepted (%d bytes) - rebooting into %s",
             written, target->label);
    httpd_resp_sendstr(req, "ok, rebooting\n");

    /* Delayed so the response actually reaches the client. Restarting inside
     * the handler drops the connection and the uploader sees a failure for an
     * update that succeeded. */
    vTaskDelay(pdMS_TO_TICKS(500));
    esp_restart();
    return ESP_OK;
}

esp_err_t ota_start(int port)
{
    httpd_config_t cfg = HTTPD_DEFAULT_CONFIG();
    cfg.server_port = port;
    cfg.lru_purge_enable = true;
    /* A 4 MB image over a link this slow takes a while; the default 5 s recv
     * timeout would abort a perfectly good upload mid-flight. */
    cfg.recv_wait_timeout = 30;
    cfg.send_wait_timeout = 30;

    httpd_handle_t server = NULL;
    esp_err_t err = httpd_start(&server, &cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "httpd_start: %s", esp_err_to_name(err));
        return err;
    }

    httpd_uri_t ota_uri = {
        .uri = "/ota", .method = HTTP_POST, .handler = ota_handler,
    };
    httpd_uri_t status_uri = {
        .uri = "/", .method = HTTP_GET, .handler = status_handler,
    };
    httpd_register_uri_handler(server, &ota_uri);
    httpd_register_uri_handler(server, &status_uri);

    /* Marking the running image valid cancels the automatic rollback that the
     * bootloader would otherwise perform on the next reset. Reaching this point
     * means WiFi is up and the OTA endpoint is serving, which is a meaningful
     * definition of "this build works" - a build that cannot get here SHOULD be
     * rolled back. */
    esp_ota_mark_app_valid_cancel_rollback();

    const esp_partition_t *running = esp_ota_get_running_partition();
    ESP_LOGI(TAG, "OTA ready on port %d, running from %s", port, running->label);
    ESP_LOGI(TAG, "  push:   curl -X POST --data-binary @firmware.bin \\");
    ESP_LOGI(TAG, "            -H \"X-OTA-Key: <ota_password>\" http://<ip>:%d/ota", port);
    return ESP_OK;
}
