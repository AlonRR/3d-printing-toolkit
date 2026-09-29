/*
Everything you SET for the M3 spacer. Render m3-spacer.scad, not this file.

Lesson 6 - the last one. A spacer is a trivial shape on purpose: the point is the
structure, which is the one every model in this repository uses. Settings live
here, with the reason for each value next to it. The geometry, and the rules that
check these settings, live in the model file.
*/

/* [Size] */
length = 10.0;    /* Height of the spacer. Must be a whole number of layers - the model asserts it. */
hole_d = 3.2;     /* NOMINAL clearance for an M3 screw, before compensation. 3.2 is a close fit; measure what your screws need. */
wall   = 2.25;    /* Material around the hole, in mm. A screw clamps this part, so docs/fdm-design-rules.md §1 asks for 2.25 - five beads (extrusion widths) across the wall. Try 1.8 to see a WARNING, and 1.1 to see the build refuse. */

/* [Print reality - cross-checked by scripts/scad-check.sh against the profile used] */
fdm_layer_h     = 0.2;     /* Must match the print profile. length has to be a whole multiple of this. */
fdm_extrusion_w = 0.45;    /* 0.4 nozzle. Walls are designed in multiples of this - fdm-design-rules §1. */
fdm_hole_comp   = 0.15;    /* Added to every hole's RADIUS, because holes print undersize - fdm-design-rules §2. That figure is for a 0.4 nozzle; re-measure for any other. scad-check.sh does NOT cross-check this one: no slicer setting says what it should be. */
