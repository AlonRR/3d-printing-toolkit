// ---------------------------------------------------------------------------
// USB-C panel plate — a rectangle with three holes.
//
//   centre  : two-level opening — a thin lip at the front sized to the PORT,
//             opening out behind into a relief pocket for the connector's boss
//   2 sides : screw holes
//
// Fits the commodity IP67-style panel-mount USB-C feedthrough (the moulded
// black flange with a raised rounded-rect boss and one screw hole each side).
//
// ORIENTATION: z = 0 is the FRONT face — the visible one, outside the case.
//              z = plate_t is the BACK, facing the connector.
//              Print FRONT FACE DOWN on the bed. See "Printing" below.
// ---------------------------------------------------------------------------

/* [The opening in the case panel — what the plate has to cover] */
gap_w   = 23.4;     // MEASURED. Width of the opening.
gap_h   = 15.0;     // MEASURED. Height of the opening.
panel_t = 0.6;      // MEASURED. Sheet thickness of the case panel.
overlap = 0.2;      // how far the plate laps onto the panel, all the way round

/* [Plate outline — derived, don't set these directly] */
// The plate must cover the opening, AND be wide enough to keep both screw
// holes inside its own edge. The screws span 22.70 mm outer-to-outer, so
// anything narrower than that plus a margin breaks out of the side.
screw_envelope = 22.70;                 // measured, outer edge to outer edge
min_w = screw_envelope;// + 2 * 1;       // + 1.5 mm of material outboard
plate_w = max(gap_w + 2 * overlap, min_w);
plate_h = gap_h + 2 * overlap;

plate_t  = 2.5;     // thickness
corner_r = 1.5;     // rounding on the outline corners

/* [Centre opening — front lip, sized to the PORT] */
// This is the hole you actually see. It closes right down around the USB-C
// receptacle so there is no open gap around it.
// USB-C receptacle shell is 8.94 x 3.16 mm, fixed by the USB spec; the plug's
// metal tongue is 8.34 x 2.56 and passes through easily at this size.
port_w  = 9.3;      // Set to hug the 8.94 mm receptacle shell with ~0.18 mm a
                    // side. Clears the 8.34 mm plug tongue with room, so the
                    // earlier "could be too narrow for a cable" risk is gone.
port_h  = 3.6;      // Ditto against the 3.16 mm shell height.
port_r  = 2.0;      // clamped to a stadium shape by rrect2d()
lip_t   = 0.8;      // thickness of the thin front lip. The rest of plate_t is
                    // relief pocket behind it.
lead_in = 0.5;      // 45 deg chamfer on the front face, guides a plug in and
                    // fights elephant's foot. Set to 0 for a square edge.

/* [Centre opening — rear relief, clears the connector's BOSS] */
// The connector's raised rounded-rect boss nests into this pocket so the plate
// can still sit flat on the panel.
boss_w = 13.4;      // <<CONFIRM>> width NOT yet measured, still photo-scaled
boss_h = 8.0;       // MEASURED. Height of the connector's raised boss.
boss_r = 2.0;

/* [Raised rectangle protrusion] */
// A rectangular boss standing proud of the plate, with the port opening
// running through it. MEASURED 14.7 x 6.1.
prot_w = 14.7;      // MEASURED
prot_h = 6.1;       // MEASURED
prot_t = 1.5;       // <<CONFIRM>> how far it stands proud. NOT measured.
prot_r = 1.5;       // corner rounding
prot_face = "front";  // "front" = the visible side (-Z), "back" = toward the
                      // connector (+Z). See the note in "Printing".

/* [Half-circle notches in the Y edges] */
// Semicircular cutouts bitten out of the top and bottom edges.
notch_r = 2.5;      // radius. Set to 0 to remove them.
notch_x = 0;        // X offset from centre. Both notches share it, so a
                    // non-zero value shifts the pair together; use
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
cbore_h    = 1.2;   // counterbore depth

/* [Pocket -> lip transition] */
// Two straight ledges, one layer each, giving the pocket ceiling something to
// bridge from instead of reaching the whole way off the lip.
//   layer 1 : the same rounded slot, grown in Y only
//   layer 2 : a plain rectangle -- square corners take out the slot's rounding
step    = 0.2;      // step out per side, per ledge. 0 = no ledges
layer_h = 0.2;      // must match the slicer, or a ledge lands mid-layer

/* [Printing] */
flip_for_print = true;  // rotate 180 about X so the BACK face sits on the bed.
                        // Set false to work in design orientation (front at
                        // z = 0), which is what all the comments describe.
hole_comp = 0.15;   // Printed holes come out undersize (extrusion width + the
                    // arc effect). Every hole is grown by this on each side.
                    // MK3S+ / 0.4 nozzle: 0.15 is a good starting point.
$fn = 64;

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

// Tapered opening, WIDE at z = 0 and narrowing to nominal at z = lead.
// Printed front-face-down this is a 45 deg overhang, which prints cleanly.
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
    pw = port_w + 2 * hole_comp;
    ph = port_h + 2 * hole_comp;
    bw = boss_w + 2 * hole_comp;
    bh = boss_h + 2 * hole_comp;
    sd = screw_d + 2 * hole_comp;

    // With a front protrusion the visible face moves out to -prot_t, so every
    // cut has to start beyond it rather than at the old z = 0.
    pt = (prot_face == "front") ? prot_t : 0;
    front_z = -pt;
    cut_lo = front_z - 1;
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

        // Front lip opening — runs the full depth, through the protrusion too;
        // the rear pocket below then opens it out from lip_t upward.
        translate([0, 0, cut_lo])
            rrect(pw, ph, cut_len, port_r);

        // Two ledges, one layer each, working outward from the lip.
        if (step > 0) {
            // Layer 1 - the same rounded slot, grown in Y only.
            translate([0, 0, lip_t])
                linear_extrude(plate_t)
                    rrect2d(pw, ph + 2 * step, port_r);

            // Layer 2 - a plain rectangle. The square corners are what take
            // out the slot's rounded ends before the ceiling closes over it.
            translate([0, 0, lip_t + layer_h])
                linear_extrude(plate_t)
                    square([pw + 2 * step, ph + 2 * step], center = true);
        }

        // Rear relief pocket for the connector's raised boss, above the ledges.
        translate([0, 0, lip_t + (step > 0 ? 2 * layer_h : 0)])
            rrect(bw, bh, plate_t, boss_r);

        // Lead-in chamfer, on whichever face is now the outermost one.
        if (lead_in > 0)
            translate([0, 0, front_z - 0.01])
                chamfer_flare_down(pw, ph, port_r, lead_in);

        // Half-circle cutouts in the top and bottom (Y) edges. The cylinder is
        // centred ON the edge, so exactly half of it lands inside the plate.
        // Cut through the protrusion too, so it does not leave a stub behind.
        if (notch_r > 0)
            for (s = [-1, 1])
                translate([notch_mirror ? s * notch_x : notch_x,
                           s * plate_h / 2,
                           cut_lo])
                    cylinder(h = cut_len, r = notch_r + hole_comp);

        // Screw holes.
        for (s = [-1, 1]) {
            translate([s * screw_span / 2, 0, cut_lo])
                cylinder(h = cut_len, d = sd);

            if (cbore_d > 0)
                translate([s * screw_span / 2, 0, front_z - 0.01])
                    cylinder(h = cbore_h, d = cbore_d + 2 * hole_comp);
        }
    }
}

// Rotate 180 about X so the BACK face lands on the bed. That is the
// orientation this actually prints in, so the STL now arrives already
// oriented instead of needing a flip in the slicer.
// The part spans -prot_t .. plate_t before rotation, so lifting by plate_t
// puts its lowest point back on z = 0.
if (flip_for_print)
    translate([0, 0, plate_t])
        rotate([180, 0, 0])
            usbc_panel_plate();
else
    usbc_panel_plate();

// --- sanity check -----------------------------------------------------------
pocket_d = plate_t - lip_t;
web_side = (screw_span - screw_d) / 2 - boss_w / 2;
web_topbot = (plate_h - boss_h) / 2;

echo(str("plate              : ", plate_w, " x ", plate_h, " x ", plate_t, " mm"));
echo(str("covers opening     : ", gap_w, " x ", gap_h, " mm, lap ", overlap, " mm"));
echo(str("front lip          : ", port_w, " x ", port_h, " mm, ", lip_t, " mm thick"));
echo(str("rear pocket        : ", boss_w, " x ", boss_h, " mm, ", pocket_d, " mm deep"));
// How far the pocket ceiling has to reach inward, and how that reach is split.
// The governing axis is whichever of X/Y needs the bigger jump.
echo(str("ceiling reach      : X ", (boss_w - port_w) / 2,
         " mm, Y ", (boss_h - port_h) / 2, " mm"));
echo(str("ledges             : ", step, " mm/side, ", layer_h,
         " mm tall each -- L1 slot (y only), L2 rectangle"));
echo(str("max boss height    : ", pocket_d + panel_t,
         " mm from the connector flange (pocket ", pocket_d,
         " + panel ", panel_t, ")"));
echo(str("web beside pocket  : ", web_side, " mm"));
echo(str("web above/below    : ", web_topbot, " mm"));
echo(str("outboard of screw  : ", (plate_w - screw_span - screw_d) / 2, " mm"));

// The raised rectangle. Its own frame around the port is the thing most likely
// to come out too thin, because prot_h and port_h are close together.
if (prot_t > 0) {
    prot_frame_x = (prot_w - port_w) / 2;
    prot_frame_y = (prot_h - port_h) / 2;
    prot_screw_gap = screw_span / 2 - screw_d / 2 - prot_w / 2;
    echo(str("protrusion         : ", prot_w, " x ", prot_h, " x ", prot_t,
             " mm on the ", prot_face));
    echo(str("  frame beside port: ", prot_frame_x, " mm"));
    echo(str("  frame over/under : ", prot_frame_y, " mm"));
    echo(str("  prot -> screw    : ", prot_screw_gap, " mm"));
}

// The Y-edge notches eat into the same web that sits above and below the rear
// pocket, so they are only safe while that web has material to spare.
notch_over_pocket = notch_r > 0 && abs(notch_x) < boss_w / 2 + notch_r;
notch_web = plate_h / 2 - notch_r - boss_h / 2;
notch_dx = abs(abs(notch_x) - screw_span / 2);
notch_screw_gap = sqrt(notch_dx * notch_dx + (plate_h / 2) * (plate_h / 2))
                  - notch_r - screw_d / 2;
if (notch_r > 0) {
    echo(str("notch              : r ", notch_r, " mm on both Y edges at x = ",
             notch_x, notch_mirror ? " (mirrored)" : ""));
    echo(str("  notch -> pocket  : ",
             notch_over_pocket ? str(notch_web, " mm")
                               : "clear in X, does not overlap the pocket"));
    echo(str("  notch -> screw   : ", notch_screw_gap, " mm"));
    // Does the notch stay inside the lap, or bite through into the case
    // opening? Positive = still covered plate. Negative = the notch opens a
    // hole straight into the case at that point.
    notch_vs_gap = plate_h / 2 - notch_r - gap_h / 2;
    echo(str("  notch vs opening : ", notch_vs_gap, " mm ",
             notch_vs_gap >= 0
               ? "(stays within the lap)"
               : "(BREAKS THROUGH into the case opening)"));
}

// Do the screw holes land on panel material, or over the opening?
// If the screw envelope is narrower than the opening, the screws pass through
// open air. The plate is then clamped to the CONNECTOR, not bolted to the
// panel, and the sheet metal is trapped between the plate's lap and the
// connector's flange. That still works, but it means the lap is doing all the
// retention -- so don't shrink `overlap` in that case.
screws_over_air = screw_envelope < gap_w;
echo(str("screws land on     : ",
         screws_over_air ? "OPEN AIR - plate clamps to the connector, panel trapped by the lap"
                         : "panel material - plate bolts through the panel"));

assert(screw_span / 2 - screw_d / 2 > boss_w / 2,
       "screw holes overlap the rear relief pocket - widen screw_span or narrow boss_w");
assert(plate_w >= gap_w + 2 * overlap - 0.01,
       "plate is narrower than the opening it must cover");
assert(lip_t > 0 && lip_t < plate_t,
       "lip_t must be between 0 and plate_t");
assert(port_w < boss_w && port_h < boss_h,
       "front lip must be smaller than the rear pocket, or there is no lip");
assert(lead_in < lip_t,
       "lead_in eats the whole lip - reduce lead_in or raise lip_t");
assert(notch_r == 0 || notch_r < plate_h / 2,
       "notch radius is at least half the plate height - it would cut the plate in two");
assert(!notch_over_pocket || notch_web > 0.8,
       "Y-edge notch cuts into the rear pocket - shrink notch_r, offset notch_x, or raise overlap");
assert(notch_r == 0 || notch_screw_gap > 0.8,
       "Y-edge notch breaks into a screw hole - shrink notch_r or move notch_x");
assert(prot_face == "front" || prot_face == "back",
       "prot_face must be \"front\" or \"back\"");
assert(prot_t == 0 || (prot_w > port_w && prot_h > port_h),
       "protrusion is not bigger than the port opening - it would vanish");
assert(prot_t == 0 || (prot_w <= plate_w && prot_h <= plate_h),
       "protrusion is bigger than the plate it stands on");
assert(prot_t == 0 || screw_span / 2 - screw_d / 2 - prot_w / 2 > 0.4,
       "protrusion runs into the screw holes - narrow prot_w or widen screw_span");
assert(step == 0 || 2 * layer_h < pocket_d,
       "the two ledges are deeper than the pocket - reduce layer_h or raise plate_t");
