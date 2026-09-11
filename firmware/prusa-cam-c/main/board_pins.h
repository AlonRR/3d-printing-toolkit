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

/* ⚠️ CONTESTED, and worth understanding before wiring anything.
 *
 * Prusa ships two headers whose CAMERA pins are byte-for-byte identical to each
 * other and to the block above - so the camera map cannot tell these two boards
 * apart. Their auxiliary pins do differ, and they disagree exactly here:
 *
 *   module_ESP32-S3_Wroom_Freenove.h :  DHT 47,  FLASH 14
 *   module_ESP32-S3-CAM.h            :  DHT 20,  FLASH 47
 *
 * So GPIO47 is the DHT pin on one board and drives the FLASH LED on the other.
 * If this board is the second kind, putting a DHT on 47 means the sensor shares
 * a pin with an LED driver - which would read as an intermittent, wiring-like
 * fault rather than an obvious conflict.
 *
 * GPIO20 is chosen as the safer default: it is unused in BOTH headers. The
 * Freenove board simply has nothing on it, so nothing is lost by using it
 * either way, and the ambiguity costs nothing.
 *
 * ⛔ BUT GPIO20 IS NOT FREE ON THE CHIP, and the reasoning above missed it.
 * Found 11 Sep 2026 while handing this board over.
 *
 * On the ESP32-S3, GPIO19 and GPIO20 ARE the native USB D- and D+ lines, used by
 * both USB-OTG and the USB-Serial/JTAG peripheral. This build enables that
 * peripheral as a secondary console:
 *
 *     CONFIG_ESP_CONSOLE_SECONDARY_USB_SERIAL_JTAG=y
 *     CONFIG_ESP_CONSOLE_USB_SERIAL_JTAG_ENABLED=y
 *
 * So the DHT shares a pin with USB D+.
 *
 * ✅ IT WORKS IN DEPLOYMENT, which is exactly what makes it dangerous. The USB
 * PHY only drives those pins when a host enumerates. Running from a power-only
 * supply in the enclosure, nothing drives them, and the DHT has been publishing
 * correctly for days - verified live at the moment this was written.
 *
 * ⚠️ THE FAILURE IS BENCH-ONLY. Plug a data-capable USB cable into the native
 * port and the DHT shares its line with an active differential pair. Expect
 * checksum failures or silence WHILE DEBUGGING, and correct behaviour the moment
 * the cable comes out - which reads as a flaky sensor or bad wiring rather than
 * a pin conflict, and is the single most misleading shape a fault can take.
 *
 * The original reasoning asked "is this pin free on either candidate BOARD" and
 * never asked "is it free on the SoC". Both questions have to be asked.
 *
 * If the DHT is kept: move it to a pin with no peripheral claim - 21, 38, 39, 40,
 * 41, 42 are unused by the camera bus here. If USB-Serial/JTAG is not needed,
 * disabling it frees 19/20 properly rather than by luck.
 */
#define DHT_PIN          20

/* ------------------------------------------------------------------ misc */

/* Addressable RGB LED, not a plain one - it needs an RMT driver rather than a
 * gpio_set_level, so it is left alone in this milestone. */
#define BOARD_RGB_LED_PIN 48


/* ------------------------------------------------- WHAT IS ALREADY TAKEN
 *
 * Consolidated for anyone repurposing this board. The camera's parallel bus is
 * the big claim and it is not negotiable while the sensor is in use:
 *
 *   4 5 6 7 8 9 10 11 12 13 15 16 17 18   camera: SCCB, data bus, sync, clocks
 *   19 20                                 native USB D-/D+ (see the DHT note)
 *   47                                    CONTESTED: DHT on one board header,
 *                                         FLASH LED on the other
 *   48                                    onboard ADDRESSABLE RGB LED - needs an
 *                                         RMT driver, not gpio_set_level
 *
 * Believed free on this board: 14, 21, 38, 39, 40, 41, 42, 45, 46 - with the
 * usual S3 caveats that 45 and 46 are strapping pins and 26-32 are consumed by
 * octal PSRAM on an N16R8 part.
 */
