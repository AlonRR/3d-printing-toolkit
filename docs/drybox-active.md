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

### ⛔ PRINT THE DUCT IN ASA, NOT PETG — and the numbers now say why

The build step already specifies ASA. This records the reason, because **the lab holds 10 kg of
PETG and none of the parts list says "not this one"** — which is exactly how a substitution happens
at the bench.

Glass transition is the number that matters. A part does not need to melt to fail; it needs to
creep under its own load while warm, and that starts at T₉:

| | T₉ | Heat deflection @ 0.45 MPa | Margin over a 50 °C duct |
|---|---|---|---|
| **ASA** | **108 °C** | 98 °C | **~58 °C** — comfortable |
| PETG Pro | 65.5 °C *(see caveat)* | 72 °C | ~15 °C — thin |
| PLA Pro | 65.3 °C | 55.0 °C | ~15 °C, and worse under load |

Source: [inslogic-filament-data](../slicer/reference/inslogic-filament-data.md).

⚠️ **The PETG figure is the vendor's own and it is internally inconsistent.** Its sheet gives
T₉ 65.5 °C but a heat-deflection temperature of 72 °C — and for an amorphous plastic HDT sits
*below* T₉, which is what ASA (108/98) and PLA (65.3/55.0) both do. Published PETG T₉ is usually
78–85 °C. **Treat 65.5 as conservative rather than correct, and do not design to either number.**

📏 **The duct is not the only warm part in this lab.** The same table applies anywhere a
printed part sits in measured heat:

| Location | Measured | PETG margin at T₉ 65.5 |
|---|---|---|
| Chamber during a print | 38–40 °C | ~25 °C |
| **Einsy bay** | **50–51 °C** | **~15 °C** |
| Drybox target | ~50 °C | ~15 °C |

**Load-bearing PETG above 40 °C wants checking after a long print**, not assuming. Unloaded clips
and covers are fine; anything carrying weight or holding an alignment is not obviously fine.

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

### ✅ RESOLVED 9 Sep 2026 — five in the cart, two already owned

⚠️ **This was a live buy list until 9 Sep and is no longer one.** It had gone stale in a specific
way worth naming: the resolution was written into the **inventory** repo
(`docs/shopping-list.md` §7, 7 Sep) and never back to this page, so this page kept sending readers
shopping for parts that were already handled. **Inventory's shopping list is the source of truth for
status; this table is the source of truth for the SPECS**, which is why the reasoning column is kept
rather than deleted.

| Part | Status | Why the spec is what it is |
|---|---|---|
| **12 V 6 A adapter** — ₪32.53 | 🛒 **in cart** | Sized for **inrush, not steady state**: 4.2 A running, and a cold PTC pulls 2–3× on startup |
| **2× single-channel 15 A MOSFET** — ₪8.92 | 🛒 **in cart** | ⚠️ **Not a relay** — a relay cannot PWM, and PWM soft-start is what handles that inrush. See the "dual" trap below |
| **KSD9700 cutout** — ₪8.94 | 🛒 **in cart** | In series with the element. Not optional |
| **One-shot thermal fuse, 85 °C** — ₪4.45 | 🛒 **in cart** | The non-resettable backstop *above* the cutout, since a KSD9700 resets and a real fault would cycle and mask itself. The ladder has no 84 °C; 85 satisfies it |
| **Inline fuse holder + 7.5 A fuse** — ₪4.08 | 🛒 **in cart** | 14 AWG holder. Protects the wiring, not just the supply's internal limit |
| ~~Screw terminals / XT30~~ | ✅ **OWNED** | **A.R ESCO UC 03M lever connectors ×92**, 450 V / 24 A, 0.2–2.5 mm². Against 4.2 A that is **5.7× margin**. The original point stands — Dupont housings are 1–3 A and unusable here |
| ~~DC barrel socket~~ | ✅ **OWNED** | Female DC adapter, 2.1 mm jack to screw terminal. ⚠️ **But measure the plug first — see below** |
| ~~18 AWG silicone wire~~ | ✅ **OWNED** | The 4 m of 3-core is 1.37 mm = ~15.5 AWG, heavier than specified |
| ~~Silica gel~~ | ✅ **OWNED, better** | The bentonite outranks it at low RH |
| ~~Molecular sieve~~ | ⛔ **EVALUATED 12 Sep 2026 — NOT BOUGHT** | The material [moisture-isotherms](moisture-isotherms.md) already names as the only one holding 5–15 %RH *comfortably*, and **86 g would do what 0.5–1.5 kg of clay does**. Declined anyway: **nothing owned needs that band** — holdings are PETG ×11, TPU ×4, ASA ×2, PLA ×1, **no nylon/PVA/PC** — and because **PETG's isotherm is linear**, 15→5 %RH recovers only **~3.4 g** on a 4 kg load. Its vendors specify a **200–550 °C furnace with a purge gas**; only hobby sources claim a home oven works. ~$20–35/kg, so cost was never the objection. ⭐ **Buy nylon or PC and this flips — and then 4A, NOT the 3A every guide names** (3A wins only below 0.03 kPa ≈ 1 %RH; a drybox runs 10–15× above that). Full reasoning: inventory `docs/shopping-list.md` §31 |

### ⚠️ Two traps found while buying, neither visible from a spec

**1. "Dual" MOSFET means two devices on ONE channel, not two channels.** A board sold as *"Dual
High-Power MOSFET Trigger"* puts two MOSFETs **in parallel switching a single load** — it is a
current rating, not a channel count. This page previously asked for a "2-channel MOSFET module",
which would have bought exactly the wrong thing and only revealed itself at wiring time.
**The heater and its fan must switch independently**, so that is **two single-channel boards**, not
one dual. Bought as 2 × single-channel 15 A.

*(A 2-channel **relay** module was in the cart and has been removed — a relay cannot PWM, so it
cannot soft-start.)*

**2. 📏 MEASURE THE BARREL PLUG BEFORE WIRING.** The owned socket is **2.1 mm ID**. Cheap 12 V
bricks ship as **5.5 × 2.1 *or* 5.5 × 2.5**, and the adapter listing does not state which. **A
2.5 mm plug in a 2.1 mm socket is an intermittent joint carrying 4.2 A** — which is a heating
connection, not merely a loose one. If it turns out to be 2.5, the fix is a ₪3 socket, not a
redesign. This is not a purchase; it is a thirty-second check that has to happen before the first
power-up.

### Also in the cart, for other pages

**DS18B20 ×2**, ₪5.87 each, variant `1M and module` — the [chamber-sensor](chamber-sensor.md) bay
probe. ⚠️ **That listing defaults to `TO-92`**, the bare chip with no cable, despite advertising the
waterproof probe; `1M and module` is the stainless probe on 1 m of cable **plus the terminal board
carrying the 4.7 kΩ 1-Wire pull-up**.

⚠️ **Do the free measurement first.** The Einsy question needs no hardware at all — the board's own
ambient thermistor *is* the point of interest, and Prusa reports it in `M105` as **`A:`**. Close the
box, print, read it against ~60 °C. The probes are worth having regardless, but if they arrive and
get used *instead* of that reading, a two-day wait was bought for nothing.

## 🔋 This decision deletes the battery node — and its whole central problem

`homelab/docs/manual/battery-sensor-node.md` designs a **battery-powered** ESP32-C3 humidity node
for this box. **Making the box active invalidates its premise**, and the doc says so itself, in a
correction that has since been overtaken:

> *"**Corrected 22 Aug 2026.** An earlier version of this page argued the drybox was probably heated
> (from the owned PTC heater + 40 mm fans) and that the node should therefore run off the box's
> supply and need no battery. **That was wrong: the PTC heater is for the printer enclosure.**"*

That correction was **right when it was written** — the heater was allocated to the enclosure then.
But **Alon reallocated the PTC to this drybox on 3 Sep 2026**, so the rejected inference is now
simply true, arrived at from the other direction and by decision rather than by guess.

### What that removes

The doc's design is driven by one constraint:

> *"**The consequence that should drive the design: every recharge opens the box.** A passive drybox
> works by being sealed. Recharging means opening it, which admits humid room air and puts a load on
> the desiccant — so a charge is not just an inconvenience, it is a **humidity event**."*

**An active box has a 12 V supply in it anyway.** Feed the node from that through an owned TPS63020
and the recharge disappears, and with it the humidity event, the battery sizing exercise, the
chemistry decision, and the fuel-gauge question.

⛔ **Do not buy** the LiPo/18650 + holder, the protected TP4056, the `R_PROG` resistor or the
MAX17048 **for this box**. They were the right answer to a problem this project has removed.

### It composes with the sensor-placement rule, and that is what makes it clean

[chamber-sensor](chamber-sensor.md) already requires the **node outside the enclosure with a short
I²C tail to the sensor inside**, because a board that self-heats next to its own sensor reads warm
and dry — biased toward exactly the "no heater needed" conclusion the project exists to test.

Applied here: **the node never enters the box.** It mounts outside, next to the heater assembly and
its supply, and only a thin I²C tail passes through the wall. So there is no cable gland problem, no
board in a humid box, and nothing to open the box for.

⚠️ **One wiring consequence to get right:** leave the 12 V supply permanently connected and switch
only the **heater and fan** with the 2-channel MOSFET module. If the supply itself is switched, the
sensor dies whenever the box is merely storing — which is precisely the period the AHT20 exists to
watch, since storage RH is what says whether the desiccant is still working.

**Sensor is already settled and owned:** AHT20 + BMP280 (arrived 2 Sep). The DHT11 cannot be used —
it floors at 20 %RH and a working drybox sits below that.

## Build order

1. Bench the heater assembly on the new supply, **fan running**. Record outlet air temperature, outlet surface temperature, total current, and how long each takes to settle.
2. Mod and measure one C3, far-end, against an unmodified control.
3. ⚠️ **Check the MOSFET module's control polarity and fit the pull-down BEFORE wiring the heater**,
   so the default state with no firmware running is OFF. Then wire it: cutout **and the one-shot
   thermal fuse** in series with the element, and **the heater switch's control power taken from the fan's switched output** so heater-without-fan is physically impossible while the purge stays available. Print the outlet duct in **ASA, not PETG** — see the T₉ table above — sized off step 1's surface measurement.
4. Cut intake and exhaust vents — exhaust **high and diagonally opposite** the intake.
5. Wire the AHT20 out of the airstream; bring temperature and humidity into HA over MQTT, reusing the
   plumbing the camera node already has.
6. **Prepare the desiccant — it is a prerequisite, not an afterthought.** Regenerate the bentonite
   spread thin. ⭐ **Regeneration is a CURVE, not a setpoint** *(Alon, 12 Sep 2026)* — release begins
   ~90 °C, **~80 % is driven off at 120 °C**, full regeneration ~150 °C. So ~110 °C for 2–3 h is a
   fine working point, not a magic number. ⛔ **BAKE LONGER, NEVER HOTTER — corrected 12 Sep 2026.**
   Capacity rises to ~300 °C then **falls irreversibly**; Clariant specify 118 °C for 16–24 h.
   An earlier version of this step said hotter was safe, which was wrong. **Weigh it dry and record that mass** — *the only honest
   done-indicator*, and now the load-bearing one, since temperature alone cannot say how far along
   the curve you got. Cool it in a sealed jar, and **put it in a sachet or fine mesh — never loose in
   the airstream**, which is a fan pointed at the room and clay carries respirable silica. Sizing:
   **0.5–1.5 kg**, from the isotherm arithmetic in
   [moisture-isotherms](moisture-isotherms.md).
7. **Run it open-loop first, with the cutout as the only protection**, watching the sensor, before any
   automation closes the loop. A safety feature that has never been seen to fire is not one.
8. **Only then close the loop** — heater modulated against the AHT20, fan continuous, and the
   cooldown purge on the end of the cycle.

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
