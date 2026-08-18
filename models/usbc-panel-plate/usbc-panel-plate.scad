// ---------------------------------------------------------------------------
// USB-C panel plate — a rectangle with three holes.
//
//   centre  : two-level opening — a thin lip sized to the PORT, opening out
//             behind into a relief pocket for the connector's boss
//   2 sides : screw holes
//
// Fits the commodity IP67-style panel-mount USB-C feedthrough (the moulded
// black flange with a raised rounded-rect boss and one screw hole each side).
//
// ORIENTATION
//   AUTHORED with the plate body spanning z = 0 .. plate_t, z = 0 being the
//   face that ends up outside the case. With the default prot_face = "front"
//   the raised rectangle extends to z = -prot_t, so the visible face is at
//   -prot_t, not 0.
//
//   EXPORTED rotated: flip_for_print puts the BACK face on the bed.
//   PRINT BACK FACE DOWN — the STL already arrives that way, so do NOT flip it
//   again in the slicer. Front-face-down lands the protrusion on the bed and
//   leaves the plate rim overhanging ~4.6 mm in mid-air.
// ---------------------------------------------------------------------------

// The parameters live in their own file — see the note at the top of it.
// include (not use): this needs the VALUES, and `use` would import only modules.
include <usbc-panel-plate.params.scad>

// ---------------------------------------------------------------------------
// DERIVED — computed from the parameters, never set by hand. If you want one of
// these to be a different number, change what it is computed FROM.
// ---------------------------------------------------------------------------
min_w   = (screw_style == "slot") ? 0 : screw_envelope + 2 * screw_edge_margin;
cover_w = gap_w + 2 * overlap;
plate_w = max(cover_w, min_w);
plate_h = gap_h + 2 * overlap;
// ---------------------------------------------------------------------------
// AS-CUT dimensions. Every cut, echo and assert below uses these, so what gets
// audited is the geometry actually produced. Computing a web from nominal while
// cutting with fdm_hole_comp reports it 0.15-0.30 mm better than it really is.
// ---------------------------------------------------------------------------
pw  = port_w  + 2 * fdm_hole_comp;                  // lip opening, as cut
ph  = port_h  + 2 * fdm_hole_comp;
bw  = boss_w  + 2 * (fdm_hole_comp + boss_clear);   // pocket, as cut
bh  = boss_h  + 2 * (fdm_hole_comp + boss_clear);
sd  = screw_d + 2 * fdm_hole_comp;                  // screw hole, as cut
nr  = notch_r + fdm_hole_comp;                      // notch radius, as cut
cbd = cbore_d + 2 * fdm_hole_comp;                  // counterbore, as cut
eps = 0.01;         // nudge for cut solids that would otherwise end exactly
                    // on another cut's plane -- a shared coplanar face is
                    // what breaks 2-manifoldness

slot_n      = bridge_slot ? 2 : 0;              // staged layers before the lip
pocket_z    = lip_t + slot_n * fdm_layer_h;         // where the pocket floor sits
pocket_d    = plate_t - pocket_z;               // usable pocket depth
port_recess = lip_t + ((prot_face == "front") ? prot_t : 0);
top_z       = plate_t + ((prot_face == "back") ? prot_t : 0);

// ---------------------------------------------------------------------------

// 2D rounded rectangle, centred on the origin. r is clamped so an over-large
// value degrades to a stadium rather than erroring.
module rrect2d(w, h, r) {
    rr = min(r, w / 2, h / 2);
    hull()
        for (x = [-1, 1], y = [-1, 1])
            translate([x * (w / 2 - rr), y * (h / 2 - rr)])
                circle(r = rr);
}

// 3D rounded-rectangle prism, centred in X and Y, sitting on z = 0.
module rrect(w, h, t, r) {
    linear_extrude(height = t) rrect2d(w, h, r);
}

// Tapered opening, WIDE at z = 0 and narrowing to nominal at z = lead. On
// whichever face it sits, the hole is largest at that face and closes inward,
// so it is a 45 deg feature rather than an unsupported ledge.
module chamfer_flare_down(w, h, r, lead) {
    hull() {
        linear_extrude(height = 0.01)
            rrect2d(w + 2 * lead, h + 2 * lead, r + lead);
        translate([0, 0, lead])
            linear_extrude(height = 0.01)
                rrect2d(w, h, r);
    }
}

module usbc_panel_plate() {
    // With a front protrusion the outermost face moves out to -prot_t, so cuts
    // that must pass through everything start beyond it.
    pt      = (prot_face == "front") ? prot_t : 0;
    front_z = -pt;
    cut_lo  = front_z - 1;
    cut_len = pt + plate_t + ((prot_face == "back") ? prot_t : 0) + 2;

    difference() {
        union() {
            rrect(plate_w, plate_h, plate_t, corner_r);

            // The raised rectangle. Overlaps the plate by 0.01 so the union is
            // manifold rather than two solids touching on a plane.
            if (prot_t > 0)
                translate([0, 0, (prot_face == "front")
                                   ? -prot_t
                                   : plate_t - 0.01])
                    rrect(prot_w, prot_h, prot_t + 0.01, prot_r);
        }

        // Lip opening — runs the full depth, through the protrusion too.
        translate([0, 0, cut_lo])
            rrect(pw, ph, cut_len, port_r);

        // The three staged layers. Ordered from the LIP outward, which is the
        // reverse of print order — printed back-face-down the pocket comes
        // first, so layer 1 below is the one nearest the pocket and prints
        // first, and the rounded lip prints last.
        //
        // Each cut runs one layer and is a superset of the one under it, so the
        // larger opening simply wins at its own height. Nothing here relies on
        // the order the cuts are written in.
        if (bridge_slot) {
            // layer 2 — the RECTANGLE. Square corners, port-sized. Sits
            // between the slot and the rounded lip, and is what lets layer 3
            // add nothing but curves.
            translate([0, 0, lip_t])
                linear_extrude(fdm_layer_h + eps)
                    square([pw, ph], center = true);

            // layer 1 — THE TWO BRIDGE. Full-height slot, so what gets laid is
            // two strips spanning bh wall-to-wall, anchored at both ends.
            translate([0, 0, lip_t + fdm_layer_h])
                linear_extrude(fdm_layer_h + eps)
                    square([pw, bh], center = true);
        }

        // Rear relief pocket for the connector's raised boss, above the slot.
        // Extruded with cut_len so it still reaches the rear face on the
        // prot_face = "back" branch.
        translate([0, 0, pocket_z])
            rrect(bw, bh, cut_len, boss_r);

        // Chamfer at the pocket mouth. Printed back-face-down that mouth is the
        // bed face, so this costs nothing and eases the boss in.
        if (pocket_chamfer > 0)
            translate([0, 0, top_z + 0.01])
                mirror([0, 0, 1])
                    chamfer_flare_down(bw, bh, boss_r, pocket_chamfer);

        // Lead-in chamfer, on whichever face is the outermost one.
        if (lead_in > 0)
            translate([0, 0, front_z - 0.01])
                chamfer_flare_down(pw, ph, port_r, lead_in);

        // Half-circle cutouts in the top and bottom (Y) edges. The cylinder is
        // centred ON the edge, so exactly half of it lands inside the plate.
        if (notch_r > 0)
            for (s = [-1, 1])
                translate([notch_mirror ? s * notch_x : notch_x,
                           s * plate_h / 2,
                           cut_lo])
                    cylinder(h = cut_len, r = nr);

        // Screw holes — closed, or open to the edge as a U-slot.
        for (s = [-1, 1]) {
            translate([s * screw_span / 2, 0, cut_lo])
                cylinder(h = cut_len, d = sd);

            // The slot's channel runs from the hole centre outward past the
            // plate edge. Same width as the hole, so the screw shank is a
            // sliding fit the whole way and the plate cannot rattle sideways.
            if (screw_style == "slot")
                translate([s > 0 ? screw_span / 2 : -screw_span / 2 - plate_w,
                           -sd / 2, cut_lo])
                    cube([plate_w, sd, cut_len]);

            // Counterbore is anchored to the PLATE face, not the protrusion's
            // outer face — otherwise the protrusion swallows it and it becomes
            // a silent no-op whenever one exists.
            if (cbore_d > 0)
                translate([s * screw_span / 2, 0, -0.01])
                    cylinder(h = cbore_h + 0.01, d = cbd);
        }
    }
}

// Rotate 180 about X so the BACK face lands on the bed — the orientation this
// actually prints in, so the STL arrives already oriented. The part's top is
// top_z, which includes prot_t again when the protrusion is on the back;
// lifting by that puts its lowest point on z = 0.

// draw_model lets a companion file (parameter-map.scad) include this one for
// its VALUES without also rendering the part. Assign it false AFTER the
// include -- in OpenSCAD the last assignment in a scope wins.
draw_model = true;

if (draw_model && flip_for_print)
    translate([0, 0, top_z])
        rotate([180, 0, 0])
            usbc_panel_plate();
else if (draw_model)
    usbc_panel_plate();

// --- sanity check -----------------------------------------------------------
// All computed from the AS-CUT names above.
web_side   = (screw_span - sd) / 2 - bw / 2;
web_topbot = (plate_h - bh) / 2;
edge_dist  = (plate_w - screw_span - sd) / 2;
corner_min = corner_r * (1 - 1 / sqrt(2));
// Stage 1 leaves four corner pieces. They are not bridges — each hangs off the
// pocket's own rounded corner — so what matters is how far each reaches in.
bridge_1   = bh;   // layer 1: two strips span this, wall to wall
bridge_2   = pw;   // layer 2: the two remaining sides span this, onto the strips
// Stage 2 then bridges BETWEEN those corners: the top and bottom arms span pw
// in X, the left and right arms span ph in Y. Cutting the cross both ways is
// what turns the old single 8.8 mm span into a 9.6 and a 3.9.
bridge_3   = port_r; // layer 3: only fillets of this radius, on solid material
prot_screw_gap = screw_span / 2 - sd / 2 - prot_w / 2;

notch_over_pocket = notch_r > 0 && abs(notch_x) < bw / 2 + nr;
notch_web         = plate_h / 2 - nr - bh / 2;
notch_dx          = abs(abs(notch_x) - screw_span / 2);
notch_screw_gap   = sqrt(notch_dx * notch_dx + (plate_h / 2) * (plate_h / 2))
                    - nr - sd / 2;
notch_vs_gap      = plate_h / 2 - nr - gap_h / 2;

echo(str("plate              : ", plate_w, " x ", plate_h, " x ", plate_t, " mm"));
// Which floor is actually setting the width, and what the other one would allow.
// Without this it is invisible that shrinking the plate means touching the
// fasteners rather than the coverage.
echo(str("  width set by     : ",
         (plate_w > cover_w + 1e-9) ? str("FASTENERS (", min_w,
             ") - coverage alone would allow ", cover_w)
           : str("COVERAGE (", cover_w, ") - the hard floor"),
         "   [screw_style ", screw_style, "]"));
echo(str("covers opening     : ", gap_w, " x ", gap_h, " mm, lap ", overlap,
         " mm (corner floor ", corner_min, ")"));
echo(str("port opening       : ", pw, " x ", ph, " mm as cut"));
echo(str("port recess        : ", port_recess, " mm a plug must reach in",
         (prot_face == "front" && prot_t > 0)
            ? str(" (lip ", lip_t, " + protrusion ", prot_t, ")") : ""));
echo(str("rear pocket        : ", bw, " x ", bh, " mm as cut, ", pocket_d,
         " mm deep, ", boss_clear, " mm/side clearance on the boss"));
echo(str("max boss height    : ", pocket_d + panel_t,
         " mm from the connector flange (pocket ", pocket_d,
         " + panel ", panel_t, ")"));
echo(str("two-bridge trick   : ", bridge_slot ? "ON" : "OFF",
         bridge_slot ? str(" -- ", slot_n + 1, " staged layers of ", fdm_layer_h, " mm")
                     : " -- the port outline is drawn in mid-air"));
echo(str("  L1 two bridge    : slot ", pw, " x ", bh,
         "  -> two strips spanning ", bridge_1, " mm, anchored both ends"));
echo(str("  L2 rectangle     : ", pw, " x ", ph,
         " square  -> the other two sides bridge ", bridge_2, " mm"));
echo(str("  L3 rounded       : r", bridge_3,
         " fillets only, laid on the solid rectangle below"));
echo(str("web beside pocket  : ", web_side, " mm"));
echo(str("web above/below    : ", web_topbot, " mm"));
echo(str("outboard of screw  : ", edge_dist, " mm"));

if (prot_t > 0) {
    echo(str("protrusion         : ", prot_w, " x ", prot_h, " x ", prot_t,
             " mm on the ", prot_face));
    echo(str("  frame beside port: ", (prot_w - pw) / 2, " mm"));
    echo(str("  frame over/under : ", (prot_h - ph) / 2, " mm"));
    echo(str("  prot -> screw    : ", prot_screw_gap, " mm"));
}

if (notch_r > 0) {
    echo(str("notch              : r ", notch_r, " mm (", nr, " as cut) at x = ",
             notch_x, notch_mirror ? " (mirrored)" : ""));
    echo(str("  notch -> pocket  : ",
             notch_over_pocket ? str(notch_web, " mm")
                               : "clear in X, does not overlap the pocket"));
    echo(str("  notch -> screw   : ", notch_screw_gap, " mm"));
    echo(str("  lap left at notch: ", notch_vs_gap, " mm"));
}

screws_over_air = screw_envelope < gap_w;
echo(str("screws land on     : ",
         screws_over_air ? "OPEN AIR - plate clamps to the connector, panel trapped by the lap"
                         : "panel material - plate bolts through the panel"));

// ============================================================================
// GUARDS — two kinds, and the distinction is deliberate
//
//   BLOCK (assert)  the geometry is impossible or self-contradictory. A feature
//                   would vanish, invert, or cut the part in two. There is no
//                   sensible STL to produce, so the render stops.
//
//   WARN  (echo)    the part builds and can be printed, but something about it
//                   is compromised — a wall under the perimeter floor, a notch
//                   that opens into the case, a stage that lands mid-layer.
//                   You get the STL AND you get told.
//
// The earlier version asserted both, which meant exploring a design was blocked
// by problems that were judgement calls rather than impossibilities. Deciding to
// accept a thin wall is the operator's call; producing a part with no lip is
// not a call at all.
// ============================================================================

// --- BLOCK: impossible geometry ---------------------------------------------
assert(prot_face == "front" || prot_face == "back",
       "prot_face must be \"front\" or \"back\"");
assert(lip_t > 0 && lip_t < plate_t,
       "lip_t must be between 0 and plate_t");
assert(pw < bw && ph < bh,
       "the lip is not smaller than the pocket - there would be no lip at all");
assert(pocket_d > 0,
       "no pocket left once the staged layers are taken out");
assert(pocket_chamfer < pocket_d,
       "the pocket chamfer is deeper than the pocket");
assert(!bridge_slot || slot_n * fdm_layer_h < plate_t - lip_t,
       "the staged layers are deeper than the space between lip and back face");
assert(lead_in < ((prot_face == "front") ? prot_t : 0) + lip_t,
       "lead_in eats through the protrusion and the whole lip");
assert(notch_r == 0 || notch_r < plate_h / 2,
       "notch radius is at least half the plate height - it would cut the plate in two");
assert(prot_t == 0 || (prot_w > pw && prot_h > ph),
       "the protrusion is not bigger than the port opening - it would vanish");
assert(prot_t == 0 || (prot_w <= plate_w && prot_h <= plate_h),
       "the protrusion is bigger than the plate it stands on");
assert(prot_t == 0 || prot_face != "back" || (prot_w > bw && prot_h > bh),
       "prot_face=\"back\": the rear pocket swallows the protrusion - it would print as two slivers");

// --- WARN: it builds, but ----------------------------------------------------
// Collected as a list so they can be counted and reported together rather than
// scattered through the log where a single line is easy to scroll past.
warns = [
    // coverage
    if (overlap <= corner_min)
        str("overlap ", overlap, " is at or under the corner floor ", corner_min,
            " - the ROUNDED CORNERS fall inside the aperture, leaving four open",
            " gaps into the case even though every straight edge covers"),
    if (plate_h < gap_h + 2 * overlap - 0.01)
        str("plate is shorter than the opening it must cover"),

    // fasteners and webs, against the derived perimeter floors
    if (screw_style != "slot" && edge_dist < perim3 - 1e-9)
        str("outboard of screw ", edge_dist, " mm is under 3 perimeters (",
            perim3, ") as cut - a screw pulls directly on this and it will split"),
    if (web_side <= perim2)
        str("web beside pocket ", web_side, " mm is under 2 perimeters (",
            perim2, ") as cut"),

    // the notches eat the lap, which is the only retention this part has
    if (notch_r > 0 && notch_vs_gap <= 0.4)
        str("notch breaks through into the case opening by ", -notch_vs_gap,
            " mm - it severs the lap across its whole chord, and the lap is the",
            " ONLY thing retaining this plate"),
    if (notch_over_pocket && notch_web <= 0.8)
        str("notch cuts to within ", notch_web, " mm of the rear pocket"),
    if (notch_r > 0 && notch_screw_gap <= 0.8)
        str("notch cuts to within ", notch_screw_gap, " mm of a screw hole"),

    // protrusion
    if (prot_t > 0 && prot_screw_gap <= 0.4)
        str("protrusion is within ", prot_screw_gap, " mm of the screw holes"),

    // bridging
    if (bridge_slot && bridge_1 > 10)
        str("L1 strips span ", bridge_1, " mm, over the ~10 mm bridge ceiling"),
    if (bridge_slot && bridge_2 > 10)
        str("L2 sides span ", bridge_2, " mm, over the ~10 mm bridge ceiling"),

    // the staging quietly doing less than it claims
    if (bridge_slot && bh <= ph)
        str("L1 slot is no taller than the port - L1 and L2 are the same layer"),
    if (bridge_slot && port_r <= 0)
        str("port_r is 0 - L2 and L3 are the same layer, so the staging is",
            " buying nothing"),

    // layer alignment
    if (abs(plate_t / fdm_layer_h - round(plate_t / fdm_layer_h)) >= 1e-6)
        str("plate_t ", plate_t, " is not a whole number of ", fdm_layer_h,
            " layers - internal steps will land mid-layer"),
    if (abs(lip_t / fdm_layer_h - round(lip_t / fdm_layer_h)) >= 1e-6)
        str("lip_t ", lip_t, " is not a whole number of ", fdm_layer_h, " layers")
];

for (w = warns) echo(str("WARNING: ", w));
echo(len(warns) == 0
     ? "warnings           : none"
     : str("warnings           : ", len(warns), " - the part will build, read them"));

assert(screw_style == "hole" || screw_style == "slot",
       "screw_style must be \"hole\" or \"slot\"");
