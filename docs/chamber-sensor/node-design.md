# The node — where it goes, its pins, power, placement and safety (§3–§7)

*Part of the [chamber sensor](../chamber-sensor.md) notes.*

**In short:**

- **The node goes outside the enclosure; only the probes go in.** It keeps the electronics out of
  the heat and fumes, the USB port reachable, and the WiFi out of the box.
- **Pins:** I2C on 5/6, 1-Wire on 7 (its bay and room probes are not planned since 3 Oct 2026),
  fan PWM on 10 and tach on 3. **Never GPIO18/19 on a C3** —
  they are native USB.
- **Power:** off the fume fan's 12 V rail through the **S09 buck-boost**, never the TPS63020s,
  which a 12 V input destroys.
- **Placement causes most of the error.** A sensor on the node's own board reads warm and dry —
  biased toward "the chamber is fine". Hang the chamber probe in free air on a short lead.
- **Safety logic runs on the device, convenience logic in Home Assistant.** The bay interlock must
  work with WiFi, the broker and HA all down, and a missing bay reading must run the fan.

## The node goes outside the enclosure (§3)

Only the probes go inside. Reasons, in order:

1. **The node would be sitting in the thing it is measuring.** An ESP32-C3 is happy at 50 °C, but
   the buck converter and any electrolytics next to it are less happy, and their lifetime is the
   quiet cost.
2. **The USB port has to stay reachable** for the first flash and for recovery. (OTA covers the
   rest.)
3. **Wi-Fi out of the box** rather than through it.
4. A 30 cm I2C run at 100 kHz is trivial; 1-Wire to the bay is trivial at a metre.

## Pin map — ESP32-C3 SuperMini (§4)

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
Reported 30 Aug 2026. The GPIO10/GPIO3 below is the correction, not a
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

## Power — and the converter trap (§5)

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

## Placement — where most of the error comes from (§6)

**Chamber probe (A).** Mid-height, hung in free air on its own wires. **Not** above the bed, where
it reads radiant heat rather than air; **not** in the part-cooling fan's exhaust; **not** touching
the frame, which conducts. If it reads high whenever the bed is hot but the print is going fine,
it is seeing the bed — add a small printed baffle between probe and bed.

### Never on the node's own PCB — the bias points at the answer

**Measured, 3–4 Sep 2026.** The DHT11 riding on the S3 camera board reported 31.2 °C / 37.2 %RH in
the chamber. Self-heating from an ESP32 running WiFi and a camera continuously means **both figures
are wrong in the same direction**: a sensing element hotter than the air it samples over-reads
temperature *and* under-reads RH, because RH is measured against saturation at the **element's**
temperature, not the air's.

| Self-heat | A true 48 %RH air reads |
|---|---|
| +1 °C | 45.3 % |
| +2 °C | 42.8 % |
| +3 °C | 40.4 % |

⚠️ **This is why the error is dangerous rather than merely annoying: warmer-and-drier is exactly the
reading that says "the chamber is fine, no heater needed, ASA will print".** The single measurement
this whole project exists to make — *does the closed enclosure get hot enough* — is biased toward
answering "yes" by the very sensor taking it. A random ±2 °C would average out; a **directional**
bias never does, and it points at the conclusion.

**The AHT20 does not fix this by being a better part.** It shrinks the error, it does not remove it:
mount an AHT20 on a node PCB beside a WiFi radio and it inherits the same bias, just smaller.
**Placement is the fix, not the part number.**

### The wiring conflict this creates, and the resolution

The requirements pull against each other:

- [The sensor choice](sensors.md#what-to-build-with) puts the **bay** probe on **1-Wire** specifically because *"I²C is not a long-cable bus and will
  fail intermittently, which is the worst way for a safety sensor to fail"*.
- Placement requires the **chamber** probe to hang **in free air, away from everything** — and now, away
  from the node as well.
- But the chamber probe is **I²C** (AHT20), so "far enough to avoid self-heating" and "close enough
  for reliable I²C" appear to be in tension.

✅ **They are not, once the node moves.** The conflict only exists if the node is assumed to be inside
the chamber. **Mount the node on the OUTSIDE of the enclosure wall and run a short I²C tail through
it to the sensor hanging inside.**

- The I²C run stays **short** — 20–30 cm, which [the node-outside rule](#the-node-goes-outside-the-enclosure-3) already calls trivial at 100 kHz — so the
  long-cable objection never arises.
- The node's own heat is dumped **outside the chamber entirely**, which is strictly better than
  moving it to a far corner inside.
- It suits the rest of the design: the controller's other job is the fans, which live at the filter
  and extraction points on the chamber wall, not in the middle of the print volume.
- It also keeps the electronics out of a hot, ASA-fume-laden box, which is its own win.

**So: node outside, sensor inside on a short tail, in free air.** Neither giving up humidity for
1-Wire nor calibrating out an offset is necessary — and the second was never attractive, since it
needs a trusted reference that does not exist yet.

**Bay probe (B).** Against the Einsy's case or near the driver heatsinks, inside the electronics
box, in still air. The TO-92 DS18B20 taped down is fine; the stainless-probe version is easier to
wedge and easier to route.

**Room probe (C).** Outside the enclosure, away from the printer's own exhaust and out of sunlight.

## Safety logic runs on the device (§7)

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
