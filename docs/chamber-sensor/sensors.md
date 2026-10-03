# Sensors — what each point needs (§1, §2)

*Part of the [chamber sensor](../chamber-sensor.md) notes.*

**In short:**

- **Decided 3 Oct 2026: no DS18B20 probes** (Alon). The chamber air is the C3's AHT20; the room is
  the guest bedroom's climate unit — the printer's room; the bay is the Einsy's own thermistor, read
  at the printer. The design below, and its case for a separate bay probe, is the reasoning that
  decision weighed.
- **Three points, not one:** chamber air (A), the electronics bay (B), and the room (C). The bay is the
  one that justifies the project — it is what can be damaged.
- **As designed — chamber air: an AHT20 or similar on I2C. Bay and room: DS18B20s on one 1-Wire bus**, because
  1-Wire tolerates a metre of cable and I2C does not.
- **The DHT11s are a first-experiment probe, not the build sensor:** they stop at 50 °C and 20 %RH.
- The Einsy's own ambient thermistor is physically point B and a free second opinion, but not a
  substitute for an independent probe on the node.
- **The node in service measures point A** (AHT20), pressure (BMP280), and its own link. The SPS30
  could join it electrically; its 60 °C ceiling and its other claimant were the obstacles.

## Three measurements, not one (§1)

The instinct is "put a thermometer in the box." That answers the least important question.

| # | Point | Why | Range needed | Accuracy needed |
|---|---|---|---|---|
| **A** | **Chamber air** | The variable that controls warping and layer bonding. Target **40–50 °C** | to ~60 °C | ±1 °C |
| **B** | **Electronics bay** | The thing that can be *damaged*. Einsy trouble starts around **60 °C**; the printer's own `TMC DRIVER OVERTEMP` is the last-resort guard | to ~100 °C | ±2 °C is fine |
| **C** | Room ambient | The reference. "Chamber is 42 °C" means nothing without "room is 24 °C" — the **delta** is what says whether the enclosure is working | to ~50 °C | ±2 °C |

**B is the one that justifies the project.** A is what you want; B is what lets you chase A
without risking hardware. A design with only A is the one that ends with a dead board.

## The DHT11 problem — ten owned, and still not the right part

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

## What to build with

| Point | Part | Bus | Why this one |
|---|---|---|---|
| **A** chamber | **AHT20** (or SHT31) | I2C | −40 to +85 °C, ±0.3 °C, and it gives **humidity** too — which is free information about what the chamber is doing to an open spool of hygroscopic ASA. SHT31 if you want ±0.2 °C and 125 °C range |
| **B** bay | **DS18B20** | 1-Wire | 125 °C range, and — the real reason — **1-Wire tolerates metres of cable.** The bay is a ~1 m run from wherever the node lives. I2C is not a long-cable bus and will fail intermittently, which is the worst way for a safety sensor to fail |
| **C** room | **DS18B20** | same 1-Wire bus | 1-Wire is multi-drop: point C costs **one extra part and zero extra GPIOs** |

## What is owned — checked 30 Aug 2026

Checked against the parts actually on hand rather than anyone's memory:

| Part | Verdict |
|---|---|
| **DS18B20 ×2** | ❌ **Not owned — the only genuine gap.** Not on hand anywhere. Needs buying |
| Point A, chamber | ✅ **BME688, owned and free** (Adafruit PID 5046) — −40–85 °C ±1.0, RH ±3 %, plus pressure and gas. Its inventory record reads "THIS IS THE DRYBOX SENSOR", but **the drybox was never built** (Alon, 30 Aug 2026), so it is unallocated. Use it |
| Point A, alternative | An **AHT20 + BMP280** is on hand, a ~₪5 part. No longer needed for this — keep it for the drybox if that project ever starts |
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

## What the printer already has — and why it does not replace the DS18B20

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
   ESP32 is precisely the chain [the safety rule](node-design.md#safety-logic-runs-on-the-device-7) says a safety interlock must not depend on. An independent
   probe wired to the node keeps the interlock working when all of that is down.

So treat it as a **free second opinion**: two independent measurements of the same bay, from
different sensors on different paths, which is how you find out that one of them is lying.

⚠️ **Unverified: whether PrusaLink exposes the value at all.** The firmware reads it and the
LCD shows it; whether it appears in PrusaLink's JSON is untested here, and cannot be tested
right now because [the stored API key is dead](../../README.md) (open item 8). Check that before
building anything on it.

**✅ T1 is a free thermistor input.** On the MK3S the three jacks are T0 = hotend, T2 = heatbed,
**T1 unused**. So the board could physically read a chamber probe — but **stock Prusa firmware
has no chamber-temperature feature**, so using it means a custom firmware build. That trades
PrusaLink support and painless updates for a number an ESP32 gives you for free. Not worth it.

## What the installed node measures — and whether the SPS30 can join it

*Asked 12 Sep 2026. The sensor specs below are from the manufacturer datasheet, not assumed.*

### The current complement

| Sensor | Gives | Worth knowing |
|---|---|---|
| **AHT20** | temperature + **relative humidity** | The reason for the swap. 0–100 %RH at 0.1 % resolution — a DHT11 floors at 20 %RH in 1 % steps, and this chamber measured below 20 % in 7.3 % of 22,021 samples |
| **BMP280** | **pressure** + a second temperature die | Pressure is new to the chamber. The second die is a **free cross-check**: two independent sensors reading the same air, where disagreement is itself a signal |
| `wifi_signal` | RSSI | Link diagnostics — the C3 measured min −46 / mean −32.9 against the S3's min −75 / mean −56.5 |
| `wifi_info` | **BSSID** | Which AP the node is on. This is the instrument the midnight re-association investigation runs on |
| `uptime` | seconds since boot | Detects reboots that would otherwise look like a data gap |

⚠️ **There is no disconnect counter on this node.** That was a feature of the S3's hand-written C
firmware; the ESPHome build has no equivalent, which is deliberate — the question it existed to
answer was closed first ([the disconnect counter](s3-disconnect-counter.md)).

### Adding the SPS30 — electrically easy, thermally marginal

The lab owns **two** Sensirion SPS30s (PM1.0 / PM2.5 / PM4 / PM10 mass and number concentration, plus
typical particle size), and two GY-SGP41s — Alon, 3 Oct 2026. These notes said one until then. Adding it to this node is **not blocked by the bus**:

| Check | Result |
|---|---|
| I2C address | **0x69** — no clash with AHT20 (0x38) or BMP280 (0x77) |
| Logic levels | 3.3 V I2C is fine; **no level shifter needed** |
| ESPHome support | native `sps30` platform |
| Bus capacity | the C3's GPIO10/GPIO3 bus has two devices on it; a third is nothing |

⛔ **Three things stood in the way; the third is gone now that there are two:**

1. **It needs a 5 V supply — 4.5–5.5 V, not 3.3 V.** It must come off the board's 5 V pin (present
   when USB-powered, which this node is), never off 3V3. At **45-65 mA** in measurement mode (55 typ), with an **80 mA peak for the first 200 ms** as the fan spins up that is comfortable on
   USB, but it does mean the sensor dies if the node is ever moved to a 3.3 V battery rail.
2. ⚠️ **Its operating ceiling is +60 °C, and that IS the chamber's target.** An ASA chamber is wanted
   at 40–60 °C. Closed, the chamber holds 45–46 °C through an ASA print and peaked at 47.5 °C during a
   bed anneal ([measurements](measurements.md#closed-every-print-since-19-sep-2026)) — in spec, but
   already above the 10–40 °C the SPS30 performs best in, and the whole point of the enclosure work is
   to raise that number further. This is the blocker that matters, and it is a design conflict rather
   than a wiring problem. What happens past the ratings is in
   [the box's design notes](../../models/print-chamber-box/docs/design.md#past-the-ratings).
3. ~~**There is exactly one SPS30 and it is already claimed.**~~ There are two (3 Oct 2026).
   [chamber-airflow](../chamber-airflow.md) wants one to verify the *scrubber* — measuring whether
   particulate actually falls when the fan runs, which a tachometer cannot tell you — and that no
   longer competes with the air-quality use.

⭐ **Verdict: possible, and no longer an allocation question.** Nothing technical prevents it, and
the second unit removed the contention. What remains is the thermal ceiling: the chamber use pushes
a part rated to +60 °C towards +60 °C, and the SGP41 beside it is rated to +50 °C.

⚠️ **Also worth expecting: fouling.** The SPS30 is a laser scattering counter that pulls sample air
across its optics with a fan. In an ASA/ABS chamber the thing it measures is also the thing that
coats it. That is not a reason against — it is a reason to treat its calibration as perishable.
