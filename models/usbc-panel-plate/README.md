# USB-C panel plate

A rectangle with three holes — USB-C opening in the middle, one screw hole
either side. Mirrors the flange of the commodity IP67-style **panel-mount USB-C
feedthrough** (moulded black flange, raised rounded-rect boss around the port,
one screw hole per side).

Source: [`usbc-panel-plate.scad`](usbc-panel-plate.scad). Parametric — every
dimension is a named variable at the top of the file.

```
   +------------------------------------+
   |                                    |
   |     O        [==========]       O  |
   |   screw       USB-C hole     screw |
   +------------------------------------+
       |<---- screw_span (c-to-c) ----->|
```

## Dimension provenance

The screw pattern is measured. Everything else is still scaled off photographs,
using the USB-C receptacle mouth (8.9 mm, fixed by the USB spec) as the ruler,
and is good to roughly ±10 %.

| Parameter | Value | Basis |
|---|---|---|
| `screw_span` | **19.8** | **MEASURED** — see derivation below |
| `screw_d` | **2.9** (M2.5 clearance) | **MEASURED** — see derivation below |
| `gap_w` × `gap_h` | **23.4 × 15.0** | **MEASURED** — the case opening |
| `panel_t` | **0.6** | **MEASURED** — case sheet thickness |
| `overlap` | 2.5 | chosen — how far the plate laps onto the panel |
| `plate_w` × `plate_h` | 28.4 × 20.0 | **derived** from `gap_*` + `overlap`, floored by the screw envelope |
| `plate_t` | 2.5 | chosen |
| `port_w` × `port_h` | 9.5 × 3.7 | front lip — snug on the 8.94 × 3.16 receptacle shell |
| `lip_t` | 0.8 | chosen — thickness of the thin front lip |
| `boss_w` × `boss_h` | 13.4 × 8.4 | photo-scaled rear relief, clears the connector's raised boss |

`plate_w` and `plate_h` are computed, not set. The plate must cover the opening
*and* keep both screw holes inside its own edge, so:

```
plate_w = max(gap_w + 2*overlap,  22.70 + 2*1.5)
plate_h = gap_h + 2*overlap
```

The `max()` floor means the width only responds to `gap_w` once the opening
exceeds 21 mm. The measured 23.4 mm is past that, so the opening governs and
the plate came out 28.4 mm.

## The centre opening has two levels

The visible hole closes right down around the USB-C receptacle, so no gap shows
around the port. That is only possible because the connector's raised boss gets
its own relief pocket behind the lip:

```
   FRONT (visible, outside the case)          BACK (toward the connector)
                    |
   ---------+       |       +---------
            |  9.5 x 3.7    |            <- lip_t = 0.8 mm, sized to the PORT
            +---+       +---+
                |       |
                | 13.4 x 8.4 |           <- pocket 1.7 mm deep, clears the BOSS
   -------------+       +-------------
```

The pocket swallows a boss standing up to **2.3 mm** proud of the connector
flange — 1.7 mm of pocket plus the 0.6 mm the panel itself absorbs. If the plate
will not sit flat on the panel, the boss is taller than that: reduce `lip_t` or
raise `plate_t`.

The lip only has to clear the plug's metal tongue (8.34 × 2.56 mm, fixed by the
USB spec), and 9.5 × 3.7 clears it comfortably. The plug's overmould bottoms
against the lip, which at 0.8 mm is close enough to flush that the tongue still
reaches the receptacle.

## The screws pass through open air — this is how the part is held

The opening is **23.4 mm** wide. The screws span **22.70 mm** outer-to-outer.
So both screw holes sit *inside* the opening, clearing the panel edge by only
about **0.35 mm per side**.

Two consequences:

1. **The plate is not bolted to the panel.** It is clamped to the *connector*,
   and the sheet metal is trapped between the plate's 2.5 mm lap and the
   connector's own flange. The lap is doing all the retention — so if this ever
   gets re-parameterised, do not shrink `overlap`.
2. **The screws only just clear.** 0.35 mm per side means the connector has to
   sit close to centred in the opening or a screw shank will foul the panel
   edge and the assembly won't pull up tight. If it binds, that's the cause —
   not the plate.

The `.scad` echoes which case applies on every render:

```
screws land on    : OPEN AIR - plate clamps to the connector, panel trapped by the lap
```

### Screw pattern derivation

Calipers across the connector's own flange holes:

```
inner edge to inner edge = 16.90 mm
outer edge to outer edge = 22.70 mm

centre-to-centre = (16.90 + 22.70) / 2 = 19.80 mm
hole diameter    = (22.70 - 16.90) / 2 =  2.90 mm   -> M2.5, not M2
```

The 22.70 mm outer-to-outer figure also sets a floor on `plate_w`: the plate
cannot be narrower than ~25.7 mm without breaking out of the screw holes. That
independently corroborates the photo-scaled 26 mm width.

## Web thicknesses

The `.scad` echoes the three material webs on every render. All three want to be
≥ 1.2 mm (three perimeters at a 0.4 nozzle) or the plate cracks when the screws
are tightened. At the values above:

```
web beside pocket  : 1.75 mm
web above/below    : 5.80 mm
outboard of screw  : 2.85 mm
```

Five asserts also fire on render rather than letting a bad edit through: screw
holes must not merge into the rear pocket, the plate must not be narrower than
what it covers, `lip_t` must lie inside `plate_t`, the front lip must be smaller
than the rear pocket, and `lead_in` must not eat the whole lip.

## Regenerating

```sh
openscad -o usbc-panel-plate.stl usbc-panel-plate.scad
```

Previews:

```sh
openscad -o iso.png --imgsize=1400,900 --camera=0,0,0,55,0,25,70 usbc-panel-plate.scad
openscad -o top.png --imgsize=1400,700 --camera=0,0,0,0,0,0,55 --projection=ortho usbc-panel-plate.scad
```

## Printing

**Front face down**, flat on the bed, no supports. The model is built with
`z = 0` as the front face, so dropping it on the bed unrotated is already
correct — but the orientation now matters, and getting it upside down costs a
part.

Front-down is what makes the two-level opening printable. The 0.8 mm lip lays
down solid on the bed first, and the rear pocket then opens *outward* as Z
increases, so every new perimeter sits on material below it. Flip the part over
and that same lip becomes a 13.4 × 8.4 mm unsupported bridge.

The `lead_in` chamfer sits on the bed face, where it prints as a 45° overhang —
fine on an MK3S+ — and doubles as elephant's-foot relief on the one opening
whose size actually matters.

`hole_comp = 0.15` grows every hole radius to compensate for printed holes
coming out undersize on an MK3S+ with a 0.4 nozzle. If the screws are tight or
the connector won't seat, raise it before changing any nominal dimension.

STL output is gitignored here (repo convention — binaries live in
`OneDrive\3D printing\`); the `.scad` is the artefact worth keeping.
