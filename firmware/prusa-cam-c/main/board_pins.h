/* Pin map for the ESP32-S3-WROOM-1 dual-USB-C camera board.
 *
 * PROVENANCE, because this is the single most likely thing to be wrong. These
 * numbers are transcribed from module_ESP32-S3_Wroom_Freenove.h in Prusa's own
 * Prusa-Firmware-ESP32-Cam, which supports that board officially. The board on
 * the bench is an AliExpress board of the same layout rather than a genuine
 * Freenove, so the map is well-sourced but NOT verified on this hardware.
 *
 * It is verified at run time instead: if these pins are wrong, the SCCB probe
 * fails and the sensor PID does not read back as OV3660. That check is in
 * camera.c and it is the acceptance test for this whole file.
 */

#pragma once

/* ---------------------------------------------------------------- camera */

/* Both tied high on this board, so the driver must not drive them. */
#define CAM_PIN_PWDN     -1
#define CAM_PIN_RESET    -1

#define CAM_PIN_XCLK     15
#define CAM_PIN_SIOD      4     /* SCCB data  (I2C SDA) */
#define CAM_PIN_SIOC      5     /* SCCB clock (I2C SCL) */

/* Parallel data bus. Y0/Y1 are unused: the OV3660 is wired 8-bit here, so the
 * driver's D0 is the sensor's Y2. */
#define CAM_PIN_D0       11     /* Y2 */
#define CAM_PIN_D1        9     /* Y3 */
#define CAM_PIN_D2        8     /* Y4 */
#define CAM_PIN_D3       10     /* Y5 */
#define CAM_PIN_D4       12     /* Y6 */
#define CAM_PIN_D5       18     /* Y7 */
#define CAM_PIN_D6       17     /* Y8 */
#define CAM_PIN_D7       16     /* Y9 */

#define CAM_PIN_VSYNC     6
#define CAM_PIN_HREF      7
#define CAM_PIN_PCLK     13

/* ------------------------------------------------------------------- DHT */

/* Prusa's firmware puts the external temperature sensor here on this board, and
 * it does not collide with any camera pin above. GPIO47 is broken out on the
 * header, so the KY-015 module reaches it directly. */
#define DHT_PIN          47

/* ------------------------------------------------------------------ misc */

/* Addressable RGB LED, not a plain one - it needs an RMT driver rather than a
 * gpio_set_level, so it is left alone in this milestone. */
#define BOARD_RGB_LED_PIN 48
