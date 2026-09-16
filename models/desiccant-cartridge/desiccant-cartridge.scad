/*
desiccant-cartridge — the swappable 500 g unit of the desiccant module (docs/desiccant-module.md).

A shallow tray with a slotted grille in its floor and a matching slotted lid. Box air is pulled through the bed, so the bed is WIDE AND THIN: pressure drop through a packed bed rises with depth and falls with cross-section, and a 60 mm fan cannot pull through a column of the same volume.

ORIENTATION. Authored with the grille floor on z = 0 and the walls rising to cart_h. That is also how it prints: flat, grille face down. Every opening is a gap in the bed layer and every wall rises from it, so there is nothing to bridge and nothing to support — which is the house rule, not a happy accident (docs/fdm-design-rules.md §3b).

ONE SOLID PER RENDER. draw_part picks the tray or the lid; scad-check.sh asserts a single-part STL, and "both" is for looking at rather than exporting.

This file holds the derived values, the modules, the geometry, the echoes and the guards. Everything you SET is in desiccant-cartridge.params.scad. Render this file, not that one.
*/

/* include, not use: this needs the VALUES, and `use` imports only modules. */
include <desiccant-cartridge.params.scad>

/*
DERIVED — computed from the parameters, never set by hand. To change one of these, change what it is computed FROM.
*/
inner_w = cart_w - 2 * wall;
inner_d = cart_d - 2 * wall;
inner_r = max(corner_r - wall, 0);
cavity_h = cart_h - grille_t;       /* floor of the bed to the top of the wall */

/*
AS-CUT dimensions. Every cut, echo and assert below uses these, so what gets audited is the geometry actually produced. A slot grown by fdm_hole_comp per side takes that width OUT OF THE BAR, and auditing the nominal bar would report it 0.30 mm wider than it prints — on the feature carrying the weight of the bed.
*/
eps = 0.01;         /* Nudge so cut solids never end exactly on another face; a shared coplanar face is what breaks 2-manifoldness. */
sw = slot_w + 2 * fdm_hole_comp;            /* slot, as cut */
spd = screw_pilot_d + 2 * fdm_hole_comp;    /* boss pilot, as cut */
scd = screw_d + 2 * fdm_hole_comp;          /* lid clearance hole, as cut */
pitch = slot_w + bar_w;                     /* slot centres; unchanged by compensation */
bar_cut = pitch - sw;                       /* THE REAL BAR — narrower than bar_w */

/* The slotted field, inset from the cavity so the grille has a solid border to stand on. */
field_w = inner_w - 2 * grille_margin;
field_d = inner_d - 2 * grille_margin;
n_slots = floor((field_w + bar_w) / pitch);
span_w = n_slots * pitch - bar_w;           /* what the slots actually occupy */

/* Screw/boss positions, measured in from each outer corner on both axes. */
bx = cart_w / 2 - screw_inset;
by = cart_d / 2 - screw_inset;
boss_reach = max(bx + boss_d / 2 - inner_w / 2, by + boss_d / 2 - inner_d / 2);

/* Capacity. This is the number that ties the geometry to docs/moisture-isotherms.md: design to the MASS the cartridge holds, not to the size of the box it sits in. */
boss_vol = 4 * PI * pow(boss_d / 2, 2) * cavity_h;
cavity_vol = inner_w * inner_d * cavity_h - boss_vol;
cavity_cm3 = cavity_vol / 1000;
capacity_g = cavity_cm3 * bulk_density * fill_factor;
/* Clay holds ~10 % of its mass in water; 5 % is the pessimistic figure this repo also records. */
water_g = capacity_g * 0.10;
water_g_pess = capacity_g * 0.05;

open_area = n_slots * sw * field_d;
face_area = inner_w * inner_d;
open_frac = open_area / face_area;

/* 2D rounded rectangle, centred on the origin. r is clamped so an over-large value degrades to a stadium rather than erroring. */
module rrect2d(w, h, r) {
    rr = min(r, w / 2, h / 2);
    hull()
        for (x = [-1, 1], y = [-1, 1])
            translate([x * (w / 2 - rr), y * (h / 2 - rr)])
                circle(r = rr);
}

/* 3D rounded-rectangle prism, centred in X and Y, sitting on z = 0. */
module rrect(w, h, t, r) {
    linear_extrude(height = t) rrect2d(w, h, r);
}

/* One slot: a cutting solid of height t starting at z = 0, centred on x and on the field in Y. Authored by translating its own half-extents rather than with center=true, so the field's symmetry is visible in the caller. */
module slot(t, x) {
    translate([x - sw / 2, -field_d / 2, 0])
        cube([sw, field_d, t]);
}

module slots(t) {
    for (i = [0 : n_slots - 1])
        slot(t, -span_w / 2 + i * pitch + sw / 2);
}

module tray() {
    difference() {
        union() {
            /* Shell: solid block, cavity taken out of it from the grille face up. */
            difference() {
                rrect(cart_w, cart_d, cart_h, corner_r);
                translate([0, 0, grille_t])
                    rrect(inner_w, inner_d, cavity_h + eps, inner_r);
            }
            /* Lid bosses, standing on the grille floor. Added after the cavity is cut, or the cavity would remove them. */
            for (sx = [-1, 1], sy = [-1, 1])
                translate([sx * bx, sy * by, grille_t])
                    cylinder(h = cavity_h, d = boss_d);
        }
        /* Grille slots: floor only, so they never reach the bosses. */
        translate([0, 0, -eps]) slots(grille_t + 2 * eps);
        /* Pilot holes: thread-forming in plastic, not clearance. */
        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx * bx, sy * by, grille_t - eps])
                cylinder(h = cavity_h + 2 * eps, d = spd);
    }
}

module lid() {
    difference() {
        rrect(cart_w, cart_d, lid_t, corner_r);
        translate([0, 0, -eps]) slots(lid_t + 2 * eps);
        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx * bx, sy * by, -eps])
                cylinder(h = lid_t + 2 * eps, d = scd);
    }
}

draw_model = true;

if (draw_model) {
    if (draw_part == "tray") tray();
    else if (draw_part == "lid") lid();
    else {
        tray();
        translate([0, 0, cart_h + 5]) lid();
    }
}

echo(str("part rendered      : ", draw_part,
         (draw_part == "both") ? "  -- TWO SOLIDS, for viewing only" : ""));
echo(str("envelope           : ", cart_w, " x ", cart_d, " x ", cart_h,
         " mm, wall ", wall, " mm"));
echo(str("interior           : ", inner_w, " x ", inner_d, " x ", cavity_h,
         " mm  = ", cavity_cm3, " cm3 (bosses removed)"));
echo(str("capacity           : ", capacity_g, " g of clay at ", bulk_density,
         " g/cm3, ", fill_factor * 100, "% full   [target ", target_mass, " g]"));
echo(str("  holds            : ", water_g, " g of water at 10% capacity, ",
         water_g_pess, " g at the pessimistic 5%"));
echo(str("grille             : ", n_slots, " slots of ", sw,
         " mm as cut, pitch ", pitch, " mm, field ", span_w, " x ", field_d, " mm"));
echo(str("  bar as cut       : ", bar_cut, " mm  (nominal ", bar_w,
         ", each slot grows ", fdm_hole_comp, " per side)"));
echo(str("  open area        : ", open_area, " mm2 = ", open_frac * 100,
         "% of the ", face_area, " mm2 face"));
echo(str("lid                : ", lid_t, " mm plate, same slot pattern, ",
         scd, " mm clearance holes"));
echo(str("bosses             : d", boss_d, " at +-", bx, ", +-", by,
         ", pilot ", spd, " mm as cut (M3 self-tap)"));
echo(str("prints             : flat, grille face down - no bridges, no supports"));

/*
GUARDS — two kinds, and the distinction is deliberate.

BLOCK, via assert: the geometry is impossible or self-contradictory — a feature vanishes, inverts, or cuts the part in two. There is no sensible STL, so the render stops.

WARN, via echo: it builds and prints, but something is compromised — a bar under the perimeter floor, slots a granule can fall through, a capacity short of the design point. Judgement calls belong to the operator, so they get the STL and the warning.
*/

/* BLOCK — impossible geometry. */
assert(draw_part == "tray" || draw_part == "lid" || draw_part == "both",
       "draw_part must be \"tray\", \"lid\" or \"both\"");
assert(wall > 0 && grille_t > 0 && lid_t > 0,
       "wall, grille_t and lid_t must all be positive");
assert(inner_w > 0 && inner_d > 0,
       "the wall is thicker than half the cartridge - there is no cavity");
assert(cavity_h > 0,
       "grille_t is deeper than the cartridge is tall - nothing is left to fill");
assert(field_w > 0 && field_d > 0,
       "grille_margin leaves no field to slot");
assert(slot_w > 0 && bar_w > 0,
       "slot_w and bar_w must be positive");
assert(bar_cut > 0,
       "the slots are grown wider than the pitch - the grille would come out as one hole with no bars at all");
assert(n_slots >= 1,
       "no slot fits in the grille field");
assert(boss_reach <= 0,
       "the lid bosses fall outside the cavity - they would merge into the wall or hang in air");
assert(spd < boss_d - 2 * perim2,
       "the pilot hole leaves under two perimeters of boss wall - the boss splits when the screw forms its thread");
assert(scd < boss_d,
       "the lid clearance hole is wider than the boss it lands on");

/* WARN — it builds, but. Collected as a list so they are counted and reported together rather than scattered through the log. */
warns = [
    /* The bed sits on these bars and is pulled out hot. */
    if (bar_cut < perim3 - 1e-9)
        str("bar as cut ", bar_cut, " mm is under 3 perimeters (", perim3,
            ") - the bed's weight sits on it, and nominal ", bar_w,
            " hides that because each slot grows ", fdm_hole_comp, " per side"),
    if (wall < perim3 - 1e-9)
        str("wall ", wall, " mm is under 3 perimeters (", perim3,
            ") for a part that is handled hot and pulled out by hand"),

    /* Retention: the point of a grille is that the clay stays in it. */
    if (sw >= granule_min)
        str("slots are ", sw, " mm as cut against a smallest granule of ",
            granule_min, " mm - the clay falls through, and it is a fan pointed",
            " at a room"),

    /* Airflow. */
    if (open_frac < 0.35)
        str("open area is ", open_frac * 100, "% of the face - restrictive for a",
            " 60 mm fan pulling through a packed bed"),

    /* Capacity against the design point, with a tolerance: a cartridge a gram
       under target is not a finding, and a guard that cries at 1 part in 500
       trains its reader to scroll past the ones that matter. */
    if (capacity_g < target_mass * 0.95)
        str("holds ", capacity_g, " g against a target of ", target_mass,
            " g, more than 5% short - either accept it or grow the envelope",
            " SIDEWAYS, since depth costs pressure drop"),

    /* Layer alignment: every horizontal face should land ON a layer boundary. */
    if (abs(cart_h / fdm_layer_h - round(cart_h / fdm_layer_h)) >= 1e-6)
        str("cart_h ", cart_h, " is not a whole number of ", fdm_layer_h, " layers"),
    if (abs(grille_t / fdm_layer_h - round(grille_t / fdm_layer_h)) >= 1e-6)
        str("grille_t ", grille_t, " is not a whole number of ", fdm_layer_h,
            " layers - the slot roof resolves on a slicer tie-break"),
    if (abs(lid_t / fdm_layer_h - round(lid_t / fdm_layer_h)) >= 1e-6)
        str("lid_t ", lid_t, " is not a whole number of ", fdm_layer_h, " layers"),

    /* Assumptions that feed the capacity number. */
    if (bulk_density < 0.7 || bulk_density > 0.9)
        str("bulk_density ", bulk_density, " g/cm3 is outside the usual 0.7-0.9",
            " for granular clay - weigh a measured volume before trusting the capacity"),

    /* Exporting the viewing configuration. */
    if (draw_part == "both")
        str("draw_part is \"both\" - the STL is two solids and will fail the",
            " single-part check; render \"tray\" and \"lid\" separately to export")
];

for (w = warns) echo(str("WARNING: ", w));
echo(len(warns) == 0
     ? "warnings           : none"
     : str("warnings           : ", len(warns), " - the part will build, read them"));
