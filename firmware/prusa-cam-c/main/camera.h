#pragma once

#include "esp_err.h"

/* Brings up the OV3660 using the pin map in board_pins.h, and logs the sensor
 * PID it reads back. A successful init with PID 0x3660 is what proves that pin
 * map against this particular board. */
esp_err_t camera_start(void);

/* Grabs one frame and logs its size and dimensions. The buffer is returned to
 * the driver before this call returns, so nothing is retained. */
esp_err_t camera_capture_and_report(void);
