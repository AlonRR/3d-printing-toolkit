# Mechanical design review — the questions a collision check never asks

A reference for reviewing a printed mechanical assembly in this repo, and a checklist to run against an
OpenSCAD model. Written 26 Sep 2026, after the desiccant module's spring inserts fell over in the first
coupon. The review that followed is what this page came out of.
It found four ceilings that cannot print, a joint with no seal, and a spring whose preload is smaller
than its tolerance. The checks had called all of them fine.

Printing rules (quantised walls, holes, overhang angles, bridging tricks, materials) are in
[fdm-design-rules](fdm-design-rules.md) and are not repeated here. This page is about the assembly.

**Tags.**
- **[standard]** a code or standard.
- **[handbook]** a textbook, handbook or paper.
- **[vendor]** a maker's own guide or datasheet.
- **[community]** blogs, wikis, trade press.
- **[inferred]** reasoning or arithmetic done here.

`S#` refers to the source list at the end.

`§5.x` refers to a numbered finding in the desiccant module's own facts document. That build moved to
its own repository in September 2026 and is not public, so those sections cannot be opened from here;
the citation is kept only to mark where a claim came from. Every claim below is stated in full, so
nothing depends on following one.

---

## 0. The pattern

Every check in the desiccant model asked one question: **does the part exist here without colliding?**
Each miss was a different question:

| The question that was not asked | The miss |
|---|---|
| Does air actually get through? | two broken air paths (§5.12, §5.14) |
| What does gravity do when it is mounted? | the cartridge bypass, the hanging gates (§5.15, §5.17) |
| Can it be put in at all? | a gate slot closed at both ends (§5.17) |
| Does it stay where it was put? | the spring insert (§5.22) |
| Does its first layer hang off one edge? | four valve ceilings (§5.23) |

A part does not live in one state. It lives through a set of them, and **every check should say which
set it covers**:

| Code | The set |
|---|---|
| **O** | every orientation gravity can take: on the bench, flipped to screw, hung on the wall |
| **A** | every step of assembly *and* disassembly |
| **T** | both tolerance extremes, not nominal |
| **H** | hot, at the service temperature |
| **R** | after creep, relaxation and compression set |
| **M** | the whole range of motion, not a few poses |
| **S** | service: taken apart and refitted, repeatedly |

## 1. Assembly — located before released

- **Boothroyd–Dewhurst's rule: "design so that a part is located before it is released."** A part that
  has to be held until something else arrives is, in their scoring, *holding down required*: the costly
  case. [handbook S1] The spring insert broke exactly this.
- **Justify every separate part.** It must move relative to the others, be a different material, or be
  separate so the others can be assembled. A small elastic motion is not a reason, because a flexure can
  provide it. [handbook S1] Here the insert is separate for a real reason: so it can be annealed and
  reprinted without the 190 g valve (§5.18). The cost of that choice is retention, which must then be
  designed in.
- **Symmetric about the insertion axis, or obviously not.** Poka-yoke features reject the wrong way
  round by shape. [handbook S1; community S21] Check each part rotated 180° about each axis:
  - the wrong pose must collide with its seat;
  - the collision must also be **bigger than the part's own compliance**. An upside-down spring
    insert collides with the body by 1.3 mm, but its fingers bend 1.4 mm, so the body still closes
    (§5.23). [inferred]
- **Assemble from above, around one axis, with lead-ins.** Access must be clear and visible.
  [handbook S1]

## 2. Constraint — every contact needs a force that keeps it closed

- A rigid body has six degrees of freedom. **A contact is a constraint only while a nesting force keeps
  it closed**: gravity, a spring, a cam. That force has to exist in every state of the machine.
  [community S2, after Blanding]
- **Gravity nests in one orientation only.** A pocket that seats a part on the bench may hold nothing
  once the module hangs on the wall, or while the part beside it is out for service. Every loose part
  needs a named retaining force, for each state in O and A. [inferred]
- **Over-constraint turns tolerance into stress or binding.** Pick one datum and give the others
  clearance. [community S2] The gates here do it right: sprung onto the floor, with clearance in the
  dovetail.

## 3. Tolerance — compliance must be large against the stack

- **Worst case, not RSS, for prints.** RSS assumes independent, centred, normal contributors. FDM errors
  are largely systematic:
  - the same printer and spool;
  - holes always undersize;
  - the first layer always spread;
  - one shrink in XY and another in Z.

  So check the worst case, and treat RSS as the optimistic bound. [community S3; inferred]
- **Starting numbers** are about ±0.2 mm on a calibrated desktop machine; calibrate with a printed
  ladder. [community S27] Elephant's-foot compensation is ~0.2 mm, and this repo's profiles set it.
  [vendor S5]
- ⭐ **A spring's or seal's working deflection must be several times the worst-case stack**, because
  force and squeeze are proportional to deflection. Aim for at least 3×. [inferred]
  - *The desiccant spring:* 0.7 mm preload against a ±0.23 mm RSS stack (±0.5 worst case), and it needs
    0.667 mm hot (§5.23).
  - *A 0.2 mm gasket squeeze is one layer.* A ±0.1 mm stack gives 12–38 % squeeze; ±0.2 mm gives 0–50 %.
- **The remedy is a softer element with more travel,** not a stiffer one. A tip-loaded cantilever's root
  strain is ε ≈ 1.5·t·y/L², so a longer, thinner finger takes more deflection at the same strain and
  force. [vendor S8; inferred]
- **Where a thin dimension is set matters.** A finger printed flat is quantised to layers (0.8 or
  1.0 mm), and its force goes as t³. The desiccant insert prints on its back, which puts the 0.9 mm into
  the bed plane: two perimeters, set by the extrusion width instead. [inferred]

## 4. Printed plastic under load

- **Interlayer strength is about a quarter of in-plane.** Printed ASA gives 11 MPa across layers
  against 42 MPa along them. [vendor S6] Load along the roads, never across them, and make springs bend
  in the print's plane. [vendor S4]
- **Moulded ASA shrinks 0.5–0.9 %.** [vendor S7] A fit between a dimension printed in XY and one printed
  in Z inherits the difference. This repo's profile compensates neither (0 %).
- **Sealing faces as top or bottom skins, never as layered side walls.** Rib large flat faces against
  warp. [inferred]

## 5. Fastening into printed parts

- **Plastic under a screw head creeps, and the joint loosens**, faster the hotter it is. [vendor S9] A
  **compression limiter** (a metal sleeve as long as the plastic) or a hard stop carries the clamp load
  instead. [vendor S11] Pan heads with washers, not countersunk heads, which put the hole into hoop
  tension. Keep the edge distance at least max(d, 2t). [vendor S9]
- **Self-tapping into plastic:**
  - pilot ~0.8–0.9 d, boss OD ~2 d, engagement ≥ 2 d (EJOT, Covestro; both for moulded bosses);
  - tighten to ≥1.2× driving torque and ≤0.5× stripping torque;
  - on refitting, find the existing thread. [vendor S9, S10]

  Printed pilots come out undersize, so size them from a coupon. [inferred]
- **Nuts and inserts, M3 pull-out in PETG** (CNC Kitchen):
  - bottom-inserted nut ≈ 1.63 kN;
  - heat-set insert ≈ 1.17 kN;
  - screwed direct ≈ 1.16 kN;
  - **side-slit nut ≈ 0.84 kN.**

  Heat-set inserts take about three times the torque of a printed thread, and are the choice for joints
  opened repeatedly. [community S12]
- **A nut in a side slit is held by nothing once its screw is out** — the §0 bug again. It needs its own
  retention, or an assembly order that never tilts it out. [inferred]
- **Set screws in printed bosses: no source found.**
  - The screw's reaction sits on plastic threads that creep hot.
  - A set screw on a round shaft slips.
  - File a flat where it bears, and back the thread with a metal nut or insert, or use a split clamp.
    [inferred]

## 6. Seals and gaskets

- **Squeeze targets:**
  - Parker face seals run ~18–27 %, and permanent set is lowest at 25–30 %. [vendor S13]
  - Solid silicone runs 15–25 %. [vendor S14]
  - Size the *minimum* squeeze with every tolerance at its limit. [vendor S13]
- **Geometry, not torque.** A hard compression stop fixes the squeeze whatever the screws do. [community
  S15] The desiccant module's base seal does this since 26 Sep: the body's walls land on the plate as the
  stop, and a hollow TPU bead beside them takes the squeeze (facts §5.24). The valve-to-body joint has
  the same since then: a hollow ring in a groove, with the faces still meeting (facts §5.25).
- **Give it volume.** Elastomer is incompressible and bulges into its groove. [vendor S14]
- **TPU takes a set.** Elastollan 95A shows about **30 % at 23 °C over 72 h and 45 % at 70 °C over 24 h**
  (moulded, ISO 815). [vendor S16] A 0.2 mm squeeze in the hot path can lose ~0.09 mm early. So hot
  seals want more squeeze behind a hard stop, and should be replaceable. [inferred]
- **Every interface between two pressures needs a seal, or a stated reason why not.** A leak through a
  flat gap goes as the cube of the gap, so it is decided by how flat the faces print. [inferred]

## 7. Plastic springs under permanent load

- **Snap-fit guidance assumes the spring returns to a stress-free state after assembly.** [vendor S8]
  Allowable strains are single-snap values; use ~60 % for repeated snapping. ASA yields at ~3.3 %.
  [vendor S7, S8]
- **Radius the roots:** stress concentration levels off near R ≈ 0.6 t. [vendor S8]
- **A permanently preloaded printed spring is outside that guidance.**
  - Moulded ASA's creep modulus falls from 2200 to 1650 MPa between 1 h and 1000 h, at 23 °C.
    [vendor S7]
  - **No data at 80–85 °C was found.** Design to strain, and measure the hot loss on a coupon.
    [vendor S8; inferred]

## 8. Heat

- **HDT is not a service rating.** ISO 75 loads a bar at 0.45 or 1.8 MPa, heats it at 2 °C/min, and
  records the temperature at 0.25 mm of deflection: a short-term figure. A common rule of thumb puts
  continuous loaded service **30–50 °C below HDT**. [community S17]
  - The owned ASA's sheet gives HDT 98 °C at 0.45 MPa ([fdm-design-rules](fdm-design-rules.md) §6), and
    Prusament ASA's gives 93 °C. [vendor S6]
  - Either way, 80–85 °C sits inside that margin, so loaded parts there creep first.
- **Expansion.** ASA expands at 80–110 ×10⁻⁶/K against steel's 12–17. [vendor S7, S13] From 23 to
  85 °C the difference is 0.4–0.6 mm per 100 mm. Fix a steel part to plastic at one point, and let every
  other support slide. [inferred]

## 9. Motion

- **Sweep, not pose.** Collisions happen between the poses a preview shows. [inferred]
- **Binding ("sticky drawer").** A cocked slider jams when μ exceeds its engagement length over its
  width. Keep a drive's offset below L / 2μ; at μ = 0.25 that is the 2:1 rule. [vendor S19, S20b;
  community S20] ASA-on-ASA μ is unsourced, so check at 0.3 and 0.5. [inferred]
- **The spring force is also the friction the drive fights.** Size the drive for the *maximum* preload,
  hot, with static friction. A dovetail pressed into its flanks multiplies friction by ~1/sin 45° ≈
  1.4. [inferred]
- **Dust is abrasive.** Let it fall *out* of slides, not into them. [inferred]

## 10. Service and access

- An L-key needs a 60° swing (30° if flipped) at the step where it is used. A ball end enters up to 25°
  off the axis. [vendor S25; inferred]
- Parts serviced often come out first, and need no tools. Nuts stay put without their screw.
  [handbook S1; inferred]
- **Disassembly is a sequence too.** It is not always the assembly run backwards in the same
  orientation. Lifting that valve off in place drops its spring inserts.

## 11. Moisture

Hot, wet exhaust condenses on anything cooler. Condensate drains by gravity, not along the air path.
Slope every exhaust surface **≥ 1 % (10.4 mm/m) to one drain** — the plumbing rule for condensate lines.
[standard S24] Avoid pockets and U-bends, and keep TPU and electronics out of the drip path. [inferred]

## 12. Process

- **DFMEA.** The 2019 AIAG–VDA method has seven steps, replaces the RPN with Action Priority, and
  weights prevention above detection. [community S22] Ask of each part how it can fail to *stay*,
  *seal*, *move* or *come apart*, under each set in §0.
- **Coupons before the big print, on the production profile:**
  - a clearance ladder;
  - a pilot-hole torque coupon;
  - a spring's force before and after 24 h at the service temperature under preload;
  - a gasket's set after the same.

  Measure each first print against the model (first-article inspection). [community S23; inferred]

---

## Checklist — run against an OpenSCAD model

The codes are §0's. *How* names this repo's check where one exists; the rest are manual today.

| # | Check | How |
|---|---|---|
| 1 | **[O,A] Each loose part stays put** — name its retaining force | render it without its mating part and gravity along ±X, ±Y, ±Z; sweep it out of its seat both ways: out must be blocked, in must be clear (`desiccant-spring-fit.py`) |
| 2 | **[A] Every step, not the end state** | render the sequence; at each step, list what holds the parts already placed |
| 3 | **[A] Orientation-proof** | rotate each asymmetric part 180° about each axis: it must collide with its seat, by more than its own compliance |
| 4 | **Constraint** | per part, count constraints and name the nesting force; flag redundant datums |
| 5 | **[T] Worst case both ways** | fit, preload and squeeze at min/min and max/max |
| 6 | **[T] Compliance ≫ stack** | working deflection ÷ worst-case stack ≥ 3, for every spring and seal |
| 7 | **[T] Quantisation** | thin Z features in whole layers, thin walls in whole perimeters (`fdm-design-rules` §1) |
| 8 | **[T] Holes and pilots** | sized from a coupon, not nominal |
| 9 | **Print** | every ceiling bridged between two supports, never hung off one edge (check every ceiling, not just the obvious ones); overhangs by the 50 % rule (`fdm-design-rules` §3) |
| 10 | **[H,R] After relaxation** | recompute spring force and squeeze with the coupon's measured hot loss |
| 11 | **[H] Hot loaded parts** | list every permanently loaded part in the hot path, each with the test that proves it |
| 12 | **[H] Thermal float** | each steel–plastic interface fixed at one point; compute Δα·ΔT·L |
| 13 | **[M] Sweep** | the whole travel of every moving part against everything fixed, and moving parts against each other (`desiccant-drive-sweep.py`) |
| 14 | **[M,T] Binding and drive margin** | L/W > μ at 0.5; drive force above static μ × maximum spring force, hot |
| 15 | **Seals** | every interface between two pressures has a seal, squeezed by a hard stop, 15–30 % at both tolerance extremes |
| 16 | **Fasteners** | pan heads and washers; edge ≥ max(d, 2t); boss OD ≥ 2d; engagement ≥ 2d; a hard stop or limiter where it runs hot |
| 17 | **[S] Nuts and repeated joints** | each nut stays in its slit, screw out, in every orientation it passes through; inserts where a joint is opened often |
| 18 | **[S] Tool access** | the key as a cylinder plus its swing, clear at the step it is used |
| 19 | **[S] Disassembly** | the teardown sequence, in the orientation it will actually be done in |
| 20 | **Condensate** | in the mounted pose, every exhaust surface falls ≥ 1 % to one drain |
| 21 | **Interfaces** | every air path connects end to end (the desiccant model's airflow guards) |
| 22 | **DFMEA** | one line per part — stay, seal, move, come apart — each with a prevention and a check |

---

## Sources

- **S1** [handbook] Boothroyd, Dewhurst & Knight, *Product Design for Manufacture and Assembly*, ch. 3 —
  https://www.routledge.com/Product-Design-for-Manufacture-and-Assembly/Boothroyd-Dewhurst-Knight/p/book/9781420089271
- **S2** [community] MistyWest, exact constraint analysis (after Blanding) —
  https://www.mistywest.com/posts/make-parts-fit-right-the-first-time-with-exact-constraint-analysis/
- **S3** [community] https://en.wikipedia.org/wiki/Tolerance_analysis
- **S4** [vendor] Protolabs Network (Hubs), designing for FDM —
  https://www.hubs.com/knowledge-base/how-design-parts-fdm-3d-printing/
- **S5** [vendor] Prusa knowledge base, elephant foot compensation — https://help.prusa3d.com/article/elephant-foot-compensation_114487
- **S6** [vendor] Prusament ASA technical data sheet (2022) —
  https://prusament.com/wp-content/uploads/2022/10/ASA_Prusament_TDS_2022_16_EN.pdf
- **S7** [vendor] INEOS Styrolution, Luran S 757G data sheet —
  https://upmold.com/wp-content/uploads/data-sheet/ASA-Luran-S-757G.pdf
- **S8** [vendor] Covestro, *Snap-Fit Joints for Plastics* —
  https://solutions.covestro.com/-/media/covestro/solution-center/brands/downloads/imported/1556891135.pdf
- **S9** [vendor] Covestro, *Engineering Polymers: Joining Techniques* —
  https://solutions.covestro.com/-/media/covestro/solution-center/brands/downloads/imported/1557217197.pdf
- **S10** [vendor] EJOT, DELTA PT — https://www.ejot-atf.com/wp-content/uploads/2017/02/ATFDELTAPT2017LowRes.pdf
- **S11** [vendor] SPIROL on compression limiters —
  https://fastenerandfixing.com/technical/how-to-ensure-bolted-joint-integrity-when-using-a-compression-limiter-in-a-plastic-assembly/
- **S12** [community] CNC Kitchen, inserts and nuts in prints —
  https://www.cnckitchen.com/blog/helicoils-threaded-insets-and-embedded-nuts-in-3d-prints-strength-amp-strength-assessment
- **S13** [vendor] Parker, *O-Ring Handbook* PTD5705 —
  https://www.parker.com/content/dam/Parker-com/Literature/Praedifa/Catalogs/Catalog_O-Ring-Handbook_PTD5705-EN.pdf
- **S14** [vendor] Stockwell Elastomerics, solid silicone — https://www.stockwell.com/solid-silicone-sheet/
- **S15** [community] Engineers Edge, gasket compression stops —
  https://www.engineersedge.com/general_engineering/gasket_compression_stop.htm
- **S16** [vendor] BASF, *Elastollan product range* (TPU) — https://download.basf.com/p1/8a8082587fd4b608017fd6411cdd6d63/en/Elastollan%3Csup%3E%C2%AE%3Csup%3E_%E2%80%93_Thermoplastic_Polyurethane_Elastomers_(TPU)_-_Product_Range
- **S17** [community] ISO 75 heat deflection explained — https://kunststoff-profi.de/en/standards/iso-75-heat-deflection/
- **S19** [vendor] Kalsi Seals Handbook D21, the sticky drawer effect — https://www.kalsi.com/handbook/D21_Sticky_drawer_effect.pdf
- **S20** [community] Linear Motion Tips, the 2:1 ratio — https://www.linearmotiontips.com/what-you-need-to-know-about-the-2-1-ratio/
- **S20b** [vendor] PBC Linear, the 2:1 ratio — https://www.pbclinear.com/blog/2019/september/white-paper-demystifying-the-2-1-ratio
- **S21** [community] https://en.wikipedia.org/wiki/Poka-yoke
- **S22** [community] Quality-One, AIAG–VDA FMEA — https://quality-one.com/aiag-vda-fmea/
- **S23** [community] https://en.wikipedia.org/wiki/First_article_inspection
- **S24** [standard] Uniform Plumbing Code 814.1, condensate slope, as adopted —
  https://up.codes/s/condensate-waste-and-control
- **S25** [vendor] Bondhus, ball-end keys — https://bondhus.com/ball-end
- **S27** [community] Sovol, FDM tolerances (starting points for a calibration ladder, not data) —
  https://www.sovol3d.com/blogs/news/fdm-3d-printing-tolerances-clearances-how-to-design-parts-that-fit

**Not found:** ASA creep or stress relaxation at 80–85 °C; set screws in plastic bosses; ASA-on-ASA
friction; printed-spring fatigue; a primary source for TPU HDT.
