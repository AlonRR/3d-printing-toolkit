# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

idf_component_register(
    SRCS "main.c" "camera.c" "dht11.c" "wifi.c" "benchmark.c" "mqtt.c"
         "connect_cam.c" "ota.c"
    INCLUDE_DIRS "."
    REQUIRES mqtt esp_wifi esp_netif nvs_flash esp_timer driver
             esp_http_client esp-tls mbedtls esp_http_server app_update)
