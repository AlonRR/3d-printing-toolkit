// ---------------------------------------------------------------------------
// USB-C panel plate — a rectangle with three holes.
//
//   centre  : opening for the USB-C connector
//   2 sides : screw holes
//
// Fits the commodity IP67-style panel-mount USB-C feedthrough (the moulded
// black flange with a raised rounded-rect boss and one screw hole each side).
//
// !! Every value tagged <<CONFIRM>> was scaled off a photograph, using the
// !! USB-C receptacle mouth (8.9 mm, fixed by the USB spec) as the ruler.
// !! They are good to roughly +/-10 %. Measure with calipers before printing —
// !! screw_span in particular is the one number that makes this bolt on or not.
// ---------------------------------------------------------------------------

/* [The opening in the case panel — what the plate has to cover] */
gap_w = 23.4;       // MEASURED.
gap_h = 15.0;       // MEASURED.
overlap = 2.5;      // how far the plate laps onto the panel, all the way round

/* [Plate outline — derived, don't set these directly] */
// The plate must cover the opening, AND be wide enough to keep both screw
// holes inside its own edge. The screws span 22.70 mm outer-to-outer, so
// anything narrower than that plus a margin breaks out of the side.
screw_envelope = 22.70;                 // measured, outer edge to outer edge
min_w = screw_envelope + 2 * 1.5;       // + 1.5 mm of material outboard
plate_w = max(gap_w + 2 * overlap, min_w);
plate_h = gap_h + 2 * overlap;

plate_t  = 2.5;     // thickness
corner_r = 1.5;     // rounding on the outline corners

/* [Centre opening] */
open_w  = 13.4;     // <<CONFIRM>> width  — clears the connector's raised boss
open_h  = 8.4;      // <<CONFIRM>> height — clears the connector's raised boss
open_r  = 2.0;      // rounding on the opening corners
lead_in = 0.6;      // 45 deg chamfer on the front face, guides a plug in.
                    // Set to 0 for a plain square-edged opening.

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
cbore_d    = 0;     // counterbore diameter, 0 = none. M2 socket head = 4.0
cbore_h    = 1.2;   // counterbore depth

/* [Printing] */
hole_comp = 0.15;   // Printed holes come out undersize (extrusion width + the
                    // arc effect). Every hole is grown by this on each side.
                    // MK3S+ / 0.4 nozzle: 0.15 is a good starting point.
$fn = 64;

// ---------------------------------------------------------------------------

// 2D rounded rectangle, centred on the origin.
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

// A tapered opening: `lead` tall, growing outward by `lead` toward +Z.
module chamfer_flare(w, h, r, lead) {
    hull() {
        linear_extrude(height = 0.01)
            rrect2d(w, h, r);
        translate([0, 0, lead])
            linear_extrude(height = 0.01)
                rrect2d(w + 2 * lead, h + 2 * lead, r + lead);
    }
}

module usbc_panel_plate() {
    ow = open_w + 2 * hole_comp;
    oh = open_h + 2 * hole_comp;
    sd = screw_d + 2 * hole_comp;

    difference() {
        rrect(plate_w, plate_h, plate_t, corner_r);

        // Centre opening, straight through.
        translate([0, 0, -1])
            rrect(ow, oh, plate_t + 2, open_r);

        // Lead-in chamfer on the front (+Z) face.
        if (lead_in > 0)
            translate([0, 0, plate_t - lead_in])
                chamfer_flare(ow, oh, open_r, lead_in + 0.01);

        // Screw holes.
        for (s = [-1, 1]) {
            translate([s * screw_span / 2, 0, -1])
                cylinder(h = plate_t + 2, d = sd);

            if (cbore_d > 0)
                translate([s * screw_span / 2, 0, plate_t - cbore_h])
                    cylinder(h = cbore_h + 1, d = cbore_d + 2 * hole_comp);
        }
    }
}

usbc_panel_plate();

// --- sanity check -----------------------------------------------------------
// Material left between the opening and each screw hole, and above/below the
// opening. Both want to be >= 1.2 mm (three perimeters at a 0.4 nozzle) or the
// plate snaps when you tighten the screws.
web_side = (screw_span - screw_d) / 2 - open_w / 2;
web_topbot = (plate_h - open_h) / 2;
echo(str("plate              : ", plate_w, " x ", plate_h, " x ", plate_t, " mm"));
echo(str("covers opening     : ", gap_w, " x ", gap_h, " mm, lap ", overlap, " mm"));
echo(str("web beside opening : ", web_side, " mm"));
echo(str("web above/below    : ", web_topbot, " mm"));
echo(str("outboard of screw  : ", (plate_w - screw_span - screw_d) / 2, " mm"));

// Do the screw holes land on panel material, or over the opening?
// If the screw envelope is narrower than the opening, the screws pass through
// open air. The plate is then clamped to the CONNECTOR, not bolted to the
// panel, and the sheet metal is trapped between the plate's lap and the
// connector's flange. That still works, but it means the lap is doing all the
// retention -- so don't shrink `overlap` in that case.
screws_over_air = screw_envelope < gap_w;
echo(str("screws land on    : ",
         screws_over_air ? "OPEN AIR - plate clamps to the connector, panel trapped by the lap"
                         : "panel material - plate bolts through the panel"));
echo(str("lap on the panel  : ", overlap, " mm all round"));

// The screw holes sit on the horizontal centreline, level with the opening.
// Check they clear it rather than merging into it.
assert(screw_span / 2 - screw_d / 2 > open_w / 2,
       "screw holes overlap the centre opening — widen screw_span or narrow open_w");
assert(plate_w >= gap_w + 2 * overlap - 0.01,
       "plate is narrower than the opening it must cover");
