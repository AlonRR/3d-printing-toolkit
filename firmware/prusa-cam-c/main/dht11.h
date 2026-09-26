// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: MPL-2.0

/* Bit-banged DHT11 / DHT22 reader.
 *
 * Written rather than pulled from a component because the protocol is ~80 lines
 * and every available library brings either an Arduino dependency or a
 * different IDF version pin.
 */

#pragma once

/* stdbool and stdint are included here, not left to the includer. A header that
 * names bool in its own struct has to be compilable on its own - dht11.c
 * happened to include stdbool first, so only main.c broke, which makes the
 * error look like a problem with the caller rather than with this file. */
#include <stdbool.h>
#include <stdint.h>

#include "esp_err.h"

typedef struct {
    float temperature_c;
    float humidity_pct;
    bool is_dht22;      /* inferred from the payload; see dht11.c */
} dht_reading_t;

/* Configures the pin. Safe to call once at startup. */
void dht_init(int gpio);

/* One complete read.
 *
 * ESP_OK                 - reading is valid
 * ESP_ERR_TIMEOUT        - no response, or a pulse never ended: usually nothing
 *                          wired to the pin
 * ESP_ERR_INVALID_CRC    - all 40 bits arrived but the checksum disagrees
 * ESP_ERR_INVALID_STATE  - called again within the sensor's minimum interval
 */
esp_err_t dht_read(dht_reading_t *out);
