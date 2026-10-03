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
    marker(1,  [W - 10, back_t + f, H - 14]);                                    // the plate
    marker(2,  [key_x + 7, back_t + f, (key_z0 + key_z1) / 2]);                  // keyhole
    marker(3,  [ch_x0 - cradle_t / 2, y_ch1 + f, z_sps0 + 22]);                 // channel wall
    marker(3,  [ch_x1 + cradle_t / 2, y_ch1 + f, z_sps0 + 22]);
    marker(4,  [ch_x0 + ledge_w / 2 + 2, back_t + sps_t + f, -3.5]);            // ledge
    marker(5,  [x_div, y_in1 - part_fit + f, -divider_proud - 3.5]);            // divider
    marker(6,  [conn_hi ? W - 17 : 17, back_t + rim_hgt + f, z_board1 + 3]);    // board rims
    marker(7,  [stop_x0 + rim_t / 2 + (conn_hi ? -3 : 3), back_t + rim_hgt + f, z_board1 + 3]);  // stops
    marker(8,  [conn_hi ? gy_ped_x1 - 2.5 : gy_ped_x0 + 2.5, gy_floor + f, gz0 - rim_t - 3.5]);  // pedestal
    marker(9,  [(gy_ledge_x0 + gy_ledge_x1) / 2, gy_floor + gy_ledge_h + f, gz1 - 2]);   // ledge, standoff, rim
    marker(10, [gy_hole_x + (conn_hi ? 4.5 : -4.5), gy_floor + gy_ledge_h + f, gy_hole_z]);   // pilot
    marker(11, [conn_hi ? wch_x0 - 3.2 : wch_x1 + 3.2, wch_y1 + f, (wch_z0 + wch_z1) / 2]);   // cable channel
    for (b = bosses) marker(12, [b[0], y_in1 + f, b[1] + boss_d / 2 + 3.5]);    // bosses
    legend(["BACK PLATE - as you face the box, cover off",
            "",
            " 1  the plate - against the wall",
            " 2  keyhole - it hangs on one wall screw",
            " 3  channel walls - the SPS30 goes in from the front",
            " 4  ledges - the SPS30 stands on them",
            " 5  divider - splits inlet from outlet air",
            " 6  rails - the SuperMini slides in under their lips",
            " 7  stops - take the push of plugging in",
            " 8  pedestal - lifts the SGP41's far half to its vents",
            " 9  ledge, standoff and rim for the SGP41",
            "10  pilot for the SGP41's M2.5 screw",
            "11  cable channel - up to the power pins",
            "12  bosses for the cover's four screws"],
           [-18, 0, H + 34]);
    axes([-22, 0, -25], 20, [78, 0, 195], [[0, 0], [1.7, -0.3], [0, 0]]);   // the box's own axes, as every figure carries
}

// ------------------------------------------------------------------ the cover, from inside
if (view == "cover") {
    color([0.62, 0.72, 0.85]) cover();
    f = -1.2;   // markers stand towards the wall, where the camera is
    vx0 = max(sm_x0, wall + gap); vx1 = min(sm_x1, W - wall - gap);
    marker(1,  [W - 18, y_in1 + f, 30], -1);                                     // the front
    marker(2,  [(gx0 + gx1) / 2, y_in1 + f, gz1 + 3.5], -1);                     // SGP41 vents
    marker(3,  [(vx0 + vx1) / 2, y_in1 + f, z_board1 + 1], -1);                  // board vents
    marker(4,  [bosses[0][0], y_in1 + f, bosses[0][1] + boss_d / 2 + 2.5], -1);  // screw holes
    marker(4,  [bosses[3][0] - 6, y_in1 + f, bosses[3][1] - boss_d / 2 - 2.5], -1);
    marker(5,  [ch_x0 + 8, back_t + f, wall + 3.5], -1);                         // window
    marker(6,  [conn_hi ? W - wall / 2 : wall / 2, back_t + f, z_board_c - usb_shell_w / 2 - 4], -1);   // USB opening
    marker(7,  [conn_hi ? W - wall - 2.5 : wall + 2.5, back_t + f, z_board_c + sm_pocket_h / 2 + 3], -1);   // thinned wall
    marker(8,  [x_div, y_sps1 + sps_fit + f, z_sps0 + sps_h / 2], -1);           // partition
    marker(9,  [(ch_x0 + ch_x1) / 2 + 8, y_sps1 + sps_fit + f, z_sps1 + 4], -1); // baffle
    marker(10, [corner_r * 0.4, back_t + f, H - corner_r * 0.4], -1);           // rounded corners
    legend(["COVER - seen from INSIDE: left and right swapped",
            "",
            " 1  the front - printed face down",
            " 2  vents in front of the SGP41",
            " 3  vents in front of the board",
            " 4  holes for the four M3 screws",
            " 5  window under the SPS30's air face",
            " 6  USB-C opening - the shell passes through",
            " 7  wall thinned for the board's USB end",
            " 8  partition - splits the air, holds the SPS30 in",
            " 9  baffle - shuts the sensor's air off",
            "10  rounded corners - instead of a brim"],
           [W + 8, 0, H + 34], -1);
    axes([W + 12, 0, -20], 20, [100, 0, 15], [[0, 0], [-1.75, -0.3], [0, 0]]);
}
