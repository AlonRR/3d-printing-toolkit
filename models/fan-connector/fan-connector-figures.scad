// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0

// The README's pictures, rendered (not previewed) by models/fan-connector/figures.sh:
//   pair  - the 3-pin pair pulled apart: the male, its wire pins, and the female over it
//   open  - the female's open end: the cavities, the hooks' notches, the lip between the ribs
//   set   - every printed part, from the STLs scad-check.sh leaves beside the sources
include <fan-connector.scad>
use <../lib/axes.scad>
part = "none";
view = "pair";      // [pair, open, set]
cam = [55, 0, 25];  // the picture's --camera angles, so the arrows' labels face it
lift = 9;

if (view == "pair") {
    color("dimgray") male();
    color("goldenrod") male_pins();
    color("ivory") translate([0, 0, male_base[0] + male_pin + lift]) female();
    axes([m_x0 - 6, m_y0, 0], l = 4, cam = cam);
}
else if (view == "open") {
    color("ivory") female();
    axes([-plug_a / 2 - 5, -y_ribs, 0], l = 3, cam = cam);
}
else if (view == "set") {
    names = ["male-2", "male-3", "male-4", "female-2", "female-3", "female-4", "coupon"];
    for (i = [0 : len(names) - 1]) translate([i < 3 ? i * 16 : i < 6 ? (i - 3) * 16 : 52, i < 3 ? 0 : i < 6 ? 22 : 11, 0]) {
        color(i < 3 ? "dimgray" : i < 6 ? "ivory" : "lightsteelblue") import(str("fan-connector-", names[i], ".stl"));
        translate([0, -9, 0]) color("black") linear_extrude(0.4) text(names[i], size = 2.2, halign = "center");
    }
    axes([-12, -12, 0], l = 5, cam = cam);
}
