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
  broker: 192.0.2.22
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

⚠️ **ESPHome renamed the 1-Wire components.** Before 2024.6 it is `dallas:` with
`platform: dallas`; after, `one_wire:` with `platform: dallas_temp`. Check which your version
wants — the old spelling fails with a confusing schema error rather than a clear one.

---

## 10. Build order

1. **DHT11 on a breadboard, node on USB, no enclosure changes.** Get a number for the chamber as
   it is today, with the side open. This is the baseline everything else is measured against and
   it costs nothing.
2. **Partially close the open side. Measure again.** If the delta is small, the whole chamber
   theory is weaker than assumed and that is worth knowing before buying anything.
3. **Buy the AHT20 + 2× DS18B20**, build points A/B/C properly, node outside, probes inside.
4. **Wire the interlock and prove it** — heat the bay probe with a hairdryer and watch the fan
   start without HA involved. A safety feature that has never been *seen* to fire is not a safety
   feature.
5. **Only then** close the side fully and run a long ASA print with all three temperatures
   logging to Grafana.
6. **Then** revisit chamber heating. The 12 V 50 W PTC heater is owned and earmarked for the
   enclosure, but 50 W is modest for a Lack-sized volume and it needs **> 4 A at 12 V**, which the
   PD trigger board cannot supply. That is a separate power design, not a bolt-on.

Steps 1 and 2 need nothing bought and answer the question that decides whether the rest is worth
doing.

---

## Where this lives

The design is here because the reason for it is ASA print quality. Once it is built, the firmware,
the MQTT topics and the HA automations belong in **`alon/homelab`**, next to
`docs/manual/fume-fan-esp32.md` and `print-station.md`, which already own the print-station
hardware. This page should then shrink to a pointer rather than being copied — a drifted copy of a
wiring diagram is worse than no diagram.
