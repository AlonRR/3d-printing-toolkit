/*
desiccant-module — the stack that carries desiccant cartridges and pulls box air through them.

        inlet lid        grille + sensor pocket, box air enters here
        bay section      one cartridge; ADD A SECTION PER CARTRIDGE
        [filter sheet]   HEPA paper, clamped between sections - not printed
        fan section      plenum, fan pocket, discharge to the PORT
        ---- port ----   flange + clamp through a wall, or the louvre plate

ORIENTATION. Every part is authored with the face that prints on the bed at z = 0, and every part prints FLAT with vertical walls. The bay is a plain frame; the lid is a plate; the fan section's internal transitions are 45 degree cones that grow outward going up, so nothing bridges and nothing needs support. The overhang guard checks that rather than the prose asserting it.

ONE SOLID PER RENDER. draw_part picks the part; "stack" is a preview of the assembly and fails the single-part check deliberately.

This file holds the derived values, the modules, the geometry, the echoes and the guards. Everything you SET is in desiccant-module.params.scad. Render this file, not that one.
*/

include <desiccant-module.params.scad>

/*
DERIVED — computed from the parameters, never set by hand.
*/
eps = 0.01;

/* AS-CUT. Every cut is grown by fdm_hole_comp per side; clearances are separate, because hole_comp only cancels shrink and lands a feature ON nominal - which for a pocket means printing line-to-line on whatever goes in it. */
bay_cut = cart_w + 2 * bay_clear + 2 * fdm_hole_comp;       /* cartridge cavity */
bay_cut_d = cart_d + 2 * bay_clear + 2 * fdm_hole_comp;
ssd = stack_screw_d + 2 * fdm_hole_comp;                    /* stack bolt hole */
psd = port_screw_d + 2 * fdm_hole_comp;                     /* port bolt hole */
pocket_w = fan_size + 2 * fan_clear + 2 * fdm_hole_comp;    /* fan pocket */
throat_cut = throat_d + 2 * fdm_hole_comp;
plenum_cut = plenum_w + 2 * fdm_hole_comp;
bore_cut = port_bore + 2 * fdm_hole_comp;
spigot_od = port_bore - 2 * spigot_clear;                   /* enters the bore */
sens_cut_w = sensor_w + 2 * fdm_hole_comp;
sens_cut_d = sensor_d + 2 * fdm_hole_comp;

bay_h = cart_h + 2 * bay_clear;         /* headroom equal to the side clearance */
inner_r = max(corner_r - wall, 0);

/* Stack bolts, measured in from each outer corner on both axes. */
bx = stack_w / 2 - bolt_inset;
by = stack_d / 2 - bolt_inset;
bolt_to_cavity = bx - bay_cut / 2 - ssd / 2;        /* material between bolt and cartridge */
bolt_to_edge = stack_w / 2 - bx - ssd / 2;          /* material outboard of the bolt */

/* Fan section, built from the port face upward. Each transition is a 45 degree cone: the rise equals half the change in width, so no layer overhangs the one below it. */
trans1 = (pocket_w - throat_cut) / 2;
z_pocket = throat_t + trans1;
z_pocket_top = z_pocket + fan_depth;
trans2 = (plenum_cut - pocket_w) / 2;
fan_h = z_pocket_top + trans2;

/* Inlet grille. The field is pulled back in Y to leave a strip for the sensor housing, and shifted the other way by half of what it gave up, so the slots stay centred on what is left. */
house_w = sensor_w + 2 * wall;
house_d = sensor_d + 2 * wall;
house_h = sensor_h + 1.6;               /* pocket plus a floor for the pilots */
field_w = bay_cut - 2 * in_margin;
field_d = bay_cut_d - 2 * in_margin - house_d;
field_y = house_d / 2;                  /* shift away from the housing strip */
house_y = -(bay_cut_d / 2 - in_margin - house_d / 2);

in_slot_cut = in_slot_w + 2 * fdm_hole_comp;
in_pitch = in_slot_w + in_bar_w;
in_bar_cut = in_pitch - in_slot_cut;
n_in = floor((field_w + in_bar_w) / in_pitch);
in_span = n_in * in_pitch - in_bar_w;
in_open = n_in * in_slot_cut * field_d;
in_face = bay_cut * bay_cut_d;
in_frac = in_open / in_face;

/* Port plates. ⚠️ THE BOLTS ARE AT THE CORNERS OF A SQUARE, so their distance from the centre is the DIAGONAL - port_bolt/2 * sqrt(2) - not half the pitch. Reading the pitch as a radius understates it by 30% and was what made the first version of the groove guard fail on its own defaults: it compared a groove at r37 against a bolt "radius" of 35 when the bolts are really at 49.5. */
port_bolt_r = port_bolt / 2 * sqrt(2);
/* Groove centred between the bore edge and the plate edge, rather than offset from a number that happened to be nearby. */
groove_mid = (port_bore / 2 + port_plate_w / 2) / 2;
groove_out = groove_mid + gasket_w / 2;
groove_in = groove_mid - gasket_w / 2;

/* Screw lengths the stack actually needs, which is the number you buy rather than a dimension you draw. */
screw_len_1 = lid_t + bay_h + fan_h;
screw_len_2 = lid_t + 2 * bay_h + fan_h;

module rrect2d(w, h, r) {
    rr = min(r, w / 2, h / 2);
    hull()
        for (x = [-1, 1], y = [-1, 1])
            translate([x * (w / 2 - rr), y * (h / 2 - rr)])
                circle(r = rr);
}

module rrect(w, h, t, r) {
    linear_extrude(height = t) rrect2d(w, h, r);
}

/* Thin section helpers, so a 45 degree transition is a hull of two of them rather than a cylinder with a computed angle. */
module sq_at(z, w) { translate([0, 0, z]) linear_extrude(eps) square([w, w], center = true); }
module circ_at(z, d) { translate([0, 0, z]) linear_extrude(eps) circle(d = d); }

/* The four stack bolts, as cutting solids through height t from z = 0. */
module stack_bolts(t) {
    for (sx = [-1, 1], sy = [-1, 1])
        translate([sx * bx, sy * by, -eps])
            cylinder(h = t + 2 * eps, d = ssd);
}

/* The four port bolts. */
module port_bolts(t) {
    for (sx = [-1, 1], sy = [-1, 1])
        translate([sx * port_bolt / 2, sy * port_bolt / 2, -eps])
            cylinder(h = t + 2 * eps, d = psd);
}

/* A slotted field of n slots, centred on the origin in X and on fy in Y. */
module slot_field(t, n, span, sw, pitch, fd, fy) {
    for (i = [0 : n - 1])
        translate([-span / 2 + i * pitch, fy - fd / 2, -eps])
            cube([sw, fd, t + 2 * eps]);
}

/* ---------------------------------------------------------------- the parts */

/* BAY — a plain frame. One per cartridge; stack as many as the screws reach. */
module bay() {
    difference() {
        rrect(stack_w, stack_d, bay_h, corner_r);
        translate([0, 0, -eps])
            rrect(bay_cut, bay_cut_d, bay_h + 2 * eps, inner_r);
        stack_bolts(bay_h);
    }
}

/* FAN SECTION — discharge bore, 45 degree cone, fan pocket, 45 degree cone to the plenum. */
module fan_section() {
    difference() {
        rrect(stack_w, stack_d, fan_h, corner_r);
        union() {
            translate([0, 0, -eps]) cylinder(h = throat_t + eps, d = throat_cut);
            hull() { circ_at(throat_t, throat_cut); sq_at(z_pocket, pocket_w); }
            translate([0, 0, z_pocket])
                linear_extrude(fan_depth) square([pocket_w, pocket_w], center = true);
            hull() { sq_at(z_pocket_top, pocket_w); sq_at(fan_h + eps, plenum_cut); }
        }
        stack_bolts(fan_h);
    }
}

/* LID — inlet grille, stack bolts, and the sensor housing standing on the inner face. */
module lid() {
    difference() {
        union() {
            rrect(stack_w, stack_d, lid_t, corner_r);
            translate([0, house_y, lid_t - eps])
                rrect(house_w, house_d, house_h + eps, 2);
        }
        slot_field(lid_t, n_in, in_span, in_slot_cut, in_pitch, field_d, field_y);
        stack_bolts(lid_t);
        /* Sensor pocket, open on the inner face. */
        translate([0, house_y, lid_t + house_h - sensor_h])
            rrect(sens_cut_w, sens_cut_d, sensor_h + eps, 1);
        /* Cable slot out of the pocket, toward the nearest edge. */
        translate([-cable_w / 2, house_y - house_d / 2 - eps, lid_t + house_h - sensor_h])
            cube([cable_w, house_d / 2 + 2 * eps, sensor_h + eps]);
        /* Pilot holes for the breakout. */
        for (sx = [-1, 1])
            translate([sx * sensor_pitch / 2, house_y, lid_t - eps])
                cylinder(h = house_h, d = sensor_screw_d + 2 * fdm_hole_comp);
    }
}

/* FLANGE — outside face of the enclosure wall. Spigot locates it in the bore. */
module flange() {
    difference() {
        union() {
            rrect(port_plate_w, port_plate_w, port_plate_t, corner_r);
            translate([0, 0, port_plate_t - eps])
                cylinder(h = spigot_len + eps, d = spigot_od);
        }
        translate([0, 0, -eps])
            cylinder(h = port_plate_t + spigot_len + 2 * eps, d = throat_cut);
        port_bolts(port_plate_t + spigot_len);
        /* Gasket groove, in the face that meets the wall. */
        translate([0, 0, port_plate_t - gasket_t])
            difference() {
                cylinder(h = gasket_t + eps, d = groove_out * 2);
                translate([0, 0, -eps]) cylinder(h = gasket_t + 3 * eps, d = groove_in * 2);
            }
    }
}

/* CLAMP — the other side of the wall. A plate with a bore big enough to clear the spigot. */
module clamp() {
    difference() {
        rrect(port_plate_w, port_plate_w, port_plate_t, corner_r);
        translate([0, 0, -eps]) cylinder(h = port_plate_t + 2 * eps, d = bore_cut);
        port_bolts(port_plate_t);
    }
}

/* LOUVRE — blanks the port and returns the air to the box. This is what v1 runs. */
module louvre() {
    lv_field = port_plate_w - 2 * in_margin;
    lv_n = floor((lv_field + in_bar_w) / in_pitch);
    lv_span = lv_n * in_pitch - in_bar_w;
    difference() {
        rrect(port_plate_w, port_plate_w, port_plate_t, corner_r);
        slot_field(port_plate_t, lv_n, lv_span, in_slot_cut, in_pitch, lv_field, 0);
        port_bolts(port_plate_t);
    }
}

draw_model = true;

if (draw_model) {
    if (draw_part == "bay") bay();
    else if (draw_part == "fan") fan_section();
    else if (draw_part == "lid") lid();
    else if (draw_part == "flange") flange();
    else if (draw_part == "clamp") clamp();
    else if (draw_part == "louvre") louvre();
    else {
        fan_section();
        translate([0, 0, fan_h + 2]) bay();
        translate([0, 0, fan_h + bay_h + 4]) lid();
        translate([stack_w + 10, 0, 0]) flange();
        translate([stack_w + 10, port_plate_w + 10, 0]) clamp();
        translate([stack_w + 10, -(port_plate_w + 10), 0]) louvre();
    }
}

echo(str("part rendered      : ", draw_part,
         (draw_part == "stack") ? "  -- SIX SOLIDS, preview only" : ""));
echo(str("PORT (the standard): bore ", port_bore, " mm, 4x M3 on ", port_bolt,
         " mm square, plates ", port_plate_w, " x ", port_plate_w, " x ", port_plate_t));
echo(str("  spigot           : ", spigot_od, " mm OD x ", spigot_len,
         " into a ", port_bore, " bore (", spigot_clear, " mm/side)"));
echo(str("  gasket groove    : ", gasket_w, " x ", gasket_t, " mm at r", groove_mid,
         "  (bore r", port_bore / 2, ", bolts r", port_bolt_r,
         ", plate r", port_plate_w / 2, ")"));
echo(str("stack footprint    : ", stack_w, " x ", stack_d, " mm, wall ", wall,
         ", bolts at +-", bx));
echo(str("  bolt -> cavity   : ", bolt_to_cavity, " mm"));
echo(str("  bolt -> edge     : ", bolt_to_edge, " mm"));
echo(str("bay section        : ", bay_h, " mm tall, cavity ", bay_cut, " x ", bay_cut_d,
         " as cut for a ", cart_w, " x ", cart_d, " x ", cart_h, " cartridge"));
echo(str("fan section        : ", fan_h, " mm tall  =  throat ", throat_t,
         " + cone ", trans1, " + fan ", fan_depth, " + cone ", trans2));
echo(str("  pocket           : ", pocket_w, " mm square as cut for a ", fan_size,
         " mm fan - CLAMPED by the section above, not screwed"));
echo(str("  plenum           : ", plenum_cut, " mm square under the cartridge"));
echo(str("inlet grille       : ", n_in, " slots of ", in_slot_cut, " as cut, bar ",
         in_bar_cut, ", open ", in_frac * 100, "% of the cartridge face"));
echo(str("sensor housing     : ", house_w, " x ", house_d, " x ", house_h,
         " on the inlet face, pocket ", sens_cut_w, " x ", sens_cut_d, " as cut"));
echo(str("screws to buy      : M3 x ", screw_len_1, " for one cartridge, x ",
         screw_len_2, " for two, plus engagement"));
echo(str("port screws        : M3 x ", port_plate_t * 2 + panel_max,
         " covers the thickest wall specified (", panel_max, " mm)"));
echo(str("prints             : every part flat, vertical walls, 45 degree cones - no supports"));

/* BLOCK — impossible geometry. */
assert(draw_part == "bay" || draw_part == "fan" || draw_part == "lid"
       || draw_part == "flange" || draw_part == "clamp" || draw_part == "louvre"
       || draw_part == "stack",
       "draw_part must be bay, fan, lid, flange, clamp, louvre or stack");
assert(bolt_to_cavity >= perim3,
       "the stack bolts pass through the cartridge cavity, or leave under 3 perimeters beside it - widen stack_w or move bolt_inset");
assert(bolt_to_edge >= perim3,
       "the stack bolts leave under 3 perimeters outboard - they will split the corner out");
assert(bay_cut < stack_w - 2 * perim3 && bay_cut_d < stack_d - 2 * perim3,
       "the cartridge cavity leaves no wall");
assert(throat_cut < pocket_w,
       "the discharge bore is wider than the fan pocket - the pocket walls would be cut away");
assert(plenum_cut <= bay_cut,
       "the plenum is wider than the cartridge it feeds");
assert(plenum_cut < stack_w - 2 * perim3,
       "the plenum leaves no wall in the fan section");
assert(trans1 >= 0 && trans2 >= 0,
       "a transition inverts - the fan pocket is not between the bore and the plenum");
assert(spigot_od > throat_cut,
       "the spigot wall vanishes - its bore is as wide as the spigot");
assert(groove_in > port_bore / 2 && groove_out < port_bolt_r - psd / 2
       && groove_out < port_plate_w / 2 - perim3,
       "the gasket groove runs into the bore, into the bolts, or off the edge of the plate");
assert(n_in >= 1, "no inlet slot fits the field");
assert(in_bar_cut > 0,
       "the inlet slots are grown wider than their pitch - the grille has no bars");
assert(field_d > 0,
       "the sensor housing leaves no room for the inlet field");
assert(house_w < stack_w - 2 * perim3 && house_d < stack_d - 2 * perim3,
       "the sensor housing is wider than the lid");
assert(sensor_pitch + sensor_screw_d < sens_cut_w,
       "the breakout's pilot holes fall outside its own pocket");

/* WARN — it builds, but. */
warns = [
    if (wall < perim3 - 1e-9)
        str("wall ", wall, " mm is under 3 perimeters (", perim3,
            ") for a bolted section carrying a fan"),
    if (in_bar_cut < perim3 - 1e-9)
        str("inlet bar as cut ", in_bar_cut, " mm is under 3 perimeters (", perim3,
            ") - nominal ", in_bar_w, " hides that, since each slot grows ",
            fdm_hole_comp, " per side"),
    if (in_frac < 0.35)
        str("inlet is ", in_frac * 100, "% open - restrictive in front of a packed bed"),
    if (bolt_to_cavity < 2 * perim3)
        str("only ", bolt_to_cavity, " mm between bolt and cavity - thin for a joint",
            " that is tightened by hand"),
    if (abs(bay_h / fdm_layer_h - round(bay_h / fdm_layer_h)) >= 1e-6)
        str("bay_h ", bay_h, " is not a whole number of ", fdm_layer_h, " layers"),
    if (abs(fan_h / fdm_layer_h - round(fan_h / fdm_layer_h)) >= 1e-6)
        str("fan section height ", fan_h, " is not a whole number of ", fdm_layer_h,
            " layers"),
    if (abs(lid_t / fdm_layer_h - round(lid_t / fdm_layer_h)) >= 1e-6)
        str("lid_t ", lid_t, " is not a whole number of ", fdm_layer_h, " layers"),
    if (abs(port_plate_t / fdm_layer_h - round(port_plate_t / fdm_layer_h)) >= 1e-6)
        str("port_plate_t ", port_plate_t, " is not a whole number of ", fdm_layer_h,
            " layers"),
    if (spigot_len > panel_max)
        str("the spigot is longer than the thickest wall specified - it will stand",
            " proud inside the enclosure"),
    if (draw_part == "stack")
        str("draw_part is \"stack\" - the STL is six solids and will fail the",
            " single-part check; render each part separately to export")
];

for (w = warns) echo(str("WARNING: ", w));
echo(len(warns) == 0
     ? "warnings           : none"
     : str("warnings           : ", len(warns), " - the part will build, read them"));
