# The desiccant module — one part that bolts to any box or cabinet

**Alon, 16 Sep 2026:** *"We should make the desiccant area a module that we can simply attach to any
sort of cabinet or box."*

Right call, and it changes what gets standardised. [drybox-active](drybox-active.md) designs a
desiccant *area inside one box*, and [drybox-cabinet](drybox-cabinet.md) would design another one
inside a cabinet. Two builds, two sets of parts, and neither moves.

## ⭐ The standard is the PORT, not the module

The module cannot be universal, because boxes are not. What can be universal is the **hole it bolts
to**. Fix one port and every enclosure — the SAMLA box, a cabinet, a future dry bin — gets the same
hole, and every module fits every one of them.

```
        BOX WALL                      THE MODULE
   ───────────────────┐
                      │   ┌─────────────────────────────┐
     box air  ────────┼──►│ inlet + sensor              │
                      │   │   ↓                         │
                      │   │ desiccant cartridge(s)      │
                      │   │   ↓                         │
     dry air  ◄───────┼───│ fan + dust filter           │
                      │   └─────────────────────────────┘
   ───────────────────┘
          port: Ø62 bore, 4× M3 on a 70 mm square
```

**Port spec v1** — the only thing an enclosure has to provide:

| | |
|---|---|
| Bore | **Ø62 mm** (a 60 mm fan's throat, plus clearance) |
| Bolt pattern | **4× M3 on a 70 × 70 mm square**, symmetric, so orientation never matters |
| Panel thickness | **2–25 mm**, taken up by the clamp, not by the module |
| Seal | gasket ring on the module face; the clamp plate pulls it against the wall |

Two adapters share that pattern, so the **module body never changes**:

⚠️ **Self-regeneration adds a second path, and it changes which adapter is the default.** The module
now needs *two* ways out: the port into the filament area, and a **vent to the room** that only opens
during a purge. Without the second one there is nowhere for the water to go.

- **Bulkhead adapter** — needs a Ø62 hole cut, and is now the **standard** fitting rather than one of
  two options: it is what carries the vent through the wall.
- **No-cut adapter** — the module sits fully inside on pads or magnets. ⛔ **It cannot purge in
  place**, because a module that exhausts into the box it is drying is a machine for moving water in
  a circle. An internally mounted module is therefore either **absorb-only** — pulled out to be baked,
  the way the superseded plan describes — or given a short duct to a wall.

Both are modelled, along with the module itself, in
[`models/desiccant-module`](../models/desiccant-module/): a **bolted stack** of printed sections —
inlet lid, one bay section per cartridge, fan section — plus the port hardware (flange, clamp, and a
louvre plate that serves as the filament-side return grille). The stack is why capacity is additive:
a second cartridge is a second bay section and four longer screws.

📋 **The model does not yet carry the damper, the vent port, the servo mount or the heater pocket** —
those are the next revision, and the parts above are the v1 absorb-only stack until then.

## Capacity scales by adding modules, not by redesigning

From the arithmetic in [moisture-isotherms](moisture-isotherms.md): a 4 kg PETG load moving
65 → 15 %RH releases **17.2 g** of water, clay holds ~10 % of its mass (5 % pessimistically), and
real sizing wants 3–5× the bare minimum.

| Cartridge | Bentonite | Bare minimum it covers | Realistic (3–5×) |
|---|---|---|---|
| **1 cartridge** | **500 g** | ~50 g of water | one 4-spool box, comfortably |
| 2–3 cartridges | 1–1.5 kg | | a 22 L box with margin for ingress |
| 4–8 cartridges | 2–4 kg | | a 120–180 L cabinet |

**500 g is the cartridge unit** because it is what one printed carrier can hold without the bed
becoming deep enough to choke the fan. The envelope that actually holds it is
**130 × 130 × 45 mm**, and the model reports the figure rather than leaving it to be assumed:
[`models/desiccant-cartridge`](../models/desiccant-cartridge/) echoes **499 g** of clay at
0.8 g/cm³ and a 90 % fill.

⚠️ **This page first said 120 × 120 × 45, and that was wrong by 78 g.** The number came from
500 g ÷ 0.8 g/cm³ = 625 cm³ done by hand here — but **625 cm³ of clay needs more than 625 cm³ of
box**, because the walls, the four lid bosses and the 10 % of headroom the granules need all come
out of it first. The model's capacity echo caught it; the arithmetic in this paragraph did not.
Kept rather than quietly corrected, because the lesson is the reason the model echoes grams at all.

⭐ **When it has to grow, grow it sideways.** Reaching 500 g by deepening the bed to 53 mm works
arithmetically and is the wrong direction: pressure drop rises with depth and falls with
cross-section, so the deeper cartridge is the one the fan cannot pull through.

⚠️ **Shallow and wide, never long and thin.** Pressure drop through a packed bed rises with depth
and falls with cross-section. A 45 mm bed across a 120 mm face is something a 60 mm fan can pull
through; the same volume as a Ø50 × 320 mm tube is not.

## 🔑 The sensor goes on the INLET

Put it in the module's return path and it reads the air that has just left the desiccant — the
driest air in the system, and a reading that says the box is fine while the box is not. **The
sensor's job is to measure the enclosure**, so it sits at the inlet, in box air.

That also makes the module self-describing: each one reports the RH of the box it is plugged into,
so a box with two modules gives two independent readings of the same air — a free cross-check.

## The module regenerates itself — a servo, three positions, and a buffer

**Alon, 16 Sep 2026**, taking the FilaDC i10 as the inspiration: the module carries a servo damper
that *isolates the filament area and opens to the room* for a purge, *closes both* to cool down, and
*reopens to the filament area* to go back to work. A small amount of desiccant **stays loose in the
filament area** so its RH barely moves while the module is away.

⛔ **This supersedes the swap-the-cartridge plan below, which is kept because its reasoning is still
what constrains the design.** The earlier version of this page argued regeneration could not live in
a printed module, and the argument had one wrong premise.

### ⭐ What makes it possible: regeneration does not need 118 °C

[moisture-isotherms](moisture-isotherms.md) already records that **bentonite gives up moisture above
~50 °C** — the property that makes 50 °C the *ceiling* for a storage box is exactly the property a
regenerator wants. Full restoration of capacity is Clariant's 118 °C for 16–24 h and remains an oven
job; a **partial cycle at 70–85 °C with airflow** is what a self-regenerating unit actually does, and
it keeps every printed part inside ASA's 108 °C glass transition instead of demanding a metal
canister.

🔑 **And the air is the other half.** Room air at 25 °C and 55 %RH holds 1.74 kPa of vapour. Heat it
to 80 °C and its capacity rises to about 48 kPa — the **same air is now ~4 %RH**, far drier than the
cabinet it is serving. So the purge does not need dry air from anywhere; it needs *warm* air and a
way out.

### The cycle

| Phase | Filament side | Room side | Heater | Ends when |
|---|---|---|---|---|
| **Store** | **open** | closed | off | a purge is due, by RH or schedule |
| **Purge** | **closed** | **open** | on, 70–85 °C | the outlet air stops giving up water |
| **Cool** | closed | **closed** | off, fan on | the bed is back under ~35 °C |
| → Store | reopen | closed | off | — |

⛔ **The cool phase is not optional, and it is the one an obvious design leaves out.** Hot clay
*releases*; reopening a hot module to the filament area dumps both the heat and the moisture still in
that air straight onto the spools. Wait on a **measured** bed temperature, not a timer.

### ⭐ The buffer is what makes an imperfect valve acceptable

Leaving a sachet loose in the filament area does two jobs, and the second is the subtle one:

1. It holds the cabinet's RH while the module is isolated — the "temporary gap" — so a purge is not
   paid for in filament moisture.
2. It **absorbs the damper's leakage**. A printed valve does not seal like a solenoid, and without
   the buffer every gram that leaks in during a hot purge lands on the spools. With it, the failure
   mode of an imperfect seal is a slightly harder-working sachet rather than a wet cabinet.

Size it from the cabinet's measured **ingress rate**, not from a rule of thumb — which is what the
overnight sealed-RH log in the build order is for. As an order of magnitude: 100–200 g of clay holds
10–20 g of water at its nominal capacity, against the fraction of a gram a sealed cabinet admits in
an 8 h purge.

### 📏 The reference design, measured — and the defect the buffer targets

The inspiration is the **SUNLU / INSLOGIC FilaDC i10**. Figures below are from an independent test
rather than the vendor page, and they are someone else's product: useful as targets and as evidence,
not as our specification.

| Measured | |
|---|---|
| Holds | **15–16 %RH** by external logger (its own display reads optimistic); under 20 % in about half a day |
| Regeneration | **~40 min** per cycle, triggered when the desiccant can no longer hold the target — **not on a schedule** |
| Frequency | several cycles on day one with wet spools, tapering to about one every other day |
| Power | ~450 W peak, settling to **~60 W** while regenerating; **1–2 W** idle; ~35 kWh/year |
| Filament-area air during regeneration | **not above ~30 °C** |
| It genuinely dries | ten spools lost **27 g on day one, >60 g over 12 days** |
| It is not enough for | nylon, PPS, PPA, PEEK |

⭐ **And the one measured defect is exactly what the buffer is for:** *"Every time a regeneration
cycle runs, the humidity inside the cabinet spikes… lasting for around an hour."* A product that
isolates its desiccant but leaves nothing behind in the box pays for every cycle in cabinet humidity.
Alon's sachet is the cheap fix, and it is the one thing in this design the reference does not have.

📐 **Two numbers to design to, taken from that test:** the filament area must stay **≤30 °C** during a
purge — that is an acceptance criterion, not an aspiration — and **~60 W** is the right order for the
element, which the owned 12 V 50 W PTC meets.

### ⚠️ Their desiccant is not ours, and it decides the floor

The i10 uses a **molecular sieve**. [moisture-isotherms](moisture-isotherms.md) is explicit that
sieve is the only material that holds the 5–15 % band comfortably — and equally explicit that it
regenerates at **200 °C and above**, which no printed housing survives. That is how they reach 16 %.

**Clay regenerates at 70–85 °C and cannot reach that floor.** Its peak efficiency band is 30–60 %RH,
so a clay module should be expected to hold somewhere in the **25–35 %** region, not 16 %.

**For PETG that costs little and it is worth stating in grams**: the isotherm slope is 0.0086 % of
spool weight per point of RH, so holding 30 % instead of 16 % leaves about **1.2 g of water per kg**
— roughly 5 g across a 4 kg load. ⛔ **For nylon it would be a different verdict entirely**, and
nothing owned is nylon.

⭐ **So the material choice is really a choice about the regeneration hardware.** Clay keeps the
module printable and the element small; sieve buys the 15 % band and demands a metal chamber and a
much hotter element. Start with the clay that is already on the shelf, and treat the sieve as a
change of design rather than a change of fill.

**Sources:** [CNC Kitchen test](https://www.cnckitchen.com/blog/sunlu-filadc-i10-review) ·
[3Dnatives](https://www.3dnatives.com/en/sunlu-inslogic-filadc-i10-dehumidifying-cabinet-01092026/) ·
[VoxelMatters](https://www.voxelmatters.com/inslogic-and-sunlu-launch-filadc-i10-filament-dehumidifying-storage-cabinet/) ·
[vendor page](https://store.sunlu.com/products/filament-dehumidifying-cabinet-filadc-i10)

### ⚠️ What the servo adds to the safety case

The v1 module could not hurt anything: a fan and a sensor. This one has a heater behind a valve, so
two new failure modes exist and both are interlocks rather than warnings:

- **Heat with no way out.** The heater may run **only** when the damper is proven in the purge
  position *and* the fan is running. A servo has no feedback, so the position must be **sensed** — a
  microswitch at each end of the drum's travel — and *unknown position means heater off*.
- **Heat into the filament area.** Same interlock, opposite consequence: if the filament side is
  open while the heater runs, the module bakes its water into the cabinet.

The hardware ladder does not change and is not replaced by any of it: cutout in series with the
element, a one-shot thermal fuse above it, and a fused supply.

### 📋 The superseded plan, and why its reasoning still matters

> **v1 regenerated by swapping cartridges**: pull it, bake it, weigh it dry — the recorded mass is
> the only honest done-indicator, since regeneration is a curve and not a setpoint. The argument
> against in-place baking was that clay wants 118 °C, ASA softens at 108 °C, and a vent to outside
> plus an interlock proving it is open would be needed.

Two of those three are still true and now appear as requirements rather than objections: **the vent
and the interlock are in the design above**. The third — the temperature — was the wrong premise,
because it assumed full regeneration was the only useful kind.

⭐ **Swapping does not go away, it becomes the annual service.** A partial cycle at 80 °C leaves
residual loading that accumulates over many cycles, so the cartridge still comes out eventually for a
real bake and a weighing. Designing it to be swappable was right for a different reason than the one
originally given.

## Electrical and firmware interface

**Each module is its own node.** A C3, a sensor and a fan inside the module, powered by 12 V or 5 V
through one connector. Nothing in the enclosure has to know a module exists, which is what makes a
module portable between boxes.

| | |
|---|---|
| Power | 12 V (lever connector) or 5 V USB-C, 2 wires |
| Compute | ESP32-C3 — ten are owned |
| Sensor | SHT31 at **0x44**, or SHT40/AHT20 with a distinct address |
| Fan | 60 mm 12 V, PWM |

⚠️ **Two AHT20s cannot share a bus** — the address is fixed at 0x38 — so modules that may one day
share a controller get distinct parts. As separate nodes this does not arise, which is a second
reason the module carries its own board.

Firmware is a **package**, not a copy:
[`firmware/packages/desiccant-module.yaml`](../firmware/packages/desiccant-module.yaml), included by
a per-module file such as
[`firmware/desiccant-module-a.yaml`](../firmware/desiccant-module-a.yaml) that sets only the
substitutions. A second module is a five-line file, and a fix to the shared logic reaches every
module at the next flash.

What the package does:

- Publishes **inlet temperature, humidity and dew point** for the enclosure it is in.
- **Duty-cycles the fan** rather than running it continuously: a store needs circulation often
  enough to keep the air mixed and the reading honest, not constantly. Continuous running wears the
  fan, and in a sealed box there is nothing for it to do between cycles.
- Raises a **desiccant-spent** flag when inlet RH stays above a threshold for hours. This is the
  failure a passive box hides: the clay saturates silently, with no indication, which is precisely
  what [drybox-active](drybox-active.md) says is wrong with a passive box.
- Names every entity after **the enclosure**, never the board, so replacing a module does not strand
  the history.

## Build order

1. Print one cartridge carrier and one module body; fill a cartridge and **weigh it**.
2. Fit the no-cut adapter in the existing SAMLA box, flash a module, and log RH for a week against
   the box's current behaviour. That is the comparison that says whether forced circulation through
   a bed beats clay sitting in a tub.
3. Only then cut a port in anything.
4. Build the second module and put both in the same box — two readings of one air is the cheapest
   sensor validation available.

## What is still open

- **Fan choice.** 60 mm 12 V is the assumption above. The owned 40 mm units are 24 V, and the 12 V
  Delta 4020s are claimed by the scrubber.
- **Whether the cabinet's dryer and the module's fan share a port.** They are different jobs — one
  exhausts to the room, one recirculates — and combining them saves a hole at the cost of an
  interlock.
- **Cartridge retention.** Snap, screw or gravity. It has to survive being pulled hot.
