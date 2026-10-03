// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
Assembly views of the print-chamber box, for docs/assembly.md and docs/wiring.md.

  view = "exploded"   every part, moved apart along the way it goes in: the nuts from the wall side, the
                      SuperMini from the front and along to its stops, the SGP41 and its screw from the side,
                      the SPS30, the cover and its screws from the front.
  view = "open"       assembled with the cover off, and the wiring table beside it. The wires' routes are
                      not drawn yet (Alon, 3 Oct 2026: "Let's first get the layout right").

It includes the model, so every part sits where the model puts it.

    openscad -o docs/assembly-exploded.png -D 'view="exploded"' --imgsize=1800,1500 --projection=o --viewall \
      --autocenter --camera=33,80,38,68,0,252,560 --colorscheme=Tomorrow assembly-views.scad
    openscad -o docs/assembly-open.png -D 'view="open"' --imgsize=1800,1500 --projection=o --viewall \
      --autocenter --camera=33,0,38,78,0,195,260 --colorscheme=Tomorrow assembly-views.scad

draw_model = false MUST come after the include: the last assignment in a scope wins.
*/
include <print-chamber-box.scad>
use <../lib/axes.scad>
draw_model = false;

view = "open";   // "exploded" or "open"

// ------------------------------------------------------------------ the parts, as drawn here
module sps30() {
    color("silver") box3([sps_x0, back_t, z_sps0], [sps_x1, back_t + sps_t, z_sps1]);
    // its plug, on the connector face at the outlet end
    color([0.15, 0.15, 0.15]) box3([lead_x0, back_t + sps_t / 2 - 2.5, z_sps1], [lead_x1, back_t + sps_t / 2 + 2.5, z_sps1 + 3.5]);
}
module supermini() for (i = [0 : 4]) sm_piece(i, 0);

gy_pcb_nom = 1.2;                                   // a GY board, for the picture only
module sgp41() {
    // the PCB, on edge against its standoff, pins up
    color([0.15, 0.55, 0.25]) box3([gy_xs, gy_y0 + pocket_fit, gy_z0], [gy_xs + gy_pcb_nom, gy_y1 + pocket_fit, gy_z1]);
    // the parts on its underside, away from the bare patch round the hole
    color([0.12, 0.12, 0.12]) box3([gy_xs - (gy_back - gy_pcb_nom), gy_y0 + 4.5, gy_z0 + gy_bare + 0.5],
                                   [gy_xs, gy_y1 - 0.8, gy_z1 - 2.6]);
    // the sensor, on its face at the far end, by the long edge away from the hole
    color([0.75, 0.75, 0.70]) box3([gy_xs + gy_pcb_nom, gy_y1 + pocket_fit - 3.94, gy_z0 + 1.5],
                                   [gy_xs + gy_pcb_nom + gy_sensor_h, gy_y1 + pocket_fit - 1.5, gy_z0 + 3.94]);
    // its four pins, along the top edge
    for (i = [0 : 3]) color([0.8, 0.7, 0.2])
        box3([gy_xs - 0.5, gy_y0 + pocket_fit + 1.5 + i * 2.54 - 0.3, gy_z1 - 1.2],
             [gy_xs + gy_pcb_nom + 0.5, gy_y0 + pocket_fit + 1.5 + i * 2.54 + 0.3, gy_z1 + 2]);
}
module m25() color([0.55, 0.55, 0.60]) {   // head on the module's face, shank sideways into the standoff
    cyl_x(gy_hy, gy_hz, gy_head_d / 2, gy_xs + gy_pcb_nom, gy_xs + gy_pcb_nom + gy_head_h);
    cyl_x(gy_hy, gy_hz, gy_screw_d / 2, gy_xs + gy_pcb_nom + gy_head_h - gy_screw_l, gy_xs + gy_pcb_nom);
}
module nuts() for (x = nut_bx) color([0.55, 0.55, 0.60])
    translate([x, nut_y1 - nut_h, nut_bz]) rotate([-90, 0, 0]) rotate([0, 0, 30]) cylinder(d = nut_ac, h = nut_h, $fn = 6);
module m3s() for (x = nut_bx) color([0.55, 0.55, 0.60]) {   // head on the cover's face, shank back into -Y
    cyl_y(x, nut_bz, 2.75, D, D + 3);
    cyl_y(x, nut_bz, 1.5, D - cover_screw_l, D);
}

// ------------------------------------------------------------------ text and guide lines
// labels face the camera: flat text turned by the camera's own angles
module label(t, p, cam, size = 4.0) translate(p) rotate(cam) color("black")
    linear_extrude(0.4) text(t, size = size, halign = "center", valign = "center");
module guide(a, b) color([0.6, 0.6, 0.6]) hull() { translate(a) sphere(d = 0.5, $fn = 8); translate(b) sphere(d = 0.5, $fn = 8); }

// ------------------------------------------------------------------ the views
if (view == "open") {
    cam = [78, 0, 195];
    color([0.80, 0.72, 0.58]) back_plate();
    sps30(); supermini(); sgp41(); m25(); nuts();
    axes([-22, 0, -25], 20, cam, [[0, 0], [1.7, -0.3], [0, 0]]);
    translate([-18, 0, H + 34]) rotate([90, 0, 180]) color("black") linear_extrude(0.4) {
        lines = ["OPEN - as you face the box, cover off",
                 "",
                 "SPS30 black   VDD  ->  5V",
                 "SPS30 orange  GND  ->  GND",
                 "SPS30 yellow  SEL  ->  GND",
                 "SPS30 red     SDA  ->  GPIO5",
                 "SPS30 white   SCL  ->  GPIO6",
                 "SGP41 VIN  ->  3V3",
                 "SGP41 GND  ->  GND",
                 "SGP41 SDA  ->  GPIO5",
                 "SGP41 SCL  ->  GPIO6",
                 "",
                 "the wires' routes are not drawn yet"];
        for (i = [0 : len(lines) - 1]) translate([0, -i * 5.2]) text(lines[i], size = 3.0);
    }
}

if (view == "exploded") {
    cam = [68, 0, 252];
    color([0.80, 0.72, 0.58]) back_plate();
    e_nut = -18; e_sm = 72; e_sps = 40; e_gy = 22; e_m25 = 36; e_cov = 105; e_m3 = 150;   // how far out each one goes
    dx_sm = -(sm_back_lip + gap);
    translate([0, e_nut, 0]) nuts();
    translate([dx_sm, e_sm, 0]) supermini();
    translate([0, e_sps, 0]) sps30();
    translate([e_gy, 0, 0]) sgp41();
    translate([e_m25, 0, 0]) m25();
    translate([0, e_cov, 0]) color([0.62, 0.72, 0.85]) cover();
    translate([0, e_m3, 0]) m3s();
    // the way each one goes in
    for (x = nut_bx) guide([x, e_nut + nut_y1, nut_bz], [x, nut_y1 - nut_h, nut_bz]);
    guide([sm_x0 + sm_l / 2 + dx_sm, y_bc + e_sm, zu], [sm_x0 + sm_l / 2 + dx_sm, y_bc, zu]);
    guide([sm_x0 + sm_l / 2 + dx_sm, y_bc, zu - 0.5], [sm_x0 + sm_l / 2, y_bc, zu - 0.5]);
    guide([(sps_x0 + sps_x1) / 2, back_t + e_sps, (z_sps0 + z_sps1) / 2], [(sps_x0 + sps_x1) / 2, back_t, (z_sps0 + z_sps1) / 2]);
    guide([gy_xs + e_m25, gy_hy, gy_hz], [gy_xs, gy_hy, gy_hz]);
    for (x = nut_bx) guide([x, D + e_m3, nut_bz], [x, y_in1, nut_bz]);
    label("back plate",                            [W / 2, 0, H + 12], cam);
    label("2 x M3 nut, from the back",             [W / 2, e_nut, -16], cam, 3.2);
    label("SuperMini - onto its shelf, then along", [sm_x0 + dx_sm + sm_l / 2, y_bc + e_sm, zu + ant_h + 6], cam, 3.2);
    label("SPS30 - in from the front",             [(sps_x0 + sps_x1) / 2, back_t + e_sps + sps_t, z_sps0 - 12], cam, 3.2);
    label("cover - its top on two pins",           [W / 2, D + e_cov, -14], cam, 3.2);
    label("2 x M3 x 20",                           [W / 2, D + e_m3, nut_bz + 16], cam, 3.2);
    axes([W, 0, -80], 25, cam, [[-1, 0], [0, 0], [0, 0]]);
}
