/*
Lesson 6 - a real part, written the way this repository writes them.

Check it end to end from the repository root:

    scripts/scad-check.sh docs/openscad-basics/06-a-real-part/m3-spacer.scad

That renders it, runs its asserts, confirms the mesh is one manifold part, slices
it, and compares the fdm_* values against the profile it was actually sliced with.

Two kinds of check, and the difference between them is the point:
  assert()               the settings describe something that cannot print
                         properly. The build STOPS, and scad-check.sh reports BLOCKED.
  echo("WARNING: ...")   it builds and prints, but something is compromised. The
                         build continues, and scad-check.sh exits 2 so you decide.

BEADS, NOT PERIMETERS. This model counts BEADS: extrusion widths across the wall.
scad-check.sh also prints the profile's `perimeters` setting, which counts loops
per SURFACE - and a tube has two surfaces, the outside and the hole. So "5 beads"
here and "perimeters 2" in the slicer line are not in conflict.
fdm-design-rules §1 uses "perimeters" in the bead sense.
*/
include <m3-spacer.params.scad>

// Derived values - computed from the settings, never set by hand.
hole_model_d = hole_d + 2 * fdm_hole_comp;   // what is actually modelled
outer_d      = hole_model_d + 2 * wall;
beads        = wall / fdm_extrusion_w;
layers       = length / fdm_layer_h;

eps = 0.01;    // how far a cutter overshoots a face (lesson 2)
$fa = 2;       // curve resolution for the whole part (lesson 1)
$fs = 0.4;

// The rules. Each message quotes the numbers it protects, so a failure tells
// you what to change - not merely that something is wrong.
assert(abs(beads - round(beads)) < 1e-6,
       str("wall (", wall, ") must be a whole number of extrusion widths (",
           fdm_extrusion_w, "); it is ", beads,
           " - fdm-design-rules §1: an in-between wall prints with a void in it"));

assert(beads >= 3,
       str("wall (", wall, ") is under three beads (", 3 * fdm_extrusion_w,
           " mm), the minimum for anything that takes force - fdm-design-rules §1"));

assert(hole_d >= 2,
       str("hole_d (", hole_d, ") is under 2 mm. Holes that small distort or close up;",
           " print a pilot and drill it - fdm-design-rules §2"));

assert(abs(layers - round(layers)) < 1e-6,
       str("length (", length, ") must be a whole number of ", fdm_layer_h,
           " mm layers; it is ", layers));

// A judgement call, not an impossibility: a thinner wall still prints.
if (round(beads) < 5)
    echo(str("WARNING: the wall is ", round(beads), " beads. A screw clamps",
             " this part, and fdm-design-rules §1 asks for 5 (", 5 * fdm_extrusion_w, " mm)"));

// Facts worth seeing every time it renders.
echo(str("M3 spacer: ", length, " mm long, ", outer_d, " mm across, ",
         round(beads), " beads of wall, ", round(layers), " layers"));
echo(str("hole modelled at ", hole_model_d, " mm for a nominal ", hole_d,
         " mm - it prints undersize by roughly the difference"));

// The part itself is two lines. Everything above exists so that these two lines
// can only ever be given numbers that print.
difference() {
    cylinder(h = length, d = outer_d);
    translate([0, 0, -eps])
        cylinder(h = length + 2 * eps, d = hole_model_d);
}

// TRY
//  1. Set wall = 1.8 in the params file and run scad-check.sh. Read the WARNING.
//  2. Set wall = 1.1. Read the assert message, then find the rule it quotes.
//  3. Set length = 10.1. Why does that fail when 10.2 does not?
//  4. Add a hexagonal outside, so a spanner can hold it: cylinder(..., $fn = 6).
//     A hexagon's "diameter" is corner to corner, so work out what d gives 7 mm
//     across the flats - and add an assert that the wall still holds at a flat.
