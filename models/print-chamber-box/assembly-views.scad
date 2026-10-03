// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
Assembly views of the print-chamber box, for docs/assembly.md and docs/wiring.md.

  view = "exploded"   every part, moved apart along the way it goes in: the SuperMini out to its USB-C side
                      (it slides in), the sensors, the screws and the cover out from the wall.
  view = "wiring"     assembled with the cover off, and every wire drawn along its route to its pin.
  view = "check_wires" the back plate where the SGP41's wires pass through it - export it to STL; it must be
                      empty, so OpenSCAD writes no file.

It includes the model, so every part sits where the model puts it. The wire routes are illustrative - a
wire bends where it likes - but each one ends on the pin docs/wiring.md gives it and keeps out
of the antenna and the air paths. The SPS30's five pass up the cable channel. The SGP41's four come out of
its back and run across to the board's pins, and the asserts below hold their routes to what wire_room
promises: no bend tighter than bend_r, within the room behind the board, clear of each other, of the
SPS30's wires and of the board's antenna half. The SPS30 lead's colours are the meter-checked ones; the
SGP41's are stand-in colours for the lab's 22 AWG solid hookup wire.

    openscad -o docs/assembly-exploded.png -D 'view="exploded"' --imgsize=1800,1500 --projection=o --viewall \
      --autocenter --camera=31,80,44,68,0,252,560 --colorscheme=Tomorrow assembly-views.scad
    openscad -o docs/assembly-wiring.png   -D 'view="wiring"'   --imgsize=1800,1500 --projection=o --viewall \
      --autocenter --camera=31,0,44,78,0,195,260 --colorscheme=Tomorrow assembly-views.scad
    openscad -o docs/assembly-wiring-detail.png -D 'view="wiring"' -D 'axes_at=[23.2, 30, 75.5]' -D axes_l=5 \
      -D 'axes_cam=[72, 0, 200]' --imgsize=1800,1500 --projection=o \
      --camera=16,6,58,72,0,200,95 --colorscheme=Tomorrow assembly-views.scad

The wiring view checks the SGP41's routes as it draws them, and an ERROR: Assertion line in the output
means one broke - OpenSCAD still exits 0, so read the output, not the exit code.

draw_model = false MUST come after the include: the last assignment in a scope wins.
*/
include <print-chamber-box.scad>
use <../lib/axes.scad>
draw_model = false;

view = "wiring";   // "exploded" or "wiring"

// The xyz arrows every figure carries (../lib/axes.scad): the box's own axes. The wiring detail's camera
// is fixed rather than --viewall, so its render command moves and shrinks them with -D.
axes_at  = undef;
axes_l   = 20;
axes_cam = [78, 0, 195];

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
    // its parts, on the pin half of its back, inboard of the pin row
    color([0.12, 0.12, 0.12])
        translate([conn_hi ? gy_bare_x0 + gy_bare + 0.5 : gy_pin_x + 1.5, gy_pcb_y0 - (gy_back - gy_pcb_nom), z0 + 0.8])
            cube([gy_l - gy_bare - (gy_pin_x - gx0 - pocket_fit) - 2.0, gy_back - gy_pcb_nom, gy_w - 1.6]);
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
wd        = 1.0;   // the SPS30 lead's wires, drawn 1 mm thick
gy_wd     = 1.56;  // the SGP41's: the lab's 22 AWG solid hookup wire, measured over its insulation
bend_r    = 3.0;   // the SGP41's wires' tightest bend, on the centreline - about twice the wire
wire_stub = 1.0;   // straight out of a solder joint before the first bend

// A route is a list of corners. Each corner is drawn as a circular arc of radius bend_r where the
// segments leave room for one: an end segment may give all its length to its one bend, a middle segment
// half to each of its two. Where they do not, the arc is tighter - min_radius() reports it.
function unit(v) = v / norm(v);
function turn(pts, i) = acos(max(-1, min(1, unit(pts[i] - pts[i - 1]) * unit(pts[i + 1] - pts[i]))));
function cut_max(pts, i) = min(norm(pts[i] - pts[i - 1]) / (i == 1 ? 1 : 2),
                               norm(pts[i + 1] - pts[i]) / (i == len(pts) - 2 ? 1 : 2));
function cut(pts, i) = min(bend_r * tan(turn(pts, i) / 2), cut_max(pts, i));
function arc(pts, i, n = 8) = let(th = turn(pts, i), p = pts[i]) th < 0.5 ? [p] : let(
    ui = unit(p - pts[i - 1]), uo = unit(pts[i + 1] - p),
    ra = cut(pts, i) / tan(th / 2), n1 = unit(uo - ui * (ui * uo)), o = p - ui * cut(pts, i) + n1 * ra)
    [for (k = [0 : n]) let(f = th * k / n) o - n1 * ra * cos(f) + ui * ra * sin(f)];
function rounded(pts) = concat([pts[0]], [for (i = [1 : len(pts) - 2]) each arc(pts, i)], [pts[len(pts) - 1]]);
function min_radius(pts) = min([for (i = [1 : len(pts) - 2])
    turn(pts, i) < 0.5 ? 1e9 : cut(pts, i) / tan(turn(pts, i) / 2)]);
// for the clearance checks: the drawn route, a point every 0.2 mm
function dense(pts, step = 0.2) = concat([for (i = [0 : len(pts) - 2]) let(a = pts[i], b = pts[i + 1],
    n = max(1, ceil(norm(b - a) / step))) each [for (k = [0 : n - 1]) a + (b - a) * k / n]], [pts[len(pts) - 1]]);
function min_gap(p, q) = min([for (a = p) min([for (b = q) norm(a - b)])]);

module wire(pts, c, d = wd, fn = 10) let(r = rounded(pts)) color(c) for (i = [0 : len(r) - 2])
    hull() { translate(r[i]) sphere(d = d, $fn = fn); translate(r[i + 1]) sphere(d = d, $fn = fn); }

sgn = conn_hi ? -1 : 1;                          // +1: away from the connector-end wall is +X
function pin_x(k) = sm_usb_x + sgn * (pin_mid + (k - 2) * pin_pitch);   // power-edge pin k = 1, 2, 3
pad_y = back_t + sm_pcb_t + 0.3;                 // where a wire meets a pad, on the component side
z_lo  = z_board_c - sm_w / 2 + 1.0;              // the pins along the board's lower edge ...
z_hi  = z_board_c + sm_w / 2 - 1.0;              // ... and its upper edge
// where each wire lies in the channel: across its slot, and out from the plate
function slot(dx, y) = [wch_cx + sgn * dx, y];

// from the top of the channel to its pin: straight up into a lower-edge pad, or up across the front of
// the board's USB-C end, 8 mm out, into an upper-edge one. An upper wire rises at xr: GPIO6's pad is
// straight above GND's, so its wire rises between pads - as far from GND's as the SGP41's thicker wire,
// coming straight in from the front, needs - and the 5V pad's wire comes in low, under it.
function to_pin(s, x, upper, xr) = upper
    ? [[s[0], s[1], wch_z1 + 0.8], [xr, 8.0, wch_z1 + 2.5], [xr, 8.0, z_hi - 1.5], [x, 8.0, z_hi], [x, pad_y, z_hi]]
    : [[s[0], s[1], wch_z1 + 0.8], [x, 4.6, z_lo - 0.6], [x, pad_y, z_lo]];

// the SPS30's lead: five wires out of its plug, up, over to the channel and up it
y_mid = back_t + sps_t / 2;
function lead_x(d) = conn_hi ? sps_x1 - d : sps_x0 + d;   // d from the outlet end
function sps_route(d, s, x, upper, xr = undef) = concat(
    [[lead_x(d), y_mid, z_sps1 + 3.5], [lead_x(d), y_mid, z_sps1 + cable_zone_h - 3],
     [s[0], s[1], wch_z0 - 1.5]], to_pin(s, x, upper, is_undef(xr) ? x : xr));
// GPIO6's riser stands this far aside of the GND pad, so the SGP41's thicker GND wire clears it
riser_aside = (gy_wd + wd) / 2 + 0.1;
// pin 1 to 5, read 8.6 down to 3.0 mm from the outlet end (photo 1)
sps_routes = [
    sps_route(8.6, slot(-1.1, 3.1), pin_x(1), false),                              // black  VDD -> 5V
    sps_route(7.2, slot( 1.1, 4.3), pin_x(1), true),                               // red    SDA -> GPIO5
    sps_route(5.8, slot(-1.1, 4.3), pin_x(2), true, pin_x(2) - sgn * riser_aside),     // white  SCL -> GPIO6
    sps_route(4.4, slot( 0.0, 4.3), pin_x(2), false),                              // yellow SEL -> GND
    sps_route(3.0, slot( 0.0, 3.1), pin_x(2), false)];                             // orange GND -> GND
sps_colours = [[0.10, 0.10, 0.10], [0.85, 0.10, 0.10], [0.95, 0.95, 0.95], [0.95, 0.80, 0.10], [0.95, 0.45, 0.10]];

// The SGP41's four: soldered so they come out of its back, straight towards the plate, over on bend_r
// into the room the pedestal leaves behind its pin half, then across to the board's pins and straight
// into them. Its pins run SDA, SCL, GND, VIN down its edge - the reverse of the board's order - so two
// pairs must cross. They lie in two layers a wire apart: the near one for SDA and GND, the far one for SCL
// and VIN. They stay below the board until they are past its middle, so nothing runs in front of the
// antenna half. Over the SPS30's lead they pass in front of it: the column kept clear for that lead is
// kept clear of printed parts, and the wire checks below keep them clear of the lead's own wires.
gy_pin_x = conn_hi ? gx1 - pocket_fit - 1.6 : gx0 + pocket_fit + 1.6;   // the pin row, as drawn
function gy_pin_z(off) = conn_hi ? gz0 + pocket_fit + off : gz1 - pocket_fit - off;   // off from the edge by SDA
lay_gap = gy_wd + 0.1;                                       // the two layers, centre to centre
lay     = [gy_pcb_y0 - wire_stub - bend_r, gy_pcb_y0 - wire_stub - bend_r - lay_gap];   // near, far
lo_dx = 1.5; lo_dz = 3.0;   // GND and VIN: along under the board, then up to its lower edge, just past their pin
up_dx = 1.0; up_dz = 1.85;   // SDA and SCL: under the board to just short of its middle, then up its USB-C half
up_w  = [sm_usb_x + sgn * (sm_l / 2 - up_dx), z_board0 - up_dz];
function lo_w(off, x) = [x + sgn * lo_dx, gy_pin_z(off) + lo_dz];
function gy_route(off, x, z, w, layer) = let(zs = gy_pin_z(off), y = lay[layer])
    [[gy_pin_x, gy_pcb_y0, zs], [gy_pin_x, y, zs], [w[0], y, w[1]], [x, y, z], [x, pad_y, z]];
gy_routes = [
    gy_route(2.2,  pin_x(1), z_hi, up_w,                 0),   // SDA -> GPIO5
    gy_route(4.55, pin_x(2), z_hi, up_w,                 1),   // SCL -> GPIO6
    gy_route(6.9,  pin_x(2), z_lo, lo_w(6.9,  pin_x(2)), 0),   // GND -> GND
    gy_route(9.2,  pin_x(3), z_lo, lo_w(9.2,  pin_x(3)), 1)];  // VIN -> 3V3
gy_colours = [[0.20, 0.35, 0.85], [0.20, 0.65, 0.30], [0.45, 0.30, 0.20], [0.60, 0.15, 0.55]];

// The checks, on the routes as drawn. Against the SPS30's wires too - except, for two wires that end on
// the same pad, within pad_join of it, where they are meant to meet.
pad_join = 5.0;
gy_dense  = [for (r = gy_routes) dense(rounded(r))];
sps_dense = [for (r = sps_routes) dense(rounded(r))];
function last(v) = v[len(v) - 1];
function away(d, pad, shared) = shared ? [for (p = d) if (norm(p - pad) > pad_join) p] : d;
function cross_gap(i, j) = let(pad = last(gy_routes[i]), shared = norm(last(sps_routes[j]) - pad) < 0.01)
    min_gap(away(gy_dense[i], pad, shared), away(sps_dense[j], pad, shared));
function in_ant(p) = sgn * (p[0] - sm_usb_x) + gy_wd / 2 > sm_l / 2 && p[2] + gy_wd / 2 > z_board0 && p[2] - gy_wd / 2 < z_board1;
gy_min_r   = min([for (r = gy_routes) min_radius(r)]);
// surface to surface: centre to centre, less the two wires' radii
gy_min_gap = min(concat([for (i = [0 : 2]) for (j = [i + 1 : 3]) min_gap(gy_dense[i], gy_dense[j]) - gy_wd],
                        [for (i = [0 : 3]) for (j = [0 : 4]) cross_gap(i, j) - (gy_wd + wd) / 2]));
gy_ant     = [for (d = gy_dense) for (p = d) if (in_ant(p)) p];
gy_room    = (lay[1] - gy_wd / 2) - (gy_pcb_y0 - wire_room);   // the far layer, inside the room behind the board
module check_routes() {
    // Mirroring the layout turns both boards end for end: the SGP41's pins run the other way up, and the
    // SuperMini's power pins move to its upper edge. These routes are for the layout as built.
    assert(!conn_hi, "the wire routes are laid out for outlet_at_left = false, the sensor as built");
    assert(gy_min_r >= bend_r - 0.01,
           str("an SGP41 wire bends on ", gy_min_r, " mm, tighter than bend_r ", bend_r, " - a segment is too short for its bend"));
    assert(gy_room >= -1e-6,
           str("the SGP41's far wire layer reaches ", -gy_room, " mm past the room behind its board - wire_room is too small"));
    assert(gy_min_gap >= -1e-6,
           str("an SGP41 wire runs into another wire: ", -gy_min_gap, " mm of overlap"));
    assert(len(gy_ant) == 0, str("an SGP41 wire runs in front of the board's antenna half, at ", gy_ant[0]));
    echo(str("SGP41 wires: tightest bend ", gy_min_r, " mm, ", gy_min_gap, " mm clear of the nearest other wire, ", gy_room,
             " mm inside the room behind its board"));
}

module wires() {
    for (i = [0 : 4]) wire(sps_routes[i], sps_colours[i]);   // the SPS30's lead
    // the SGP41's four, top to bottom along its pin edge: SDA, SCL, GND, VIN
    for (i = [0 : 3]) wire(gy_routes[i], gy_colours[i], gy_wd);
}

// ------------------------------------------------------------------ the views
if (view == "wiring") {
    check_routes();
    color([0.80, 0.72, 0.58]) back_plate();
    sps30(); supermini(); sgp41(); m25();
    wires();
    axes(is_undef(axes_at) ? [-22, 0, -25] : axes_at, axes_l, axes_cam, [[0, 0], [1.7, -0.3], [0, 0]]);
    translate([-18, 0, H + 38]) rotate([90, 0, 180]) color("black") linear_extrude(0.4) {
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
                 "the SPS30's five up the cable channel,",
                 "the SGP41's four out of its back, straight across;",
                 "GPIO5/6 then over the USB-C end"];
        for (i = [0 : len(lines) - 1]) translate([0, -i * 5.2]) text(lines[i], size = 3.0);
    }
}

// the back plate where the SGP41's wires run through it: must be empty
if (view == "check_wires")
    intersection() {
        back_plate();
        for (i = [0 : 3]) wire(gy_routes[i], gy_colours[i], gy_wd, fn = 6);
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
    axes([W, 0, -80], 25, [cam_rx, 0, cam_rz], [[-1, 0], [0, 0], [0, 0]]);
}
