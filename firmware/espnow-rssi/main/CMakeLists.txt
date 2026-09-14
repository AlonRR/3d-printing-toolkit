idf_component_register(SRCS "espnow_test.c"
                       INCLUDE_DIRS "."
                       REQUIRES nvs_flash esp_event esp_netif esp_wifi esp_driver_tsens)

# TX power in 0.25 dBm steps. Default 78 = 19.5 dBm; override with idf.py -D TX_QDBM=<n>.
if(NOT DEFINED TX_QDBM)
  set(TX_QDBM 78)
endif()
target_compile_definitions(${COMPONENT_LIB} PRIVATE TX_QDBM=${TX_QDBM})
