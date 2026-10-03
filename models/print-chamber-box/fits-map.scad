// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
Which piece of the clearance test is which: print-chamber-box-fits.scad as it sat on the bed, seen from
the printer's front and a little above - enough tilt for the posts' pilots to show - each group
lettered. docs/clearance-test.md shows it, with a table of what each letter tries and the
value behind each dot count.

It INCLUDES the test, so every letter sits wherever the test puts that group and the dots are the test's
own. Three colours: the base, everything standing on it, and the dots - plus the xyz arrows every figure
carries (../lib/axes.scad).

    openscad -o docs/fits-map.png --imgsize=1600,1150 --projection=o --viewall --autocenter \
      --camera=0,0,0,30,0,0,300 --colorscheme=Tomorrow fits-map.scad

draw_fits = false MUST come after the include, so the test does not also draw itself uncoloured.
*/
include <print-chamber-box-fits.scad>
use <../lib/axes.scad>
draw_fits = false;

// the split sits 0.3 mm above the base, so the pads under the posts read as pieces
module above_base() translate([-1, -1, base_t + 0.3]) cube([BW + 2, BH + 2, 50]);

color([0.88, 0.82, 0.68]) difference() { fits(); above_base(); }                    // the base
color([0.55, 0.40, 0.25]) difference() { intersection() { fits(); above_base(); } tags(); }   // the pieces
color([0.05, 0.05, 0.05]) translate([0, 0, 0.05]) tags();                            // the dots

// a lettered disc, lying flat in front of the group it names
module letter(t, p, z = 0.6) translate([p[0], p[1], z]) {
    color([0.95, 0.70, 0.05]) cylinder(d = 8, h = 0.4, $fn = 32);
    color("black") translate([0, 0, 0.4]) linear_extrude(0.4)
        text(t, size = 5, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
}
module note(t, p, size = 3.4) color("black") translate([p[0], p[1], 0]) linear_extrude(0.4) text(t, size = size);

letter("M", [BW / 2, -7]);                       // the SGP41's mounts

note("this edge faced the printer's front", [0, -17]);
note("dots: 1 = a step tighter, 2 = as set, 3 = a step looser", [0, -24]);

// the part's own axes, as it lay on the bed. At this tilt +z points up the picture too: its label goes left
axes([BW + 10, 2, 0], 14, [30, 0, 0], [[0, 0], [0, 0], [-1.3, -0.3]]);
