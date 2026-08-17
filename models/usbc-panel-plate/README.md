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
| `gap_h` | **15.0** | **MEASURED** — height of the case opening |
| `gap_w` | 21.0 | ⚠️ **NOT MEASURED** — placeholder |
| `overlap` | 2.5 | chosen — how far the plate laps onto the panel |
| `plate_w` × `plate_h` | 26.0 × 20.0 | **derived** from `gap_*` + `overlap`, floored by the screw envelope |
| `plate_t` | 2.5 | chosen |
| `open_w` × `open_h` | 13.4 × 8.4 | photo-scaled, clears the connector's raised boss |

`plate_w` and `plate_h` are computed, not set. The plate must cover the opening
*and* keep both screw holes inside its own edge, so:

```
plate_w = max(gap_w + 2*overlap,  22.70 + 2*1.5)
plate_h = gap_h + 2*overlap
```

The `max()` floor means the width only responds to `gap_w` once the opening
exceeds 21 mm — below that, the screw envelope dominates and the plate stays
26 mm wide.

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
are tightened. At the defaults above:

```
web beside opening : 2.1 mm
web above/below    : 1.3 mm     <- the tight one; raise plate_h to improve
outboard of screw  : 1.8 mm
```

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

Flat on the bed, no supports — all three holes run straight through vertically.
The lead-in chamfer is on the top (`+Z`) face, so that face is the one a plug
enters from.

`hole_comp = 0.15` grows every hole radius to compensate for printed holes
coming out undersize on an MK3S+ with a 0.4 nozzle. If the screws are tight or
the connector won't seat, raise it before changing any nominal dimension.

STL output is gitignored here (repo convention — binaries live in
`OneDrive\3D printing\`); the `.scad` is the artefact worth keeping.
