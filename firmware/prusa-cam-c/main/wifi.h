// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: MPL-2.0

#pragma once

#include <stdbool.h>

#include "esp_err.h"

/* The node's name on the network, used three ways: as the DHCP hostname option
 * (so the router's client list shows a name rather than an anonymous lease,
 * which is what makes a reservation easy to create), as the mDNS hostname
 * (prusa-cam.local), and as the mDNS instance name. */
#define WIFI_HOSTNAME "prusa-cam"

/* Joins the station network and blocks until an IP arrives or the timeout
 * expires. Credentials come from the gitignored wifi_secrets.h. */
esp_err_t wifi_connect(int timeout_ms);

/* True while the station holds an IP. The reconnect machinery runs forever in
 * the background, so this can go false and true again at any time. */
bool wifi_is_connected(void);

/* Dotted-quad of the address obtained, or "0.0.0.0" if not connected. */
const char *wifi_ip_str(void);

/* How many times the station has LOST its association, LIFETIME - persisted in
 * NVS and carried across reboots, so it is genuinely monotonic and can be
 * published as total_increasing without lying. Distinguishes a link that reconnects constantly from one
 * that has been up throughout. */
unsigned wifi_disconnect_count(void);

/* Seconds since boot. Published so that a counter reset - which should now
 * only happen on an NVS wipe - is attributable rather than mysterious. */
unsigned wifi_uptime_s(void);

/* BSSID of the associated AP as "aa:bb:cc:dd:ee:ff", or "" when not associated.
 * A change here with RSSI intact is a mesh roam; RSSI falling with this
 * unchanged is a weak spot. */
const char *wifi_bssid_str(void);

/* Current AP signal strength in dBm, or 0 if unavailable. Worth logging beside
 * any throughput figure: a number measured at -75 dBm means something quite
 * different from the same number at -45 dBm. */
int wifi_rssi(void);
