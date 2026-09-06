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

/* Current AP signal strength in dBm, or 0 if unavailable. Worth logging beside
 * any throughput figure: a number measured at -75 dBm means something quite
 * different from the same number at -45 dBm. */
int wifi_rssi(void);
