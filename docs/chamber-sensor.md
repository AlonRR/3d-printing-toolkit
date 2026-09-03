# Chamber sensor — design

Designed 30 Aug 2026. **Nothing built.** This is the design for step 5 of
[asa-print-quality.md](asa-print-quality.md), the last and largest item: knowing what the air
inside the Lack enclosure is actually doing, so the open side can be closed without cooking the
Einsy.

Grounded in hardware that exists: the ESP32-C3 Super Minis in the drawer, the conventions in
`Tools/mcu-workflow` (`examples/board-c3.yml`), and the fume-fan node described in
`alon/homelab` → `docs/manual/fume-fan-esp32.md`, which is **also still unbuilt**. That is
convenient rather than awkward: one node can do both jobs, and designing them together avoids
building the wrong one twice.

---

## 1. It is three measurements, not one

The instinct is "put a thermometer in the box." That answers the least important question.

| # | Point | Why | Range needed | Accuracy needed |
|---|---|---|---|---|
| **A** | **Chamber air** | The variable that controls warping and layer bonding. Target **40–50 °C** | to ~60 °C | ±1 °C |
| **B** | **Electronics bay** | The thing that can be *damaged*. Einsy trouble starts around **60 °C**; the printer's own `TMC DRIVER OVERTEMP` is the last-resort guard | to ~100 °C | ±2 °C is fine |
| **C** | Room ambient | The reference. "Chamber is 42 °C" means nothing without "room is 24 °C" — the **delta** is what says whether the enclosure is working | to ~50 °C | ±2 °C |

**B is the one that justifies the project.** A is what you want; B is what lets you chase A
without risking hardware. A design with only A is the one that ends with a dead board.

---

## 2. Sensors

### The DHT11 problem — 10 owned, and still not the right part

`CLAUDE.md` and `print-station.md` both point at the ten DHT11s as the reason this project is
unblocked. They are enough to *start* and not enough to *finish*:

- **Range 0–50 °C.** The chamber target is 40–50 °C, so the sensor saturates exactly where the
  reading gets interesting. It cannot say whether you reached 45 or 55.
- **±2 °C, 1 °C resolution, ~1 Hz.** Against a 20 °C delta that is fine; against "is the chamber
  at its target" it is not.
- **It cannot do point B at all.** The threshold that matters there is 60 °C, above its range.

So the DHT11 is the **probe for the first experiment**, not the sensor for the build. It answers
one question well — *does closing the open side move the chamber at all?* — because 24 → 42 °C
is a signal no amount of ±2 °C can hide.

### What to actually build with

| Point | Part | Bus | Why this one |
|---|---|---|---|
| **A** chamber | **AHT20** (or SHT31) | I2C | −40 to +85 °C, ±0.3 °C, and it gives **humidity** too — which is free information about what the chamber is doing to an open spool of hygroscopic ASA. SHT31 if you want ±0.2 °C and 125 °C range |
| **B** bay | **DS18B20** | 1-Wire | 125 °C range, and — the real reason — **1-Wire tolerates metres of cable.** The bay is a ~1 m run from wherever the node lives. I2C is not a long-cable bus and will fail intermittently, which is the worst way for a safety sensor to fail |
| **C** room | **DS18B20** | same 1-Wire bus | 1-Wire is multi-drop: point C costs **one extra part and zero extra GPIOs** |

### What is actually owned — checked, 30 Aug 2026

The homelab session ran this against HomeBox (209 entities) and the AliExpress, a second marketplace and
Adafruit order histories rather than anyone's memory:

| Part | Verdict |
|---|---|
| **DS18B20 ×2** | ❌ **Not owned — the only genuine gap.** Absent from HomeBox and from every order history. Needs buying |
| Point A, chamber | ✅ **BME688, owned and free** (Adafruit PID 5046) — −40–85 °C ±1.0, RH ±3 %, plus pressure and gas. Its HomeBox record reads "THIS IS THE DRYBOX SENSOR", but **the drybox was never built** (Alon, 30 Aug 2026), so it is unallocated. Use it |
| Point A, alternative | ⏳ An **AHT20 + BMP280 is inbound** (a ~₪5 part). No longer needed for this — keep it for the drybox if that project ever starts |
| Pull-up resistor | ✅ **Not a purchase.** The ELEGOO assortment on hand has no 4.7 k but does have **5K1 ×10**, and 5.1 kΩ is a fine 1-Wire pull-up. Count the compartment rather than trusting the label — an M3×12 box labelled 20 once held 2 |

**So the whole design costs two DS18B20s.** Everything else — the board, the chamber sensor, the
pull-up, the fan, the power converter — is on the shelf.

The BME688's gas sensor is a bonus nobody asked for and it is genuinely useful here: it responds
to VOCs, which is a crude but real proxy for *"is the enclosure full of ASA fumes"*. That makes
it a second, independent input to the same fume-extraction decision the fan is already making.
Do not read it as a calibrated air-quality number — it is an index, and it needs a burn-in
period before it means anything.

A **BME280** would also serve point A and is the example device in
`mcu-workflow/examples/board-c3.yml` (`0x76`, `i2c0`); the pressure reading is of no use here.

### What the printer already has — and why it does not remove the DS18B20

Worth knowing before buying anything, because two of the obvious ideas are already half-built.

**✅ The Einsy has an ambient thermistor, and it is physically point B.** An NTC sits on the
board itself, just above the main power connector, and Prusa firmware has read it since 3.9.1 —
it raises `AMBIENT_MINTEMP` / `AMBIENT_MAXTEMP` at −30 °C and 100 °C. Because it is *on the
board*, it heats when the board heats, which is [a known complaint about calling it
"ambient"](https://github.com/prusa3d/Prusa-Firmware/issues/2441) — and is exactly the property
point B wants. It is not a room sensor; it is a board sensor with a misleading name.

Two reasons it does not delete the bay DS18B20:

1. **Its guard is useless for this.** `AMBIENT_MAXTEMP` fires at **100 °C**. The drivers are in
   trouble around 60. The firmware protection that actually matters is `TMC DRIVER OVERTEMP`,
   and by then the print is already aborting — which is the outcome the interlock exists to
   prevent, not a substitute for it.
2. **Reading it means routing safety through the network.** Printer → PrusaLink → HA → MQTT →
   ESP32 is precisely the chain §7 says a safety interlock must not depend on. An independent
   probe wired to the node keeps the interlock working when all of that is down.

So treat it as a **free second opinion**: two independent measurements of the same bay, from
different sensors on different paths, which is how you find out that one of them is lying.

⚠️ **Unverified: whether PrusaLink exposes the value at all.** The firmware reads it and the
LCD shows it; whether it appears in PrusaLink's JSON is untested here, and cannot be tested
right now because [the stored API key is dead](../README.md) (open item 8). Check that before
building anything on it.

**✅ T1 is a free thermistor input.** On the MK3S the three jacks are T0 = hotend, T2 = heatbed,
**T1 unused**. So the board could physically read a chamber probe — but **stock Prusa firmware
has no chamber-temperature feature**, so using it means a custom firmware build. That trades
PrusaLink support and painless updates for a number an ESP32 gives you for free. Not worth it.

### 📏 FIRST CHAMBER MEASUREMENT — 31 °C mid-print, 3 Sep 2026

The S3 camera node with its DHT11 was placed in the enclosure during a live print. Over a 40 s
sample it read **31.2–31.3 °C and 37.2–37.6 %RH**, flat rather than still climbing, so this is a
plateau and not a mid-warmup number.

⚠️ **THE DOOR WAS ALSO OPEN. This is NOT a measurement of the enclosure.** The first version of this
entry read it as "one side deliberately open reaches 31 °C, so the open side costs 10–20 °C" — that
conclusion is **withdrawn**, because it was never a measurement of the normal configuration. With
the permanent open side *and* the door open, this is very nearly an unenclosed printer, and 31 °C is
about what a bed at print temperature does to the air near an open machine.

**So what this number actually establishes is a BASELINE, not a verdict** — and a baseline is worth
having, because it is the control the closed-up measurement gets compared against. It says: with the
box effectively open, the chamber sits ~5 °C over room ambient. Whatever closing it buys is measured
from here.

**Step 2 of the build order is therefore still outstanding.** It asks for the temperature with the
enclosure *closed*, and that run has not happened.

Consequences that do hold regardless:

- **The reading is biased HIGH, so any enclosure conclusion drawn from it is doubly unsafe.** The DHT11 sits
  on the same PCB as an ESP32-S3 running WiFi and a camera continuously, and self-heating lifts it.
  True chamber air is likely a degree or two below the figure. Same error class as putting the
  camera's sensor inside its own sealed case.
- **Do not read "31.2" as precision.** The DHT11 is ±2 °C with 1 °C resolution, so this is 31 ± 2.
  It is entirely adequate for "is the chamber warm" — which is the question being asked — and
  inadequate for characterising a 40–60 °C ASA chamber, which is the question that comes next.
- **Record the CONFIGURATION with every future reading.** This entry had to be corrected within the
  hour because the number was written down without noting that the door was open, and a chamber
  temperature without its configuration is not a datum — it is a number that will be misread later
  by someone who assumes the box was shut.

⚠️ **The DHT11 tops out at 50 °C.** It has ample headroom at 31, but if the side is closed and the
chamber is pushed toward ASA temperatures the sensor will approach and then clip its own range. The
upgrade decision arrives at the same moment the enclosure starts working.

**Incidental but useful: WiFi reaches inside the enclosure.** The node stayed reachable by name from
workstation and kept publishing throughout, which closes an open question about coverage at the printer.

### On a chamber heater — not yet, and the reasons are not just cost

Asked and answered here so it does not get re-opened from scratch:

- **The bed is already the heater.** At 105–110 °C it is a ~200 W source *inside* the box. A
  properly closed enclosure usually reaches 40–50 °C on bed heat alone — which is the target.
  Close it and measure before assuming a heater is needed; that measurement is step 2 of the
  build order and costs nothing.
- **A heater makes the Einsy problem worse, not better.** The board is inside the enclosure, and
  its stepper drivers and bed MOSFET have thermal pads bonded to the case — case temperature
  couples straight into the parts that throttle. Every watt added to the chamber lands partly on
  the thing point B is watching.
- **There is no spare heater output on the Einsy.** E0 and BED are both used, so a chamber heater
  is externally controlled hardware regardless.
- **A heater needs hardware over-temperature protection, not software.** A stuck MOSFET or a
  crashed ESP32 with a heating element latched on is a fire, and no amount of ESPHome prevents
  it. That means a thermal cutout or thermal fuse physically in series with the element. It is a
  different class of build from a sensor node, and it is why this is a separate project rather
  than a bolt-on.
- The **12 V 50 W PTC** is no longer owned by this project (reallocated to the drybox, 3 Sep 2026), and a replacement would still need **> 4 A at 12 V**, which the PD trigger board cannot
  supply, and 50 W is modest for a Lack-sized volume.

**Order of operations: close the side, measure, and only then ask whether heat is missing.**


---

## 3. Put the node *outside* the enclosure

Only the probes go inside. Reasons, in order:

1. **The node would be sitting in the thing it is measuring.** An ESP32-C3 is happy at 50 °C, but
   the buck converter and any electrolytics next to it are less happy, and their lifetime is the
   quiet cost.
2. **The USB port has to stay reachable** for the first flash and for recovery. (OTA covers the
   rest.)
3. **Wi-Fi out of the box** rather than through it.
4. A 30 cm I2C run at 100 kHz is trivial; 1-Wire to the bay is trivial at a metre.

---

## ⛔ 3z. THE ROOT CAUSE: the C3 SuperMini boards barely transmit

**Read this before anything else on this page.** It invalidates several
conclusions below and explains an entire night of WiFi debugging.

The two ESP32-C3 **SuperMini** boards this project was built on have the known
defective PCB antenna. They **receive perfectly and transmit almost nothing.**

Measured 1 Sep 2026. Three boards, same plain-C ESP-NOW binary, all on one desk:
two SuperMinis and one board built around an **ESP32-C3-MINI-1** module, which
has a proper shielded antenna.

```
SuperMini-A   RX 30 bytes from aa:bb:cc:dd:ee:01 : PING 22 ...
SuperMini-B   RX 30 bytes from aa:bb:cc:dd:ee:01 : PING 22 ...
MINI-1        (nothing, ever)
```

`aa:bb:cc:dd:ee:01` is the MINI-1. **Both SuperMinis hear it flawlessly, every
ping. It hears neither of them. And they never hear each other** — every
received frame in the capture came from the MINI-1.

### Why this was so hard to see

**`TX SUCCESS` is not evidence of radio.** ESP-NOW's send callback reports that
the MAC layer accepted the frame. A detuned antenna radiates almost nothing
while the MAC stays perfectly happy, and on an *unacknowledged broadcast* there
is no feedback path at all. Both SuperMinis reported `TX SUCCESS` every two
seconds for hours while being effectively mute.

Everything that looked like healthy configuration — matching channels, matching
protocol versions, registered peers, components initialising — was true and
irrelevant. **Initialising is not transmitting**, and nothing in the stack
measures radiated power.

### It probably explains the WiFi failures too

A board that hears well but shouts weakly, talking to an access point, produces
exactly the pattern that consumed the night of 31 Aug:

| Symptom | Explanation |
|---|---|
| Full signal bars | It hears the AP's beacons fine. Receive works |
| `Auth Expired` / `Handshake Failed` | The AP cannot reliably hear *its* replies, so the handshake times out |
| Intermittent, per-radio, self-clearing | A marginal link budget that only sometimes closes |
| Unaffected by moving the boards | Both ends were already close; the deficit is radiated power, not distance |

So **the "hostile mesh" theory in §3a was wrong.** Setting the IoT SSID to
WPA2-only did genuinely help — but it removed one obstacle from a link that was
already crippled at the transmitter.

### What to build on

- ✅ **The ESP32-C3-MINI-1 board**, or the **Arduino Nano ESP32** (u-blox
  NORA-W106). Both have real module antennas.
- ❌ **Not the SuperMinis.** Keep them for anything that does not need to be
  heard — USB-attached sensors, bench toys, HIL rig duty where a cable carries
  the data.

### Conclusions this overturns

- Blaming ESPHome's `espnow` component (commit `a925e7d`) — already retracted in
  `7ec50a9`; this identifies the actual cause.
- Calling both radios "provably healthy" (commit `d839179`) because both ends
  initialised and agreed on channel and version. They agreed about everything
  except whether any RF was leaving the board, which nothing measured.


---

## ✅ 3y. The pairing that works

Proven 1 Sep 2026, and it is just §3z's finding applied: **give the transmitting
job to the board that radiates, and the receiving job to the boards that only
listen well.**

| Role | Board | Port | Firmware |
|---|---|---|---|
| Sender + DHT11 | ESP32-C3-**MINI-1** | `COM8` on workstation | `firmware/chamber-sensor-mini1.yaml` |
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

### Still expected, not a fault

The hub logs `no data from sensor yet` and the sender logs
`no reading - check wiring`, because **the DHT11 is still wired to a
SuperMini.** The transport is proven; move the sensor to `GPIO4` on the MINI-1
(KY-015: minus to GND, plus to 3V3, S to GPIO4) and real readings flow.

---

## 3x. Rescuing the SuperMinis — the 31 mm wire mod

There are 10 C3s here, so it is worth knowing they are repairable. **Optional:
the link above already works without it.**

### Why the board is bad

Espressif's own [C3 PCB layout
guidelines](https://docs.espressif.com/projects/esp-hardware-design-guidelines/en/latest/esp32c3/pcb-layout-design.html)
require **at least 15 mm clearance in all directions** around the antenna, a CLC
matching network, and USB/UART lines kept far away. The SuperMini is about
22 by 18 mm with a USB-C connector millimetres from the antenna. It cannot
satisfy any of them. Reported on top of that: two of the three matching-network
capacitor pads left unpopulated, and some batches with the ceramic antenna
mounted backwards.

**The corroborating symptom is heat.** Two independent observers measured these
boards running hotter than other C3s, one confirming the chip temperature
*dropped* after the mod. That points at reflected power being dissipated in the
die — a **mismatch**, not merely a weak antenna.

### The mod

One piece of **31 mm** of **1.0 mm** wire (about 18 AWG):

- **16 mm** wound into a roughly **8 mm** loop (around a 5 mm drill shank), ends
  spread to reach both chip-antenna pads — the chip antenna itself completes the
  last quarter of the circle.
- **15 mm** continuing straight up from the second pad.
- **Leave the stock ceramic antenna in place.** Tested better that way than
  removed.
- If the board has a visible ~4 mm feed trace before the antenna, use **27 mm**
  instead — the 4 mm difference matters.

**⚠️ The one step that breaks boards: the loop must start on the FEED pad.**
Do **not** trust the white stripe on the ceramic — documented photos show the
same part mounted in opposite orientations on different boards. **Ohm it out:**
the feed pad has continuity to an ESP32 pin, the other pad reads open to
everything. Thirty seconds, and it removes the single most common failure.

### Measure it honestly

**Do not measure at 5 cm.** At 2.4 GHz that is about 0.4 wavelengths — inside
the reactive near-field, where two mismatched antennas couple in ways that
ignore path loss. Read RSSI **from the far end** (the AP, or the MINI-1) at
several metres through a wall, and keep **one unmodified board as a permanent
control**. Every trustworthy number in the literature came from that method.

Expect **+10 to +17 dB**. Then accept the ceiling: the best-documented A/B put a
*modded* SuperMini at -45 dBm where a properly laid-out C3 read -33 dBm on the
same desk. The mod recovers most of the defect; **it does not make the board
good.**

### Known ways it goes wrong

Several people report WiFi going *dead* after the mod, or the board raising RSSI
yet refusing to associate. The fallback is a different topology — remove the
ceramic antenna and fit about **62 mm** end-fed on the feed pad — and the
reported lengths for it genuinely conflict (32 mm also worked for one person),
because nobody has resolved it with a VNA. Do the reversible 31 mm version
first; removing the ceramic antenna is **not** reversible without a spare.

The other real risk is mechanical: the vertical wire snagging has torn the
ceramic antenna off a board along with its traces. Strain-relieve it where it
leaves any enclosure, and keep §3z's keep-out in mind — do not bury a modded C3
next to the fan, the PD board, or metal.


---

## 3w. The Arduino Nano ESP32 as the bench reference

When a result is ambiguous, the question is always *is the board lying to me?*
§3z is what happens when nothing on the bench can answer that. The **Arduino
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

### ⚠️ The one real cost: flashing ESPHome kills double-tap recovery

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


---

## 3a. Which WiFi network — this cost an evening, so it is written down

Two facts about this house's networks decide where the node can live, and neither
is discoverable from the ESP32's error messages.

### `HomeNet` (the main SSID) is permanently impossible for this hardware

It runs **WPA3-Personal with GCMP-256**. ESP32 radios implement **CCMP only** —
GCMP is not a setting being refused, it is a cipher the silicon does not have. The
node reports `Authentication Failed` and `Handshake Failed`, which look exactly
like a wrong password and are not.

Ruled the password out properly rather than by assertion: Windows had a stored
profile for that SSID, and its key matched `secrets.yaml` byte for byte, case
sensitive. Same length, identical string, still refused. **Do not spend time
retyping the password for this network** — no ESP32 will ever join it.

### `HomeNet_IoT` works, but only since it was set to WPA2-only

It was **WPA/WPA2 mixed**, offering TKIP alongside AES. That was the root cause of
an evening of the node working for ~17 minutes, then being refused by every radio
for ~17 minutes, then recovering on its own with nothing changed at either end.
Mixed mode lets a client end up on deprecated TKIP, and the resulting failures are
intermittent, per-AP, self-clearing and completely unaffected by signal strength —
which is what made them look like a temporary client ban.

**Alon set that SSID to WPA2-only on 31 Aug 2026 and the node then associated
first time, with no scan-and-fail across the three mesh radios.**

Diagnoses tried and discarded before that, all wrong, listed so nobody repeats
them: dead power supply, a wedged TCP stack, a mesh rate-limiting the client, and
WPA2/WPA3 transition mode. The right *class* of answer — cipher negotiation on a
mixed-mode SSID — arrived last, and the fix was one router setting rather than
anything in this repo. `fast_connect: true` was also tried and **made it strictly
worse**: it skips the scan, so the node only ever retries the remembered AP and
never falls back when that one is the one refusing.

### Two habits that follow from this

- **Address the node by `chamber-baseline.local`, not by IP.** It came back from
  the WPA2 change on a new DHCP lease — `.100` instead of `.103` — and every port
  check against the old address failed while the node was perfectly healthy. The
  logger takes a hostname for this reason.
- **Never trust ping here.** During these failures ICMP answered while all three
  TCP ports refused, and later ICMP failed while all three were open. The serial
  log and a TCP port check are the only signals worth acting on.


---

## 4. Pin map — ESP32-C3 Super Mini

Constraints taken from `mcu-workflow/examples/board-c3.yml` and the fume-fan page, not invented:
**GPIO8 = onboard LED (active-LOW), GPIO9 = BOOT strap, GPIO20/21 = UART0, ADC is limited to
GPIO0–GPIO4, and GPIO2/8/9 are strapping pins.**

⛔ **And one that is documented nowhere in the repo: on the ESP32-C3, GPIO18 and GPIO19 are the
native USB D−/D+ lines.** These boards flash and log over native USB-Serial/JTAG, so wiring
anything to 18 or 19 takes out flashing and the console. It fails *silently, at the bench, after
the hardware is wired* — unlike a wrong `board:`, which fails loudly at build time.

This is not hypothetical. `alon/homelab` → `docs/manual/fume-fan-esp32.md` still specifies
`GPIO18` for fan PWM and `GPIO19` for tach: its `board:` was corrected from `esp32dev` to
`esp32-c3-devkitm-1` on 21 Aug 2026 and **the pin numbers underneath were never revisited**.
Reported by the homelab session, 30 Aug 2026. The GPIO10/GPIO3 below is the correction, not a
rival convention.

`board-c3.yml` names LED, BOOT, UART0 and JTAG and stops — it does not mention 18/19 either, so
anyone deriving a pin map from this lab's own repos would not learn this. That is a gap in
`mcu-workflow`, not only in the fume-fan page.

| GPIO | Use | Note |
|---|---|---|
| **5** | I2C SDA | The house convention from `board-c3.yml` |
| **6** | I2C SCL | " |
| **7** | 1-Wire (both DS18B20s) | Needs a pull-up to 3.3 V. 4.7 kΩ is the usual value; **5.1 kΩ works fine** and homelab reports the ELEGOO assortment on hand has `5K1` but no 4.7 k — so this is probably not a purchase |
| **10** | Fan PWM out | 25 kHz LEDC, to fan pin 4 |
| **3** | Fan tach in | `INPUT_PULLUP`, fan pin 3. Chosen over GPIO2 because **GPIO2 is a strapping pin** and must be high at boot |
| 8 | Status LED | Onboard, active-low |
| 9 | BOOT | Leave alone |
| 20/21 | UART0 | Leave alone |
| 0, 1, 2, 4 | free | The only ADC-capable pins, kept free in case an analog sensor shows up |

`board-c3.yml` puts I2C on 5/6 while noting GPIO4–7 are the JTAG pins. That is a deliberate
trade — JTAG only matters if you are debugging over JTAG, and this node flashes over native USB.
Worth knowing before someone tries to attach a debugger and finds the bus in the way.

---

## 5. Power — and the converter trap

Reuse the fume-fan's 12 V PD rail so there is one supply, not two.

⛔ **Do not reach for the TPS63020 modules.** Ten are owned and they are the obvious grab, but
their input range is **1.8–5.5 V**. Feeding one 12 V destroys it.

✅ **Use the S09 buck-boost — `2.5–15 V in → 3.3 V out`** (owned, one unit). It is the only
converter in the drawer that accepts 12 V.

Wiring: S09 output → the C3's **3V3 pin** (this bypasses the onboard LDO), grounds common between
the PD board, the fan and the node. **Do not leave the S09 connected while flashing over USB** —
5 V through the LDO meets 3.3 V from the S09 at the same node. In practice this only matters for
the first flash, since everything after is OTA.

For bring-up, skip all of that and run the node off a USB charger. Prove the sensors first, add
the shared rail later.

---

## 6. Placement — where most of the error comes from

**Chamber probe (A).** Mid-height, hung in free air on its own wires. **Not** above the bed, where
it reads radiant heat rather than air; **not** in the part-cooling fan's exhaust; **not** touching
the frame, which conducts. If it reads high whenever the bed is hot but the print is going fine,
it is seeing the bed — add a small printed baffle between probe and bed.

**Bay probe (B).** Against the Einsy's case or near the driver heatsinks, inside the electronics
box, in still air. The TO-92 DS18B20 taped down is fine; the stainless-probe version is easier to
wedge and easier to route.

**Room probe (C).** Outside the enclosure, away from the printer's own exhaust and out of sunlight.

---

## 7. The architecture decision that matters

> **Safety logic runs on the ESP32. Convenience logic runs in Home Assistant.**

The bay-temperature interlock must fire when Wi-Fi is down, when the broker is restarting, and
when the HA container is being updated. If it lives in an HA automation, it is not a safety
feature — it is a notification that happens to usually work.

So:

- **On the device:** bay temp above threshold → run the fan, regardless of what HA wants. With
  hysteresis, and with a **fail-safe: if the bay sensor stops reporting, run the fan anyway.** A
  1-Wire sensor that falls off the bus publishes nothing, and "no reading" must not read as "not
  hot."
- **In HA:** logging to InfluxDB/Grafana, the print-start/cooldown choreography off the PrusaLink
  enum sensor, a "chamber up to temperature" gate before starting an ASA print, notifications.

Escalation ladder for point B: **> 50 °C** vent, **> 55 °C** notify, **> 60 °C** the printer's own
`TMC DRIVER OVERTEMP` stops the print. The sensor exists so the third rung never happens.

---

## 8. The conflict nobody has written down yet: extraction vs chamber heat

The fume project and the chamber project pull in opposite directions. **An extractor fan pulls
warm air out of the enclosure — which is precisely what ASA needs kept in.** Build both naively
and the fume fan will fight every degree the closed side gains.

The resolution is already in the parts drawer. The **Bento box** design (models in
`OneDrive\3D printing\usefull\Bento box 120mm fan.3mf`, plus the HEPA filter paper and the
120 mm 12 V PWM fan, all owned) is a **recirculating** filter: it pulls chamber air through
HEPA + carbon and returns it *to the chamber*. It cleans the air without exporting the heat.

So:

- **During the print:** recirculating filter on. Fumes handled, chamber stays hot.
- **After the print / on a bay-temperature interlock:** that is when you want actual extraction,
  or simply the enclosure opened.

This is worth settling before either build starts, because it decides whether the 120 mm fan
blows *through a filter into the chamber* or *out of a duct* — a mechanical decision that is
expensive to reverse.

⚠️ **A recirculate-only build closes a door you may want open.** Acetone is ruled out here
until the filtration system runs in its extract-to-outside mode
([fdm-design-rules §6a](fdm-design-rules.md#6a-joining-two-printed-parts)). A design that can
*only* recirculate keeps ASA solvent welding and vapour smoothing permanently unavailable — a
bigger consequence than it looks while drawing ducts.

## ✅ DECIDED, 4 Sep 2026 — recirculate AND extract, at negative pressure

**Alon's ruling, and it is a third option neither this page nor the homelab page considered:** during
a print, run the recirculating filter **and** a small continuous extraction, sized so the chamber
sits slightly **below room pressure**.

**Why this is better than either thing that was being argued.** The recirculate-only proposal below
cleans the chamber air but does nothing about *leakage* — a Lack enclosure is not airtight, and fumes
escape through every gap regardless of how clean the air inside is. Extract-only exports the chamber
heat that [asa-print-quality](asa-print-quality.md) is trying to build. Negative pressure resolves
both at once, and it is the principle fume hoods, biosafety cabinets and cleanrooms all run on:
**below ambient, every leak flows INWARD.** The enclosure no longer has to be sealed to contain
fumes — it only has to be closed enough that a modest extraction can hold the differential.

### What it requires

- ⚠️ **The enclosure must actually be closed.** This is the one hard prerequisite. With a side
  permanently open there is no differential to hold — the flow required scales with the leakage area,
  and an open side is not leakage, it is a duct. This converges neatly with build-order step 2, which
  already wanted the box closed and measured.
- **Give it a DEFINED makeup-air inlet.** Do not rely on incidental gaps. A deliberate opening of
  known area makes the inward flow predictable and lets the extraction be sized against something,
  instead of against the sum of every unknown seam.
- **A duct to somewhere that is not the room.** Extraction that vents indoors is recirculation with
  extra steps.

### The number that matters is face velocity, not pressure

Containment is achieved when air moves **inward** through the opening faster than fumes can drift
out — fume-hood practice is about **0.5 m/s** at the face. Since Q = v × A, a *small* defined inlet
makes this cheap: a 10 × 10 cm inlet at 0.5 m/s is only ~18 m³/h, far below what any 120 mm fan
moves. **The small inlet is what makes the small extraction sufficient**, which is also why the
makeup air costs little chamber heat.

### It changes the mechanical design — two fans, and NO damper

The proposal below was one fan with a switchable outlet. Running both modes *simultaneously* means
two independent air paths:

| Path | Flow | Fan |
|---|---|---|
| Recirculation | high | the owned 120 mm axial, through HEPA + carbon, back into the chamber |
| Extraction | low, continuous | a **separate small fan** to the outside duct |

⚠️ **Do not use a second axial PC fan for the extraction leg.** This page already records that a
120 mm axial produces only tens of pascals; a duct run needs static pressure, not free-air flow. The
extraction leg wants a small **radial/blower** type, which trades flow for pressure — exactly the
opposite of what the recirculation leg wants.

**This simplifies the controller rather than complicating it.** There is no damper servo and no mode
switching: both fans simply run during a print. Extraction can very likely be a fixed rate set once
mechanically, since the differential is a property of fixed geometry, not something that needs a
closed loop.

### Verifying it — a tissue, not a sensor

Hold a strip of tissue at the inlet: it should be drawn **in**. That is the whole test, and it is
more trustworthy here than instrumentation.

⛔ **Do not try to measure this with the BMP280.** The differential is a few pascals. The BMP280's
*absolute* accuracy is ±100 Pa, and a differential built from two of them would have one sensor at
50 °C chamber and the other at room temperature, with temperature-dependent offset swamping the
signal. This is a case where the cheap physical test is not a shortcut — it is the better instrument.

### One consequence worth banking

A recirculate-only build was recorded below as closing the door on ASA solvent welding and vapour
smoothing, which need real extraction. **This design keeps that door open**, since an extract path
now exists — turn the extraction up for solvent work rather than rebuilding for it.

**Proposed design, and it is a change of plan, not a reading of the existing one:** recirculate
during the print, vent afterwards. One fan, one filter, a switchable outlet — a damper or a
movable duct — decided now rather than reprinted later.

⚠️ **Every existing document says extraction, and none of them treats recirculation as an
option.** The homelab page is titled *Fume extractor*; `CLAUDE.md` says *"Filter project (fume
extractor)"*. Flagged by the homelab session on 30 Aug 2026, and they are right that it has to be
settled before parts are printed. **This section argues for a change; it does not record a
decision.** Until Alon rules on it, the documented plan is extraction, and the reason to consider
recirculating at all is that an extractor removes the very chamber heat
[asa-print-quality.md](asa-print-quality.md) is trying to build up.

### Why you do not need a second filter in the exhaust duct

The instinct is to put filtration *in front of* the extraction, so nothing dirty leaves the
house. It is the right instinct and it is already satisfied, in series over time rather than in
series along the duct: **the recirculating loop cleans the same air repeatedly for the whole
print, so what the vent later releases has already been through HEPA and carbon many times.**
Adding a second filter in the duct filters air that is already filtered.

There is also a hard engineering reason not to put a filter in the duct. **A 120 mm axial PC
fan produces very little static pressure** — tens of pascals — and a HEPA element needs far
more than that. Push one through the other and airflow collapses to almost nothing, quietly:
the fan still spins, so it looks like it is working. Filter-in-duct wants a **centrifugal
blower**, not the axial fan already owned. The Bento box gets away with an axial fan precisely
because its filter area is large, which keeps face velocity and therefore pressure drop low.

And for the solvent case specifically, a carbon tray buys little: **activated carbon adsorbs
acetone poorly and saturates fast**, then desorbs it later. Acetone is also, as solvents go, an
unusually mild environmental release — the US EPA
[removed it from the VOC definition in 1995](https://www.epa.gov/sites/default/files/2015-07/documents/orgchem.pdf)
(60 FR 31633) on the grounds of negligible photochemical reactivity, meaning it contributes
essentially nothing to ground-level ozone, and it biodegrades readily.

So: **filter hard where the real hazard is — the ultrafine particles and styrene from printing
ASA and ABS — and keep the vent path simple.**

---

## 9. ESPHome skeleton

Untested — no firmware exists for this node or the fume fan. GPIO numbers match §4; the DS18B20
addresses must be read off the bus on first boot (ESPHome logs them).

```yaml
esphome:
  name: print-chamber
  friendly_name: Print Chamber

esp32:
  board: esp32-c3-devkitm-1
  variant: esp32c3
  framework:
    type: arduino

logger:
  # C3 Super Mini logs over native USB-Serial/JTAG, not a UART bridge.
  hardware_uart: USB_SERIAL_JTAG

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password

mqtt:
  # The name, not 192.0.2.22 - Home Assistant's own MQTT integration is
  # configured against this name, so the two agree by construction.
  broker: mqtt.internal.example
  port: 1883
  username: esp
  password: !secret mqtt_esp_password
  topic_prefix: printer
  # Don't hardcode topics elsewhere - ESPHome publishes HA discovery, so drive
  # the resulting entities by name. Same lesson as the fume-fan page.

i2c:
  sda: GPIO5
  scl: GPIO6
  frequency: 100kHz        # down from the rig's 400 kHz for a ~30 cm cable run

one_wire:
  - platform: gpio
    pin: GPIO7             # 4.7k pull-up to 3V3 required

output:
  - platform: ledc
    pin: GPIO10
    id: fan_pwm
    frequency: 25000Hz

fan:
  - platform: speed
    output: fan_pwm
    id: chamber_fan
    name: "Chamber fan"

sensor:
  - platform: aht10
    variant: AHT20
    temperature:
      name: "Chamber temperature"
      id: chamber_temp
    humidity:
      name: "Chamber humidity"
    update_interval: 10s

  - platform: dallas_temp
    address: 0x0000000000000000      # <- read the real address from the boot log
    name: "Electronics bay temperature"
    id: bay_temp
    update_interval: 10s
    on_value_range:
      - above: 50.0
        then: [fan.turn_on: {id: chamber_fan, speed: 100}]
      - below: 45.0
        then: [fan.turn_off: {id: chamber_fan}]

  - platform: dallas_temp
    address: 0x0000000000000000
    name: "Room temperature"
    update_interval: 30s

  - platform: pulse_counter
    pin:
      number: GPIO3
      mode: INPUT_PULLUP
    name: "Chamber fan RPM"
    unit_of_measurement: RPM
    filters:
      - multiply: 0.5      # most 4-pin fans emit 2 pulses per revolution

binary_sensor:
  - platform: template
    name: "Chamber up to temperature"
    lambda: 'return id(chamber_temp).state > 40.0;'

# FAIL-SAFE: no reading must never read as "not hot".
interval:
  - interval: 30s
    then:
      - if:
          condition:
            lambda: 'return isnan(id(bay_temp).state);'
          then:
            - fan.turn_on: {id: chamber_fan, speed: 100}
            - logger.log: "bay sensor unavailable - venting as a precaution"
```

✅ **Settled: ESPHome 2026.8.1 is installed** (via `uv tool install esphome`, 30 Aug 2026), so
the modern spelling above is the right one — `one_wire:` with `platform: dallas_temp`. The old
`dallas:` / `platform: dallas` form was renamed in 2024.6 and now fails with a confusing schema
error rather than a clear one, so do not copy it from an older tutorial.

---

## 10. Build order

1. ✅ **RIG WORKING, 30 Aug 2026.** DHT11 on a C3 Super Mini, flashed over COM4, reading
   `chamber 27.1 C  RH 39 %` on the bench — which matches room temperature, so the sensor is
   sane. Board, firmware, sensor and wiring are all proven; what remains is the measurement.
   Two observations worth keeping: it reports in **0.5 °C steps**, better than the DHT11's
   nominal 1 °C resolution, but **the ±2 °C accuracy is unchanged** — do not read meaning into
   small movements. And the `no reading` warning fired correctly while the sensor was miswired,
   which is the fail-safe doing its job: a dead sensor announces itself instead of going quiet.

   **DHT11 on a breadboard, node on USB, no enclosure changes.** Get a number for the chamber as
   it is today, with the side open. This is the baseline everything else is measured against and
   it costs nothing.
   ✅ **Ready to run:** [`firmware/chamber-baseline.yaml`](../firmware/chamber-baseline.yaml),
   **built and flashable**. Wiring is in its header; DHT11 on GPIO4, chosen so it does not collide with
   the final pin map in §4. ESPHome 2026.8.1 via `uv tool install esphome`; compiles to 11.4 %
   flash / 16.6 % RAM on a C3, which also settles that `dht` builds under ESP-IDF there.
   ⛔ **Build and flash from PowerShell, not git-bash** — PlatformIO will not install ESP-IDF under
   MSYS (*"MSys/Mingw is not supported"*). **Unsetting `MSYSTEM` is not enough; tried, same
   failure.** `esphome config` passes from either shell, so it surfaces only at compile time.
2. **Partially close the open side. Measure again.** If the delta is small, the whole chamber
   theory is weaker than assumed and that is worth knowing before buying anything.
3. **Buy the AHT20 + 2× DS18B20**, build points A/B/C properly, node outside, probes inside.
4. **Wire the interlock and prove it** — heat the bay probe with a hairdryer and watch the fan
   start without HA involved. A safety feature that has never been *seen* to fire is not a safety
   feature.
5. **Only then** close the side fully and run a long ASA print with all three temperatures
   logging to Grafana.
6. **Then** revisit chamber heating — and note the element is **no longer here**. The 12 V 50 W
   PTC was **reallocated to the active drybox on 3 Sep 2026** by Alon's decision, precisely because
   this step is deferred behind steps 1-5 while 10 kg of PETG absorbs humidity now. See
   [drybox-active.md](drybox-active.md). Reviving chamber heating therefore starts with buying a
   second element (₪39), which is cheap and was judged better than cannibalising a working build.
   The rest of the objection stands regardless: 50 W is modest for a Lack-sized volume, it needs
   **> 4 A at 12 V** which the PD trigger board cannot supply, and it needs a hardware thermal
   cutout. That is a separate power design, not a bolt-on.

Steps 1 and 2 need nothing bought and answer the question that decides whether the rest is worth
doing.

---

## Where this lives

The design is here because the reason for it is ASA print quality. Once it is built, the firmware,
the MQTT topics and the HA automations belong in **`alon/homelab`**, next to
`docs/manual/fume-fan-esp32.md` and `print-station.md`, which already own the print-station
hardware. This page should then shrink to a pointer rather than being copied — a drifted copy of a
wiring diagram is worse than no diagram.
