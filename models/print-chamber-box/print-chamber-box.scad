// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
The print-chamber box: two printed parts, joined by four M3 x 14 self-tapping screws.

  BACK PLATE   printed flat. Carries the mounting tabs, the channel the SPS30 is set into from the
               front, the divider under its air face, the board's pocket, the SGP41's pedestal, the
               cable channel for the wires and the four screw bosses.
  COVER        printed front-face down. A five-sided shell.

Neither part has a bridge over air. Every opening in the cover is either a hole in its first layers or
a notch open at its back edge, and the back plate is all features rising from the bed. (The slicer
labels seven regions of the back plate "bridge infill"; all are internal, over its own sparse infill.)

  part = "back"       this file as it stands - what scripts/scad-check.sh checks
  part = "cover"      print-chamber-box-cover.scad sets it
  part = "assembly"   the two parts in place, with the components ghosted in. Not printable.

Settings are in print-chamber-box.params.scad, and why the layout is what it is - with a source for each
rule - is in docs/design.md. The checks it carries, and their controls, are in docs/checking.md.
*/
include <print-chamber-box.params.scad>

draw_model = true;

eps = 0.01;
$fa = 2;
$fs = 0.4;

function hole_r(d) = d / 2 + fdm_hole_comp;
function whole(x) = abs(x - round(x)) < 1e-6;

// =================================================================== derived: X (across the box)
ch_in_w  = sps_w + 2 * sps_nub + 2 * sps_fit;               // inside of the SPS30 channel
ch_out_w = ch_in_w + 2 * cradle_t;
W        = ch_out_w + 2 * (boss_d + 2 * part_fit) + 2 * wall;   // bosses sit beside the channel
ch_x0    = (W - ch_in_w) / 2;
ch_x1    = ch_x0 + ch_in_w;
sps_x0   = ch_x0 + sps_fit + sps_nub;                       // the sensor body, nominally centred
sps_x1   = sps_x0 + sps_w;
// "Left" means left AS YOU FACE THE BOX, which is +X here (see the coordinate note in the params file).
// So outlet_at_left puts the outlet at the HIGH-X end and the inlets at the low-X end.
x_div    = outlet_at_left ? sps_x0 + divider_from_inlet_end
                          : sps_x1 - divider_from_inlet_end;
div_clear_in  = divider_from_inlet_end - divider_t / 2 - sps_inlet_end;     // to the inlets' far end
div_clear_out = sps_outlet_from - (divider_from_inlet_end + divider_t / 2);  // to the outlet grille

// =================================================================== derived: Y (out from the wall)
ledge_w   = sps_fit + sps_nub + ledge;                      // what each ledge spans, wall to sensor
y_sps1    = back_t + sps_t;                                 // the SPS30's label face
inner_d   = max(sps_t + sps_fit + front_gap_min,
                wire_perpendicular ? ant_h + gap : sm_t + gap);
D         = back_t + inner_d + front_t;
y_in1     = D - front_t;                                    // inside face of the cover's front
// The channel walls stand 2 * gap proud of the SPS30's face. It goes in from the front - nothing on
// the plate overhangs it - and the cover's partition rib, sps_fit off its face, keeps it from tipping.
y_ch1     = y_sps1 + 2 * gap;

// =================================================================== derived: Z (up)
z_sps0      = wall;                     // the air face sits at the inside of the bottom wall: minimal depth to ambient
z_sps1      = z_sps0 + sps_h;
gy_pocket_l = gy_l + 2 * pocket_fit;
gy_pocket_w = gy_w + 2 * pocket_fit;
gy_z_base   = part_fit + rib_t + part_fit;   // the SGP41's pedestal clears the cover's baffle over the sensor
zone_h      = max(cable_zone_h + gap,                           // the SPS30 lead's bend
                  gy_z_base + gy_pocket_w + 2 * rim_t + gap);   // the SGP41's pedestal, clear of the baffle
z_board0    = z_sps1 + zone_h;
sm_pocket_h = sm_w + 2 * pocket_fit;
z_board_c   = z_board0 + rim_t + sm_pocket_h / 2;
z_board1    = z_board0 + 2 * rim_t + sm_pocket_h;
H           = z_board1 + gap + boss_d + 2 * part_fit + wall;   // the top bosses sit above the board

// =================================================================== the board
// Its USB-C end faces the SPS30's connector, which is at the outlet end. The board's power and I2C pins
// (5V, GND, 3V3, GPIO5, GPIO6) are all at its USB-C end, so every wire stays at one end of the box and
// the antenna end is left with no wire near it.
conn_hi  = outlet_at_left;             // connector at high X - your left
// The PCB's USB-C edge reaches into the wall, which is thinned to port_wall over the board's end, so the
// socket's mouth reaches the outside face. A plug's body then never enters the wall, whatever its size.
sm_usb_x = conn_hi ? W - port_wall - part_fit : port_wall + part_fit;
sm_x0    = conn_hi ? sm_usb_x - sm_l : sm_usb_x;
sm_x1    = sm_x0 + sm_l;
sm_ant_x = conn_hi ? sm_x0 : sm_x1;    // the PCB's antenna end
rim_hgt      = sm_pcb_t + 2 * fdm_layer_h;   // the rims only locate the boards; they do not hold them
usb_center_h = sm_pcb_t + usb_shell_h / 2;  // the shell sits on the component side
usb_y        = back_t + usb_center_h;
usb_proud    = usb_overhang - port_wall - part_fit;   // the mouth, past the outside face, board at rest
usb_proud_in = usb_proud - pocket_fit;   // the same, with a plug pushing the board against its stops
// The rims run from the cover's wall - they stay out of it - to the two stops past the antenna end.
stop_x0 = conn_hi ? sm_ant_x - pocket_fit - rim_t : sm_ant_x + pocket_fit;
rim_x0  = conn_hi ? stop_x0 : wall + part_fit;
rim_x1  = conn_hi ? W - wall - part_fit : stop_x0 + rim_t;
// The board slides in from the USB-C side, before the cover goes on, under a 45-degree lip on each rim.
// The lips run from its 4th pin to its antenna end, clear of the pins the node solders to - all of them
// among the first three on each edge.
pin_pitch = 2.54;                              // the SuperMini's 0.1-inch pin pitch
sm_lip_x0 = conn_hi ? rim_x0 : sm_usb_x + pin_mid + 2 * pin_pitch;
sm_lip_x1 = conn_hi ? sm_usb_x - pin_mid - 2 * pin_pitch : rim_x1;
sm_lip_l  = pocket_fit + sm_lip_over;          // each lip's reach from its rim's inner face
sm_lip_y0 = back_t + sm_pcb_t + pocket_fit;    // its underside, at that face
sm_lip_y1 = sm_lip_y0 + sm_lip_l + 2 * fdm_layer_h;   // its top

// =================================================================== the SPS30's lead
// Its plug sits on the connector face at the outlet end; the wires rise from it and bend over towards
// the board's pins. Nothing may stand in that column (photo 1, 2 Oct 2026).
lead_x0 = outlet_at_left ? sps_x1 - conn_to : sps_x0 + conn_from;
lead_x1 = outlet_at_left ? sps_x1 - conn_from : sps_x0 + conn_to;

// =================================================================== the SGP41: beside the lead, raised to its vents
// Its pins face the board's pin end, so its four wires head straight there; the sensor is at the far end.
// It stands on a pedestal that brings its sensor close behind its vents: on the plate it would sit 16 mm
// back from them and measure the box's own air. Only the bare strip at the far end of its underside rests
// on a ledge, so its parts carry no load and its board's thickness does not matter. Its wires come out of
// its back, so the pedestal carries only its far half: behind the pin half there is nothing to the plate.
gx0 = conn_hi ? lead_x0 - gap - gy_pocket_l : lead_x1 + gap;
gx1 = gx0 + gy_pocket_l;
gz0 = z_sps1 + gy_z_base + rim_t;
gz1 = gz0 + gy_pocket_w;
gy_bare_x0  = conn_hi ? gx0 + pocket_fit : gx1 - pocket_fit - gy_bare;   // the board's bare strip
gy_parts_x0 = conn_hi ? gx0 + pocket_fit + gy_bare : gx0 + pocket_fit;   // ... and the half with its parts
// The parts on the thinnest board clear the floor by `gap`, so the floor's top skin - printed over infill,
// and not perfectly flat - cannot reach them. Raising the ledge costs nothing: it lowers the floor, not
// the board.
gy_ledge_h   = gy_back - gy_pcb_min + gap;
gy_rim_h     = gy_ledge_h + gy_pcb_min / 2;          // reaches halfway up the thinnest board's edge
gy_front_max = gy_ledge_h + gy_pcb_max;              // the board's front face, above the floor, at most
gy_sensor_h  = gy_t - gy_back;
gy_floor     = y_in1 - (gy_head_h + part_fit) - gy_front_max;   // the pedestal's top: room in front for the screw's head
// The screw goes through the module's mounting hole into a blind pilot in the ledge. The hole is in the
// bare strip, by the long edge away from the sensor - and which edge of the pocket that is follows from
// which way the pins face (photo 1).
gy_hole_x      = conn_hi ? gx0 + pocket_fit + gy_hole_far : gx1 - pocket_fit - gy_hole_far;
gy_hole_z      = conn_hi ? gz1 - pocket_fit - gy_hole_side : gz0 + pocket_fit + gy_hole_side;
gy_pilot_depth = gy_screw_l - gy_pcb_min + 2 * fdm_layer_h;   // below the ledge's top
// the pedestal: from the far rim to a rim's width past the standoff, and no further towards the pins
gy_ped_x0    = conn_hi ? gx0 - rim_t : gy_hole_x - gy_standoff_d / 2 - rim_t;
gy_ped_x1    = conn_hi ? gy_hole_x + gy_standoff_d / 2 + rim_t : gx1 + rim_t;
gy_pin_half  = conn_hi ? [gx1 - gy_pocket_l / 2, gx1] : [gx0, gx0 + gy_pocket_l / 2];   // the pocket's pin half
gy_strip     = gy_bare - gap / 2;    // how far the ledge reaches under the board: short of its parts
gy_ledge_x0  = conn_hi ? gx0 : gx1 - pocket_fit - gy_strip;
gy_ledge_x1  = conn_hi ? gx0 + pocket_fit + gy_strip : gx1;
loop_z0      = z_board_c - sm_w / 2 + ant_loop_free;    // the antenna loop's lowest edge

// =================================================================== the cable channel
// Upright, directly under the board's three power pins (5V, GND, 3V3), wire_ch_l long up to just below the
// board: the wires from both sensors press in from the front past a 45-degree lip on each wall, run up it,
// and leave its top end straight into those pads. Open at both ends.
wch_lip = (wire_slot_w - wire_lip_gap) / 2;     // each lip's reach into the slot, at 45 degrees
wch_cx  = conn_hi ? sm_usb_x - pin_mid : sm_usb_x + pin_mid;
wch_x0  = wch_cx - wire_slot_w / 2 - rib_t;      // its walls' outer faces
wch_x1  = wch_cx + wire_slot_w / 2 + rib_t;
wch_z1  = z_board0 - gap;                        // its top, just below the board's rim
wch_z0  = wch_z1 - wire_ch_l;
wch_y1  = back_t + wire_slot_d + wch_lip;        // the walls' front, lips included

// =================================================================== bosses and tabs
boss_inset = wall + part_fit + boss_d / 2;
bosses     = [[boss_inset, boss_inset], [W - boss_inset, boss_inset],
              [boss_inset, H - boss_inset], [W - boss_inset, H - boss_inset]];
tab_z      = z_sps0 + sps_h / 2;
tab_hole_x = tab_l - tab_w / 2;         // from the box's side

// =================================================================== the rules
for (w = [["wall", wall], ["cradle_t", cradle_t], ["divider_t", divider_t], ["rib_t", rib_t],
          ["rim_t", rim_t], ["port_wall", port_wall], ["vent_rib", vent_rib]])
    assert(whole(w[1] / fdm_extrusion_w),
           str(w[0], " (", w[1], ") must be a whole number of ", fdm_extrusion_w,
               " mm beads - fdm-design-rules §1"));

for (t = [["back_t", back_t], ["front_t", front_t]])
    assert(whole(t[1] / fdm_layer_h),
           str(t[0], " (", t[1], ") is printed flat, so it must be a whole number of ",
               fdm_layer_h, " mm layers"));

assert(div_clear_in >= 0.5 && div_clear_out >= 0.5,
       str("the divider must sit in the blank gap between the inlets (to ", sps_inlet_end,
           " mm) and the outlet grille (from ", sps_outlet_from, " mm); it clears them by ",
           div_clear_in, " and ", div_clear_out, " mm"));
assert(x_div - divider_t / 2 > sps_x0 + ledge && x_div + divider_t / 2 < sps_x1 - ledge,
       str("the divider (at ", divider_from_inlet_end, " mm from the inlet end) does not fit between",
           " the two ledges - check divider_from_inlet_end"));

assert(pilot_d >= 2 && tab_hole_d >= 2 && gy_pilot_d >= 2,
       "a hole under 2 mm distorts or closes up - fdm-design-rules §2");

assert(y_ch1 <= y_in1 - part_fit,
       str("the SPS30 channel's walls (to ", y_ch1, ") reach the cover's front (", y_in1,
           ") - raise front_gap_min"));

assert(usb_proud_in >= -1e-6,
       str("plugging in pushes the board against its stops, and there the USB-C socket's mouth sits ",
           -usb_proud_in, " mm inside the wall - a plug's body would hit the wall before it seats.",
           " Thin port_wall, or tighten part_fit and pocket_fit"));
assert(usb_y - usb_plug_h / 2 >= 0,
       "the USB-C plug would hit the surface the box is screwed to - the board sits too low");
assert(abs(z_board_c - tab_z) >= (usb_plug_w + tab_w) / 2 + gap,
       "the USB-C plug would hit the mounting tab on its side");
assert(2 * stop_reach < sm_pocket_h,
       "the two stops at the board's antenna end meet - stop_reach is too large");
assert(sm_lip_over < sm_edge,
       "the rails' lips would reach past the SuperMini's pad strip onto its parts - check sm_lip_over");
assert(sm_lip_x1 - sm_lip_x0 >= 2 * pin_pitch, "the rails' lips have no length - check pin_mid");
assert(stop_reach - pocket_fit + gap <= ant_loop_free,
       str("the stops at the board's antenna end reach ", stop_reach - pocket_fit, " mm over it, and the",
           " antenna loop leaves only ", ant_loop_free, " mm free - reduce stop_reach"));

assert(wire_perpendicular || (conn_hi ? sm_x0 - ant_h - gap >= wall : sm_x1 + ant_h + gap <= W - wall),
       "an antenna wire running past the board's end does not fit inside the box");

assert(gy_floor > back_t + gap,
       str("the SGP41's pedestal has no height (its top at ", gy_floor, ") - the bounds are too large"));
assert(gy_ped_x0 >= ch_x0 && gy_ped_x1 <= ch_x1,
       "the SGP41's pedestal reaches past the cover's baffle, which it is raised to clear");
assert(gy_ped_x0 >= wall + gap && gy_ped_x1 <= W - wall - gap,
       "the SGP41's pedestal does not fit between the side walls");
assert(gy_bare + pocket_fit < gy_pocket_l / 2,
       "the SGP41's ledge would reach the parts on its underside - check gy_bare");
assert(gy_rim_h < gy_ledge_h + gy_pcb_min,
       "the SGP41's rim would stand above its board's face, under the screw's head");
assert(gy_hole_d >= gy_screw_d + 0.1,
       str("the SGP41's mounting hole (", gy_hole_d, " mm) is too small for an M", gy_screw_d,
           " screw - use a smaller one and set gy_screw_d, gy_head_d and gy_head_h"));
assert(gy_pilot_d / 2 + 2 * fdm_extrusion_w <= gy_standoff_d / 2,
       "the standoff round the SGP41's pilot is thinner than two beads - widen gy_standoff_d");
assert(gy_standoff_d > gy_hole_d,
       "the SGP41's standoff is no wider than its mounting hole - the board would have nothing to rest on");
assert(gy_strip > 0, "the SGP41's ledge has no depth - check gy_bare");
assert(gy_ledge_x0 >= gy_ped_x0 && gy_ledge_x1 <= gy_ped_x1,
       "the SGP41's ledge runs off the end of its pedestal - check gy_bare and gy_standoff_d");
assert(gy_pilot_depth + gap <= gy_ledge_h + gy_floor - back_t,
       "the SGP41's screw would run out of pedestal");
assert(loop_z0 - (gz1 + rim_t) >= gap,
       str("the SGP41's pedestal reaches within ", loop_z0 - (gz1 + rim_t), " mm of the antenna loop"));
// signed: negative means the channel is on the wrong side of the wall or of the lead
wch_wall_room = conn_hi ? (W - wall) - wch_x1 : wch_x0 - wall;
wch_lead_room = conn_hi ? wch_x0 - lead_x1 : lead_x0 - wch_x1;
assert(wch_wall_room >= gap && wch_lead_room >= gap,
       str("the cable channel, under the board's power pins, must stand clear of the side wall and of the",
           " SPS30's lead; it leaves ", wch_wall_room, " and ", wch_lead_room, " mm"));
assert(wire_ch_l >= wire_slot_w, "the cable channel is shorter than it is wide - it would not hold a wire");
assert(wch_z0 >= z_sps1 + gap, "the cable channel reaches down to the SPS30 - shorten wire_ch_l");
assert(wch_lip > 0 && wire_lip_gap >= 2 * fdm_extrusion_w,
       "the cable channel's lips must narrow its slot and leave an opening at least two beads wide");

// =================================================================== geometry helpers
// A 2D rectangle with its convex corners rounded: shrink, then grow (lesson 5 of docs/openscad-basics).
module rrect(w, h, r) {
    if (r > 0) offset(r = r) offset(delta = -r) square([w, h]);
    else square([w, h]);
}

// A block spanning the given X, Y and Z ranges, its corners rounded as seen from the front.
module slab_xz(x0, x1, y0, y1, z0, z1, r = 0) {
    translate([0, y1, 0])
        rotate([90, 0, 0])
            linear_extrude(height = y1 - y0)
                translate([x0, z0]) rrect(x1 - x0, z1 - z0, r);
}

// A cylinder along Y.
module cyl_y(x, z, r, y0, y1) {
    translate([x, y0, z]) rotate([-90, 0, 0]) cylinder(r = r, h = y1 - y0);
}

// Vertical slots through the cover's front, spread across [x0, x1].
module vent_slots(x0, x1, z0, z1) {
    n     = floor((x1 - x0 + vent_rib) / (vent_w + vent_rib));
    used  = n * vent_w + (n - 1) * vent_rib;
    start = x0 + (x1 - x0 - used) / 2;
    if (n > 0)
        for (i = [0 : n - 1])
            translate([start + i * (vent_w + vent_rib), y_in1 - eps, z0])
                cube([vent_w, front_t + 2 * eps, z1 - z0]);
}

// =================================================================== the back plate, as installed
module back_plate() {
    difference() {
        union() {
            // the plate, and its two mounting tabs
            slab_xz(0, W, 0, back_t, 0, H, corner_r);
            for (side = [0, 1])
                slab_xz(side == 0 ? -tab_l : W - corner_r,
                        side == 0 ? corner_r : W + tab_l,
                        0, back_t, tab_z - tab_w / 2, tab_z + tab_w / 2, tab_w / 2 - eps);

            // the channel walls the SPS30 is set between, from the front. No lips: anything overhanging
            // its face would have to be slid past, and the board's rims and the SGP41's pedestal stand in
            // the way from above. Down to Z = 0, through the window, so the ledges join them by a FACE -
            // meeting along an edge only is not manifold (docs/openscad-basics, lesson 2).
            for (xw = [ch_x0 - cradle_t, ch_x1])
                translate([xw, back_t - eps, 0]) cube([cradle_t, y_ch1 - back_t + eps, z_sps1]);

            // the ledges the sensor stands on, one under each end of the air face
            translate([ch_x0 - cradle_t / 2, back_t - eps, 0]) cube([ledge_w + cradle_t / 2, sps_t + eps, z_sps0]);
            translate([ch_x1 - ledge_w, back_t - eps, 0]) cube([ledge_w + cradle_t / 2, sps_t + eps, z_sps0]);

            // the divider: it also carries the sensor, and stands proud below the box. It rises from
            // the very back (Y = 0) so that the part below the plate still starts on the bed.
            translate([x_div - divider_t / 2, 0, -divider_proud])
                cube([divider_t, y_in1 - part_fit, divider_proud + z_sps0]);

            // the board pocket: rims along the two long edges. Outwards, the PCB's USB-C end bears on
            // the cover's thinned wall when a plug is pulled out.
            for (zz = [z_board0, z_board1 - rim_t])
                translate([rim_x0, back_t - eps, zz]) cube([rim_x1 - rim_x0, rim_hgt + eps, rim_t]);
            // and on each rim a lip with a 45-degree underside, over the board's pad strip from its 4th
            // pin to its antenna end: it slides in under them, and they keep it down on the plate.
            // Their cross-section in Y-Z, run along X.
            translate([sm_lip_x0, 0, 0]) rotate([90, 0, 90]) linear_extrude(height = sm_lip_x1 - sm_lip_x0) {
                zi = z_board0 + rim_t;   // the rims' inner faces
                zo = z_board1 - rim_t;
                polygon([[back_t - eps, z_board0], [sm_lip_y1, z_board0], [sm_lip_y1, zi + sm_lip_l],
                         [sm_lip_y0 + sm_lip_l, zi + sm_lip_l], [sm_lip_y0, zi], [back_t - eps, zi]]);
                polygon([[back_t - eps, z_board1], [sm_lip_y1, z_board1], [sm_lip_y1, zo - sm_lip_l],
                         [sm_lip_y0 + sm_lip_l, zo - sm_lip_l], [sm_lip_y0, zo], [back_t - eps, zo]]);
            }
            // inwards, a stop over each corner of the antenna end takes the push of plugging in. The
            // middle of that end stays open, because the antenna loop lies in the board's plane past it.
            for (zz = [z_board0, z_board1 - rim_t - stop_reach])
                translate([stop_x0, back_t - eps, zz]) cube([rim_t, rim_hgt + eps, rim_t + stop_reach]);

            // the SGP41's pedestal, under its far half only, with its rim on three sides - open towards
            // the pins, whose wires leave the board's back - and the ledge its bare strip rests on
            translate([gy_ped_x0, back_t - eps, gz0 - rim_t])
                cube([gy_ped_x1 - gy_ped_x0, gy_floor - back_t + eps, gy_pocket_w + 2 * rim_t]);
            for (zz = [gz0 - rim_t, gz1])
                translate([gy_ped_x0, gy_floor - eps, zz]) cube([gy_ped_x1 - gy_ped_x0, gy_rim_h + eps, rim_t]);
            translate([conn_hi ? gx0 - rim_t : gx1, gy_floor - eps, gz0 - rim_t])
                cube([rim_t, gy_rim_h + eps, gy_pocket_w + 2 * rim_t]);
            translate([gy_ledge_x0, gy_floor - eps, gz0])
                cube([gy_ledge_x1 - gy_ledge_x0, gy_ledge_h + eps, gy_pocket_w]);
            // and the standoff round the mounting hole, level with the ledge: the screw clamps the board
            // onto it, the one bare patch of its underside that reaches past the strip
            cyl_y(gy_hole_x, gy_hole_z, gy_standoff_d / 2, gy_floor - eps, gy_floor + gy_ledge_h);

            // the cable channel: two upright walls under the board's power pins, each with a 45-degree
            // lip over the slot, so the wires press in past the lips and stay. Its cross-section in X-Y,
            // run up Z.
            translate([0, 0, wch_z0]) linear_extrude(height = wch_z1 - wch_z0) {
                xi0 = wch_cx - wire_slot_w / 2;   // the slot's two faces
                xi1 = wch_cx + wire_slot_w / 2;
                polygon([[xi0 - rib_t, back_t - eps], [xi0, back_t - eps], [xi0, back_t + wire_slot_d],
                         [xi0 + wch_lip, wch_y1], [xi0 - rib_t, wch_y1]]);
                polygon([[xi1 + rib_t, back_t - eps], [xi1, back_t - eps], [xi1, back_t + wire_slot_d],
                         [xi1 - wch_lip, wch_y1], [xi1 + rib_t, wch_y1]]);
            }

            // the four bosses the cover screws into
            for (b = bosses) cyl_y(b[0], b[1], boss_d / 2, back_t - eps, y_in1);
        }
        // pilot holes - blind, so the plate behind stays whole
        for (b = bosses) cyl_y(b[0], b[1], hole_r(pilot_d), back_t + 1.0, y_in1 + eps);
        // the pilot for the SGP41's screw, blind, down from the ledge's top
        cyl_y(gy_hole_x, gy_hole_z, hole_r(gy_pilot_d), gy_floor + gy_ledge_h - gy_pilot_depth,
              gy_floor + gy_ledge_h + eps);
        // mounting holes in the tabs
        cyl_y(-tab_hole_x, tab_z, hole_r(tab_hole_d), -eps, back_t + eps);
        cyl_y(W + tab_hole_x, tab_z, hole_r(tab_hole_d), -eps, back_t + eps);
    }
}

// =================================================================== the cover, as installed
module cover() {
    difference() {
        slab_xz(0, W, back_t, D, 0, H, corner_r);
        // hollow it: four walls and a front
        slab_xz(wall, W - wall, back_t - eps, y_in1, wall, H - wall, max(corner_r - wall, 0));
        // the window over the SPS30's air face - open at the back edge, so it is a notch, not a bridge
        translate([ch_x0 - cradle_t - part_fit, back_t - eps, -eps])
            cube([ch_in_w + 2 * (cradle_t + part_fit), y_in1 - back_t + eps, wall + 2 * eps]);
        // the wall over the board's USB-C end, thinned from inside to port_wall and as tall as the
        // board's tallest part - a notch open at the back edge. Its step back to the full wall is a
        // 45-degree chamfer, not a square corner: pulling the plug loads this stretch of wall, and a
        // crack would start at a sharp inside corner.
        hull() {
            translate([conn_hi ? W - wall - eps : port_wall, back_t - eps, z_board_c - sm_pocket_h / 2])
                cube([wall - port_wall + eps, sm_t + part_fit + eps, sm_pocket_h]);
            translate([conn_hi ? W - wall - eps : wall - eps, back_t - eps,
                       z_board_c - sm_pocket_h / 2 - (wall - port_wall)])
                cube([2 * eps, sm_t + part_fit + (wall - port_wall) + eps, sm_pocket_h + 2 * (wall - port_wall)]);
        }
        // the USB-C opening through it, the size of the socket's shell - also open at the back edge
        translate([conn_hi ? W - wall - eps : -eps, back_t - eps, z_board_c - usb_shell_w / 2 - part_fit])
            cube([wall + 2 * eps, usb_y + usb_shell_h / 2 + part_fit - back_t + eps,
                  usb_shell_w + 2 * part_fit]);
        // vents: in front of the SGP41, and in front of the board
        vent_slots(gx0, gx1, gz0, gz1);
        vent_slots(max(sm_x0, wall + gap), min(sm_x1, W - wall - gap), z_board0 + rim_t, z_board1 - rim_t);
        // clearance holes for the four screws
        for (b = bosses) cyl_y(b[0], b[1], hole_r(screw_d), y_in1 - eps, D + eps);
    }
    // the partition between the inlet and outlet sides of the air gap in front of the sensor
    // part_fit above the divider fin, which it slides past as the cover goes on
    translate([x_div - rib_t / 2, y_sps1 + sps_fit, z_sps0 + part_fit])
        cube([rib_t, y_in1 - y_sps1 - sps_fit + eps, sps_h - part_fit]);
    // the baffle that closes that air gap off from the warm compartment above, part_fit over the
    // sensor's top. With the partition it also keeps the SPS30 from tipping forward, sps_fit off its face.
    translate([ch_x0, y_sps1 + sps_fit, z_sps1 + part_fit])
        cube([ch_in_w, y_in1 - y_sps1 - sps_fit + eps, rib_t]);
}

// =================================================================== the SPS30's way in
// The sensor goes in from the front, before the cover: its outline, nubs included, swept from its seat to
// the cover's front. Nothing on the back plate may stand in it - check_insert intersects the two.
module sps_insert_path()
    translate([sps_x0 - sps_nub, back_t + 0.02, z_sps0 + 0.02])
        cube([sps_w + 2 * sps_nub, y_in1 - back_t, sps_h - 0.04]);

// =================================================================== the SuperMini, piece by piece
// Five pieces, so the slide-in check can sweep each one on its own: a hull of the whole board would fill
// the space between its antenna wire and its edges, which is exactly where the rails' lips are.
module sm_piece(i, s) {
    if (i == 0)        // the bare PCB
        color("teal") translate([sm_x0 + s, back_t + s, z_board_c - sm_w / 2 + s])
            cube([sm_l - 2 * s, sm_pcb_t - 2 * s, sm_w - 2 * s]);
    else if (i == 1)   // its parts, up to the tallest, clear of the pad strip along each long edge
        color("teal") translate([sm_x0 + s, back_t + sm_pcb_t - s, z_board_c - sm_w / 2 + sm_edge + s])
            cube([sm_l - 2 * s, sm_t - sm_pcb_t, sm_w - 2 * sm_edge - 2 * s]);
    else if (i == 2)   // the USB-C shell, overhanging the PCB through the wall's opening
        color("teal") translate([conn_hi ? sm_usb_x + s : sm_usb_x - usb_overhang + s, usb_y - usb_shell_h / 2 + s,
                                 z_board_c - usb_shell_w / 2 + s])
            cube([usb_overhang - 2 * s, usb_shell_h - 2 * s, usb_shell_w - 2 * s]);
    else if (i == 3)   // the antenna loop, in the board's plane past its end
        color("orange") translate([conn_hi ? sm_ant_x - ant_over + s : sm_ant_x + s, back_t + sm_pcb_t + s,
                                   z_board_c - sm_w / 2 + ant_loop_free + s])
            cube([ant_over - 2 * s, 1 - 2 * s, sm_w - 2 * ant_loop_free - 2 * s]);
    else if (i == 4)   // the antenna's straight wire
        color("orange")
            if (wire_perpendicular)
                cyl_y(conn_hi ? sm_ant_x + 1.5 : sm_ant_x - 1.5, z_board_c, 0.5 - s,
                      back_t + sm_pcb_t + s, back_t + ant_h - s);
            else
                translate([conn_hi ? sm_ant_x - ant_h + s : sm_ant_x + s, back_t + sm_pcb_t, z_board_c])
                    cube([ant_h - 2 * s, 1, 1]);
}

// The board's way in: each piece swept from clear of the plate's USB-C side to its seat against the stops.
module sm_slide_path(s = 0.02) {
    dx = conn_hi ? sm_l + ant_over + gap : -(sm_l + ant_over + gap);
    for (i = [0 : 4]) hull() { sm_piece(i, s); translate([dx, 0, 0]) sm_piece(i, s); }
}

// =================================================================== the components, for preview and checks
module components(shrink = 0) {
    s = shrink;
    color("silver") translate([sps_x0 + s, back_t + s, z_sps0 + s])
        cube([sps_w - 2 * s, sps_t - 2 * s, sps_h - 2 * s]);
    for (i = [0 : 4]) sm_piece(i, s);   // the SuperMini
    // the body of the largest compliant plug, seated, with the board pushed against its stops. Its
    // face can come right up to the socket's mouth, so that is where it is drawn.
    color("dimgray") translate([conn_hi ? W + usb_proud_in + s : -usb_proud_in - 20 + s, usb_y - usb_plug_h / 2 + s,
                                z_board_c - usb_plug_w / 2 + s])
        cube([20 - 2 * s, usb_plug_h - 2 * s, usb_plug_w - 2 * s]);
    // the GY-SGP41, as the envelope of every board thickness within the bounds: the bare strip on its
    // ledge, and the half with the parts hanging towards the floor
    color("green") {
        translate([gy_bare_x0 + s, gy_floor + gy_ledge_h + s, gz0 + pocket_fit + s])
            cube([gy_bare - 2 * s, gy_front_max + gy_sensor_h - gy_ledge_h - 2 * s, gy_w - 2 * s]);
        // the half with its parts - less the bare patch round the mounting hole (gy_hole_bare_d, read off
        // photo 2), where the standoff goes. Its own setting, so a standoff too wide shows as a collision.
        difference() {
            translate([gy_parts_x0 + s, gy_floor + gap + s, gz0 + pocket_fit + s])
                cube([gy_l - gy_bare - 2 * s, gy_front_max + gy_sensor_h - gap - 2 * s, gy_w - 2 * s]);
            cyl_y(gy_hole_x, gy_hole_z, gy_hole_bare_d / 2 - s, gy_floor, gy_floor + gy_front_max + gy_sensor_h);
        }
    }
    // the room behind the pin half, wire_room deep, where the wires leave the board's back and bend over
    color("purple") translate([gy_pin_half[0] + s, gy_floor + gy_ledge_h - wire_room + s, gz0 + s])
        cube([gy_pin_half[1] - gy_pin_half[0] - 2 * s, wire_room - 2 * s, gy_pocket_w - 2 * s]);
    // the screw's head, on the thickest board - the nearest it comes to the cover
    color("silver") cyl_y(gy_hole_x, gy_hole_z, gy_head_d / 2 - s, gy_floor + gy_front_max + s,
                          gy_floor + gy_front_max + gy_head_h - s);
    // the SPS30's plug and the column its lead rises through before it bends over
    color("orange") translate([lead_x0 + s, back_t + s, z_sps1 + s])
        cube([lead_x1 - lead_x0 - 2 * s, sps_t - 2 * s, cable_zone_h - 2 * s]);
}

// =================================================================== what gets drawn
if (len(unmeasured) > 0)
    echo(str("WARNING: ", len(unmeasured), " dimensions are placeholders, not measurements: ", unmeasured));
if (len(untested_fits) > 0)
    echo(str("WARNING: these fits have not been tested in ASA on this printer: ", untested_fits));

echo(str("print-chamber box: ", W, " x ", H, " x ", D, " mm (width x height x depth, installed), plus a ",
         tab_l, " mm tab each side and the divider ", divider_proud, " mm below"));
echo(str("outlet at the ", outlet_at_left ? "LEFT" : "RIGHT", " end; divider at ", divider_from_inlet_end,
         " mm from the inlet end; depth set by the ", inner_d == sps_t + sps_fit + front_gap_min
         ? "SPS30" : "antenna wire"));
echo(str("SGP41: its sensor ", y_in1 - (gy_floor + gy_front_max + gy_sensor_h), " to ",
         y_in1 - (gy_floor + gy_ledge_h + gy_pcb_min + gy_sensor_h), " mm behind the vents' inner face; its pedestal ",
         loop_z0 - (gz1 + rim_t), " mm below the antenna loop; held by an M", gy_screw_d, " x ", gy_screw_l,
         " screw in a ", gy_pilot_depth, " mm pilot"));
echo(str("USB-C: the socket's mouth stands ", usb_proud_in, " to ", usb_proud + part_fit,
         " mm past the outside face; any plug body up to ", 2 * usb_y,
         " mm thick clears the mounting surface (a compliant one is at most ", usb_plug_h, ")"));

if (draw_model) {
    if (part == "back")
        rotate([90, 0, 0]) back_plate();
    else if (part == "cover")
        translate([0, 0, D]) rotate([-90, 0, 0]) cover();
    else if (part == "assembly") {
        back_plate();
        %cover();
        %components();
    }
    else if (part == "check_parts")
        intersection() { back_plate(); cover(); }
    else if (part == "check_components")
        intersection() { union() { back_plate(); cover(); } components(shrink = 0.02); }
    else if (part == "check_insert")
        intersection() { back_plate(); sps_insert_path(); }
    else if (part == "check_slide")
        intersection() { back_plate(); sm_slide_path(); }
    else
        assert(false, str("unknown part \"", part, "\" - use back, cover or assembly"));
}
