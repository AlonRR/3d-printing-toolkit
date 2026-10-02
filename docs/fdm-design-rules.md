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

### Clearance between parts that have to fit together

⚠️ **There is no house default, and that is a gap rather than a decision.** Every model here picks
its own, and the two that exist do not agree:

| model | clearance | on what |
|---|---|---|
| `usbc-panel-plate` | **0.25 mm/side** | a pocket over a boss |
| `gridfinity-foot-negative` | **0** nominal, 0.1–0.25 suggested only if it seats tightly | a foot in a baseplate |

Both are values that happened to work, not measurements. The generic figure quoted online is around
0.3 mm/side; it is **not** a number from this printer and is not adopted here.

⭐ **Settle it with a test print rather than by picking one.** A clearance ladder — the same pin
through a row of holes stepping 0.05 mm — gives the answer in a single print. Record the result
**against the profile it was measured on**, exactly as §1 does for extrusion width: fit tolerance
moves with extrusion width and with material shrinkage, so a bare number with no profile attached
is the same trap §1 exists to prevent.

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

## 3b. Standing design rules

Two, and they decide most of the choices below before the geometry is drawn:

> **Prefer no support.**
> **Prefer permanent over sacrificial.**

If a design seems to need a sacrificial feature, that is usually a signal a
better design exists — not a licence to add the sacrificial feature. Snipping,
drilling and cleanup are recurring costs paid on every copy, and each one is a
chance to damage the part.

So of the techniques below, the **geometry** ones are first choice; the
**sacrificial** ones are listed to be recognised, not reached for.

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

Worked example, the USB-C plate's pocket → lip:

```
L1  slot 9.6 x 8.8    -> two strips spanning 8.8 mm, anchored both ends
L2  9.6 x 3.9 square  -> the other two sides bridge 9.6 mm onto those strips
L3  r2 fillets only   -> laid on the solid rectangle below
```

Both spans under 10 mm, all three guards asserted in the model, and the sliced
G-code confirms `support_material = 0`.

## 4. Fasteners

- **Edge distance is the thing people get wrong.** Material between a screw hole
  and the part edge is a thin wall that will be *actively pulled apart* by the
  screw. Give it **3 perimeters (1.35 mm) minimum**, and prefer 1.80 mm.
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
  so if it is both preloaded *and* hot, the stress-relaxation caution in
  [annealing-and-hot-service.md](annealing-and-hot-service.md) applies to it.

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

### 5b. Shapes that resist warping — round the plan view first

⚠️ **Untested here.** Reasoning plus one measured fact from this repo, not a result from this
printer.

§6 records that ASA's *small thin features lift at the corners*. The answer used to be process —
the `ASA brim + draft shield` profile, `brim_width = 5` — and **that is ruled out since 2 Oct 2026**:
never a skirt, and a part designed correctly needs no brim (Alon). So the geometry answer is the only
one, and `scripts/scad-check.sh` fails any G-code with a skirt or a brim.

- ⭐ **Round the corners as seen from above.** Lifting starts at a sharp corner in the plan view,
  where the largest contraction meets the smallest bonded area. A radius there is permanent, costs
  nothing per copy, and stays on the part.
- **Mouse ears** — small thin discs at the corners, trimmed off afterwards. ⛔ **Sacrificial, so
  §3b applies.** They are the same class of answer as a brim, which is ruled out, just with less
  cleanup. Recognise them; use the radius.
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

## 6. Material notes for what's on the shelf

| | Warp | Bed | Watch for |
|---|---|---|---|
| **PLA** | low | 60 | Most dimensionally predictable — use it for fit tests even if the real part is ASA |
| **ASA** | **high** | 100 | Small thin features lift at the corners. Aggressive cooling splits layers — the tuned `Inslogic ASA - thin wall` profile runs 70 % fan and is single-wall only for that reason |
| **TPU** | n/a | 50 | Ignore tolerance rules; it deforms to fit. Slow retractions |

For a **fit test**, print in PLA regardless of the final material. You are
checking geometry, and PLA lies to you least.

### 6b. Choosing a material by what the part has to survive

The §6 table above ranks materials by how hard they are to *print*. This one
ranks them by how the finished part fails, using the numbers from Inslogic's own
data sheets, transcribed in
[`../slicer/reference/inslogic-filament-data.md`](../slicer/reference/inslogic-filament-data.md),
rather than folklore.

| | **PLA Pro** | **PETG Pro** | **ASA** |
|---|---|---|---|
| Tensile strength | **56.0 MPa** | 50.0 MPa | 52.4 MPa |
| Elongation at break | 20.3 % | **34.5 %** | 21.4 % |
| Flexural strength | **85.8 MPa** | 81.9 MPa | 75.2 MPa |
| Flexural modulus | **2795 MPa** | 2750 MPa | 2162 MPa |
| **Izod impact, notched** | **20.1 kJ/m²** | **4.8 kJ/m²** | 18.3 kJ/m² |
| **HDT @ 0.45 MPa** | 55.0 °C | 72 °C | **98 °C** |
| Glass transition | 65.3 °C | 65.5 °C | **108 °C** |

Two results here contradict the usual rules of thumb, and both matter:

**PLA Pro is the toughest of the three on impact — 4.2× this PETG.** "PETG is
tougher than PLA" is true of *commodity* PLA, which runs 2–5 kJ/m². PLA Pro is a
toughened grade; its own sheet claims "impact strength similar to ABS" and the
18.3 vs 20.1 against ASA bears that out. For a part whose failure mode is being
dropped, PLA Pro is the strongest thing on this shelf.

**ASA wins on heat by a mile, and that is often the real constraint.** HDT 98 °C
against PLA's 55 °C. A part left in a car in an Israeli summer sees 60–70 °C in
the cabin and more on a dashboard — PLA Pro sags there, PETG is marginal, ASA
does not care. Add UV stability and ASA is the only one of the three that
survives outdoors long-term.

⚠️ **These are ISO test bars, not printed parts.** Injection-moulded specimens
are isotropic; a printed part is much weaker across layers, typically by half or
worse. Use the table to rank materials against each other, never as an absolute
strength for a printed part. Orientation still decides more than material — see
§2.

**So, by what the part must survive:**

| The part is… | Use | Why |
|---|---|---|
| Dropped, thrown, played with, indoors | **PLA Pro** | Highest notched impact here, cheapest, easiest to print and to paint, no enclosure needed |
| Left in a car, outdoors, or in the sun | **ASA** | HDT 98 °C and UV-stable, so both the part and its paint survive. Costs an enclosure and fume handling |
| Needing to bend without snapping | **PETG** | 34.5 % elongation — it yields where the others crack. Poor on notched impact though |
| Held to a tight dimension | **PLA** | Least warp, most predictable. §6 |

⛔ **Avoid Matte PLA for anything structural.** The matting additive is a filler,
and it costs strength: measured layer adhesion on matte grades runs around **a
third** of the same maker's standard PLA, with bending strength roughly 53 MPa
against 76. It is a lovely finish for a display piece and the wrong choice for a
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

The house rule mirrors §3b: prefer the permanent, structural option. For ASA and
ABS that option is a solvent weld — but it is **currently gated**, so read the
gate before the technique.

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
> [chamber-sensor.md §8](chamber-sensor.md) works through the airflow design that
> serves both.

**When the gate opens: ASA and ABS solvent-weld in acetone, and that beats any
adhesive.** Wet both mating faces, clamp, and the surfaces chemically fuse into a
single piece — roughly as strong as the surrounding print. Free gap filler, from
waste: dissolve failed ASA prints in acetone to a syrup, which is adhesive,
filler and colour-match at once.

**Meanwhile — what to actually use.** In rough order of joint strength:

1. **Design the joint out.** Print it as one part, or add a fastener. §3b already
   prefers permanent geometry over sacrificial; a screw into a printed boss or a
   captive nut beats every adhesive on this list and is reversible.
2. **Two-part epoxy** for anything structural. It is the closest non-solvent
   substitute for a weld: it fills gaps — which matters, because FDM mating faces
   are never truly flat — and it bonds ASA, ABS, PLA and PETG alike. Slower and
   messier than CA, and that is the trade.
3. **Cyanoacrylate for what CA is actually good at**: TPU, PLA, dissimilar
   materials, and tacking parts in place before a fastener or epoxy goes in.

**Why CA is third and not first.** It bonds only to the outer skin, so a CA joint
on an FDM part fails by **peeling the outer perimeter off the layer beneath it** —
a different failure mode from the material's own strength, at a much lower load.
It also fills no gaps. It is a positioning adhesive here, not a structural one.

**Do not mail-order cyanoacrylate.** It has a short shelf life and polymerises
in the bottle with age and heat, so slow shipping through a hot summer is the
worst case for it. Buy it locally and fresh — and buy acetone locally too, when
the gate opens, since shipping flammable solvent is a non-starter.

- [Prusa — The great guide to gluing and assembling 3D prints](https://blog.prusa3d.com/the-great-guide-to-gluing-and-assembling-3d-prints_44908/)
- [Formfutura — The ultimate 3D prints bonding guide](https://www.formfutura.com/blog/blogs-1/the-ultimate-3d-prints-bonding-guide-50)

---

## Applied: the USB-C panel plate

Audit of [`models/usbc-panel-plate/`](../models/usbc-panel-plate/), against §1
and §4. The `.scad` echoes all of these on every render — and, since the review
of 18 Aug 2026, computes them from the **as-cut** dimensions rather than the
nominal ones.

| Feature | As cut | Perimeters | Verdict |
|---|---:|---:|---|
| `web above/below` | 5.60 mm | 12.4 | ✅ |
| `outboard of screw` | 2.70 mm | 6.0 | ✅ |
| `frame beside port` | 2.55 mm | 5.7 | ✅ |
| `web beside pocket` | 1.20 mm | 2.7 | ⚠️ between 2 and 3 perimeters |
| `frame over/under` | 1.10 mm | 2.4 | ⚠️ same |
| `prot -> screw` | 0.95 mm | 2.1 | ⚠️ same |
| `lap left at notch` | 0.55 mm | — | ⚠️ thin, but it is lap not structure |
| `lip_t` | 0.80 mm | 4 layers | ✅ whole layers at 0.2 mm |

### The trap this section exists to record

`outboard of screw` used to read **0.55 mm** here and was graded a failure. It
was worse than that: the echo computed `(plate_w - screw_span - screw_d) / 2`
from the *nominal* hole, while the cut was grown by `hole_comp`. The real figure
was **0.40 mm** — under a single extrusion.

> **A diagnostic that measures something adjacent to what it claims is worse
> than no diagnostic.** It had been quoted a dozen times as evidence the part
> was merely marginal.

Every echo and assert in that model now derives from as-cut names defined once
at file scope. The fix was not the arithmetic; it was removing the *opportunity*
for the audited number and the built geometry to disagree.

### Why the staircase was abandoned

Printed back-face-down, the step from the rear pocket to the lip is a flat 90°
ceiling. §3's staircase would need `reach × (layer_h / step)` of depth:

```
horizontal reach : 2.25 mm   (Y governs, measured from the ledge edge)
depth available  : 1.20 mm   (plate_t 2.4 - lip_t 0.8 - two ledges 0.4)

@ 0.20 mm layers : needs 2.25 mm  -> DOES NOT FIT, short by 1.05 mm
```

It fitted by 0.05 mm at 0.15 mm layers and stopped fitting the moment the
profile moved to 0.20 — the geometry never changed. That is the whole reason the
exchange-rate table above is keyed by layer height.

What the model does instead is **two ledges, one layer each**: a rounded step
matching the lip profile, then two relief lines. Together they cost 0.4 mm of
pocket depth. The remaining reach is made in one jump, which is fine — a bridge
of this span is well within the machine, on a face hidden against the connector.

---

## Claims deliberately NOT imported

A design-tips poster (in Sources) was compared tip by tip against this document. Most of its advice
is already here and more precisely, because these numbers come from this printer's own sliced
output. Three of its claims **conflict** with what this machine does, and are recorded so nobody
imports them later by accident:

| the poster says | this repo measures | why they differ |
|---|---|---|
| wall steps 0.8 / 1.2 / 1.6 mm | **0.90 / 1.35 / 1.80** | it assumes a 0.4 mm extrusion width; §1 uses the width the slicer actually emits, **0.45** |
| bridges of "2 cm+" | **~10 mm** | asserted in `usbc-panel-plate.scad` against the ceiling this machine was measured at |
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
