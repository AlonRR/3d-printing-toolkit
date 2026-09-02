idf_component_register(
    SRCS "main.c" "camera.c" "dht11.c" "wifi.c" "benchmark.c" "mqtt.c"
    INCLUDE_DIRS "."
    REQUIRES mqtt esp_wifi esp_netif nvs_flash esp_timer driver)
