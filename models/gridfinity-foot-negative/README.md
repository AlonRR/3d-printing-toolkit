# Gridfinity foot negative

A **negative volume**: the material you remove from a flat-bottomed model to leave a standard
gridfinity foot behind. Not a bin, and not a baseplate.

## Use

In PrusaSlicer: right-click the model → **Add negative volume** → **Load…** → pick an STL, then set
its Z to the bottom of the part. The mesh is centred on X/Y and sits on Z0. Anything of the model
outside the footprint keeps a flat skirt, which is usually what you want.

**The STLs are not in this repo.** `*.stl` is gitignored here by design — the `.scad` is the
source and meshes are generated artefacts. Regenerate them with:

```
openscad -D GridX=1 -D GridY=1 -o gridfinity-foot-negative-1x1.stl gridfinity-foot-negative.scad
openscad -D GridX=4 -D GridY=4 -o gridfinity-foot-negative-4x4.stl gridfinity-foot-negative.scad
```

| variant | footprint | render time |
|---|---|---|
| 1x1 | 42 × 42 × 4.65 mm | ~4 s |
| 4x4 | 168 × 168 × 4.65 mm | ~42 s |

Ready-to-load copies of both live in the OneDrive `Gridfinity` folder alongside the other
gridfinity assets, which is where they are actually loaded from.

`GridX`/`GridY` regenerate any size; `Clearance` defaults to 0 (nominal 42 mm pitch). Raise it to
0.1–0.25 only if prints seat too tightly — this is a negative, so **more clearance removes more
material and leaves a smaller foot**.

## Why it draws strokes where the reference sets cut voids

The profile is taken from `gridfinitybasket.scad` so both produce the same foot, but the solid is
built differently, and the reason is worth keeping.

The basket sweeps the profile around a rounded rectangle with `sweep_rounded()`. That works, and it
leaves **50 non-manifold edges** where the four wall segments meet the four corner `rotate_extrude`s.
Here each section of the profile is a `hull()` between two `offset()` rounded squares instead. A
rounded square is convex and the hull of two parallel convex profiles is a convex frustum, so every
section is manifold by construction — measured, both STLs export as closed meshes with **zero**
non-manifold edges.

The cross-section at any height is just the 34 mm core square offset outward by the profile's x at
that height, which is what makes the `offset()`/`hull()` construction exact rather than an
approximation of the swept version.

## Verified

The claim under test is not "it renders" but "subtracting this from a flat box yields a gridfinity
foot" — a negative that is inverted, offset or the wrong height still renders fine.

Predicted before measuring: the 1x1 box is 42 × 42 × 4.65 = **8202.600 mm³** and the negative
measures **1291.384 mm³**, so a correct complement must leave a foot of exactly **6911.216 mm³**.
Rendering *box minus negative* gives 6911.216 mm³ and matches a directly-rendered foot vertex for
vertex (identical sorted vertex sets; only facet normals differ). The 4x4's volume is 16.0000× the
1x1's, so the tiling has no overlap and no gap.

Note that the bounding box **cannot** discriminate here — the foot is 42 × 42 at its top and the
negative is 42 × 42 throughout, so both share the same box. The volume is what carries the test.
