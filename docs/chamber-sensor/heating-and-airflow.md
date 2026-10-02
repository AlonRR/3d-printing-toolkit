# Chamber heat — extraction, recirculation, and a heater (§8)

*Part of the [chamber sensor](../chamber-sensor.md) notes.*

**In short:**

- **Fume extraction and a warm chamber pull against each other:** extraction exports the heat ASA
  needs.
- **Decided 4 Sep 2026: recirculate through the filter AND extract a little, so the chamber sits
  just below room pressure.** Every leak then flows inward, and the box only has to be closed, not
  sealed. It needs a closed enclosure, a defined makeup-air inlet, and a duct to outside.
- **One fan with a split outlet** — the owned high-pressure 120 mm fan — rather than two fans and a
  damper. The build itself is in [chamber-airflow](../chamber-airflow.md).
- **No second filter in the exhaust duct:** the recirculation loop has already cleaned that air.
- **No chamber heater yet:** the bed is already a ~200 W heater inside the box, and a heater would
  need its own hardware over-temperature cutout.

## The conflict: extraction against chamber heat (§8)

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
([fdm-design-rules §6a](../fdm-design-rules.md#6a-joining-two-printed-parts)). A design that can
*only* recirculate keeps ASA solvent welding and vapour smoothing permanently unavailable — a
bigger consequence than it looks while drawing ducts.

## The decision, 4 Sep 2026: recirculate and extract, at negative pressure

**Alon's ruling, and it is a third option neither this page nor the homelab page considered:** during
a print, run the recirculating filter **and** a small continuous extraction, sized so the chamber
sits slightly **below room pressure**.

**Why this is better than either thing that was being argued.** The recirculate-only proposal below
cleans the chamber air but does nothing about *leakage* — a Lack enclosure is not airtight, and fumes
escape through every gap regardless of how clean the air inside is. Extract-only exports the chamber
heat that [asa-print-quality](../asa-print-quality.md) is trying to build. Negative pressure resolves
both at once, and it is the principle fume hoods, biosafety cabinets and cleanrooms all run on:
**below ambient, every leak flows INWARD.** The enclosure no longer has to be sealed to contain
fumes — it only has to be closed enough that a modest extraction can hold the differential.

### What it requires

- ⚠️ **The enclosure must actually be closed.** This is the one hard prerequisite. With a side
  left open there is no differential to hold — the flow required scales with the leakage area,
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

### The mechanical design — one fan with a split outlet, no damper

*First written for two fans; corrected the same day to one, because the owned fan is a
high-static-pressure part. The correction follows the first version.*

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
downstream side of the HEPA. The full build is in [chamber-airflow](../chamber-airflow.md).

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

A recirculate-only build was recorded above as closing the door on ASA solvent welding and vapour
smoothing, which need real extraction. **This design keeps that door open**, since an extract path
now exists — turn the extraction up for solvent work rather than rebuilding for it.

## Superseded: recirculate during the print, vent afterwards

*Kept because the decision above answers it. This was the proposal before 4 Sep 2026.*

**Proposed design, and it is a change of plan, not a reading of the existing one:** recirculate
during the print, vent afterwards. One fan, one filter, a switchable outlet — a damper or a
movable duct — decided now rather than reprinted later.

⚠️ **Every existing document says extraction, and none of them treats recirculation as an
option.** The homelab page is titled *Fume extractor*; `CLAUDE.md` says *"Filter project (fume
extractor)"*. Flagged on 30 Aug 2026, and rightly so: it has to be
settled before parts are printed. **This section argues for a change; it does not record a
decision.** Until Alon rules on it, the documented plan is extraction, and the reason to consider
recirculating at all is that an extractor removes the very chamber heat
[asa-print-quality.md](../asa-print-quality.md) is trying to build up.

## No second filter in the exhaust duct

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

## A chamber heater — not yet, and not only for cost

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
