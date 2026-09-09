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

## ✅ DECIDED 8 Sep 2026 — TWO fans, split by job

**Alon:** *"maybe the jumpeak should stay as the vent fan and the 40mm fans should be the
filters?"*

```
            ┌──────────── chamber ────────────┐
  makeup ──►│  (defined inlet, known area)    │
   air in   │   ┌──────────────────────────┐  │
            └──►│ ventobox: carbon + HEPA  │  │   recirculating scrubber
                │   2-3 × 40 mm, 24 V      ├──┘   (all flow returns)
                └──────────────────────────┘
            ┌────────────────────────────────┐
            └──► JUMPEAK 120 mm ──► duct ──► outside     the extraction
```

The **ventobox** scrubs continuously inside the chamber; the **JUMPEAK** pulls the bleed out
through the duct. Two jobs, two fans, each sized for its own load.

### ⚠️ Read the one-fan section below before assuming this is strictly better — it is not

The single-fan design was not a compromise, and **the argument that killed it is NOT "a 120 mm
fan cannot push a filter"**. This page already corrects exactly that: at 3200 RPM the JUMPEAK is
an industrial-class, high-static-pressure part, and that correction still stands. It could do
both jobs.

**What actually decides it is three things the one-fan design cannot give:**

1. **Independent extraction rate.** This page already names that as a two-fan trigger —
   *"if solvent work later wants extraction turned up independently of the recirculation rate"*.
   Splitting now buys it without a rebuild.
2. **The 40 mm fans and their model already exist.** `ventobox/` (54 × 122 mm, 40 mm class,
   downloaded 12 Apr 2026) is a complete carbon + HEPA tray stack with nothing else to do, and
   the two 24 V Gdstime fans were bought for it. The one-fan design needs a 120 mm Bento body
   printed instead.
3. **The heavy restriction stops fighting the duct.** Carbon trays plus HEPA in series with a
   duct bleed is one fan doing two dissimilar loads. Separating them means neither is a
   compromise, and the *"do not PWM it down far"* constraint below applies only to the vent fan.

### 📛 What this costs, stated plainly

- **Noise, and it lands the wrong way round.** 7000 RPM in a 40 mm frame is a screamer, and the
  scrubber runs *the whole print* while the bleed could be intermittent. Mitigate with duty
  (a scrubber does not need full rpm) and with the box being inside the enclosure.
- **No stall detection on the scrubber.** The Gdstime fans are **2-wire** — no tach, so a seized
  fan is indistinguishable from a running one. The single-fan design had the same blindness, but
  concentrated it in one part rather than two.

  > ✅ **AND THE SPLIT MAKES THIS LESS SERIOUS, NOT MORE — I had it backwards when I first wrote
  > this row.** This page's own principle is that *"with negative pressure the room is protected
  > by **containment and export**, not by adsorption"*. So the safety-critical fan is the one
  > holding the differential — **the extraction** — and that is the **JUMPEAK, which is 4-pin and
  > already has a tach**. A stalled scrubber degrades filtration; it does not break containment,
  > because the duct still pulls and makeup air still flows inward.
  >
  > Under the ONE-fan design the opposite was true: the single untached fan *was* the containment,
  > and losing it lost everything. **Splitting moved the safety function onto the fan that can
  > report on itself.** The scrubber's blindness is a quality-of-filtration problem, not a
  > containment one — worth fixing, not urgent. See *Adding stall detection* below.
- **A 24 V rail is now required** at the chamber. Nothing in the inventory makes 24 V; the
  printer's own PSU is the intended source (2–3 fans at ~0.1 A each against 240 W).
- **Fan count is unconfirmed** — 122 mm is almost exactly 3 × 40 mm and only two were bought.
  Count the apertures in the slicer; a third is ~₪12.71.

### 🔬 The measurement that would settle it

**Two 40 mm fans may not turn the chamber over fast enough.** That is the one real risk and it
is not answerable from a datasheet: build the ventobox, run it in the closed chamber, and use
the tissue test in *Verification* plus the temperature rise. If the scrubber cannot keep up,
the fallback is not a redesign — it is the one-fan architecture below, unchanged and still
correct.

### 🔧 Adding stall detection — five ways, ranked for THIS lab

Asked 8 Sep 2026. Ranked by fit with the constraint Alon set the same week — **no
micro-electronics soldering** — not by cleverness.

| # | Method | Parts | Verdict |
|---|---|---|---|
| **1** | **Buy 3-wire (tach) 40 mm 24 V fans** | ~₪15–25 | ⭐ **The answer.** Deletes the problem instead of instrumenting around it. Same 40 mm frame, so the ventobox tray is unaffected. No analog design, no soldering past connectors |
| **2** | **SPS30 particulate sensor** — measure the OUTCOME | **owned** | Best *engineering*, different question. See below |
| **3** | **Self-heated NTC in the airstream** | 1 NTC owned | A real airflow sensor: moving air cools a self-heated thermistor. Direct measure of *flow*, not rotation. Cheap, but analog and needs calibrating |
| **4** | **Acoustic** — MAX4466 mic + band-pass | **10 owned** | 7000 rpm × blade count ≈ a strong tone. Non-contact. But the printer is noisy, so it needs real signal processing to discriminate |
| **5** | **Current-ripple tach** | shunt + cap, owned | The clever one: a BLDC's supply current pulses at the commutation rate, so a shunt gives a true tach from a 2-wire fan. **But the ripple across a 1 Ω shunt at ~0.1 A is tens of mV** and needs amplification — exactly the analog bench work that is off the table |
| — | **SW-420 vibration ×5 owned** | — | ❌ Considered and rejected. It is a *shock switch*, not a vibration transducer: pot-set, hysteretic, and the printer vibrates anyway |

**⭐ Why option 2 deserves a look even though option 1 is the recommendation.** A tach proves the
**rotor turns**. It does not prove the air is being *cleaned* — it says nothing about a HEPA that
is unseated, a bypass leak, or carbon that has saturated. The **SPS30 (owned)** answers the
question you actually care about: chamber particulate should fall when the scrubber runs and rise
when it does not, whatever the cause. Two caveats: it is a **slow** signal (minutes, not seconds),
and there is **one** SPS30, already wanted for air-quality work — so this competes rather than
combines.

**The honest recommendation: buy the 3-wire fans.** ₪15–25 removes a known blindness with no
bench work, and it is the only option on this list that does not trade one unknown for another.
Do it when the ducting is ordered — that is the only other purchase left on this page.

---

## The one-fan alternative — ONE fan, split outlet *(superseded 8 Sep 2026, kept intact)*

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

> ✅ **That second trigger was pulled on 8 Sep 2026** — see the decision at the top. Note *which*
> reason applied: independent extraction control, plus two 40 mm fans and a matching model already
> in hand. **Not** because the bleed collapsed, and **not** because the JUMPEAK was found wanting.

## The fans — one each, and a correction that still stands

Since 8 Sep 2026 there are **two**, doing different jobs:

| | Fan | Duty | Rail |
|---|---|---|---|
| **Scrubber** | 2–3 × Gdstime 40 mm, 7000 RPM, **2-wire** | high restriction: carbon + HEPA | **24 V** — printer PSU |
| **Extraction** | JUMPEAK 120 mm, 3200 RPM, 4-pin PWM | low restriction: the duct | 12 V — PD trigger board |

Everything below is about the **JUMPEAK**, and the correction in it is the reason the split is a
choice rather than a necessity.

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
3. **Build the SCRUBBER** — `ventobox/` (base, carbon trays, HEPA tray, fan tray), the HEPA
   paper, the ENVIROCARB pellets, and the 40 mm Gdstime fans on a 24 V feed from the printer's
   PSU. Run it as a pure recirculator inside the closed chamber and **verify it turns the
   chamber over** — see *The measurement that would settle it*. ⚠️ Count the fan apertures in
   the slicer first: 122 mm is almost exactly 3 × 40 mm and only two fans are owned.
4. **Add the extraction** — the JUMPEAK on the duct, its own 12 V feed. Size the orifice, run
   the duct out. ⚠️ **Take the duct off the ventobox's clean side**, so what leaves the house is
   filtered air. That was free in the one-fan design and is now a plumbing decision.
5. **Cut the makeup inlet.** Known area, low, away from the filter intake.
6. **Tissue test, print running.** Adjust the orifice until inflow is unambiguous.
7. **Then** add the control node, the sensor, and HA integration — automation last, after the
   mechanical design is known good. A fan that is manually switched and correct beats an automated
   one that has never been verified.
8. ~~Add carbon when convenient.~~ **Carbon is in from step 3** — 20 kg of ENVIROCARB AP4-60 pellets are owned, and the ventobox has three carbon trays. It stopped being the deferred nice-to-have the moment it turned out not to need buying.

## Buy list

| Item | Priority | Note |
|---|---|---|
| ~~**Ducting**~~ + ~~a termination~~ | **Required** | 🛒 **DUCT SHORTLISTED 9 Sep 2026** *(the offer was time-limited — the duct is −53%, ₪16.88 at risk)*. ✅ **THE TERMINATION IS BEING PRINTED** — Alon, 9 Sep. Grille dropped; print it in **ASA**, see below — 100 mm × 2 m aluminium flex ₪14.96, plus a 100 mm stainless wall grille with insect mesh ₪17.94. **The diameter was not guessed** — see below |
| ~~**3-wire (tach) 40 mm 24 V fans ×3**~~ | **Recommended** | 🛒 **SHORTLISTED 9 Sep 2026** — variant `24V 3PIN FG` + `Ball bearing`, **₪15.19 each = ₪45.57**. ⚠️ **Two of this row's own claims were wrong; corrections below** |
| ~~**Activated carbon** media~~ | — | ✅ **REMOVED 8 Sep 2026 — ~20 kg is OWNED.** It was never in the order history, so no sweep could have found it; Alon reported it. The row is struck rather than deleted so the correction stays visible |
| — | | **Both fans, HEPA paper, 20 kg of carbon, control board and PD trigger are all owned.** Nothing on this page is unpurchased except the 24 V feed, which is a decision rather than a part |

### 🛒 What was bought, and the two things this buy list had wrong

**✅ The duct diameter came from a model already on disk, not from a guess.**
`OneDrive\3D printing\usefull\120mm+Fan+To+100mm+Pipe+Adaptor+-+Modern+Long.3mf` measures
**120 × 73 × 120 mm** — a 120 mm fan face tapering to a 100 mm pipe. So the owned JUMPEAK mates to
**100 mm** ducting through a part that needs *printing*, not buying. This row said *"length and type
depend on where it vents"* for a month; half of that was already answered on disk.

**⚠️ CORRECTION 1 — the price was out by 2–3×.** This row said *"~₪15–25"*, which read as the cost of
the lot. The real figure is **₪15.19 EACH**: ₪45.57 for three, against an estimate that implied ₪25
for three. Four searches found nothing cheaper in this specification — the two best candidates were
₪15.19 and ₪14.07, so this is the market price, not a bad pick.

**⚠️ CORRECTION 2 — the 3-wire fan does not exist in 4020, only 4010. That is a real trade, and this
row hid it.** The row said *"Same 40 mm frame, so the ventobox tray is unaffected"* — true, and about
**fit**. It is silent on **performance**. The owned Gdstime are **4020** (40 × 40 × **20** mm); every
3-wire 24 V unit found is **4010** (40 × 40 × **10**). Half the blade depth means materially less
airflow and, more to the point here, **less static pressure** — which is the one property a carbon +
HEPA stack actually consumes. So:

> 📌 **Do NOT treat these as a drop-in replacement for the owned 4020s.** Bench-test them against the
> Gdstime units on the built scrubber before committing. If the 4010s cannot hold flow through three
> carbon trays plus HEPA, the answer is to keep the 4020s and take a different stall-detection route
> from the ranked list above — the fans cost ₪45.57, which is cheap enough to be a test rather than a
> commitment.

**Why the tach fan is scarce at all — the same heuristic that read the INA226's shunt.** Fans compete
on airflow and price, and a tach wire adds cost while improving no headline number. So the 3-wire
variant is the one nobody markets, and in 4020 it appears not to be stocked at all. *A specification
that makes a product look no better in its headline number is one the market selects against.*

**✅ One thing that needs no hardware: the tach output is safe on a 3.3 V MCU even at 24 V.** It is an
open-collector transistor, so it pulls to whatever rail the pull-up resistor is tied to. Tie the
pull-up to **3.3 V** and the ESP32 reads it directly — **no level shifter, no divider.** The 24 V is
only the motor supply.

⚠️ **That is the convention, not a datasheet reading — verify before wiring.** These are no-brand ₪15
fans, and a totem-pole tach referenced to the 24 V rail would destroy an ESP32 GPIO. **Run the fan and
probe the tach pin with no pull-up attached:** near 0 V or floating → open-collector, wire it straight;
swinging to 24 V → divide it.

### ✅ THE TERMINATION IS BEING PRINTED — Alon, 9 Sep 2026. Do not buy one.

The ₪17.94 stainless grille is **dropped from the cart**. Nothing else changes: the duct is still
100 mm, still 2 m, still in the cart.

**No vent model exists on disk** — searched `vent` / `louv` / `grille` / `damper` / `flap` / `duct`
across the whole model library and the only hit is `ventobox/`. So this is a design-or-download job,
unlike the 120→100 adapter which was already there.

**🎯 PRINT IT IN ASA, and this is not a preference.**

| Material | Verdict |
|---|---|
| **ASA** — 2 kg owned | ⭐ **The right answer.** ~95–100 °C service and **UV-stable by design**. An exterior vent sits in direct Israeli sun; this is the material that exists for that |
| PETG — 10 kg owned | Workable, but it **yellows and embrittles under prolonged UV**. Fine for an indoor-side flange, poor for the outdoor face |
| PLA | ⛔ **No.** Softens around 60 °C. A dark vent in direct sun reaches that easily, and it sags into the duct bore |

⚠️ **ASA warps**, and a vent face is exactly the wide flat part that warps worst — but the LACK
enclosure this project is built around is the thing that fixes that. Print it closed.

**Three things printing buys that the bought part could not:**

1. ⭐ **A backdraft flap, free.** This page recorded that *nothing purchased had one* — fan off, the
   duct is an open path from outside into the chamber. A gravity flap is a trivial printed part and
   deletes that gap at zero cost.
2. **A proper insect screen.** A reviewer on the bought grille said its mesh was **coarse enough that
   they added their own behind it**. A printed part can capture real mesh in a designed seat.
3. **It mates to a part already modelled.** Match the **100 mm** bore of
   `120mm+Fan+To+100mm+Pipe+Adaptor`, and the fan → duct → vent chain is one consistent dimension.

**📋 What still gates it:** where the duct terminates. That decides the **flange shape** (wall plate
vs window panel) — not the bore, which is settled at 100 mm.

**📋 The superseded note, kept because it explains why a grille was ever in the cart:**
The bought termination assumed a permanent 100 mm penetration (an exterior wall, or a cut window
panel). If the plan is to hang the duct out of an open window, the grille is unnecessary — it is a
separate cart line precisely so it can be dropped without touching the duct.
⚠️ A reviewer on that listing notes the insect grid is **coarse** and that they added their own mesh
behind it. Worth a square of finer mesh if insects are a concern.
⚠️ **Nothing here has a backdraft flap.** With the fan off, the duct is an open path from outside into
the chamber. If that matters, an inline 100 mm check valve is ~₪10 and independent of where the duct
terminates — **not bought**, because a short duct with a running fan is the base case and this page
never called for one.

**📎 A second model on disk that this page should know about, and has not acted on.**
`usefull\Bento box 120mm fan.3mf` is a **140 × 140 mm** tray stack (trays 40/45/30/100 mm tall, plus
two tie rods) built around a **120 mm** fan — a complete alternative scrubber body to the 54 × 122 mm
`ventobox/`. It is recorded here, not adopted: the two-fan split was **Alon's decision on 8 Sep** and
this does not reopen it. But if the 4010 bench test above goes badly, this is the other end of the
design space and it is already modelled.
| **A 24 V feed** for the scrubber fans | **Required** | Nothing here makes 24 V — the PD trigger boards stop at 20 V. The printer's own PSU is the intended source: 2–3 fans at ~0.1 A each against 240 W. Free, if tapping it is acceptable |

## What is still open

- 📋 **The fan's real static-pressure figure**, from the listing rather than inferred from RPM.
- 📋 **Where the duct terminates.** A physical decision about the room that gates step 4. ⚠️ **Narrowed, not closed, 9 Sep 2026:** the *diameter* is settled at 100 mm by the adapter model on disk, and 2 m of flex is in the cart. What is still undecided is **wall vs window vs open window**, which decides only whether the ₪17.94 grille is used and whether 2 m is enough. **If the run is longer than 2 m**, a second length plus a coupler is needed — buy that with the termination once the room is chosen, not before.
- 📋 **Whether the Einsy tolerates a closed chamber.** The stepper drivers throttle when hot, so step 2
  measures the chamber and **the Einsy needs watching in the same run** — closing the box is what puts
  it at risk. ✅ **The PSU is already outside** (moved when the enclosure was built), which removes the
  larger of the two heat sources and makes a good result substantially more likely.

  ✅ **This needs no hardware.** The Einsy's own ambient thermistor is physically point B, and Prusa's
  firmware reports it in `M105` as **`A:`** (alongside `P:` for the PINDA). Close the box, run a
  print, read `A:` against the ~60 °C figure. **Do this before considering any relocation of the
  board or PSU** — it is a free measurement that decides whether a large, safety-sensitive job is
  needed at all.
