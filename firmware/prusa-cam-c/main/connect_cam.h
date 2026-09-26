// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: MPL-2.0

#pragma once

#include <stddef.h>
#include <stdint.h>

#include "esp_err.h"

/* Derives this camera's fingerprint from its MAC. Call once after WiFi is up.
 *
 * Connect requires a fingerprint of 16-64 characters that is stable for the
 * life of the camera - it is how the server recognises the same device across
 * reboots. Deriving it from the MAC gives that for free, with no storage. */
void connect_cam_init(void);

/* The fingerprint, for logging. */
const char *connect_cam_fingerprint(void);

/* Uploads one JPEG to Prusa Connect.
 *
 * PUT /c/snapshot with Token and Fingerprint headers. Returns ESP_OK only on
 * HTTP 204, which is what the API defines as success - any 2xx is NOT good
 * enough to assume here. */
esp_err_t connect_cam_upload(const uint8_t *jpeg, size_t len);
