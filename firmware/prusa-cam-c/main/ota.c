// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: MPL-2.0

/* Over-the-air update, PUSH model: the board listens and the PC uploads.
 *
 * WHY PUSH RATHER THAN PULL. The usual OTA has the device fetch a binary from a
 * server. That needs a reachable HTTP server on the LAN, which a hardened network
 * may well not offer: host firewalls and per-container rules commonly block
 * arbitrary inbound ports. Opening a hole on somebody's host to serve a file is a
 * bigger change than the feature is worth.
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
#include "esp_camera.h"
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

    /* THE SHA IS THE ONLY HONEST FRESHNESS INDICATOR. "built" is not: the
     * app description's date and time come from compiling esp_app_desc.c, and
     * ccache happily reuses that object across rebuilds - measured here, three
     * successive OTA pushes of genuinely different binaries all reported the
     * same build timestamp. Anyone using it to confirm an update landed would
     * conclude the push had failed and reflash, or worse, conclude it had
     * succeeded when it had not.
     *
     * app_elf_sha256 changes whenever the ELF does, so it answers the one
     * question that matters for a board nobody can reach: is it running the
     * image I just pushed? Compare it against the local build with:
     *   xxd -s 176 -l 8 -p build/prusa_cam_c.bin */
    char sha[17] = {0};
    for (int i = 0; i < 8; i++) {
        sprintf(sha + i * 2, "%02x", app->app_elf_sha256[i]);
    }

    char body[256];
    int n = snprintf(body, sizeof(body),
                     "partition: %s\n" "version:   %s\n" "built:     %s %s\n"
                     "idf:       %s\n" "sha:       %s\n",
                     running->label, app->version, app->date, app->time,
                     app->idf_ver, sha);
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
    httpd_resp_set_hdr(req, "Connection", "close");
    httpd_resp_sendstr(req, "ok, rebooting\n");
    httpd_sess_trigger_close(req->handle, httpd_req_to_sockfd(req));

    /* Connection: close AND an explicit session close, because esp_restart()
     * tears the TCP stack down without sending a FIN - the client then gets an
     * RST and reports a FAILURE for an update that fully succeeded.
     *
     * That is the worst available way for this to be wrong. Measured here: the
     * board logged "update accepted" and rebooted into the new slot on every
     * attempt, while the uploader saw ConnectionResetError on every one. The
     * cost of believing the client is a needless retry, or unmounting a working
     * camera to reflash it over USB - exactly the situation OTA exists to
     * avoid. A 500 ms delay was not enough on its own: the close has to be
     * REQUESTED, not merely waited for. */
    vTaskDelay(pdMS_TO_TICKS(2000));
    esp_restart();
    return ESP_OK;
}


/* GET /raw - one frame, exactly as the sensor delivered it.
 *
 * A DIAGNOSTIC, not a feature. Two guesses at the colour cast have already been
 * wrong, so the next step is to stop guessing and look at the actual bytes: the
 * true pixel layout is decidable from the data itself, and a wrong guess costs
 * a flash cycle while this costs an HTTP request.
 *
 * Dimensions and format travel in headers so the receiver never has to assume
 * them - assuming geometry is how a layout bug gets misdiagnosed as a colour
 * bug in the first place. */
static esp_err_t raw_handler(httpd_req_t *req)
{
    camera_fb_t *fb = esp_camera_fb_get();
    if (!fb) {
        httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR, "capture failed");
        return ESP_FAIL;
    }

    /* THREE SEPARATE BUFFERS, and that is the whole point.
     *
     * httpd_resp_set_hdr stores the POINTER it is given, not a copy of the
     * string. A single reused buffer therefore leaves all three headers aiming
     * at the same bytes, and every one of them sends whatever was written LAST.
     * Measured on the bench: X-Width, X-Height and X-Format all arrived as "0",
     * because the last write was fb->format and RGB565 is format 0.
     *
     * That is a bad failure in this handler specifically. /raw exists so the
     * receiver never has to ASSUME the geometry - assuming geometry is how a
     * layout bug gets misdiagnosed as a colour bug, which is the mistake this
     * endpoint was added to stop. A diagnostic that quietly reports 0x0 is
     * worse than no diagnostic: the first client written against it built a
     * zero-by-zero image and only an assertion on the byte count caught it.
     *
     * The buffers must also outlive the send, so they cannot be scoped tighter
     * than the handler. */
    char v_w[16], v_h[16], v_f[16];
    snprintf(v_w, sizeof(v_w), "%u", (unsigned) fb->width);
    httpd_resp_set_hdr(req, "X-Width", v_w);
    snprintf(v_h, sizeof(v_h), "%u", (unsigned) fb->height);
    httpd_resp_set_hdr(req, "X-Height", v_h);
    snprintf(v_f, sizeof(v_f), "%d", (int) fb->format);
    httpd_resp_set_hdr(req, "X-Format", v_f);

    httpd_resp_set_type(req, "application/octet-stream");
    esp_err_t err = httpd_resp_send(req, (const char *) fb->buf, fb->len);
    esp_camera_fb_return(fb);
    return err;
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
    httpd_uri_t raw_uri = {
        .uri = "/raw", .method = HTTP_GET, .handler = raw_handler,
    };
    httpd_register_uri_handler(server, &raw_uri);
    httpd_register_uri_handler(server, &ota_uri);
    httpd_register_uri_handler(server, &status_uri);

    /* Marking the running image valid cancels the automatic rollback that the
     * bootloader would otherwise perform on the next reset. Reaching this point
     * means WiFi is up and the OTA endpoint is serving, which is a meaningful
     * definition of "this build works" - a build that cannot get here SHOULD be
     * rolled back. */
    /* Reported BEFORE the image is confirmed, because this line is the only
     * visible proof that the rollback net is actually armed. PENDING_VERIFY on
     * the first boot after a push means the bootloader is holding the previous
     * slot in reserve; UNDEFINED here would mean the safety net is off and a
     * bad-but-bootable image would strand the board. */
    const esp_partition_t *running = esp_ota_get_running_partition();
    esp_ota_img_states_t state;
    if (esp_ota_get_state_partition(running, &state) == ESP_OK) {
        ESP_LOGI(TAG, "image state on boot: %s",
                 state == ESP_OTA_IMG_PENDING_VERIFY ? "PENDING_VERIFY (rollback armed)"
                 : state == ESP_OTA_IMG_VALID        ? "VALID"
                 : state == ESP_OTA_IMG_UNDEFINED    ? "UNDEFINED - check CONFIG_BOOTLOADER_APP_ROLLBACK_ENABLE"
                                                     : "other");
    }

    esp_ota_mark_app_valid_cancel_rollback();

    ESP_LOGI(TAG, "OTA ready on port %d, running from %s", port, running->label);
    ESP_LOGI(TAG, "  push:   curl -X POST --data-binary @firmware.bin \\");
    ESP_LOGI(TAG, "            -H \"X-OTA-Key: <ota_password>\" http://<ip>:%d/ota", port);
    return ESP_OK;
}
