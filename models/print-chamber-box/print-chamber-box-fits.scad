// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
The clearance test for the print-chamber box: one small print that tries every untested fit in
print-chamber-box.params.scad at three settings - a step tighter, as set, and a step looser - so the box
is printed with fits that were tried in ASA on this printer rather than guessed.

Every size comes from the box's own settings, so the test cannot drift from what it tests. Each try
carries 1, 2 or 3 dots: 1 = a step tighter, 2 = as set, 3 = a step looser. docs/clearance-test.md
says what to try with each, how to turn the result into a setting, and what has been found so far.

  sps_fit      three open frames the SPS30 slides through
  pocket_fit   three trays for the SuperMini, three for the GY-SGP41
  pilot_d      three bosses for the M3 x 14 self-tapping screws that close the cover
  gy_pilot_d   three bosses for the M2.5 x 8 screw that holds the SGP41
  screw_d      three clearance holes for those M3 screws
  tab_hole_d   three mounting holes for the wood screws
  part_fit     a peg and a socket at part_fit, to measure with calipers rather than to try

One part, printed flat. Every piece stands on a shared base, which is also the floor the boards rest on.
*/
include <print-chamber-box.params.scad>

draw_model = true;   // also tells the params file it is being used

eps = 0.01;
$fa = 2;
$fs = 0.4;

function hole_r(d) = d / 2 + fdm_hole_comp;   // the box's own hole compensation
function ladder(v, s) = [v - s, v, v + s];
function whole(x) = abs(x - round(x)) < 1e-6;

base_t = 6 * fdm_layer_h;   // 1.2 mm: the floor everything stands on
fit_step  = 0.1;            // the step for the fits
hole_step = 0.2;            // the step for the screw holes
m = 3;                      // margin round and between the pieces
dot_d = 1.5;                // the tags: about three beads across, two layers proud

sps_fits    = ladder(sps_fit, fit_step);
pocket_fits = ladder(pocket_fit, fit_step);
m3_pilots   = ladder(pilot_d, hole_step);
gy_pilots   = ladder(gy_pilot_d, fit_step);
screw_ds    = ladder(screw_d, hole_step);
tab_ds      = ladder(tab_hole_d, hole_step);

// ------------------------------------------------------------------ sizes, at the loosest try
sps_in_w  = sps_w + 2 * sps_nub + 2 * sps_fits[2];
sps_in_t  = sps_t + 2 * sps_fits[2];
sps_out_w = sps_in_w + 2 * cradle_t;
sps_out_t = sps_in_t + 2 * cradle_t;
frame_h   = 4;                                     // tall enough to guide, short enough to see through
sm_out_l  = sm_l + 2 * pocket_fits[2] + 2 * rim_t;
sm_out_w  = sm_w + 2 * pocket_fits[2] + 2 * rim_t;
gy_out_l  = gy_l + 2 * pocket_fits[2] + 2 * rim_t;
gy_out_w  = gy_w + 2 * pocket_fits[2] + 2 * rim_t;
rim_top   = base_t + sm_pcb_t + 2 * fdm_layer_h;   // as tall above the floor as the box's rims
// No cover sits on these, so the whole M3 x 14 goes in: the pilot must take all 14 mm. The 2 Oct print's
// was 13 deep and the screws stopped short (Alon). The box's pilots are deeper than its 12.2 mm of screw.
m3_boss_h = 15;
m3_pilot_depth = 15;
gy_boss_d = 6;
gy_boss_h = 9;
gy_pilot_depth = gy_screw_l - gy_pcb_min + 2 * fdm_layer_h;   // as deep as the box's
peg = 6;                       // the part_fit peg, and the socket's nominal size
bar_t = back_t;                // the hole bar is as thick as the box's tabs

// ------------------------------------------------------------------ layout: four columns
row = 4;                                  // gap between tries in a column; the dots sit in it
x1 = m;                                   // SPS30 frames
x2 = x1 + sps_out_w + m;                  // SuperMini trays
x3 = x2 + sm_out_l + m;                   // GY-SGP41 trays, then the hole bar
hole_pitch = 7;                           // between holes in the bar: leaves 2.5 mm between the largest
col3_w = max(gy_out_l, 3 * hole_pitch);
x4 = x3 + col3_w + m;                     // bosses, then the peg and socket
col4_w = 2 * boss_d + m;
bar_y = m + 3 * (gy_out_w + row);
bar_h = 2 * (max(tab_ds) + 2 * fdm_hole_comp) + 3 * m;
peg_y = m + 3 * (boss_d + row) + 3 * (gy_boss_d + row);
BW = x4 + col4_w + m;
BH = max(m + 3 * (sps_out_t + row), m + 3 * (sm_out_w + row), bar_y + bar_h + m, peg_y + peg + 2 * m + m);

// ------------------------------------------------------------------ the rules
assert(min(m3_pilots) >= 2 && min(gy_pilots) >= 2 && min(screw_ds) >= 2 && min(tab_ds) >= 2,
       "a hole under 2 mm distorts or closes up - fdm-design-rules §2");
assert(whole(base_t / fdm_layer_h) && whole(bar_t / fdm_layer_h), "printed flat: whole layers only");
assert(hole_pitch - 2 * hole_r(max(tab_ds)) >= 4 * fdm_extrusion_w, "the holes in the bar are too close together");
assert(m3_pilot_depth < m3_boss_h + base_t - 2 * fdm_layer_h && gy_pilot_depth < gy_boss_h + base_t - 2 * fdm_layer_h,
       "a pilot would break through the base");
// ------------------------------------------------------------------ pieces
module tag(n, x, y, z = base_t)
    for (i = [0 : n - 1])
        translate([x + i * (dot_d + 0.7), y + dot_d / 2, z - eps]) cylinder(d = dot_d, h = 2 * fdm_layer_h + eps);

module frame(in_x, in_y, wall, h, x, y)   // a rectangular ring standing on the base at (x, y)
    translate([x, y, base_t - eps])
        difference() {
            cube([in_x + 2 * wall, in_y + 2 * wall, h + eps]);
            translate([wall, wall, -eps]) cube([in_x, in_y, h + 3 * eps]);
        }

module boss(d, h, pilot, depth, x, y)
    translate([x, y, base_t - eps])
        difference() {
            cylinder(d = d, h = h + eps);
            translate([0, 0, h + eps - depth]) cylinder(r = hole_r(pilot), h = depth + eps);
        }

// every try's dots, beside it - a module of their own, so fits-map.scad can show them in a colour
module tags() {
    for (i = [0 : 2]) {
        tag(i + 1, x1, m + i * (sps_out_t + row) + sps_out_t + (row - dot_d) / 2);   // SPS30 frames
        tag(i + 1, x2, m + i * (sm_out_w + row) + sm_out_w + (row - dot_d) / 2);     // SuperMini trays
        tag(i + 1, x3, m + i * (gy_out_w + row) + gy_out_w + (row - dot_d) / 2);     // GY-SGP41 trays
        by = m + boss_d / 2 + i * (boss_d + row);                                    // M3 bosses
        tag(i + 1, x4 + boss_d + 1, by - dot_d / 2);
        gby = m + 3 * (boss_d + row) + gy_boss_d / 2 + i * (gy_boss_d + row);        // M2.5 bosses
        tag(i + 1, x4 + boss_d + 1, gby - dot_d / 2);
        // the hole bar: one group per column of holes, between its two rows
        tag(i + 1, x3 + col3_w * (i + 0.5) / 3 - (i * (dot_d + 0.7) + dot_d) / 2 + dot_d / 2,
            bar_y + bar_h / 2 - dot_d / 2, bar_t);
    }
}

// ------------------------------------------------------------------ the part
module fits() {
    difference() {
        union() {
            // the base, corners rounded against ASA's lifting
            linear_extrude(height = base_t)
                offset(r = corner_r) offset(delta = -corner_r) square([BW, BH]);

            for (i = [0 : 2]) {
                f = sps_fits[i];
                // the SPS30 frames, centred in the column so all three line up
                sy = m + i * (sps_out_t + row);
                frame(sps_w + 2 * sps_nub + 2 * f, sps_t + 2 * f, cradle_t, frame_h,
                      x1 + (sps_in_w - (sps_w + 2 * sps_nub + 2 * f)) / 2,
                      sy + (sps_in_t - (sps_t + 2 * f)) / 2);

                // the SuperMini trays
                p = pocket_fits[i];
                my = m + i * (sm_out_w + row);
                frame(sm_l + 2 * p, sm_w + 2 * p, rim_t, rim_top - base_t, x2, my);

                // the GY-SGP41 trays
                gy = m + i * (gy_out_w + row);
                frame(gy_l + 2 * p, gy_w + 2 * p, rim_t, rim_top - base_t, x3, gy);

                // the M3 pilot bosses, then the M2.5 ones, down column 4
                by = m + boss_d / 2 + i * (boss_d + row);
                boss(boss_d, m3_boss_h, m3_pilots[i], m3_pilot_depth, x4 + boss_d / 2, by);
                gby = m + 3 * (boss_d + row) + gy_boss_d / 2 + i * (gy_boss_d + row);
                boss(gy_boss_d, gy_boss_h, gy_pilots[i], gy_pilot_depth, x4 + boss_d / 2, gby);
            }
            tags();

            // the hole bar: M3 clearance holes above, mounting holes below
            translate([x3, bar_y, base_t - eps]) cube([col3_w, bar_h, bar_t - base_t + eps]);

            // the part_fit peg, and the block its socket is cut in
            translate([x4, peg_y, base_t - eps]) cube([peg, peg, peg]);
            translate([x4 + peg + m, peg_y - m / 2, base_t - eps]) cube([peg + 2 * part_fit + m, peg + 2 * part_fit + m, peg]);
        }
        // the SPS30 slides right through: open the base inside each frame
        for (i = [0 : 2]) {
            f = sps_fits[i];
            sy = m + i * (sps_out_t + row);
            translate([x1 + (sps_in_w - (sps_w + 2 * sps_nub + 2 * f)) / 2 + cradle_t,
                       sy + (sps_in_t - (sps_t + 2 * f)) / 2 + cradle_t, -eps])
                cube([sps_w + 2 * sps_nub + 2 * f, sps_t + 2 * f, base_t + 3 * eps]);
        }
        // the holes in the bar, three across each row
        for (i = [0 : 2]) {
            hx = x3 + col3_w * (i + 0.5) / 3;
            translate([hx, bar_y + m + max(screw_ds) / 2, -eps]) cylinder(r = hole_r(screw_ds[i]), h = bar_t + 2 * eps);
            translate([hx, bar_y + bar_h - m - max(tab_ds) / 2, -eps]) cylinder(r = hole_r(tab_ds[i]), h = bar_t + 2 * eps);
        }
        // the part_fit socket
        translate([x4 + peg + m + m / 2, peg_y, base_t])
            cube([peg + 2 * part_fit, peg + 2 * part_fit, peg + eps]);
    }
}

echo(str("clearance test: ", BW, " x ", BH, " mm base; dots 1 / 2 / 3 = a step tighter / as set / a step looser"));
echo(str("  sps_fit ", sps_fits, "   pocket_fit ", pocket_fits, "   pilot_d ", m3_pilots, "   gy_pilot_d ", gy_pilots));
echo(str("  screw_d ", screw_ds, " (the bar's row next to the GY-SGP41 trays)   tab_hole_d ", tab_ds,
         " (its other row)   part_fit ", part_fit,
         " (peg ", peg, ", socket ", peg + 2 * part_fit, ")"));

if (draw_model) fits();
