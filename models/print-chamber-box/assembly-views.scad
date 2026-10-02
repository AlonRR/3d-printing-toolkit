// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
Assembly views of the print-chamber box, for README.md.

  view = "exploded"   every part, moved apart along the way it goes in: the SuperMini out to its USB-C side
                      (it slides in), the sensors, the screws and the cover out from the wall.
  view = "wiring"     assembled with the cover off, and every wire drawn along its route to its pin.

It includes the model, so every part sits where the model puts it. The wire routes are illustrative - a
wire bends where it likes - but each one ends on the pin the README's wiring table gives it, passes up
the cable channel, and keeps out of the SPS30 lead's column, the antenna and the air paths. The SPS30
lead's colours are the meter-checked ones; the SGP41's four are stand-ins for whatever hookup wire is used.

    openscad -o assembly-exploded.png -D 'view="exploded"' --imgsize=1800,1500 --projection=o --viewall \
      --autocenter --camera=31,80,44,68,0,252,560 --colorscheme=Tomorrow assembly-views.scad
    openscad -o assembly-wiring.png   -D 'view="wiring"'   --imgsize=1800,1500 --projection=o --viewall \
      --autocenter --camera=31,0,44,78,0,195,260 --colorscheme=Tomorrow assembly-views.scad

draw_model = false MUST come after the include: the last assignment in a scope wins.
*/
include <print-chamber-box.scad>
draw_model = false;

view = "wiring";   // "exploded" or "wiring"

// ------------------------------------------------------------------ the parts, as drawn here
module sps30() {
    color("silver") translate([sps_x0, back_t, z_sps0]) cube([sps_w, sps_t, sps_h]);
    // its plug, on the connector face at the outlet end
    color([0.15, 0.15, 0.15])
        translate([lead_x0, back_t + sps_t / 2 - 2.5, z_sps1]) cube([lead_x1 - lead_x0, 5, 3.5]);
}
module supermini() for (i = [0 : 4]) sm_piece(i, 0);

gy_pcb_nom = 1.2;                               // a GY board, for the picture only
gy_pcb_y0  = gy_floor + gy_ledge_h;             // its back face, on the ledge
gy_front   = gy_pcb_y0 + gy_pcb_nom;            // its front face
module sgp41() {
    x0 = gx0 + pocket_fit; z0 = gz0 + pocket_fit;
    color([0.15, 0.55, 0.25]) translate([x0, gy_pcb_y0, z0]) cube([gy_l, gy_pcb_nom, gy_w]);
    // its parts, on the pin half of its back
    color([0.12, 0.12, 0.12]) translate([gy_parts_x0 + 0.5, gy_pcb_y0 - (gy_back - gy_pcb_nom), z0 + 0.8])
        cube([gy_l - gy_bare - 1, gy_back - gy_pcb_nom, gy_w - 1.6]);
    // the sensor, on its front at the far end, by the long edge away from the hole
    color([0.75, 0.75, 0.70])
        translate([conn_hi ? x0 + 2.0 : x0 + gy_l - 4.44, gy_front, conn_hi ? z0 + 1.5 : z0 + gy_w - 3.94])
            cube([2.44, gy_sensor_h, 2.44]);
}
module screw(p, head_d, head_h, d, l) {   // head on the face at p, shank running back into -Y
    color([0.55, 0.55, 0.60]) translate(p) {
        rotate([-90, 0, 0]) cylinder(d = head_d, h = head_h);
        rotate([90, 0, 0]) cylinder(d = d, h = l);
    }
}
module m25() screw([gy_hole_x, gy_front, gy_hole_z], gy_head_d, gy_head_h, gy_screw_d, gy_screw_l);
module m3s() for (b = bosses) screw([b[0], D, b[1]], 5.6, 2.2, 3, 14);

// ------------------------------------------------------------------ text and guide lines
// labels in the exploded view face its camera: flat text turned by the camera's own angles
cam_rx = 68; cam_rz = 252;
module label(t, p, size = 4.0) translate(p) rotate([cam_rx, 0, cam_rz]) color("black")
    linear_extrude(0.4) text(t, size = size, halign = "center", valign = "center");
module guide(a, b) color([0.6, 0.6, 0.6]) hull() { translate(a) sphere(d = 0.5, $fn = 8); translate(b) sphere(d = 0.5, $fn = 8); }

// ------------------------------------------------------------------ the wires
wd = 1.0;   // a wire, drawn 1 mm thick
module wire(pts, c) color(c) for (i = [0 : len(pts) - 2])
    hull() { translate(pts[i]) sphere(d = wd, $fn = 10); translate(pts[i + 1]) sphere(d = wd, $fn = 10); }

sgn = conn_hi ? -1 : 1;                          // +1: away from the connector-end wall is +X
function pin_x(k) = sm_usb_x + sgn * (pin_mid + (k - 2) * pin_pitch);   // power-edge pin k = 1, 2, 3
pad_y = back_t + sm_pcb_t + 0.3;                 // where a wire meets a pad, on the component side
z_lo  = z_board_c - sm_w / 2 + 1.0;              // the pins along the board's lower edge ...
z_hi  = z_board_c + sm_w / 2 - 1.0;              // ... and its upper edge
// where each wire lies in the channel: across its slot, and out from the plate
function slot(dx, y) = [wch_cx + sgn * dx, y];

// from the top of the channel to its pin: straight up into a lower-edge pad, or up across the front of
// the board's USB-C end into an upper-edge one
function to_pin(s, x, upper) = upper
    ? [[s[0], s[1], wch_z1 + 0.8], [x, 8.0, wch_z1 + 2.5], [x, 8.0, z_hi], [x, pad_y, z_hi]]
    : [[s[0], s[1], wch_z1 + 0.8], [x, 4.6, z_lo - 0.6], [x, pad_y, z_lo]];

// the SPS30's lead: five wires out of its plug, up, over to the channel and up it
y_mid = back_t + sps_t / 2;
function lead_x(d) = conn_hi ? sps_x1 - d : sps_x0 + d;   // d from the outlet end
module sps_wire(d, s, x, upper, c) wire(concat(
    [[lead_x(d), y_mid, z_sps1 + 3.5], [lead_x(d), y_mid, z_sps1 + cable_zone_h - 3],
     [s[0], s[1], wch_z0 - 1.5]], to_pin(s, x, upper)), c);

// the SGP41's four: soldered from its sensor side, bent flat towards the channel, in front of the lead's
// column, then back down to the plate and up the channel
gy_pin_x = conn_hi ? gx1 - pocket_fit - 1.6 : gx0 + pocket_fit + 1.6;
function gy_pin_z(off) = conn_hi ? gz0 + pocket_fit + off : gz1 - pocket_fit - off;   // off from the edge by SDA
module gy_wire(off, s, x, upper, c) wire(concat(
    [[gy_pin_x, gy_front, gy_pin_z(off)], [gy_pin_x, gy_front + 1.5, gy_pin_z(off)],
     [(conn_hi ? lead_x1 + 1.5 : lead_x0 - 1.5), gy_front + 1.5, gy_pin_z(off)],
     [s[0], s[1], wch_z0 - 1.5]], to_pin(s, x, upper)), c);

module wires() {
    // the SPS30's lead, pin 1 to 5, read 8.6 down to 3.0 mm from the outlet end (photo 1)
    sps_wire(8.6, slot(-1.1, 3.1), pin_x(1), false, [0.10, 0.10, 0.10]);   // black  VDD -> 5V
    sps_wire(7.2, slot(-1.1, 4.3), pin_x(1), true,  [0.85, 0.10, 0.10]);   // red    SDA -> GPIO5
    sps_wire(5.8, slot( 1.1, 4.3), pin_x(2), true,  [0.95, 0.95, 0.95]);   // white  SCL -> GPIO6
    sps_wire(4.4, slot( 0.0, 4.3), pin_x(2), false, [0.95, 0.80, 0.10]);   // yellow SEL -> GND
    sps_wire(3.0, slot( 0.0, 3.1), pin_x(2), false, [0.95, 0.45, 0.10]);   // orange GND -> GND
    // the SGP41's four, top to bottom along its pin edge: SDA, SCL, GND, VIN
    gy_wire(2.2,  slot(-1.1, 5.5), pin_x(1), true,  [0.20, 0.35, 0.85]);   // SDA -> GPIO5
    gy_wire(4.55, slot( 1.1, 5.5), pin_x(2), true,  [0.20, 0.65, 0.30]);   // SCL -> GPIO6
    gy_wire(6.9,  slot( 0.0, 5.5), pin_x(2), false, [0.45, 0.30, 0.20]);   // GND -> GND
    gy_wire(9.2,  slot( 1.1, 3.1), pin_x(3), false, [0.60, 0.15, 0.55]);   // VIN -> 3V3
}

// ------------------------------------------------------------------ the views
if (view == "wiring") {
    color([0.80, 0.72, 0.58]) back_plate();
    sps30(); supermini(); sgp41(); m25();
    wires();
    translate([-tab_l - 4, 0, H + 38]) rotate([90, 0, 180]) color("black") linear_extrude(0.4) {
        lines = ["WIRING - as you face the box, cover off",
                 "",
                 "SPS30 black   VDD  ->  5V",
                 "SPS30 orange  GND  ->  GND",
                 "SPS30 yellow  SEL  ->  GND",
                 "SPS30 red     SDA  ->  GPIO5",
                 "SPS30 white   SCL  ->  GPIO6",
                 "SGP41 VIN (purple)  ->  3V3",
                 "SGP41 GND (brown)   ->  GND",
                 "SGP41 SDA (blue)    ->  GPIO5",
                 "SGP41 SCL (green)   ->  GPIO6",
                 "",
                 "all nine up the cable channel;",
                 "GPIO5/6 then across the USB-C end"];
        for (i = [0 : len(lines) - 1]) translate([0, -i * 5.2]) text(lines[i], size = 3.0);
    }
}

if (view == "exploded") {
    dx_sm = conn_hi ? sm_l + 14 : -(sm_l + 14);
    color([0.80, 0.72, 0.58]) back_plate();
    e_sps = 40; e_gy = 60; e_m25 = 82; e_cov = 115; e_m3 = 160;   // how far out each one goes
    translate([dx_sm, 0, 0]) supermini();
    translate([0, e_sps, 0]) sps30();
    translate([0, e_gy, 0]) sgp41();
    translate([0, e_m25, 0]) m25();
    translate([0, e_cov, 0]) color([0.62, 0.72, 0.85]) cover();
    translate([0, e_m3, 0]) m3s();
    // the way each one goes in
    guide([sm_usb_x + dx_sm, back_t, z_board_c], [sm_usb_x, back_t, z_board_c]);
    guide([sps_x0 + sps_w / 2, back_t + e_sps, z_sps0 + sps_h / 2], [sps_x0 + sps_w / 2, back_t, z_sps0 + sps_h / 2]);
    guide([gy_hole_x, gy_front + e_m25, gy_hole_z], [gy_hole_x, gy_pcb_y0, gy_hole_z]);
    for (b = bosses) guide([b[0], D + e_m3, b[1]], [b[0], y_in1, b[1]]);
    label("back plate",                            [W / 2, 0, H + 14]);
    label("SuperMini - slides in under the lips",  [sm_usb_x + dx_sm + sm_l / 2, back_t, z_board1 + 16]);
    label("SPS30 - in from the front",             [sps_x0 + sps_w / 2, back_t + e_sps + sps_t, z_sps0 - 12]);
    label("GY-SGP41",                              [gx0 + gy_pocket_l / 2, gy_front + e_gy, gz1 + 8]);
    label("M2.5 x 8",                              [gy_hole_x + (conn_hi ? 9 : -9), gy_front + e_m25 + gy_head_h, gy_hole_z + 10]);
    label("cover",                                 [W / 2, D + e_cov, -12]);
    label("4 x M3 x 14 self-tapping",              [W / 2, D + e_m3, H + 18]);
}
