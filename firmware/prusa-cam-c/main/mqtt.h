// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: MPL-2.0

#pragma once

#include <stdbool.h>

#include "esp_err.h"

/* Connects to the broker and publishes Home Assistant discovery.
 *
 * Requires WiFi to be up. Non-blocking after this returns: the client runs its
 * own task and reconnects on its own, so a broker restart does not need the
 * node restarted. */
esp_err_t mqtt_start(void);

/* True once the broker connection is established. */
bool mqtt_is_connected(void);

/* Publishes one reading. Silently does nothing if not connected - a sensor node
 * must not block or fail because the broker is briefly away. */
void mqtt_publish_reading(float temperature_c, float humidity_pct);
