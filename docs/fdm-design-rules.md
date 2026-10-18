# FDM design rules — calibrated to this printer

Generic guides quote "1.2 mm minimum wall" and "0.4 mm nozzle". Neither is the
number that matters here. What governs is the **extrusion width the slicer
actually uses**, and on the six 0.4 mm-nozzle MK3S+ profiles in this repo that is
**0.45 mm**, not 0.4 — read straight out of a sliced file:

```
; extrusion_width                    = 0.45
; perimeter_extrusion_width          = 0.45
; external_perimeter_extrusion_width = 0.45
; layer_height                       = 0.15
; first_layer_height                 = 0.2
```

The three 0.8 mm-nozzle profiles (`... @0.8 nozzle ...` in `slicer/print/`) use
**0.90 mm**, with 0.3 or 0.4 mm layers over a 0.3 mm first layer. Everything
below is derived from the 0.45 mm profiles unless it says otherwise; on a 0.8 mm
profile, double every width. Read the width and the layer heights out of the
profile you will slice with, never from this page or a generic table.

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
thicker wall. On a 0.8 mm-nozzle profile the series is 0.90 / 1.80 / 2.70 mm.

Same idea vertically. A feature can only land on **first layer + n × layer
height**, so the series depends on the profile:

```
0.15 mm profile   0.2 + n x 0.15   0.35  0.50  0.65  0.80  0.95  1.10 ...
0.2 mm profiles   0.2 + n x 0.2    0.40  0.60  0.80  1.00  1.20  1.40 ...
0.10 mm profile   0.2 + n x 0.1    0.30  0.40  0.50  0.60  0.70  0.80 ...
```

A 0.8 mm lip lands on all three: five layers at 0.15, four at 0.2, seven at
0.10. A 0.75 mm lip would land mid-layer and round to a neighbour anyway, just
unpredictably. Choose heights for the profile the part will print on, and
recheck them if the profile changes.

## 2. Holes print undersize

Two causes stack: the extrusion is laid on the *inside* of the arc, and each
segment cuts the chord rather than following the curve. Expect **0.1–0.3 mm**
undersize on a 0.4 nozzle.

- Grow modelled holes by ~**0.15 mm on the radius** (`fdm_hole_comp` in the
  models that follow the scad-tools layout).
- **Holes under 2 mm print, but size them from a printed ladder**, not from the
  compensation alone, and never start one in a bridged layer:
  - A vertical hole through a floor, with a 45° lead-in at the bed so the first
    layer's squish cannot close it, prints open and usable at 1.04 mm as cut.
    Measured on a coupon in ASA at 0.2 mm layers (Oct 2026): holes cut 0.84,
    0.94, 1.04 and 1.14 mm (0.82 to 1.12 mm in the G-code) through a 2 mm floor,
    each with a 0.4 mm lead-in; 1.04 mm was the smallest that let a 0.64 mm
    wire core through and held it upright. The 0.84 and 0.94 mm holes did not
    let it through.
  - A hole that starts in a bridged layer prints closed: a 0.94 mm hole over a
    slot with a flat roof printed shut. §3c gives the measurement and the fix,
    a 45° roof.
  - A drill is the repair for a hole that printed tight, not the design: §3b.
- A horizontal hole (axis parallel to the bed) prints as an oval and needs a
  **teardrop** profile to avoid the unsupported top arc.

### Clearance between parts that have to fit together

**The measured house fits.** Each was found with a printed coupon on this printer, and each holds
for the material and profile it was measured in; for anything else, print a ladder (below). Values
are as cut in the model, hole compensation included. "House 0.2 mm profile" is
`0.2mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter`: 0.2 mm layers, 0.45 mm width.

| Fit | Value | What it is, and what the coupon showed | Measured in | When, and where it is recorded |
|---|---|---|---|---|
| **Pull-nut seat**, M3 | **5.7 mm** across the flats: 0.1 mm a side over the nut (0.15 compensation, −0.05 play) | A hex seat a nut is pulled up into once, with a spare screw, and stays in. Seats 5.5 to 5.9 tried: 5.5 would not go in, 5.6 too tight, 5.7 just right, 5.8 held, 5.9 let the nut slip out | ASA, house 0.2 mm profile | 10 Oct 2026. printer-enclosure `docs/bentobox-scrubber.md`, *The samples* (`bd5c933`); scad-tools `lib/nuts.scad`, `pull_nut_pocket`'s default fit (`1caee0a`) |
| **Side nut slot with a nut-shaped end**, M3 | **6.1 mm** across the flats: 0.3 mm a side (0.15 compensation, 0.15 play) | A slot a nut slides into from the side, its back end the nut's own shape: it held the nut still and kept it in. A square end as wide jammed the nut, and a narrower square end (5.8 mm) let it fall out easily | ASA, house 0.2 mm profile | 10 Oct 2026. printer-enclosure `docs/bentobox-scrubber.md`, *The samples* (`bd5c933`); scad-tools `lib/nuts.scad`, `nut_slot_hex_end`'s default fit (`ad8e628`) |
| **Friction grip** on a bought part | Ribs biting **0.05 mm** into its faces | Round ribs up a header's end walls, biting a fan plug's end faces: it goes on and off by hand and holds. 0.15, 0.25 and 0.35 mm were too tight. 0.05 was the smallest tried; nothing looser was printed | ASA, house 0.2 mm profile | 11 Oct 2026. fan-connector `README.md`, *The grip coupon* (`0860e86`) |
| **Clip over a lip** | Reach **0.1 mm** past a 0.3 mm lip, so the part squeezes past by 0.05 mm | A ridge with a 45° underside that the mating part's lip rides over and clicks under: it clicks on, holds and comes off by hand. 0.125, 0.15 and 0.25 mm were too tight; 0.1 was the smallest tried. A Z-quantised ladder, so it holds at 0.2 mm layers only | ASA, house 0.2 mm profile | 11 Oct 2026. fan-connector `README.md`, *The clip coupon* (`0860e86`) |
| **Hole for a solid wire core** | **1.04 mm** for a 22 AWG core (0.64 mm): 0.2 mm a side (0.15 compensation, 0.05 play) | A vertical hole through a 2 mm floor, with a 0.4 mm 45° lead-in at the bed: it lets the core through and holds it upright. 0.84 and 0.94 mm did not let it through | ASA, house 0.2 mm profile | 11 Oct 2026. fan-connector `README.md`, *The coupons' holes* (`5406e64`) |
| **Entrance for a TPU grommet** | A **0.6 mm** 45° chamfer round the hole's mouth | For a TPU grommet with a 45° lip, 0.1 mm proud of its hole all round, to click in: at 0.5 mm it clicked in but was a little hard; at 0.6 mm it was good | Coupon in **PETG** (what was loaded), grommet in TPU, the model drawn for the house 0.2 mm profile; the part it is for prints in ASA, where 0.6 is not yet proven | 11 to 14 Oct 2026. printer-enclosure `docs/bentobox-scrubber.md`, *The samples* (`d06c972`, `9ab731d`) |
| **A printed TPU bead's height** | Prints about **0.2 mm under** its drawn height | A hollow 2 mm bead, its wall one perimeter, drawn 0.4 mm proud of its land, stood 0.16 to 0.20 mm proud, and still sealed. Draw a printed seal's squeeze with this loss in it | TPU 95A, house 0.2 mm profile | 9 Oct 2026. printer-enclosure `docs/bentobox-scrubber.md`, *The samples* (`a5df3fa`) |

Two older model values were never measured: 0.25 mm a side for a pocket over a boss (the
`usbc-panel-plate` model, in the `parts` repository) and 0 nominal for a gridfinity foot in its
baseplate (`models/gridfinity-foot-negative`, 0.1 to 0.25 suggested only if it seats tightly). The generic figure quoted online is
around 0.3 mm a side; it is **not** a number from this printer and is not adopted here.

⭐ **Settle a new fit with a coupon, printed on the production profile in the production
material.** A clearance ladder — the same pin through a row of holes stepping 0.05 mm — gives the
answer in a single print. Fit moves with extrusion width and with the material's shrinkage, so a
coupon in another material measures another fit. Record the result **against the material and
profile it was printed in**, as the table does: a bare number with neither attached is the same
trap §1 exists to prevent.

⚠️ **A ladder whose rungs grow upwards is quantised by the layer.** The slicer cuts each layer at
its mid-height, so a feature whose size runs in Z - a ridge with sloped faces, a clip's catch over
a lip - prints as a staircase sampled once per layer, and rungs closer than that can slice alike.
Read each rung off the G-code (the perimeter path's position, layer by layer) and pick values that
print distinct; the result holds only at the layer height it was sliced at. A ladder that steps in
XY, like the pin through holes above, does not have this problem.
Measured on a clip coupon's G-code at 0.2 mm layers (Oct 2026): clips reaching 0.1, 0.15, 0.2 and
0.25 mm over a lip caught it by 0.07, 0.15, 0.15 and 0.19 mm, since every reach from 0.15 to 0.22
sliced to the same first layer over the lip; reaches of 0.1, 0.125, 0.15 and 0.25 gave even steps
of 0.04 mm.

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

Extrusion width is **0.45 mm on every 0.4 mm-nozzle profile in this repo**, 0.10,
0.15 and 0.2 alike. Layer height is what varies, and it moves the answer:

| Step per layer | Supported | @ 0.15 mm layers | @ 0.20 mm layers |
|---:|---:|---:|---:|
| 0.225 mm | 50 % | **56°** | **48°** |
| **0.20 mm** | 56 % | **53°** | **45°** |
| 0.15 mm | 67 % | 45° | 37° |

**Thin layers buy overhang.** On the 0.15 profile the layer is a third of the
extrusion width and 53° holds; on the 0.20 profiles the same 0.2 mm step is
exactly the textbook 45°; at the same step the 0.10 profile takes about 63°.
Check which profile you're slicing with before trusting an angle.

The 0.8 mm-nozzle profiles keep the same ratios at twice the size (0.90 mm
width over 0.3 or 0.4 mm layers), so the table holds for them with every step
doubled: the 0.3 mm profile reads like the 0.15 column, the 0.4 mm profiles like
the 0.20 column.

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
*more* height, not less, which is the opposite of most people's intuition. A
staircase that fits at one layer height can stop fitting at another with nothing
in the model moved.
Worked on a panel plate's pocket-to-lip step as first drawn (Aug 2026): 2.20 mm
of reach in 1.70 mm of depth needed 1.65 mm at 0.15 mm layers, which fitted by
0.05 mm, and 2.20 mm at 0.20 mm layers, 0.50 mm short.

Where the full staircase does not fit, take the steps that do, one layer each,
and bridge the rest in one jump if the span is short and the face is hidden.

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

## 3b. Standing design rules

**Prefer no support, and prefer permanent geometry over sacrificial.** Both rules, and why
needing a sacrificial feature signals a better design, are part design: they are in the
`printed-part-design` skill, in the owner's engineering-practices collection (private for now).
On this printer they decide the techniques below: of §3c's, the **geometry** ones are first
choice, and the **sacrificial** ones are listed to be recognised, not reached for.

## 3c. The named bridging techniques

Vocabulary, so a design conversation can point at one by name.

**Make nothing bridge** — permanent, no cleanup. Always try these first.

| Name | What it is |
|---|---|
| **Teardrop** / **diamond hole** | Horizontal-axis hole gets a pointed top instead of an arc |
| **Chamfer** / **45° taper** | A flat roof becomes a slope |
| **Arch** | A straight ceiling becomes a curve |
| **Staircase** / **stepped overhang** | The jump split into per-layer steps (§3) |

**Shorten the span** — the bridge still happens, it is just easier.

| Name | Permanent? |
|---|---|
| **Support rib** / **spar** / **intermediate wall** | ✅ permanent — first choice |
| **Sacrificial pillar** | ❌ snipped out |

**Change what the bridge lands on.**

| Name | Permanent? |
|---|---|
| **Bridge anchor** — make sure *both* ends are supported | ✅ |
| ⭐ **Two-bridge trick** | ✅ **permanent, and the one used here** |
| **Sacrificial bridge layer** — one solid layer, drilled out after | ❌ |

**Bridge vs overhang is not a distinction to blur.** A bridge has two anchored
ends and the strand is held in tension between them. An overhang is a
cantilever, held at one end only. They fail differently and the fixes differ.

### ⭐ The two-bridge trick — in three layers

The problem it solves is **a bridge with a hole in it** — a roof over a cavity
that also has an opening in it. The printer is asked to draw the hole's outline
in mid-air and produces spaghetti.

The house version runs over three layers, and the rule is **each layer does
exactly one thing**:

```
L1  THE TWO BRIDGE   slot the hole out to the cavity's FULL extent on the
                     SHORT axis. What gets laid is two strips spanning
                     wall-to-wall, each anchored at BOTH ends.

L2  THE RECTANGLE    close to a plain rectangle, SQUARE corners, hole-sized.
                     The two remaining sides bridge across onto those strips.

L3  THE CORNERS      the real rounded shape. The only new material is the
                     fillets, and they sit on the solid rectangle below.

   L1                 L2                 L3
+--+      +--+     +--+------+--+     +--+------+--+
|  |      |  |     |  |      |  |     |  /      \  |
|  |  gap |  |     |  | rect |  |     |  | hole |  |
|  |      |  |     |  |      |  |     |  \      /  |
+--+      +--+     +--+------+--+     +--+------+--+
```

**Why three and not two.** Closing straight from a rectangle to a rounded hole
lays an arc whose supporting material is only half there. Giving the curve its
own layer means no layer ever has to lay a straight run *and* a curve in the
same pass — and nothing curved is ever unsupported.

Rules that make it work:

- **Slot L1 across the short axis.** The slicer bridges the short span anyway,
  and it keeps L1 under the ~10 mm ceiling.
- **Every intermediate stage stays square.** A rounded slot puts an arc back in
  mid-air, which is the thing being removed.
- **One layer per stage**, and `layer_h` must match the slicer or the stages
  land mid-layer and get rounded away.
- **Each cut a superset of the one below**, so the larger opening wins at its
  own height and nothing depends on the order the cuts are written in.
- Costs one layer of cavity depth per stage. Check the depth is there.

Three guards are worth asserting, because each fails while the render still
succeeds and the part still looks right:

| Guard | What it catches |
|---|---|
| both spans ≤ 10 mm | sagging |
| slot taller than the hole | L1 and L2 collapse to the same shape |
| corner radius > 0 | L2 and L3 collapse to the same shape |

**Nothing is sacrificial.** All three layers are load-bearing geometry, nothing
is removed afterwards, and the sliced G-code should carry
`support_material = 0`. That is what makes this preferable to a sacrificial
bridge layer for the same problem — see §3b.

Example, a panel plate's pocket opening into a smaller lip (the `usbc-panel-plate` model in
the `parts` repository): L1 a 9.6 × 8.8 slot, two strips spanning 8.8 mm; L2 a 9.6 × 3.9
rectangle, its other sides bridging 9.6 mm onto the strips; L3 the r2 fillets only. Both spans
under 10 mm, all three guards asserted in the model, and `support_material = 0` in the G-code.

### Simpler over a narrow slot: roof it at 45°

A hole over a narrow slot needs no bridge at all. Roof the slot at 45° up to a
ridge, and let the hole start where the ridge has narrowed to it. Every layer
then sits 0.2 mm in from the one below it. The cost is half the slot's width in
height above it. Check every hole that starts over a cavity before the first
print: under a flat roof the slicer lays the hole's rim as overhang perimeters
over air, and the hole prints closed. A roof that narrows to the hole also guides
whatever goes into it, a wire's core for instance.

Measured on a part in ASA at 0.2 mm layers (Oct 2026): a 0.94 mm hole over a
1.9 mm slot with a flat roof printed closed, and a wire core could not go in;
its G-code had eight overhang perimeters in the first layer over the slot. With
the 45° roof the G-code has none. The roofed version has not been printed yet.

## 4. Fasteners

- **Edge distance is the thing people get wrong.** Material between a screw hole
  and the part edge is a thin wall that will be *actively pulled apart* by the
  screw. **3 perimeters (1.35 mm) is the printing floor**, and 1.80 mm is better:
  §1 gives nothing thinner to anything that takes force, and a screw pulls. It is
  a floor, not a strength rating. How much edge a loaded screw needs is a question
  for the engineering principles (the `printed-part-engineering` skill): at least
  the hole's diameter or twice the part's thickness, whichever is greater, so
  usually more - 3.6 mm for an M3 clearance hole in a 1.8 mm part. Where both
  apply, the larger wins.
- If the geometry genuinely can't afford it, an **edge-open U-slot** is stronger
  than a thin bridge — there's nothing left to split.
- Screws threading *into* plastic want a pilot around **0.8 × the thread
  diameter**, not a clearance hole. Clearance is for screws passing *through*.


Two named features, in the §3c style, so a design conversation can point at one:

- **Pinch clamp** — a slit through a boss, closed by a bolt through a captive nut, tightening a
  bore around a rod. Converts a sliding fit into a locked one without a grub screw biting into
  the rod, and it is permanent geometry rather than an added part.
- **Compliant feature** — a deliberately thinned or slotted section that flexes so two parts
  push together and stay. §3b prefers this to a sacrificial alignment aid. ⚠️ It is a flexure,
  so if it is both preloaded *and* hot, the stress-relaxation caution in the
  `printed-part-engineering` skill applies to it (see
  [annealing-and-hot-service.md](annealing-and-hot-service.md)).

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

The three safe 0.2 mm profiles are `0.20mm QUALITY @MK3 no skirt`,
`0.2mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter` and
`0.2mm QUALITY @MK3 - ULG, no skirt, no brim, no crossing perimeter` (no
`lightning` suffix). `scad-tools/scripts/scad-check.sh` refuses a G-code with
`spiral_vase = 1`. Worth grepping the sliced G-code rather than trusting the
dropdown:

```sh
grep -E "^; (spiral_vase|perimeters|layer_height) " out.gcode
```

### 5b. Shapes that resist warping — round the plan view first

⚠️ **Untested here.** Reasoning plus one measured fact from this repo, not a result from this
printer.

§6 records that ASA's *small thin features lift at the corners*. A brim is not the answer: **no
skirt, no brim and no draft shield on any print** (a draft shield is drawn from the skirt), and a
part designed correctly needs no brim. So the geometry answer is the only one, and
`scad-tools/scripts/scad-check.sh` fails any G-code with a skirt or a brim.

- ⭐ **Round the corners as seen from above.** Lifting starts at a sharp corner in the plan view,
  where the largest contraction meets the smallest bonded area. A radius there is permanent, costs
  nothing per copy, and stays on the part.
- **Mouse ears** — small thin discs at the corners, trimmed off afterwards. ⛔ **Sacrificial, so
  §3b applies.** They are the same class of answer as a brim, which is ruled out, just with less
  cleanup. Recognise them; use the radius. [`scripts/add_brim_ears.py`](../scripts/add_brim_ears.py)
  still adds them to an STL: it stays as a tool for other people's parts, drawn without this
  printer in mind. The house designs here don't use ears - design the warping out instead.
- Concentric slits cut into the underside of a large flat part are sometimes offered as stress
  relief. Not tested here, and it trades a sealed base for a slotted one — recorded for
  completeness, not recommended.

### 5c. Which way round to put text — measured here

A two-way rule. Both halves come from `models/petg-temp-tower`, which does each deliberately:

| face | do this | why |
|---|---|---|
| **Vertical** | **raise** the text | engraved text at this size *fills in* — the band numbers are embossed outward for exactly this reason |
| **Horizontal** | **engrave** it | raised text on a top face is fragile and collects stringing — the base label is engraved for exactly this reason |

Under about **5 mm digit height** the digits close up either way at a 0.4 nozzle, which is why that
model uses 6.0 mm.

**Size a mark by its stroke, not its height.** A stroke wants at least two extrusions (0.9 mm)
across. In Liberation Sans Bold, the font OpenSCAD ships with, the stem is **0.21 ×** the cap
height and the crossbar **0.17 ×**: `text(size = 10)` draws caps 9.55 mm tall, stems 2.00 mm wide
and crossbars 1.65 mm (Arial Bold: 0.20 and 0.17). So 0.9 mm strokes need caps of about 4.3 mm
for the stems and 5.3 mm for the crossbars, and that is where the 5 mm rule above comes from: the
extrusion width showing through the font. A lighter font needs taller letters. Measured from
OpenSCAD's SVG export (Oct 2026).

**Check that the font resolves.** OpenSCAD substitutes another face, without an error, when the
named font is not installed. Measured here (Oct 2026): `DejaVu Sans:style=Bold`, not installed,
rendered exactly as Liberation Sans Bold and as a made-up font name in the 2021.01 release, and as a
different face again in the nightly. Name a font that ships with OpenSCAD, or check the render.

**A G-code that keeps a mark's strokes says nothing about whether the eye can read it.** Measured on
coupons in ASA at 0.2 mm layers (Oct 2026): 1.4 mm bold digits engraved 0.4 mm into a wall's top
kept a path round every stroke in the G-code, leaving grooves about 0.3 mm wide, as the stroke ratios
predict, and printed illegible.

**Where there is no room for 5 mm letters, mark with a shape the nozzle draws whole: recessed round
dots, counted.** The current mark is a dot **1.6 mm across and 0.6 mm deep** (three layers at
0.2 mm), dots **3 mm apart** centre to centre, recessed into the face that prints on the bed. Guard
each one: two extrusions across, two layers deep or more, and two extrusions of face between
neighbours. Read in the G-code that each dot stays open through its layers. Proven legible in PETG,
on a fit coupon printed face down (Oct 2026); not yet proven in ASA.

**Keep marks off working surfaces**: not on a face that presses, seals, slides or carries load.
Line notches across a wall's top (0.7 mm wide, through the wall, counted I to IIII) were dropped
before they were printed, because they cut into walls that a mating plug presses on.

**An engraved gap is straight-sided and wider than one extrusion**, about 0.7 mm, so the paths on
either side leave it open. A V narrows below a line's width part way down, and the layers there run
over it. From the notches' G-code, where each 0.7 mm straight-sided notch stayed a gap of its drawn
width (Oct 2026); never printed.

## 6. Material notes for what's on the shelf

How each material behaves on this printer. Temperatures are not repeated here: the filament
profiles under [`slicer/filament/`](../slicer/filament/) are their source of truth, the bed's
included.

| | Warp | Watch for |
|---|---|---|
| **PLA** | low | Most dimensionally predictable of the three |
| **ASA** | **high** | Small thin features lift at the corners. Aggressive cooling splits layers — the tuned `Inslogic ASA - thin wall` profile runs 70 % fan and is single-wall only for that reason |
| **TPU** | n/a | Ignore tolerance rules; it deforms to fit. Slow retractions |

A fit test is printed on the production profile in the production material, whatever is easiest
to print: §2.

### 6b. The filaments on this shelf, by what the part has to survive

How to choose a material - by what the part must survive, why an HDT is not a service
temperature, why a data sheet's test bars overstate a printed part, and the findings that hold
beyond this shelf - is in the `printed-part-engineering` skill, in the owner's
engineering-practices collection (private for now). This section is the data it is used with:
the §6 table above ranks the shelf by how hard each material is to *print*; this one by how the
finished part fails, from Inslogic's own data sheets, transcribed in
[`../slicer/reference/inslogic-filament-data.md`](../slicer/reference/inslogic-filament-data.md).

| | **PLA Pro** | **PETG Pro** | **ASA** |
|---|---|---|---|
| Tensile strength | **56.0 MPa** | 50.0 MPa | 52.4 MPa |
| Elongation at break | 20.3 % | **34.5 %** | 21.4 % |
| Flexural strength | **85.8 MPa** | 81.9 MPa | 75.2 MPa |
| Flexural modulus | **2795 MPa** | 2750 MPa | 2162 MPa |
| **Izod impact, notched** | **20.1 kJ/m²** | **4.8 kJ/m²** | 18.3 kJ/m² |
| **HDT @ 0.45 MPa** | 55.0 °C | 72 °C | **98 °C** |
| Glass transition | 65.3 °C | 65.5 °C | **108 °C** |

What the table says about this shelf:

- **PLA Pro is the toughest of the three on impact — 4.2× this PETG** on notched Izod. PLA Pro
  is a toughened grade; its own sheet claims "impact strength similar to ABS", and the 18.3 vs
  20.1 against ASA bears that out. PETG Pro's low figure is notch sensitivity: read its
  elongation beside it. For a part whose failure mode is being dropped, PLA Pro is the strongest
  thing on this shelf.
- **ASA wins on heat by a mile, and that is often the real constraint.** HDT 98 °C at 0.45 MPa
  against PLA Pro's 55 °C. A part left in a car in an Israeli summer sees 60–70 °C in the cabin
  and more on a dashboard — PLA Pro sags there, PETG is marginal, ASA does not care. Add UV
  stability and ASA is the only one of the three that survives outdoors long-term.
- **PETG Pro's sheet gives a glass transition (65.5 °C) below its own HDT (72 °C)**, which cannot
  both be right for an amorphous plastic; published PETG figures are nearer 78–85 °C. Treat 65.5 as the
  conservative figure, as the transcription above explains.

These are test bars, not printed parts: rank the three against each other with the table, never
read it as a printed part's strength, and orient the part so its load runs along the layers — §3.

**So, by what the part must survive:**

| The part is… | Use | Why |
|---|---|---|
| Dropped, thrown, played with, indoors | **PLA Pro** | Highest notched impact here, cheapest, easiest to print and to paint, no enclosure needed |
| Left in a car, outdoors, or in the sun | **ASA** | HDT 98 °C and UV-stable, so both the part and its paint survive. Costs an enclosure and fume handling |
| Needing to bend without snapping | **PETG** | 34.5 % elongation — it yields where the others crack. Poor on notched impact though |
| Held to a tight dimension | **PLA** | Least warp, most predictable. §6 |

⛔ **Avoid Matte PLA for anything structural.** The matting additive is a filler,
and it costs layer adhesion most; the figures are in the `printed-part-engineering`
skill. It is a lovely finish for a display piece and the wrong choice for a
toy. If the appeal was that matte hides layer lines and takes primer well, five
minutes with 200-grit on PLA Pro buys the same surface and costs no strength.

**Printed parts for children — three things that are not about the plastic:**

- **Paint and primer, not just the filament.** Look for craft acrylics marked
  **EN 71-3** (European toy safety, migration of certain elements) or
  **ASTM D-4236**, and seal with a water-based varnish. Solvent enamels and
  rattle-can primers are the wrong end of this for something that gets handled
  and mouthed.
- **Layer lines hold dirt.** A sealed, painted surface is easier to clean than
  bare FDM, which is a hygiene argument for finishing rather than a cosmetic one.
- **Small parts come off.** Design for it — fillets over chamfered edges, no
  snap-off tabs, and nothing small enough to swallow on a toy for a young child.


### 6a. Joining two printed parts

The house rule mirrors §3b: prefer the permanent, structural option. Design the
joint out first - print it as one part, or add a fastener - as the
`printed-part-design` skill says. Where a bond is still needed on ASA and ABS, the
strongest is a solvent weld — but it is **currently gated**, so read the gate
before the technique.

> ⛔ **ACETONE IS RULED OUT UNTIL THE FILTRATION SYSTEM IS RUNNING.**
> Alon's decision, 21 Aug 2026, restated as a condition rather than a permanent
> ban on 30 Aug. It is a decision, not a gap in anyone's information — do not
> route around it, and do not propose acetone, acetone slurry or ABS juice while
> the gate is closed. Until then, use the *Meanwhile* section below.
>
> **What the gate needs is the system running in its extract-to-outside mode.**
> Extraction is part of the planned filtration system, so this is one milestone,
> not two — but the *mode* matters, because the same hardware can run two ways:
> - **Recirculating** (Bento-style HEPA + carbon, air returned to the chamber)
>   is what handles particulates and VOCs during a print, and is what keeps the
>   chamber hot for ASA.
> - **Extracting to outside** is what solvent work needs. Vapour smoothing and
>   solvent welding release far more than a carbon tray can hold, and acetone is
>   **flammable** — lower explosive limit about 2.5 % by volume in air. Keep
>   ignition sources out of the vapour path; motors and heaters count.
>
> A recirculate-only build therefore never opens this gate.
> [chamber-sensor §8](https://github.com/AlonRR/printer-enclosure/blob/main/docs/chamber-sensor/heating-and-airflow.md) works through the airflow design that
> serves both.

**When the gate opens**, ASA and ABS solvent-weld in acetone. **Meanwhile**, a
bond that is still needed takes two-part epoxy where it is structural, and
cyanoacrylate only to tack parts in place or for TPU, PLA and dissimilar
materials. How each of these holds a print, in order of joint strength - and why a
CA joint peels the outer perimeter off the layer beneath it - is in the
`printed-part-engineering` skill.

**Do not mail-order cyanoacrylate.** It has a short shelf life and polymerises
in the bottle with age and heat, so slow shipping through a hot summer is the
worst case for it. Buy it locally and fresh — and buy acetone locally too, when
the gate opens, since shipping flammable solvent is a non-starter.

---

## Applied: auditing a part against §1 and §4

- **Grade every thin feature in perimeters.** Divide each web, frame and edge distance by the
  extrusion width: a feature between two whole counts (2.4 or 2.7 perimeters) prints as the lower
  count plus a gap the slicer fudges, so it is a warning, not a pass. Have the model echo each of
  them on every render, so the grade cannot go stale. Example: the `usbc-panel-plate` model (in
  the `parts` repository) grades its features from 5.60 mm (12.4 perimeters) down to 0.95 mm (2.1),
  three of them between 2 and 3.
- **Audit from the dimensions the geometry is cut with, never the nominal ones.** Define the as-cut
  sizes once at file scope, and derive every echo, assert and cut from them, so the audited number
  and the built geometry have no chance to disagree.
  Found in that plate's audit (Aug 2026): the echo computed the material outboard of a screw from
  the nominal hole while the cut was grown by the hole compensation, and reported 0.55 mm where
  0.40 mm, under one extrusion, was cut.

> **A diagnostic that measures something adjacent to what it claims is worse
> than no diagnostic.** The 0.55 mm figure had been quoted a dozen times as
> evidence the part was merely marginal.

---

## Claims deliberately NOT imported

A design-tips poster (in Sources) was compared tip by tip against this document. Most of its advice
is already here and more precisely, because these numbers come from this printer's own sliced
output. Three of its claims **conflict** with what this machine does, and are recorded so nobody
imports them later by accident:

| the poster says | this repo measures | why they differ |
|---|---|---|
| wall steps 0.8 / 1.2 / 1.6 mm | **0.90 / 1.35 / 1.80** | it assumes a 0.4 mm extrusion width; §1 uses the width the slicer actually emits, **0.45** on the 0.4 mm nozzle |
| bridges of "2 cm+" | **~10 mm** | asserted in [`usbc-panel-plate.scad`](https://github.com/AlonRR/parts/tree/main/models/usbc-panel-plate) against the ceiling this machine was measured at |
| engrave text into vertical faces | **raise** it on vertical faces | §5c — engraved text at readable sizes fills in here |

⭐ **The pattern is worth more than the three corrections.** Every conflict is a generic figure
meeting a measured one, and in each case the generic figure is not wrong in general — it is wrong
*for this extrusion width, this cooling, this nozzle*. That is the same reason §1 tells you to read
the width out of the profile instead of trusting a table.

## Sources

- [Protolabs Network — How to design parts for FDM 3D printing](https://www.hubs.com/knowledge-base/how-design-parts-fdm-3d-printing/)
- [Layer X — FDM design rules: wall thickness, overhangs, bridging, tolerances](https://layerx3d.in/blog/fdm-design-rules-wall-thickness-overhangs-bridging-tolerances)
- [SGD3D — FDM 3D printing design guide: strength & accuracy](https://sgd3d.co.uk/3d-printing/fdm-3d-printing-design-guide/)
- [Mandarin3D — Wall thickness guide](https://mandarin3d.com/blog/wall-thickness-guide-minimum-and-optimal-measurements)
- [Simple Machining — DFM for 3D printing](https://www.simplemachining.com/blogs/dfm-for-3d-printing-a-practical-design-guide)
- Billie Ruben, *CAD Design Tips for 3D Printing* — [infographic poster](https://imgur.com/gallery/i-made-another-infographic-poster-3d-printing-SqIdFwB). Someone else's work, so linked rather than reproduced. Compared tip by tip against this document; see *Claims deliberately NOT imported* above.

The extrusion-width, layer-height and bridge figures are read from this repo's
own sliced output, not from those pages.
