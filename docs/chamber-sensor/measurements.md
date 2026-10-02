# What the chamber and the bay actually do — the measurements

*Part of the [chamber sensor](../chamber-sensor.md) notes.*

**In short:**

- **Box open (door and side), 3 Sep:** the chamber sat about +5 °C over the room. A baseline, not a
  verdict on the enclosure.
- **Nearly closed (one side 2 cm open), 9 Sep:** 40.2 °C against a 27.7 °C room, **+12.5 °C** —
  closing the box roughly doubled the rise, and reaches the bottom of the 40–60 °C ASA band.
- **The electronics bay, 9 Sep: 50–51 °C**, about 10 °C above the chamber air, so roughly **9.5 °C
  below the ~60 °C trouble figure.** Any extra chamber heat spends that margin directly.
- **The box cools within about an hour** once a print ends; a long flat trace meant back-to-back
  prints, not a box that cannot shed heat.
- **Long-term graphs have a seam on 11 Sep, ~14:30 local**, where the instrument changed.
- Always record the configuration — door, side, how far open — with a reading.

## The baseline: 31 °C mid-print, door and side open — 3 Sep 2026

The S3 camera node with its DHT11 was placed in the enclosure during a live print. Over a 40 s
sample it read **31.2–31.3 °C and 37.2–37.6 %RH**, flat rather than still climbing, so this is a
plateau and not a mid-warmup number.

⚠️ **THE DOOR WAS ALSO OPEN. This is NOT a measurement of the enclosure.** The first version of this
entry read it as "one side deliberately open reaches 31 °C, so the open side costs 10–20 °C" — that
conclusion is **withdrawn**, because it was never a measurement of the normal configuration. With
the open side *and* the door open, this is very nearly an unenclosed printer, and 31 °C is
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

## Nearly closed: closing the box doubles the rise — 9 Sep 2026

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
position in the [build order](build.md#build-order-10) is looking correct rather than merely cautious.

### When the Einsy question stops being theoretical

The chamber is at ~40 °C **now**, with the box nearly shut, and [the three points](sensors.md) put Einsy trouble at
around **60 °C**. The electronics bay is not the chamber — it sits near the bed and the drivers
self-heat — so bay temperature is expected to be *above* the 39.9 °C measured here, not equal to it.

✅ **The measurement needs no hardware and can be taken during this print:** the Einsy's own ambient
thermistor *is* point B, and Prusa's firmware reports it in **`M105`** as **`A:`** (alongside `P:`
for the PINDA). Read it against ~60 °C.

⚠️ **The DS18B20s on order do not replace this.** They arrive in days; `A:` is available now, in the
condition that matters, and this condition may not be reproduced on demand.

### The humidity reading is not a finding — it points the way the known bias points

Measured 18.5 %RH at 39.9 °C, against room air at 27.7 °C / 68.5 %RH. Heating room air to 39.9 °C
would give **34.6 %RH**, so the chamber reads as holding **~47 % less water than the room**.

**Do not bank that.** The sensor is a DHT11 on the S3 camera board, which self-heats — and
self-heating biases temperature **high** *and* RH **low**, both pushing in exactly the direction that
would manufacture this result. Add the DHT11's own ±5 %RH and the two readings not being strictly
simultaneous, and the apparent drying is inside the error budget of the instrument.

It is the same trap already recorded in these notes: *a directional bias is indistinguishable from the
effect it mimics.* Worth re-testing once the AHT20 is on a node mounted **outside** the box, which is
what the placement rule exists for.

## The electronics bay: 50–51 °C — 9 Sep 2026. Read it before closing the box further

**Taken from the printer's own LCD (`Support → Temperatures`) during a print, box one side 2 cm
open.** This is the measurement [build-order](build.md#build-order-10) step 2 has been asking for since these notes were written,
and it is the first number that bears directly on the Einsy.

| | | |
|---|---|---|
| Room | 27.7 °C | |
| Chamber air | 40.2 °C | +12.5 over room |
| **EINSY BAY** | **50–51 °C** | **+10.3 over chamber air** |
| Trouble figure | ~60 °C | |
| **Headroom** | **≈ 9.5 °C** | |

### This corrects an assessment given earlier the same day

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
- ⭐ **The makeup-air inlet siting is no longer a nice-to-have.** [chamber-airflow](../chamber-airflow.md)
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

## The box cools within about an hour — and "it never cools" was wrong

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

⚠️ **The lesson is the one these notes keep relearning:** a flat series is not evidence of a
mechanism. I had two candidate explanations — continuous printing, or sensor self-heating — and
chose the wrong one because the trace's *shape* looked more like self-heating. **The shape could not
distinguish them; only the print log could**, and it was one page away.

### A second cooling observation — 10 Sep 2026

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

## What this does and does not say about the Einsy

**It stands that the bay runs hot for very long stretches** — but because prints are back-to-back,
not because the box cannot shed heat. ✅ **And the bay figure is now measured: 50–51 °C, see above.** ✅ **That job ended on schedule at 10 Sep 05:57** and the chamber
has been idle at ~31 °C since — see the cooling observation above.

**That is still a duty-cycle question rather than a peak one**, and it is the condition in which to
take the `M105` `A:` reading — during a long print, not after one.

📋 **Prusa Connect is the print-history source; Home Assistant is not.** The recorder holds no
printer entity at all — the only matches are a Xerox office printer. Correlating chamber behaviour
with print activity therefore means reading Connect, unless PrusaLink is added to HA.

## The 11 Sep seam: two instruments in one graph. Read this before trusting a long graph

The chamber entity_ids were **repointed**: the C3's entities were renamed onto the S3's historical
ids, so the long-term statistics continue as one unbroken series.

**That is convenient and it hides something.** The same graph now contains two different
instruments:

| | Before ~14:30, 11 Sep | After |
|---|---|---|
| Board | ESP32-S3 CAM | ESP32-C3-MINI-1 |
| Temp / RH sensor | **DHT22** (single-wire) | **AHT20** (I2C) |
| RH accuracy | ±2–5 % | ±2 % |
| Temp accuracy | ±0.5 °C | ±0.3 °C |
| Firmware | hand-written C | ESPHome |
| Typical RSSI | −56.5 mean | −32.9 mean |

⛔ **So a step change at that timestamp is an INSTRUMENT ARTEFACT, not the chamber doing
something.** Anyone analysing a multi-day trend across it must treat it as two series joined, not
one measurement. The enclosure was also opened at the changeover, so its air was exchanged with the
room at that moment too — a second, independent discontinuity at the same instant.

📋 **Why merge at all, then?** Continuity of the 47-row statistics series was judged worth
more than the seam, and the seam is recoverable *because it is written down here*. The alternative
— leaving `sensor.chamber_c3_*` separate — would have been more honest by default and less useful
in every graph. **This note is the price of that choice; do not delete it.**
