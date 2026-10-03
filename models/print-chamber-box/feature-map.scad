// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
Feature map for the print-chamber box: each printed part with its features numbered. docs/features.md
says what every number does.

It INCLUDES the model rather than restating it, so every marker sits wherever the model currently puts
that feature. Change a parameter and re-render, and the map follows.

    openscad -o docs/feature-map-back.png  -D 'view="back"'  --imgsize=1800,1500 --projection=o --viewall \
      --autocenter --camera=31,0,44,78,0,195,260 --colorscheme=Tomorrow feature-map.scad
    openscad -o docs/feature-map-cover.png -D 'view="cover"' --imgsize=1800,1500 --projection=o --viewall \
      --autocenter --camera=31,0,44,100,0,15,260 --colorscheme=Tomorrow feature-map.scad

The back plate is seen as you face the box with the cover off, so its right is your right. The cover is
seen from INSIDE, from the wall, because that is where most of its features are - so its left and right
are swapped: the USB-C opening, on your right when the box is up, is on the left of the picture.

draw_model = false MUST come after the include: the last assignment in a scope wins, so this suppresses
the part while keeping every variable.
*/
include <print-chamber-box.scad>
use <../lib/axes.scad>
draw_model = false;

view = "back";   // "back" or "cover"

tsize = 3.2;     // marker text
mk_d  = 5.6;     // marker disc

// A numbered marker: a disc with its number, standing proud of the feature towards the camera.
// toward = +1 faces the front (+Y, the back plate's view); -1 faces the wall (-Y, the cover's).
module marker(n, p, toward = 1) {
    translate(p) rotate(toward > 0 ? [90, 0, 180] : [90, 0, 0]) {
        color("gold") cylinder(d = mk_d, h = 0.6, center = true);
        color("black") translate([0, 0, 0.35])
            linear_extrude(0.4) text(str(n), size = tsize, halign = "center", valign = "center");
    }
}

// The legend: one line per number, in the plane facing the camera.
module legend(lines, p, toward = 1) {
    translate(p) rotate(toward > 0 ? [90, 0, 180] : [90, 0, 0])
        color("black") for (i = [0 : len(lines) - 1])
            translate([0, -i * 5.2, 0]) linear_extrude(0.4) text(lines[i], size = 3.0);
}

// ------------------------------------------------------------------ the back plate, as you face it
if (view == "back") {
    color([0.80, 0.72, 0.58]) back_plate();
    f = 1.2;   // how far a marker stands in front of its surface
    marker(1,  [W / 2 + 14, back_t + f, H - 24]);                                   // the plate
    for (x = key_xs) marker(2, [x, back_t + f, key_z1 + 7.5]);                      // keyholes
    marker(3,  [ch_x0 - cradle_t / 2, y_ch1 + f, z_sps0 + 22]);                     // channel walls
    marker(3,  [ch_x1 + cradle_t / 2, y_ch1 + f, z_sps0 + 22]);
    marker(4,  [ch_x0 + ledge_w / 2 + 2, back_t + sps_t + f, -3.5]);                // ledge
    marker(5,  [x_div, y_in1 - part_fit + f, -divider_proud - 3.5]);                // divider
    for (c = clasp_xs) marker(6, [(c[0] + c[1]) / 2, y_b0 + clasp_low + f, z_f0 - 3.5]);   // the board's back clips
    marker(7,  [stop_x0 + rim_t / 2 + 3.5, y_b0 + stop_reach + f, zu + 4.5]);       // back stop
    marker(8,  [gy_x1 - 3, gy_yu + f, gy_rib_z1 + 3.5]);                             // post and rib
    marker(9,  [gy_hx, gy_post_y1 + f, gy_hz + gy_standoff_d / 2 + 3.2]);            // pilot
    marker(10, [gy_x1 - 2.5, gy_yf + f, gy_z0 - 5.5]);                               // ledge
    for (x = nut_bx) marker(11, [x, y_in1 + f, nut_bz + nut_boss_d / 2 + 3.5]);     // nut bosses
    marker(12, [W / 2, back_t + bump_out + f, u_z0 - 3.5]);                         // the bump at the top
    marker(13, [(gy_ch_x0 + gy_ch_x1) / 2, gy_ch_y1 + f, gy_ch_zc + gy_ch_slot / 2 + rib_t + 3.5]);   // the SGP41 wires' channel
    legend(["BACK PLATE - as you face the box, cover off",
            "",
            " 1  the plate - against the wall",
            " 2  keyholes - it hangs on two wall screws",
            " 3  channel walls - the SPS30 goes in from the front",
            " 4  ledges - the SPS30 stands on them",
            " 5  divider - splits inlet from outlet air",
            " 6  clips - the board's back edge snaps in",
            " 7  back stop - takes the push of plugging in",
            " 8  post and rib - the SGP41 lies flat on them",
            " 9  pilot for the SGP41's M2.5 screw, upright",
            "10  ledge - the SGP41's bottom edge sits on it",
            "11  nut bosses - an M3 nut pressed in from behind",
            "12  bump - the cover's top locates on it",
            "13  channel - holds the SGP41's wires"],
           [-18, 0, H + 34]);
    axes([-22, 0, -25], 20, [78, 0, 195], [[0, 0], [1.7, -0.3], [0, 0]]);   // the box's own axes, as every figure carries
}

// ------------------------------------------------------------------ the cover, from inside
if (view == "cover") {
    color([0.62, 0.72, 0.85]) cover();
    f = -1.2;   // markers stand towards the wall, where the camera is
    marker(1,  [W / 2 + 14, y_in1 + f, 26], -1);                                      // the front
    marker(2,  [(gy_x0 + gy_x1) / 2, y_in1 + f, gy_z0 + gy_l / 2 + 6], -1);          // the SGP41's vents
    marker(3,  [(sm_x0 + sm_x1) / 2, y_in1 + f, zu + sm_t + gap + 13.5], -1);       // board vents
    for (x = nut_bx) marker(4, [x, y_in1 + f, nut_bz + 8], -1);                  // screw holes
    marker(13, [W / 2, back_t + part_fit + f, u_z0 - 3.5], -1);                      // the U at the top
    marker(5,  [ch_x0 + 15, back_t + f, wall + 3.5], -1);                             // window
    marker(6,  [wall / 2, back_t + f, z_uc - 7], -1);                                // USB opening
    marker(7,  [wall + 2.5, back_t + f, zu + sm_t + 5], -1);                         // thinned wall
    marker(8,  [x_div, y_sps1 + sps_fit + f, z_sps0 + sps_h / 2], -1);               // partition
    marker(9,  [(ch_x0 + ch_x1) / 2 + 8, y_sps1 + sps_fit + f, z_sps1 + 4.5], -1);   // baffle
    marker(10, [(sm_lip_x0 + sm_lip_x1) / 2, y_b1 - sm_lip_over + f, zu + 6], -1);   // the board's rim and lip
    marker(11, [stop_x0 + rim_t + 3.5, y_b1 - stop_reach + f, zu + 4], -1);         // front stop
    marker(12, [corner_r * 0.4, back_t + f, H - corner_r * 0.4], -1);               // rounded corners
    legend(["COVER - seen from INSIDE: left and right swapped",
            "",
            " 1  the front - printed face down",
            " 2  vents in front of the SGP41's sensor",
            " 3  vents in front of the board",
            " 4  bottom screws - their heads sit flush",
            " 5  window under the SPS30's air face",
            " 6  USB-C opening - the shell passes through",
            " 7  wall thinned for the board's USB end",
            " 8  partition - splits the air, holds the SPS30 in",
            " 9  baffle - shuts the sensor's air off",
            "10  front clasp - the board's front edge",
            "11  front stop - takes the push of plugging in",
            "12  rounded corners - instead of a brim",
            "13  U - straddles the plate's bump"],
           [W + 8, 0, H + 34], -1);
    axes([W + 12, 0, -20], 20, [100, 0, 15], [[0, 0], [-1.75, -0.3], [0, 0]]);
}
