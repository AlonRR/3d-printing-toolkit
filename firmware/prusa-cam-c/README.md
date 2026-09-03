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

## Milestone 1 — PASSED

Measured on the bench, 1 Sep 2026:

```
adopting: RGB565 VGA PSRAM fb2
frame 640x480  614400 bytes            <- exactly 640x480x2
JPEG 31631 bytes (software encoded, SOI ok)
DHT 11: 28.2 C  64.4 %RH               <- GPIO20
free heap 7471723                      <- identical across every cycle
```

The 28.2 °C is cross-checked against a **separate device**: the printer's own heatbed sensor read
26.9–27.3 °C at the same time, so a DHT sitting beside warm electronics reading about a degree
higher is right. An internally-consistent number proves nothing on its own.

640x480 RGB565 captured, compressed to a valid ~20 KB JPEG on the CPU in roughly 570 ms. The free
heap is byte-identical cycle after cycle, which is the check that matters for a camera loop: a
leaked frame buffer exhausts a fixed pool and presents as a *hang* minutes later rather than as an
error.

## The approach — prove the hardware, no network

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

**`GPIO20`** — see `board_pins.h` for why not 47. Free of every camera pin. The driver is bit-banged here
rather than pulled in as a component — the protocol is ~80 lines and every library available brings
either an Arduino dependency or a conflicting IDF pin.

It distinguishes three outcomes deliberately, because they mean different things:

| Log | Meaning |
|---|---|
| `DHT 11: 24.0 C  41.0 %RH` | working |
| `DHT no response on GPIO20` | nothing wired to the pin |
| `DHT checksum failed` | **wired and responding**, but the frame was corrupted |

A timeout and a checksum failure are very different problems, and collapsing them into one "sensor
error" is how a wiring question gets mistaken for a timing bug.

Wiring, KY-015 module: `−` → GND, `+` → 3V3, `S` → **GPIO20**.

⚠️ **A passing checksum with absurd values is a DECODE bug, not a wiring fault.** This bit once:
the sensor reported 742.5 °C and 1715.7 %RH with the checksum *passing*, which meant all 40 bits
had arrived intact and only the interpretation was wrong. The part is distinguished by physical
plausibility rather than by assuming a DHT11 leaves its fractional bytes at zero — modern DHT11s
send tenths, and that assumption produced exactly those numbers.

## Benchmark — how fast can it capture, and how fast can it send

VGA RGB565. Two runs; the second adds TCP/WiFi buffer tuning and a 240 MHz CPU.
Both ends of every transfer measured independently and agreed to two decimals.

| | run 1 (−27 dBm) | run 2, tuned (−65 dBm) |
|---|---|---|
| **1. capture only** | 5.6 fps · 3.25 MB/s | **5.6 fps** · 3.25 MB/s |
| **2. software JPEG** | 589 ms/frame · 1.7 fps ceiling | **401 ms** · 2.5 fps ceiling |
| **3. radio only** | 0.19 MB/s | **0.18 MB/s** |
| **4a. pipeline RAW** | 0.65 fps | 0.32 fps |
| **4b. pipeline JPEG** | 1.53 fps | **2.36 fps** |

### The three numbers that matter

**5.6 fps is the capture ceiling** at VGA and nothing downstream can beat it. Unchanged between
runs, so it is sensor/DMA-bound, not CPU-bound — the 240 MHz clock did not move it at all.

**240 MHz cut the software encode by a third**, 589 → 401 ms. That is the one tuning change that
clearly worked.

**Throughput is capped at ~0.19 MB/s by the network, not by this board.** Three independent facts
say so:

- It did not change across a **38 dB** signal difference (−27 → −65 dBm). If RF were the limit,
  that swing would dominate.
- Raising the TCP window from 5760 to 65534 bytes changed nothing.
- workstation reaches the server at a much higher rate over the wire, and routing to the board goes out the
  LAN adapter, not the VPN — so the receiver and the PC's network stack are not the constraint.

### What the cap actually is — two hypotheses tested and refuted

**Refuted 1: a per-SSID bandwidth limit on the AP.** The network is a the router vendor the mesh router + 2× X60,
WiFi 6 hardware whose standard firmware offers QoS *prioritisation*, not hard per-SSID caps.

**Refuted 2: the PSRAM-to-internal copy on the WiFi TX path.** The ESP32 cannot DMA out of external
RAM, so sending from PSRAM costs a copy — a plausible fixed cost insensitive to signal. Measured
directly, same size, same socket, same link:

| buffer source | MB/s |
|---|---|
| PSRAM | 0.05 |
| internal RAM | 0.06 |

Identical. Not the cause.

**⚠️ And the reasoning that pointed at the network was itself wrong.** The argument was "throughput
did not change across 38 dB of signal, so RF is not the limit". **RSSI measures signal, not noise.**
A strong signal on a congested 2.4 GHz channel still yields poor SNR and heavy retransmission, which
looks exactly like this: low throughput, flat across RSSI, immune to TCP tuning and to memory
source. Insensitivity to RSSI rules out *path loss*, not *interference*.

**What the data actually shows** is throughput scaling with write size:

| write size | MB/s |
|---|---|
| 32 KB | 0.05–0.06 |
| 64 KB | 0.10–0.19 |
| 614 KB | 0.15–0.38 |

That is the signature of a link losing airtime to contention and retries, where bigger writes
amortise the loss better. Consistent with a busy 2.4 GHz band — three a mesh nodes beaconing, mesh
backhaul, and neighbouring networks.

⚠️ **Enabling 5 GHz on the IoT SSID would not help**: the ESP32-S3 has no 5 GHz radio (2.4 GHz
802.11 b/g/n only), and a combined-band SSID makes 2.4-only devices harder to onboard. What might
help is a clear 2.4 GHz channel at 20 MHz, and checking which a mesh node the board associates with —
a client on a satellite shares airtime with the wireless backhaul.

**Calibration:** an ESP32 tops out near 1–2.5 MB/s of TCP even in ideal conditions. It is not a fast
WiFi device, so the realistic headroom here is about 10×, not 100×.

### Therefore: keep the software JPEG

At the measured link speed **JPEG beats raw by 7×** — 2.36 fps against 0.32 — because the payload
is 20× smaller (30 KB against 614 KB) and that dwarfs the 401 ms encode.

This refutes the intuition that compression is unnecessary when power does not matter. It would be
right if the link were fast; it is not, because the link is the bottleneck. The crossover is
computable — raw gives `link/614400` fps, JPEG gives `1/(0.401 + 30631/link)` — and they are equal
at **~1.4 MB/s**. Below that JPEG wins; above it raw does. The link is currently 0.19 MB/s, about
7× short.

Note the counter-intuitive consequence: making the encoder *faster* moves the break-even **up**,
because it makes JPEG better. 240 MHz shifted it from ~0.95 to ~1.4 MB/s.

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

## Reaching it once it is mounted — name, not address

The board answers to **`prusa-cam.local`**, and that is not a convenience. OTA here is a **push**:
the developer machine POSTs firmware *to* the board, so something has to know where the board is.
Nothing else does — MQTT and the Prusa Connect upload are both **outbound**, so they keep working
perfectly from any address and would never reveal that the DHCP lease had moved. The failure is
silent right up until the day an update is needed. It has already moved once in practice, `.120` to
`.127` between two checks on the same day.

Once the board is cased and mounted on the printer there is no serial console left to ask, so a
moved lease would mean unscrewing it to recover. Hence a name, set three ways in `wifi.c`:

| Mechanism | Gives you |
|---|---|
| `esp_netif_set_hostname()` | a named DHCP lease, so the router lists `prusa-cam` and a reservation is easy to make |
| `mdns_hostname_set()` | `prusa-cam.local` resolves from the workstation |
| `mdns_service_add(_http._tcp)` | discoverable by service when the name is not known |

⚠️ **mDNS is link-local multicast and does NOT cross a subnet or a VLAN.** It resolves today only
because workstation (`192.0.2.106`) and the board sit on the same `/24`. Putting the IoT network behind
the the firewall on its own VLAN is a planned project, and that change would silently break name
resolution from the workstation. **A DHCP reservation on the router is the belt to this braces** —
it survives segmentation, a flash erase, and this firmware being replaced entirely.

The hostname is set *before* the interface starts, because it travels as DHCP option 12 in the lease
request itself. Set it afterwards and the router has already recorded an anonymous client.

## Verifying an OTA push — the sha, never the timestamp

```
curl -X POST --data-binary @build/prusa_cam_c.bin      -H "X-OTA-Key: <ota_password>" http://prusa-cam.local/ota
curl http://prusa-cam.local/          # read back what is actually running
```

⛔ **`built:` does not change between builds and must not be used to confirm an update landed.**
The app description's date and time come from compiling `esp_app_desc.c`, and ccache reuses that
object across rebuilds. Measured: four successive OTA pushes of genuinely different binaries all
reported `Sep  3 2026 19:55:05`. Anyone checking that field would conclude the push had failed —
and reflash a board that was already correct.

✅ **`sha:` is the honest indicator.** It is the first 8 bytes of `app_elf_sha256`, which changes
whenever the ELF does. Compare it with the local build:

```
xxd -s 176 -l 8 -p build/prusa_cam_c.bin     # 176 = 0x20 image header + 144 into esp_app_desc
```

Verified end to end, 3 Sep 2026: pushed by name, client got `HTTP 200 ok, rebooting`, partition
flipped `ota_1 -> ota_0`, and the running sha `b26031f66edc1627` matched the local binary exactly.

**A `ConnectionResetError` on push is not necessarily a failure.** The board reboots immediately
after replying, and on a weak link the reset outruns the response — the update has still applied.
`ota_handler` now sends `Connection: close` and calls `httpd_sess_trigger_close()` before the
2 s delay so the reply lands deterministically rather than depending on signal strength, but if you
ever do see a reset, **read the sha back before concluding anything**. The transfer itself is
signal-bound: 67 s at -72 dBm, 5 s at -26 dBm, for the same 1.18 MB.

## Rollback — the net for an image that boots and then dies

`CONFIG_BOOTLOADER_APP_ROLLBACK_ENABLE=y`, and it is not optional for a board nobody can reach.

Without it, a pushed image that passes validation and **boots** but then crashes before it can serve
— a camera-init hang, a WiFi regression — is permanent. It comes up, dies, and never offers an OTA
endpoint to push a fix to. The only recovery is a USB cable, which means unscrewing a camera from
inside a printer enclosure. Note that image *corruption* was never the risk here; the bootloader's
structural check always catches that. The uncovered case was the one that is structurally perfect
and behaviourally broken.

With it, a freshly pushed image boots as **`PENDING_VERIFY`** and only becomes permanent when
`esp_ota_mark_app_valid_cancel_rollback()` runs — which `ota_start()` calls *after* WiFi is up and
the OTA endpoint is serving. An image that cannot get that far is rolled back to the previous slot
on the next reset, automatically. "This build works" is therefore defined as "it can be updated
again", which is the only definition that matters remotely.

⚠️ **This is a BOOTLOADER option, and OTA does not replace the bootloader.** It can only ever be
enabled over USB, so it had to be turned on before the board was mounted — afterwards is too late.

`ota_start()` logs the state on every boot, because a config flag in a file is not evidence:

```
I (8455) ota: image state on boot: PENDING_VERIFY (rollback armed)   <- after an OTA push
I (8446) ota: image state on boot: VALID                             <- after a USB flash
```

Verified 3 Sep 2026: pushed by name, `HTTP 200`, rebooted into `ota_1`, reported `PENDING_VERIFY`,
then marked valid on reaching the OTA endpoint.

## The build script is in the repo

`build-cam.ps1` — run it with an optional COM port to flash as well:

```
powershell -NoProfile -ExecutionPolicy Bypass -File build-cam.ps1 COM9
```

It encodes the ESPHome-provisioned IDF cache paths, the unified `xtensa-esp-elf` PATH fix described
above, and a guard so `set-target` does not wipe the build directory on every run. It is committed
rather than kept in a scratchpad because none of that is recoverable from prose. An occasional
`internal compiler error: Segmentation fault` from the toolchain is transient — re-run it.

## Roadmap

`camera.c`, `dht11.c` and `main.c` are separate from the start so phase 2 drops in without touching
capture:

- **Snapshot → Prusa Connect** via `POST /c/snapshot` with `Token` + `Fingerprint` headers — the
  only officially supported Connect API.
- **Publish the DHT reading**, to MQTT (`mqtt.internal.example`, already carrying the chamber work) or as
  plain-text HTTP endpoints in the style Prusa's own firmware uses.

⚠️ Prusa's firmware does **not** send its DHT reading to Connect — checked in `connect.cpp` and
`exif.cpp`. Anything wanting that temperature in Home Assistant has to publish it itself.

## The colour cast — five hypotheses tested, all refuted

Structure is flawless in every capture format; only colour is wrong. Each attempt below was
measured, not argued, and each is recorded so none gets repeated.

| # | hypothesis | result |
|---|---|---|
| 1 | RGB565 byte-order swap | **far worse** — `frame2jpg` already swaps; the second swap undid it |
| 2 | sensor auto-WB / gamma / lens correction | no visible change |
| 3 | grey-world correction in software | cast moved teal → green, not removed |
| 4 | YUV422 capture (separate register path) | a *different* cast, still wrong |
| 5 | one-byte phase offset in the parallel capture | **refuted** — see below |

### The data path is exonerated end to end

**Layout** — correlating the channel planes across candidate decodes scored the true layout at
**0.925** against 0.229. The layout was right from the first snapshot.

**Phase** — every offset × byte-order combination, scored on a real frame:

| candidate | saturation | chroma zigzag |
|---|---|---|
| offset 0, as-stored | 0.683 | 0.4651 |
| **offset 0, swapped** (in use) | **0.473** | **0.0774** |
| offset 1, as-stored | 0.474 | 0.0848 |
| offset 1, swapped | 0.683 | 0.4721 |

The **zigzag** metric was built for this: it measures how much *chroma* changes between adjacent
pixels, with luminance divided out so brightness edges don't count. A half-pixel latch error makes
neighbouring pixels take colour from each other's bytes, so hue alternates violently while
structure stays smooth — the 0.47 rows. The decode in use scores best on both metrics.

⚠️ **A trap worth recording:** an apparently clean *greyscale* image, produced by taking every
second byte, briefly looked like proof the sensor was emitting YUV422. It wasn't. With the bytes
swapped, every even byte is `RRRRRGGG` — that picture was the **red channel**, which naturally
resembles a plausible monochrome photo.

**Driver** — esp32-camera **2.1.7**, the current release, and `sensors/ov3660.c` is byte-identical
to upstream master. There is no version to move to.

### ⛔ Reflowing the ESP32-S3 would not help

It is also the wrong chip: **JPEG compression happens inside the OV3660 module**, not the S3. And
the connections are already proven — raw capture succeeds at VGA, QVGA *and* QQVGA, exercising all
eight data lines plus `VSYNC`, `HREF` and `PCLK`, while SCCB covers `SIOD`/`SIOC`. A bad joint
corrupts structure; structure is perfect in every format.

### What remains is optical — check this before writing more code

A missing or wrong **IR-cut filter** produces exactly this: a strong, spatially smooth, consistent
cast that no decoding change affects, because the light reaching the sensor is already wrong. Cheap
modules often omit it. Two checks, neither needing a build:

- **Look at the lens** — a proper IR-cut filter is visible as blue-green tinted glass behind the
  barrel.
- **Daylight vs incandescent** — an infrared problem shifts dramatically between them; a data
  problem does not.

The JPEG fault is then plausibly a separate, internal DSP problem in the module, which the software
encoder already works around at 2.4 fps.
