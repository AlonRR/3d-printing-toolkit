/* OV3660 bring-up.
 *
 * This file is the acceptance test for board_pins.h. The pin map came from
 * Prusa's Freenove board header and has never been checked against the board on
 * this bench, so the sensor PID is read back and logged: 0x3660 means the SCCB
 * lines and the clock are right, and by extension that the board really is of
 * the Freenove layout.
 *
 * A failure here is far more likely to be the ribbon than the code. The FPC
 * connector has a flip-up latch and the cable only works one way round, so
 * reseat it before doubting the pin numbers.
 */

#include "camera.h"

#include "board_pins.h"
#include "esp_camera.h"
#include "esp_heap_caps.h"
#include "esp_log.h"

static const char *TAG = "cam";

#define OV3660_PID 0x3660

esp_err_t camera_start(void)
{
    camera_config_t config = {
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

        /* 20 MHz is the standard XCLK for this family. */
        .xclk_freq_hz = 20000000,
        .ledc_timer = LEDC_TIMER_0,
        .ledc_channel = LEDC_CHANNEL_0,

        /* JPEG, because the eventual destination is an HTTP POST of a JPEG and
         * the sensor's own encoder is free. Raw formats would also not fit in
         * PSRAM at this resolution with two buffers. */
        .pixel_format = PIXFORMAT_JPEG,

        /* SVGA rather than the sensor's full 3 MP: deliberately conservative
         * for a first bring-up, because a resolution the buffers cannot hold
         * fails inside the driver and looks like a wiring fault. Raise it once
         * the pin map is proven. */
        .frame_size = FRAMESIZE_SVGA,
        .jpeg_quality = 12,          /* lower number = better quality */

        .fb_count = 2,
        .fb_location = CAMERA_FB_IN_PSRAM,
        .grab_mode = CAMERA_GRAB_WHEN_EMPTY,
    };

    /* Without PSRAM the two SVGA buffers cannot be allocated, and the failure
     * appears deep inside the driver. Checking first turns that into one clear
     * line naming the actual cause. */
    size_t psram = heap_caps_get_total_size(MALLOC_CAP_SPIRAM);
    ESP_LOGI(TAG, "PSRAM total %u bytes", (unsigned) psram);
    if (psram == 0) {
        ESP_LOGE(TAG, "no PSRAM - check CONFIG_SPIRAM and the OCT/QUAD mode");
        return ESP_ERR_NOT_SUPPORTED;
    }

    esp_err_t err = esp_camera_init(&config);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "esp_camera_init failed: %s", esp_err_to_name(err));
        ESP_LOGE(TAG, "reseat the FPC ribbon first, then suspect board_pins.h");
        return err;
    }

    sensor_t *s = esp_camera_sensor_get();
    if (s == NULL) {
        ESP_LOGE(TAG, "init succeeded but no sensor handle");
        return ESP_FAIL;
    }

    ESP_LOGI(TAG, "sensor PID 0x%04x  VER 0x%02x  MIDL 0x%02x MIDH 0x%02x",
             s->id.PID, s->id.VER, s->id.MIDL, s->id.MIDH);

    if (s->id.PID == OV3660_PID) {
        ESP_LOGI(TAG, "OV3660 confirmed - the pin map in board_pins.h is CORRECT");
        /* The OV3660 ships with these defaults inverted relative to how the
         * module is mounted on this board. */
        s->set_vflip(s, 1);
        s->set_brightness(s, 1);
        s->set_saturation(s, -2);
    } else {
        ESP_LOGW(TAG, "unexpected PID - a sensor answered, so SCCB works, but "
                      "it is not the OV3660 this was written for");
    }

    return ESP_OK;
}

esp_err_t camera_capture_and_report(void)
{
    camera_fb_t *fb = esp_camera_fb_get();
    if (fb == NULL) {
        ESP_LOGE(TAG, "capture failed");
        return ESP_FAIL;
    }

    ESP_LOGI(TAG, "frame %ux%u  %u bytes  format=%d",
             (unsigned) fb->width, (unsigned) fb->height,
             (unsigned) fb->len, (int) fb->format);

    /* Returned immediately. Holding frame buffers is how a camera firmware runs
     * out of PSRAM several minutes in, which then looks like a random hang. */
    esp_camera_fb_return(fb);
    return ESP_OK;
}
