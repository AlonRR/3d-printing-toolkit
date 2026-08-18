# USB-C panel plate

A printed plate covering an oversized rectangular aperture in a PC case front
panel, around a commodity IP67-style **panel-mount USB-C feedthrough** (moulded
black flange, raised rounded-rect boss around the port, one screw hole per side).

Source is split like C:

| File | |
|---|---|
| [`usbc-panel-plate.params.scad`](usbc-panel-plate.params.scad) | **the header** — every value you SET, and nothing else. No geometry, no derived values |
| [`usbc-panel-plate.scad`](usbc-panel-plate.scad) | **the body** — derived values, modules, geometry, echoes, guards. Render this one |

Every parameter is a named variable, tagged MEASURED or <<CONFIRM>>.

```
        raised rectangle (14.4 x 6.1)
   +---------------------------------------+
   |          .-------------.              |
   |   O      |   [=====]   |      O       |   23.9 x 15.0 x 2.4 mm
   | screw    '-------------'    screw     |
   |            notch top/bottom           |
   +---------------------------------------+
        |<--- screw span 19.8 c-to-c --->|
```

> **Every number below is regenerated from the model's own echo block.**
> Do not hand-edit them — re-render and paste. Hand-edited numbers drift, and a
> drifted table reads exactly as authoritative as a correct one.

## Current geometry

```
plate              : 23.9 x 15 x 2.4 mm
  width set by     : FASTENERS (23.9) - coverage alone would allow 23.4   [screw_style hole]
covers opening     : 23.4 x 15 mm, lap 0 mm (corner floor 0.43934)
port opening       : 9.6 x 3.9 mm as cut
port recess        : 2.3 mm a plug must reach in (lip 0.8 + protrusion 1.5)
rear pocket        : 14.2 x 8.8 mm as cut, 1.2 mm deep, 0.25 mm/side clearance on the boss
max boss height    : 1.8 mm from the connector flange (pocket 1.2 + panel 0.6)
two-bridge trick   : ON -- 3 staged layers of 0.2 mm
  L1 two bridge    : slot 9.6 x 8.8  -> two strips spanning 8.8 mm, anchored both ends
  L2 rectangle     : 9.6 x 3.9 square  -> the other two sides bridge 9.6 mm
  L3 rounded       : r2 fillets only, laid on the solid rectangle below
web beside pocket  : 1.2 mm
web above/below    : 3.1 mm
outboard of screw  : 0.45 mm
protrusion         : 14.4 x 6.1 x 1.5 mm on the front
  frame beside port: 2.4 mm
  frame over/under : 1.1 mm
  prot -> screw    : 1.1 mm
notch              : r 1.8 mm (1.95 as cut) at x = 0
  notch -> pocket  : 1.15 mm
  notch -> screw   : 8.87014 mm
  lap left at notch: -1.95 mm
screws land on     : OPEN AIR - plate clamps to the connector, not to the panel - and with overlap 0 there is no lap, so the panel is not trapped at all
WARNING: overlap 0 - the plate is no larger than the aperture, so NOTHING in front of the panel is wider than the hole. The connector flange behind can still stop it pulling OUT, but nothing stops the assembly being pushed IN - which is the direction a plug loads it
WARNING: outboard of screw 0.45 mm is under 3 perimeters (1.35) as cut - a screw pulls directly on this and it will split
WARNING: notch reaches 1.95 mm past the aperture edge - it opens a gap straight into the case across its whole chord, and removes any lap there was to retain the plate at that edge
warnings           : 3 - the part will build, read them
```

## Dimension provenance

| Parameter | Value | Basis |
|---|---|---|
| `gap_w` × `gap_h` | **23.4 × 15.0** | **MEASURED** — the case aperture |
| `panel_t` | **0.6** | **MEASURED** — case sheet thickness |
| `screw_span` | **19.8** | **MEASURED** — see derivation below |
| `screw_d` | **2.9** (M2.5) | **MEASURED** — see derivation below |
| `boss_h` | **8.0** | **MEASURED** |
| `prot_w` × `prot_h` | **14.4 × 6.1** | **MEASURED** |
| `boss_w` | 13.4 | ⚠️ **NOT measured** — photo-scaled, and it feeds the fit |
| `prot_t` | 1.5 | ⚠️ **NOT measured** |
| `overlap` | **0** | chosen deliberately — the fitting is space-limited. See "Retention" |
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

Every cut is grown by `fdm_hole_comp` (0.15 mm/side) to compensate for printed holes
coming out undersize. **Every echo and assert is therefore computed from the
grown values, not the nominal ones.** This matters more than it sounds. Auditing
nominal dimensions while cutting compensated ones reports every clearance
0.15–0.30 mm better than the part actually has: a screw edge distance of 0.40 mm
reads as 0.55 — under one extrusion, on the feature most likely to break, and on
the wrong side of the perimeter floor.

The as-cut names (`pw`, `ph`, `bw`, `bh`, `sd`, `nr`, `cbd`) are defined once at
file scope and used by the geometry, the echoes and the guards alike.

`boss_clear` is separate and deliberate: `fdm_hole_comp` only cancels shrink, which
for a pocket means printing *line-to-line* on the boss. Fit needs its own
allowance, so the pocket gets 0.25 mm/side on top.

## Retention

The aperture is 23.4 mm wide; the screws span 22.70 mm outer-to-outer. Both
screws therefore pass through **open air**, not sheet metal. The plate bolts to
the *connector*, not to the panel.

That leaves the panel held only by what is larger than the hole on each side of
it, and the two directions are **not** symmetric:

| Direction | What stops it | Status at `overlap = 0` |
|---|---|---|
| assembly pulled **OUT**, forward | the connector's flange, behind the panel | works — *if* that flange exceeds 23.4 × 15 (**unmeasured**) |
| assembly pushed **IN**, backward | the plate's lap, in front of the panel | **nothing** — the plate is no larger than the hole |

`overlap = 0` is deliberate: the fitting is space-limited and the plate cannot
grow. The cost is the second row, and push-in is the direction a plug loads it.
The guard states exactly that rather than calling it a failure.

A **rear flange on the plate does not fix this.** Trapping a sheet needs material
on both faces of it; a rear flange sits on the same side as the connector flange,
so the assembly can still travel inward. Only something in *front* wider than the
aperture — or friction/adhesive — resists push-in.

Two guards cover the geometry, and they are deliberately separate because they
describe different failures:

- **No lap at all** (`overlap <= 0`) — nothing in front of the panel is wider
  than the hole. Independent of `corner_r`.
- **Corners only** (`corner_r > 0 && 0 < overlap <= corner_r * (1 - 1/sqrt(2))`)
  — the straight edges cover but the *rounded corners* fall inside, leaving four
  open gaps. Not obvious from the edge arithmetic.

Testing `overlap <= corner_min` alone conflates them, and degenerates at
`corner_r = 0`: `corner_min` is 0, the condition reads `0 <= 0`, and it reports
rounded corners falling inside on a plate that has no rounded corners.

**The notches cut past the aperture edge** by 1.95 mm. At `overlap = 0` there is
no lap left for them to remove, so the warning states what is actually true — an
open gap into the case across the notch chord — rather than asserting a lap that
does not exist.

## Layer alignment

`plate_t = 2.4`, not 2.5. At `fdm_layer_h = 0.2` that puts the pocket floor and
all three staged layers at print z **1.2 / 1.4 / 1.6 / 2.4** — every one on-grid.
At 2.5 mm they all land mid-layer and the staging resolves on a slicer tie-break
rather than on the geometry. Asserted.

## Slicer facts are named `fdm_*`

`fdm_layer_h`, `fdm_extrusion_w` and `fdm_hole_comp` are facts about how the part
gets **made**, not decisions about what it should **be**. Each has a counterpart
in the print profile, and the model is wrong the moment they disagree — so they
are grouped and prefixed to make that obvious at a glance rather than discovered
by a bad print.

The wall thresholds are derived from them rather than written down:

```scad
perim2 = 2 * fdm_extrusion_w;   // 0.90 — minimum for a non-load feature
perim3 = 3 * fdm_extrusion_w;   // 1.35 — minimum for anything that takes force
```

Spelled as the literal `1.35`, with "3 perimeters" explained in the assert
message, it would be a magic number whose meaning lives somewhere nothing can
check it. Derived, the guards move with the profile. Verified by overriding
them:

```
-D fdm_extrusion_w=0.8   -> "web ... is under 2 perimeters as cut"   (fires)
-D fdm_layer_h=0.15      -> "lip_t is not a whole number of layers"  (fires)
```

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

Two kinds, and the distinction is deliberate.

| | Count | Meaning | Behaviour |
|---|---:|---|---|
| **BLOCK** — `assert` | 12 | the geometry is impossible or self-contradictory: a feature vanishes, inverts, or cuts the part in two | render stops |
| **WARN** — `echo "WARNING: …"` | 15 | it builds and prints, but is compromised: a wall under the perimeter floor, a notch into the case, a stage landing mid-layer | STL still produced |

Accepting a thin wall is the operator's call, so it warns. Producing a part with
no lip at all is not a call, so it blocks. `scad-check.sh` mirrors the split —
exit 1 for blocked, exit 2 for builds-with-warnings.

Coverage of the non-default branches is deliberate: `prot_face = "back"`,
`cbore_d > 0`, `prot_t = 0`, `bridge_slot = false`, `screw_style = "slot"` and
`flip_for_print = false` all render clean and manifold. `prot_face = "back"`
fails loudly rather than silently printing the protrusion as two slivers.

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
