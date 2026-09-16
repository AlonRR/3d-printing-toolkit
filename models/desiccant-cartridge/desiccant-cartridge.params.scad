/*
desiccant-cartridge.params.scad — THE HEADER

Every value you SET lives here and nowhere else. No geometry, no modules, no derived values: nothing here is computed from anything else, so any line can be changed without reading the rest.

The geometry, the derived values, the echoes and the guards are in desiccant-cartridge.scad, which includes this. Render THAT file, not this one — on its own it produces nothing.

WHAT THIS IS. The swappable 500 g unit of the desiccant module (docs/desiccant-module.md). A shallow tray with a slotted grille on both large faces: box air is pulled through the bed, so the bed is wide and thin rather than long and deep — pressure drop rises with depth and falls with cross-section, and a 60 mm fan cannot pull through a column.

THE CARTRIDGE, NOT THE MODULE, IS THE STANDARD SIZE. v1 regenerates by swapping: pull it, bake it, weigh it dry. That is why this part has a fixed envelope and the module body does not.

Tags to keep honest as you edit:
    MEASURED      taken off the real part or material with calipers or scales
    <<CONFIRM>>   assumed, NOT measured, and still feeding the design

Comment style: prose is one long line per paragraph inside a block comment, so it reflows to the editor width. The bracketed section markers are OpenSCAD Customizer syntax and must stay on their own line. OpenSCAD does not nest block comments — a close token inside prose ends the comment there.
*/

/* [Which part to render] */
/* One solid per render: scad-check.sh asserts the STL is a single part, and it is the tray that carries every guard. Set "lid" and render again for the other half; "both" is for looking at, not for exporting. */
draw_part = "tray";     /* "tray" | "lid" | "both" */

/* [Cartridge envelope] */
/* 120 x 120 x 45 holds ~500 g of bentonite granules at their bulk density, which docs/moisture-isotherms.md sizes as enough for one four-spool box with margin. Change these and the echo block tells you the new capacity in grams — design to the MASS, not to the box. */
/* 130 x 130 x 45 measures 499 g in the capacity echo. The first attempt at this was 120 x 120 x 45, from 500 g / 0.8 g/cm3 = 625 cm3 done in the doc by hand — and it holds 422 g, because 625 cm3 of CLAY needs more than 625 cm3 of BOX once the walls, the four bosses and a 90% fill are taken out. The model caught it; the arithmetic did not. */
cart_w = 130;       /* Outer width.  Grown from 120 to reach the design mass. */
cart_d = 130;       /* Outer depth.  Ditto. */
cart_h = 45;        /* Outer height, tray floor to the top of the wall. HELD at 45 deliberately: 120 x 120 x 53 reaches the same mass by deepening the bed 18%, and pressure drop rises with depth. Width is the free direction; depth is not. */
corner_r = 3;       /* Outline corner rounding. */
wall = 1.8;         /* Side wall. 4 beads at 0.45. Handled hot and pulled out by hand, so not a 2-bead wall. */

/* [Grille — the two air faces] */
/* Slots, not a square mesh: a slot is a straight run the printer lays in one pass, and a grid of small squares is a corner-count problem with no benefit here. Printed flat, the openings are holes in the bed layer — nothing bridges, nothing overhangs. */
slot_w = 1.5;       /* Opening width. Must be under the smallest granule — see granule_min. */
bar_w = 1.65;       /* Material between slots, NOMINAL. What matters is the bar AS CUT, and it is narrower than this: every slot is grown by fdm_hole_comp per side, so the bar loses 2 * 0.15 while the pitch stays put. 1.65 nominal lands the as-cut bar on exactly 3 beads (1.35), which is what the bed's weight sits on. Set it to 1.35 and the real bar is 1.05 - under the floor - which the guards report rather than assume. */
grille_t = 1.2;     /* Thickness of the grille face itself. Whole layers at 0.2. */
grille_margin = 4;  /* Solid border between the last slot and the inside of the wall. */

/* [Lid and fasteners] */
lid_t = 1.2;        /* Lid plate thickness; the lid carries the same slot pattern. */
boss_d = 7.0;       /* Corner boss the lid screws into. */
screw_d = 3.0;      /* M3. The LID gets clearance; the tray boss gets a pilot — see screw_pilot_d. */
screw_pilot_d = 2.5;    /* Self-tapping pilot in the boss. M3 minor diameter is 2.459, so this is a thread-forming fit in plastic, not a clearance hole. */
screw_inset = 7.0;  /* Screw centre, in from each outer corner along both axes. */

/* [What goes in it] */
/* MEASURED on the bentonite on hand would be better than either of these. Both feed the capacity echo, so they are tagged rather than buried. */
bulk_density = 0.80;    /* <<CONFIRM>> g/cm3, granular bentonite as poured. Cat-litter clay is usually 0.7-0.9. */
fill_factor = 0.90;     /* How full it actually gets. Filling to the brim stops the lid seating and gives the granules nowhere to settle. */
granule_min = 2.0;      /* <<CONFIRM>> mm, the smallest granule that must not fall through a slot. */
target_mass = 500;      /* g. The design point. The echo reports what this geometry really holds, and warns if it is short. */

/* [Slicer facts — MIRROR these from the profile, do not invent them] */
/* Everything with an fdm_ prefix is a fact about how the part gets MADE, not a decision about what it should BE. Each has a counterpart in the print profile and the model is wrong the moment they disagree. scripts/scad-check.sh cross-checks them against the sliced G-code. */
fdm_layer_h = 0.2;      /* = layer_height. */
fdm_extrusion_w = 0.45; /* = extrusion_width. NOT the nozzle diameter: the 0.4 nozzle lays a 0.45 bead, and every wall here is a multiple of the bead. */
fdm_hole_comp = 0.15;   /* Printed holes come out undersize; every cut is grown by this per side. */

/* Wall thresholds, derived rather than written down. Spelled as 0.9 and 1.35 they would be magic numbers whose meaning lives in a comment where nothing can check them, and they would go silently wrong the first time this is sliced with a 0.8 nozzle. */
perim2 = 2 * fdm_extrusion_w;   /* Minimum for a non-load feature. */
perim3 = 3 * fdm_extrusion_w;   /* Minimum for anything that takes force. */

/* [Printing] */
/* Flat, grille face down, no supports and no bridges: every opening is a gap in the bed layer, and the walls rise from it. ASA rather than PETG if this ever sits in a heated dryer — docs/drybox-active.md has the glass-transition table. */
$fn = 48;
