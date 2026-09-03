# Active drybox — heating the SAMLA box that already exists

**Decision, 3 Sep 2026.** The passive 4-spool IKEA SAMLA 22 L box gets a heater and forced airflow.
The **12 V 50 W PTC element is reallocated to this build from the printer-enclosure heater**, which
has not been started and is explicitly deferred behind two measurements that cost nothing
(see [chamber-sensor](chamber-sensor.md), build order step 6).

## Why this, and why now

A 10 kg PETG bundle landed on 29 Aug — the largest single filament holding in the lab — and PETG is
hygroscopic. The box that exists is **passive**, and that distinction is the whole point:

| | What it actually does |
|---|---|
| **Passive box + desiccant** | **Stores** filament dry. Pulls moisture out only slowly, and stops when the desiccant saturates — silently, with no indication |
| **Active box (heat + airflow)** | **Removes** water already in the spool, in hours rather than never |

Both halves are wanted. Drying fixes a wet spool; storage stops you needing to. This build adds the
half that is missing.

## ⛔ The mistake this design exists to avoid: heating a sealed box

Warming sealed air does **not** dry filament. It raises the air's capacity to hold water, the water
leaves the plastic — and then, on cooldown, it goes straight back in, because it never left the box.
A sealed heated box is a machine for cycling moisture in and out of a spool.

**Drying requires an exhaust.** Air must enter, pick up water, and *leave carrying it*. That is why
this design is a through-flow, not a warm cupboard.

## The architecture — heater OUTSIDE the box

**Alon's call, and it is the right one.** The element sits in an external plenum, not inside the box:

```
   ambient air ──► [ fan ]──►[ PTC element ]──► intake vent ──►┌──────────────┐
                    plenum, mounted outside                    │  SAMLA 22 L  │
                                                               │  4 spools    │
                             moist air out ◄── exhaust vent ───┤              │
                               (high, far corner)              └──────────────┘
```

What putting the element outside actually buys — each of these is a failure mode removed, not a
convenience:

- **The PTC never touches polypropylene.** SAMLA is PP: fine at 50 °C, softening well before a PTC's
  surface temperature. With the element outside, its Curie point stops being a question that can
  melt the box. It is still worth knowing (see checks below), but it is no longer load-bearing.
- **The venting stops being a retrofit.** With an internal element you drill holes to undo
  recirculation. Here the airflow path *is* the design: in through the plenum, out through the
  exhaust.
- **The hot part is reachable.** The thermal cutout, the element and its wiring can be inspected and
  serviced without opening the box or disturbing spools.
- **A failure is outside the enclosure**, not sitting against the plastic wall next to 10 kg of
  plastic.

**Exhaust placement matters:** high, and diagonally opposite the intake. Warm moist air rises, and an
exhaust next to the intake short-circuits the flow — the air leaves before crossing the spools.

## Parts

### Owned — nothing to buy

| Part | Note |
|---|---|
| **IKEA SAMLA 22 L**, 4-spool box | Already built as a passive box. **Polypropylene** — see the temperature limit below |
| **PTC heater, 12 V 50 W, insulated** | ⚠️ **Reallocated from the printer-enclosure build on 3 Sep 2026, by Alon's decision.** PTC is the right element class here: it self-limits at its Curie point, so it cannot thermally run away the way a nichrome coil can |
| **AHT20 + BMP280** | Already recorded as the drybox sensor. 0–100 %RH, which is the reason it exists: **the DHT11 floors at 20 %RH and a working drybox runs 5–15 %RH**, so the ten DHT11s physically cannot measure one. Do not substitute one on availability grounds |
| **TPS63020 buck-boost ×10** | 3.3 V rail for the controller off the 12 V supply |
| **ESP32-C3 ×10** | Controller — with a caveat, below |
| Dupont crimp kit, resistor kit | Wiring and I²C pull-ups |

### Must be bought — five items, all small

| Part | Why | Rough |
|---|---|---|
| **12 V 5–6 A supply** | 50 W at 12 V is 4.2 A steady, and **a cold PTC pulls 2–3× that on startup** — inrush margin is a spec, not a nicety. Neither owned PD trigger board is a 12 V variant | ₪40–60 |
| **Relay or MOSFET module, ≥10 A** | Same inrush reason. A module sized at 5 A is sized for the steady state only | ₪10–15 |
| **NC thermal cutout, ~65–70 °C** (KSD9700 type) | **Not optional — see safety** | ₪10 |
| **Small 12 V fan** (40–60 mm) for the plenum | The owned 40 mm Gdstimes are **24 V** and will not run properly on this rail. ⚠️ **Not the JUMPEAK 120 mm** — that belongs to the fume extractor, a live and fully-parted project, and 120 mm at 3200 RPM would blow the heat straight out the exhaust anyway | ₪10 |
| **Silica gel / desiccant** | For the storage half. **None is owned** — an order-history sweep found no desiccant or silica gel at all | ₪20–40 |

Total is roughly **₪90–145**, against ₪184–349 for a bought single-spool unit that dries one spool
instead of four. With ten spools to cycle that is three runs against ten.

## 🔥 Safety — hardware over-temperature, not software

This repo already states the rule, for the chamber heater, and it applies verbatim here:

> A stuck MOSFET or a crashed ESP32 with a heating element latched on is a fire, and no amount of
> ESPHome prevents it. That means a thermal cutout or thermal fuse physically in series with the
> element.

So:

- **An NC thermal cutout (~65–70 °C) goes in series with the heater**, bolted to the element's body
  or the plenum wall. It is the answer to the latched-on failure. The controller is not.
- **The PTC's self-limiting is a second layer, not the first.** It is a genuine property and the
  reason a PTC beats a coil here — but "insulated/thermostatic" on a listing is not a measured
  Curie point.
- **Mount the element on metal standoffs** with an air gap to any printed plenum wall. If the plenum
  is printed, print it in **ASA** — not PLA, and not PETG, whose Tg is ~80 °C and which is the
  material being dried.
- **The fan and the heater share a switched leg.** Heat with no airflow is the plenum's own hazard,
  so wire it such that the element cannot be energised with the fan dead.

## Checks before building — none of these are assumptions to carry forward

1. **The PTC's actual Curie point and form factor.** Pull the AliExpress order detail page rather
   than reasoning from typical listings, then **bench it in open air on the new supply and watch the
   surface temperature settle.** The bench test happens either way — a measured number beats a
   listing.
2. **The controller board.** ⚠️ The ten owned C3s are **SuperMinis, whose antennas barely transmit**
   — that defect cost this lab days on the chamber-sensor project. §3x of
   [chamber-sensor](chamber-sensor.md) documents a 31 mm wire mod, but **that mod has not been
   performed here** — the measurements in that section are other people's. So: mod one, measure it
   honestly from the far end (not at 5 cm, which is inside the near field), and keep an unmodified
   board as a control. Expect +10 to +17 dB, and accept that the mod recovers the defect rather than
   making the board good. Do **not** take the MINI-1 out of the chamber rig for this.
3. **Where the AHT20 sits.** **Not in the intake stream.** A sensor in the plume reads the heater,
   not the box, and the controller then undershoots the whole volume — the same error class as
   putting the camera's DHT inside its own sealed case.

## Temperature limit

**50 °C, and do not chase 70.** Two independent reasons:

- **The spools.** PETG's glass transition is ~80 °C, but windings **fuse** well below it, and a
  welded spool is unrecoverable. The recorded schedule for the unbranded PETG is 50 °C for 4 h —
  inherited from Inslogic's TDS, since this filament publishes nothing of its own.
- **The box.** SAMLA is polypropylene. 50 °C is comfortable; pushing toward 70 risks lid warp, which
  would ruin the seal the *storage* half depends on. Breaking the passive box to speed up the active
  one is a bad trade.

## Build order

1. Bench the PTC on the new supply, in open air. Measure surface temperature and settling time.
2. Mod and measure one C3, far-end, against an unmodified control.
3. Build the plenum: element on standoffs, cutout in series, fan on the same switched leg.
4. Cut intake and exhaust vents — exhaust **high and diagonally opposite** the intake.
5. Wire the AHT20 out of the airstream; bring temperature and humidity into HA over MQTT, reusing the
   plumbing the camera node already has.
6. **Run it open-loop first, with the cutout as the only protection**, watching the sensor, before any
   automation closes the loop. A safety feature that has never been seen to fire is not one.

## What this does not do

It is a **dryer with storage**, not a dry-while-printing feeder. Nothing here feeds filament to the
extruder, so a dried spool starts re-absorbing the moment it goes on the printer. That is acceptable
for a batch workflow, and is worth knowing rather than discovering.

## Until it is built — you can dry today

Nothing above blocks drying a spool now. The printer's **heated bed at 50 °C** under a cardboard box,
with a gap left so moist air escapes rather than recirculating, is thermostatically controlled and
uses only what is already on the bench. That is the method recorded in the
[unbranded PETG profile notes](../slicer/filament/unbranded/README.md), and it is what should happen
before the temperature tower is printed — **calibrating on wet filament measures the water, not the
temperature.**
