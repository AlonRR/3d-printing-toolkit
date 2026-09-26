// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
flange-check.scad — the one measurement that decides whether this plate needs a lap.

The plate bolts to the CONNECTOR, never to the panel: the screws span 22.7 mm inside a 23.4 mm aperture, so both pass through open air. The panel is therefore held only by whatever is wider than the aperture on each side of it, and at overlap = 0 the plate is not. That leaves the connector's own flange, behind the panel, as the only candidate — and its size has never been measured.

SOLID lines are values the model already knows. DASHED lines and orange are the unknown: the flange outline, and the two dimensions A and B. Measure those two and the question resolves.

The section is cut through the HEIGHT deliberately. plate_h is gap_h + 2*overlap, which at overlap = 0 is exactly 15 — the same as the aperture — so that axis shows the plate edge landing precisely on the aperture edge with nothing to spare. Cutting through the width would be misleading: plate_w is pushed to 23.9 by the fastener floor, so it happens to carry 0.25 mm of lap that the design does not rely on and that vanishes the moment screw_style changes.

    openscad -o flange-check.png --imgsize=2200,1500 \
      --camera=19,-16,0,0,0,0,158 --projection=ortho flange-check.scad
*/

/* Include the BODY, not just the header: plate_w and plate_h are derived values and live there. draw_model = false after the include suppresses the part itself while keeping every variable — the same mechanism parameter-map.scad uses. */
include <usbc-panel-plate.scad>
include <draw2d.scad>
draw_model = false;

txt = 0.62;
lw  = 0.075;
ah  = 0.5;

C_KNOWN = [0.13, 0.13, 0.13];
C_ASK   = [0.85, 0.25, 0.05];
C_PANEL = [0.45, 0.50, 0.56];
C_PLATE = [0.55, 0.66, 0.82];
C_CONN  = [0.30, 0.30, 0.34];
C_GO    = [0.05, 0.45, 0.20];
C_NO    = [0.75, 0.10, 0.10];

/* A PLAUSIBLE flange, drawn only so the dashed outline has somewhere to be. It is NOT a measurement and nothing is derived from it. */
guess_w = 27.5;
guess_h = 18.5;
fl_t    = 2.0;

/* ===== FRONT VIEW ========================================================= */
heading("FRONT VIEW - looking at the case front, plate removed", [-17, 14.2], C_KNOWN);

color(C_PANEL) difference() {
    square([34, 24], center = true);
    square([gap_w, gap_h], center = true);
}
color(C_KNOWN) difference() {                      /* aperture edge */
    square([gap_w + 2 * lw, gap_h + 2 * lw], center = true);
    square([gap_w, gap_h], center = true);
}
color(C_CONN) for (s = [-1, 1]) translate([s * screw_span / 2, 0]) circle(d = screw_d);
color(C_CONN) difference() {                       /* the boss */
    square([boss_w, boss_h], center = true);
    square([boss_w - 1.3, boss_h - 1.3], center = true);
}
dashed_rect(guess_w, guess_h, C_ASK);              /* the flange - UNKNOWN */

dim_h(-gap_w / 2, gap_w / 2, -gap_h / 2 - 2.4, -gap_h / 2,
      str("aperture ", gap_w, "   (known)"), C_KNOWN, false);
dim_h(-guess_w / 2, guess_w / 2, -gap_h / 2 - 6.4, -guess_h / 2,
      "A = flange width = ?", C_ASK, false);
dim_v(-gap_h / 2, gap_h / 2, -gap_w / 2 - 2.2, -gap_w / 2,
      str("aperture ", gap_h), C_KNOWN, false);
dim_v(-guess_h / 2, guess_h / 2, gap_w / 2 + 9.6, guess_w / 2,
      "B = flange height = ?", C_ASK);

color(C_ASK) translate([-17, -17.4])
    text(str("MEASURE A AND B.    Is A > ", gap_w, " ?    Is B > ", gap_h, " ?"),
         size = txt * 1.3, font = "DejaVu Sans:style=Bold");

/* ===== SECTION, THROUGH THE HEIGHT ======================================== */
zs = 2.6;   /* depth exaggeration - the real sheet is 0.6 mm */
translate([0, -33.5]) {
    heading("SECTION through the HEIGHT - front of the case is UP", [-17, 11.7], C_KNOWN);

    color(C_PLATE) translate([-plate_h / 2, 0]) square([plate_h, zs * plate_t]);
    for (s = [-1, 1]) color(C_PANEL)               /* the sheet, aperture between */
        translate([s > 0 ? gap_h / 2 : -gap_h / 2 - 6.5, -zs * panel_t])
            square([6.5, zs * panel_t]);
    color(C_CONN) translate([-boss_h / 2, -zs * panel_t])   /* boss, up through */
        square([boss_h, zs * (panel_t + pocket_d)]);
    color(C_ASK, 0.16) translate([-guess_h / 2, -zs * (panel_t + fl_t)])
        square([guess_h, zs * fl_t]);              /* flange body, unknown width */
    dashed_rect_at(guess_h, zs * fl_t, [0, -zs * (panel_t + fl_t / 2)], C_ASK);

    color(C_PLATE) translate([-plate_h / 2 - 0.8, zs * plate_t * 0.28])
        text("plate", size = txt, halign = "right");
    color(C_PANEL) translate([-gap_h / 2 - 7.2, -zs * panel_t - 0.35])
        text("case sheet", size = txt, halign = "right");
    color(C_ASK) translate([-guess_h / 2, -zs * (panel_t + fl_t) - 1.7])
        text("connector flange - height B unknown", size = txt);

    /* the whole point: the plate edge lands exactly on the aperture edge */
    color(C_NO) {
        translate([gap_h / 2, zs * plate_t + 0.5]) square([lw * 2.4, 2.2]);
        translate([gap_h / 2 + 0.9, zs * plate_t + 2.9])
            text(str("plate height ", plate_h, " = aperture ", gap_h,
                     "   ->   zero lap, both edges"), size = txt * 0.95,
                 font = "DejaVu Sans:style=Bold");
    }

    translate([13.2, 0]) {
        color(C_GO) {
            translate([0, 1.4]) square([lw * 3, 3.2]);
            arrow_at([lw * 1.5, 5.4], 270, C_GO);
            translate([1.3, 3.6]) text("PULL OUT", size = txt, font = "DejaVu Sans:style=Bold");
            translate([1.3, 2.5]) text("stopped by the flange", size = txt * 0.9);
            translate([1.3, 1.5]) text("-- but only IF A > 23.4 and B > 15", size = txt * 0.9);
        }
        color(C_NO) {
            translate([0, -5.4]) square([lw * 3, 3.2]);
            arrow_at([lw * 1.5, -5.9], 90, C_NO);
            translate([1.3, -3.6]) text("PUSH IN", size = txt, font = "DejaVu Sans:style=Bold");
            translate([1.3, -4.7]) text("nothing stops this at overlap = 0", size = txt * 0.9);
            translate([1.3, -5.7]) text("-- and it is the direction a plug loads it", size = txt * 0.9);
        }
    }
    color(C_KNOWN) translate([-17, -12.0])
        text(str("depth exaggerated x", zs, "  --  the sheet is only ", panel_t, " mm thick"),
             size = txt * 0.9);
}

/* ===== WHAT THE ANSWER MEANS ============================================== */
translate([25.5, 12.0]) {
    heading("WHAT EACH ANSWER MEANS", [0, 2.6], C_KNOWN);
    rows = [
        [C_GO, "A > 23.4  AND  B > 15"],
        [C_KNOWN, "   The flange catches the sheet all the way round."],
        [C_KNOWN, "   Pull-out is handled. Only push-in is unresisted,"],
        [C_KNOWN, "   and the screws into the connector may well be"],
        [C_KNOWN, "   enough on their own. overlap = 0 stands."],
        [C_KNOWN, ""],
        [C_NO, "A < 23.4  OR  B < 15"],
        [C_KNOWN, "   The flange passes through the aperture on that"],
        [C_KNOWN, "   axis. NOTHING retains the assembly, either"],
        [C_KNOWN, "   direction. It needs a lap on that axis, an"],
        [C_KNOWN, "   interference fit, or adhesive."]
    ];
    for (i = [0 : len(rows) - 1])
        color(rows[i][0]) translate([0, -i * txt * 1.72])
            text(rows[i][1], size = txt * 1.0, font = "DejaVu Sans Mono");
}
