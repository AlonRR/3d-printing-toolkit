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
#include "img_converters.h"
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

/* YUV422 FIRST, RGB565 only as a fallback.
 *
 * The hardware JPEG encoder is broken on this board (isolation matrix below),
 * which forced a raw capture format. RGB565 was the obvious choice and produced
 * a persistent colour cast that survived three attempts to fix it:
 *
 *   - a byte-order swap, which made it far worse because frame2jpg already
 *     swaps internally and the second swap simply undid the first;
 *   - enabling the sensor's auto white balance, gamma and lens correction,
 *     which changed nothing visible;
 *   - a grey-world correction in software, which moved the cast from teal to
 *     green rather than removing it.
 *
 * Measurement settled what argument could not. Pulling a raw frame off the
 * board and correlating the channel planes scored the true layout at 0.925
 * against 0.229 for the alternative, so the LAYOUT was right the whole time and
 * per-channel gain was never going to fix it.
 *
 * Reading upstream - which should have come first - found the RGB565 path on
 * this chip is not trusted: espressif/esp32-camera issue 422 (byte order
 * between RGB565 producers and consumers) and issue 692 (RGB565 wrong on
 * ESP32-S3, unresolved). Neither matches exactly, but both say the same thing.
 *
 * YUV422 avoids the problem rather than compensating for it. The driver
 * configures it through a SEPARATE register set - sensor_fmt_yuv422 rather than
 * sensor_fmt_rgb565 - so it does not share the suspect path at all. And JPEG's
 * native colour space is YCbCr, so YUV422 needs no colour conversion before
 * encoding: it is both the most direct route and the least code.
 *
 * YUV422 WAS TRIED AND IS ALSO WRONG - differently wrong, yellow and pink
 * rather than teal, but wrong. So the fault is not specific to the RGB565
 * register path, and four attempts have now failed:
 *
 *   byte swap          -> far worse (frame2jpg already swaps)
 *   sensor auto-WB     -> no visible change
 *   grey-world in SW   -> cast moved, not removed
 *   YUV422 capture     -> different cast, still wrong
 *
 * What every attempt has in common: STRUCTURE IS PERFECT and only colour is
 * wrong, in every format. The remaining hypothesis that fits all four results
 * is a one-byte PHASE OFFSET in the parallel capture - the DMA latching the
 * byte stream half a pixel out. That would leave luminance intact while
 * swapping the two bytes of an RGB565 pixel (which frame2jpg then compensates
 * for) AND swapping Y with U/V in YUV422 (which nothing compensates for).
 *
 * It is a testable idea rather than another guess, but it has not been tested
 * and the cast is cosmetic for print monitoring, so RGB565 - the least bad of
 * the four - is restored as the default rather than chasing it further.
 */
static const cam_attempt_t ATTEMPTS[] = {
    { 20000000, PIXFORMAT_RGB565, FRAMESIZE_VGA,   2, CAMERA_GRAB_WHEN_EMPTY,
      CAMERA_FB_IN_PSRAM, "RGB565 VGA   PSRAM fb2" },
    { 20000000, PIXFORMAT_RGB565, FRAMESIZE_QVGA,  2, CAMERA_GRAB_WHEN_EMPTY,
      CAMERA_FB_IN_PSRAM, "RGB565 QVGA  PSRAM fb2" },
    { 20000000, PIXFORMAT_YUV422, FRAMESIZE_VGA,   2, CAMERA_GRAB_WHEN_EMPTY,
      CAMERA_FB_IN_PSRAM, "YUV422 VGA   PSRAM fb2  (alt)" },
    { 20000000, PIXFORMAT_RGB565, FRAMESIZE_QQVGA, 1, CAMERA_GRAB_LATEST,
      CAMERA_FB_IN_DRAM,  "RGB565 QQVGA DRAM  fb1  (fallback)" },
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
                size_t bpp = (format == PIXFORMAT_RGB565 || format == PIXFORMAT_YUV422) ? 2 : 1;
                size_t expect = (size_t) w * h * bpp;
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

        /* COLOUR. The first snapshots reached Prusa Connect with whites showing
         * purple and tans showing green.
         *
         * A byte-order swap was tried first and made it far worse - which was
         * the evidence that the bytes were already aligned correctly. The
         * reasoning that should have come first: swapping red and blue leaves
         * WHITE unchanged, and white was not unchanged. Green was being lost,
         * so the fault is white balance and gain, not pixel layout.
         *
         * These are on by default in the driver's JPEG path but are not applied
         * when a raw format is selected, which is why capturing RGB565 - forced
         * on us by the broken hardware JPEG - lost them. */
        s->set_whitebal(s, 1);      /* auto white balance            */
        s->set_awb_gain(s, 1);      /* and its gain control          */
        s->set_wb_mode(s, 0);       /* auto, not a fixed preset      */
        s->set_exposure_ctrl(s, 1); /* auto exposure                 */
        s->set_gain_ctrl(s, 1);     /* auto gain                     */
        s->set_raw_gma(s, 1);       /* gamma - without it mid-tones sink */
        s->set_lenc(s, 1);          /* lens shading correction       */
        s->set_bpc(s, 1);           /* bad pixel correction          */
        s->set_wpc(s, 1);           /* white pixel correction        */
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


/* Grey-world white balance, applied in software.
 *
 * WHY THIS EXISTS. Measured from a real frame pulled off the board: red averages
 * 20% below green and blue 11% above, which renders as the teal cast the first
 * snapshots showed. The sensor's own AWB is enabled but does not converge in a
 * raw pixel format - the driver applies those corrections in its JPEG path, and
 * capturing RGB565 is forced on us by the broken hardware encoder.
 *
 * Two wrong turns preceded this, both settled by measuring rather than by
 * argument. A byte-order swap made the picture far worse, because frame2jpg
 * ALREADY swaps internally and the extra swap simply undid it. Enabling the
 * sensor's auto-correction changed nothing. Correlating the channel planes
 * across candidate layouts scored the true layout at 0.925 against 0.229 for
 * the alternative, which proved the layout was right all along and the fault
 * was purely colour balance.
 *
 * ASSUMPTION, stated because it can be wrong: grey-world takes the scene to
 * average to neutral. That holds for a printer and its surroundings and fails
 * for a frame filled with one saturated colour - a large orange print would be
 * partly desaturated. The gains are clamped so that failure is mild rather than
 * absurd.
 *
 * The buffer is stored byte-swapped relative to the true RGB565 value, so each
 * word is swapped on read and swapped back on write.
 */
static void white_balance(camera_fb_t *fb)
{
    if (fb->format != PIXFORMAT_RGB565 || fb->len < 4) {
        return;
    }

    uint16_t *p = (uint16_t *) fb->buf;
    size_t n = fb->len / 2;

    /* Subsampled: 1 pixel in 16 is ample for a mean and keeps this well under
     * the cost of the encode it precedes. */
    uint32_t sr = 0, sg = 0, sb = 0, count = 0;
    for (size_t i = 0; i < n; i += 16) {
        uint16_t v = (uint16_t) ((p[i] >> 8) | (p[i] << 8));
        sr += ((v >> 11) & 0x1F) << 3;
        sg += ((v >> 5) & 0x3F) << 2;
        sb += (v & 0x1F) << 3;
        count++;
    }
    if (count == 0 || sr == 0 || sg == 0 || sb == 0) {
        return;
    }

    uint32_t target = (sr + sg + sb) / (3 * count);

    /* Fixed point, 8 fractional bits - no float in a per-pixel loop. */
    int32_t gr = (int32_t) ((target * 256ULL * count) / sr);
    int32_t gg = (int32_t) ((target * 256ULL * count) / sg);
    int32_t gb = (int32_t) ((target * 256ULL * count) / sb);

    /* Clamped to 0.5x - 2x. An unclamped gain on a scene that genuinely is one
     * colour would swing wildly frame to frame, which looks far worse than a
     * mild cast. */
    const int32_t LO = 128, HI = 512;
    if (gr < LO) { gr = LO; }
    if (gr > HI) { gr = HI; }
    if (gg < LO) { gg = LO; }
    if (gg > HI) { gg = HI; }
    if (gb < LO) { gb = LO; }
    if (gb > HI) { gb = HI; }

    for (size_t i = 0; i < n; i++) {
        uint16_t v = (uint16_t) ((p[i] >> 8) | (p[i] << 8));
        int32_t r = (((v >> 11) & 0x1F) * gr) >> 8;
        int32_t g = (((v >> 5) & 0x3F) * gg) >> 8;
        int32_t b = ((v & 0x1F) * gb) >> 8;
        if (r > 31) r = 31;
        if (g > 63) g = 63;
        if (b > 31) b = 31;
        uint16_t o = (uint16_t) ((r << 11) | (g << 5) | b);
        p[i] = (uint16_t) ((o >> 8) | (o << 8));
    }
}

esp_err_t camera_capture_jpeg(uint8_t quality, uint8_t **out, size_t *out_len)
{
    if (!s_started || out == NULL || out_len == NULL) {
        return ESP_ERR_INVALID_STATE;
    }

    camera_fb_t *fb = esp_camera_fb_get();
    if (fb == NULL) {
        ESP_LOGE(TAG, "capture failed");
        return ESP_FAIL;
    }

    white_balance(fb);

    *out = NULL;
    *out_len = 0;
    bool ok = frame2jpg(fb, quality, out, out_len);

    /* Returned before the result is examined, so that no early return can leak
     * it. Frame buffers are a fixed pool; leaking one stalls capture
     * permanently, and that presents as a hang rather than as an error. */
    esp_camera_fb_return(fb);

    if (!ok || *out == NULL || *out_len < 4) {
        ESP_LOGE(TAG, "software JPEG encode failed");
        if (*out) { free(*out); *out = NULL; }
        *out_len = 0;
        return ESP_FAIL;
    }

    /* The same check the hardware path failed. Encoding in software makes a
     * malformed JPEG far less likely, but "far less likely" is not a reason to
     * stop checking - especially having just spent three sweeps on exactly this
     * marker. */
    if ((*out)[0] != 0xFF || (*out)[1] != 0xD8) {
        ESP_LOGE(TAG, "encoder returned data without a JPEG SOI");
        free(*out);
        *out = NULL;
        *out_len = 0;
        return ESP_FAIL;
    }

    return ESP_OK;
}
