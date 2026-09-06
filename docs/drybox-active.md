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
| **Silica gel / desiccant** | For the storage half, and **not optional if 5–15 %RH is the goal** — at 50 °C on room air the box bottoms out near 17 %RH, so desiccant is what closes the last gap rather than a refinement. **None is owned** — an order-history sweep found no desiccant or silica gel at all | ₪20–40 |

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

## 📐 The humidity floor — why heat alone cannot reach drybox numbers

**Measured reference, 4 Sep 2026: the printer room is 25.8 °C / 64.4 %RH.** (From the Sensibo in the
guest bedroom — the value is a `current_humidity` *attribute* on the climate entity, not a sensor
entity, which is why it is invisible to anything reading entity states.)

That number sets a hard limit on this design, because **a vented heated box cannot produce air drier
than the air it is fed.** It has no desiccant and no condenser in the loop; heating only lowers RH by
raising the air's capacity, so the *absolute* humidity coming in is the floor. Room air at 2.14 kPa
vapour pressure, reheated:

| Box temperature | Best achievable RH inside |
|---|---|
| 40 °C | 29 % |
| **50 °C** ← the chosen setpoint | **17 %** |
| 60 °C | 11 % |
| 70 °C | 7 % |

### The consequence: 50 °C dries well, but it will NOT hold a 5–15 %RH box

A working drybox sits at **5–15 %RH** — that is the figure the AHT20 was bought for, since a DHT11
floors at 20 %RH and physically cannot read one. At 50 °C on a day like today the active box bottoms
out around **17 %**, just *above* that range.

Both halves of the design are needed, and this is the number that proves it rather than asserting it:

- **Drying works.** 17 % against a 64 % ambient is a very steep gradient, and that gradient is what
  pulls water out of the spools. The active box does its job.
- **Storage cannot be done by heat.** Sealing a box that has just been flushed with 17 % air leaves
  it at 17 %, not at 5–15 %. **The desiccant is what closes that last gap**, which promotes it from
  "nice to have" to a required part of reaching the target — see the buy list.

### ⚠️ Track ABSOLUTE humidity, not RH — a worked example of why

Two readings of the same room, two days apart:

| | Room | Vapour pressure | Absolute | **Floor in a 50 °C box** |
|---|---|---|---|---|
| 4 Sep | 25.8 °C / **64.4 %RH** | 2.135 kPa | 15.5 g/m³ | **17.3 %** |
| 6 Sep | 24.7 °C / **68.6 %RH** | 2.130 kPa | 15.5 g/m³ | **17.2 %** |

**The RH rose by more than four points and nothing about the drybox changed.** The air holds
precisely the same amount of water; the room is simply cooler, because the AC was running, and
cooler air at the same moisture content reads a higher RH.

This is the trap in monitoring RH alone: **relative humidity is a ratio, and its denominator moves.**
A rising number can mean more water, or it can mean a cooler room. The quantity that sets what this
box can achieve is the **absolute** humidity of the air it is fed, which is unchanged here.

✅ **So the logging must capture temperature AND humidity together**, and the useful derived series is
vapour pressure or g/m³, not the raw RH. The Sensibo climate entity carries both, so this costs
nothing extra — but a dashboard showing RH alone would have reported a change that did not happen.

⚠️ **Do not read a single RH figure as good or bad news.** It was tempting to read 68.6 % as "the
floor moved up, the desiccant case got stronger". It did not move. The desiccant case was already
made and stands on its own.

### The floor over ten days of MEASURED room air

⚠️ **An earlier version of this section used hypothetical inputs — 50 % and 80 %RH at 25 °C — and
drew the wrong conclusion from them.** The recorder holds the real ones: **5760 paired
temperature+humidity points, 27 Aug → 6 Sep**, from the Sensibo climate entity's own recorded
attributes. Arithmetic below re-derived independently rather than taken on trust.

| | Room air | Vapour pressure | **Floor at 50 °C** |
|---|---|---|---|
| **Driest** seen (31 Aug) | 24.1 °C / 61 %RH | 1.83 kPa | **14.8 %** |
| **Moistest** seen (29 Aug) | 27.7 °C / 84 %RH | 3.12 kPa | **25.2 %** |

Note the two swings, because the difference between them is the whole point of the section above:

- **Raw RH swing: 26 points** (61 → 86 %) — mostly temperature, largely an artefact
- **Actual floor swing: 10.2 points** (14.8 → 25.2 %) — physical

### ⛔ The heated box alone never reaches the target band in this room

**The 25 °C / 50 %RH day the old table imagined does not occur here.** Over ten days the *single
driest sample on record* lands the floor at **14.8 %** — right at the top edge of the 5–15 % band,
with no margin — and every other sample sits above it.

So the conclusion is stronger than "desiccant makes storage weather-independent":

> 🔑 **Desiccant is not a refinement to the storage half. In this room it is what makes the storage
> half work at all** — heat and airflow alone cannot deliver the 5–15 %RH band, on any day yet
> recorded.

**This does not weaken the case for the heated box; it clarifies the division of labour.** The two
halves do different jobs and are sequential, not competing:

- **Heat + airflow = DRYING.** Its job is the *gradient*: ~17 % inside against ~65 % ambient is what
  pulls water out of a wet spool, and nothing passive achieves that.
- **Desiccant = STORAGE.** Its job is *holding* the result, in a band the airflow can never reach.

⚠️ **Caveat, and it is the honest one:** ten days is a single weather pattern in one season. It bounds
what this room *has* done, not what it will do. A dry winter spell could well drop the floor into
band — which is an argument for keeping the logging, not for discounting the finding.

⚠️ Israeli coastal humidity swings widely, and the box is worst exactly when filament needs it most.
**Log over time rather than trusting any spot value** — that is what the recorded Sensibo sensors
now provide, with 38 hourly rows accumulating since 4 Sep.

⚠️ **Do not respond to this by raising the setpoint.** 70 °C reaches 7 % on paper, and would also
deform spools and risk fusing windings — the reason 50 °C was chosen. The answer to the last few
points of RH is desiccant, not heat.

## Temperature limit

**50 °C, and do not chase 70.** Two independent reasons:

- **The spools.** PETG's glass transition is ~80 °C, but windings **fuse** well below it, and a
  welded spool is unrecoverable. The recorded schedule for the unbranded PETG is 50 °C for 4 h —
  inherited from Inslogic's TDS, since this filament publishes nothing of its own.
- **The box.** SAMLA is polypropylene. 50 °C is comfortable; pushing toward 70 risks lid warp, which
  would ruin the seal the *storage* half depends on. Breaking the passive box to speed up the active
  one is a bad trade.

## Regenerating the desiccant — bentonite specifically

Desiccant is not consumed, it is *filled*. Regenerating it means driving the adsorbed water back
off with heat. **Bentonite (montmorillonite clay) is not silica gel and the differences all matter.**

### ⚠️ The real hazard is dust, not heat

**Bentonite dust can contain respirable crystalline silica**, and bone-dry clay is far dustier than
damp clay — so the moment it is most hazardous is exactly when you have just finished regenerating
it. This is a genuine long-term respiratory hazard, not a nuisance.

- Handle it **outdoors or with ventilation**, wear a dust mask (**P2/N95 or better**) while pouring
  hot dry material, and let it settle before disturbing it.
- ⛔ **Never put loose bentonite in the drybox airstream.** The design has a fan pushing air through
  the box; loose clay in that path is a dust generator aimed at the room, and it would also foul the
  filament. **Contain it** — a breathable sachet, a fine-mesh bag, or a vented tub with fabric over
  the opening.
- Don't blow it clean with compressed air, for the same reason.

### Temperature — LOWER than silica gel, and the ceiling is real

| | Regenerate at | Do not exceed |
|---|---|---|
| **Bentonite / clay** | **~105–120 °C** | ~150 °C — above this the clay structure collapses and capacity is **permanently** lost |
| Silica gel (for contrast) | ~120 °C | ~150 °C for indicating types (the dye degrades first) |

The instinct is that desiccant should be baked hot. For clay it should not: **overheating does not
over-dry it, it destroys it**, and the damage is invisible until it stops working.

**Time: 2–3 hours at ~110 °C, spread THIN** — a single layer on a tray, not a heap. A deep pile
regenerates only at the surface and the middle stays wet, which is why "it was in there for hours"
is not evidence of anything.

### ✅ How to know it is actually done: weigh it

This is the only honest indicator, and it costs nothing.

1. Weigh the batch **once, right after a full regeneration** — that is its dry mass, recorded and
   reused forever.
2. Weigh it when it comes out of service to see how loaded it was.
3. Regenerate until it returns to the dry mass. **When the weight stops falling, it is done** — and
   further heat is only risk.

A clay desiccant holds roughly 10–20 % of its own weight in water, so a 500 g batch that comes out
60 g heavy is genuinely saturated and the change is easy to see on kitchen scales.

### Cool it SEALED, or you undo the work

Hot desiccant adsorbs fast. Left to cool in room air at ~65 %RH it will be measurably loaded before
it ever reaches the box. **Move it hot into an airtight container** — a jar with a metal lid, not a
plastic bag while hot — and let it cool closed.

### ⛔ Two things not to use

- **Not the printer's heated bed.** It reaches the right temperature, but it means abrasive
  silica-bearing dust on the PEI sheet and around the linear rails and leadscrews. Wrong place.
- **Not the drybox itself.** At 50 °C it is nowhere near the ~110 °C needed. **The active drybox
  cannot regenerate its own desiccant** — regeneration is always a separate operation with a
  separate heat source. Worth knowing before the build, because it is tempting to assume otherwise.

A kitchen oven at ~110 °C *is* acceptable here, and this is a real difference from filament: spools
are ruined by an oven's temperature swings, while bentonite tolerates ±20 °C around 110 without
harm. ✅ **Confirmed 6 Sep 2026: the material on hand is plain bentonite cat litter with no
additives**, so there is no fragrance, clumping agent or dust suppressant to bake off and an
ordinary oven is fine. The dust precautions above still apply in full — cat-litter bentonite is
often *dustier* than pelletised desiccant, not less.

### ⚠️ Bentonite may not reach the 5–15 %RH target

Clay is a **weaker desiccant than silica gel at low humidity**. Its adsorption isotherm is
favourable at high RH and flattens badly at low RH, so it pulls a box down efficiently from 65 %
but struggles to hold the low band. Expect it to settle somewhere around **20–35 %RH** rather than
5–15 %.

That is not useless — it is a large improvement over an undried box, and it is free if the material
is already on hand. But if the 5–15 % band is the actual goal, **silica gel is the right purchase**,
and indicating silica gel additionally shows its own state by colour rather than requiring the scale.
Bentonite is the sensible thing to start with and to learn the workflow on.

## 💡 A dehumidifier — upstream, never inside

The instinct is right and the placement inverts the answer. **Inside the box a household
dehumidifier is useless. Upstream of it, the same appliance is transformative.**

### ⛔ Inside the box: it cannot reach these humidities

A compressor/refrigerant dehumidifier works by condensing water on a cold coil, so **the lowest RH it
can hold is set by how cold that coil gets**:

| Target inside the box | Coil must sit below |
|---|---|
| 30 %RH at 25 °C | +6.2 °C |
| 20 %RH | **+0.5 °C** |
| 10 %RH | **−8.8 °C** |

Household units ice up and enter defrost around 0 °C, so the low band is not merely hard for them,
it is **physically out of reach**. They are also rated for roughly 5–35 °C ambient, and the drybox
runs at 50 °C — outside the envelope entirely.

✅ **Confirmed in this house, which is better evidence than the theory:** the Cave dehumidifier is
**set to 25 %RH, running, and the room is at 50 %.** It is not broken; it is at its limit. That is
exactly the flattening this table predicts.

*(A desiccant-rotor dehumidifier is the exception — those do reach low RH and work cold. But that is
a different appliance and a purchase, and it is essentially a machine that automates what the
desiccant tray already does.)*

### ✅ Upstream: the heating multiplies it, and this is the big lever

The box's floor is set by the **absolute** humidity of the air it is fed. Drop the room's humidity
and the floor drops with it — then the 50 °C heating multiplies the gain:

| Room at 25 °C | **Box floor at 50 °C** |
|---|---|
| 65 %RH *(measured today)* | 16.6 % |
| 55 %RH | **14.1 %** ← in band |
| 50 %RH | **12.8 %** |
| 45 %RH | **11.5 %** |
| 40 %RH | **10.2 %** |

**A dehumidifier that cannot get below 45 %RH — the very limitation that makes it useless inside the
box — is more than enough upstream to put the box comfortably inside the 5–15 % target.** It only
has to do the easy part of its range, which is the part it is good at.

⚠️ **This does not replace the desiccant.** Sealing the box always returns it to the *incoming* air's
RH once it cools — heat never helps storage, only drying. What a drier room does is make the
desiccant's job far easier: buffering against a 45 % room instead of a 65 % one, which is squarely
where bentonite's weaker isotherm still performs.

### ⛔ Do NOT close the loop — duct the OUTLET only

The natural next step is to duct both the dehumidifier's intake *and* its outlet to the box, so it
recirculates box air. **That is the one arrangement that performs worse than either alternative**, and
the reason is worth understanding because it is not obvious.

**Dehumidifying and heating are antagonistic in the same air.** Condensation needs the air *cold
enough* to reach the coil's dew point; low RH needs the air *hot*. Put both in one loop and they
fight — and the compressor loses, because a household unit is only rated to about **35 °C return
air**. The dehumidifier is also a **net heater** (all its electrical input plus the latent heat of
condensation ends up in the air), so a sealed loop drives itself toward the temperature that shuts
the compressor down.

Box temperature is exactly what buys low RH, so capping it at 35 °C throws away the main lever:

| Same dried air, coil at 5 °C | Box at | Result |
|---|---|---|
| closed loop — compressor's limit | 35 °C | **15.5 %** |
| | 40 °C | 11.8 % ← compressor cannot tolerate this return air |
| | 50 °C | 7.1 % ← nor this |

✅ **The fix is to use half the idea: duct the OUTLET to the box intake, and let the box exhaust to
the room.** That makes the two stages *sequential* rather than simultaneous — dehumidify at room
temperature where the unit works well, **then** heat, where the box works well.

| Arrangement | Box floor |
|---|---|
| Closed loop, box capped ~33 °C | ~17 % |
| Dehumidifier in the room, box on room air, 50 °C | 11.5 % |
| **Outlet ducted to the intake, box at 50 °C** | **~8 %** ← best, and it is half the plumbing |

The outlet air's absolute humidity is bounded below by saturation at the coil, roughly 0.9–1.2 kPa in
practice — **drier than the room average**, which is why tapping the outlet beats dehumidifying the
whole room volume.

**Practical notes, since this is now the recommended arrangement:**

- **No tight ducting needed.** A household unit moves 100–200 m³/h; the box wants ~18 m³/h. Simply
  **siting the box intake at the dehumidifier's outlet** captures the effect, and the surplus spills
  into the room — which helps the passive box and the shelves anyway.
- **The PTC is still required.** Outlet air is ~24 %RH at 30 °C; it is the *heating* that turns that
  into ~8 %. Neither stage reaches the band alone.
- **Condensate must drain**, or the tank fills and the unit stops — with a closed loop that failure
  is silent, because the box just quietly stops being dried.
- ⚠️ **A closed loop also ices.** As the air dries the latent load falls, the coil runs colder, and it
  frosts — after which the unit spends its time in defrost rather than drying.

### What this actually buys, and what it costs

**Two dehumidifiers are already owned** (Cave and Master Bedroom). Neither is in the printer room —
the guest bedroom, the one measured at 64–69 %RH. Moving or borrowing one is a household decision,
not a lab one.

The leverage is unusually good, because a drier *room* improves everything at once: the active box's
floor, the passive box's baseline, and every spool sitting out on a shelf. It is the single
highest-leverage change available here, and it needs no purchase.

⚠️ **One interaction to be aware of:** the chamber's negative-pressure extraction continuously pulls
room air out of the house, drawing replacement air in from outside. **A dehumidifier is fighting that
while a print runs.** Drying and printing need not overlap, so this is a scheduling note rather than
a conflict — but running both at once means the dehumidifier is working against a deliberate
ventilation system.

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
