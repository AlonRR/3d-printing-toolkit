#pragma once

#include "esp_err.h"

/* Joins the station network and blocks until an IP arrives or the timeout
 * expires. Credentials come from the gitignored wifi_secrets.h. */
esp_err_t wifi_connect(int timeout_ms);

/* Dotted-quad of the address obtained, or "0.0.0.0" if not connected. */
const char *wifi_ip_str(void);

/* Current AP signal strength in dBm, or 0 if unavailable. Worth logging beside
 * any throughput figure: a number measured at -75 dBm means something quite
 * different from the same number at -45 dBm. */
int wifi_rssi(void);
