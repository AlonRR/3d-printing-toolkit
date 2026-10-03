// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
Assembly views of the print-chamber box, for docs/assembly.md and docs/wiring.md.

  view = "exploded"   every part, moved apart along the way it goes in: the nuts from the wall side, the
                      SuperMini from the front into its clasps, the SGP41 and its screw from the side,
                      the SPS30, the cover and its screws from the front.
  view = "open"       assembled with the cover off, every wire drawn along its route to its pin, and the
                      wiring table beside it.
  view = "check_wires" every wire against the printed parts and everything else in the box - export it to
                      STL; it must be empty, so OpenSCAD writes no file.

It includes the model, so every part sits where the model puts it. The routes are one way the wires can
go, not the only one - a wire bends where it likes - but each ends on the pin docs/wiring.md gives it,
and the checks below hold every route to what the box allows: no bend tighter than the wire takes, every
wire clear of every other except where two meet on one pad, clear of the antenna by ant_clear, and
clear of the printed parts, the sensors, the board and the wall screws' heads (view "check_wires"). The
open view runs the checks as it draws; an ERROR: Assertion line in its output means one broke - OpenSCAD
still exits 0, so read the output, not the exit code. The routes are laid out for the box as built,
outlet at the right.

    openscad -o docs/assembly-exploded.png -D 'view="exploded"' --imgsize=1800,1500 --projection=o --viewall \
      --autocenter --camera=33,80,38,68,0,252,560 --colorscheme=Tomorrow assembly-views.scad
    openscad -o docs/assembly-open.png -D 'view="open"' --imgsize=1800,1500 --projection=o --viewall \
      --autocenter --camera=33,0,38,78,0,195,260 --colorscheme=Tomorrow assembly-views.scad
    openscad -o docs/wiring-detail.png -D 'view="open"' -D detail=true --imgsize=1800,1350 --projection=o \
      --camera=8,11,51,112,0,215,70 --colorscheme=Tomorrow assembly-views.scad

draw_model = false MUST come after the include: the last assignment in a scope wins.
*/
include <print-chamber-box.scad>
use <../lib/axes.scad>
draw_model = false;

view = "open";   // "exploded" or "open"
detail = false;  // the open view without its table, the arrows moved in: for a close-up of the pins

// ------------------------------------------------------------------ the parts, as drawn here
module sps30() {
    color("silver") box3([sps_x0, back_t, z_sps0], [sps_x1, back_t + sps_t, z_sps1]);
    // its plug, on the connector face at the outlet end
    color([0.15, 0.15, 0.15]) box3([lead_x0, back_t + sps_t / 2 - 2.5, z_sps1], [lead_x1, back_t + sps_t / 2 + 2.5, z_sps1 + 3.5]);
}
module supermini() for (i = [0 : 4]) sm_piece(i, 0);

module sgp41() {
    // the PCB, flat, its sensor towards the cover and its pins up
    color([0.15, 0.55, 0.25]) box3([gy_x0, gy_yu, gy_z0], [gy_x1, gy_yf, gy_z1]);
    // the parts on its underside, above the bare strip along its bottom edge and clear of the bare patch
    // round its hole; and the sensor, on its face at the bottom, at the side away from the hole
    color([0.12, 0.12, 0.12]) difference() {
        box3([gy_x0 + 0.8, gy_yp, gy_z0 + gy_bare + 0.3], [gy_x1 - 0.8, gy_yu, gy_z1 - 2.6]);
        cyl_y(gy_hx, gy_hz, gy_hole_bare_d / 2, gy_yp - 1, gy_yu + 1);
    }
    xs = gy_hole_lowx ? gy_x1 - 4.3 : gy_x0 + 1.84;
    color([0.75, 0.75, 0.70]) box3([xs, gy_yf, gy_z0 + 1.7], [xs + 2.44, gy_yf + gy_sensor_h, gy_z0 + 4.14]);
    // its four pin holes along the top edge, the wires soldered into them - no header
    for (i = [0 : 3]) color([0.8, 0.7, 0.2])
        box3([gy_pin_x(i) - 0.5, gy_yu - 0.2, gy_pin_z - 0.5], [gy_pin_x(i) + 0.5, gy_yf + 0.2, gy_pin_z + 0.5]);
}
module m25() color([0.55, 0.55, 0.60]) {   // head on the module's face, shank back into the post
    cyl_y(gy_hx, gy_hz, gy_head_d / 2, gy_yf, gy_yf + gy_head_h);
    cyl_y(gy_hx, gy_hz, gy_screw_d / 2, gy_yf - gy_screw_l, gy_yf);
}
module nuts() for (x = nut_bx) color([0.55, 0.55, 0.60])
    translate([x, nut_y1 - nut_h, nut_bz]) rotate([-90, 0, 0]) rotate([0, 0, 30]) cylinder(d = nut_ac, h = nut_h, $fn = 6);
module m3s() for (x = nut_bx) color([0.55, 0.55, 0.60]) {   // head on the cover's face, shank back into -Y
    cyl_y(x, nut_bz, 2.75, D, D + 3);
    cyl_y(x, nut_bz, 1.5, D - cover_screw_l, D);
}

// ------------------------------------------------------------------ the wires
wd          = 1.0;    // the SPS30 lead's wires, drawn 1 mm thick
bend_r      = gy_bend_r;   // the SGP41's 22 AWG solid wire's tightest bend, on the centreline (gy_wd: the params)
lead_bend_r = 1.0;    // the lead's stranded wires bend tighter
wire_stub   = gy_stub;     // straight out of a solder joint before the first bend
ant_clear   = 3.0;    // no wire nearer the antenna's loop or pole than this, surface to surface
pad_join    = 5.0;    // two wires that end on one pad may meet within this of it

// A route is a list of corners. Each corner is drawn as a circular arc of radius r where the segments
// leave room for one: an end segment may give all its length to its one bend, a middle segment half to
// each of its two. Where they do not, the arc is tighter - min_radius() reports it.
function unit(v) = v / norm(v);
function turn(pts, i) = acos(max(-1, min(1, unit(pts[i] - pts[i - 1]) * unit(pts[i + 1] - pts[i]))));
function cut_max(pts, i) = min(norm(pts[i] - pts[i - 1]) / (i == 1 ? 1 : 2),
                               norm(pts[i + 1] - pts[i]) / (i == len(pts) - 2 ? 1 : 2));
function cut(pts, i, r) = min(r * tan(turn(pts, i) / 2), cut_max(pts, i));
function arc(pts, i, r, n = 8) = let(th = turn(pts, i), p = pts[i]) th < 0.5 ? [p] : let(
    ui = unit(p - pts[i - 1]), uo = unit(pts[i + 1] - p),
    ra = cut(pts, i, r) / tan(th / 2), n1 = unit(uo - ui * (ui * uo)), o = p - ui * cut(pts, i, r) + n1 * ra)
    [for (k = [0 : n]) let(f = th * k / n) o - n1 * ra * cos(f) + ui * ra * sin(f)];
function rounded(pts, r) = concat([pts[0]], [for (i = [1 : len(pts) - 2]) each arc(pts, i, r)], [pts[len(pts) - 1]]);
function min_radius(pts, r) = min([for (i = [1 : len(pts) - 2])
    turn(pts, i) < 0.5 ? 1e9 : cut(pts, i, r) / tan(turn(pts, i) / 2)]);
// for the clearance checks: the drawn route, a point every step mm
function dense(pts, step = 0.4) = concat([for (i = [0 : len(pts) - 2]) let(a = pts[i], b = pts[i + 1],
    n = max(1, ceil(norm(b - a) / step))) each [for (k = [0 : n - 1]) a + (b - a) * k / n]], [pts[len(pts) - 1]]);
function min_gap(p, q) = min([for (a = p) min([for (b = q) norm(a - b)])]);
function last(v) = v[len(v) - 1];

module wire(pts, c, d, r, s = 0, fn = 10) let(q = rounded(pts, r)) color(c) for (i = [0 : len(q) - 2])
    hull() { translate(q[i]) sphere(d = d - 2 * s, $fn = fn); translate(q[i + 1]) sphere(d = d - 2 * s, $fn = fn); }

// The board's pins the wires go to, along X from its USB-C end: 5V, GND, 3V3 on its front edge, GPIO5,
// GPIO6 on its back edge - the first two columns.
px = [for (k = [0 : 2]) sm_usb_x + pin_mid + (k - 1) * pin_pitch];
y_back_end  = y_b0 + 0.6;     // where a wire ends under a back pad ...
y_front_end = y_b1 - 0.6;     // ... and a front one
zg = zu - gy_wd / 2;          // an SGP41 wire lying against the board's underside
zl = zu - wd / 2;             // a lead wire doing the same

// The SPS30's lead: five wires out of the top of its plug, at the outlet end. Pin 1 to 5 read 8.6 down to
// 3.0 mm from that end (photo 1). They rise and bend over towards the board's USB-C end inside the cable
// zone. SEL and GND, for the front's GND pad, cross at one height; VDD, bound past them for 5V, and the
// two for the back pads a wire higher - so each passes over the risers and the turns of the others. The
// back two run over the wall screw's head and under the SGP41's wires to the same pads, and come up beside
// them at the end.
y_plug  = back_t + sps_t / 2;
z_plug  = z_sps1 + 3.5 + wd / 2;               // just out of the plug's top
function lead_x(d) = sps_x0 + d;               // d from the outlet end
z_front = z_sps1 + cable_zone_h - 2.4;         // the front-bound lead wires' height
z_back  = z_front + wd + 0.3;                   // the back-bound ones, a wire higher
z_stack = zg - gy_wd / 2 - 0.1 - wd / 2;       // a lead wire under an SGP41 wire, at a back pad
// x_turn: where the lane turns for its pad - either side of it, for two wires to one pad
function lead_front(d, lane, x, x_turn, z = z_front) = [[lead_x(d), y_plug, z_plug], [lead_x(d), y_plug, z - 1.5],
    [lead_x(d), lane, z], [x_turn, lane, z], [x, y_front_end, z + 1.5], [x, y_front_end, zl]];
// y_step: the lane steps forward off the plug first, clear of the risers it passes
function lead_back(d, lane, x, y_step) = concat([[lead_x(d), y_plug, z_plug]],
    y_step > 0 ? [[lead_x(d), y_plug, z_back - 1.8], [lead_x(d), y_plug + y_step, z_back]] : [[lead_x(d), y_plug, z_back]],
    [[x + 1.0, lane, z_back], [x + 0.6, y_back_end + 0.8, z_stack], [x + 0.4, y_back_end, zl]]);
lead_routes = [
    lead_front(8.6, y_front_end - 3.6, px[0], px[0], z_back),  // black  VDD -> 5V
    lead_back (7.2, y_plug + 1.4, px[0], 1.4),                 // red    SDA -> GPIO5
    lead_back (5.8, y_plug - 1.8, px[1], 0),                   // white  SCL -> GPIO6
    lead_front(4.4, y_front_end - 1.4, px[1], px[1] + 0.6),    // yellow SEL -> GND
    lead_front(3.0, y_front_end - 2.5, px[1], px[1] - 0.6)];   // orange GND -> GND
lead_pads   = ["5V", "GPIO5", "GPIO6", "GND", "GND"];
lead_colours = [[0.10, 0.10, 0.10], [0.85, 0.10, 0.10], [0.95, 0.95, 0.95], [0.95, 0.80, 0.10], [0.95, 0.45, 0.10]];

// The SGP41's four: soldered into its pin holes from its back, they come out towards the plate, turn up
// the column behind the module - stepping to their lanes low down, below the wall screw's head - and once
// level cross the SPS30's top-left corner in the plate's channel (gy_channel in the model). Past it they slant forward - gently, so the slant does not
// bring them together - to pass in front of the SPS30's plug, under the cable zone's lead wires and well
// under the antenna. At the board's USB-C end the two for the back pads
// climb to lie against the board's underside and run back to them; VIN climbs straight up to 3V3 at the
// front edge, and GND, which passes behind it, slants up to its pad beside it.
z_cross  = gy_ch_zc;                                           // where they cross the SPS30's top: the channel's slot
gy_lane  = [for (i = [0 : 3]) y_front_end - (3 - i) * gy_pitch];   // past the channel; VIN's is the front pads' line
gy_slant = 20;                                                  // the run over which they slant forward
gy_y_up  = gy_yu - gy_wd / 2 - wire_stub - bend_r;              // where they rise, behind the module
function gy_start(i) = [[gy_pin_x(i), gy_yu - gy_wd / 2, gy_pin_z], [gy_pin_x(i), gy_y_up, gy_pin_z],
    [gy_rise_x(i), gy_ch_lane[i], gy_pin_z + 8], [gy_rise_x(i), gy_ch_lane[i], z_cross], [gy_ch_x0, gy_ch_lane[i], z_cross],
    [gy_ch_x0 - gy_slant, gy_lane[i], z_cross]];
function gy_to_back(i, x, y_flat) = concat(gy_start(i),
    [[x, gy_lane[i], z_cross], [x, y_flat, zg], [x, y_back_end, zg]]);
gy_routes = [
    gy_to_back(0, px[0], y_back_end + 5.8),                                          // SDA -> GPIO5
    gy_to_back(1, px[1], y_back_end + 8.8),                                          // SCL -> GPIO6
    concat(gy_start(2), [[px[1], gy_lane[2], z_cross], [px[1], y_front_end, z_cross + 6.0],
                         [px[1], y_front_end, zg]]),                                 // GND -> GND
    concat(gy_start(3), [[px[2], gy_lane[3], z_cross], [px[2], y_front_end, zg]])];   // VIN -> 3V3
gy_pads    = ["GPIO5", "GPIO6", "GND", "3V3"];
gy_colours = [[0.20, 0.35, 0.85], [0.20, 0.65, 0.30], [0.45, 0.30, 0.20], [0.60, 0.15, 0.55]];

// The checks, on the routes as drawn: every pair of wires - except, for two that end on one pad, within
// pad_join of where they end - and every wire against the antenna.
all_routes = concat(gy_routes, lead_routes);
all_d      = concat([for (i = [0 : 3]) gy_wd], [for (i = [0 : 4]) wd]);
all_r      = concat([for (i = [0 : 3]) bend_r], [for (i = [0 : 4]) lead_bend_r]);
all_pads   = concat(gy_pads, lead_pads);
all_dense  = [for (i = [0 : len(all_routes) - 1]) dense(rounded(all_routes[i], all_r[i]))];
function away(d, end, shared) = shared ? [for (p = d) if (norm(p - end) > pad_join) p] : d;
function pair_gap(i, j) = let(shared = all_pads[i] == all_pads[j], ei = last(all_routes[i]))
    min_gap(away(all_dense[i], ei, shared), away(all_dense[j], ei, shared)) - (all_d[i] + all_d[j]) / 2;
pole_c = [sm_ant_x - pole_in, y_bc];
loop_b = [[sm_ant_x, y_b0 + ant_loop_free, zu + sm_pcb_t], [sm_ant_x + ant_over, y_b1 - ant_loop_free, zu + sm_pcb_t + 1]];
function d_box(p, b) = norm([for (k = [0 : 2]) max(b[0][k] - p[k], 0, p[k] - b[1][k])]);
function d_pole(p) = let(dz = max(zu + sm_pcb_t - p[2], 0, p[2] - (zu + ant_h)))
    norm([norm([p[0] - pole_c[0], p[1] - pole_c[1]]) - 0.5 > 0 ? norm([p[0] - pole_c[0], p[1] - pole_c[1]]) - 0.5 : 0, dz]);
wire_min_r   = min([for (i = [0 : len(all_routes) - 1]) min_radius(all_routes[i], all_r[i]) - all_r[i]]);
wire_min_gap = min([for (i = [0 : len(all_routes) - 2]) for (j = [i + 1 : len(all_routes) - 1]) pair_gap(i, j)]);
wire_ant     = min([for (i = [0 : len(all_routes) - 1]) for (p = all_dense[i]) min(d_box(p, loop_b), d_pole(p)) - all_d[i] / 2]);
module check_routes() {
    assert(!outlet_at_left, "the wire routes are laid out for outlet_at_left = false, the box as built");
    assert(wire_min_r >= -0.01, str("a wire bends ", -wire_min_r, " mm tighter than it takes - a segment is too short for its bend"));
    assert(wire_min_gap >= -1e-6, str("two wires run into each other: ", -wire_min_gap, " mm of overlap"));
    assert(wire_ant >= ant_clear, str("a wire comes within ", wire_ant, " mm of the antenna - ant_clear is ", ant_clear));
    assert(gy_wd + 0.1 + wd <= back_wire_room + 1e-6, "the two wires stacked under a back pad do not fit back_wire_room");
    echo(str("wires: tightest bend ", wire_min_r, " mm over what each takes; nearest two ", wire_min_gap,
             " mm apart; nearest the antenna ", wire_ant, " mm"));
}
module wires(s = 0, fn = 10) {
    for (i = [0 : 4]) wire(lead_routes[i], lead_colours[i], wd, lead_bend_r, s, fn);
    for (i = [0 : 3]) wire(gy_routes[i], gy_colours[i], gy_wd, bend_r, s, fn);
}
// Everything a wire must keep out of, other than the printed parts and the other wires: the SPS30 and its
// plug, the board, its parts and USB-C shell, the GY-SGP41 - its pin strip excepted, where its wires leave
// it - and its screw's head, and the wall screws' heads as they slide up their keyholes. The antenna is
// held off by ant_clear above, and the air gap in front of the sensor by the baffle the cover closes it with.
module obstacles() {
    box3([sps_x0, back_t, z_sps0], [sps_x1, back_t + sps_t, z_sps1]);
    box3([lead_x0, y_plug - 2.5, z_sps1], [lead_x1, y_plug + 2.5, z_sps1 + 3.5]);
    for (i = [0 : 2]) sm_piece(i, 0);
    box3([gy_x0, gy_yu, gy_z0], [gy_x1, gy_yf + gy_sensor_h, gy_z1]);
    difference() {
        box3([gy_x0, gy_yp, gy_z0 + gy_bare], [gy_x1, gy_yu, gy_z1 - 2.6]);
        cyl_y(gy_hx, gy_hz, gy_hole_bare_d / 2, gy_yp - 1, gy_yu + 1);
    }
    cyl_y(gy_hx, gy_hz, gy_head_d / 2, gy_yf, gy_yf + gy_head_h);
    for (x = key_xs) hull() for (z = [key_z0, key_z1]) cyl_y(x, z, key_head_d / 2, back_t, back_t + key_slack + key_head_h);
    box3([ch_x0, y_sps1, z_sps0], [ch_x1, y_in1, z_sps1 + part_fit]);
}

// ------------------------------------------------------------------ text and guide lines
// labels face the camera: flat text turned by the camera's own angles
module label(t, p, cam, size = 4.0) translate(p) rotate(cam) color("black")
    linear_extrude(0.4) text(t, size = size, halign = "center", valign = "center");
module guide(a, b) color([0.6, 0.6, 0.6]) hull() { translate(a) sphere(d = 0.5, $fn = 8); translate(b) sphere(d = 0.5, $fn = 8); }

// ------------------------------------------------------------------ the views
if (view == "open") {
    cam = [78, 0, 195];
    check_routes();
    color([0.80, 0.72, 0.58]) back_plate();
    sps30(); supermini(); sgp41(); m25(); nuts();
    wires();
    if (detail) axes([-20, 30, 34], 5, [112, 0, 215], [[0, 0], [0, 0], [0, 0]]);
    else axes([-22, 0, -25], 20, cam, [[0, 0], [1.7, -0.3], [0, 0]]);
    if (!detail) translate([-18, 0, H + 34]) rotate([90, 0, 180]) color("black") linear_extrude(0.4) {
        lines = ["OPEN - as you face the box, cover off",
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
                 "every pin at the board's USB-C end;",
                 "the SGP41's four across in front of the lead"];
        for (i = [0 : len(lines) - 1]) translate([0, -i * 5.2]) text(lines[i], size = 3.0);
    }
}

if (view == "exploded") {
    cam = [68, 0, 252];
    color([0.80, 0.72, 0.58]) back_plate();
    e_nut = -18; e_sm = 72; e_sps = 40; e_gy = 22; e_m25 = 44; e_cov = 105; e_m3 = 150;   // how far out each one goes
    dx_sm = 0;
    translate([0, e_nut, 0]) nuts();
    translate([dx_sm, e_sm, 0]) supermini();
    translate([0, e_sps, 0]) sps30();
    translate([0, e_gy, 0]) sgp41();
    translate([0, e_m25, 0]) m25();
    translate([0, e_cov, 0]) color([0.62, 0.72, 0.85]) cover();
    translate([0, e_m3, 0]) m3s();
    // the way each one goes in
    for (x = nut_bx) guide([x, e_nut + nut_y1, nut_bz], [x, nut_y1 - nut_h, nut_bz]);
    guide([sm_x0 + sm_l / 2 + dx_sm, y_bc + e_sm, zu], [sm_x0 + sm_l / 2 + dx_sm, y_bc, zu]);
    guide([(sps_x0 + sps_x1) / 2, back_t + e_sps, (z_sps0 + z_sps1) / 2], [(sps_x0 + sps_x1) / 2, back_t, (z_sps0 + z_sps1) / 2]);
    guide([gy_hx, gy_yf + e_m25, gy_hz], [gy_hx, gy_post_y1, gy_hz]);
    for (x = nut_bx) guide([x, D + e_m3, nut_bz], [x, y_in1, nut_bz]);
    label("back plate",                            [W / 2, 0, H + 12], cam);
    label("2 x M3 nut, from the back",             [W / 2, e_nut, -16], cam, 3.2);
    label("SuperMini - into its clasps, from the front", [sm_x0 + dx_sm + sm_l / 2, y_bc + e_sm, zu + ant_h + 6], cam, 3.2);
    label("SPS30 - in from the front",             [(sps_x0 + sps_x1) / 2, back_t + e_sps + sps_t, z_sps0 - 12], cam, 3.2);
    label("cover - its top in a U on a bump",           [W / 2, D + e_cov, -14], cam, 3.2);
    label("2 x M3 x 20",                           [W / 2, D + e_m3, nut_bz + 16], cam, 3.2);
    label("SGP41 and its M2.5 x 6, from the front", [gy_x1 + 4, gy_yf + e_m25, gy_z1 + 6], cam, 3.2);
    axes([W, 0, -80], 25, cam, [[-1, 0], [0, 0], [0, 0]]);
}

// every wire against the printed parts and everything else in the box: must be empty
if (view == "check_wires")
    intersection() {
        union() { back_plate(); cover(); obstacles(); }
        wires(0.02, 8);
    }
