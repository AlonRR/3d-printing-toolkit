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
// THE PROFILE IS COPIED FROM gridfinitybasket.scad IN THIS FOLDER, deliberately, so both produce
// the same foot. The four points are the gridfinity standard: up-and-out at 45 degrees for 0.7,
// straight up for 1.8, then up-and-out at 45 degrees for 2.15 - 4.65 mm tall in total.
//
// HOW THE SOLID IS BUILT, and why not the way the basket builds it. The basket sweeps the profile
// around a rounded rectangle with sweep_rounded(), which works but leaves 50 non-manifold edges
// where the four wall segments meet the four corner rotate_extrudes. Here each section of the
// profile is instead a hull() between two offset() rounded squares. A rounded square is convex, and
// the hull of two parallel convex profiles is a convex frustum, so every section is manifold by
// construction and the union of three stacked sections is too. Same geometry, no seams to fix.
//
// The cross-section at any height is simply the 34 mm core square offset outward by the profile's
// x at that height - which is what makes the offset()/hull() construction exact rather than an
// approximation of the swept version.

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
EPS = 0.001;

// ---- gridfinity constants, names kept identical to gridfinitybasket.scad for traceability -----
BASEPLATE_DIMENSIONS = [42, 42];
BASEPLATE_OUTER_DIAMETER = 8;
BASEPLATE_PROFILE = [
    [0, 0],                         // innermost bottom point
    [0.7, 0.7],                     // up and out at 45 degrees
    [0.7, (0.7 + 1.8)],             // straight up
    [(0.7 + 2.15), (0.7 + 1.8 + 2.15)],  // up and out at 45 degrees
];
BASEPLATE_OUTER_RADIUS = BASEPLATE_OUTER_DIAMETER / 2;          // 4.00
BASEPLATE_INNER_RADIUS = BASEPLATE_OUTER_RADIUS - BASEPLATE_PROFILE[3].x;  // 1.15

CORE = BASEPLATE_DIMENSIONS.x - BASEPLATE_OUTER_DIAMETER;       // 34 - the square being offset
FOOT_H = BASEPLATE_PROFILE[3].y;                                // 4.65

// offset of the wall from the core, at profile point i, minus any clearance
function off(i) = BASEPLATE_INNER_RADIUS + BASEPLATE_PROFILE[i].x - Clearance;

// ---- geometry ---------------------------------------------------------------------------------
module rounded_core(r) {
    // offset(r) on a CORE square yields a rounded square of side CORE+2r with corner radius r,
    // which is exactly the gridfinity cross-section at the height that r came from.
    offset(r = r) square([CORE, CORE], center = true);
}

module foot_section(i) {
    z0 = BASEPLATE_PROFILE[i].y;
    z1 = BASEPLATE_PROFILE[i + 1].y;
    hull() {
        translate([0, 0, z0])           linear_extrude(EPS) rounded_core(off(i));
        translate([0, 0, z1 - EPS])     linear_extrude(EPS) rounded_core(off(i + 1));
    }
}

module foot() {
    for (i = [0 : len(BASEPLATE_PROFILE) - 2]) foot_section(i);
}

module foot_negative(nx, ny) {
    difference() {
        // Exactly FOOT_H tall, sitting on Z0. It is tempting to extend this below Z0 to avoid a
        // coplanar face with the model's underside - do not. Below Z0 there is no foot to subtract
        // from it, so the extension would be a solid slab spanning the whole footprint and would
        // shave that much off the ENTIRE bottom of the model, not just around the feet.
        translate([0, 0, FOOT_H / 2])
            cube([nx * BASEPLATE_DIMENSIONS.x, ny * BASEPLATE_DIMENSIONS.y, FOOT_H], center = true);

        for (x = [0 : nx - 1], y = [0 : ny - 1])
            translate([(x - (nx - 1) / 2) * BASEPLATE_DIMENSIONS.x,
                       (y - (ny - 1) / 2) * BASEPLATE_DIMENSIONS.y, 0])
                foot();
    }
}

echo(str("gridfinity foot negative ", GridX, "x", GridY,
         "  footprint ", GridX * BASEPLATE_DIMENSIONS.x, " x ", GridY * BASEPLATE_DIMENSIONS.y,
         " mm, height ", FOOT_H, " mm, clearance ", Clearance, " mm"));

foot_negative(GridX, GridY);
