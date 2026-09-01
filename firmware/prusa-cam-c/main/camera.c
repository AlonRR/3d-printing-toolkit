/* OV3660 bring-up, with a self-diagnosing configuration sweep.
 *
 * WHAT THE FIRST RUN TAUGHT US. The sensor PID read back as 0x3660 and PSRAM
 * allocated two frame buffers, yet every capture failed with
 * "NO-SOI - JPEG start marker missing" followed by a frame timeout.
 *
 * That pair is precise, and it narrows the fault a long way:
 *
 *   - Reading the PID happens over SCCB, which is I2C. It proves SIOD, SIOC and
 *     XCLK, and NOTHING ELSE. In particular it does not touch the 8-bit
 *     parallel data bus, VSYNC, HREF or PCLK.
 *   - NO-SOI means the DMA engine did receive bytes, but they did not begin
 *     with 0xFFD8. So the sensor is alive and clocked, and the pixel path is
 *     either misread or running too fast.
 *
 * So rather than reflash once per guess, this sweeps candidate configurations
 * at boot and reports which one actually yields a frame. One flash, one answer.
 * The sweep is ordered by how likely each change is to matter: XCLK first,
 * because an over-fast pixel clock is the usual cause of NO-SOI, then buffer
 * strategy, then resolution.
 */

#include "camera.h"

#include "board_pins.h"
#include "esp_camera.h"
#include "esp_heap_caps.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "cam";

#define OV3660_PID 0x3660

typedef struct {
    int xclk_hz;
    pixformat_t format;
    framesize_t size;
    int fb_count;
    camera_grab_mode_t grab;
    camera_fb_location_t location;
    const char *label;
} cam_attempt_t;

/* SECOND SWEEP, after the first one ruled out clock speed.
 *
 * Halving XCLK took PCLK from 10 MHz to 5 MHz and changed nothing, which is
 * strong evidence the problem is not the DMA failing to keep up. And the pin
 * map is now corroborated twice over: Prusa's module_ESP32-S3-CAM.h carries
 * pins IDENTICAL to the Freenove header, and SCCB works on them here.
 *
 * So the question is no longer "how fast" but "what shape". The discriminating
 * test is a NON-JPEG format:
 *
 *   RGB565 frames arrive  -> the parallel bus, VSYNC, HREF and PCLK are all
 *                            fine, and the fault is in JPEG mode specifically.
 *   RGB565 also fails     -> the pixel path itself is wrong, and no amount of
 *                            JPEG tuning will help.
 *
 * Raw formats are put early and small: QQVGA RGB565 is 160x120x2 = 38 KB, which
 * fits in internal DRAM, so it also removes PSRAM from the question at the same
 * time. One JPEG attempt is kept first purely as a fast baseline. */
static const cam_attempt_t ATTEMPTS[] = {
    { 20000000, PIXFORMAT_JPEG,   FRAMESIZE_SVGA,  2, CAMERA_GRAB_WHEN_EMPTY,
      CAMERA_FB_IN_PSRAM, "JPEG   SVGA  20MHz fb2 psram" },
    { 20000000, PIXFORMAT_RGB565, FRAMESIZE_QQVGA, 1, CAMERA_GRAB_LATEST,
      CAMERA_FB_IN_DRAM,  "RGB565 QQVGA 20MHz fb1 DRAM " },
    { 10000000, PIXFORMAT_RGB565, FRAMESIZE_QQVGA, 1, CAMERA_GRAB_LATEST,
      CAMERA_FB_IN_DRAM,  "RGB565 QQVGA 10MHz fb1 DRAM " },
    { 20000000, PIXFORMAT_GRAYSCALE, FRAMESIZE_QQVGA, 1, CAMERA_GRAB_LATEST,
      CAMERA_FB_IN_DRAM,  "GRAY   QQVGA 20MHz fb1 DRAM " },
    { 20000000, PIXFORMAT_RGB565, FRAMESIZE_QVGA,  1, CAMERA_GRAB_LATEST,
      CAMERA_FB_IN_PSRAM, "RGB565 QVGA  20MHz fb1 psram" },
    { 20000000, PIXFORMAT_JPEG,   FRAMESIZE_QVGA,  1, CAMERA_GRAB_LATEST,
      CAMERA_FB_IN_PSRAM, "JPEG   QVGA  20MHz fb1 psram" },
};

#define N_ATTEMPTS (sizeof(ATTEMPTS) / sizeof(ATTEMPTS[0]))

static bool s_started = false;

static camera_config_t build_config(const cam_attempt_t *a)
{
    camera_config_t c = {
        .pin_pwdn = CAM_PIN_PWDN,
        .pin_reset = CAM_PIN_RESET,
        .pin_xclk = CAM_PIN_XCLK,
        .pin_sccb_sda = CAM_PIN_SIOD,
        .pin_sccb_scl = CAM_PIN_SIOC,

        .pin_d0 = CAM_PIN_D0,
        .pin_d1 = CAM_PIN_D1,
        .pin_d2 = CAM_PIN_D2,
        .pin_d3 = CAM_PIN_D3,
        .pin_d4 = CAM_PIN_D4,
        .pin_d5 = CAM_PIN_D5,
        .pin_d6 = CAM_PIN_D6,
        .pin_d7 = CAM_PIN_D7,

        .pin_vsync = CAM_PIN_VSYNC,
        .pin_href = CAM_PIN_HREF,
        .pin_pclk = CAM_PIN_PCLK,

        .xclk_freq_hz = a->xclk_hz,
        .ledc_timer = LEDC_TIMER_0,
        .ledc_channel = LEDC_CHANNEL_0,

        .pixel_format = a->format,
        .frame_size = a->size,
        .jpeg_quality = 12,

        .fb_count = a->fb_count,
        .fb_location = a->location,
        .grab_mode = a->grab,
    };
    return c;
}

/* Tries to pull real frames. Several are attempted because the first frame
 * after a mode change is routinely malformed while the sensor's AGC/AEC
 * settle - treating a single failure as final would reject a working config. */
static bool capture_works(pixformat_t format, int tries)
{
    for (int i = 0; i < tries; i++) {
        camera_fb_t *fb = esp_camera_fb_get();
        if (fb != NULL) {
            size_t len = fb->len;
            int w = fb->width, h = fb->height;
            bool ok;

            if (format == PIXFORMAT_JPEG) {
                /* JPEG must start with the SOI marker. A non-NULL buffer is not
                 * enough - the first sweep returned buffers full of data that
                 * were not JPEG at all. */
                ok = (len > 3 && fb->buf[0] == 0xFF && fb->buf[1] == 0xD8);
            } else {
                /* Raw formats have no marker to check, so the test is that the
                 * buffer is the size the geometry demands AND is not uniformly
                 * one value. An all-zero or all-0xFF buffer is what a dead
                 * parallel bus produces, and it would otherwise pass. */
                size_t expect = (size_t) w * h * (format == PIXFORMAT_RGB565 ? 2 : 1);
                bool varied = false;
                for (size_t k = 1; k < len && k < 4096; k++) {
                    if (fb->buf[k] != fb->buf[0]) { varied = true; break; }
                }
                ok = (len == expect) && varied;
                if (len == expect && !varied) {
                    ESP_LOGW(TAG, "  -> right size but every byte is 0x%02x - "
                                  "that is a dead data bus, not an image",
                             fb->buf[0]);
                }
            }

            esp_camera_fb_return(fb);
            if (ok) {
                ESP_LOGI(TAG, "  -> GOOD frame %dx%d %u bytes", w, h,
                         (unsigned) len);
                return true;
            }
            if (format == PIXFORMAT_JPEG) {
                ESP_LOGW(TAG, "  -> frame returned but no JPEG SOI (%u bytes)",
                         (unsigned) len);
            }
        }
        vTaskDelay(pdMS_TO_TICKS(200));
    }
    return false;
}

esp_err_t camera_start(void)
{
    size_t psram = heap_caps_get_total_size(MALLOC_CAP_SPIRAM);
    ESP_LOGI(TAG, "PSRAM total %u bytes", (unsigned) psram);
    if (psram == 0) {
        ESP_LOGE(TAG, "no PSRAM - check CONFIG_SPIRAM and the OCT/QUAD mode");
        return ESP_ERR_NOT_SUPPORTED;
    }

    for (size_t i = 0; i < N_ATTEMPTS; i++) {
        const cam_attempt_t *a = &ATTEMPTS[i];
        ESP_LOGI(TAG, "attempt %u/%u: %s",
                 (unsigned) (i + 1), (unsigned) N_ATTEMPTS, a->label);

        camera_config_t cfg = build_config(a);
        esp_err_t err = esp_camera_init(&cfg);
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "  init failed: %s", esp_err_to_name(err));
            continue;
        }

        sensor_t *s = esp_camera_sensor_get();
        if (s != NULL && i == 0) {
            /* Logged once. Note carefully what this does and does not prove:
             * SCCB is I2C, so a correct PID confirms SIOD, SIOC and XCLK only.
             * The parallel data bus is proven by a frame, not by this. */
            ESP_LOGI(TAG, "sensor PID 0x%04x (SCCB ok: SIOD/SIOC/XCLK correct; "
                          "data bus NOT yet proven)", s->id.PID);
            if (s->id.PID != OV3660_PID) {
                ESP_LOGW(TAG, "expected OV3660 0x3660");
            }
        }
        if (s != NULL) {
            s->set_vflip(s, 1);
        }

        if (capture_works(a->format, 3)) {
            ESP_LOGI(TAG, "WORKING CONFIG: %s", a->label);
            ESP_LOGI(TAG, "  put these values in the single config once settled");
            s_started = true;
            return ESP_OK;
        }

        ESP_LOGW(TAG, "  no usable frame with %s", a->label);
        esp_camera_deinit();
        vTaskDelay(pdMS_TO_TICKS(300));
    }

    ESP_LOGE(TAG, "no configuration produced a usable frame");
    ESP_LOGE(TAG, "SCCB works (PID read), so the ribbon IS seated and XCLK/SIOD/"
                  "SIOC are right. RGB565 failing too means the fault is the "
                  "PIXEL PATH, not JPEG: D0-D7, VSYNC, HREF or PCLK.");
    return ESP_FAIL;
}

esp_err_t camera_capture_and_report(void)
{
    if (!s_started) {
        return ESP_ERR_INVALID_STATE;
    }

    camera_fb_t *fb = esp_camera_fb_get();
    if (fb == NULL) {
        ESP_LOGE(TAG, "capture failed");
        return ESP_FAIL;
    }

    /* Only JPEG has an SOI marker. Reporting "SOI=NO" for a perfectly good
     * RGB565 frame would be a false alarm in the log, which is exactly the kind
     * of noise that sends the next person chasing a non-problem. */
    if (fb->format == PIXFORMAT_JPEG) {
        bool soi = (fb->len > 3 && fb->buf[0] == 0xFF && fb->buf[1] == 0xD8);
        ESP_LOGI(TAG, "frame %ux%u  %u bytes  JPEG SOI=%s",
                 (unsigned) fb->width, (unsigned) fb->height,
                 (unsigned) fb->len, soi ? "yes" : "NO");
    } else {
        ESP_LOGI(TAG, "frame %ux%u  %u bytes  raw fmt=%d",
                 (unsigned) fb->width, (unsigned) fb->height,
                 (unsigned) fb->len, (int) fb->format);
    }

    /* Returned immediately: holding frame buffers is how a camera firmware runs
     * out of PSRAM minutes in, which then looks like a random hang. */
    esp_camera_fb_return(fb);
    return ESP_OK;
}
