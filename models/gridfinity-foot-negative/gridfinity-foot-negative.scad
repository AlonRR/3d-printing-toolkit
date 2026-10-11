// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

// Gridfinity foot NEGATIVE - gives any model a gridfinity bin bottom.
//
// WHAT THIS IS. Not a bin, and not a baseplate: it is the material you REMOVE from a flat-bottomed
// model to leave a gridfinity foot behind. Load your model in PrusaSlicer, right-click ->
// Add negative volume -> Load..., pick one of the STLs, and drop it to the bottom of the part.
// What remains is a standard gridfinity foot that seats in any baseplate.
//
// PLACEMENT. The mesh is centred on X and Y and sits on Z0, matching how PrusaSlicer places a
// loaded negative volume relative to the object's own origin. Set the negative's Z position to the
// bottom of your model; if the model is not centred, match X/Y too. The part of your model that
// lies outside this footprint is untouched, so a model larger than the negative keeps a flat skirt
// around the foot - which is usually what you want.
//
// THE GEOMETRY is scad-tools' lib/gridfinity.scad (11 Oct 2026): the standard's profile, and why each
// section is a hull() of two offset() rounded squares rather than a sweep. This file only sets the size,
// the fit and the smoothness, and says what it drew.

use <../../scad-tools/lib/gridfinity.scad>

/* [Grid] */
// cells along X
GridX = 1;      // [1:16]
// cells along Y
GridY = 1;      // [1:16]

/* [Fit] */
// Shrinks the foot on every side, so the printed foot is looser in a baseplate. 0 is nominal and
// matches gridfinitybasket.scad. Try 0.1-0.25 only if your prints seat too tightly - note this is
// a NEGATIVE, so a larger clearance removes MORE material and leaves a SMALLER foot.
Clearance = 0;  // [0:0.05:0.5]

/* [Quality] */
// segments per full circle; 64 is smooth at a 4 mm corner radius
Smoothness = 64;

/* [Hidden] */
$fn = Smoothness;

echo(str("gridfinity foot negative ", GridX, "x", GridY,
         "  footprint ", GridX * gridfinity_cell()[0], " x ", GridY * gridfinity_cell()[1],
         " mm, height ", gridfinity_foot_h(), " mm, clearance ", Clearance, " mm"));

gridfinity_foot_negative(GridX, GridY, Clearance);
