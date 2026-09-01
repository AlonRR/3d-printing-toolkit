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

/* WHAT THE HARDWARE HAS ALREADY TOLD US, and what this table asks next.
 *
 * Two sweeps established the following, each by a result that could have gone
 * the other way:
 *
 *   - Halving XCLK moved PCLK from 10 MHz to 5 MHz and changed NOTHING. So the
 *     failure is not the DMA struggling to keep up, which is the usual reading
 *     of "NO-SOI - JPEG start marker missing".
 *   - RGB565 QQVGA into DRAM captured perfectly: 38400 bytes, exactly
 *     160x120x2, with varied content. So D0-D7, VSYNC, HREF and PCLK are all
 *     correct, and every pin in board_pins.h is now proven rather than assumed.
 *
 * The pin map is separately corroborated: Prusa's module_ESP32-S3-CAM.h carries
 * camera pins byte-for-byte identical to the Freenove header this was taken
 * from, and SCCB works on them here.
 *
 * So the fault is narrow: JPEG mode specifically. But the working case and the
 * failing case differ in THREE variables at once - format, size and location -
 * and that cannot say which one matters.
 *
 * These attempts therefore vary ONE axis at a time around the known-good
 * corner:
 *
 *   1 vs 2 : format   (RGB565 -> JPEG, everything else held)
 *   1 vs 3 : location (DRAM   -> PSRAM)
 *   2 vs 4 : format change, now in PSRAM
 *   5, 6   : does size matter once the working format is known
 *
 * Unlike the previous sweeps this one runs EVERY attempt and prints a table.
 * Stopping at the first success is what a search does; an experiment has to
 * collect the failures too, because "JPEG never works" and "nothing works in
 * PSRAM" are different diagnoses that the first success would hide. */
static const cam_attempt_t ATTEMPTS[] = {
    { 20000000, PIXFORMAT_RGB565, FRAMESIZE_QQVGA, 1, CAMERA_GRAB_LATEST,
      CAMERA_FB_IN_DRAM,  "1 RGB565 QQVGA DRAM  fb1  (control)" },
    { 20000000, PIXFORMAT_JPEG,   FRAMESIZE_QQVGA, 1, CAMERA_GRAB_LATEST,
      CAMERA_FB_IN_DRAM,  "2 JPEG   QQVGA DRAM  fb1  (format)" },
    { 20000000, PIXFORMAT_RGB565, FRAMESIZE_QQVGA, 1, CAMERA_GRAB_LATEST,
      CAMERA_FB_IN_PSRAM, "3 RGB565 QQVGA PSRAM fb1  (location)" },
    { 20000000, PIXFORMAT_JPEG,   FRAMESIZE_QQVGA, 1, CAMERA_GRAB_LATEST,
      CAMERA_FB_IN_PSRAM, "4 JPEG   QQVGA PSRAM fb1  (both)" },
    { 20000000, PIXFORMAT_RGB565, FRAMESIZE_QVGA,  1, CAMERA_GRAB_LATEST,
      CAMERA_FB_IN_PSRAM, "5 RGB565 QVGA  PSRAM fb1  (size)" },
    { 20000000, PIXFORMAT_JPEG,   FRAMESIZE_VGA,   2, CAMERA_GRAB_WHEN_EMPTY,
      CAMERA_FB_IN_PSRAM, "6 JPEG   VGA   PSRAM fb2  (realistic)" },
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

    bool passed[N_ATTEMPTS];
    int first_ok = -1;

    /* Every attempt runs, including ones after a success. A search stops at the
     * first win; this is an experiment, and the failures carry the diagnosis. */
    for (size_t i = 0; i < N_ATTEMPTS; i++) {
        const cam_attempt_t *a = &ATTEMPTS[i];
        ESP_LOGI(TAG, "attempt %u/%u: %s",
                 (unsigned) (i + 1), (unsigned) N_ATTEMPTS, a->label);

        camera_config_t cfg = build_config(a);
        esp_err_t err = esp_camera_init(&cfg);
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "  init failed: %s", esp_err_to_name(err));
            passed[i] = false;
            continue;
        }

        sensor_t *s = esp_camera_sensor_get();
        if (s != NULL && i == 0) {
            /* SCCB is I2C: a correct PID confirms SIOD, SIOC and XCLK only. The
             * parallel bus is proven by a frame, never by this. */
            ESP_LOGI(TAG, "sensor PID 0x%04x", s->id.PID);
            if (s->id.PID != OV3660_PID) {
                ESP_LOGW(TAG, "expected OV3660 0x3660");
            }
        }
        if (s != NULL) {
            s->set_vflip(s, 1);
        }

        passed[i] = capture_works(a->format, 3);
        if (passed[i] && first_ok < 0) {
            first_ok = (int) i;
        }
        esp_camera_deinit();
        vTaskDelay(pdMS_TO_TICKS(300));
    }

    ESP_LOGI(TAG, "================ ISOLATION MATRIX ================");
    for (size_t i = 0; i < N_ATTEMPTS; i++) {
        ESP_LOGI(TAG, "  %-38s %s", ATTEMPTS[i].label,
                 passed[i] ? "PASS" : "fail");
    }
    ESP_LOGI(TAG, "==================================================");

    if (first_ok < 0) {
        ESP_LOGE(TAG, "nothing captured - the pixel path itself is wrong");
        return ESP_FAIL;
    }

    /* Re-init the first configuration that worked, so the main loop has a live
     * camera rather than a deinitialised one. */
    const cam_attempt_t *win = &ATTEMPTS[first_ok];
    ESP_LOGI(TAG, "adopting: %s", win->label);
    camera_config_t cfg = build_config(win);
    esp_err_t err = esp_camera_init(&cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "re-init of the winning config failed: %s",
                 esp_err_to_name(err));
        return err;
    }
    sensor_t *s = esp_camera_sensor_get();
    if (s != NULL) {
        s->set_vflip(s, 1);
    }
    s_started = true;
    return ESP_OK;
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
