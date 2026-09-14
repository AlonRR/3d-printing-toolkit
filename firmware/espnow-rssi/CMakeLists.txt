cmake_minimum_required(VERSION 3.16)
# Build only what main needs. Without this every IDF component is compiled -
# including esp_lcd, which crashed the compiler on the first attempt.
set(COMPONENTS main)
include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(espnow_rssi)
