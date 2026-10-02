# Moving the chamber node from the S3 to a C3 — 11 Sep 2026

*Part of the [chamber sensor](../chamber-sensor.md) notes.*

**In short:**

- **The ESP32-S3 camera node went to the cell-tester project.** Chamber sensing moved to an
  **ESP32-C3-MINI-1 board with an AHT20+BMP280**, on ESPHome:
  [`firmware/chamber-c3.yaml`](../../firmware/chamber-c3.yaml). It has run since 11 Sep 2026.
- **Two rules from it that apply to every node:**
  - **Key a `unique_id` to the thing being measured, never to the board measuring it.** And what
    actually carries Home Assistant's history is the **entity_id**: a new board can be renamed onto
    the old ids, and its statistics continue.
  - **Retained MQTT discovery outlives both the device and its registry entry.** When retiring a
    node, clear its retained discovery topics, or Home Assistant recreates the entities.
- **The long-term graph continues across the change** — with a seam at ~14:30 on 11 Sep that is
  an instrument change, not the chamber ([the measurements](measurements.md)).
- **What went with the S3:** the camera, and the hand-written firmware's disconnect counter.

## Why: the S3 left for the cell-tester project — 11 Sep 2026

**Alon reassigned the ESP32-S3 N16R8 CAM to the cell-tester project**, which needs a camera to read
QR labels off battery cells and has no other board that can. The chamber sensing moves to a **C3
mini** (an interim board, held until the C3 SuperMinis get their antenna fix) carrying the owned
**AHT20+BMP280**.

⚠️ **The inventory did not know this board was in use.** It recorded the S3 against
`cell-tester` and `edge-ai`, with three claimants, and **none of them was 3d-printing** — while the
board was powered, on WiFi, publishing to Home Assistant and serving camera frames. The cell-tester
session asked rather than assuming, which is the only reason it surfaced. *A record proves presence
and never absence*, and this is the cleanest instance of it in the lab so far.

### The S3's sensor was a DHT22 — and the AHT20 still supersedes it

**Measured from 22,020 humidity and 7,070 temperature samples**, rather than read off the parts
list:

| Evidence | Reading | What it means |
|---|---|---|
| Humidity minimum | **9.3 %** | A DHT11 **floors at 20 %** and cannot go here |
| Distribution near the low end | smooth taper, 1→2→3→5→10→20 samples | **No pile-up** — so no clamp |
| Integer-valued humidity | 2,246 of 22,020 | **0.1 % resolution**, not the DHT11's 1 % steps |
| Integer-valued temperature | 798 of 7,070 | **0.1 °C resolution**, not the DHT11's 1 °C steps |

**So the chamber part is a DHT22/AM2302, not a DHT11** — which also explains why `dht11.c` carries
plausibility-based type detection: the two are protocol-compatible and a DHT11 read as a DHT22
decodes 20 °C as 522.4 °C.

**The AHT20 still supersedes it**, just by less than the parts list implied:

| | DHT22 *(what is actually there)* | **AHT20+BMP280** |
|---|---|---|
| RH accuracy | ±2–5 % | **±2 %** |
| Temp accuracy | ±0.5 °C | **±0.3 °C** |
| Interface | single-wire, timing-critical bit-bang | **I2C** — shared bus, no timing to get wrong |
| Pressure | none | **yes**, via the BMP280 |
| Standby | mA-class | sub-µA |

📋 **Keep the DHT on the bench for one overlap period.** Run both briefly and compare against
the existing series — a new sensor validated against a known one is nearly free, and it is the only
cheap way to catch a wiring or scaling error before it silently becomes the record.

### What the chamber loses, stated rather than discovered later

- **The camera.** `/raw`, the Prusa Connect uploader, and any future spaghetti-detection or
  timelapse work. The C3 has no camera interface and 4 MB of flash.
- ✅ **Open item 9c went with the S3 — and was answered before it was reflashed.** The
  persisted-counter fix is **proven**: its NVS partition held `drops = 18` with the complete write
  history and no post-reboot regression ([the disconnect counter](s3-disconnect-counter.md)). The C3's ESPHome build has no equivalent
  counter, so there was never anything to re-prove here — which is exactly why reading it off the S3
  first mattered.
- **Pressure is gained**, which the chamber has never had.

### The same contention could repeat: the AHT20 was the drybox's sensor

**The AHT20+BMP280 is earmarked for the DRYBOX sensor**, chosen specifically
because *"DHT11 floors at 20 %RH and a working drybox is 5–15 %RH"*. There is **one** of them.

Allocating it to the chamber leaves the drybox without the part chosen for it — and the drybox is
the build where the floor argument actually bites, because a working drybox lives below the DHT11's
floor while the chamber does not. **Flagged, not blocked:** Alon has allocated it, and a second
AHT20 is a ~₪5 part. It is recorded here so the drybox build does not discover it at assembly time,
which is exactly how the S3 was nearly lost.

## Keeping the history: what must not be lost

*The rule, as corrected the same day: Home Assistant's long-term statistics are keyed to the
**entity_id**; a `unique_id` only decides which registry entry a device binds to. The first
paragraph below overstated it, and is kept because the correction answers it.*

Five series already hold long-term statistics. **Home Assistant keys entity identity to
`unique_id`, not to topic or device.** If the C3 firmware publishes different ones, HA creates
*new* entities and the existing statistics orphan — they are not deleted, they simply stop being
attached to anything and no longer extend.

| Entity | Statistics rows |
|---|---|
| `sensor.print_chamber_chamber_temperature` | 44 |
| `sensor.print_chamber_chamber_humidity` | 44 |
| `sensor.print_chamber_chamber_wifi_rssi` | 44 |
| `sensor.print_chamber_chamber_wifi_disconnects` | 92 |
| `sensor.print_chamber_chamber_uptime` | 19 |

⚠️ **CORRECTION, same day.** The paragraph above originally said the C3 *must* publish the same
`unique_id`s or the history is lost. That overstated it, and I wrote it before checking what the
statistics are actually keyed to. Measured since:

| | |
|---|---|
| `statistics_meta.statistic_id` | **is the `entity_id`** — confirmed, it matches a `states_meta` row |
| `unique_id` | only decides **which registry entry** the device binds to |

**So the thing to preserve is the ENTITY_ID.** `unique_id` matters only because it is what makes
Home Assistant reuse the existing registry entry, which is what keeps the entity_id the same.

The current unique_ids, read from the registry:

| Entity | `unique_id` |
|---|---|
| `sensor.print_chamber_chamber_temperature` | `chamber_temp` |
| `sensor.print_chamber_chamber_humidity` | `chamber_rh` |
| `sensor.print_chamber_chamber_wifi_rssi` | `chamber_rssi` |
| `sensor.print_chamber_chamber_wifi_disconnects` | `chamber_wifi_drops` |
| `sensor.print_chamber_chamber_uptime` | `chamber_uptime` |

**Two routes, and the second is the safety net that makes this a low-risk migration:**

- ⛔ **Route A — publish the same `unique_id`s. NOT AVAILABLE IN ESPHOME.** Tested against the
  installed 2026.8.1 rather than assumed:

  | Attempt | Result |
  |---|---|
  | per-sensor `unique_id: chamber_temp` | **rejected** — *"invalid option for [sensor.template]"* |
  | per-component `mqtt: {unique_id: ...}` | **rejected** |
  | `mqtt: discovery_unique_id_generator: legacy` | accepted — but it only selects between **built-in schemes**, it does not take a string |

  So an ESPHome build cannot inherit the C firmware's ids. If entity continuity were ever worth
  more than ESPHome's convenience, the alternative is `discovery: false` plus hand-published
  configs — which is what `prusa-cam-c` does, and why *its* ids survive reflashes.
- ✅ **Route B — let it create new entities, then repoint them.** Different unique_ids produce new
  registry entries, whose entity_ids collide and get a `_2` suffix; the statistics stay attached to
  the old ids. **This is repairable in the UI**: delete the old registry entries, then rename the
  new entities to the original entity_ids. Because statistics are keyed by entity_id, they
  reattach.

⭐ **AND THE RULE THAT GENERATED THESE IDS, WHICH MATTERS MORE THAN THE LIST:**

> **Key the `unique_id` to the thing being MEASURED, never to the board measuring it.**

Look at what they are: `chamber_temp`, `chamber_rh`, `chamber_rssi`. **Not** `prusacam_temp`. The
subject is the chamber; the ESP32 is an instrument, and instruments get replaced — this migration
is that happening. Because the ids name the chamber, a board swap is a wiring job rather than a
history-losing event, and that is not luck: it is the only reason Route A is even available here.

⛔ **So do not "tidy" these into board-named ids on the rebuild.** `c3mini_temp` would read as an
improvement, describe the hardware accurately, and silently strand 243 rows of long-term
statistics. A later reader has no way to tell that the old-looking name is load-bearing — which is
why it is written down here rather than left to inference.

📋 **The same rule, stated generally:** an id that lives on the instrument cannot outlive the
instrument. Anything whose history has to survive a hardware change must be named after the subject
of the measurement. *(Arrived at independently by the cell-tester project from the opposite
direction — a cell id has to be physically written on the cell, because an anonymous result cannot
be compared against a run 30 days later. Two routes to one principle.)*

**So a unique_id mismatch costs a tidy-up, not the history** — which is the opposite of what the
first version of this section implied. Keep `state_class` on every numeric sensor either way; that
is the part with no workaround.

## Build path — start from the ESPHome configs, not the C firmware

`prusa-cam-c` is S3-specific: camera driver, octal PSRAM, 16 MB flash. **None of it ports to a C3**,
and it should not be attempted. The chamber already has C3 ESPHome configs from the ESP-NOW work —
[`chamber-sensor-espnow.yaml`](../../firmware/chamber-sensor-espnow.yaml) and
[`chamber-sensor-mini1.yaml`](../../firmware/chamber-sensor-mini1.yaml) — and ESPHome has a native
`aht10` platform (which covers the AHT20) plus `bmp280`. That is the short path.

**C3 pin constraints, which this lab has already been bitten by once:**

| Pin | Why to avoid |
|---|---|
| GPIO2, 8, 9 | **strapping pins** — a sensor here can prevent boot |
| GPIO18, 19 | **native USB** — same class of trap as the S3's GPIO20 |
| ADC2 channels | unusable while WiFi is active |

I2C wants two ordinary pins clear of all of the above.

## Migration checklist

1. Confirm which physical C3 is the interim board, and whether it is one of the 10 SuperMinis or a
   separate mini.
2. ✅ **DECIDED — `SDA = GPIO10`, `SCL = GPIO3`.** Every candidate went through `esphome config`
   rather than being reasoned about: **2, 8, 9** warn as strapping; **18, 19** warn as
   USB-Serial-JTAG; **20, 21** are UART0 and carry the console; **11–17** are internal flash.
   ⭐ **0 and 1 validate CLEAN and were rejected anyway** — they are `XTAL_32K_P`/`XTAL_32K_N`, free
   only if no 32.768 kHz crystal is fitted, and **ESPHome cannot know that, so it cannot warn**.
   A clean validation is not the same as a safe pin. GPIO10 and GPIO3 have no alternate function.
   ⚠️ **Module pin order is VDD, SDA, GND, SCL** — GND sits *between* the bus lines, which is not
   the usual layout. It carries its own pull-ups; add none.
3. ✅ **DONE — [`firmware/chamber-c3.yaml`](../../firmware/chamber-c3.yaml)**, `esphome config`
   valid with zero warnings. **Route B by necessity.** Every numeric sensor declares `state_class`
   explicitly rather than trusting platform defaults; MQTT birth/will carries availability.
   Deliberately no `api:` block — the native API would let the ESPHome integration discover the
   same device a second time and create a duplicate entity set.
4. ⛔ **THE OVERLAP COMPARISON IS NO LONGER POSSIBLE — capability lost 11 Sep 2026.** The DHT has
   been physically removed from the S3 and from the chamber, so that board can no longer produce a
   temperature or humidity series to compare against. It stopped publishing at **11:58** and the
   record has a hole from there.

   ⚠️ **This was a real check and it is gone, so say what replaces it rather than quietly
   dropping the step.** What remains:
   - ⭐ **The BMP280's own temperature** — an independent die on the same module reading the same
     air. Two sensors disagreeing is still a genuine signal, and it survives the S3 leaving.
   - **Room ambient** from the Sensibo unit, as a sanity bound: the chamber must read at or above
     room when idle, and well above it during a print.
   - **The historical series** — the chamber's own record (22,021 humidity, 7,070 temperature
     samples) bounds what is plausible. A new sensor reading 55 °C idle is wrong regardless of
     having nothing to compare against live.

   *Lesson worth keeping: the comparison was available for days and was spent without being used.
   A cross-check that depends on two things overlapping has a deadline, and nobody set one.*
5. Verify long-term statistics **continue on the same `statistic_id`s** rather than starting new
   ones — a `sensor.*_2` appearing in `statistics_meta` is exactly what Route B looks like before
   it is repaired.
6. Only then release the S3 to cell-tester.
7. ✅ **DONE, 12 Sep 2026 — and it was never re-provable on the C3**, whose ESPHome build has no
   persisted counter. The only copy of the answer was the S3's own NVS partition: not readable over
   serial (the firmware never prints the lifetime count), so it was read from flash in ROM download
   mode before the board was reflashed. **Result: `drops = 18`, persistence proven.** The evidence
   and the reasoning are in [the disconnect counter](s3-disconnect-counter.md).

8. ⛔ **Clear the retired node's RETAINED MQTT discovery configs — deleting the registry entries is
   not enough.** Measured 12 Sep 2026: six of the S3's discovery topics are still retained on the
   broker —
   `homeassistant/sensor/chamber_{temp,rh,rssi,bssid,uptime,wifi_drops}/config` — even though that
   board is powered down in a ROM bootloader and has published nothing since 11:58 on 11 Sep.

   **Home Assistant recreates those entities whenever discovery is re-processed.** They returned on
   12 Sep at 09:45:48 and landed as `..._2` duplicates on the old *Print chamber* device, because
   the C3 now owns the original entity_ids. That was **not** an HA restart: 13 state rows in the
   30-second window, 6 of them `unavailable`, and zero non-chamber entities.

   ⚠️ **They are ghosts, not a conflict.** All six read `unavailable` with no state, and every live
   reading is on the C3. But the device list becomes misleading: another session reading the
   registry reasonably concluded that entity-to-device attribution had been scrambled, and that
   there was no way to tell which physical node a reading came from. There is — only one set has
   data — but the appearance alone cost a round of investigation.

   **The fix:** publish an empty retained payload to each of those six topics, then delete the six
   registry entries. Both are live-service changes, so both are Alon's call.

   ⭐ **The lesson generalises to every MQTT node this lab retires: RETAINED DISCOVERY OUTLIVES BOTH
   THE DEVICE AND THE REGISTRY ENTRY.** Removing the hardware, and even removing the entity, does
   not remove the advertisement that recreates it.

## What was renamed, and what deliberately was not

| Renamed onto the historical id | Left alone |
|---|---|
| temperature, humidity, wifi_rssi, uptime, wifi_bssid | `chamber_c3_chamber_pressure`, `chamber_c3_chamber_temperature_bmp280` — **new capabilities with no predecessor**, so there is no series to continue and nothing to hide |
| | `print_chamber_chamber_wifi_disconnects` — the C3 publishes no such sensor, so it is a **closed historical series** |

⚠️ **The rename had a prerequisite that is not obvious.** `statistic_id` is UNIQUE, and the C3 had
already created its own statistics rows, so renaming onto the old ids would have collided. The
working order is **clear the new statistics first, then remove the old registry entries, then
rename** — and the ~30 minutes of new statistics cleared in step one is the deliberate cost.

## Installed and validated — 11 Sep 2026

Flashed, mounted, and publishing. `firmware/chamber-c3.yaml`.

### Validated against an independent instrument — and the raw RH would have misled

The overlap comparison against the S3 was lost when its DHT came out. **A better check replaced
it**: the room's own climate sensor — different manufacturer, different room, no shared wiring,
nothing in common with the new node but the air.

| | T | RH | **Vapour pressure** |
|---|---|---|---|
| Chamber (AHT20) | 28.9 °C | 47.6 % | **1.893 kPa** |
| Room reference | 25.1 °C | 58.9 % | **1.873 kPa** |
| | | | **Δ = 1 %** |

⛔ **Read the RH column alone and you would conclude the chamber is 11 points drier than the room.
It is not — it is the SAME AIR.** Converted to vapour pressure the two agree to about one percent,
which is inside both sensors' accuracy.

This is the rule *RH is a ratio* already states, demonstrated on live hardware rather than in
the abstract: *never compare two humidity readings taken at different temperatures.* The chamber
holds room air because the enclosure was opened to fit the sensor, and the vapour pressure says so
while the RH hides it.

⭐ **It is also the strongest sensor validation this project has had.** The old cross-check would
have been two sensors on one bench sharing a supply and a bus. This one shares nothing.

### OTA verified over the network

```
chamber-c3.local -> resolved by mDNS
INFO Handshake complete
INFO OTA successful          (5.47 s, no USB)
```

**The node never has to leave the enclosure for a config change**, which is precisely what the S3
could not offer: its rollback flag is a *bootloader* option, so it could not be enabled after
deployment, and a bad image there meant opening the box. Adding a sensor here is now an OTA away.
