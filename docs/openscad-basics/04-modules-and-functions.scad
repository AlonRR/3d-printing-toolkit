// Lesson 4 - modules and functions
//
// A MODULE makes geometry. A FUNCTION returns a value. They cannot swap roles:
// a function cannot draw anything, and a module cannot return a number.

use <04-library.scad>

// ---------------------------------------------------------------------------
// 1. A module with parameters and defaults                           (row y = 0)
// ---------------------------------------------------------------------------
// A plate with rounded corners: hull() around four cylinders (lesson 2).
// `for (x = ..., y = ...)` loops over every combination of x and y.
module plate(w = 30, d = 20, t = 3, r = 3) {
    hull()
        for (x = [r, w - r], y = [r, d - r])
            translate([x, y, 0])
                cylinder(h = t, r = r, $fn = 32);
}

plate();                                 // every default

translate([40, 0, 0])
    plate(w = 20, t = 2);                // named arguments, in any order

translate([70, 0, 0])
    plate(25, 25);                       // positional: w first, then d

// ---------------------------------------------------------------------------
// 2. A module that wraps other geometry: children()                  (row y = 35)
// ---------------------------------------------------------------------------
// children() stands for whatever the caller put after the module call. That is
// how you write your own transforms. This one draws its children, plus a mirror
// image of them - handy for any symmetric part.
module mirror_copy(axis = [1, 0, 0]) {
    children();
    mirror(axis)
        children();
}

translate([20, 35, 0])
    mirror_copy()
        translate([4, 0, 0])
            cube([10, 6, 3]);

// ---------------------------------------------------------------------------
// 3. Functions: one expression that returns a value
// ---------------------------------------------------------------------------
// Walls on this printer are designed in whole extrusion widths
// (docs/fdm-design-rules.md §1). Two small functions make that arithmetic
// readable:
bead = 0.45;
function wall_for(perimeters) = perimeters * bead;
function perimeters_in(wall) = wall / bead;

echo(wall_for_4_perimeters = wall_for(4));           // 1.8
echo(perimeters_in_2_25 = perimeters_in(2.25));      // 5

// A function can call itself - that is how you loop in an expression (lesson 3).
function count_down(n) = n <= 0 ? [] : concat([n], count_down(n - 1));
echo(count_down = count_down(4));                    // [4, 3, 2, 1]

// ---------------------------------------------------------------------------
// 4. Code from another file: `use` versus `include`                  (row y = 55)
// ---------------------------------------------------------------------------
// Measured on both builds:
//                 modules and functions   variables   top-level geometry
//   include <f>          yes                 yes       YES - drawn here too
//   use <f>              yes                 no        no
//
// `use` is for libraries: you want the tools, not the demo. `include` is for
// settings files, whose whole point is the variables - which is why lesson 6's
// model includes its .params.scad file.
//
// This file USES 04-library.scad (top of the file). So ring() and clearance_d()
// work here, but library_version is undefined and the library's sphere is absent.
translate([10, 60, 0])
    ring(d = 16);

echo(m3_clearance = clearance_d(3.2));               // 3.5
echo(library_version_is_undef = is_undef(library_version));   // true

// ---------------------------------------------------------------------------
// TRY
// ---------------------------------------------------------------------------
//  1. Give plate() a `holes = true` parameter that cuts a 3 mm hole in from each
//     corner. Remember to make the holes overshoot the plate.
//  2. Change `use` to `include` at the top of this file and press F5. What
//     appears, and what does the console now say about library_version?
//  3. Write a module grid(nx, ny, pitch) that places copies of its children on a
//     grid. Use it to lay out 3 x 2 of the rings.
