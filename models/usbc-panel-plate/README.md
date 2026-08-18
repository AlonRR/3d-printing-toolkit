# USB-C panel plate

A printed plate covering an oversized rectangular aperture in a PC case front
panel, around a commodity IP67-style **panel-mount USB-C feedthrough** (moulded
black flange, raised rounded-rect boss around the port, one screw hole per side).

Source: [`usbc-panel-plate.scad`](usbc-panel-plate.scad). Parametric — every
dimension is a named variable at the top of the file.

```
        raised rectangle (14.7 x 6.1)
   +---------------------------------------+
   |          .-------------.              |
   |   O      |   [=====]   |      O       |   28.4 x 20.0 x 2.4 mm
   | screw    '-------------'    screw     |
   |            notch top/bottom           |
   +---------------------------------------+
        |<--- screw span 19.8 c-to-c --->|
```

> **Every number below is regenerated from the model's own echo block.**
> Do not hand-edit them — re-render and paste. An earlier version of this file
> drifted a whole parameter set out of date while reading as authoritative.

## Current geometry

```
plate              : 28.4 x 20 x 2.4 mm
covers opening     : 23.4 x 15 mm, lap 2.5 mm (corner floor 0.43934)
port opening       : 9.6 x 3.9 mm as cut
port recess        : 2.3 mm a plug must reach in (lip 0.8 + protrusion 1.5)
rear pocket        : 14.2 x 8.8 mm as cut, 1.4 mm deep, 0.25 mm/side clearance
max boss height    : 2.0 mm from the connector flange (pocket 1.4 + panel 0.6)
stage 1 span       : 8.8 mm   stage 2 span : 9.6 mm
two-bridge trick   : ON -- slot 9.6 x 8.8 for 0.2 mm (stage spans 8.8 / 9.6)
web beside pocket  : 1.2 mm
web above/below    : 5.6 mm
outboard of screw  : 2.7 mm
protrusion         : 14.7 x 6.1 x 1.5 mm on the front
notch              : r 1.8 mm (1.95 as cut), lap left at notch 0.55 mm
screws land on     : OPEN AIR - plate clamps to the connector
```

## Dimension provenance

| Parameter | Value | Basis |
|---|---|---|
| `gap_w` × `gap_h` | **23.4 × 15.0** | **MEASURED** — the case aperture |
| `panel_t` | **0.6** | **MEASURED** — case sheet thickness |
| `screw_span` | **19.8** | **MEASURED** — see derivation below |
| `screw_d` | **2.9** (M2.5) | **MEASURED** — see derivation below |
| `boss_h` | **8.0** | **MEASURED** |
| `prot_w` × `prot_h` | **14.7 × 6.1** | **MEASURED** |
| `boss_w` | 13.4 | ⚠️ **NOT measured** — photo-scaled, and it feeds the fit |
| `prot_t` | 1.5 | ⚠️ **NOT measured** |
| `overlap` | 2.5 | chosen — see "the lap is the only retention" |
| `plate_t` | 2.4 | chosen — whole layers, see "layer alignment" |
| `port_w` × `port_h` | 9.3 × 3.6 | chosen to hug the 8.94 × 3.16 receptacle shell |

### Screw pattern derivation

```
inner edge to inner edge = 16.90 mm
outer edge to outer edge = 22.70 mm

centre-to-centre = (16.90 + 22.70) / 2 = 19.80 mm
hole diameter    = (22.70 - 16.90) / 2 =  2.90 mm   -> M2.5, not M2
```

## Nominal vs as-cut

Every cut is grown by `hole_comp` (0.15 mm/side) to compensate for printed holes
coming out undersize. **Every echo and assert is therefore computed from the
grown values, not the nominal ones.** This matters more than it sounds: an
earlier version audited nominal dimensions while cutting compensated ones, and
so reported every clearance 0.15–0.30 mm better than the part actually had. The
screw edge distance read 0.55 mm when it was really 0.40 mm — under one
extrusion, on the feature most likely to break.

The as-cut names (`pw`, `ph`, `bw`, `bh`, `sd`, `nr`, `cbd`) are defined once at
file scope and used by the geometry, the echoes and the guards alike.

`boss_clear` is separate and deliberate: `hole_comp` only cancels shrink, which
for a pocket means printing *line-to-line* on the boss. Fit needs its own
allowance, so the pocket gets 0.25 mm/side on top.

## The lap is the only retention

The aperture is 23.4 mm wide; the screws span 22.70 mm outer-to-outer. Both
screws therefore pass through **open air**, not sheet metal. The plate is
clamped to the *connector*, and the panel is trapped between the plate's lap and
the connector's flange — so the lap is doing all the work.

Two consequences the guards now enforce:

- **`overlap` has a hard floor of `corner_r * (1 - 1/sqrt(2))` = 0.44 mm.** Below
  that the *rounded corners* fall inside the aperture and leave four open gaps
  into the case even though every straight edge nominally covers. This is not
  obvious from the edge arithmetic and is asserted, not commented.
- **The notches must not eat the lap.** `notch_r` is sized so the cut *including*
  `hole_comp` still leaves lap on the panel — currently 0.55 mm at the notch.

## Layer alignment

`plate_t = 2.4`, not 2.5. At 0.2 mm layers that puts the pocket floor, both
the bridge slot and the lip at print z **1.0 / 1.4 / 1.6 / 2.4** — all on-grid. At 2.5 mm
every one lands mid-layer and the bridge slot resolves on a
slicer tie-break rather than on the geometry. Asserted.

## The two-bridge trick — three staged layers

Printed back-face-down, the layer closing over the pocket **is the lip, and the
lip has the port hole in it**. That is not a plain bridge — the printer would be
drawing the hole outline in mid-air.

It is split across three layers, and the point is that **each layer does exactly
one thing**. No layer has to lay a straight run and a curve in the same pass.

```
  L1  THE TWO BRIDGE   slot 9.6 x 8.8  -> two strips spanning 8.8 mm,
                                          each anchored at BOTH ends
  L2  THE RECTANGLE    9.6 x 3.9 square -> the other two sides bridge 9.6 mm
                                          onto those strips
  L3  THE CORNERS      r2 fillets only  -> laid on the solid rectangle below

     L1                 L2                 L3
  +--+      +--+     +--+------+--+     +--+------+--+
  |  |      |  |     |  |      |  |     |  /      \  |
  |  |  gap |  |     |  | rect |  |     |  | port |  |
  |  |      |  |     |  |      |  |     |  \      /  |
  +--+      +--+     +--+------+--+     +--+------+--+
```

Both spans are under the ~10 mm ceiling and both are asserted. So is the thing
that makes the staging meaningful: if the slot were no taller than the port, L1
and L2 would be the same shape; if `port_r` were 0, L2 and L3 would be. Either
way the render still succeeds while silently doing less than it claims.

**Nothing is sacrificial.** All three layers are load-bearing geometry, nothing
is snipped or drilled afterwards, and the sliced G-code carries
`support_material = 0`. House rule: prefer no support, prefer permanent over
sacrificial, and read "this needs a sacrificial feature" as a sign a better
design exists. See [`docs/fdm-design-rules.md`](../../docs/fdm-design-rules.md)
§3b–3c.

## Printing

**Back face down.** `flip_for_print` rotates the model 180° about X on export,
so the STL arrives already oriented — do **not** flip it again in the slicer.
Front-face-down puts the protrusion on the bed and leaves the plate rim
overhanging ~4.6 mm in mid-air.

The `lead_in` chamfer consequently sits on the **top** face. It is a plug lead-in
only; it does not relieve elephant's foot, which is a first-layer effect. The
`pocket_chamfer` is the one on the bed face, where a chamfer is free.

## Guards

25 asserts. They **block the render** — a check that prints a warning and builds
anyway is not a check, and this model previously had two of those (the notch
breakthrough and the coverage test) reporting problems into the log while
happily exporting the broken part.

Coverage of the non-default branches is deliberate: `prot_face = "back"`,
`cbore_d > 0`, `prot_t = 0`, `bridge_slot = false` and
`flip_for_print = false` all render clean and manifold, and `prot_face = "back"`
now *fails loudly* rather than silently printing the protrusion as two slivers.

## Regenerating

```sh
openscad -o usbc-panel-plate.stl usbc-panel-plate.scad
```

Previews, cross-sections and thin slices:

```sh
sh ../../scripts/scad-preview.sh usbc-panel-plate.scad out 1.2 1.4 1.6
```

STL output is gitignored (repo convention — binaries live in
`OneDrive\3D printing\`); the `.scad` is the artefact worth keeping.
