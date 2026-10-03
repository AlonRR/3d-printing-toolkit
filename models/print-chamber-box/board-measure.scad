// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
What was measured on the two boards on 3 Oct 2026, replacing three values read off photos: A, the strip of bare pads
along the SuperMini's 5V edge, which the cover's front clasp reaches over (sm_edge); B, where its 5V pin
is (pin_mid, which is two pins further along); C, the bare ring round the GY-SGP41's mounting hole on its
underside, where the standoff bears (gy_hole_bare_d). The GY-SGP41 is drawn from both sides, so the hole
can be matched to the right face.

Drawn as the boards lie on the table, seen from above: x to the right, y up the picture, z towards you.
Outlines and pins are the params file's; the parts on the boards are only roughly where the photos put
them.

    openscad -o docs/board-measure.png --imgsize=1800,1300 --projection=o \
      --camera=35,22.3,0,0,0,0,152 --colorscheme=Tomorrow board-measure.scad
*/
include <print-chamber-box.params.scad>
use <../lib/axes.scad>
draw_model = false;   // only the variables

cam = [0, 0, 0];      // seen from straight above, so the text needs no turning
pin_pitch = 2.54;
p1 = pin_mid - pin_pitch;            // the 5V pin, from the PCB's USB-C end
C_A = [0.80, 0.15, 0.10];
C_B = [0.10, 0.35, 0.80];
C_C = [0.85, 0.45, 0.05];
top = 6;                              // above every board, so the dimensions are never hidden

module flat(t, p, size = 1.4, col = "black", h = "left") translate(p) color(col)
    linear_extrude(0.1) text(t, size = size, halign = h, valign = "center", font = "Liberation Sans");

// a dimension line from a to b in the picture's plane, with arrowheads at both ends
module dim(a, b, col) {
    v = b - a; l = norm(v); ang = atan2(v[1], v[0]);
    color(col) translate([a[0], a[1], top]) rotate([0, 0, ang]) {
        rotate([0, 90, 0]) cylinder(d = 0.2, h = l, $fn = 8);
        rotate([0, 90, 0]) cylinder(d1 = 0, d2 = 0.9, h = 1.2, $fn = 16);
        translate([l, 0, 0]) rotate([0, -90, 0]) cylinder(d1 = 0, d2 = 0.9, h = 1.2, $fn = 16);
    }
}
// an extension line, from a feature out to its dimension line
module ext(a, b, col) {
    v = b - a;
    color(col) translate([a[0], a[1], top]) rotate([0, 0, atan2(v[1], v[0])]) rotate([0, 90, 0])
        cylinder(d = 0.12, h = norm(v), $fn = 6);
}
module ring(c, r, w, col) color(col) translate([c[0], c[1], top - 0.5])
    difference() { cylinder(r = r + w / 2, h = 0.1, $fn = 72); translate([0, 0, -1]) cylinder(r = r - w / 2, h = 2, $fn = 72); }

// ------------------------------------------------------------------ the SuperMini, parts side up
module supermini() {
    // the PCB, its USB-C shell overhanging the left end, and its antenna loop past the right one
    color([0.13, 0.13, 0.14]) cube([sm_l, sm_w, sm_pcb_t]);
    color([0.72, 0.72, 0.74]) translate([-usb_overhang, sm_w / 2 - usb_shell_w / 2, sm_pcb_t])
        cube([7.35, usb_shell_w, usb_shell_h]);
    color([0.75, 0.75, 0.78]) translate([sm_l + ant_over / 2, sm_w / 2, sm_pcb_t])
        difference() { cylinder(r = ant_over / 2, h = 0.5, $fn = 48); translate([0, 0, -1]) cylinder(r = ant_over / 2 - 0.45, h = 3, $fn = 48); }
    // its castellated pins: a gold pad at each, the half-hole in the edge
    for (i = [0 : 7], e = [0, 1]) let(x = p1 + i * pin_pitch, y = e * sm_w) {
        color([0.85, 0.68, 0.25]) intersection() {
            translate([x - 0.75, e == 0 ? 0 : sm_w - 1.9, sm_pcb_t]) cube([1.5, 1.9, 0.05]);
            cube([sm_l, sm_w, sm_pcb_t + 1]);
        }
        color("white") translate([x, y, sm_pcb_t]) cylinder(d = 0.9, h = 0.1, $fn = 24);
    }
    // its parts, roughly: the chip, the two buttons, the crystal and some small ones
    color([0.05, 0.05, 0.05]) translate([14, sm_w / 2, sm_pcb_t]) rotate([0, 0, 45]) translate([-2.4, -2.4, 0]) cube([4.8, 4.8, 0.9]);
    color([0.80, 0.78, 0.70]) for (y = [3.4, 11.4]) translate([6.8, y, sm_pcb_t]) cube([3.2, 3.2, 1.5]);
    color([0.80, 0.78, 0.70]) translate([18.3, 3.3, sm_pcb_t]) cube([2.8, 2.3, 0.8]);
    color([0.55, 0.55, 0.55]) for (p = [[11.2, 12.6], [16.6, sm_w - sm_edge - 0.6], [18.6, sm_w - sm_edge - 0.6], [19.6, 8.0], [11.4, 4.2], [15.2, 3.4]])
        translate([p[0], p[1], sm_pcb_t]) cube([1.0, 0.6, 0.5]);
    // the pins' names, as the board's labels read
    for (i = [0 : 7]) {
        flat(["5V", "G", "3V3", "4", "3", "2", "1", "0"][i], [p1 + i * pin_pitch, sm_w + 1.4, top], 1.05, "black", "center");
        flat(["5", "6", "7", "8", "9", "10", "20", "21"][i], [p1 + i * pin_pitch, -1.4, top], 1.05, "black", "center");
    }
}
supermini();

// A: from the 5V edge in to the nearest part, past the 4th pin
xa = p1 + 5.5 * pin_pitch;
dim([xa, sm_w], [xa, sm_w - sm_edge], C_A);
flat("A", [xa + 0.8, sm_w - 1.6, top], 1.8, C_A);
// B: from the PCB's USB-C end to the middle of the 5V pin, run above the pin names
yb = sm_w + 4.2;
dim([0, yb], [p1, yb], C_B);
ext([0, sm_w], [0, yb + 0.8], C_B);  ext([p1, sm_w + 2.2], [p1, yb + 0.8], C_B);
flat("B", [p1 / 2, yb + 1.9, top], 2.0, C_B, "center");

// ------------------------------------------------------------------ the GY-SGP41, both sides
gx0 = 34;                            // its underside, beside the SuperMini
gx1 = gx0 + gy_w + 9;                // its sensor side, beside that
hole_s = [gy_w - gy_hole_side, gy_hole_far];   // the hole, seen from the sensor side: bottom right
hole_u = [gy_hole_side, gy_hole_far];          // ... and from the underside, the mirror image
pin_xs = [gy_w / 2 - 3 * 1.27, gy_w / 2 - 1.27, gy_w / 2 + 1.27, gy_w / 2 + 3 * 1.27];

module gy_board(holexy, names) {
    color([0.18, 0.55, 0.25]) difference() {
        cube([gy_w, gy_l, 0.8]);
        translate([holexy[0], holexy[1], -1]) cylinder(d = gy_hole_d, h = 3, $fn = 48);
        for (x = pin_xs) translate([x, gy_l - 1.3, -1]) cylinder(d = 1.0, h = 3, $fn = 24);
    }
    color([0.80, 0.80, 0.82]) translate([holexy[0], holexy[1], 0.8])
        difference() { cylinder(d = gy_hole_d + 1.4, h = 0.05, $fn = 48); translate([0, 0, -1]) cylinder(d = gy_hole_d, h = 3, $fn = 48); }
    color([0.80, 0.80, 0.82]) for (x = pin_xs) translate([x, gy_l - 1.3, 0.8])
        difference() { cylinder(d = 1.8, h = 0.05, $fn = 24); translate([0, 0, -1]) cylinder(d = 1.0, h = 3, $fn = 24); }
    for (i = [0 : 3]) flat(names[i], [pin_xs[i], gy_l + 1.2, top], 0.72, "black", "center");
}

// the underside: the parts round the hole only roughly where photo 2 put them
translate([gx0, 0, 0]) {
    gy_board(hole_u, ["VIN", "GND", "SCL", "SDA"]);
    color([0.20, 0.20, 0.20]) {
        translate([hole_u[0] + gy_hole_bare_d / 2, gy_bare, 0.8]) cube([2.6, 1.6, 0.7]);
        translate([0.9, hole_u[1] + gy_hole_bare_d / 2 + 0.3, 0.8]) cube([3.0, 1.8, 0.7]);
        translate([5.4, 6.6, 0.8]) cube([3.6, 2.8, 1.1]);
        translate([1.2, 7.6, 0.8]) cube([1.6, 0.9, 0.5]);
    }
    ring(hole_u, gy_hole_bare_d / 2, 0.14, C_C);
}
// C: from the hole's edge to the nearest part
dim([gx0 + hole_u[0] + gy_hole_d / 2, hole_u[1]], [gx0 + hole_u[0] + gy_hole_bare_d / 2, hole_u[1]], C_C);
flat("C", [gx0 + 6.6, 1.1, top], 1.8, C_C, "center");

// the sensor side, as photo 2 shows it: the sensor bottom left, the hole bottom right
translate([gx1, 0, 0]) {
    gy_board(hole_s, ["SDA", "SCL", "GND", "VIN"]);
    color([0.45, 0.42, 0.38]) translate([1.8, 1.7, 0.8]) cube([2.44, 2.44, 0.7]);
    color("white") translate([3.4, 2.6, 1.5]) cylinder(d = 0.8, h = 0.1, $fn = 24);
}

// ------------------------------------------------------------------ the words
flat("What was measured on the boards, with calipers", [-2, 50, 0], 2.2);
lines = [
    ["A   SuperMini, its 5V edge: from the board's edge in to the nearest part,", C_A],
    ["     anywhere past the 4th pin - the cover's front clasp reaches over this strip.", C_A],
    [str("     Measured 3 Oct 2026: ", sm_edge, " mm. The photo had read 1.0."), C_A],
    ["B   SuperMini: from the PCB's USB-C end - the board itself, beside the metal shell -", C_B],
    ["     to the middle of the 5V pin's half-hole. The clips and the clasp are placed by it.", C_B],
    [str("     Measured 3 Oct 2026: ", pin_mid - pin_pitch, " mm. The photo had read 2.6."), C_B],
    ["C   GY-SGP41, its underside - the face WITHOUT the sensor: from the mounting hole's", C_C],
    ["     edge to the nearest part, whichever way that is. The standoff bears inside the", C_C],
    [str("     orange ring. Measured 3 Oct 2026: ", (gy_hole_bare_d - gy_hole_d) / 2, " mm, as the photo had read."), C_C]];
for (i = [0 : len(lines) - 1])
    flat(lines[i][0], [-2, 46.2 - i * 1.75 - floor(i / 3) * 0.9, 0], 1.15, lines[i][1]);

flat("ESP32-C3 SuperMini, parts side up", [-2, -4.6, 0], 1.3);
flat("USB-C on the left", [-2, -6.6, 0], 1.1);
flat("GY-SGP41 underside", [gx0, -4.6, 0], 1.3);
flat("GY-SGP41 sensor side", [gx1, -4.6, 0], 1.3);
flat("pins up, the hole is bottom right", [gx1, -6.6, 0], 1.1);

// the axes: the picture's own, as the boards lie on the table
axes([gx1 + gy_w + 3.5, 1, 0], 6, cam, [[0, 0], [0, 0], [-1.0, -0.9]]);
