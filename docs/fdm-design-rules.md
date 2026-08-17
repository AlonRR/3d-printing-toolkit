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

## 3. Overhangs, bridges, orientation

- **45°** from vertical is the practical overhang limit. Past it, droop.
- **Bridges** are fine to ~10 mm on a well-cooled machine; the slicer spans the
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

---

## Sources

- [Protolabs Network — How to design parts for FDM 3D printing](https://www.hubs.com/knowledge-base/how-design-parts-fdm-3d-printing/)
- [Layer X — FDM design rules: wall thickness, overhangs, bridging, tolerances](https://layerx3d.in/blog/fdm-design-rules-wall-thickness-overhangs-bridging-tolerances)
- [SGD3D — FDM 3D printing design guide: strength & accuracy](https://sgd3d.co.uk/3d-printing/fdm-3d-printing-design-guide/)
- [Mandarin3D — Wall thickness guide](https://mandarin3d.com/blog/wall-thickness-guide-minimum-and-optimal-measurements)
- [Simple Machining — DFM for 3D printing](https://www.simplemachining.com/blogs/dfm-for-3d-printing-a-practical-design-guide)

The extrusion-width, layer-height and bridge figures are read from this repo's
own sliced output, not from those pages.
