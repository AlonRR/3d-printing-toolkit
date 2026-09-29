// Lesson 1 - shapes, transforms, and how curves are made
//
// Open this file in OpenSCAD and press F5. The examples sit in rows so you can
// see all of them at once: primitives along the front, curves behind them, and
// transforms at the back.
//
// THE COORDINATE SYSTEM
//   X to the right, Y away from you, Z up. Z = 0 is the print bed.
//   Nothing declares units: an STL is only numbers, and the slicer reads them as
//   millimetres. So every number in these lessons is mm.
//
// F5 AND F6
//   F5  PREVIEW  fast and approximate. Use it while you edit.
//   F6  RENDER   computes the real solid. Needed before File > Export > STL.

// ---------------------------------------------------------------------------
// 1. The three primitives                                            (row y = 0)
// ---------------------------------------------------------------------------

// A cube sits with one CORNER on the origin...
cube([10, 10, 5]);

// ...unless you centre it. center = true centres ALL THREE axes, so half of
// this one is below the bed. See TRY 3.
translate([20, 5, 0])
    cube([10, 10, 5], center = true);

// A cylinder stands on the XY plane, centred on its own axis.
// d = diameter, r = radius; use whichever the drawing gives you.
translate([40, 5, 0])
    cylinder(h = 8, d = 10);

// Two diameters make a cone, or a truncated one.
translate([60, 5, 0])
    cylinder(h = 8, d1 = 10, d2 = 4);

// A sphere is centred on the origin, so lift it by its radius to sit on the bed.
translate([80, 5, 5])
    sphere(d = 10);

// ---------------------------------------------------------------------------
// 2. There are no curves - only polygons                             (row y = 30)
// ---------------------------------------------------------------------------
// A circle is a polygon, and three special variables decide how many sides:
//   $fn  exact number of sides (overrides the other two)
//   $fa  largest angle one side may span, in degrees   (default 12)
//   $fs  shortest length one side may have, in mm      (default 2)
//
// The defaults are coarse on small circles. Measured on both the 2021.01 release
// and a 2026 nightly: a 3 mm cylinder at the defaults has FIVE sides - a
// pentagon, with 24 % less area than the circle you asked for. That is an M3
// clearance hole.

translate([0, 30, 0])
    cylinder(h = 3, d = 3);                  // defaults: a pentagon

translate([10, 30, 0])
    cylinder(h = 3, d = 3, $fn = 32);        // 32 sides, set on this call only

translate([25, 30, 0])
    cylinder(h = 3, d = 10);                 // defaults: 16 sides at this size

translate([40, 30, 0])
    cylinder(h = 3, d = 10, $fa = 2, $fs = 0.4);

// A reasonable default for printed parts is $fa = 2 and $fs = 0.4: a side
// shorter than about one bead width cannot print as a distinct flat anyway.
// That is reasoning, not a measurement. Set it at the top of a model, not
// globally in your head.

// ---------------------------------------------------------------------------
// 3. Transforms, and why ORDER matters                               (row y = 55)
// ---------------------------------------------------------------------------
// A transform applies to the one object, or { block }, that follows it.
// Read a chain from the object OUTWARD: the transform nearest the object
// happens first.

// Rotate, then move: the bar turns in place, then slides to x = 10.
translate([10, 55, 0])
    rotate([0, 0, 45])
        cube([10, 2, 2]);

// Move, then rotate: the bar slides first, then swings about the ORIGIN,
// so it lands somewhere else entirely. Predict where before you press F5.
rotate([0, 0, 45])
    translate([60, 0, 0])
        cube([10, 2, 2]);

// scale() stretches along each axis.
translate([35, 55, 0])
    scale([2, 1, 0.5])
        cube(5);

// mirror() reflects across the plane whose normal you give: [1, 0, 0] flips X.
translate([80, 55, 0])
    mirror([1, 0, 0])
        cube([10, 4, 2]);

// color() is for the PREVIEW only. It does not survive into the STL.
translate([90, 55, 0])
    color("orange")
        cube([6, 6, 6]);

// ---------------------------------------------------------------------------
// TRY
// ---------------------------------------------------------------------------
//  1. Give the sphere $fn = 6. What shape is it now, and why?
//  2. Swap translate and rotate on the first bar. Say where it will land, then check.
//  3. Make a 20 x 10 x 3 plate that is centred in X and Y but sits ON the bed,
//     with Z running from 0 to 3. center = true alone gets Z wrong.
//  4. Press F6 and read the Console pane when the render finishes. Then change
//     one $fn and render again: the time it takes is the cost of smoothness.
