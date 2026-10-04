// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
The clearance test for the print-chamber box: one small print that tries every untested fit in
print-chamber-box.params.scad at three settings - a step tighter, as set, and a step looser - so the box
is printed with fits that were tried in ASA on this printer rather than guessed.

It INCLUDES the box, and every piece is the box's own geometry, drawn by the box's own modules with only
the fit changed and turned onto the bed as the back plate is. So the test cannot drift from what it
tests, and each piece prints the way it will in the box. Each try carries 1, 2 or 3 dots: 1 = a step
tighter, 2 = as set, 3 = a step looser. docs/clearance-test.md says what to try with each, how to turn
the result into a setting, and what has been found so far.

  M  gy_pilot_d   three of the SGP41's mounts - post, rib and ledge - each with its pilot upright

This is the third round. The first two, of 2 Oct and 3 Oct 2026, settled every other fit; their pieces
are in the history.

draw_fits = false after including this file draws nothing, as fits-map.scad does.
*/
include <print-chamber-box.scad>
draw_model = false;   // after the include: the box's own parts stay undrawn
draw_fits = true;

fit_step = 0.1;             // the step for every fit here
m = 3;                      // margin round and between the pieces
row = 4;                    // gap in front of each try, towards the printer's front; its dots sit in it
dot_d = 1.5;                // the tags: about three beads across, two layers proud
base_t = 6 * fdm_layer_h;   // 1.2 mm: the floor everything stands on

function ladder(v, s) = [v - s, v, v + s];
// Smaller is tighter. No hole may go under 2 mm (the rules below), so with the pilot at 2.0 the ladder
// starts there instead: 1 dot is then the setting itself.
gy_pilots = ladder(max(gy_pilot_d, 2 + fit_step), fit_step);

// The box's geometry is drawn in its own frame - X across, Y out from the wall, Z up - and the back plate
// prints flat on its back. This is the turn its part file makes: the box's Y comes up off the bed.
module to_bed() rotate([90, 0, 0]) children();

// ------------------------------------------------------------------ M: the SGP41's mounts
// The box's post, rib and ledge, on as much plate as they stand on, the pilot down the post. Screwed on,
// the module reaches past the pad towards the printer's front, above the dots.
m_x0 = min(gy_hx - gy_post_d / 2, gy_x0) - 1;        // the pad, in the box's frame
m_x1 = max(gy_hx + gy_post_d / 2, gy_x1) + 1;
m_z0 = gy_z0 - pocket_fit - rim_t - 1;
m_z1 = max(gy_hz + gy_post_d / 2, gy_rib_z1) + 1;
module m_piece(d) difference() {                    // in the box's frame
    union() {
        gy_mount();
        box3([m_x0, 0, m_z0], [m_x1, back_t, m_z1]);
    }
    gy_pilot(d);
}

// ------------------------------------------------------------------ layout: one row
m_w  = m_x1 - m_x0;                         // a piece across, on the bed
m_d  = m_z1 - m_z0;                         // and front to back
m_y  = m + row;                             // each pad's front edge
m_xs = [for (i = [0 : 2]) m + i * (m_w + m)];
BW = m + 3 * m_w + 2 * m + m;
BH = m_y + m_d + m;

// ------------------------------------------------------------------ the rules
assert(min(gy_pilots) >= 2, "a hole under 2 mm distorts or closes up - fdm-design-rules §2");
assert(whole(base_t / fdm_layer_h), "printed flat: whole layers only");

// ------------------------------------------------------------------ pieces
module tag(n, x, y, z = base_t)
    for (i = [0 : n - 1])
        translate([x + i * (dot_d + 0.7), y + dot_d / 2, z - eps]) cylinder(d = dot_d, h = 2 * fdm_layer_h + eps);

// every try's dots, in the gap in front of it - a module of their own, so fits-map.scad can show them in a
// colour
module tags() for (i = [0 : 2]) tag(i + 1, m_xs[i], m_y - row / 2 - dot_d / 2);

// ------------------------------------------------------------------ the part
module fits() union() {
    // the base, corners rounded against ASA's lifting
    linear_extrude(height = base_t) offset(r = corner_r) offset(delta = -corner_r) square([BW, BH]);
    for (i = [0 : 2]) translate([m_xs[i] - m_x0, m_y + m_z1, 0]) to_bed() m_piece(gy_pilots[i]);
    tags();
}

echo(str("clearance test: ", BW, " x ", BH, " mm base; dots 1 / 2 / 3 = a step tighter / as set / a step looser"));
echo(str("  M gy_pilot_d ", gy_pilots, ", the post's top ", gy_standoff_d, " mm across"));

if (draw_fits) fits();
