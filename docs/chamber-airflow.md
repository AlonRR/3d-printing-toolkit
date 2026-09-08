# Chamber airflow — the complete filter and extraction plan

**The build that follows from the 4 Sep 2026 decision** in [chamber-sensor](chamber-sensor.md):
recirculate through a filter during a print, **plus** a small continuous extraction, so the chamber
sits slightly below room pressure and every leak flows *inward*.

This page is the plan. The reasoning behind the decision lives in `chamber-sensor.md`; this is what
gets built, in what order, with what.

## The principle in one line

**Containment comes from negative pressure, not from sealing.** A Lack enclosure will never be
airtight. Below ambient, that stops mattering — air moves in through the gaps rather than fumes
moving out — so the enclosure only has to be *closed enough* for a small extraction to hold the
differential.

## Architecture — ONE fan, split outlet

The obvious reading of "recirculate and extract" is two fans. It does not need to be, and one fan is
better here:

```
            ┌──────────── chamber ────────────┐
            │                                 │
  makeup ──►│  (defined inlet, known area)    │
   air in   │                                 │
            │   ┌───────────────────────┐     │
            └──►│ HEPA (+carbon) │ FAN  ├──┬──┘  most of the flow returns
                └───────────────────────┘  │     to the chamber
                                           │
                                           └──► metered bleed ──► duct ──► outside
                                                (the extraction)
```

The fan pulls chamber air through the filter stack. **Most of the filtered air returns to the
chamber; a metered fraction bleeds out the duct.** That bleed *is* the extraction, and the chamber's
mass balance does the rest: air leaves via the duct, so air must enter via the makeup inlet, so the
chamber sits below ambient.

**Why this is the right shape:**

- **It uses the fan already owned**, and needs no second fan purchase.
- **The extracted air is already filtered** — it comes off the *downstream* side of the HEPA. That
  satisfies the "don't vent dirty air" instinct without a second filter in the duct, which
  `chamber-sensor.md` already argues against on static-pressure grounds.
- **The split ratio is set mechanically, once** — an orifice, not a servo. Nothing to control.
- **Precision does not matter.** Containment needs *net inward flow at the inlet*, not a target
  pascal figure. Any bleed large enough to exceed the inlet's leakage gives containment; the design
  is forgiving by construction.

**When to go to two fans instead:** if the duct turns out long or restrictive enough that the bleed
collapses, or if solvent work later wants extraction turned up independently of the recirculation
rate. Treat that as an upgrade with a known trigger, not a thing to build first.

## The fan — and a correction

**JUMPEAK 120 mm, 12 V, 4-pin PWM, 3200 RPM, ₪36.51, owned.**

⚠️ **`chamber-sensor.md` said "a 120 mm axial produces only tens of pascals". That is true of ordinary
case fans and NOT of this one.** 3200 RPM on a 120 mm frame is the high-static-pressure signature —
ordinary case fans run 1200–1500 RPM, and static pressure scales roughly with the square of RPM. This
is an industrial-class fan, which is exactly what a filter stack plus a duct bleed needs.

That correction matters twice: it is what makes the HEPA loop viable at all, and it is what lets a
single fan also push the duct bleed.

📋 **Still worth capturing: the actual mmH₂O figure from the listing**, rather than inferring it from
RPM as this page currently does. Reasoning from a specification is better than reasoning from a proxy,
and this lab has been bitten by titles before.

⚠️ **Do not PWM it down far in normal running.** Static pressure falls with RPM², so quietening the
fan attacks the bleed and the filter flow much faster than it attacks the noise. If it is too loud,
solve that with mounting and duct design, not by throttling the thing the design depends on.

## Filtration — what each layer is actually for

| Layer | Catches | Status |
|---|---|---|
| **HEPA** | **Ultrafine particles** — the main measured hazard from printing ASA/ABS | ✅ **Owned**: HEPA paper, 300×1200 mm, 20 mm folds |
| **Activated carbon** | **VOCs, including styrene** — the gas-phase hazard from ASA/ABS | ✅ **OWNED — ~20 kg**, air-filtration grade. Alon, 8 Sep 2026. ~~Not owned — a purchase~~ |

**HEPA does nothing about gases, and carbon does nothing about particles.** They are not alternatives.

⚠️ **Sharpening a point `chamber-sensor.md` half-makes.** That page says carbon "buys little", but it
is arguing about **acetone** — for solvent welding — and it is right there: carbon adsorbs acetone
poorly and saturates fast. **Styrene is a different molecule and a different case.** It is the gas
that ASA and ABS actually emit while printing, it is aromatic and heavy, and carbon adsorbs it well.

So the two conclusions coexist:

- **For printing:** carbon earns its place, for styrene.
- **For solvent work:** carbon is not the answer — extraction is. Which this design now has.

Carbon is nonetheless the **lowest-priority** item here, because with negative pressure the room is
protected by *containment and export*, not by adsorption. Build HEPA-only first; add carbon when
convenient.

## The makeup-air inlet — a real component, not a gap

**Give the chamber one deliberate opening of known area.** Do not rely on incidental seams.

- It makes inward flow **predictable**, and lets the bleed be sized against something known instead
  of against the sum of every unknown gap.
- It gives a **single place to verify containment** (see below).
- **Small is good.** Containment is about *face velocity*, ~0.5 m/s inward by fume-hood practice, and
  Q = v × A. A 10 × 10 cm inlet at 0.5 m/s is only ~18 m³/h — far below this fan's capability. **The
  small inlet is what makes the small extraction sufficient**, and it is also why the makeup air
  costs the chamber very little heat.
- Put it **low and away from the filter intake**, so incoming cool air crosses the chamber rather
  than short-circuiting straight back into the fan.

### ⭐ Site the inlet so the makeup air washes the electronics first

**This is close to free, and it may remove the whole reason to relocate the Einsy.**

The negative-pressure design *requires* a continuous inward flow of room-temperature air. **The Einsy
is inside the Lack frame** and is the part most at risk from closing the box — ⚠️ the **PSU is already
outside**, moved there when the enclosure was built, so target the inlet at the Einsy specifically
rather than at a general "electronics bay" —
[asa-print-quality](asa-print-quality.md) warns not to seal it for exactly this reason, and
`chamber-sensor.md` puts Einsy trouble at around **60 °C**.

Put the inlet at the electronics bay, and that incoming air becomes **forced cooling of the
electronics on its way in** — the coolest air in the system meeting the most heat-sensitive parts
first, before it picks up any chamber heat. The airflow has to exist anyway; siting it well costs a
hole in a different place.

It also improves the chamber side: air entering at the bay is well away from the filter intake, so it
crosses the volume rather than short-circuiting.

**Order of operations matters here.** Measure the bay first (below), then site the inlet, then
re-measure. If bay cooling turns out to be the inlet's real job, that should shape where it goes
while the choice is still free.

## The duct

- **It must terminate somewhere that is not the room.** Extraction that vents indoors is
  recirculation with extra steps.
- **Keep it short and straight.** Every bend costs static pressure, and the bleed is the first thing
  to suffer.
- **No filter in the duct.** Already argued in `chamber-sensor.md`: the air has been through HEPA
  many times over the print, and an axial fan cannot push a HEPA element in series anyway.

## Control and sensing

**A dedicated node — explicitly NOT the S3 camera.** Reasoning recorded on 3 Sep 2026: the camera is
the busiest and least reliable subsystem, it gets reflashed constantly (a dozen times in one day
during development), and fume extraction is a health function that must not reboot because someone
was iterating on JPEG code. Its position is chosen for optics, not for cable routing to fans.

| | |
|---|---|
| **Board** | An **ESP32-C3** — ten owned. ⚠️ SuperMini, so the [§3x antenna mod](chamber-sensor.md) comes first, and has not been done on any board yet |
| **Sensing** | Chamber temp + RH, on **its own** sensor, sited away from the fan. The camera's DHT11 reads high from self-heating and is the wrong input for a control loop |
| **Outputs** | One PWM channel for the fan. **No damper servo** — the split is mechanical |
| **Integration** | MQTT to HA, same plumbing the camera node already uses |

⚠️ **Local fallback is mandatory.** The fan must run on the node's own logic when HA or the network
is down. **Do not put a broker round-trip in the path of breathing air.** HA is for orchestration,
logging and convenience — it is not the control loop.

## Verification

**Hold a strip of tissue at the makeup inlet. It should be drawn in.** That is the acceptance test.

⛔ **Not the BMP280.** The differential is a few pascals against ±100 Pa absolute accuracy, and a
two-sensor differential would have one unit at chamber temperature and one at room temperature with
temperature-dependent offset swamping the signal. The tissue is not a shortcut here; it is the
better instrument.

Run it **before** trusting any automation, and run it **with the print running**, since that is the
condition it exists for.

## Build order

1. **Close the enclosure.** ⚠️ This is the hard prerequisite — with a side permanently open there is
   no differential to hold, because that is not leakage, it is a duct. It is also build-order step 2
   of `chamber-sensor.md`, still outstanding.
2. **Measure the closed chamber temperature**, against the open-configuration baseline already
   recorded (31 °C ± 2, door open, 3 Sep 2026). This is the number that decides whether a chamber
   heater is ever needed — answer it before buying one.
3. **Build the filter box** (`Bento box 120mm fan.3mf`, HEPA paper, the JUMPEAK) as a pure
   recirculator. Verify airflow.
4. **Add the bleed and the duct.** Size the orifice, run the duct out.
5. **Cut the makeup inlet.** Known area, low, away from the filter intake.
6. **Tissue test, print running.** Adjust the orifice until inflow is unambiguous.
7. **Then** add the control node, the sensor, and HA integration — automation last, after the
   mechanical design is known good. A fan that is manually switched and correct beats an automated
   one that has never been verified.
8. Add carbon when convenient.

## Buy list

| Item | Priority | Note |
|---|---|---|
| **Ducting** + a termination | **Required** | Length and type depend on where it vents |
| ~~**Activated carbon** media~~ | — | ✅ **REMOVED 8 Sep 2026 — ~20 kg is OWNED.** It was never in the order history, so no sweep could have found it; Alon reported it. The row is struck rather than deleted so the correction stays visible |
| — | | The fan, HEPA paper, control board and PD trigger are **all owned** |

## What is still open

- 📋 **The fan's real static-pressure figure**, from the listing rather than inferred from RPM.
- 📋 **Where the duct terminates.** A physical decision about the room that gates step 4.
- 📋 **Whether the Einsy tolerates a closed chamber.** The stepper drivers throttle when hot, so step 2
  measures the chamber and **the Einsy needs watching in the same run** — closing the box is what puts
  it at risk. ✅ **The PSU is already outside** (moved when the enclosure was built), which removes the
  larger of the two heat sources and makes a good result substantially more likely.

  ✅ **This needs no hardware.** The Einsy's own ambient thermistor is physically point B, and Prusa's
  firmware reports it in `M105` as **`A:`** (alongside `P:` for the PINDA). Close the box, run a
  print, read `A:` against the ~60 °C figure. **Do this before considering any relocation of the
  board or PSU** — it is a free measurement that decides whether a large, safety-sensitive job is
  needed at all.
