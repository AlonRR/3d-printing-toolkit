// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: MPL-2.0
// tests/fixtures/ell.scad - an L-shaped plate with a hole near one end, exported by make.sh as the binary STL
// add_brim_ears.py's tests read: convex corners for ears, and an enclosed hole no ear may cover.
difference() {
    union() {
        cube([40, 10, 3]);
        cube([10, 30, 3]);
    }
    translate([32, 5, -1]) cylinder(d = 3, h = 5, $fn = 24);
}
