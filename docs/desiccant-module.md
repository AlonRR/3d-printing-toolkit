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

- **Bulkhead adapter** — needs a Ø62 hole cut. Used where the module must also vent *outside* the
  box, which regeneration requires.
- **No-cut adapter** — the module sits fully inside, on VHB pads or magnets, and the port is blanked.
  For boxes nobody wants to drill. Storage only.

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

## ⛔ Regeneration stays out of the module, v1

Baking the clay in place, with the moist air vented outside, is the obvious next feature and it is
deliberately **not** in v1:

- **Clay wants 118 °C for 16–24 h** (Clariant's own Desi Pak procedure), and the rule is **bake
  longer, never hotter** — above ~300 °C capacity is destroyed permanently.
- **ASA's glass transition is 108 °C.** A printed carrier cannot hold the bed at regeneration
  temperature. In-place regeneration therefore needs a metal canister, insulation, and a printed
  housing kept well below the bed temperature — a different part, not a firmware flag.
- It also needs the port to vent **outside** the enclosure and an interlock proving that vent is
  open, or the module bakes its water straight back into the box it is drying.

**So v1 regenerates by swapping cartridges**: pull the cartridge, bake it, weigh it dry — the
recorded mass is the only honest done-indicator, since regeneration is a curve and not a setpoint —
and put a spare in meanwhile. The cartridge being the swappable unit is what makes that cheap, and
it is why the cartridge, not the module, is the thing with a standard size.

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
