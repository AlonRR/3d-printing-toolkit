// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
The clearance test for the print-chamber box: one small print that tries every untested fit in
print-chamber-box.params.scad at three settings - a step tighter, as set, and a step looser - so the box
is printed with fits that were tried in ASA on this printer rather than guessed.

It INCLUDES the box, and every piece is the box's own geometry - its nut pocket, its SGP41 standoff and
pilot, its clips - drawn by the box's own modules with only the fit changed, and turned onto the bed as
the back plate is. So the test cannot drift from what it tests, and each piece prints the way it will in
the box. Each try carries 1, 2 or 3 dots: 1 = a step tighter, 2 = as set, 3 = a step looser.
docs/clearance-test.md says what to try with each, how to turn the result into a setting, and what has
been found so far.

  J  nut_fit      three nut pockets, open on the bed side as the back plate's are
  K  gy_pilot_d   three SGP41 standoffs, each with its pilot sideways, as the box's
  L  clasp_pinch  three pairs of the SuperMini's back clips, as far apart as the box's

The fits the first round, of 2 Oct 2026, settled are not tried again; its pieces are in the history.

draw_fits = false after including this file draws nothing, as fits-map.scad does.
*/
include <print-chamber-box.scad>
draw_model = false;   // after the include: the box's own parts stay undrawn
draw_fits = true;

fit_step = 0.1;             // the step for every fit here
m = 3;                      // margin round and between the pieces
row = 4;                    // gap in front of each try, towards the printer's front
dot_d = 1.5;                // the tags: about three beads across, two layers proud
dots_w = 3 * dot_d + 2 * 0.7;   // three of them in a row
base_t = 6 * fdm_layer_h;   // 1.2 mm: the floor everything stands on

function ladder(v, s) = [v - s, v, v + s];
nut_fits  = ladder(nut_fit, fit_step);       // smaller is tighter
gy_pilots = ladder(gy_pilot_d, fit_step);    // smaller is tighter
// A bigger pinch is the TIGHTER clip, so this ladder runs the other way: 1 dot still means a step tighter.
pinches   = [clasp_pinch + fit_step, clasp_pinch, clasp_pinch - fit_step];

// The box's geometry is drawn in its own frame - X across, Y out from the wall, Z up - and the back plate
// prints flat on its back. This is the turn its part file makes: the box's Y comes up off the bed.
module to_bed() rotate([90, 0, 0]) children();

// ------------------------------------------------------------------ J: the nut pockets
// The box's nut boss, as tall as the pocket, its bridging layers and a cap the screw passes through.
j_r = nut_pocket_r(max(nut_fits)) + 2 * fdm_extrusion_w;   // two beads round the loosest pocket's corners
j_h = up_to_layer(nut_y1 + 2 * fdm_layer_h + 2);
// ------------------------------------------------------------------ K: the SGP41 standoffs
// In the box the block backs onto the SPS30 channel's wall, which the pilot stops short of; so the piece
// carries that much of the wall too.
k_x0 = ch_x1;                               // the channel wall's inside face, in the box's X
k_r  = gy_standoff_d / 2 + rim_t;           // the block's half-height round the hole
module k_piece(d) difference() {            // in the box's frame, on a pad of plate
    union() {
        gy_holder();
        box3([k_x0, back_t - eps, gy_hz - k_r], [k_x0 + cradle_t, gy_hy + k_r, gy_hz + k_r]);
        box3([k_x0 - 1, 0, gy_hz - k_r - 1], [gy_xs + 1, back_t, gy_hz + k_r + 1]);
    }
    gy_pilot(d);
}
// ------------------------------------------------------------------ L: the back clips
l_c0 = clasp_xs[0][0];                      // the clips' run along the board's back edge, in the box's X
l_c1 = clasp_xs[1][1];
l_m  = 1.5;                                 // the pad round them
l_z1 = zu + clip_g_mouth + rim_t + l_m;     // the pad's top, in the box's Z
module l_piece(pinch) {                     // in the box's frame, on a pad of plate
    box3([l_c0 - l_m, 0, z_f0 - l_m], [l_c1 + l_m, back_t, l_z1]);
    for (c = clasp_xs) clip(c, sm_pcb_t - pinch);
}
l_board_out = l_c0 - sm_x0 + usb_overhang;  // how far the board reaches past the clips towards its USB-C end

// ------------------------------------------------------------------ layout: three columns, J K L from the left
// L: each piece's run of clips starts at l_x; the board standing in them reaches l_board_out further left.
l_x  = m + l_board_out;
l_y0 = clip_g_mouth + rim_t + l_m;          // a piece's reach below its board line, on the bed
l_y1 = shelf_t + l_m;                       // ... and above it
l_p  = l_y0 + l_y1 + row;
// J: the bosses' centres, their dots beside them on the left, where the boss in front cannot hide them
j_x  = l_x + (l_c1 - l_c0) + l_m + m + dots_w + 0.8 + j_r;
j_p  = 2 * j_r + row;
// K: each block's back at k_x, its hole's centre row by row; its dots beside it on the left, as J's
k_x  = j_x + j_r + m + dots_w + 0.8 + 1;
k_p  = 2 * k_r + 2 + row;
k_out = gy_pcb_max + gy_sensor_h + gy_head_h;   // the module and its screw's head, past the standoff's face
BW = k_x + (gy_xs - k_x0) + k_out + m;
s0 = m + row;                               // where the first try starts, a row in from the front edge
BH = s0 + 3 * max(j_p, k_p, l_p) - row + m;
j_y = [for (i = [0 : 2]) s0 + j_r + i * j_p];
k_y = [for (i = [0 : 2]) s0 + k_r + 1 + i * k_p];
l_y = [for (i = [0 : 2]) s0 + l_y0 + i * l_p];   // the board lines

// ------------------------------------------------------------------ the rules
assert(min(gy_pilots) >= 2, "a hole under 2 mm distorts or closes up - fdm-design-rules §2");
assert(min(pinches) >= 0 && sm_pcb_t - max(pinches) >= sm_pcb_t / 2,
       "the clips' ladder must run from no pinch to one that does not close the catch up");
assert(min(nut_fits) > -fdm_hole_comp, "the tightest nut pocket would be smaller than the nut");
assert(whole(base_t / fdm_layer_h), "printed flat: whole layers only");

// ------------------------------------------------------------------ pieces
module tag(n, x, y, z = base_t)
    for (i = [0 : n - 1])
        translate([x + i * (dot_d + 0.7), y + dot_d / 2, z - eps]) cylinder(d = dot_d, h = 2 * fdm_layer_h + eps);

// every try's dots, where a view from the front sees them: in front of the low clips, beside the taller
// bosses and blocks - a module of their own, so fits-map.scad can show them in a colour
module tags() for (i = [0 : 2]) {
    tag(i + 1, l_x - l_m, l_y[i] - l_y0 - row / 2 - dot_d / 2);
    tag(i + 1, j_x - j_r - 0.8 - dots_w, j_y[i] - dot_d / 2);
    tag(i + 1, k_x - 1 - 0.8 - dots_w, k_y[i] - dot_d / 2);
}

// ------------------------------------------------------------------ the part
module fits() difference() {
    union() {
        // the base, corners rounded against ASA's lifting
        linear_extrude(height = base_t) offset(r = corner_r) offset(delta = -corner_r) square([BW, BH]);
        for (i = [0 : 2]) {
            translate([j_x, j_y[i], 0]) to_bed() cyl_y(0, 0, j_r, 0, j_h);
            translate([k_x - k_x0, k_y[i] + gy_hz, 0]) to_bed() k_piece(gy_pilots[i]);
            translate([l_x - l_c0, l_y[i] + zu, 0]) to_bed() l_piece(pinches[i]);
        }
        tags();
    }
    // the nut pockets, open on the bed side through the base, with the screw's hole on over them
    for (i = [0 : 2]) translate([j_x, j_y[i], 0]) to_bed() nut_trap(0, 0, nut_pocket_r(nut_fits[i]));
}

echo(str("clearance test: ", BW, " x ", BH, " mm base; dots 1 / 2 / 3 = a step tighter / as set / a step looser"));
echo(str("  J nut_fit ", nut_fits, "   K gy_pilot_d ", gy_pilots, "   L clasp_pinch ", pinches));

if (draw_fits) fits();
