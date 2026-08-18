// ---------------------------------------------------------------------------
// Parameter map for usbc-panel-plate.scad
//
// A numbered callout drawing: real outlines projected from the model, small
// numbered markers on each feature, and a legend giving every number's
// parameter NAME and its LIVE VALUE.
//
// The point is that it cannot drift. It includes the model rather than
// restating it, so every outline and every number here is whatever the model
// currently says. Edit a parameter, re-render, and the map is correct again.
//
//   openscad -o parameter-map.png --imgsize=1600,1100 \
//            --camera=0,0,0,0,0,0,64 --projection=ortho parameter-map.scad
//
// The `draw_model = false` below MUST come after the include -- in OpenSCAD
// the last assignment in a scope wins, so this suppresses the part while
// keeping all of its variables.
// ---------------------------------------------------------------------------

include <usbc-panel-plate.scad>
draw_model = false;

/* [Map layout] */
txt      = 0.85;    // legend text size
marker_r = 0.62;    // radius of a numbered callout marker
lead     = 0.09;    // line weight for leaders and outlines
col_x    = 20.5;    // where the legend column starts
sec_y    = -17.5;   // where the section view sits
zs       = 2.6;     // Z exaggeration on the section, and on its callouts

// A numbered marker with a leader back to the feature it points at.
module callout(n, at, from) {
    // Start the leader at the marker EDGE, not its centre. Drawn from
    // the centre it fills the ring, because 2D shapes here are coplanar
    // and cannot be masked by drawing over them.
    d = from - at;
    p = at + d * (marker_r / norm(d));
    color("black") {
        hull() {
            translate(p) circle(r = lead / 2);
            translate(from) circle(r = lead / 2);
        }
        translate(at) {
            difference() {
                circle(r = marker_r);
                circle(r = marker_r - lead);
            }
            translate([0, -txt * 0.42])
                text(str(n), size = txt * 0.95, halign = "center",
                     font = "DejaVu Sans:style=Bold");
        }
    }
}

// One legend row: number, parameter name, value, and what it means.
module legend_row(n, i, name, value, meaning) {
    y = -i * (txt * 1.72);
    translate([col_x, y]) {
        color("black") {
            translate([0, txt * 0.30]) {
                difference() {
                    circle(r = marker_r);
                    circle(r = marker_r - lead);
                }
                translate([0, -txt * 0.42])
                    text(str(n), size = txt * 0.95, halign = "center",
                         font = "DejaVu Sans:style=Bold");
            }
            translate([marker_r + 0.7, 0])
                text(str(name, " = ", value), size = txt,
                     font = "DejaVu Sans:style=Bold");
            translate([marker_r + 19.0, 0])
                text(meaning, size = txt * 0.92);
        }
    }
}

module heading(t, at) {
    color("black") translate(at)
        text(t, size = txt * 1.15, font = "DejaVu Sans:style=Bold");
}

// One labelled axis arrow. ang is measured CCW from +X.
module axis(label, ang, len) {
    color("black") rotate(ang) {
        translate([0, -lead / 2]) square([len - 0.8, lead]);
        translate([len - 0.8, 0]) polygon([[0, -0.34], [0, 0.34], [0.8, 0]]);
    }
    color("black")
        translate([cos(ang) * (len + 0.9) - txt * 0.35,
                   sin(ang) * (len + 0.9) - txt * 0.42])
            text(label, size = txt * 1.05, font = "DejaVu Sans:style=Bold");
}

// Axis triads. Which way Z points is the thing people get wrong on this part,
// because the model is AUTHORED front-at-z-0 and EXPORTED rotated — so the
// plan and the section do not share a Z direction, and saying so is the whole
// reason these are here.
module axes_plan(at) {
    translate(at) {
        axis("X", 0, 3.2);
        axis("Y", 90, 3.2);
        color("black") {
            circle(r = 0.42);
            translate([0.30, 0.30]) circle(r = 0.13);   // Z dot: out of the page
        }
        color("black") translate([-txt * 2.9, -txt * 1.9])
            text("Z out of page", size = txt * 0.8);
    }
}

module axes_section(at) {
    translate(at) {
        axis("X", 0, 3.2);
        axis("Z", 90, 3.2);
        color("black") translate([-txt * 3.4, -txt * 1.9])
            text("Y into page", size = txt * 0.8);
        color("black") translate([-txt * 3.4, -txt * 3.1])
            text(str("Z exaggerated x", zs), size = txt * 0.8);
    }
}

// --- plan view, projected straight off the model ----------------------------
// projection() of the real solid, so this outline is the part, not a sketch.
color([0.62, 0.72, 0.85])
    projection() usbc_panel_plate();

// No separate outline pass. Drawing one as offset(+) minus offset(-) filled
// the whole silhouette black, which hid every callout that sits ON the plate
// (5, 6 and 8). A flat fill in the same colour as the section is clearer and
// keeps the two views consistent.

heading("PLAN  (looking at the visible face)", [-plate_w / 2, plate_h / 2 + 1.4]);
axes_plan([-plate_w / 2 - 10.5, -plate_h / 2 + 1.0]);

// Callouts on the plan.
callout( 1, [-plate_w / 2 - 2.6,  plate_h / 2 + 0.6], [-plate_w / 2, plate_h / 2]);
callout( 2, [ plate_w / 2 + 2.6,  0                 ], [ plate_w / 2, 0]);
callout( 3, [ 0,                  plate_h / 2 + 2.6 ], [ 0, plate_h / 2]);
callout( 4, [ 0,                  0                 ], [ pw / 2, 0]);
// Markers must sit OFF the part. A 2D marker drawn on top of the plate is
// coplanar with it and renders as a solid disc instead of a numbered ring —
// and pointing in from outside is the drafting convention anyway.
callout( 5, [ plate_w / 2 + 2.6, -3.4               ], [ prot_w / 2, -prot_h / 2]);
callout( 6, [ screw_span / 2,     plate_h / 2 + 2.6 ], [ screw_span / 2, sd / 2]);
callout( 7, [ 0,                 -plate_h / 2 - 2.6 ], [ notch_x, -plate_h / 2 + nr]);
callout( 8, [-plate_w / 2 - 2.6, -3.4               ], [-bw / 2, -bh / 2]);

// --- section, cut through the middle ----------------------------------------
// projection(cut = true) on the rotated solid gives the true Z stack.
translate([0, sec_y]) {
    heading("SECTION  (cut on the long axis, print orientation)",
            [-plate_w / 2, 4.0]);
    axes_section([-plate_w / 2 - 10.5, -1.5]);

    // Z is exaggerated or the 0.2 mm layers are invisible next to a 28 mm
    // plate. The callouts must be scaled by the SAME factor or they point at
    // nothing — the drawing is stretched, the annotations are not.
    scale([1, zs])
        color([0.62, 0.72, 0.85])
            projection(cut = true) rotate([90, 0, 0]) usbc_panel_plate();

    callout( 9, [-plate_w / 2 - 3.2, zs * -1.0], [-plate_w / 2,       zs * -1.2]);
    callout(10, [ pw / 2 + 4.4,      zs *  2.3], [ pw / 2,            zs *  2.0]);
    callout(11, [ plate_w / 2 + 3.2, zs * -0.4], [ bw / 2,            zs * -0.6]);
    callout(12, [-plate_w / 2 - 3.2, zs *  3.4], [-pw / 2,            zs *  3.15]);
    callout(13, [-plate_w / 2 - 3.2, zs *  1.2], [-pw / 2,            zs *  1.5]);
}

// --- legend -----------------------------------------------------------------
heading("PLAN", [col_x, plate_h / 2 + 1.4]);
legend_row( 1,  1, "plate_w",  plate_w,  "overall width  (derived)");
legend_row( 2,  2, "plate_h",  plate_h,  "overall height  (derived)");
legend_row( 3,  3, "overlap",  overlap,  "lap onto the panel, all round");
legend_row( 4,  4, "port_w x port_h", str(port_w, " x ", port_h),
                                       "the hole you see  (as cut: pw x ph)");
legend_row( 5,  5, "prot_w x prot_h", str(prot_w, " x ", prot_h),
                                       "raised rectangle on the visible face");
legend_row( 6,  6, "screw_span", screw_span, "screw centres  (screw_d = hole)");
legend_row( 7,  7, "notch_r",  notch_r,  "half-circle bite in each Y edge");
legend_row( 8,  8, "boss_w x boss_h", str(boss_w, " x ", boss_h),
                                       "rear pocket, clears the connector boss");

translate([0, -9 * (txt * 1.72)]) {
    heading("SECTION", [col_x, 0]);
    legend_row( 9, 1, "plate_t",  plate_t,  "plate thickness");
    legend_row(10, 2, "lip_t",    lip_t,    "lip alone (port_recess = plug reach)");
    legend_row(11, 3, "pocket_d", pocket_d, "pocket depth left after the bridge slot");
    legend_row(12, 4, "prot_t",   prot_t,   "how far the rectangle stands proud");
    legend_row(13, 5, "bridge slot", str(pw, " x ", bh),
                                       "stage 1 of the two-bridge trick, fdm_layer_h tall");
}

// --- the ones with no place on a drawing ------------------------------------
translate([0, -16.4 * (txt * 1.72)]) {
    heading("NOT ON THE DRAWING — but they change the geometry", [col_x, 0]);
    translate([col_x, 0]) color("black") {
        translate([0, -txt * 1.9])
            text(str("fdm_hole_comp = ", fdm_hole_comp,
                     "   grows every CUT per side. Nominal vs as-cut:"),
                 size = txt * 0.92);
        translate([1.2, -txt * 3.5])
            text(str("port ", port_w, " x ", port_h, " -> ", pw, " x ", ph,
                     "     pocket ", boss_w, " x ", boss_h, " -> ", bw, " x ", bh,
                     "     screw ", screw_d, " -> ", sd),
                 size = txt * 0.92);
        translate([0, -txt * 5.4])
            text(str("boss_clear = ", boss_clear,
                     "   REAL fit clearance on the pocket, on top of fdm_hole_comp"),
                 size = txt * 0.92);
        translate([0, -txt * 7.0])
            text(str("fdm_layer_h = ", fdm_layer_h,
                     "   must match the slicer, or the stages land mid-layer"),
                 size = txt * 0.92);
        translate([0, -txt * 8.6])
            text(str("flip_for_print = ", flip_for_print ? "true" : "false",
                     "   exports BACK FACE DOWN -- do not flip again"),
                 size = txt * 0.92);
    }
}
