// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
The print-chamber box: two printed parts, joined by four M3 x 14 self-tapping screws.

  BACK PLATE   printed flat. Carries the mounting tabs, the channel the SPS30 slides down into, the
               divider under its air face, the two board pockets and the four screw bosses.
  COVER        printed front-face down. A five-sided shell.

Neither part has a bridge. Every opening in the cover is either a hole in its first layers or a notch
open at its back edge, and the back plate is all features rising from the bed.

  part = "back"       this file as it stands - what scripts/scad-check.sh checks
  part = "cover"      print-chamber-box-cover.scad sets it
  part = "assembly"   the two parts in place, with the components ghosted in. Not printable.

Settings are in print-chamber-box.params.scad, and why the layout is what it is - with a source for each
rule - is in README.md.
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

// =================================================================== derived: Y (out from the wall)
y_sps1    = back_t + sps_t;                                 // the SPS30's label face
inner_d   = max(sps_t + sps_fit + front_gap_min,
                wire_perpendicular ? sm_pcb_t + wire_h + gap : sm_t + gap);
D         = back_t + inner_d + front_t;
y_in1     = D - front_t;                                    // inside face of the cover's front
y_lip0    = y_sps1 + sps_fit;
lip_reach = sps_fit + sps_nub + lip;
y_lip1    = y_lip0 + lip_reach + 0.6;                       // 45-degree underside, then a flat top

// =================================================================== derived: Z (up)
z_sps0      = wall;                     // the air face sits at the inside of the bottom wall: minimal depth to ambient
z_sps1      = z_sps0 + sps_h;
gy_pocket_l = gy_l + 2 * pocket_fit;
gy_pocket_w = gy_w + 2 * pocket_fit;
zone_h      = max(cable_zone_h, gy_pocket_w + 2 * rim_t + 2 * gap);   // cable + SGP41, between sensor and board
z_board0    = z_sps1 + zone_h;
sm_pocket_h = sm_w + 2 * pocket_fit;
z_board_c   = z_board0 + rim_t + sm_pocket_h / 2;
z_board1    = z_board0 + 2 * rim_t + sm_pocket_h;
H           = z_board1 + gap + boss_d + 2 * part_fit + wall;   // the top bosses sit above the board

// =================================================================== the board: USB-C out of the +X wall - YOUR LEFT as you face the box
sm_x1   = W - wall - part_fit;          // USB-C edge
sm_x0   = sm_x1 - sm_l;                 // antenna end
rim_hgt = sm_pcb_t + 2 * fdm_layer_h;   // the rims only locate the boards; they do not hold them
usb_y   = back_t + usb_center_h;

// =================================================================== the SGP41: cable zone, inlet end
gx1 = outlet_at_left ? ch_x0 + gap + gy_pocket_l : ch_x1 - gap;   // inlets at low X when the outlet is on your left
gx0 = gx1 - gy_pocket_l;
gz0 = z_sps1 + (zone_h - gy_pocket_w) / 2;
gz1 = gz0 + gy_pocket_w;

// =================================================================== bosses and tabs
boss_inset = wall + part_fit + boss_d / 2;
bosses     = [[boss_inset, boss_inset], [W - boss_inset, boss_inset],
              [boss_inset, H - boss_inset], [W - boss_inset, H - boss_inset]];
tab_z      = z_sps0 + sps_h / 2;
tab_hole_x = tab_l - tab_w / 2;         // from the box's side

// =================================================================== the rules
for (w = [["wall", wall], ["cradle_t", cradle_t], ["divider_t", divider_t], ["rib_t", rib_t],
          ["rim_t", rim_t], ["vent_rib", vent_rib]])
    assert(whole(w[1] / fdm_extrusion_w),
           str(w[0], " (", w[1], ") must be a whole number of ", fdm_extrusion_w,
               " mm beads - fdm-design-rules §1"));

for (t = [["back_t", back_t], ["front_t", front_t]])
    assert(whole(t[1] / fdm_layer_h),
           str(t[0], " (", t[1], ") is printed flat, so it must be a whole number of ",
               fdm_layer_h, " mm layers"));

assert(x_div - divider_t / 2 > sps_x0 + ledge && x_div + divider_t / 2 < sps_x1 - ledge,
       str("the divider (at ", divider_from_inlet_end, " mm from the inlet end) does not fit between",
           " the two ledges - check divider_from_inlet_end"));

assert(pilot_d >= 2 && tab_hole_d >= 2,
       "a hole under 2 mm distorts or closes up - fdm-design-rules §2");

assert(y_lip1 <= y_in1 - part_fit,
       str("the channel's front lips (to ", y_lip1, ") reach the cover's front (", y_in1,
           ") - raise front_gap_min"));

assert(usb_y - usb_plug_h / 2 >= 0,
       "the USB-C plug would hit the surface the box is screwed to - the board sits too low");

assert(wire_perpendicular || sm_x0 - wire_h - gap >= wall,
       "an antenna wire running past the board's end does not fit inside the box");

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

            // the channel the SPS30 slides down into, with its front lips
            for (side = [0, 1]) {
                xw = side == 0 ? ch_x0 - cradle_t : ch_x1;
                // down to Z = 0, through the window, so the ledges join it by a FACE - meeting along
                // an edge only is not manifold (docs/openscad-basics, lesson 2)
                translate([xw, back_t - eps, 0]) cube([cradle_t, y_lip1 - back_t + eps, z_sps1]);
                // the lip: a 45-degree underside, so it needs no support
                translate([0, 0, z_sps0])
                    linear_extrude(height = sps_h)
                        if (side == 0)
                            polygon([[ch_x0 - cradle_t / 2, y_lip0], [ch_x0, y_lip0],
                                     [ch_x0 + lip_reach, y_lip0 + lip_reach],
                                     [ch_x0 + lip_reach, y_lip1], [ch_x0 - cradle_t / 2, y_lip1]]);
                        else
                            polygon([[ch_x1 + cradle_t / 2, y_lip0], [ch_x1, y_lip0],
                                     [ch_x1 - lip_reach, y_lip0 + lip_reach],
                                     [ch_x1 - lip_reach, y_lip1], [ch_x1 + cradle_t / 2, y_lip1]]);
            }

            // the ledges the sensor stands on, one under each end of the air face
            ledge_w = sps_fit + sps_nub + ledge;
            translate([ch_x0 - cradle_t / 2, back_t - eps, 0]) cube([ledge_w + cradle_t / 2, sps_t + eps, z_sps0]);
            translate([ch_x1 - ledge_w, back_t - eps, 0]) cube([ledge_w + cradle_t / 2, sps_t + eps, z_sps0]);

            // the divider: it also carries the sensor, and stands proud below the box. It rises from
            // the very back (Y = 0) so that the part below the plate still starts on the bed.
            translate([x_div - divider_t / 2, 0, -divider_proud])
                cube([divider_t, y_in1 - part_fit, divider_proud + z_sps0]);

            // the board pocket: three sides of rim, open at the USB-C end
            translate([sm_x0 - pocket_fit - rim_t, back_t - eps, z_board0])
                cube([rim_t, rim_hgt + eps, z_board1 - z_board0]);
            for (zz = [z_board0, z_board1 - rim_t])
                translate([sm_x0 - pocket_fit - rim_t, back_t - eps, zz])
                    cube([sm_x1 - (sm_x0 - pocket_fit - rim_t), rim_hgt + eps, rim_t]);

            // the SGP41 pocket: four sides of rim
            difference() {
                translate([gx0 - rim_t, back_t - eps, gz0 - rim_t])
                    cube([gy_pocket_l + 2 * rim_t, rim_hgt + eps, gy_pocket_w + 2 * rim_t]);
                translate([gx0, back_t - 2 * eps, gz0]) cube([gy_pocket_l, rim_hgt + 3 * eps, gy_pocket_w]);
            }

            // the four bosses the cover screws into
            for (b = bosses) cyl_y(b[0], b[1], boss_d / 2, back_t - eps, y_in1);
        }
        // pilot holes - blind, so the plate behind stays whole
        for (b = bosses) cyl_y(b[0], b[1], hole_r(pilot_d), back_t + 1.0, y_in1 + eps);
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
        // the USB-C opening in the +X wall (your left) - also a notch open at the back edge
        translate([W - wall - eps, back_t - eps, z_board_c - usb_plug_w / 2 - part_fit])
            cube([wall + 2 * eps, usb_y + usb_plug_h / 2 + part_fit - back_t + eps,
                  usb_plug_w + 2 * part_fit]);
        // vents: in front of the SGP41, and in front of the board
        vent_slots(gx0, gx1, gz0, gz1);
        vent_slots(sm_x0, sm_x1 - gap, z_board0 + rim_t, z_board1 - rim_t);
        // clearance holes for the four screws
        for (b = bosses) cyl_y(b[0], b[1], hole_r(screw_d), y_in1 - eps, D + eps);
    }
    // the partition between the inlet and outlet sides of the air gap in front of the sensor
    // part_fit above the divider fin, which it slides past as the cover goes on
    translate([x_div - rib_t / 2, y_sps1 + sps_fit, z_sps0 + part_fit])
        cube([rib_t, y_in1 - y_sps1 - sps_fit + eps, sps_h - part_fit]);
    // the baffle that closes that air gap off from the warm compartment above
    // part_fit above the channel's lips, which it slides past as the cover goes on
    translate([ch_x0, y_sps1 + sps_fit, z_sps1 + part_fit])
        cube([ch_in_w, y_in1 - y_sps1 - sps_fit + eps, rib_t]);
}

// =================================================================== the components, for preview and checks
module components(shrink = 0) {
    s = shrink;
    color("silver") translate([sps_x0 + s, back_t + s, z_sps0 + s])
        cube([sps_w - 2 * s, sps_t - 2 * s, sps_h - 2 * s]);
    color("teal") translate([sm_x0 + s, back_t + s, z_board_c - sm_w / 2 + s])
        cube([sm_l - 2 * s, sm_t - 2 * s, sm_w - 2 * s]);
    color("orange")
        if (wire_perpendicular)
            cyl_y(sm_x0 + 1.5, z_board_c, 0.5 - s, back_t + sm_pcb_t + s, back_t + sm_pcb_t + wire_h - s);
        else
            translate([sm_x0 - wire_h + s, back_t + sm_pcb_t, z_board_c]) cube([wire_h - 2 * s, 1, 1]);
    color("green") translate([gx0 + pocket_fit + s, back_t + s, gz0 + pocket_fit + s])
        cube([gy_l - 2 * s, gy_t - 2 * s, gy_w - 2 * s]);
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
    else
        assert(false, str("unknown part \"", part, "\" - use back, cover or assembly"));
}
