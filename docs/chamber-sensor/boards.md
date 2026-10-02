# Boards — the pairing that works, the console trap, the bench reference (§3y, §3w)

*Part of the [chamber sensor](../chamber-sensor.md) notes.*

**In short:**

- **Give the transmitting job to a board that radiates** — the ESP32-C3-MINI-1 — and the listening
  job to the SuperMinis. That pairing worked on 1 Sep 2026 with no software change.
- **The console trap:** a SuperMini logs over native USB (`hardware_uart: USB_SERIAL_JTAG`); the
  MINI-1 board's UART-bridge port needs no override. Get it backwards and a healthy board looks
  dead.
- **The Arduino Nano ESP32 is the bench reference** — a control when a result is ambiguous, not a
  build target. In ESPHome it needs `flash_size: 16MB` and raw GPIO numbers.

## The pairing that works (§3y)

Proven 1 Sep 2026, and it is just [§3z](supermini-antenna.md)'s finding applied: **give the transmitting
job to the board that radiates, and the receiving job to the boards that only
listen well.**

| Role | Board | Port | Firmware |
|---|---|---|---|
| Sender + DHT11 | ESP32-C3-**MINI-1** | a USB serial port | `firmware/chamber-sensor-mini1.yaml` |
| Receiver / hub | C3 **SuperMini** | `/dev/ttyACM0` on the server | `firmware/chamber-hub-espnow.yaml` |

The server's console, continuously:

```
[I][hub:055]: RX broadcast 52 bytes     <- packet_transport: chamber_t + chamber_rh
[I][hub:055]: RX broadcast  4 bytes     <- the diagnostic ping
```

**Nothing in the software changed to achieve this.** The same ESPHome `espnow`
component that "did not work" works fine the moment a board with a functioning
antenna does the transmitting.

### The serial-port trap, which cost most of a day

The two board families are **opposites**, and getting this backwards makes a
perfectly healthy board look dead:

| Board | The port you plug in | `logger:` needs |
|---|---|---|
| C3 SuperMini | native USB = the `USB_SERIAL_JTAG` peripheral | `hardware_uart: USB_SERIAL_JTAG` |
| C3-MINI-1 board | **two** USB-C ports; `COM8` is the **UART bridge** | **no override** — the default UART is right |

This is the whole reason the plain-C test printed nothing on COM8 while
transmitting perfectly: that build routed its console to `USB_SERIAL_JTAG`,
which is the *other* connector. Silence on a console is not silence on the air.

### Still expected, not a fault (as of 1 Sep 2026)

The hub logs `no data from sensor yet` and the sender logs
`no reading - check wiring`, because **the DHT11 is still wired to a
SuperMini.** The transport is proven; move the sensor to `GPIO4` on the MINI-1
(KY-015: minus to GND, plus to 3V3, S to GPIO4) and real readings flow.

## The Arduino Nano ESP32 as the bench reference (§3w)

When a result is ambiguous, the question is always *is the board lying to me?*
[§3z](supermini-antenna.md) is what happens when nothing on the bench can answer that. The **Arduino
Nano ESP32** (u-blox NORA-W106 / ESP32-S3) is the board to answer it with: it
has a real module antenna, it has worked on WiFi here before, and it is already
proven in the `mcu-workflow` project. **Use it as a control, not as the build
target.**

### ESPHome

```yaml
esp32:
  board: arduino_nano_esp32
  flash_size: 16MB          # NOT optional - see below
  framework:
    type: esp-idf
```

Officially supported — it is in ESPHome's own board table, variant `esp32s3`, so
`variant:` need not be stated. The `espnow` component gates only on
"is an ESP32", so the S3 is in.

**⚠️ `flash_size: 16MB` is mandatory.** ESPHome's `esp32:` block defaults to
`4MB` and that default **overrides the board definition**. Leave it out and you
silently build a 4 MB image with a 4 MB partition table on a 16 MB board. There
is no error — you just lose three quarters of the flash.

**The logger needs nothing.** ESPHome already defaults the S3 to
`USB_SERIAL_JTAG`, and the Nano's USB-C *is* native USB, so the override the
SuperMinis need is redundant here. (Contrast §3y — this is the third distinct
console arrangement across three boards, which is exactly why it keeps biting.)

**Raw GPIO numbers, never `D0`–`D13`.** ESPHome builds this board with
`BOARD_USES_HW_GPIO_NUMBERS`, so the silkscreen labels do not apply:

| Silk | GPIO | | Silk | GPIO |
|---|---|---|---|---|
| D0/RX | 44 | | D10 | 21 |
| D1/TX | 43 | | D11 | 38 |
| D2 | 5 | | D12 | 47 |
| D3 | 6 | | **D13 / LED** | **48** |
| D4 | 7 | | A0 | 1 |
| D5 | 8 | | A1 | 2 |
| D6 | 9 | | A2 | 3 |
| D7 | 10 | | A3 | 4 |
| D8 | 17 | | A4 / SDA | 11 |
| D9 | 18 | | A5 / SCL | 12 |

The RGB LED is internal-only and **active LOW**: red 46, green 0, blue 45.
Note green sits on **GPIO0** and red on **GPIO46** — the two strapping pins,
which is why shorting B1 to ground lights it green: same wire.

### Flashing — two things that look like failure and are not

**The first esptool call fails.** Espressif documents this for this board: the
first call enters the hardware bootloader but exits with an
`Input/output error`. **Run it again with the same arguments and it works.** On
Windows, re-check the port first — the device re-enumerates between modes
(`2341:0070` → `303a:1001`), so the COM number probably changed.

**After flashing, power-cycle or tap RESET** to leave esptool's flashing mode.

Flash params: `--chip esp32s3 --flash_mode dio --flash_freq 80m --flash_size 16MB`.

### The one real cost: flashing ESPHome kills double-tap recovery

Double-tap-RESET is **not** a bootloader feature. It is a static constructor
compiled into every *Arduino sketch* by the board variant. Once ESPHome or
plain IDF is running, no Arduino code exists to detect the tap, so **that
recovery path is gone.**

It is not a brick — ROM download mode lives in mask ROM and no firmware can
remove it. The way back in is **short B1 to GND, press RST, release the jumper**
(LED goes purple). Arduino documents restoring the bootloader from there:
*Tools > Programmer > Esptool*, **Burn Bootloader**, then *Upload Using
Programmer*. Budget a jumper wire, not a panic.

⚠️ Some early boards have **green and blue swapped**, so recovery mode shows
blue rather than green and bootloader mode yellow rather than purple. Check the
colour against the board before concluding it failed to switch modes.

### ESP-NOW interop with the C3s

The API is identical — `espnow-c` needs no source changes for S3, only
`idf.py set-target esp32s3` and a fix to `sdkconfig.defaults`, which hardcodes
`CONFIG_ESPTOOLPY_FLASHSIZE_4MB=y` (wrong here; use a separate build dir).

Interop is decided by **ESP-NOW version, not chip**. Both are v2 on this IDF, and
v1/v2 mixes still work for payloads under the 250-byte v1 limit. **Stay under
250 bytes and the chip mix is a non-issue.**
