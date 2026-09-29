// Lesson 2 - combining shapes (CSG)
//
// Every solid is built from three operations on its children:
//   union()         everything in any child                A or B
//   difference()    the FIRST child minus all the others   A and not B
//   intersection()  only where every child overlaps        A and B
// Objects at the top of a file are unioned for you, so union() mostly appears
// when a group has to act as ONE child of something else.
//
// F6 on this whole file prints ONE warning, on purpose: section 4 shows what it
// looks like when two solids only touch along an edge.

// ---------------------------------------------------------------------------
// 1. The three operations on the same pair                           (row y = 0)
// ---------------------------------------------------------------------------
union() {
    cube(10, center = true);
    sphere(d = 13, $fn = 48);
}

translate([25, 0, 0])
    difference() {
        cube(10, center = true);
        sphere(d = 13, $fn = 48);
    }

translate([50, 0, 0])
    intersection() {
        cube(10, center = true);
        sphere(d = 13, $fn = 48);
    }

// ---------------------------------------------------------------------------
// 2. Seeing what a difference() removed                              (row y = 0)
// ---------------------------------------------------------------------------
// A cutter is invisible once it has cut. Four one-character modifiers help:
//   #  highlight this child in translucent red. It still takes effect.
//   %  show it as a grey ghost, and LEAVE IT OUT of the result.
//   !  show ONLY this subtree and ignore the rest of the file.
//   *  switch this subtree off.
// They are preview tools: # and % are drawn in F5 and ignored by F6.
translate([75, 0, 0])
    difference() {
        cube(10, center = true);
        #cylinder(h = 14, d = 4, center = true, $fn = 32);
    }

// ---------------------------------------------------------------------------
// 3. Cutters that stop exactly on a face                             (row y = 25)
// ---------------------------------------------------------------------------
// This hole is exactly as tall as the plate, so its ends sit ON the plate's top
// and bottom faces. Press F5: you will see a flickering skin across the hole.
// That is the preview failing to decide which face is in front.
translate([0, 25, 0])
    difference() {
        cube([12, 12, 3]);
        translate([6, 6, 0])
            cylinder(h = 3, d = 5, $fn = 32);
    }

// Measured on both builds: F6 renders the plate above correctly - one manifold
// part, the same volume as the version below. So this is a PREVIEW problem, and
// the preview is what you debug with. Make every cutter overshoot the faces it
// cuts through, and the preview stops lying to you.
eps = 0.01;
translate([20, 25, 0])
    difference() {
        cube([12, 12, 3]);
        translate([6, 6, -eps])
            cylinder(h = 3 + 2 * eps, d = 5, $fn = 32);
    }

// ---------------------------------------------------------------------------
// 4. Solids that only touch                                          (row y = 25)
// ---------------------------------------------------------------------------
// Measured on both builds:
//   touching along a FACE  (either a whole face or part of one) -> fused into one part
//   touching along an EDGE                                       -> TWO parts
// The 2021.01 release says "Object may not be a valid 2-manifold" for the edge
// case; the 2026 nightly says nothing. A slicer may print two parts or refuse,
// and scripts/scad-check.sh blocks any STL that is not exactly one part.
translate([40, 25, 0]) {
    cube([8, 8, 3]);
    translate([8, 8, 0])
        cube([8, 8, 3]);          // edge contact: two parts
}

// So do not rely on contact at all: overlap the pieces. The models in this
// repository call that overlap `weld`, and bury every feature by it.
weld = 0.5;
translate([65, 25, 0]) {
    cube([8, 8, 3]);
    translate([8 - weld, 8 - weld, 0])
        cube([8, 8, 3]);          // overlapped: one part
}

// ---------------------------------------------------------------------------
// 5. hull() - the shrink-wrap                                        (row y = 50)
// ---------------------------------------------------------------------------
// hull() gives the smallest convex solid containing all its children. It is
// cheap, and the easiest way to make a plate with rounded corners - which is
// also the first defence against corner lift (docs/fdm-design-rules.md §5b).
translate([0, 50, 0])
    hull()
        for (x = [3, 27], y = [3, 17])
            translate([x, y, 0])
                cylinder(h = 3, r = 3, $fn = 32);

// minkowski() rounds every edge of a solid, but is very slow on anything
// complex. Reach for hull() first.

// ---------------------------------------------------------------------------
// TRY
// ---------------------------------------------------------------------------
//  1. Put # in front of the sphere in the difference() in section 1.
//  2. Put ! in front of the hull() in section 5. Then remember to take it out.
//  3. Build a 30 x 20 x 3 plate with rounded corners and a 3 mm hole 4 mm in
//     from each corner. Make the holes overshoot the plate.
//  4. Move the second block in section 4 so the blocks touch at a face again.
//     Render with F6 and read the Console: one volume, or two?
