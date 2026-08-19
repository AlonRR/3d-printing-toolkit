/*
usbc-panel-plate.params.scad — THE HEADER

Every value you SET lives here and nowhere else. This file contains no geometry, no modules and no derived values: nothing here is computed from anything else, so any line can be changed without reading the rest.

The geometry, the derived values, the echoes and the guards are in usbc-panel-plate.scad, which includes this. Render THAT file, not this one — on its own it produces nothing.

Tags to keep honest as you edit:
    MEASURED      taken off the real part with calipers
    <<CONFIRM>>   scaled off a photo, NOT measured, and still feeding the fit

Comment style: prose is written as one long line per paragraph inside a block comment, so it reflows to whatever width the editor is at. Hard-wrapped double-slash blocks go ragged the moment the window changes size. The bracketed section markers below are OpenSCAD Customizer syntax and must stay on their own single line.

One trap worth knowing, since this file is mostly block comments: OpenSCAD does not nest them. Writing a close-comment token inside prose ends the comment there, and the rest of the paragraph is parsed as code.
*/

/* [The opening in the case panel — what the plate has to cover] */
gap_w   = 23.4;     /* MEASURED. Width of the opening. */
gap_h   = 15.0;     /* MEASURED. Height of the opening. */
panel_t = 0.6;      /* MEASURED. Sheet thickness of the case panel. */
overlap = 0;        /* How far the plate laps onto the panel, all the way round. The screws pass through open air, so this lap is the ONLY thing retaining the plate. Hard floor: corner_r * (1 - 1/sqrt(2)) — below that the rounded corners fall INSIDE the aperture and leave four open gaps into the case even though every straight edge "covers". */

/* [Plate outline] */
/*
plate_w is whichever of two floors is higher.

COVERAGE is gap_w + 2*overlap. Below this the plate does not span the aperture. This one is physics — there is no way around it.

FASTENERS is the screw envelope plus material outboard of each hole. This one is a CHOICE, and it is usually the binding constraint: at overlap 0.5, coverage wants 24.4 and the fasteners want 25.7.

To make the plate narrower, lower the fastener floor — either by trimming screw_edge_margin, or by switching to edge-open slots, which removes the floor altogether because there is no bridge of material left to split.
*/
screw_envelope = 22.70;     /* MEASURED, outer edge to outer edge. */
screw_style = "hole";       /* "hole" = closed clearance hole, needs material all the way round, and the edge distance is structural. "slot" = U-shaped and open to the plate edge, so the plate slides onto the screws — nothing is left to split, the fastener floor disappears, and the plate can shrink to the coverage floor. */
screw_edge_margin = 0.6;      /* Material outboard of each hole, per side. Ignored when screw_style = "slot". Three perimeters is the rule (docs/fdm-design-rules.md §4); under that you get a warning rather than a block, because it is your call. */

plate_t  = 2.4;     /* Chosen so every internal transition lands ON a layer boundary in the print orientation. At 0.2 mm layers, 2.4 puts the pocket floor and all three staged layers at print z 1.2 / 1.4 / 1.6 / 2.4. At 2.5 they all land mid-layer and the staging resolves on a slicer tie-break rather than on the geometry. */
corner_r = 1.5;     /* Rounding on the outline corners. Feeds the overlap floor above — the bigger this is, the more lap the corners need. */

/* [Centre opening — lip, sized to the PORT] */
/* The USB-C receptacle shell is 8.94 x 3.16 mm, fixed by the USB spec; the plug's metal tongue is 8.34 x 2.56 and passes through easily at this size. */
port_w  = 9.3;      /* Hugs the 8.94 mm receptacle shell with ~0.18 mm a side. */
port_h  = 3.6;      /* Ditto against the 3.16 mm shell height. */
port_r  = 2.0;      /* Clamped to a stadium shape by rrect2d(). */
lip_t   = 0.8;      /* Thickness of the lip itself. NOT how far a plug must reach: with a front protrusion the port sits lip_t + prot_t back, and the echo reports that figure separately as the port recess. */
lead_in = 0.5;      /* 45 degree chamfer on the outermost face, to guide a plug in. Printed back-face-down this is a TOP-face feature, so it is a lead-in only — it does not relieve elephant's foot, which is a first-layer effect. */

/* [Centre opening — rear relief, clears the connector's BOSS] */
boss_w = 13.4;      /* <<CONFIRM>> width NOT yet measured, still photo-scaled, and it feeds the fit. */
boss_h = 8.0;       /* MEASURED. Height of the connector's raised boss. */
boss_r = 2.0;
boss_clear = 0.25;  /* REAL clearance per side, on top of fdm_hole_comp. fdm_hole_comp only cancels print shrink — it lands the feature ON nominal, which for a pocket means printing line-to-line on the boss. Fit needs its own allowance. */
pocket_chamfer = 0.4;   /* Chamfer at the pocket mouth. That mouth is the bed face, so this costs nothing and eases the boss in. 0 = none. */

/* [Raised rectangle protrusion] */
prot_w = 14.4;      /* MEASURED */
prot_h = 6.1;       /* MEASURED */
prot_t = 1.5;       /* <<CONFIRM>> how far it stands proud. NOT measured. */
prot_r = 1.5;       /* Corner rounding. */
prot_face = "front";    /* "front" = the visible side (-Z). "back" = toward the connector (+Z). */

/* [Half-circle notches in the Y edges] */
/* Semicircular cutouts bitten out of the top and bottom edges. These are CLEARANCE features: the fitting goes into a tight space and the notches are what lets it sit there, so they are not optional and not decorative. Removing them is not a fix for anything.

The consequence is accepted rather than avoidable. At overlap 0 the plate is already only as large as the aperture, so any notch necessarily reaches past the aperture edge and opens a gap into the case across its chord — currently 1.95 mm. The guard reports the size of that gap so it stays a known quantity; it is not asking for the notches to be removed. Size them by what has to clear, then read the number.

Where overlap > 0 there is a second, avoidable failure: a notch bigger than the lap severs it. At overlap 2.5 the ceiling is about 1.9. */
notch_r = 1.8;      /* Radius, set by the obstruction being cleared. */
notch_x = 0;        /* X offset from centre. Both notches share it; use notch_mirror to put one each side instead. */
notch_mirror = false;   /* true -> top notch at +notch_x, bottom at -notch_x. */

/* [Screws] */
/*
MEASURED with calipers across the connector's own flange holes:

    inner edge to inner edge = 16.90 mm
    outer edge to outer edge = 22.70 mm

    centre-to-centre = (16.90 + 22.70) / 2 = 19.80 mm
    hole diameter    = (22.70 - 16.90) / 2 =  2.90 mm   -> M2.5, not M2
*/
screw_d    = 2.9;   /* MEASURED. Clearance for M2.5. If the screws instead thread INTO this plate, drop to about 2.1 for a self-tap pilot rather than leaving it at clearance. */
screw_span = 19.8;  /* MEASURED. THE critical dimension. */
cbore_d    = 0;     /* Counterbore diameter, 0 = none. An M2.5 socket head wants 4.5. */
cbore_h    = 1.2;   /* Counterbore depth, measured from the PLATE face. */

/* [Pocket -> lip transition — the two-bridge trick] */
/*
Printed back-face-down, the layer that closes over the pocket is the lip, and the lip HAS THE PORT HOLE IN IT. That is not a plain bridge: the printer would be asked to draw the hole's outline in mid-air, which is the classic "bridge with a hole in it" and comes out as spaghetti.

The two-bridge trick (Hackaday calls it a sacrificial bridge; nophead called it hanging holes) fixes it. Here it runs over THREE layers, and the point is that each layer does exactly ONE thing — no layer ever has to lay a straight run and a curve in the same pass.

Layer 1, THE TWO BRIDGE, is the first layer over the pocket. The opening is a full-height slot, pw x bh. What gets laid is two strips spanning bh wall-to-wall, each anchored at BOTH ends.

Layer 2, THE RECTANGLE, closes the opening to a plain pw x ph rectangle with square corners. The two remaining sides are laid here, bridging pw onto the strips.

Layer 3, THE ROUNDED CORNERS, becomes the real port, port_r rounding and all. The only new material is four small fillets, each sitting on the solid rectangle below, so the curve is never drawn in air.

       layer 1            layer 2            layer 3
    +--+      +--+     +--+------+--+     +--+------+--+
    |  |      |  |     |  |      |  |     |  /      \  |
    |  |  gap |  |     |  | rect |  |     |  | port |  |
    |  |      |  |     |  |      |  |     |  \      /  |
    +--+      +--+     +--+------+--+     +--+------+--+
      two strips        sides close        corners added
*/
bridge_slot = true; /* false = the lip closes in one go, and the hole is drawn in mid-air. */

/* [Slicer facts — MIRROR these from the profile, do not invent them] */
/* Everything with an fdm_ prefix is a fact about how the part gets MADE, not a decision about what it should BE. Each one has a counterpart in the print profile, and the model is wrong the moment they disagree. They are grouped and prefixed so that is obvious at a glance rather than discovered by a bad print. scripts/scad-check.sh cross-checks them against the G-code. */
fdm_layer_h     = 0.2;      /* = layer_height. The staged layers land mid-layer if this is wrong. */
fdm_extrusion_w = 0.45;     /* = extrusion_width. NOT the nozzle diameter — the 0.4 nozzle lays a 0.45 bead, and every wall thickness in this design is a multiple of the bead, not of the nozzle. */
fdm_hole_comp   = 0.15;     /* Printed holes come out undersize (bead width plus the arc effect); every hole is grown by this per side. */

/* Wall thicknesses that mean something, derived rather than written down. Spelled as the literal 1.35 these would be magic numbers whose meaning lives in a comment where nothing can check it, and they would go silently wrong the first time anything is sliced on the 0.8 nozzle. */
perim2 = 2 * fdm_extrusion_w;   /* Absolute minimum for a non-load feature. */
perim3 = 3 * fdm_extrusion_w;   /* Minimum for anything that takes force. */

/* [Printing] */
flip_for_print = true;  /* Rotate 180 about X on export so the BACK face sits on the bed. */
$fn = 64;
