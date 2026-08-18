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

/* [The opening in the case panel — what the plate has to cover] */
gap_w   = 23.4;     // MEASURED. Width of the opening.
gap_h   = 15.0;     // MEASURED. Height of the opening.
panel_t = 0.6;      // MEASURED. Sheet thickness of the case panel.
overlap = 2.5;      // how far the plate laps onto the panel, all the way round.
                    // The screws pass through open air, so this lap is the ONLY
                    // thing retaining the plate.
                    // Hard floor: corner_r * (1 - 1/sqrt(2)). Below that the
                    // rounded corners fall INSIDE the aperture and leave four
                    // open gaps into the case even though every edge "covers".

/* [Plate outline — derived, don't set these directly] */
// The plate must cover the opening AND keep both screw holes inside its own
// edge with enough material to survive a screw being tightened. The screws span
// 22.70 mm outer-to-outer; that plus 1.5 mm a side is the floor.
screw_envelope = 22.70;                 // measured, outer edge to outer edge
min_w = screw_envelope + 2 * 1.5;
plate_w = max(gap_w + 2 * overlap, min_w);
plate_h = gap_h + 2 * overlap;

// plate_t is chosen so every internal transition lands ON a layer boundary in
// the print orientation. At 0.2 mm layers, 2.4 puts the pocket floor, both
// ledges and the lip at print z 1.2 / 1.4 / 1.6 / 2.4. At 2.5 they all land
// mid-layer and the whole ledge scheme resolves on a slicer tie-break.
plate_t  = 2.4;
corner_r = 1.5;     // rounding on the outline corners

/* [Centre opening — lip, sized to the PORT] */
// USB-C receptacle shell is 8.94 x 3.16 mm, fixed by the USB spec; the plug's
// metal tongue is 8.34 x 2.56 and passes through easily at this size.
port_w  = 9.3;      // hugs the 8.94 mm receptacle shell with ~0.18 mm a side
port_h  = 3.6;      // ditto against the 3.16 mm shell height
port_r  = 2.0;      // clamped to a stadium shape by rrect2d()
lip_t   = 0.8;      // thickness of the lip itself. NOT how far a plug must
                    // reach: with a front protrusion the port sits
                    // lip_t + prot_t back. The echo reports that figure.
lead_in = 0.5;      // 45 deg chamfer on the outermost face, guides a plug in.
                    // Printed back-face-down this is a TOP-face feature, so it
                    // is a lead-in only — it does not relieve elephant's foot.

/* [Centre opening — rear relief, clears the connector's BOSS] */
boss_w = 13.4;      // <<CONFIRM>> width NOT yet measured, still photo-scaled
boss_h = 8.0;       // MEASURED. Height of the connector's raised boss.
boss_r = 2.0;
boss_clear = 0.25;  // REAL clearance per side, on top of hole_comp.
                    // hole_comp only cancels print shrink — it lands the
                    // feature ON nominal, which for a pocket means line-to-line
                    // on the boss. Fit needs its own allowance.
pocket_chamfer = 0.4;   // chamfer at the pocket mouth. That mouth is the bed
                        // face, so this is free and eases the boss in. 0 = none

/* [Raised rectangle protrusion] */
prot_w = 14.7;      // MEASURED
prot_h = 6.1;       // MEASURED
prot_t = 1.5;       // <<CONFIRM>> how far it stands proud. NOT measured.
prot_r = 1.5;       // corner rounding
prot_face = "front";  // "front" = the visible side (-Z), "back" = toward the
                      // connector (+Z)

/* [Half-circle notches in the Y edges] */
// Semicircular cutouts bitten out of the top and bottom edges.
// Sized so the cut — INCLUDING hole_comp — still leaves lap on the panel.
// At overlap 2.5 the ceiling is about 1.9; beyond that the notch opens a hole
// straight into the case and severs the lap across its whole chord.
notch_r = 1.8;      // radius. Set to 0 to remove them.
notch_x = 0;        // X offset from centre. Both notches share it; use
                    // notch_mirror to put one each side instead.
notch_mirror = false;   // true -> top notch at +notch_x, bottom at -notch_x

/* [Screws] */
// MEASURED with calipers across the connector's own flange holes:
//   inner edge to inner edge = 16.90 mm
//   outer edge to outer edge = 22.70 mm
// => centre-to-centre = (16.90 + 22.70) / 2 = 19.80 mm
// => hole diameter    = (22.70 - 16.90) / 2 =  2.90 mm  (M2.5 clearance)
screw_d    = 2.9;   // MEASURED. Clearance for M2.5. If the screws instead
                    // thread INTO this plate, drop to ~2.1 for a self-tap
                    // pilot rather than leaving it at clearance.
screw_span = 19.8;  // MEASURED. THE critical dimension.
cbore_d    = 0;     // counterbore diameter, 0 = none. M2.5 socket head = 4.5
cbore_h    = 1.2;   // counterbore depth, measured from the PLATE face

/* [Pocket -> lip transition — the two-bridge trick] */
// Printed back-face-down, the layer that closes over the pocket is the lip, and
// the lip HAS THE PORT HOLE IN IT. That is not a plain bridge: the printer
// would be asked to draw the hole's outline in mid-air, which is the classic
// "bridge with a hole in it" and comes out as spaghetti.
//
// The two-bridge trick (Hackaday calls it a sacrificial bridge; nophead called
// it hanging holes) splits it into two anchored stages:
//
//   stage 1, first layer over the pocket
//     the opening is a full-height SLOT, pw wide x bh tall. The material left
//     is two strips running the short axis, EACH ANCHORED AT BOTH ENDS on the
//     pocket walls. Nothing is drawn in air.
//
//   stage 2, the layer above
//     the opening closes down to the real port. The new material -- the bands
//     above and below the port -- bridges pw across, landing on stage 1's two
//     strips. Again anchored at both ends.
//
//        stage 1              stage 2              (looking down the bore)
//     +--+      +--+       +--+------+--+
//     |  |      |  |       |  |      |  |          two strips, then the
//     |  |  gap |  |       |  | port |  |          bands close onto them
//     |  |      |  |       |  |      |  |
//     +--+      +--+       +--+------+--+
//
bridge_slot = true; // false = lip closes in one go, and the hole is drawn in air
layer_h     = 0.2;  // must match the slicer, or the slot lands mid-layer

/* [Printing] */
flip_for_print = true;  // rotate 180 about X so the BACK face sits on the bed
hole_comp = 0.15;   // Printed holes come out undersize (extrusion width + the
                    // arc effect). Every hole is grown by this on each side.
                    // MK3S+ / 0.4 nozzle: 0.15 is a good starting point.
$fn = 64;

// ---------------------------------------------------------------------------
// AS-CUT dimensions. Every cut, echo and assert below uses these, so what gets
// audited is the geometry actually produced. Computing a web from nominal while
// cutting with hole_comp reports it 0.15-0.30 mm better than it really is.
// ---------------------------------------------------------------------------
pw  = port_w  + 2 * hole_comp;                  // lip opening, as cut
ph  = port_h  + 2 * hole_comp;
bw  = boss_w  + 2 * (hole_comp + boss_clear);   // pocket, as cut
bh  = boss_h  + 2 * (hole_comp + boss_clear);
sd  = screw_d + 2 * hole_comp;                  // screw hole, as cut
nr  = notch_r + hole_comp;                      // notch radius, as cut
cbd = cbore_d + 2 * hole_comp;                  // counterbore, as cut
eps = 0.01;         // nudge for cut solids that would otherwise end exactly
                    // on another cut's plane -- a shared coplanar face is
                    // what breaks 2-manifoldness

slot_n      = bridge_slot ? 1 : 0;              // layers the slot consumes
pocket_z    = lip_t + slot_n * layer_h;         // where the pocket floor sits
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

        // Stage 1 of the two-bridge trick: one layer where the opening is a
        // full-height slot instead of the port. What is left either side are
        // two strips spanning bh wall-to-wall, anchored at both ends. Square,
        // not rounded — a rounded slot would put an arc back in mid-air, which
        // is the exact thing this is removing.
        if (bridge_slot)
            translate([0, 0, lip_t])
                linear_extrude(layer_h + eps)
                    square([pw, bh], center = true);

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

        // Screw holes.
        for (s = [-1, 1]) {
            translate([s * screw_span / 2, 0, cut_lo])
                cylinder(h = cut_len, d = sd);

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
bridge_1   = bh;                 // stage-1 strips span this, wall to wall
bridge_2   = pw;                 // stage-2 bands bridge this, onto the strips
prot_screw_gap = screw_span / 2 - sd / 2 - prot_w / 2;

notch_over_pocket = notch_r > 0 && abs(notch_x) < bw / 2 + nr;
notch_web         = plate_h / 2 - nr - bh / 2;
notch_dx          = abs(abs(notch_x) - screw_span / 2);
notch_screw_gap   = sqrt(notch_dx * notch_dx + (plate_h / 2) * (plate_h / 2))
                    - nr - sd / 2;
notch_vs_gap      = plate_h / 2 - nr - gap_h / 2;

echo(str("plate              : ", plate_w, " x ", plate_h, " x ", plate_t, " mm"));
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
         bridge_slot ? str(" -- slot ", pw, " x ", bh, " for ", layer_h, " mm")
                     : " -- the port outline is drawn in mid-air"));
echo(str("  stage 1 span     : ", bridge_1,
         " mm  (two strips, wall to wall, anchored both ends)"));
echo(str("  stage 2 span     : ", bridge_2,
         " mm  (bands close onto those strips)"));
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

// --- guards -----------------------------------------------------------------
// Each of these blocks a render. Anything that merely reports is above: a check
// that prints a warning and then builds anyway is not a check.

// Coverage. The flat-edge test alone is not enough — rounded corners pull the
// plate inside the aperture diagonally even when every edge nominally covers.
assert(overlap > corner_min,
       "overlap is under corner_r*(1-1/sqrt(2)) - the rounded corners fall inside the aperture");
assert(plate_h >= gap_h + 2 * overlap - 0.01,
       "plate is shorter than the opening it must cover");

// Fasteners.
assert(edge_dist >= 1.35,
       "material outboard of the screw holes is under 3 perimeters (1.35 mm) as cut");
assert(web_side > 1.0,
       "web between the screw holes and the rear pocket is under 1.0 mm as cut");

// Centre opening.
assert(lip_t > 0 && lip_t < plate_t, "lip_t must be between 0 and plate_t");
assert(pw < bw && ph < bh, "lip must be smaller than the pocket, or there is no lip");
assert(lead_in < ((prot_face == "front") ? prot_t : 0) + lip_t,
       "lead_in eats through the protrusion and the whole lip");
assert(!bridge_slot || slot_n * layer_h < plate_t - lip_t,
       "the bridge slot is deeper than the space between lip and back face");
assert(pocket_d > 0, "no pocket left once the ledges are taken out");
assert(pocket_chamfer < pocket_d, "pocket chamfer is deeper than the pocket");

// Notches.
assert(notch_r == 0 || notch_r < plate_h / 2,
       "notch radius is at least half the plate height - it would cut the plate in two");
assert(notch_r == 0 || notch_vs_gap > 0.4,
       "Y-edge notch breaks through into the case opening - shrink notch_r or raise overlap");
assert(!notch_over_pocket || notch_web > 0.8,
       "Y-edge notch cuts into the rear pocket - shrink notch_r, offset notch_x, or raise overlap");
assert(notch_r == 0 || notch_screw_gap > 0.8,
       "Y-edge notch breaks into a screw hole - shrink notch_r or move notch_x");

// Protrusion.
assert(prot_face == "front" || prot_face == "back",
       "prot_face must be \"front\" or \"back\"");
assert(prot_t == 0 || (prot_w > pw && prot_h > ph),
       "protrusion is not bigger than the port opening - it would vanish");
assert(prot_t == 0 || (prot_w <= plate_w && prot_h <= plate_h),
       "protrusion is bigger than the plate it stands on");
assert(prot_t == 0 || prot_screw_gap > 0.4,
       "protrusion runs into the screw holes - narrow prot_w or widen screw_span");

// Layer alignment. Every internal transition should land on a layer boundary in
// the print orientation, or the ledge scheme resolves on a slicer tie-break.
assert(abs(plate_t / layer_h - round(plate_t / layer_h)) < 1e-6,
       "plate_t is not a whole number of layers - internal steps will land mid-layer");
assert(abs(lip_t / layer_h - round(lip_t / layer_h)) < 1e-6,
       "lip_t is not a whole number of layers");


// On the "back" branch the rear pocket and the protrusion occupy the same
// space, and the pocket is the larger of the two in Y (8.8 vs 6.1) — it eats
// the protrusion's middle and leaves two slivers. The part still renders as a
// valid manifold solid, which is exactly why this needs to be a guard.
assert(prot_t == 0 || prot_face != "back" || (prot_w > bw && prot_h > bh),
       "prot_face=\"back\": the rear pocket swallows the protrusion - it would print as two slivers");

// The two-bridge trick only helps if both stages are actually bridgeable.
// ~10 mm is the practical ceiling on a well-cooled machine (see
// docs/fdm-design-rules.md §3), and the slicer spans the SHORT axis, which is
// why stage 1 runs across bh and not bw.
assert(!bridge_slot || bridge_1 <= 10,
       "stage-1 bridge is over 10 mm - the strips will sag");
assert(!bridge_slot || bridge_2 <= 10,
       "stage-2 bridge is over 10 mm - the bands will sag onto the port");
assert(!bridge_slot || bh > ph,
       "bridge slot is not taller than the port - there is nothing to stage");
