# Desiccant module

The stack that carries [desiccant cartridges](../desiccant-cartridge/), pulls box air through them,
and **regenerates itself** by sealing the filament area and baking the bed out to the room. Design
and reasoning: [`docs/desiccant-module.md`](../../docs/desiccant-module.md).

```
   lid              a plain cap - it turns the flow from the riser into the bed
   bay section      one cartridge; ADD A SECTION PER CARTRIDGE
   [filter sheet]   HEPA paper, clamped between sections - not printed
   fan section      plenum and fan pocket
   valve section    both gates, both cabinet grilles, both room bores
   ---- port ----   flange + clamp through the enclosure wall
```

**The duct is a U.** Air goes up the riser, over at the lid, down through the bed, and out at the
bottom — so both ends arrive in the valve section and **one valve assembly serves all four paths**.
The riser is carried through every section at the same place, so stacking a bay extends the duct
rather than breaking it.

| File | |
|---|---|
| [`desiccant-module.params.scad`](desiccant-module.params.scad) | **the header** — every value you SET |
| [`desiccant-module.scad`](desiccant-module.scad) | **the body** — derived values, geometry, echoes, guards. Render this one |

## The parts

| `draw_part` | Size | |
|---|---|---|
| `bay` | 152 × 152 × 46.2 | one cartridge; **stack one per cartridge** |
| `fan` | 152 × 152 × 55 | throat, 45° cone, fan pocket, cone to the plenum |
| `valve` | 152 × 152 × 40 | two gates, two cabinet grilles, two room bores, servo and switch pockets |
| `lid` | 152 × 152 × 13 | a plain cap with 10 mm of turn-over |
| `gate` | 86.6 × 42 × 4.8 | the sliding plate — **one per leg** |
| `flange` / `clamp` / `louvre` | 110 × 110 × 4 | port hardware, two bores each |
| `stack` | — | preview only; eight solids, fails the single-part check by design |

**All eight render manifold and single-part.** The default (`bay`) passes
[`scad-check.sh`](../../scripts/scad-check.sh) end to end: manifold, one part, slices at 0.2 mm in
ASA (9 h 54 m, 93.7 g), and the model's `fdm_layer_h` / `fdm_extrusion_w` match the profile it was
actually sliced with.

> **Every number below is regenerated from the model's own echo block.** Re-render and paste.

## Current geometry

```
PORT (the standard): 2 bores of 40 at 46 pitch, 4x M3 on 70 square, plates 110 x 4
  gasket racetrack : 4 x 1.4 mm, reaches r50 of a plate r55  (bolts r49.4975)
stack footprint    : 152 x 152, wall 2.4, bolts at +-71
  bolt -> cavity   : 3.4 mm   bolt -> edge: 3.15 mm
riser              : 96.3 x 9.3 = 702.99 mm2 at x-70.875
  riser -> bolt    : 21 mm
  riser -> cavity  : 1.475 mm   riser -> edge: 1.475 mm
bay section        : 46.2 tall, cavity 131.5 x 131.5 as cut
fan section        : 55 tall = throat 3 + cone 2.75 + fan 25 + cone 24.25
valve section      : 40 tall, legs at y+-23.5, ports 34.3 as cut at x-22.15 and x22.15
  gate             : 86.6 x 42 x 2.4, travel 44.3, sweep 130.9
  seals on         : 10 mm between ports, 4 mm of lap
  cabinet grilles  : 40.3 x 26.3 as cut
lid                : a plain cap, 3 + 10 mm of turn-over
screws to buy      : M3 x 144.2 for one cartridge, x 190.4 for two, plus engagement
warnings           : 1 - the part will build, read them
  ~~ the riser is 702.99 mm2 against a bore of 1275.56 mm2 - it is the throttle in the purge path
```

⚠️ **The stack screws are studding, not stock screws:** 144 mm for one cartridge, 190 mm for two.

⚠️ **The riser warning is a live judgement call, not a nuisance.** At 703 mm² against a 1276 mm²
bore the purge path is throttled by the channel rather than the ports. Widening further costs wall
band, which is the scarce direction — see below.

## Why a sliding gate, and not the obvious alternatives

Each leg's two ports sit **side by side** and a plate slides across them:

| Gate | Room bore | Cabinet port | = |
|---|---|---|---|
| one end | shut | open | absorbing |
| **middle** | **shut** | **shut** | **cooling** |
| other end | open | shut | exhausting |

The middle state is free, because a gate long enough to reach either port also spans both.

⛔ **A flap cannot produce that middle row**, and ⛔ **a barrel drum was tried and the model refused
it**: a window cut through a Ø44 drum leaves 5 mm of blank against a 40.3 mm bore, so no angle shuts
anything. A single-window drum needs its duct to connect *axially*, and in a U the duct arrives
radially. **The mechanism was wrong, not the dimensions** — no amount of adjusting Ø44 would have
found that.

## Four defects the guards caught

1. **Bolts inside the cartridge cavity.** At a 138 mm footprint a bolt inset 7 mm lands at ±62,
   inside a 131.2 mm cavity. Outline grew to 152.
2. **Bolts 1.4 mm from the cavity** — over the floor, thin for a hand-tightened joint. Fixed by
   moving them *outward* (inset 7 → 5), not by growing the part.
3. **The riser cut into its own wall.** Widened to 9 mm deep for area, it left 0.475 mm of skin. The
   wall band is only 10.25 mm, so **depth is the expensive direction**: depth went back to 7 and the
   area came from width, which costs nothing.
4. **A missing guard, found by fixing the one above.** The riser runs down the same wall band as the
   bolts, and nothing measured that gap — a wider channel would have cut into a bolt hole with every
   check still passing. `riser_to_bolt` now exists and is echoed each render.

## Guards

| | Count | Behaviour |
|---|---:|---|
| **BLOCK** — `assert` | 22 | render stops |
| **WARN** — `echo "WARNING: …"` | 10 | STL still produced |

**Every guard was made to fire on a known-bad input, and defaults stay silent:**

```
-D riser_d=9                  -> riser breaks into the cartridge cavity      (blocks)
-D riser_w=140                -> riser runs into a stack bolt                (blocks)
-D sel_gap=0.5                -> no material between a leg's two ports       (blocks)
-D gate_over=0.5              -> gate laps a port by under 3 perimeters      (blocks)
-D gate_over=0                -> gate cannot span both ports, no cooling     (blocks)
-D sel_gap=40                 -> gate's swept length does not fit            (blocks)
-D valve_h=9                  -> gate slot breaks through the top            (blocks)
-D stack_w=138 -D stack_d=138 -> bolts pass through the cartridge cavity     (blocks)
-D throat_d=70                -> bore wider than the fan pocket              (blocks)
-D gasket_margin=30           -> gasket racetrack runs off the plate         (blocks)
defaults                      -> 1 warning (the riser throttle)              (silent)
```

## ⛔ A control that exports `.echo` proves nothing

**OpenSCAD does not evaluate `assert()` when the export target is `.echo`.** Measured on this model,
with a known positive:

```
openscad -o x.echo -D riser_d=9 ...   ->  exit 0, no assertion   <- VACUOUS
openscad -o x.stl  -D riser_d=9 ...   ->  exit 1, assertion fires
```

The first form runs cleanly, prints the echo block, and reports every guard as silent — which reads
exactly like "the guards are inert". An entire round of controls here was run that way and had to be
thrown out. **Run guard controls against a real geometry export**, and capture OpenSCAD's own exit
code rather than a pipe's.

## Printing

**Every part flat, vertical walls, no supports.** The fan section's internal transitions are 45°
cones that grow outward going up; the valve section's cuts overlap rather than meet on shared planes,
which is what makes it 2-manifold — coplanar faces between two cut solids is exactly how that breaks.

**ASA rather than PETG**, since the valve section sits next to a bed that runs at 70–85 °C during a
purge; the glass-transition table is in [`docs/drybox-active.md`](../../docs/drybox-active.md).

## Regenerating

```sh
openscad -o bay.stl   -D 'draw_part="bay"'   desiccant-module.scad     # and fan, valve, lid,
openscad -o gate.stl  -D 'draw_part="gate"'  desiccant-module.scad     # gate, flange, clamp, louvre
sh ../../scripts/scad-check.sh desiccant-module.scad
```

⚠️ **`cart_w`, `cart_d` and `cart_h` are MIRRORED** from
[`models/desiccant-cartridge`](../desiccant-cartridge/). Nothing here can read that model, so if
either changes, check both.

⚠️ **The servo, microswitch and fan dimensions are `<<CONFIRM>>`** — assumed from typical SG90 and
microswitch envelopes, not measured against parts in hand. Check them before printing the valve
section.

STL and G-code output are gitignored; the `.scad` is the artefact worth keeping.
