# Chamber sensor

Knowing what the air inside the printer's Lack enclosure actually does — the chamber air, the
electronics bay, and the room — so the enclosure can be closed up for ASA without cooking the Einsy.
It is step 5 of [asa-print-quality.md](asa-print-quality.md), the last and largest item there.

These notes began as a design on 30 Aug 2026 and grew into a record of what was built and measured.
They are split into the topic pages below; this page says where things stand and where to look.

## Where it stands — 3 Oct 2026

- **In service since 11 Sep 2026:** [`firmware/chamber-c3.yaml`](../firmware/chamber-c3.yaml) — an
  ESP32-C3-MINI-1 board with an AHT20+BMP280, measuring the chamber air (point A) and pressure, on
  ESPHome over MQTT. Its history continues on the `sensor.print_chamber_chamber_*` entities. It
  replaced the ESP32-S3 camera node, which went to the cell-tester project
  ([the migration](chamber-sensor/s3-to-c3-migration.md)).
- **Planned:** `firmware/print-chamber.yaml`, in the **print-chamber-box** repository — an ESP32-C3
  SuperMini carrying the SPS30 particle sensor and the SGP41 VOC/NOx sensor now, with the fume-fan
  control to join it later on pins already reserved. Decided 1 Oct 2026; until those
  move, `chamber-c3.yaml` stays the live chamber node. Its enclosure, in the same repository,
  hangs outside the printer's enclosure. **A second, identical box inside the chamber is possible, not decided** (Alon,
  3 Oct 2026): there are two of each sensor, and it would pair with the chamber's air filter, but
  the chamber runs close to the sensors' temperature ratings and needs more thinking first. The
  outside box is built first.
- **The enclosure has been closed for every print since 19 Sep 2026.** Measured since
  ([the measurements](chamber-sensor/measurements.md)): PETG prints hold the chamber about **12 °C**
  over the room; **an ASA print reached 45–46 °C**, inside the 40–60 °C ASA band, on bed heat alone.
  Earlier: the electronics bay read **50–51 °C** on 9 Sep with the box nearly closed, about 9.5 °C
  below the ~60 °C trouble figure; and the box cools within about an hour after a print.
- **No separate bay or room probes** (Alon, 3 Oct 2026). The C3 in the chamber covers the chamber
  air, and the room is the guest bedroom's climate unit — the printer's own room. The bay is read from
  the Einsy's own thermistor, at the printer: the LCD's `Support → Temperatures`, or `M105`'s `A:`.
  The trade-off: no remote bay series, and no bay input for an automatic fan interlock, which the
  safety rule below assumed.
- **Not done yet:** **a bay reading with the box closed during an ASA print** — the most important
  open number, since on the 9 Sep offset the bay would be near 56 °C — and the fan interlock
  ([the build order](chamber-sensor/build.md)).

## Decisions that hold across the pages

- **Three measurements, not one:** chamber air, electronics bay, room. The bay is the one that
  justifies the project. Since 3 Oct 2026 only the chamber has a sensor of its own; the room comes
  from the guest bedroom's unit and the bay from the Einsy's thermistor. ([Sensors](chamber-sensor/sensors.md))
- **The node goes outside the enclosure; only the probes go in**, on short leads, hung in free air.
  ([The node](chamber-sensor/node-design.md))
- **Safety logic runs on the device; Home Assistant gets convenience logic.** A missing bay reading
  must run the fan. ([The node](chamber-sensor/node-design.md#safety-logic-runs-on-the-device-7))
- **Recirculate and extract at once, at slight negative pressure** — decided 4 Sep 2026.
  ([Chamber heat](chamber-sensor/heating-and-airflow.md))
- **The C3 SuperMinis need the antenna mod, or a board with a real antenna.**
  ([The antenna](chamber-sensor/supermini-antenna.md))
- **For every node:** key a `unique_id` to the thing measured, never the board — and when a node
  retires, clear its retained MQTT discovery, which outlives both the device and its registry
  entry. ([The migration](chamber-sensor/s3-to-c3-migration.md))

## The pages

| Page | What it covers |
|---|---|
| [Sensors](chamber-sensor/sensors.md) | the three measurement points, which sensor for each, what is owned, what the node in service measures, and the SPS30 |
| [Measurements](chamber-sensor/measurements.md) | the chamber and bay temperatures so far, how fast the box cools, and the seam in the long-term graph |
| [The node](chamber-sensor/node-design.md) | outside the enclosure, the pin map, power, sensor placement, and safety on the device |
| [Build](chamber-sensor/build.md) | the ESPHome skeleton for the full node, and the build order with where it stands |
| [Chamber heat](chamber-sensor/heating-and-airflow.md) | fume extraction against a warm chamber, the negative-pressure decision, and why no heater yet |
| [WiFi](chamber-sensor/wifi.md) | which network an ESP32 can join here, and the nightly midnight event |
| [The SuperMini antenna](chamber-sensor/supermini-antenna.md) | why the SuperMinis barely transmit, the 31 mm wire mod, and what it measured |
| [Boards](chamber-sensor/boards.md) | the board pairing that works, the console-port trap, and the Arduino Nano ESP32 as a bench reference |
| [The S3-to-C3 migration](chamber-sensor/s3-to-c3-migration.md) | moving the live node to a new board without losing its history |
| [The S3's disconnect counter](chamber-sensor/s3-disconnect-counter.md) | a counter that corrupted Home Assistant's statistics, its fix, and how to read a counter out of flash |

Related: [chamber-airflow.md](chamber-airflow.md) is the build plan for the fume filter and
extraction that [Chamber heat](chamber-sensor/heating-and-airflow.md) decides.

## The old section numbers

Other notes, firmware comments and repositories cite this page by section number. Each now lives here:

| Cited as | Now |
|---|---|
| §1 | [Sensors — three measurements, not one](chamber-sensor/sensors.md#three-measurements-not-one-1) |
| §2 | [Sensors](chamber-sensor/sensors.md) |
| §3 | [The node goes outside the enclosure](chamber-sensor/node-design.md#the-node-goes-outside-the-enclosure-3) |
| §3a | [WiFi — which network](chamber-sensor/wifi.md#which-wifi-network-3a) |
| §3w | [Boards — the Arduino Nano ESP32](chamber-sensor/boards.md#the-arduino-nano-esp32-as-the-bench-reference-3w) |
| §3x | [The SuperMini antenna — the 31 mm wire mod](chamber-sensor/supermini-antenna.md#rescuing-them-the-31-mm-wire-mod-3x) |
| §3y | [Boards — the pairing that works](chamber-sensor/boards.md#the-pairing-that-works-3y) |
| §3z | [The SuperMini antenna — the root cause](chamber-sensor/supermini-antenna.md#the-root-cause-the-superminis-barely-transmit-3z) |
| §4 | [The node — pin map](chamber-sensor/node-design.md#pin-map--esp32-c3-supermini-4) |
| §5 | [The node — power](chamber-sensor/node-design.md#power--and-the-converter-trap-5) |
| §6 | [The node — placement](chamber-sensor/node-design.md#placement--where-most-of-the-error-comes-from-6) |
| §7 | [The node — safety on the device](chamber-sensor/node-design.md#safety-logic-runs-on-the-device-7) |
| §8 | [Chamber heat](chamber-sensor/heating-and-airflow.md) |
| §9 | [Build — the ESPHome skeleton](chamber-sensor/build.md#esphome-skeleton-9) |
| §10, "build order step N" | [Build — the build order](chamber-sensor/build.md#build-order-10) |
| §11 | [Reading a counter out of flash](chamber-sensor/s3-disconnect-counter.md#reading-a-persisted-counter-out-of-flash--the-method-11) |
| "THE S3 IS LEAVING", "WHAT MUST NOT BE LOST" | [The S3-to-C3 migration](chamber-sensor/s3-to-c3-migration.md) |

## Where this lives

The design is here because the reason for it is ASA print quality. Once it is built, the firmware,
the MQTT topics and the HA automations belong in **`alon/homelab`**, next to
`docs/manual/fume-fan-esp32.md` and `print-station.md`, which already own the print-station
hardware. This page should then shrink to a pointer rather than being copied — a drifted copy of a
wiring diagram is worse than no diagram.
