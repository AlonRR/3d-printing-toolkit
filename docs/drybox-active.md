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

**Alon's call, and it is the right one.** The heater sits outside the box and ducts warm air in:

```
   ambient air ──►┌────────────────────────┐──► duct ──► intake vent ──►┌──────────────┐
                  │ PTC + BONDED FAN       │   (printed)                │  SAMLA 22 L  │
                  │ one owned assembly     │                            │  4 spools    │
                  └────────────────────────┘                            │              │
                     mounted outside            moist air out ◄─────────┤              │
                                                  exhaust vent          └──────────────┘
                                                  (high, far corner)
```

**The heater and its fan are a single owned assembly** (confirmed by eye, 3 Sep 2026), which
simplifies the build twice over. There is no plenum to design around a loose element — the assembly
*is* the plenum — so the only printed part is a **duct from its outlet to the box's intake vent**.
And that duct sits **downstream of the element, carrying warm air rather than sitting beside a hot
one**, which is a far easier thermal environment for a printed part than the original plan.

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

## Running it — what separate cables actually buy

The fan and heater being independently switchable is not just a wiring detail; it is what lets the
box do the one thing the opening section says a sealed heated box cannot.

**During a cycle: fan continuous, heater modulated.** Hold 50 °C by cycling the *heater* against the
AHT20 while the fan runs without interruption. Cycling both together would stall the airflow every
time the setpoint is reached, and moisture only leaves while air is moving — the fan is doing the
actual drying, the heater merely raises the air's capacity to carry water.

**⭐ At the end: heater off, fan keeps running — the cooldown purge.** This is the payoff. The
failure this whole design exists to avoid is warm wet air sitting in the box and giving its water
back to the spools as it cools. A purge flushes that air out **while it is still warm and still
holding the moisture**, so what cools down afterwards is dry ambient air rather than a loaded
atmosphere. Without independent control this is impossible: cutting the heater would cut the fan,
and the box would cool with the wet air still inside it.

Run the purge until the box is near ambient — on the order of 15–30 minutes, though the AHT20 makes
this measurable rather than guessed. **Then seal the box and let the desiccant hold it**, which is
the point at which the active half hands over to the passive one.

**Sequencing follows from the interlock:** fan on first, heater second; heater off first, fan last.
That is also the order the hardware enforces, so software and wiring agree rather than compete.

## Parts

### Owned — nothing to buy

| Part | Note |
|---|---|
| **IKEA SAMLA 22 L**, 4-spool box | Already built as a passive box. **Polypropylene** — see the temperature limit below |
| **PTC heater, 12 V 50 W, insulated — with its own fan, SEPARATELY CABLED** | ⚠️ **Reallocated from the printer-enclosure build on 3 Sep 2026, by Alon's decision.** **Confirmed by eye, 3 Sep 2026: the fan is attached, and its cable is separate from the heater's** — the listing's "WITH FAN" was real, so this is a self-contained heater-blower rather than a bare element, and the two are **independently controllable**, which is what makes the cooldown purge possible. That removed the plenum fan from the buy list and, better, means **airflow is matched to wattage by the manufacturer** rather than by a guess at 40–60 mm. PTC is also the right element class here: it self-limits at its Curie point, so it cannot thermally run away the way a nichrome coil can |
| **AHT20 + BMP280** | Already recorded as the drybox sensor. 0–100 %RH, which is the reason it exists: **the DHT11 floors at 20 %RH and a working drybox runs 5–15 %RH**, so the ten DHT11s physically cannot measure one. Do not substitute one on availability grounds |
| **TPS63020 buck-boost ×10** | 3.3 V rail for the controller off the 12 V supply |
| **ESP32-C3 ×10** | Controller — with a caveat, below |
| Dupont crimp kit, resistor kit | Wiring and I²C pull-ups |

### Must be bought — four items, all small

| Part | Why | Rough |
|---|---|---|
| **12 V 5–6 A supply** | 50 W at 12 V is 4.2 A steady, and **a cold PTC pulls 2–3× that on startup** — inrush margin is a spec, not a nicety. Neither owned PD trigger board is a 12 V variant | ₪40–60 |
| **2-channel relay or MOSFET module**, heater channel **≥10 A** | Two channels, because the fan and heater are separately cabled and controlling them independently is the whole point — see the purge above. The heater channel carries 4.2 A steady and **2–3× that as a cold PTC's inrush**, so a 5 A part is sized for the steady state only; the fan channel is trivial by comparison. Dual-channel modules cost about the same as single | ₪10–15 |
| **NC thermal cutout, ~65–70 °C** (KSD9700 type) | **Not optional — see safety** | ₪10 |
| **Silica gel / desiccant** | For the storage half. **None is owned** — an order-history sweep found no desiccant or silica gel at all | ₪20–40 |

Total is roughly **₪80–135** — the fan came off the list once the heater turned out to have one bonded
to it. Against ₪184–349 for a bought single-spool unit that dries one spool instead of four. With ten
spools to cycle that is three runs against ten.

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
- **The printed duct attaches at the assembly's outlet, not around the element.** Print it in
  **ASA** — not PLA, and not PETG, whose Tg is ~80 °C and which is the material being dried. How
  close it can sit to the outlet depends on the bench measurement below; leave a metal or air-gap
  standoff if the outlet runs hot.
- ⚠️ **The fan and heater have SEPARATE cables** (confirmed 3 Sep 2026), which is good for control
  and is the reason the safety wiring below is not optional. Independent control means the state
  **heater on, fan off** is now *reachable* — a crashed or buggy controller can produce it. Shared
  cables would have made it physically impossible; separate cables hand that guarantee back to
  software, and software is exactly what this repo's rule says not to rely on.
- **Gate the heater on the fan's supply — an asymmetric hardware interlock.** Do not simply tie them
  to one leg, because that would throw away the independent control that makes the purge below
  possible. Instead take the heater switch's *control* power — the relay coil, or the MOSFET gate
  driver's Vcc — **from the fan's switched output**:

  | Fan | Heater | Possible? |
  |---|---|---|
  | off | on | ⛔ **physically impossible** — no control power to the heater switch |
  | on | off | ✅ yes — this is the purge, and it is wanted |
  | on | on | ✅ yes — normal drying |

  One wire moved, no parts added, and it restores the guarantee the shared cable would have given
  while keeping everything independent control buys.
- **A stalled fan is still the case the thermal cutout exists for.** The interlock above covers the
  fan being *unpowered*. It does nothing about a bearing that seizes with voltage still applied —
  the fan leg reads live, the heater stays enabled, and the element sits at full power in still air.
  That is precisely what the in-series cutout catches, and it is why the cutout is not negotiable no
  matter how the control is wired.

## Checks before building — none of these are assumptions to carry forward

1. **The PTC's Curie point — now known to be UNDOCUMENTED, which makes the bench test mandatory.**
   The order detail page was pulled (ref `[order reference removed]`, 8 May 2026, ₪39.12) and it **states no
   Curie point at all**. The variant is only `(INSULATED) 12V 50W`; "thermostatic" and "insulated"
   are words on a title that also spans **50–400 W and five voltages** — the same variant-ladder
   shape that has misled this lab repeatedly.

   So there is no document to read, and **the bench test is the only source of that number.** Treat
   the self-limiting temperature as **UNKNOWN** until measured.

   **Bench it as the complete assembly, with its own fan running**, because that is how it will run —
   testing a forced-air heater in still air measures a machine that does not exist, and would read
   far hotter than reality. Measure three things: the **outlet air** temperature, the **body/outlet
   surface** temperature, and the **total current** including the fan. The first sizes the box
   control, the second decides whether a printed duct can touch the outlet or needs a standoff, and
   the third confirms the supply.
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

1. Bench the heater assembly on the new supply, **fan running**. Record outlet air temperature, outlet surface temperature, total current, and how long each takes to settle.
2. Mod and measure one C3, far-end, against an unmodified control.
3. Wire it: cutout in series with the element, and **the heater switch's control power taken from the fan's switched output** so heater-without-fan is physically impossible while the purge stays available. Print the outlet duct in ASA, sized off step 1's surface measurement.
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
