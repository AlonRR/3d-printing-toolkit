// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
Parameter map for usbc-panel-plate.scad

A DIMENSIONED drawing, not a callout drawing. Every measurement is shown as a proper dimension line — extension lines out to the feature, arrowheads at both ends, the parameter name and its live value on the line — so it is never ambiguous WHAT is being measured, or BETWEEN WHICH TWO EDGES.

A numbered dot can only say "this feature"; a dimension line says "this distance, from here to here". That is why every measurable span here gets a dimension line, and a leader is used only for the two things that are genuinely features rather than spans.

Colour groups the measurements by what they belong to, and the key is bottom left.

Prior art: Don Smiley's OpenSCAD dimensioned-drawings library has exactly these modules — dimensions, leader_line, arrow, titleblock — but it is unmaintained and depends on a font from Thingiverse that predates native text(). BOSL2 offers stroke() with arrowheads, which is the primitive rather than the system. Conventions taken from both, implemented natively so this file has no dependencies.

The point is that it cannot drift: it INCLUDES the model rather than restating it, so every outline and every number is whatever the model currently says. Edit a parameter, re-render, and the map is correct again.

    openscad -o parameter-map.png --imgsize=2200,1560 \
      --camera=6,-17,0,0,0,0,205 --projection=ortho parameter-map.scad

draw_model = false MUST come after the include — in OpenSCAD the last assignment in a scope wins, so this suppresses the part while keeping all of its variables.
*/

include <usbc-panel-plate.scad>
draw_model = false;

include <draw2d.scad>

/* Where the two views sit, and the Z exaggeration on the section. */
sec_y = -60.0;
zs    = 3.0;

/* ===== PLAN ================================================================ */
/*
Dimensions sit on a LADDER — each one gets its own offset from the part, so none can land on another. Innermost measurements go closest; the overall outline goes furthest out. That ordering is the drafting convention and it is also what keeps this readable as parameters get added.
*/
color(C_PART) projection() usbc_panel_plate();
heading("PLAN — the visible face", [-plate_w / 2, plate_h / 2 + 9.4]);

/* --- above (rungs at +12.0, +15.4) */
dim_h(-prot_w / 2, prot_w / 2, plate_h / 2 + 2.0, prot_h / 2,
      str("prot_w ", prot_w), C_PORT);
dim_h(-screw_span / 2, screw_span / 2, plate_h / 2 + 5.6, sd / 2,
      str("screw_span ", screw_span), C_FIX);

/* --- below (rungs at -13.0, -16.4, -19.8) */
dim_h(-pw / 2, pw / 2, -plate_h / 2 - 3.0, -ph / 2,
      str("port_w ", port_w), C_PORT, false);
dim_h(-bw / 2, bw / 2, -plate_h / 2 - 6.4, -bh / 2,
      str("boss_w ", boss_w, " (", bw, " as cut)"), C_POCK, false);
dim_h(-plate_w / 2, plate_w / 2, -plate_h / 2 - 9.8, -plate_h / 2,
      str("plate_w ", plate_w), C_OUT, false);

/* --- right (rungs at +16.2, +20.4, +25.2) */
dim_v(-prot_h / 2, prot_h / 2, plate_w / 2 + 2.0, prot_w / 2,
      str("prot_h ", prot_h), C_PORT);
dim_v(-plate_h / 2, plate_h / 2, plate_w / 2 + 9.0, plate_w / 2,
      str("plate_h ", plate_h), C_OUT);
dim_v(gap_h / 2, plate_h / 2, plate_w / 2 + 16.0, plate_w / 2 - 1.0,
      str("overlap ", overlap), C_OUT);

/* --- left (rungs at -16.2, -21.0) */
dim_v(-ph / 2, ph / 2, -plate_w / 2 - 2.0, -pw / 2,
      str("port_h ", port_h), C_PORT, false);
dim_v(-bh / 2, bh / 2, -plate_w / 2 - 10.0, -bw / 2,
      str("boss_h ", boss_h), C_POCK, false);

/* features rather than spans */
leader([-plate_w / 2 - 3.0, 7.4], [-screw_span / 2 - sd / 2, 0],
       str("screw_d ", screw_d), C_FIX);
leader([plate_w / 2 + 3.0, -7.6], [notch_x, -plate_h / 2 + nr],
       str("notch_r ", notch_r), C_OUT);

translate([0, 0]) { axis("X", 0, 2.6, C_OUT); axis("Y", 90, 2.6, C_OUT); }

/* ===== SECTION ============================================================= */
translate([0, sec_y]) {
    heading("SECTION — print orientation, bed at the bottom", [-plate_w / 2, zs * 4.4]);
    /*
    Section the PRINT-ORIENTED assembly, not the raw module. usbc_panel_plate() is authored front-at-z-0 with the protrusion at NEGATIVE z, so sectioning it directly draws the protrusion below the plate — design orientation, under a heading that says print orientation. Applying the same flip the export does puts the bed at y = 0 and everything above it, which is what the dimensions below already assume.
    */
    scale([1, zs]) color(C_PART)
        projection(cut = true) rotate([-90, 0, 0])
            translate([0, 0, top_z]) rotate([180, 0, 0]) usbc_panel_plate();

    /* right ladder */
    dim_v(zs * (plate_t - lip_t), zs * plate_t, plate_w / 2 + 2.0, pw / 2,
          str("lip_t ", lip_t), C_PORT);
    dim_v(zs * plate_t, zs * (plate_t + prot_t), plate_w / 2 + 9.0, prot_w / 2,
          str("prot_t ", prot_t), C_PORT);
    dim_v(0, zs * pocket_d, plate_w / 2 + 16.0, bw / 2,
          str("pocket_d ", pocket_d), C_POCK);

    /*
    left ladder — plate_t furthest out, the three staged layers stepping in. They are the reason the section is exaggerated at all: at true scale three 0.2 mm layers are one pixel.
    */
    dim_v(0, zs * plate_t, -plate_w / 2 - 16.0, -plate_w / 2,
          str("plate_t ", plate_t), C_OUT, false);
    for (i = [0 : 2]) {
        zlo = zs * (pocket_d + i * fdm_layer_h);
        nm  = ["L1", "L2", "L3"][i]; /* spelled out in the key */
        dim_v(zlo, zlo + zs * fdm_layer_h, -plate_w / 2 - 2.0 - i * 4.0,
              -bw / 2, str(nm, " ", fdm_layer_h), C_STAGE, false);
    }

    axis("X", 0, 3.0, C_OUT);
    axis("Z", 90, 3.0, C_OUT);
    color(C_OUT) translate([-3.4, -2.6])
        text(str("Z exaggerated x", zs), size = txt * 0.9);
}

/* ===== KEY ================================================================= */
translate([-plate_w / 2 - 15.0, sec_y - 8.0]) {
    heading("COLOUR KEY", [0, 2.2]);
    keys = [[C_OUT, "plate outline"], [C_PORT, "port opening / raised rect"],
            [C_FIX, "fasteners"], [C_POCK, "rear pocket (behind the face)"],
            [C_STAGE, "staged bridge layers"]];
    for (i = [0 : len(keys) - 1])
        translate([0, -i * txt * 1.7]) {
            color(keys[i][0]) square([2.2, lw * 3]);
            color(keys[i][0]) translate([2.8, -txt * 0.34])
                text(keys[i][1], size = txt);
        }
}

/* Facts with no place on a drawing. */
translate([9.0, sec_y - 8.0]) {
    heading("NOT DIMENSIONABLE — but they change the geometry", [0, 2.2]);
    notes = [
        str("fdm_layer_h = ", fdm_layer_h, "   fdm_extrusion_w = ",
            fdm_extrusion_w, "   fdm_hole_comp = ", fdm_hole_comp,
            "   — mirror these from the slicer profile"),
        str("as cut:  port ", pw, " x ", ph, "   pocket ", bw, " x ", bh,
            "   screw ", sd, "   notch r", nr),
        str("boss_clear = ", boss_clear,
            "   real fit clearance, on top of fdm_hole_comp"),
        str("flip_for_print = ", flip_for_print ? "true" : "false",
            "   exports BACK FACE DOWN — do not flip again in the slicer")
    ];
    for (i = [0 : len(notes) - 1])
        color(C_OUT) translate([0, -i * txt * 1.7 - txt * 0.34])
            text(notes[i], size = txt * 0.95);
}
