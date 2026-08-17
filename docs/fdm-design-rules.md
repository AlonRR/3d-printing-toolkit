# FDM design rules — calibrated to this printer

Generic guides quote "1.2 mm minimum wall" and "0.4 mm nozzle". Neither is the
number that matters here. What governs is the **extrusion width the slicer
actually uses**, and on the MK3S+ profiles in this repo that is **0.45 mm**, not
0.4 — read straight out of a sliced file:

```
; extrusion_width                    = 0.45
; perimeter_extrusion_width          = 0.45
; external_perimeter_extrusion_width = 0.45
; layer_height                       = 0.15
; first_layer_height                 = 0.2
```

Everything below is derived from those, so it applies to *these* profiles rather
than to FDM in the abstract.

---

## 1. The single most useful rule: quantise thin walls

A wall is built from whole perimeters. Ask for a thickness that isn't a multiple
of the extrusion width and the slicer has to either leave a void in the middle
or over-extrude to close it. **Design thin walls at multiples of 0.45 mm.**

| Perimeters | Wall | Use for |
|---:|---:|---|
| 1 | **0.45 mm** | Nothing structural. Vase mode only |
| 2 | **0.90 mm** | Absolute minimum for a non-load feature |
| 3 | **1.35 mm** | Minimum for anything that takes force |
| 4 | **1.80 mm** | Comfortable structural default |
| 5 | **2.25 mm** | Anything a screw pulls against |

The in-between values are the trap. **1.1 mm is worse than 0.90 mm** — it's two
perimeters plus a 0.2 mm gap the slicer has to fudge, so you get a void, not a
thicker wall.

Same idea vertically. `0.2 + n × 0.15` are the only heights a feature can
actually land on:

```
0.35  0.50  0.65  0.80  0.95  1.10  1.25 ...
```

A 0.8 mm lip is exactly `0.2 + 4 × 0.15` — five clean layers. A 0.75 mm lip
would land mid-layer and round to the same thing anyway, just unpredictably.

## 2. Holes print undersize

Two causes stack: the extrusion is laid on the *inside* of the arc, and each
segment cuts the chord rather than following the curve. Expect **0.1–0.3 mm**
undersize on a 0.4 nozzle.

- Grow modelled holes by ~**0.15 mm on the radius** (that's what `hole_comp`
  does in the plate model).
- Below **2 mm diameter** holes distort badly or close up. Print a pilot and
  drill.
- A horizontal hole (axis parallel to the bed) prints as an oval and needs a
  **teardrop** profile to avoid the unsupported top arc.

## 3. Overhangs — the 45° rule is not the real rule

45° is a *consequence*, not a law. The actual constraint is that **each new
extrusion must land with at least ~50 % of its width sitting on the layer
below**. Everything else follows from that:

```
max horizontal step per layer  =  0.5 x extrusion_width
overhang angle from vertical   =  atan(step / layer_height)
```

45° only pops out when `layer_height == 0.5 x extrusion_width`. That is the Cura
default for a 0.4 nozzle (0.2 mm layers, 0.4 mm width) — which is why the number
got quoted everywhere. **It is not our profile.**

Extrusion width is **0.45 mm on every profile in this repo**, 0.2 and 0.15 alike.
Layer height is what varies, and it moves the answer:

| Step per layer | Supported | @ 0.15 mm layers | @ 0.20 mm layers |
|---:|---:|---:|---:|
| 0.225 mm | 50 % | **56°** | **48°** |
| **0.20 mm** | 56 % | **53°** | **45°** |
| 0.15 mm | 67 % | 45° | 37° |

**Thin layers buy overhang.** On the 0.15 profiles the layer is a third of the
extrusion width and 53° holds; on the 0.20 profiles the same 0.2 mm step is
exactly the textbook 45°. Check which profile you're slicing with before
trusting an angle.

### The 0.2 mm step — faking a 90° overhang

A true 90° overhang (a flat ceiling) cannot be printed onto air; it must be
bridged or supported. But it can be **staircased**: break the horizontal jump
into 0.2 mm steps, one per layer, and no single layer ever overhangs more than
it can carry.

```
   abrupt 90 deg ceiling          staircased at 0.2 mm/layer
   -- must bridge --              -- prints onto itself --

   +--------------+               +--------------+
   |              |               |            __|
   |              |               |         __|
   +-----+  +-----+               |      __|
         |  |                     |   __|
         |  |                     |  |
```

The cost is height, and the exchange rate is `layer_height / step`:

| Profile | Height per 1 mm of reach |
|---|---:|
| 0.15 mm layers, 0.2 mm step | **0.75 mm** |
| 0.20 mm layers, 0.2 mm step | **1.00 mm** |

So before staircasing anything, check the depth is there — and check it against
the profile you'll actually print with. Coarser layers make a staircase cost
*more* height, not less, which is the opposite of most people's intuition.

### Holes with a horizontal axis

A round hole lying parallel to the bed is the classic 90° case: its top arc
reaches horizontal at the apex, so it droops and closes up. Three fixes, in
order of preference:

1. **Teardrop** — keep the bottom semicircle, replace the top with a point. With
   a 53° capability the apex can be steeper than the usual 45°, but 45° is the
   safe default and costs nothing.
2. **Diamond / hexagon** — same idea, easier to model, uglier bore.
3. **Sacrificial bridge layer** — let the slicer bridge one flat layer across
   the top and drill it out after. Fine when the bore finish doesn't matter.

Vertical holes (axis along Z) have none of this problem — they are just
undersized per §2.

### Bridges and orientation

- **Bridges** are fine to ~10 mm on a well-cooled machine. The slicer spans the
  **short** axis of an opening, so a 13.4 × 8.0 pocket is an 8 mm bridge, not a
  13.4 mm one.
- **Parts are weak between layers.** XY is filament-strong, Z is
  adhesion-strong-only. Orient so load runs along the layers, never across them.
- A boss standing proud is free to print. The same boss on the bed makes
  everything around it an overhang. **Orientation is a design decision, not a
  slicer setting.**

## 4. Fasteners

- **Edge distance is the thing people get wrong.** Material between a screw hole
  and the part edge is a thin wall that will be *actively pulled apart* by the
  screw. Give it **3 perimeters (1.35 mm) minimum**, and prefer 1.80 mm.
- If the geometry genuinely can't afford it, an **edge-open U-slot** is stronger
  than a thin bridge — there's nothing left to split.
- Screws threading *into* plastic want a pilot around **0.8 × the thread
  diameter**, not a clearance hole. Clearance is for screws passing *through*.

## 5. Corners

Round or chamfer everything you can. Sharp internal corners are stress
concentrators and crack-initiation sites; sharp external corners at the bed
amplify elephant's foot. A small chamfer on the bed face costs nothing and
fixes both.

## 5a. One profile in this repo is vase mode

`0.2mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter, **lightning**`
carries `spiral_vase = 1`, `perimeters = 1`, `top_solid_layers = 0` and
`fill_density = 0%`. Slice a functional part with it and you get a single-wall
open shell — it will look plausible in preview and be useless in the hand.

The two safe 0.2 mm profiles are `0.20mm QUALITY @MK3 no skirt` and
`0.2mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter` (no `lightning`
suffix). Worth grepping the sliced G-code rather than trusting the dropdown:

```sh
grep -E "^; (spiral_vase|perimeters|layer_height) " out.gcode
```

## 6. Material notes for what's on the shelf

| | Warp | Bed | Watch for |
|---|---|---|---|
| **PLA** | low | 60 | Most dimensionally predictable — use it for fit tests even if the real part is ASA |
| **ASA** | **high** | 100 | Small thin features lift at the corners. Aggressive cooling splits layers — the tuned `Inslogic ASA - thin wall` profile runs 70 % fan and is single-wall only for that reason |
| **TPU** | n/a | 50 | Ignore tolerance rules; it deforms to fit. Slow retractions |

For a **fit test**, print in PLA regardless of the final material. You are
checking geometry, and PLA lies to you least.

---

## Applied: the USB-C panel plate

Audit of [`models/usbc-panel-plate/`](../models/usbc-panel-plate/) as it stands,
against §1 and §4. The `.scad` echoes all of these on every render.

| Feature | Value | Perimeters | Verdict |
|---|---:|---:|---|
| `web above/below` | 3.70 mm | 8.2 | ✅ |
| `web beside pocket` | 1.75 mm | 3.9 | ✅ |
| `frame over/under` | 1.25 mm | 2.8 | ⚠️ lands between 2 and 3 — quantise to **1.35** |
| `notch -> pocket` | 1.20 mm | 2.7 | ⚠️ same, quantise to **1.35** |
| `prot -> screw` | 1.10 mm | 2.4 | ⚠️ same, quantise to **1.35** |
| **`outboard of screw`** | **0.55 mm** | **1.2** | ❌ **one perimeter, and a screw pulls directly on it** |
| `lip_t` | 0.80 mm | 5 layers | ✅ exactly `0.2 + 4 × 0.15` |

**`outboard of screw` is the one that will actually fail.** It is a single
extrusion holding each screw hole to the plate edge, loaded in the exact
direction that splits it. §4 wants 1.35 mm there; it has 0.55.

It reads as acceptable only because the `min_w` margin on line 27 of the `.scad`
is commented out — that guard existed to enforce this rule. Three ways out:

1. **Restore the margin** → plate 25.7 mm wide, 1.5 mm outboard. ✅
2. **Edge-open U-slots** → nothing left to split; the plate slides onto the
   screws. Best if the plate must stay 23.8 mm.
3. Accept it, hand-tighten, treat the first print as disposable.

The three ⚠️ rows are not failures, just wasted material — each is a void the
slicer has to paper over. Rounding them to 1.35 mm makes them genuinely stronger
*and* faster to print.

### The pocket ceiling can be staircased instead of bridged

Printed back-face-down, the step from the rear pocket to the front lip is a flat
90° ceiling, and the lip has to bridge 8 mm across it. §3 says that jump can be
staircased at 0.2 mm per layer instead — and here the depth happens to be there:

```
pocket 13.4 x 8.0  ->  lip 9.3 x 3.6

horizontal reach : 2.20 mm   (the Y axis governs: (8.0 - 3.6) / 2)
depth available  : 1.70 mm   (plate_t 2.5 - lip_t 0.8)

@ 0.15 mm layers : needs 1.65 mm  -> FITS, margin +0.05 mm
@ 0.20 mm layers : needs 2.20 mm  -> DOES NOT FIT, short by 0.50 mm
```

**The part is printed on a 0.20 mm profile, so the full staircase is off the
table.** It only ever fitted by 0.05 mm at 0.15 mm layers, and the coarser
profile costs 1.00 mm of height per 1 mm of reach instead of 0.75 — which wipes
out the margin and then some.

This is exactly the trap the exchange-rate table exists to catch: the geometry
did not change, the *profile* did, and a staircase that was feasible became
impossible without anything in the model moving.

What the model does instead is a **single 0.2 mm ledge, one layer tall**, sitting
hard against the hole. It costs 0.2 mm of pocket depth rather than 2.2 mm, and
gives the ceiling something to start from. The remaining reach is still made in
one jump — which is fine, because an 8 mm bridge is comfortably within what the
machine does, on a face that ends up hidden against the connector anyway.

---

## Sources

- [Protolabs Network — How to design parts for FDM 3D printing](https://www.hubs.com/knowledge-base/how-design-parts-fdm-3d-printing/)
- [Layer X — FDM design rules: wall thickness, overhangs, bridging, tolerances](https://layerx3d.in/blog/fdm-design-rules-wall-thickness-overhangs-bridging-tolerances)
- [SGD3D — FDM 3D printing design guide: strength & accuracy](https://sgd3d.co.uk/3d-printing/fdm-3d-printing-design-guide/)
- [Mandarin3D — Wall thickness guide](https://mandarin3d.com/blog/wall-thickness-guide-minimum-and-optimal-measurements)
- [Simple Machining — DFM for 3D printing](https://www.simplemachining.com/blogs/dfm-for-3d-printing-a-practical-design-guide)

The extrusion-width, layer-height and bridge figures are read from this repo's
own sliced output, not from those pages.
