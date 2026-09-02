#pragma once

#include "esp_err.h"

/* Starts the OTA HTTP server. The board LISTENS; the developer machine pushes.
 *
 *   GET  /      -> running partition, version, build time
 *   POST /ota   -> the new firmware.bin, header X-OTA-Key: <ota_password>
 *
 * Also marks the running image valid, cancelling the bootloader's automatic
 * rollback - reaching this point means WiFi is up and OTA is serving. */
esp_err_t ota_start(int port);
