// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: MPL-2.0

#pragma once

/* Included here rather than relied upon from esp_err.h: this header names
 * uint8_t and size_t in its own prototypes, so it has to compile standalone.
 * dht11.h made exactly this mistake and the error surfaced in main.c, which
 * made it look like the caller was at fault. */
#include <stddef.h>
#include <stdint.h>

#include "esp_err.h"

/* Brings up the OV3660 using the pin map in board_pins.h, and logs the sensor
 * PID it reads back. A successful init with PID 0x3660 is what proves that pin
 * map against this particular board. */
esp_err_t camera_start(void);

/* Grabs one frame and logs its size and dimensions. The buffer is returned to
 * the driver before this call returns, so nothing is retained. */
esp_err_t camera_capture_and_report(void);

/* Captures a frame and returns it as a JPEG, encoded in SOFTWARE.
 *
 * The sensor's own JPEG mode does not work on this board - see the isolation
 * matrix in camera.c - so the pixels come back as RGB565 and are compressed on
 * the CPU. This is what the Prusa Connect upload will send.
 *
 * On ESP_OK the caller owns *out and must free() it. quality is 1-100, higher
 * being better; 80 is a reasonable default for a print monitor. */
esp_err_t camera_capture_jpeg(uint8_t quality, uint8_t **out, size_t *out_len);
