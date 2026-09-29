// A small library for lesson 4. Open 04-modules-and-functions.scad, not this.
//
// It holds four kinds of thing, so lesson 4 can show which of them `use`
// brings across: a module, a function, a variable, and some top-level geometry.

library_version = 1;

module ring(d = 12, t = 2, h = 3) {
    difference() {
        cylinder(h = h, d = d, $fn = 48);
        translate([0, 0, -0.01])
            cylinder(h = h + 0.02, d = d - 2 * t, $fn = 48);
    }
}

function clearance_d(nominal, comp = 0.15) = nominal + 2 * comp;

// Top-level geometry: drawn when you open THIS file, and when a file INCLUDES
// it. A file that USES it never sees this sphere.
translate([0, 0, 20])
    sphere(d = 30, $fn = 48);
