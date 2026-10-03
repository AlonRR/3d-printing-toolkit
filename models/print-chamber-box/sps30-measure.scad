// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
What to measure on the SPS30 to set the box's width allowance for it: two caliper readings across it in
x. A goes across the small plastic nubs on its sides - its widest point, and the one the channel has to
clear. B goes across the body beside them. Their difference is the nubs; together they replace the
datasheet's 41.2 mm, which frame A of the clearance test found about 0.7 mm generous.

Drawn as the sensor stands in frame A of the clearance test, in that part's axes: x across its width, y
through its thickness, z along the way it slides through. Sizes are the params file's; where the nubs
sit is read off the datasheet's Figure 7, so it is approximate, and they are drawn three times as proud
as they are so that they show.

    openscad -o docs/sps30-measure.png --imgsize=1800,1300 --projection=o --viewall --autocenter \
      --camera=0,0,0,86,0,0,300 --colorscheme=Tomorrow sps30-measure.scad
*/
include <print-chamber-box.params.scad>
use <../lib/axes.scad>
draw_model = false;   // only the variables

cam = [86, 0, 0];     // the --camera angles above: the text faces the camera
show = 3;             // how much prouder than they are the nubs are drawn
nub = 1.2;            // a nub's side, read off Figure 7
nub_z = [5.4, 15.7, 25.7, 36.0];   // their centres along the sensor, from Figure 7
nub_y = 2.1;          // their centres in from the big face nearest the camera

proud = show * sps_nub;

module flat(t, p, size = 2.6, col = "black") translate(p) rotate(cam) color(col)
    linear_extrude(0.2) text(t, size = size, valign = "center", font = "Liberation Sans");

// a dimension line from a to b, along x, with arrowheads at both ends
module dim_x(x0, x1, y, z, col) color(col) {
    translate([x0, y, z]) rotate([0, 90, 0]) cylinder(d = 0.35, h = x1 - x0, $fn = 8);
    translate([x0, y, z]) rotate([0, 90, 0]) cylinder(d1 = 0, d2 = 1.6, h = 2.4, $fn = 16);
    translate([x1, y, z]) rotate([0, -90, 0]) cylinder(d1 = 0, d2 = 1.6, h = 2.4, $fn = 16);
}
// an extension line, from the feature out to its dimension line
module ext(x, y0, y1, z, col) color(col) translate([x, y1, z]) rotate([-90, 0, 0]) cylinder(d = 0.25, h = y0 - y1, $fn = 6);

// the sensor: the metal body, and the nubs on its two x sides
color([0.72, 0.72, 0.74]) cube([sps_w, sps_t, sps_h]);
color([0.12, 0.12, 0.12]) for (z = nub_z, side = [0, 1])
    translate([side == 0 ? -proud : sps_w, nub_y - nub / 2, z - nub / 2]) cube([proud, nub, nub]);

// A, across the nubs, level with the third row; B, across the body, between the second and third
za = nub_z[2];
zb = (nub_z[1] + nub_z[2]) / 2;
dy = -9;   // how far in front of the sensor the dimension lines run
C_A = [0.80, 0.15, 0.10];
C_B = [0.10, 0.35, 0.80];
dim_x(-proud, sps_w + proud, dy, za, C_A);
ext(-proud, nub_y, dy, za, C_A);  ext(sps_w + proud, nub_y, dy, za, C_A);
dim_x(0, sps_w, dy, zb, C_B);
ext(0, 0, dy, zb, C_B);  ext(sps_w, 0, dy, zb, C_B);
flat("A", [sps_w / 2 - 1, dy, za + 2.2], 3.2, C_A);
flat("B", [sps_w / 2 - 1, dy, zb + 2.2], 3.2, C_B);

// what each one is
flat("SPS30 - the two widths to measure, both in x", [-8, dy, sps_h + 22], 3.0);
flat("A  across the small plastic nubs on its sides - its widest point", [-8, dy, sps_h + 16], 2.6, C_A);
flat("B  across the body, beside the nubs", [-8, dy, sps_h + 11], 2.6, C_B);
flat("datasheet: 40.6 body, 41.2 with the nubs; the nubs are drawn 3x as proud as they are", [-8, dy, -11], 2.2);
flat("measure it as it will go in the box - shipping foil on or off", [-8, dy, -15.5], 2.2);

// which way round: the two plain sides, not the connector end and the air end
flat("the 5-pin connector is on this end", [2, dy, sps_h + 3], 2.4);
flat("the air openings are on this end", [2, dy, -4], 2.4);

// the axes, as in the clearance test's picture. +y points away, so its label goes left
axes([sps_w + 12, 0, 8], 12, cam, [[0, 0], [-1.6, 0], [0, 0]]);
