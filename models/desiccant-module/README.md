# Desiccant module

The stack that carries [desiccant cartridges](../desiccant-cartridge/) and pulls box air through
them. Design and reasoning: [`docs/desiccant-module.md`](../../docs/desiccant-module.md).

```
   inlet lid        grille + sensor pocket, box air enters here
   bay section      one cartridge; ADD A SECTION PER CARTRIDGE
   [filter sheet]   HEPA paper, clamped between sections - not printed
   fan section      plenum, fan pocket, discharge to the PORT
   ---- port ----   flange + clamp through a wall, or the louvre plate
```

Source is split like C:

| File | |
|---|---|
| [`desiccant-module.params.scad`](desiccant-module.params.scad) | **the header** — every value you SET, and nothing else |
| [`desiccant-module.scad`](desiccant-module.scad) | **the body** — derived values, modules, geometry, echoes, guards. Render this one |

## ⭐ The port is the standard, not the module

Enclosures differ; the hole they provide does not. Those four numbers live in **one** file, and
every mating feature is derived from them — a standard that exists in two places is not a standard.

| | |
|---|---|
| Bore | **Ø62 mm** |
| Bolts | **4 × M3 on a 70 mm square**, symmetric so orientation never matters |
| Plates | 92 × 92 × 4 mm — flange, clamp and louvre share the outline |
| Wall thickness served | 2–25 mm, taken up by screw length, not by the parts |

## The parts

| `draw_part` | Size | |
|---|---|---|
| `bay` | 152 × 152 × 46.2 | one cartridge; **stack one per cartridge** |
| `fan` | 152 × 152 × 55 | discharge bore, 45° cone, fan pocket, cone to the plenum |
| `lid` | 152 × 152 × 9.6 | inlet grille + the sensor housing |
| `flange` | 92 × 92 × 12 | outside the wall; spigot locates it in the bore, gasket groove in its face |
| `clamp` | 92 × 92 × 4 | the other side of the wall |
| `louvre` | 92 × 92 × 4 | blanks the port and returns air to the box — **what v1 runs** |
| `stack` | — | preview only; six solids, fails the single-part check by design |

> **Every number below is regenerated from the model's own echo block.**
> Do not hand-edit them — re-render and paste.

## Current geometry

```
part rendered      : bay
PORT (the standard): bore 62 mm, 4x M3 on 70 mm square, plates 92 x 92 x 4
  spigot           : 61 mm OD x 8 into a 62 bore (0.5 mm/side)
  gasket groove    : 4 x 1.4 mm at r38.5  (bore r31, bolts r49.4975, plate r46)
stack footprint    : 152 x 152 mm, wall 2.4, bolts at +-71
  bolt -> cavity   : 3.4 mm
  bolt -> edge     : 3.15 mm
bay section        : 46.2 mm tall, cavity 131.5 x 131.5 as cut for a 130 x 130 x 45 cartridge
fan section        : 55 mm tall  =  throat 3 + cone 2.75 + fan 25 + cone 24.25
  pocket           : 61.8 mm square as cut for a 60 mm fan - CLAMPED by the section above, not screwed
  plenum           : 110.3 mm square under the cartridge
inlet grille       : 18 slots of 4.3 as cut, bar 2.1, open 41.4925% of the cartridge face
sensor housing     : 24.8 x 20.8 x 6.6 on the inlet face, pocket 20.3 x 16.3 as cut
screws to buy      : M3 x 104.2 for one cartridge, x 150.4 for two, plus engagement
port screws        : M3 x 33 covers the thickest wall specified (25 mm)
prints             : every part flat, vertical walls, 45 degree cones - no supports
warnings           : none
```

The bay slices at **9 h 42 m, 95.7 g** in ASA at 0.2 mm. ⚠️ **The stack screws are studding, not
stock screws** — 104 mm for one cartridge, 150 mm for two.

## Three defects the guards caught

Recorded because each was found by the model rather than by a print, which is what the guards are
for.

**1. The footprint put the bolts inside the cartridge.** At 138 mm the cavity is 131.2 wide, leaving
3.4 mm of wall, and a bolt inset 7 mm from the corner lands at ±62 — inside the cavity, passing
through nothing. The floor is `cavity/2 + screw/2 + 3 beads`, so the outline had to grow to 152.

**2. Then the bolts sat 1.4 mm from the cavity.** Over the 3-bead floor, but thin for a joint
tightened by hand — so the guard warned rather than blocked, which is the right split. Fixed by
moving the bolts **outward** (`bolt_inset` 7 → 5): 3.4 mm to the cavity, 3.15 mm outboard, same
footprint.

**3. ⭐ The gasket-groove guard failed on its own defaults — and the guard was wrong, not the
geometry.** Bolts at the corners of a 70 mm square are **49.5 mm** from the centre, not 35: the
check compared a groove at r37 against half the *pitch* as if it were a radius. Real clearance was
never in doubt. It now uses the diagonal, and also checks the plate edge it never looked at.

> **A guard that measures the wrong quantity is worse than no guard**: it fails confidently, and the
> obvious response is to "fix" geometry that was correct.

## The fan is clamped, not screwed

A 60 mm fan's mounting holes are at ±25 mm in both axes — **inside** a 61.5 mm pocket — so a pilot
hole for them would be drilled in mid-air. The fan drops into the pocket and the section above traps
it, along with the filter sheet. `fan_pitch` and `fan_screw_d` were therefore deleted rather than
left in the header: a parameter nothing uses is a promise the model does not keep.

## Guards

| | Count | Meaning | Behaviour |
|---|---:|---|---|
| **BLOCK** — `assert` | 15 | impossible geometry: bolts through the cavity, a bore wider than its pocket, a groove into the bolts, a plenum wider than the cartridge | render stops |
| **WARN** — `echo "WARNING: …"` | 10 | builds but compromised: a bar under the perimeter floor, a restrictive inlet, a face landing mid-layer | STL still produced |

**Verified by making each one fire**, using the two real defects above as positive controls:

```
-D stack_w=138 -D stack_d=138  -> assert: bolts through the cartridge cavity   (blocks)
-D gasket_w=30                 -> assert: groove into the bore/bolts/edge      (blocks)
-D throat_d=70                 -> assert: bore wider than the fan pocket       (blocks)
-D plenum_w=140                -> assert: plenum wider than the cartridge      (blocks)
-D in_bar_w=1.5                -> "inlet bar as cut ... under 3 perimeters"    (warns)
-D wall=1.2                    -> "wall ... under 3 perimeters"                (warns)
-D draw_part="stack"           -> "six solids ... will fail the single-part check" (warns)
defaults                       -> 0 warnings                                   (silent)
```

All six parts render **manifold and single-part**; the default passes
[`scripts/scad-check.sh`](../../scripts/scad-check.sh) end to end, including the cross-check that
the model's `fdm_layer_h` and `fdm_extrusion_w` match the profile it was actually sliced with.

## Printing

**Every part flat, vertical walls, no supports.** The bay is a plain frame, the lid is a plate, and
the fan section's internal transitions are 45° cones that grow outward going up — so no layer
overhangs the one below it and nothing bridges.

**ASA rather than PETG** for anything that may sit in or near a heated dryer; the glass-transition
table is in [`docs/drybox-active.md`](../../docs/drybox-active.md).

## Regenerating

```sh
openscad -o bay.stl    -D 'draw_part="bay"'    desiccant-module.scad
openscad -o fan.stl    -D 'draw_part="fan"'    desiccant-module.scad
openscad -o lid.stl    -D 'draw_part="lid"'    desiccant-module.scad
openscad -o flange.stl -D 'draw_part="flange"' desiccant-module.scad
openscad -o clamp.stl  -D 'draw_part="clamp"'  desiccant-module.scad
openscad -o louvre.stl -D 'draw_part="louvre"' desiccant-module.scad

sh ../../scripts/scad-check.sh desiccant-module.scad      # render -> slice -> cross-check
```

⚠️ **`cart_w`, `cart_d` and `cart_h` are MIRRORED** from
[`models/desiccant-cartridge`](../desiccant-cartridge/). Nothing here can read that model, so if
either changes, check both.

STL and G-code output are gitignored (repo convention — binaries live in `OneDrive\3D printing\`);
the `.scad` is the artefact worth keeping.
