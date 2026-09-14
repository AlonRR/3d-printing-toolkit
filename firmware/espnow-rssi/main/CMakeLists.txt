idf_component_register(SRCS "espnow_test.c"
                       INCLUDE_DIRS "."
                       REQUIRES nvs_flash esp_event esp_netif esp_wifi esp_driver_tsens)
