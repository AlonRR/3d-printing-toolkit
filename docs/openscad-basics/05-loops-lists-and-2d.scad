// Lesson 5 - loops, lists, and designing in 2D
//
// Most printable parts are easier to draw as a flat outline and then extrude,
// than to assemble from 3D primitives. This lesson covers the lists and loops you
// need to describe outlines, and the operations that turn them into solids.

// ---------------------------------------------------------------------------
// 1. Ranges and lists
// ---------------------------------------------------------------------------
//   [start : end]           steps of 1, and the END IS INCLUDED
//   [start : step : end]
echo(evens = [for (i = [0:2:8]) i]);                    // [0, 2, 4, 6, 8]

pts = [[0, 0], [20, 0], [20, 10], [0, 10]];
echo(count = len(pts), first = pts[0], x_of_third = pts[2][0]);

// A list comprehension can filter with `if`...
echo(right_side = [for (p = pts) if (p[0] > 10) p]);   // [[20, 0], [20, 10]]
// ...and `each` splices a list in, instead of nesting it:
echo(flat = [for (p = pts) each p]);                   // [0, 0, 20, 0, 20, 10, 0, 10]

// ---------------------------------------------------------------------------
// 2. A for loop makes one copy per value, and unions them          (row y = 0)
// ---------------------------------------------------------------------------
for (i = [0:4])
    translate([i * 8, 0, 0])
        cylinder(h = 2 + i, d = 5, $fn = 24);

// ---------------------------------------------------------------------------
// 3. 2D shapes, and linear_extrude to make them solid                (row y = 20)
// ---------------------------------------------------------------------------
// square(), circle() and polygon() live on the XY plane with no thickness.
// linear_extrude(height) lifts an outline straight up.
translate([0, 20, 0])
    linear_extrude(height = 3)
        polygon([[0, 0], [20, 0], [20, 4], [6, 12], [0, 12]]);

// twist and scale are optional, and make shapes no primitive can.
translate([40, 26, 0])
    linear_extrude(height = 12, twist = 90, scale = 0.6, slices = 24)
        square(10, center = true);

// ---------------------------------------------------------------------------
// 4. offset() - grow, shrink, or round an outline                    (row y = 45)
// ---------------------------------------------------------------------------
// offset(r = x) grows the outline by x and rounds every convex corner with
// radius x. Rounding the plan view is the first defence against corner lift
// (docs/fdm-design-rules.md §5b), and offset() is the cheapest way to do it.
translate([3, 48, 0])
    linear_extrude(height = 3)
        offset(r = 3)
            square([24, 14]);

// offset(r = -x) shrinks. Chained offsets run from the shape OUTWARD - the one
// nearest the shape first, exactly like the transforms in lesson 1. Measured on
// this L-shaped outline:
//   offset(r = 2)  offset(r = -2)                  shrink, then grow: rounds the OUTSIDE corners only
//   offset(r = -2) offset(r = 2)                   grow, then shrink: rounds the INSIDE corner only
//   offset(r = -2) offset(r = 4) offset(r = -2)    rounds both, as below
translate([40, 45, 0])
    linear_extrude(height = 3)
        offset(r = -2) offset(r = 4) offset(r = -2)
            polygon([[0, 0], [30, 0], [30, 20], [20, 20], [20, 8], [0, 8]]);

// ---------------------------------------------------------------------------
// 5. rotate_extrude - spin a profile around Z                        (row y = 80)
// ---------------------------------------------------------------------------
// The 2D profile is drawn in X (radius) and Y (height), and must sit entirely at
// x >= 0. This one is the wall of a small cup: 2 mm thick, with a 1.5 mm floor.
translate([15, 85, 0])
    rotate_extrude($fn = 96)
        polygon([[0, 0], [12, 0], [14, 16], [12, 16], [10.2, 1.5], [0, 1.5]]);

// ---------------------------------------------------------------------------
// 6. text() - labels                                                 (row y = 80)
// ---------------------------------------------------------------------------
// docs/fdm-design-rules.md §5c: RAISE text on vertical faces and ENGRAVE it on
// horizontal ones, and keep digits at least 5 mm tall on a 0.4 nozzle. This label
// is engraved into a top face, and the cutter overshoots it (lesson 2).
translate([40, 78, 0])
    difference() {
        cube([40, 14, 3]);
        translate([20, 7, 3 - 0.6])
            linear_extrude(height = 1)
                text("M3", size = 7, halign = "center", valign = "center");
    }

// ---------------------------------------------------------------------------
// TRY
// ---------------------------------------------------------------------------
//  1. Turn section 2 into a staircase: every step 2 mm taller AND 5 mm further
//     along, with the steps overlapping so they print as one part.
//  2. Engrave your initials instead of "M3". Then raise them instead (union in
//     place of difference) and decide which one you would rather print on a top face.
//  3. Change the cup profile in section 5 into a 40 mm pot with a 3 mm wall.
//  4. Give polygon() a point list you built with a list comprehension: a regular
//     hexagon, [for (a = [0:60:300]) [10 * cos(a), 10 * sin(a)]].
