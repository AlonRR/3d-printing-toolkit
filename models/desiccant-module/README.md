# Desiccant module

The stack that carries [desiccant cartridges](../desiccant-cartridge/), pulls box air through them,
and **regenerates itself** by sealing the filament area and baking the bed out to the room. Design
and reasoning: [`docs/desiccant-module.md`](../../docs/desiccant-module.md).

```
   lid              a plain cap + the heater, on standoffs above the turn-over volume
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

**The heater sits where the airflow put it.** During a purge the flow is riser up, turn over, down
through the bed, so the element must warm the air *before* it crosses the desiccant — and the lid's
turn-over volume is the only upstream space. It stands off on posts with a **10 mm air gap** to the
lid's outer skin, because that skin is the cabinet side.

| File | |
|---|---|
| [`desiccant-module.params.scad`](desiccant-module.params.scad) | **the header** — every value you SET |
| [`desiccant-module.scad`](desiccant-module.scad) | **the body** — derived values, geometry, echoes, guards. Render this one |

## The parts

| `draw_part` | |
|---|---|
| `bay` | one cartridge; **stack one per cartridge** |
| `fan` | throat, 45° cone, fan pocket, cone to the plenum |
| `valve` | two gates, two cabinet grilles, two room bores, servo and switch pockets |
| `lid` | cap, turn-over volume, heater standoffs and lead slot |
| `gate` | the sliding plate — **one per leg** |
| `flange` / `clamp` / `louvre` | port hardware, two bores each |
| `stack` | preview only; eight solids, fails the single-part check by design |

**All eight render manifold and single-part.** The default (`bay`) passes
[`scad-check.sh`](../../scripts/scad-check.sh) end to end: manifold, one part, slices at 0.2 mm in
ASA (9 h 52 m, 93.7 g), and the model's `fdm_layer_h` / `fdm_extrusion_w` match the profile it was
actually sliced with.

> **Every number below is regenerated from the model's own echo block.** Re-render and paste.

## Current geometry

```
PORT (the standard): 2 bores of 40 at 46 pitch, 4x M3 on 70 square, plates 110 x 4
  gasket racetrack : 4 x 1.4 mm, reaches r50 of a plate r55  (bolts r49.4975)
stack footprint    : 152 x 152, wall 2.4, bolts at +-71
  bolt -> cavity   : 3.4 mm   bolt -> edge: 3.15 mm
riser              : 96.3 x 7.3 = 702.99 mm2 at x-70.875
  riser -> bolt    : 21 mm
  riser -> cavity  : 1.475 mm   riser -> edge: 1.475 mm
bay section        : 46.2 tall, cavity 131.5 x 131.5 as cut
fan section        : 55 tall = throat 3 + cone 2.75 + fan 25 + cone 24.25
valve section      : 40 tall, legs at y+-23.5, ports 34.3 as cut at x-22.15 and x22.15
  gate             : 86.6 x 42 x 2.4, travel 44.3, sweep 130.9
  seals on         : 10 mm between ports, 4 mm of lap
  cabinet grilles  : 40.3 x 26.3 as cut
lid                : cap 3 + 26 mm of turn-over
  heater           : 41.5 x 41.5 as cut on 6 mm posts (floor 6), leads out a 8.3 mm slot
  air gap to skin  : 10 mm - air, not plastic, is what keeps the cabinet side cool
screws to buy      : M3 x 144.2 for one cartridge, x 190.4 for two, plus engagement
warnings           : 1 - the part will build, read them
  ~~ the riser is 702.99 mm2 against a bore of 1275.56 mm2 - it is the throttle in the purge path
```

⚠️ **The stack screws are studding, not stock screws:** 144 mm for one cartridge, 190 mm for two.

⚠️ **The riser warning is a live judgement call.** At 703 mm² against a 1276 mm² bore the purge path
is throttled by the channel, not the ports. Widening costs wall band, which is the scarce direction —
decide it when the real fan is known.

## Why a sliding gate

| Gate | Room bore | Cabinet port | = |
|---|---|---|---|
| one end | shut | open | absorbing |
| **middle** | **shut** | **shut** | **cooling** |
| other end | open | shut | exhausting |

The middle state is free: a plate long enough to reach either port also spans both.

⛔ **A flap cannot produce that middle row**, and ⛔ **a barrel drum was tried and the model refused
it** — a window through a Ø44 drum leaves 5 mm of blank against a 40.3 mm bore, so no angle shuts
anything, and a single-window drum needs an axial duct where a U delivers a radial one. **The
mechanism was wrong, not the dimensions.**

## Six defects the guards caught

1. **Bolts inside the cartridge cavity** at a 138 mm footprint. Outline grew to 152.
2. **Bolts 1.4 mm from that cavity** — fixed by moving them *outward*, not by growing the part.
3. **The riser cut into its own wall** when widened for area. The band is 10.25 mm, so **depth is the
   expensive direction**: depth back to 7, area from width.
4. **A missing guard**, found by fixing (3): nothing measured riser-to-bolt, so a wider channel would
   have cut a bolt hole with every check passing.
5. **Heater posts 2 mm tall.** `turn_clear` was a number I picked; it has to be the **sum** of post,
   element and air gap. The guard passed it because `post_h > 0` asks whether a post exists, not
   whether it can hold a screwed-down element.
6. **The default shipped warning about itself** — a 6 mm air gap against a warn-below-8 test. A part
   that warns about its own defaults is either misconfigured or has a test it doesn't believe. The
   gap went to 10 mm; air is the cheap direction, costing turn-over volume rather than wall.

## Guards

| | Count | Behaviour |
|---|---:|---|
| **BLOCK** — `assert` | 26 | render stops |
| **WARN** — `echo "WARNING: …"` | 11 | STL still produced |

```
-D riser_d=9                  -> riser breaks into the cartridge cavity      (blocks)
-D riser_w=150                -> riser runs into a stack bolt                (blocks)
-D sel_gap=0.5                -> no material between a leg's two ports       (blocks)
-D gate_over=0.5              -> gate laps a port by under 3 perimeters      (blocks)
-D gate_over=0                -> gate cannot span both ports, no cooling     (blocks)
-D sel_gap=40                 -> gate's swept length does not fit            (blocks)
-D valve_h=9                  -> gate slot breaks through the top            (blocks)
-D turn_clear=18              -> heater posts shorter than post_min          (blocks)
-D heater_w=130               -> heater and posts do not fit the volume      (blocks)
-D heater_screw_d=7           -> pilot leaves under 3 perimeters of post     (blocks)
-D stack_w=138 -D stack_d=138 -> bolts pass through the cartridge cavity     (blocks)
-D throat_d=70                -> bore wider than the fan pocket              (blocks)
-D gasket_margin=30           -> gasket racetrack runs off the plate         (blocks)
-D heater_gap=4               -> under 8 mm of air to the cabinet side       (warns)
defaults                      -> 1 warning, the riser throttle               (silent otherwise)
```

## ⛔ Two ways a control can lie about a guard

**1. Exporting `.echo` skips every assert.** Measured here with a known positive:

```
openscad -o x.echo -D riser_d=9 ...  ->  exit 0, no assertion   <- VACUOUS
openscad -o x.stl  -D riser_d=9 ...  ->  exit 1, assertion fires
```

The first form runs cleanly, prints the echo block, and reports every guard as silent — which reads
exactly like "the guards are inert". A whole round of controls here was run that way and thrown out.
**Run controls against a real geometry export, and capture OpenSCAD's own exit code, not a pipe's.**

**2. Reading only the first line hides later ones.** The riser warning fires on defaults, so a
harness that greps the first match reports every *other* warning as silent. The air-gap guard was
mislabelled inert for exactly that reason.

⭐ **And one guard turned out to be unreachable.** A check that "a heater post lands in the riser"
could not be made to fire by any parameter: `heater_w` hits the fit guard ~1 mm sooner, `riser_d`
trips the cavity guard first, `riser_w` reaches the bolt guard, and relaxing `post_w` trips the pilot
guard. It was **deleted rather than kept** — a guard nobody can make fire reads as coverage and is
not.

## Printing

**Every part flat, vertical walls, no supports.** The fan section's transitions are 45° cones that
grow outward going up; the valve section's cuts overlap rather than meet on shared planes, which is
what makes it 2-manifold.

**ASA rather than PETG** — the valve section and lid sit next to a bed running at 70–85 °C during a
purge. Glass-transition table: [`docs/drybox-active.md`](../../docs/drybox-active.md).

## Regenerating

```sh
openscad -o bay.stl  -D 'draw_part="bay"'  desiccant-module.scad   # and fan, valve, lid, gate,
openscad -o lid.stl  -D 'draw_part="lid"'  desiccant-module.scad   # flange, clamp, louvre
sh ../../scripts/scad-check.sh desiccant-module.scad
```

⚠️ **`cart_w`, `cart_d` and `cart_h` are MIRRORED** from
[`models/desiccant-cartridge`](../desiccant-cartridge/). Nothing here can read that model, so if
either changes, check both.

⚠️ **The servo, microswitch, fan and heater envelopes are `<<CONFIRM>>`** — typical figures, not
measurements off the parts in hand. Check all four before printing the valve section or the lid.

STL and G-code output are gitignored; the `.scad` is the artefact worth keeping.
