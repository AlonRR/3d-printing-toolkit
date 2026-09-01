# ESP32-S3 camera node — our own firmware, in C

Plain **ESP-IDF 5.5**, no Arduino. An alternative to
[prusa3d/Prusa-Firmware-ESP32-Cam](https://github.com/prusa3d/Prusa-Firmware-ESP32-Cam), which is
an Arduino sketch and whose last commit was January 2025 — see
[docs/prusa-connect-api.md](../../docs/prusa-connect-api.md).

## The board

**ESP32-S3-WROOM-1 N16R8**, dual USB-C, camera FPC connector, with an **OV3660** module.

⚠️ **Two USB-C ports and they are not interchangeable.** One is native USB, the other a **CH343
UART bridge**. The bridge is the one in use here — it enumerates as `USB-Enhanced-SERIAL CH343`
(**COM9**), and `sdkconfig.defaults` therefore leaves the console on **UART0**. Selecting
`USB_SERIAL_JTAG` would push every log line out the *other* connector and the board would look
dead while running perfectly. That already cost a day on the C3-MINI-1; see
[chamber-sensor](../../docs/chamber-sensor.md) §3y.

## Milestone 1 — prove the hardware, no network

Deliberately no WiFi. The chamber-sensor work lost days to a network stack built on a radio that
was never transmitting, and the lesson was to prove the physical layer first with a check that can
actually fail.

This build brings up the camera, reads back the sensor ID, reads the DHT, and logs both.

### Result: the pin map is PROVEN, on this hardware

`board_pins.h` was transcribed from Prusa's `module_ESP32-S3_Wroom_Freenove.h`, and this board is
an AliExpress board of that *layout* rather than a genuine Freenove — well-sourced, but an
assumption. It is now verified in two independent halves:

```
cam: sensor PID 0x3660                     <- SCCB: proves SIOD, SIOC, XCLK
cam:  -> GOOD frame 160x120 38400 bytes    <- pixels: proves D0-D7, VSYNC, HREF, PCLK
```

**Both halves are needed and neither substitutes for the other.** Reading the PID happens over
SCCB, which is I²C — it says nothing at all about the parallel data bus. An early version of this
file logged "pin map is CORRECT" on the PID alone, which was an overstatement: the data bus was
still entirely unproven at that point. 38400 bytes is exactly 160×120×2, and the check also
requires the buffer to contain more than one distinct byte value, because a dead bus returns a
correctly-sized block of uniform `0x00` or `0xFF` that a length check would happily accept.

Corroboration: Prusa's `module_ESP32-S3-CAM.h` carries camera pins **byte-for-byte identical** to
the Freenove header, so both of Prusa's S3 boards share this map.

If `esp_camera_init` fails, **reseat the FPC ribbon before doubting the pin numbers.** The latch
flips up and the cable only seats one way round; a freshly-plugged ribbon is the likeliest cause by
a wide margin. Note that SCCB working already proves the ribbon is seated.

### The sensor's hardware JPEG is broken on this board — isolated, not guessed

Raw formats capture fine; **every JPEG attempt fails** with `NO-SOI - JPEG start marker missing`
and a frame timeout. An isolation matrix varying one axis at a time settles the attribution:

| Attempt | Result |
|---|---|
| RGB565 QQVGA **DRAM** | **PASS** |
| JPEG QQVGA DRAM | fail |
| RGB565 QQVGA **PSRAM** | **PASS** |
| JPEG QQVGA PSRAM | fail |
| RGB565 **QVGA** PSRAM | **PASS** |
| JPEG VGA PSRAM fb2 | fail |

**Location does not matter. Size does not matter. Format is the only variable.** Halving XCLK
(PCLK 10 MHz → 5 MHz) also changed nothing, which had already ruled out the usual "DMA cannot keep
up" reading of `NO-SOI`.

The matrix runs *every* attempt rather than stopping at the first success. That distinction is the
point: a search stops when it wins, but an experiment needs the failures, because "JPEG never
works" and "nothing works in PSRAM" are different diagnoses with different fixes, and the first
PASS would have hidden which one this is.

**The fix is to not use it.** Capture **RGB565** and encode JPEG in **software** with esp32-camera's
`frame2jpg()`. The sensor's JPEG path is bypassed entirely. For a print-monitoring snapshot every
few seconds the CPU cost is irrelevant — this is not a video stream.

### The DHT

`GPIO47`, from the same Prusa header, and free of every camera pin. The driver is bit-banged here
rather than pulled in as a component — the protocol is ~80 lines and every library available brings
either an Arduino dependency or a conflicting IDF pin.

It distinguishes three outcomes deliberately, because they mean different things:

| Log | Meaning |
|---|---|
| `DHT 11: 24.0 C  41.0 %RH` | working |
| `DHT no response on GPIO47` | nothing wired to the pin |
| `DHT checksum failed` | **wired and responding**, but the frame was corrupted |

A timeout and a checksum failure are very different problems, and collapsing them into one "sensor
error" is how a wiring question gets mistaken for a timing bug.

Wiring, KY-015 module: `−` → GND, `+` → 3V3, `S` → GPIO47.

## Building

The S3 needs the **xtensa** toolchain. This machine had only `riscv32-esp-elf`, because everything
built here before targeted the C3. Install into the ESP-IDF that ESPHome already provisioned:

```powershell
$py $IDF_PATH\tools\idf_tools.py --non-interactive install --targets=esp32s3
```

⚠️ IDF 5.5 installs **one unified `xtensa-esp-elf`**, not the older per-chip
`xtensa-esp32s3-elf`. Any script that puts tool directories on `PATH` by name must use the new one
— otherwise the compiler is installed but invisible, and the build fails with "compiler not found"
while the toolchain sits right there.

Then `set-target esp32s3` and `build`. The first build needs network: `espressif/esp32-camera` is
pulled by the component manager.

## Roadmap

`camera.c`, `dht11.c` and `main.c` are separate from the start so phase 2 drops in without touching
capture:

- **Snapshot → Prusa Connect** via `POST /c/snapshot` with `Token` + `Fingerprint` headers — the
  only officially supported Connect API.
- **Publish the DHT reading**, to MQTT (`mqtt.internal.example`, already carrying the chamber work) or as
  plain-text HTTP endpoints in the style Prusa's own firmware uses.

⚠️ Prusa's firmware does **not** send its DHT reading to Connect — checked in `connect.cpp` and
`exif.cpp`. Anything wanting that temperature in Home Assistant has to publish it itself.
