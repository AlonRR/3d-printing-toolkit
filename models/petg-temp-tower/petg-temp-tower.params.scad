/*
Everything you SET for the PETG temperature tower. Render petg-temp-tower.scad, not this file.

The tower exists because the new unbranded PETG (SKU NPETG087-ZX) ships with NO data sheet - the spool label gives a 30 C nozzle band and nothing else. A 30 C band is far too wide to pick a number out of, so the number has to be measured.
*/

/* [The band temperatures — what is actually being tested] */
/*
One band per temperature, printed bottom to top. These span the label's full 230-260 C range, because the whole point is that no narrower claim exists to trust.

The slicer is what changes the temperature; the model only makes each band identifiable and gives it features that fail visibly. Add an M104 at each band boundary via the layer slider - petg-temp-tower.scad echoes the exact Z heights and layer numbers to use.
*/
temps = [230, 240, 250, 260];

/* [Band geometry] */
band_h  = 10.0;     /* Height of each band. MUST be a whole number of layers or the temperature change lands mid-band and the boundary stops being readable — the .scad asserts this against fdm_layer_h. */
body_w  = 30.0;     /* Across the front face. Wide enough for three digits at text_size without crowding the corners. */
body_d  = 18.0;     /* Front to back. Also the bridge span, so this is the number that decides how hard the bridge is. */

/* [Features that fail visibly — one per failure mode] */
/*
Each band carries the same three features, so the ONLY variable between bands is temperature. That is the entire experimental design: vary one thing.
*/
shelf_len   = 7.0;      /* How far the shelf sticks out with nothing under it. A 90 degree overhang, deliberately the hardest case rather than a 45 degree one — too hot and it droops, and droop is easy to see against the band above. */
shelf_t     = 2.0;      /* Thickness of the shelf. Thin enough to sag if it is going to, thick enough to survive handling. */
shelf_z     = 0.55;     /* Where the shelf sits within its band, 0..1. Just above middle, so the droop has clean air below it. */

bridge_d    = 6.0;      /* Diameter of the through-hole. Its ceiling is an unsupported bridge of body_d across — sag here reads as too hot or too little cooling. */
bridge_z    = 0.25;     /* Where the hole sits within its band, 0..1. Low, so the bridge is well clear of the shelf above it. */

fin_w       = 1.2;      /* A thin vertical fin on the back. Narrow features are where stringing and over-extrusion show first. */
fin_len     = 4.0;      /* How far it stands off the back face. */

/* [Labels] */
text_size   = 6.0;      /* Digit height. Under about 5 mm the digits close up at 0.4 mm nozzle and stop being readable, which defeats the point of labelling. */
text_depth  = 0.6;      /* Embossed OUTWARD, not engraved. Raised text prints cleanly on a vertical face; engraved text at this size fills in. */

/* [Stringing — the fourth failure mode] */
/*
TWO towers, not one, and the gap between them is the test. A single tower never travels far, so retraction is barely exercised and stringing does not show. Printing a pair forces a long travel move at every layer of every band, which is exactly when PETG strings - and PETG strings more readily than any other common material.

Added after checking what established temperature towers include: overhang, bridge, thin wall AND retraction. The first three were already here; this is the one that was missing.
*/
twin        = true;     /* Print the pair. Set false for a single tower if bed space is tight. */
base_t      = 1.0;      /* A thin plate joining the two towers. Three purposes, all real: it makes the model ONE part rather than two, which is what scad-check.sh wants and what stops a deliberate pair being indistinguishable from an accidentally fragmented model; it puts a wide first layer on the bed, which is itself a bed-adhesion test at 70 C - an open question for this filament; and it stops a tall thin tower being knocked over by a travel move. Must be a whole number of layers. */
tower_gap   = 40.0;     /* Clear air between the two towers. Long enough that a string spans it visibly rather than being dragged back into the wall. */

/* [Identity — what filament this tower actually tested] */
/*
A finished temperature tower is a physical record, and an unlabelled one is worthless the moment a second spool enters the room: the bands say 230/240/250/260 but nothing says WHAT was printed at those temperatures. Engraved into the base so it survives being handled, and so it cannot be confused with the band labels.

ENGRAVED, not embossed, unlike the band numbers. The base's top face is a horizontal surface, where raised text is fragile and collects strings; recessed text on a flat top prints cleanly and stays readable.
*/
label_line1 = "PETG";              /* The material. */
label_line2 = "NPETG087-ZX";       /* The SKU, which for this filament IS the name - there is no brand. */
label_size  = 4.5;                 /* Small enough for two lines to fit between the towers, large enough to read at 0.4 mm nozzle. */
label_depth = 0.4;                 /* Two layers deep, leaving three layers of base under it. */

/* [Modelling] */
weld = 0.5;         /* How far each feature is buried INTO the body. Features that merely touch a face are not fused - CGAL reports them as separate volumes and the STL is multi-part, which scad-check.sh blocks. Coincident faces are a modelling bug, not a style choice. */

/* [Print reality — cross-checked by scripts/scad-check.sh against the profile used] */
fdm_layer_h     = 0.2;      /* Must match the print profile. band_h has to be a whole multiple of this. */
fdm_extrusion_w = 0.45;     /* 0.4 nozzle. Feeds the thin-feature check on fin_w. */
