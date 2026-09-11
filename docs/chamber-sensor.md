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

### ✅ CORRELATED WITH PRINT HISTORY — and it kills my own "it never cools" claim

Prusa Connect's print history, against the recorder's chamber series. **The chamber tracks print
activity exactly**, and the apparent anomaly was an artefact of how busy the printer has been.

| Print | Result | Ended |
|---|---|---|
| `…latch-m3-bolt-rev-02` 1h48m | finished | **7 Sep 18:03** |
| `…m3-bolt-rev-01` 23h47m | **STOPPED** after 14 h 45 m | **8 Sep 08:55** |
| `…m3-bolt-rev-01` 1d0h11m | finished after **1 d 0 h 24 m** | **9 Sep 09:27** |
| `…m3-bolt-rev-01` 17h38m | **running**, started 9 Sep 12:15 | est. 10 Sep 05:57 |

All PETG, 240 °C nozzle / 70 °C bed, 0.2 mm.

**⛔ I reported that the chamber "holds 37–38 °C continuously, including overnight" and suggested the
S3 board's own self-heating might be holding it warm. That was wrong.** The printer has been running
almost continuously for two days — a 14 h 45 m attempt, then a 24 h print, now a 17 h 38 m one. The
chamber was warm because something was always printing.

**The one gap proves the box cools perfectly well:**

| Local time | Chamber | What was happening |
|---|---|---|
| 09-09 08:00 | 37.7–38.7 | 24 h print finishing |
| **09-09 09:27** | — | **print ends** |
| 09-09 10:00 | 30.4–32.5 | cooling |
| 09-09 11:00 | **29.5–30.3** | ← floor, ~2 °C over room |
| **09-09 12:15** | — | **next print starts** |
| 09-09 13:00 | 36.8–38.4 | back up |
| 09-09 15:00 | 39.1–**39.9** | current |

**From 38.3 °C to 29.5 °C in about two hours with the box nearly closed**, decaying toward a 27.7 °C
room. So the enclosure has a thermal time constant on the order of an hour, and the flat two-day
trace was a duty-cycle observation misread as a physical property.

⚠️ **The lesson is the one this page keeps relearning:** a flat series is not evidence of a
mechanism. I had two candidate explanations — continuous printing, or sensor self-heating — and
chose the wrong one because the trace's *shape* looked more like self-heating. **The shape could not
distinguish them; only the print log could**, and it was one page away.

### 🌡️ THE BAY MEASUREMENT — 50–51 °C, 9 Sep 2026. Read it before closing the box further.

**Taken from the printer's own LCD (`Support → Temperatures`) during a print, box one side 2 cm
open.** This is the measurement build-order step 2 has been asking for since this page was written,
and it is the first number that bears directly on the Einsy.

| | | |
|---|---|---|
| Room | 27.7 °C | |
| Chamber air | 40.2 °C | +12.5 over room |
| **EINSY BAY** | **50–51 °C** | **+10.3 over chamber air** |
| Trouble figure | ~60 °C | |
| **Headroom** | **≈ 9.5 °C** | |

### ⚠️ This corrects an assessment I gave earlier the same day

Arguing against relocating the Einsy, I wrote *"twenty degrees of headroom at the worst moment two
days of printing could produce"*. **That used chamber AIR as if it were the bay.** The bay runs
about **10 °C hotter**, so the real figure was never 20 °C — it is **9.5 °C**, and it was 9.5 °C
while I was saying 20.

The conclusion I drew may still hold; the margin I drew it from does not. That distinction matters
because the whole argument was *"relocation is solving a problem nobody has shown exists"* — and the
problem is now measured, and closer to the line than the number I used.

### What the 10 °C offset actually means

**The bay tracks chamber air with a roughly fixed offset, so any change that raises chamber
temperature spends bay headroom directly.** Two consequences:

- ⛔ **Do not close that last 2 cm without re-reading the bay.** Whatever fully closing buys in
  chamber temperature comes off the 9.5 °C.
- ⭐ **The makeup-air inlet siting is no longer a nice-to-have.** [chamber-airflow](chamber-airflow.md)
  proposes putting the negative-pressure design's inlet **at the electronics bay**, so incoming
  room-temperature air washes the Einsy before picking up chamber heat. At 50–51 °C with 9.5 °C of
  margin, that stops being an elegant free extra and becomes the thing that buys the headroom back.

### Caveats, so this is not over-read either

- **~60 °C is a rule of thumb, not a datasheet limit.** The hard guard is the printer's own
  `TMC DRIVER OVERTEMP`, which fires far higher. 50–51 °C is *warm and sustained*, not dangerous —
  the honest reading is "less margin than assumed", not "the board is at risk tonight".
- **It is a spot reading from an LCD**, not a series. The bay has no remote readout: it is absent
  from Prusa Connect's telemetry, from every PrusaLink 0.8.1 endpoint, and from Home Assistant.
  Verified in all three on 9 Sep — which is precisely why the DS18B20s were bought.
- **Conditions:** mid-print, ~33 % through a 17 h 38 m PETG job at 240/70, after two days of
  near-continuous printing. This is close to a realistic worst case, but the box was not fully shut.

### 🕛 The two multi-day gaps were the WiFi give-up bug, and they stopped when it was fixed

Homelab found two holes in the node's series and the pattern that identifies them:

| Gap | Started | Ended |
|---|---|---|
| 16.7 h | **3 Sep 00:00:27Z** | 3 Sep 16:40Z |
| **53.9 h** | **4 Sep 00:00:29Z** | 6 Sep 05:54Z |

**Both start within two seconds of midnight UTC**, on consecutive nights — a schedule, not a roam.
And it was not a recorder outage: the bucket took 1,765–9,339 points per 6 h throughout, so HA and
InfluxDB were up and only this node was absent.

**The duration was `wifi.c`'s give-up bug**, and the dates line up exactly:

- The handler stopped calling `esp_wifi_connect()` after 8 consecutive disconnects, permanently.
- The 53.9 h gap **ends 6 Sep 05:54** — when the node was power-cycled by hand, the only recovery
  that bug left.
- The fix landed **6 Sep 12:22** (`43607f7`).
- Since then the node's longest unbroken stretch runs **7 Sep 17:00Z → 9 Sep 07:00Z**, which
  **contains two midnights**, and it is up now.

**So the trigger is still unexplained but is no longer consequential.** Something at midnight UTC
disturbs this link — a scheduled AP event, a lease renewal, a channel re-selection — and before the
fix that burst exhausted an 8-retry budget and stranded the node for days. It now costs a
reconnection. ⚠️ **Worth chasing as "why does the link blip at midnight", not as "why does the node
vanish".**

📋 **And it bounds what this node's own history can support.** Availability and channel count are
different things: the probes hang off the same board and the same uplink, so *"a DS18B20 goes into
HA automatically"* is true only while the node is up — and it demonstrably was not for 54 of the
140 hours before the fix.

### 🕒 CAUGHT IN THE ACT — the midnight event, two consecutive nights, 10 Sep 2026

The section above could only infer the midnight trigger from *gaps*, because the give-up bug turned
every burst into a multi-day outage. With the reconnect fix in and the disconnect counter
published, the event is now visible **directly**, as a counter burst:

| Local time | `wifi_drops` | |
|---|---|---|
| 09-09 03:03:40 | 17 | night 1 — burst, then a reboot resets it |
| 09-09 03:04:06 | 15 | |
| 09-09 15:49:04 | **0** | the `state_class` reflash |
| **10-09 03:00:30** | **1** | ← **night 2 begins, 00:00:30 UTC** |
| 10-09 03:03:06 | 15 | |
| 10-09 03:03:54 | 16 | |
| **10-09 03:04:08** | **18** | ← **ends. ~14 reconnects in 3 m 38 s** |

**So it is confirmed, recurring, and self-healing.** 03:00–03:04 local is **00:00–00:04 UTC**, the
same two-second-of-midnight signature as the 3 and 4 Sep gaps. The node rides it out and is up
now — which is exactly what the reconnect fix was for.

✅ **This narrows the trigger usefully.** It is not a roam and not a chamber-thermal effect: it is
a scheduled event at midnight UTC. ⭐ **It has since been narrowed much further — to the access
point itself. See the next section.** Nothing on this node can fix it; the node's job is only to
survive it, and it does.

### 📡 It is the access point, not the network — and a free test settles it on 25 October

Homelab ran the other half of the correlation from a **wired** host at 5-minute resolution, across
both midnight windows:

| Target | 00:00Z | 00:05Z | 00:10Z | 00:15Z |
|---|---|---|---|---|
| Gateway | 0 % / 0.70 ms | 0 % / 0.77 ms | 0 % / 0.68 ms | 0 % / 0.83 ms |
| Two public resolvers | 0 % loss | 0 % loss | 0 % loss | 0 % loss |

**The router never stops answering and never slows down.** So the event is not a router reboot, not
a routing or uplink outage, and not congestion. A sweep of the lab found no scheduled task — no
timers, no cron entries — firing at that moment on any host or container.

⚠️ **Stated rather than buried: a wired host cannot observe a WiFi deauthentication.** That
evidence rules out the network; it cannot say what the radio did. For that, the only witness is
this node.

**And this node's own association log is the positive evidence.** It has ever associated with
exactly **two BSSIDs of the same SSID, differing in the final octet alone**, and at the event it
gets bounced between them:

| Night | Association changes in the 02:50–03:20 window |
|---|---|
| 8 Sep | settles on the second BSSID at 03:04:15 |
| 9 Sep | one change, 03:03:40 |
| 10 Sep | three changes — 03:00:27, 03:00:30, 03:03:06 |

So the node is being **re-associated at the moment of the burst**, while routing stays perfect.
That is an access point re-initialising or re-steering, not a network fault.

### ✅ SETTLED BY THE SILICON — band-steering is impossible, not merely unlikely

I recorded band-steering as "probably right but not proven". **It is not right at all, and the part
number settles it without anyone reading the AP's configuration.**

`sdkconfig` says `CONFIG_IDF_TARGET_ESP32S3=y`. **The ESP32-S3 is 802.11 b/g/n — 2.4 GHz only.
There is no 5 GHz PHY on the die.** A client that cannot receive 5 GHz cannot be steered onto it,
so **both BSSIDs are necessarily 2.4 GHz** and "bouncing between the 2.4 and 5 GHz radios" is
excluded by hardware.

📏 **The RSSI hint was pointing the right way.** A few dB between the two associations is
exactly what two 2.4 GHz BSSIDs look like — which is why the small difference felt wrong for a band
change. The instinct was sound; the silicon is the proof.

### ⚠️ "One physical AP" is withdrawn too — MAC adjacency proves nothing here

The other half of the inference was that five identical octets meant two radios in one box. That
does not hold either:

- The uplink is a **consumer mesh system**, so two 2.4 GHz BSSIDs are as easily **two separate
  units** as two virtual APs on one unit.
- The BSSIDs have the **locally-administered bit set** — they are derived/virtual addresses. Once
  an address is synthesised, **numerical adjacency says nothing about physical identity.**

**So the honest position is: two 2.4 GHz BSSIDs from one vendor allocation, physical topology
undetermined.** Which lands back where the 9 Sep analysis started — **these are roams** — and makes
a **mesh-wide re-optimisation at 03:00 local** the natural candidate, since consumer mesh systems
ship exactly such a scheduled job. That fits every observation and leaves the 25 October test
exactly as decisive.

⭐ **The general lesson, and it caught two sessions in two days:** a plausible mechanism built from
a structural pattern is not evidence. Both "seven flips" and "one physical AP" came from reading
structure — row counts, address adjacency — as if it were observation. **The datasheet was one
lookup away the whole time.**

### 📈 The −72 dBm figure, checked against the series it was collected for

The RSSI series was added so the enclosure's weak spot would stop being a single bench observation.
At **44,378 samples** it can now answer that:

| | |
|---|---|
| Mean | **−56.1 dBm** |
| Max | −46.0 dBm |
| Min | −74.0 dBm |
| At or below −70 dBm | **30 samples — 0.07 %** |

**−72 dBm is real; the enclosure reaches it and worse.** But it is the **extreme tail, not the
level.** Typical is −56, and the box sits below −70 about seven hundredths of one percent of the
time.

⚠️ **Caveat that limits this:** the series begins 7 Sep 12:12Z, so there is **no RSSI data for
4 Sep** and the original spot reading cannot be checked — only the enclosure's general level since.
The 4 Sep observation is not being called wrong.

### ⭐ THE FREE TEST — 25 October 2026, costs nothing, needs no equipment

00:00 UTC is **03:00 Israel local**, the classic hour for a consumer AP's nightly maintenance or
channel re-selection. **Israel leaves DST on 25 Oct 2026**, which separates the two hypotheses
cleanly at zero cost:

| What happens that night | What it means |
|---|---|
| The event moves to **01:00 UTC** | The AP schedules in **local** time — a nightly maintenance job |
| The event stays at **00:00 UTC** | It is genuinely **UTC**-scheduled, and the local-time theory is wrong |

📋 **Whoever looks at this in November: that shift is the experiment, not a glitch.** Read the
disconnect counter and the association log for the nights either side of 25 October.

### ⛔ THE COUNTER IS CORRUPTING THE STATISTICS — node says 18, Home Assistant says 50

Measured 10 Sep 2026, and this is the concrete cost of the `total_increasing` contradiction that
[`f276ff1`](../firmware/prusa-cam-c/main/wifi.c) fixes:

| Source | Value |
|---|---|
| The node's own counter | **18** |
| HA long-term statistics `sum` | **50** |

**A 178 % overstatement, from exactly two decreases.** `17 → 15` on night 1, and `15 → 0` when the
`state_class` reflash rebooted the board. HA reads any decrease in a `total_increasing` series as a
counter rollover and **adds** the new value to the running sum, so each reboot donated its whole
count a second time. The hourly rows show the jump cleanly: `sum` sat at 32 while the state read 0,
then became 50 the moment the state reached 18.

⚠️ **Nothing here is a measurement error.** Every individual value the node published was
correct. The **declared semantics** were wrong, and a per-boot counter cannot be summed across
reboots without knowing which decreases are reboots — which is why two separate attempts to
reconstruct a lifetime figure by hand both produced numbers the data does not support.

📋 **The fix stops future corruption; it does not repair the past.** The inflated sum stays
inflated, and the flash itself will cause **one final reset** (18 → 0), because the old firmware
never wrote NVS so there is nothing for the new one to load. That is a one-time, understood cost.
Correcting the historical sum is a Home Assistant operation (Developer Tools → Statistics →
*Adjust sum*), so it belongs to homelab, not to this firmware.

### 🔄 THE S3 IS LEAVING — migration to a C3 mini + AHT20, 11 Sep 2026

**Alon reassigned the ESP32-S3 N16R8 CAM to the cell-tester project**, which needs a camera to read
QR labels off battery cells and has no other board that can. The chamber sensing moves to a **C3
mini** (an interim board, held until the C3 SuperMinis get their antenna fix) carrying the owned
**AHT20+BMP280**.

⚠️ **The inventory did not know this board was in use.** HomeBox recorded the S3 against
`cell-tester` and `edge-ai`, with three claimants, and **none of them was 3d-printing** — while the
board was powered, on WiFi, publishing to Home Assistant and serving camera frames. The cell-tester
session asked rather than assuming, which is the only reason it surfaced. *A record proves presence
and never absence*, and this is the cleanest instance of it in the lab so far.

### ✅ "Do we need the DHT11 if we have the AHT20?" — No. And the part is not a DHT11.

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

### ⛔ WHAT MUST NOT BE LOST — the unique_ids carry the history

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

### What the chamber loses, stated rather than discovered later

- **The camera.** `/raw`, the Prusa Connect uploader, and any future spaghetti-detection or
  timelapse work. The C3 has no camera interface and 4 MB of flash.
- **Open item 9c becomes untestable on this hardware.** The persisted-disconnect-counter fix is
  deployed and unproven, and proving it needs a reboot of *that* board. If the S3 is repurposed
  before that reboot happens, the question closes unanswered — the NVS code moves to the C3 build
  and gets re-proved there instead.
- **Pressure is gained**, which the chamber has never had.

### ⚠️ THE SAME CONTENTION IS ABOUT TO REPEAT — the AHT20 is the drybox's sensor

**HomeBox records the AHT20+BMP280 against `project-x`, the DRYBOX sensor**, bought specifically
because *"DHT11 floors at 20 %RH and a working drybox is 5–15 %RH"*. There is **one** of them.

Allocating it to the chamber leaves the drybox without the part chosen for it — and the drybox is
the build where the floor argument actually bites, because a working drybox lives below the DHT11's
floor while the chamber does not. **Flagged, not blocked:** Alon has allocated it, and a second
AHT20 is a ~₪5 part. It is recorded here so the drybox build does not discover it at assembly time,
which is exactly how the S3 was nearly lost.

### Build path — there is prior art, do not start from the C firmware

`prusa-cam-c` is S3-specific: camera driver, octal PSRAM, 16 MB flash. **None of it ports to a C3**,
and it should not be attempted. The chamber already has C3 ESPHome configs from the ESP-NOW work —
[`chamber-sensor-espnow.yaml`](../firmware/chamber-sensor-espnow.yaml) and
[`chamber-sensor-mini1.yaml`](../firmware/chamber-sensor-mini1.yaml) — and ESPHome has a native
`aht10` platform (which covers the AHT20) plus `bmp280`. That is the short path.

**C3 pin constraints, which this lab has already been bitten by once:**

| Pin | Why to avoid |
|---|---|
| GPIO2, 8, 9 | **strapping pins** — a sensor here can prevent boot |
| GPIO18, 19 | **native USB** — same class of trap as the S3's GPIO20 |
| ADC2 channels | unusable while WiFi is active |

I2C wants two ordinary pins clear of all of the above.

### 📋 Migration checklist

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
3. ✅ **DONE — [`firmware/chamber-c3.yaml`](../firmware/chamber-c3.yaml)**, `esphome config`
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
7. Re-prove the NVS counter on the C3 build (open item 9c). ⚠️ **The S3 can no longer answer it
   remotely at all**: the firmware publishes the whole MQTT state payload — counter, uptime and
   BSSID included — only on a GOOD DHT read (`main.c`, `log_dht()`), and there is no DHT. With the
   sensor gone the diagnostics went with it, so the only way to read that counter now is over the
   serial console. Worth knowing before anyone plans to close 9c from Home Assistant.

### 🚀 FLASHED — the persisted counter went live 10 Sep 2026, 13:29:46Z

`f276ff1` is running. It had been built and committed but not deployed for a day, while the
per-boot counter carried on inflating the statistics above.

| | |
|---|---|
| Partition | `ota_0` → **`ota_1`** |
| `app_elf_sha256` | **`ca8176f8b61bd346`** |
| Version string | `007e706-dirty` — the tree the image was built from |
| Reply | **`HTTP 200 "ok, rebooting"`** |

⭐ **That clean 200 is itself a result.** Every previous OTA looked like a failure: the board
logged `update accepted` while the client got a connection reset, because the reboot outran the
reply. The `Connection: close` + `httpd_sess_trigger_close()` change in `ota.c` fixed it, and this
is the first flash that reported honestly. **The old rule — "a reset on POST is success" — is
retired; a non-200 now means something.**

### 📏 `app_elf_sha256` is the ELF's hash, NOT the .bin's — this nearly caused a false alarm

Two sessions checked the artifact and briefly disagreed, because they hashed different things:

| What was measured | Value |
|---|---|
| The `app_elf_sha256` **field**, at offset **0xB0 inside the .bin** | `ca8176f8b61bd346` |
| `sha256` of **`prusa_cam_c.elf`** | `ca8176f8b61bd346` ✅ same |
| `sha256` of **`prusa_cam_c.bin`** | `47813091ebfdf869` — a different, correct, irrelevant number |

**The field is the ELF's hash, embedded in the app descriptor.** Hashing the `.bin` answers a
question nobody asked. Getting this backwards produces a discrepancy that looks like a corrupted
artifact and is not one — and the two readings agreeing is *stronger* evidence than either alone,
because they are independent paths to the same value.

### ✅ Verified by behaviour, not by the upload returning

The POST's return value is not evidence — that is the whole lesson of the reset-as-success era.
What was actually checked:

- **Read-back**: partition flipped and the running sha matches the built image.
- **Publishing resumed** within seconds — temp 39.0 °C, RSSI −55.
- ⭐ **The new `uptime` entity exists and is counting** (26 → 30 → 33 s). This is the one that
  matters: it proves the **new discovery ran**, not merely that a new image booted. A sha proves
  what is in flash; a new entity proves the new code is doing its job.

### ⚠️ The one-time reset happened, exactly as predicted: 18 → 0

At 13:29:46Z the counter went from 18 to 0. **Expected and unavoidable**: the old firmware never
wrote NVS, so the new one had nothing to load. Once only.

📋 **It makes the Home Assistant correction easier, not harder.** A `total_increasing`
rollover adds the *new* value, which was 0, so the inflated sum stays at 50 and from here
`sum = 50 + (node counter)`. The offset is now a **constant +50** against a counter that starts at
zero and is meant to persist — where before it was +32 against a counter that reset unpredictably,
with no stable target to correct to.

⛔ **Do not correct the sum yet.** Persistence is still unproven, and if `drops_save()` does not
fire the target moves again.

### 🔬 WHAT IS STILL UNPROVEN — and the test is tonight

**Deployment is not vindication.** The counter sits at 0 with no disconnects since boot, so nothing
meaningful has reached NVS; rebooting now would load 0 and prove nothing either way.

The real test is the next midnight event:

1. ~03:00 local should drive the count to roughly **14–18**.
2. `drops_save()` should fire on the reconnect that ends the burst.
3. **The next reboot after that should come back non-zero instead of at 0.**

Step 3 is the only one that proves the fix. Until then this section records a deployment, not a
working feature.

### ✅ The `state_class` fix is verified in the field

All four chamber series now build long-term statistics, where three of them had **zero**:

| Series | Long-term rows |
|---|---|
| `chamber_temperature` | 21 |
| `chamber_humidity` | 21 |
| `chamber_wifi_rssi` | 21 |
| `chamber_wifi_disconnects` | 69 *(it always had `state_class`)* |

The three at 21 are counting from the flash; the history *before* it was recorded as states only
and is on the purge clock. **The data was never missing — it was perishable**, and that distinction
is the whole reason this was worth fixing.

### 📉 Second cooling observation — the box sheds heat, again

The 17 h 38 m print ended on schedule at **10 Sep 05:57**, and the chamber behaved exactly as the
9 Sep observation predicted:

| Local time | Chamber | |
|---|---|---|
| 10-09 05:00 | 39.3–39.9 °C | print running |
| **10-09 ~06:00** | — | **print ends** |
| 10-09 06:00 | 32.2–39.6 °C | falling |
| 10-09 07:00 | 30.6–32.1 °C | |
| 10-09 08:00–11:00 | **30.1–31.1 °C** | ← floor, idle |

**39.6 → 30.6 °C inside one hour**, settling ~3 °C above room. This is the second independent
confirmation that the enclosure's thermal time constant is on the order of an hour, and it closes
out the retracted "the chamber never cools" claim for good.

### What this does and does not say about the Einsy

**It stands that the bay runs hot for very long stretches** — but because prints are back-to-back,
not because the box cannot shed heat. ✅ **And the bay figure is now measured: 50–51 °C, see above.** ✅ **That job ended on schedule at 10 Sep 05:57** and the chamber
has been idle at ~31 °C since — see the cooling observation above.

**That is still a duty-cycle question rather than a peak one**, and it is the condition in which to
take the `M105` `A:` reading — during a long print, not after one.

📋 **Prusa Connect is the print-history source; Home Assistant is not.** The recorder holds no
printer entity at all — the only matches are a Xerox office printer. Correlating chamber behaviour
with print activity therefore means reading Connect, unless PrusaLink is added to HA.

### 📏 NEARLY CLOSED — +12.2 °C, 9 Sep 2026. Closing the box doubles the rise.

**Alon, printing with the enclosure almost shut, one side 2 cm open.** This is the configuration the
build order's step 2 has been asking for, and it is the first measurement of a chamber that is
actually closed.

| Configuration | Chamber | Room | **Rise** |
|---|---|---|---|
| Door **and** side open (3 Sep) | 31.2 °C | 25.8 °C | **+5.4 °C** |
| **Side 2 cm open (9 Sep)** | **40.2 °C** ⚠️ *still rising when quoted at 39.9 — plateaued at 40.0–40.2* | 27.7 °C | **+12.5 °C** |

**Closing the box roughly doubled the rise over ambient**, which is the number that was missing —
the earlier reading was a baseline with the box effectively open, and could not say what closing it
would buy.

**39.9 °C sits at the bottom of the 40–60 °C ASA band.** So a nearly-closed Lack on bed heat alone
just reaches ASA territory, and the *"close it and measure before assuming a heater is needed"*
position in this page's own build order is looking correct rather than merely cautious.

### ⚠️ And this is exactly when the Einsy question stops being theoretical

The chamber is at ~40 °C **now**, with the box nearly shut, and this page puts Einsy trouble at
around **60 °C**. The electronics bay is not the chamber — it sits near the bed and the drivers
self-heat — so bay temperature is expected to be *above* the 39.9 °C measured here, not equal to it.

✅ **The measurement needs no hardware and can be taken during this print:** the Einsy's own ambient
thermistor *is* point B, and Prusa's firmware reports it in **`M105`** as **`A:`** (alongside `P:`
for the PINDA). Read it against ~60 °C.

⚠️ **The DS18B20s on order do not replace this.** They arrive in days; `A:` is available now, in the
condition that matters, and this condition may not be reproduced on demand.

### 📛 The humidity number here is NOT a finding — it points the way the known bias points

Measured 18.5 %RH at 39.9 °C, against room air at 27.7 °C / 68.5 %RH. Heating room air to 39.9 °C
would give **34.6 %RH**, so the chamber reads as holding **~47 % less water than the room**.

**Do not bank that.** The sensor is a DHT11 on the S3 camera board, which self-heats — and
self-heating biases temperature **high** *and* RH **low**, both pushing in exactly the direction that
would manufacture this result. Add the DHT11's own ±5 %RH and the two readings not being strictly
simultaneous, and the apparent drying is inside the error budget of the instrument.

It is the same trap already recorded on this page: *a directional bias is indistinguishable from the
effect it mimics.* Worth re-testing once the AHT20 is on a node mounted **outside** the box, which is
what the placement rule exists for.

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
the workstation and kept publishing throughout, which closes an open question about coverage at
the printer.

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

`aa:bb:cc:dd:ee:01` is the MINI-1 — **the address is redacted here**, and what the test turns on is
that it is the SAME address on both lines. **Both SuperMinis hear it flawlessly, every
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
| Sender + DHT11 | ESP32-C3-**MINI-1** | `COM8` on the workstation | `firmware/chamber-sensor-mini1.yaml` |
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

### Why 31 mm — and the thing it makes the mod depend on

Source: GreatScott!, *"I Found the Secret to WiFi Antennas! EB#68"*, 24 May 2026
([Q_5bna_cyBw](https://www.youtube.com/watch?v=Q_5bna_cyBw)). Measured with a VNA and RSSI A/B
tests, so the numbers below are his measurements, not theory.

**The 31 mm is not arbitrary and it checks out.** At 2.4 GHz the wavelength is ~12.5 cm:

| Antenna | Conductor length | Needs a ground plane? |
|---|---|---|
| **Dipole** — half wave | **6.25 cm** | No — the second element *is* the other half |
| **Monopole** — quarter wave | **3.125 cm** | **Yes** — the ground plane supplies the missing half |

So **§3x's 31 mm of wire is roughly a quarter wave in total**, and it behaves monopole-like: a
single-ended radiator working against the board's ground. ⚠️ **Do not read it as a plain quarter-wave
whip, though** — the procedure is 16 mm of loop plus 15 mm of straight, with the chip antenna left in
circuit, so most of that length is an impedance-matching structure and only the straight part sticks
out and radiates. The classification is still the useful part, because it names what the mod's
performance rests on: the ground plane.

### ⚠️ Which means the ground plane is the limiting factor, not the wire

His DIY monopole — 3.2 cm of solid core wire on an SMA connector — matched commercial monopoles
**while clamped in a metal vice**. Removing it from the vice, i.e. shrinking its ground plane,
**visibly degraded it**, and on the VNA the same antenna read *"pretty terrible"* until a ground
plane was attached.

**A C3 SuperMini is a 22 × 18 mm board.** Its ground plane is a postage stamp. That is very likely
the real explanation for the ceiling already recorded above — that a *modded* SuperMini reaches
-45 dBm where a properly laid-out C3 reads -33 dBm on the same desk. The wire is the right length;
it is standing on almost nothing.

**Consequence for this build:** effort spent on the ground plane is likely worth more than effort
spent on the wire. Anything that enlarges it — a ground pour, a scrap of copper tape bonded to the
board's ground, mounting against a grounded metal surface — attacks the actual limit.

### 💡 Three recovery routes, cheapest first — for the 10 owned SuperMinis

His explicit verdict: *"if you want an easy and reliable WiFi antenna, get yourself a dipole."*
Dipoles beat monopoles across his whole test set, and the reason is exactly this — **a dipole carries
its own second half and does not care about the ground plane.**

Because ten of these boards are owned and recovering them is worth real effort, here are the three
options ranked by effort, with what each actually attacks:

| # | Change | Attacks | Effort | Tested here |
|---|---|---|---|---|
| **A** | §3x wire — one 31 mm element | antenna *absence*; leaves the ground plane tiny | 30 s solder | no |
| **B** | **Enlarge the ground plane** | the measured limit, directly | copper tape | no |
| **C** | **Dipole** — two 31 mm elements | removes ground-plane dependence entirely | rework | no |

**A — the documented wire.** Already written up above. Expect +10 to +17 dB and a ceiling.

**B — give the monopole a ground plane, which is the cheap win nobody tried.** A quarter-wave
monopole ideally wants a ground plane of about **λ/4 radius — ~3 cm, so a ~6 cm disc**. The
SuperMini's is a 22 × 18 mm board. Copper tape or thin sheet bonded to board ground, or simply
mounting the board flat against a grounded metal surface, closes most of that gap for pennies.
**This is the option I would try first**, because it is reversible, needs no rework of the RF
section, and it is the exact variable his experiment isolated — his DIY monopole matched commercial
ones *in a metal vice* and degraded out of it.

**C — the dipole.** Two ~31 mm elements, one on the antenna feed and one on board ground, extending
in **opposite** directions and **in line** with each other. Each is a quarter wave, so the pair makes
a half-wave dipole, and it stops caring about the ground plane.

### ⚠️ A dipole is NOT "the §3x mod twice" — and the difference is the whole mechanism

The natural reading is that C is A plus one more wire. It is not:

| | §3x mod (A) | Dipole (C) |
|---|---|---|
| Shape | **16 mm loop + 15 mm straight** | **two plain straight elements** |
| Attaches to | both **chip-antenna pads** | one on **feed**, one on **GROUND** |
| Direction | one radiator | **opposite, collinear** |
| Chip antenna | **left in place** — it completes the loop | in the way; see below |

Two consequences, both load-bearing:

- **A second wire soldered to the feed is not a dipole, it is a fatter monopole.** The second element
  must go to **ground**. Ground supplying the other half of the radiator — instead of the board's
  tiny ground plane doing it badly — *is* the mechanism.
- **The §3x loop is a matching structure, not a radiator.** Its 16 mm does impedance work together
  with the chip antenna; only the 15 mm sticks out and radiates. A dipole discards that arrangement
  rather than duplicating it.

📋 **Open question, untested: what to do with the ceramic chip antenna.** §3x found leaving it in
place measured *better* — but that is for the loop mod, which deliberately uses it. Under a dipole it
sits in parallel with the driven element and will pull the match around. Removing it is
irreversible. **Try it in place first**, since that is reversible, and only remove it on a board
already accepted as possibly sacrificial.

### ⭐ Mobility is the real argument for the dipole — stronger than "B needs metal"

**A monopole's other half is effectively whatever it is sitting near.** Its ground plane is the board
plus any nearby conductive mass. For a fixed node that is merely small; **for a node that moves it is
a variable** — the same board performs differently on a bench, in a plastic box, and beside a printer
frame, and it changes with no warning and no error.

**A dipole is self-contained**: both halves are soldered to it, so it behaves the same wherever it
goes. **For a mobile node that consistency is worth more than raw dB**, because a link budget you
cannot predict is one you cannot design around.

⚠️ **Be honest about what a dipole here is:** the SuperMini's feed is single-ended, so this is a
dipole fed unbalanced with no balun. It works in practice — plenty of cheap dipoles are built this
way — but common-mode current rides the ground element. Do not expect textbook performance; expect
*consistent* performance, which is the point.

### Wire: what matters, and what does not

- **Diameter barely affects the resonant LENGTH.** It sets **bandwidth** — thicker is more forgiving
  of a length error. WiFi's ~80 MHz at 2.4 GHz is undemanding, so **thin wire still works.**
- **Solid beats stranded for mechanical reasons only.** An element must hold a straight 31 mm and
  stay there; stranded wanders and its effective length changes as it is handled.
- ⚠️ **§3x's 1.0 mm spec is largely mechanical** — its loop has to hold an 8 mm circle unaided. **A
  dipole has no loop**, so it tolerates thinner wire than the mod does. Cores too floppy for A are
  perfectly usable for C.
- **Strip individual conductors out of multi-core cable; never use it as a cable.** *(The cable on hand is measured and specified just below.)* Two cores in one
  jacket run parallel and adjacent, and a dipole's elements must be **collinear and opposite** —
  separated, in line, pointing away from each other.

### Which wire: 0.60 mm is preferred, and the reason is the fourth-power law

Two solid wires are on hand and measured. **The thinner one is the better element**, and the margin
is not close:

| Wire | AWG | L/d | Element | **Bending stiffness** |
|---|---|---|---|---|
| **0.60 mm** | 22.6 | 51 | **~29.3 mm** | **1×** |
| 1.00 mm *(§3x spec)* | 18.2 | 31 | ~29.0 mm | 7.7× |
| 1.37 mm *(3-core)* | 15.5 | 22 | ~28.7 mm | **27×** |

**Second moment of area scales with d⁴**, so the 1.37 mm is not "somewhat stiffer" than the
0.60 mm — it is **27× stiffer**, and all of that torque is delivered to an SMD pad. Against ten
boards worth keeping, that dominates every other consideration in the table. The electrical cost of
going thinner is negligible: the element length moves by 0.6 mm, and the higher L/d sits marginally
*closer* to the nominal quarter wave.

**Cut 31 mm, trim toward ~29 mm**, measuring far-end RSSI against an unmodified control.

✅ **The inventory record agrees independently**, noting 22 AWG is *"NOT the gauge for the drybox PTC heater at ~4.2 A"*. ⚠️ **So the 1.37 mm is not waste — it is the right wire for that heater**, where the buy list
calls for 18 AWG to carry 4.2 A continuous and where stiffness is a virtue. See
[drybox-active](drybox-active.md).

### ✅ IDENTIFIED: UL1007 22 AWG solid tinned copper, 5 × 10 m coils

**`Hookup wire, UL1007 22AWG solid tinned copper - 5 colours, 10m each`** — HomeBox, parts storage.

| | |
|---|---|
| Conductor | **22 AWG solid tinned copper** — 0.644 mm nominal, measures 0.60 |
| Insulation | PVC |
| Quantity | **5 coils, 10 m each — 50 m total**, in black, red, blue, green, yellow |
| Provenance | AliExpress ref `[order reference removed]`, a marketplace seller, 20 Apr 2026, ₪75.85 |
| Model | `DXXAW22YL-10M` |

**Every open question about this wire is closed, and all three answers are the good ones:**

- ✅ **Tinned copper, not CCA.** The copper-clad-aluminium worry — brittle, work-hardens, fails at
  the copper/aluminium interface — does not apply. This is real copper.
- ✅ **Pre-tinned, so there is no enamel to strip.** It takes solder directly.
- ✅ **50 m against the ~700 mm ten boards need** — about **70× margin**. Quantity is a non-issue and
  practice attempts cost nothing.

### 💡 Use two different colours, and let the wire prevent the mistake

Five colours is not decoration here. **The most likely way to build a dipole wrong is to solder both
elements to the feed**, which produces a fatter monopole that looks identical, measures worse, and
gives no visible clue why.

**Pick one colour for the feed element and another for the ground element, and hold that convention
across all ten boards.** The error then becomes visible at a glance instead of needing a meter — and
across a batch, a mistake you can see beats one you have to measure.

### 📋 Why two searches missed it — a race, not a search failure

Worth recording, because the obvious lesson would be the wrong one. A full inventory agent and a
direct ten-route search both returned **NOT FOUND**, and **both were correct when they ran**:

| | Entities |
|---|---|
| Agent's sweep | 221 |
| Direct search | 222 |
| The search that found it | **223** |

**The record was created while the searches were running**, by another session working the same
inventory. Nothing was mis-searched and no keyword was wrong — a `hookup` query genuinely returned
zero, minutes before the row existed.

⚠️ **The generalisable point: `NOT FOUND` against a live shared inventory carries a timestamp.** It
describes a moment, not a property of the world, and re-running it costs seconds. The house rule
that *a match proves presence and nothing proves absence* already implies this; this is what it looks
like in practice.

*(What led here was `homebox-add-hookup-wire.py` in `Tools/inventory/scripts/` — **a script named
for a part is evidence the part exists, even when the record does not yet.**)*

### If the 1.37 mm is used after all — strain relief is mandatory

⛔ **A 15 AWG solid conductor on an SMD antenna pad is a lever.** Its stiffness means any knock, flex
or tug transfers into a pad measured in fractions of a millimetre, and SMD pads lift. This is the
most likely way to destroy a board in this work — more likely than any RF mistake.

- Anchor the wire to the PCB with epoxy or hot glue **a few millimetres past the solder joint**, so
  load lands in adhesive rather than the pad.
- Better: solder a **short thin flexible section to the pad** and join the heavy element to *that*
  a few millimetres away, making the thin part a deliberate mechanical fuse.
- Do the strain relief **before** the first bend.

**There is no shortage of it:** 4 m of 3-core is **12 m of conductor**, about **195 dipoles' worth**
for 10 boards. Practice is free — **do the first attempt on a board already written off**, because
wire is not the constraint here, pads are.

### How to tell whether any of it worked — the same protocol either way

⛔ **Do not measure at 5 cm.** At 2.4 GHz that is inside the reactive near field, where two
mismatched antennas couple in ways that ignore path loss.

- Read **RSSI from the far end** — the AP, or another node — at several metres, through a wall.
- **Keep one unmodified board as a permanent control**, and measure it in the same spot in the same
  session. A number without a control is not a result.
- **Orient the element vertically**, matching the AP's antennas. Simple antennas radiate in a donut —
  strong to the sides, weak off the ends — and he measured co-alignment as clearly best. This is
  free and applies to every option above.
- ⛔ **Do not use a longer wire.** *"Bigger is not always better"* — his largest antenna was a
  monopole that lost to the dipoles. Length has an optimum, not a direction.

**For the drybox and chamber nodes specifically, the node is mounted OUTSIDE the box**, so there is
physical room for a proper antenna and no reason to compromise the geometry to fit a lid.

### Two free wins, whichever antenna is used

- **Orient the wire vertically**, matching the AP's antennas. Simple straight antennas radiate in a
  donut — strong to the sides, weak off the ends — and he measured co-alignment as clearly best.
  For a drybox or chamber node this costs nothing at mounting time.
- ⛔ **Do not use a longer wire.** *"Bigger is not always better"* — his largest antenna was a
  monopole and lost to the dipoles. Length has an optimum, not a direction.

⚠️ **What this source does NOT settle.** He tests SMA-connected wire antennas on boards with uFL
connectors; he explicitly lists **chip antennas and PCB antennas as not yet covered**, and those are
what a SuperMini actually has. The SuperMini's fault is a layout and impedance-matching problem, and
this video does not measure that class of part. Treat the ground-plane finding as a strong
explanation for the observed ceiling, not as a measurement of this board.

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

### The main SSID is permanently impossible for this hardware

It runs **WPA3-Personal with GCMP-256**. ESP32 radios implement **CCMP only** —
GCMP is not a setting being refused, it is a cipher the silicon does not have. The
node reports `Authentication Failed` and `Handshake Failed`, which look exactly
like a wrong password and are not.

Ruled the password out properly rather than by assertion: Windows had a stored
profile for that SSID, and its key matched `secrets.yaml` byte for byte, case
sensitive. Same length, identical string, still refused. **Do not spend time
retyping the password for this network** — no ESP32 will ever join it.

### The IoT SSID works, but only since it was set to WPA2-only

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

### ⛔ And NEVER on the node's own PCB — the bias points at the answer

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

- §4 puts the **bay** probe on **1-Wire** specifically because *"I²C is not a long-cable bus and will
  fail intermittently, which is the worst way for a safety sensor to fail"*.
- §6 requires the **chamber** probe to hang **in free air, away from everything** — and now, away
  from the node as well.
- But the chamber probe is **I²C** (AHT20), so "far enough to avoid self-heating" and "close enough
  for reliable I²C" appear to be in tension.

✅ **They are not, once the node moves.** The conflict only exists if the node is assumed to be inside
the chamber. **Mount the node on the OUTSIDE of the enclosure wall and run a short I²C tail through
it to the sensor hanging inside.**

- The I²C run stays **short** — 20–30 cm, which §4 already calls trivial at 100 kHz — so the
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

| Path | Flow | Source |
|---|---|---|
| Recirculation | high | the owned 120 mm fan, through HEPA + carbon, back into the chamber |
| Extraction | low, continuous | a **metered bleed off the same fan's outlet**, into the duct |

⚠️ **CORRECTION, 4 Sep 2026 — and it changes the design back to ONE fan.** The claim below that "a
120 mm axial produces only tens of pascals" is true of ordinary case fans and **not of the fan
actually owned.** The JUMPEAK runs **3200 RPM** on a 120 mm frame, where ordinary case fans run
1200–1500, and static pressure scales roughly with RPM² — it is an industrial high-static-pressure
part.

That makes a **single fan with a split outlet** the better design: it pushes the filter stack *and* a
metered bleed out the duct, most of the flow returning to the chamber. One owned fan, no second
purchase, no damper, and the extracted air is already filtered because the bleed comes off the
downstream side of the HEPA. The full build is in [chamber-airflow](chamber-airflow.md).

Two fans remain the upgrade path if the duct proves restrictive enough to collapse the bleed, or if
solvent work later wants extraction turned up independently of the recirculation rate.

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
  # The name, not a bare IP - Home Assistant's own MQTT integration is
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
