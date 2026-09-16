/*
desiccant-module — the stack that carries desiccant cartridges, pulls box air through them, and
regenerates itself by sealing the filament area and baking the bed out to the room.

        lid              a plain cap - it turns the flow from the riser into the bed
        bay section      one cartridge; ADD A SECTION PER CARTRIDGE
        [filter sheet]   HEPA paper, clamped between sections - not printed
        fan section      plenum and fan pocket
        valve section    both barrel valves, both cabinet grilles, both room bores
        ---- port ----   flange + clamp through the enclosure wall

THE DUCT IS A U. Air goes UP the riser, over at the lid, DOWN through the bed, and out at the bottom,
so both ends arrive in the valve section and ONE valve assembly serves all four paths. Every section
therefore carries two through-features at the same place - the riser channel in one wall and the
shaft bore in the other - so stacking another bay extends both rather than breaking them.

ORIENTATION. Every part is authored with the face that prints on the bed at z = 0 and prints FLAT
with vertical walls. The fan section's internal transitions are 45 degree cones that grow outward
going up; the valve chambers are horizontal cylinders, which print as a bridge-free arch because
their crowns are cut, not bridged (see the guard on chamber depth).

ONE SOLID PER RENDER. draw_part picks the part; "stack" is a preview and fails the single-part check
deliberately.

Everything you SET is in desiccant-module.params.scad. Render this file, not that one.
*/

include <desiccant-module.params.scad>

/* DERIVED — computed from the parameters, never set by hand. */
eps = 0.01;

/* AS-CUT. Every cut is grown by fdm_hole_comp per side; clearances are separate. */
bay_cut = cart_w + 2 * bay_clear + 2 * fdm_hole_comp;
bay_cut_d = cart_d + 2 * bay_clear + 2 * fdm_hole_comp;
ssd = stack_screw_d + 2 * fdm_hole_comp;
psd = port_screw_d + 2 * fdm_hole_comp;
pocket_w = fan_size + 2 * fan_clear + 2 * fdm_hole_comp;
throat_cut = throat_d + 2 * fdm_hole_comp;
plenum_cut = plenum_w + 2 * fdm_hole_comp;
bore_cut = port_bore + 2 * fdm_hole_comp;
riser_cut_w = riser_w + 2 * fdm_hole_comp;
riser_cut_d = riser_d + 2 * fdm_hole_comp;
sens_cut_w = sensor_w + 2 * fdm_hole_comp;
sens_cut_d = sensor_d + 2 * fdm_hole_comp;

bay_h = cart_h + 2 * bay_clear;
inner_r = max(corner_r - wall, 0);

/* Stack bolts. */
bx = stack_w / 2 - bolt_inset;
by = stack_d / 2 - bolt_inset;
bolt_to_cavity = bx - bay_cut / 2 - ssd / 2;
bolt_to_edge = stack_w / 2 - bx - ssd / 2;

/* The riser, in one wall, clear of the cavity and of the bolts. There is no second through-feature:
   the push-rod is horizontal and lives inside the valve section, so nothing else crosses a section. */
wall_band = (stack_w - bay_cut) / 2;                 /* material each side of the cavity */
riser_x = -(bay_cut / 2 + wall_band / 2) * (riser_face == "left" ? 1 : -1);
riser_to_cavity = abs(riser_x) - riser_cut_d / 2 - bay_cut / 2;
riser_to_edge = stack_w / 2 - abs(riser_x) - riser_cut_d / 2;
/* The riser runs down the same wall band the bolts pass through, so it has a THIRD neighbour that
   the first version of this guard never looked at. Width is the cheap direction for area, which is
   exactly why it needs a limit: nothing else here would notice a channel cut into a bolt hole. */
riser_to_bolt = by - riser_cut_w / 2 - ssd / 2;

/* Fan section, built from the port face upward. Each transition is a 45 degree cone: the rise
   equals half the change in width, so no layer overhangs the one below it. */
trans1 = (pocket_w - throat_cut) / 2;
z_pocket = throat_t + trans1;
z_pocket_top = z_pocket + fan_depth;
trans2 = (plenum_cut - pocket_w) / 2;
fan_h = z_pocket_top + trans2;

/* Valve section. Each leg of the U gets two ports SIDE BY SIDE in the floor - the room bore and
   the cabinet port - and a gate that slides across them. The middle position spans both, which is
   the cooling state and the whole reason this is a gate rather than a flap or a drum. */
leg_y = (sel_port + partition + sel_gap) / 2;        /* the two legs, +- this in Y */
sel_cut = sel_port + 2 * fdm_hole_comp;
gate_cut_t = gate_t + 2 * gate_clear + 2 * fdm_hole_comp;
gate_len = 2 * sel_cut + sel_gap + 2 * gate_over;    /* long enough to span BOTH ports */
gate_travel = sel_cut + sel_gap;                     /* end to end, three positions */
gate_z = 6;                                          /* gate plane above the port face */
port_x_room = -(sel_cut + sel_gap) / 2;              /* room bore, one side of each leg */
port_x_cab = (sel_cut + sel_gap) / 2;                /* cabinet port, the other */
rod_cut = rod_d + 2 * rod_clear + 2 * fdm_hole_comp;
rod_z = gate_z + gate_cut_t / 2;
gate_sweep = gate_len + gate_travel;                 /* swept length the guide must allow */
gate_w = sel_port + 2 * gate_over;                   /* across the gate */
grille_cut_w = grille_w + 2 * fdm_hole_comp;         /* cabinet opening, as cut */
grille_cut_h = grille_h + 2 * fdm_hole_comp;

/* Port plates: two bores, and one gasket racetrack encircling both. */
groove_r = port_bore / 2 + gasket_margin;
groove_out = groove_r + gasket_w / 2;
groove_in = groove_r - gasket_w / 2;
port_bolt_r = port_bolt / 2 * sqrt(2);               /* bolts are at the CORNERS of a square */
racetrack_reach = port_bore_pitch / 2 + groove_out;  /* how far the groove gets from centre */

/* Grille slots for the cabinet openings. */
in_slot_cut = in_slot_w + 2 * fdm_hole_comp;
in_pitch = in_slot_w + in_bar_w;
in_bar_cut = in_pitch - in_slot_cut;
n_in = floor((grille_w + in_bar_w) / in_pitch);
in_span = n_in * in_pitch - in_bar_w;

/* Screw lengths - the number you buy rather than a dimension you draw. */
screw_len_1 = lid_t + bay_h + fan_h + valve_h;
screw_len_2 = lid_t + 2 * bay_h + fan_h + valve_h;

module rrect2d(w, h, r) {
    rr = min(r, w / 2, h / 2);
    hull()
        for (x = [-1, 1], y = [-1, 1])
            translate([x * (w / 2 - rr), y * (h / 2 - rr)])
                circle(r = rr);
}

module rrect(w, h, t, r) { linear_extrude(height = t) rrect2d(w, h, r); }

module sq_at(z, w) { translate([0, 0, z]) linear_extrude(eps) square([w, w], center = true); }
module circ_at(z, d) { translate([0, 0, z]) linear_extrude(eps) circle(d = d); }

module stack_bolts(t) {
    for (sx = [-1, 1], sy = [-1, 1])
        translate([sx * bx, sy * by, -eps])
            cylinder(h = t + 2 * eps, d = ssd);
}

module port_bolts(t) {
    for (sx = [-1, 1], sy = [-1, 1])
        translate([sx * port_bolt / 2, sy * port_bolt / 2, -eps])
            cylinder(h = t + 2 * eps, d = psd);
}

/* The riser channel every stacked section carries, so the duct continues when a bay is added. */
module through_features(t) {
    translate([riser_x - riser_cut_d / 2, -riser_cut_w / 2, -eps])
        cube([riser_cut_d, riser_cut_w, t + 2 * eps]);
}

/* A slotted field, n slots wide, centred on the origin. */
module slots(t, n, span, sw, pitch, fd) {
    for (i = [0 : n - 1])
        translate([-span / 2 + i * pitch, -fd / 2, -eps])
            cube([sw, fd, t + 2 * eps]);
}

/* ---------------------------------------------------------------- the parts */

/* BAY — a plain frame, plus the riser and the shaft. */
module bay() {
    difference() {
        rrect(stack_w, stack_d, bay_h, corner_r);
        translate([0, 0, -eps]) rrect(bay_cut, bay_cut_d, bay_h + 2 * eps, inner_r);
        stack_bolts(bay_h);
        through_features(bay_h);
    }
}

/* FAN SECTION — discharge bore, cone, fan pocket, cone to the plenum. */
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
        through_features(fan_h);
    }
}

/* LID — a plain cap. It closes the top and leaves turn_clear of headroom so the flow can cross from
   the riser into the bed. No grille, no valve: the U put both of those in the valve section. */
module lid() {
    difference() {
        rrect(stack_w, stack_d, lid_t + turn_clear, corner_r);
        /* the turn-over volume, open downward */
        translate([0, 0, -eps])
            rrect(bay_cut, bay_cut_d, turn_clear + eps, inner_r);
        stack_bolts(lid_t + turn_clear);
        /* the riser opens into the turn-over volume; the shaft does not reach this far */
        translate([riser_x - riser_cut_d / 2, -riser_cut_w / 2, -eps])
            cube([riser_cut_d, riser_cut_w, turn_clear + eps]);
    }
}

/* VALVE SECTION — two legs, two gates, one rod. Ports in the floor, plenums above them. */
module valve_section() {
    difference() {
        rrect(stack_w, stack_d, valve_h, corner_r);

        /* One plenum per leg, above the gate plane, separated by the partition. It starts eps
           BELOW the top of the gate slot: two cut solids that merely touch on a plane are what
           breaks 2-manifoldness, which is why every cut here overlaps its neighbour. */
        for (sy = [-1, 1])
            translate([0, sy * leg_y, gate_z + gate_cut_t - eps])
                rrect(gate_sweep, gate_w, valve_h, inner_r);

        /* the slot each gate slides in */
        for (sy = [-1, 1])
            translate([-gate_sweep / 2 - eps, sy * leg_y - gate_w / 2 - eps, gate_z])
                cube([gate_sweep + 2 * eps, gate_w + 2 * eps, gate_cut_t]);

        /* floor ports: room bore and cabinet port, side by side, per leg */
        for (sy = [-1, 1])
            for (px = [port_x_room, port_x_cab])
                translate([px, sy * leg_y, -eps])
                    cylinder(h = gate_z + 2 * eps, d = sel_cut);

        /* the push-rod, through both gates and out to the servo */
        translate([-stack_w / 2 - eps, 0, rod_z])
            rotate([0, 90, 0])
                cylinder(h = stack_w + 2 * eps, d = rod_cut);

        /* cabinet grilles in the side walls, feeding each leg's cabinet port. Explicit cubes from
           each outer face inward: a mirrored linear_extrude silently cuts nothing on one side, and
           no guard here would catch a wall that stayed solid. */
        for (sy = [-1, 1])
            translate([port_x_cab - grille_cut_w / 2,
                       sy > 0 ? stack_d / 2 - wall - eps : -stack_d / 2 - eps,
                       gate_z + gate_cut_t - eps])
                cube([grille_cut_w, wall + 2 * eps, grille_cut_h + eps]);

        /* the riser leaves one plenum upward; the bed leg arrives in the other */
        translate([riser_x - riser_cut_d / 2, -riser_cut_w / 2, gate_z])
            cube([riser_cut_d, riser_cut_w, valve_h - gate_z + 2 * eps]);
        translate([0, leg_y, gate_z + gate_cut_t - eps])
            cylinder(h = valve_h - gate_z + 2 * eps, d = throat_cut);

        stack_bolts(valve_h);

        /* servo pocket in the -X wall, on the rod axis */
        translate([-stack_w / 2 - eps, -servo_d / 2, rod_z - servo_h / 2])
            cube([servo_w + fdm_hole_comp, servo_d + 2 * fdm_hole_comp,
                  servo_h + 2 * fdm_hole_comp]);

        /* two microswitch pockets, sensing THE ROD at each end of its travel */
        for (sy = [-1, 1])
            translate([-stack_w / 2 + servo_w + 4, sy * (rod_cut / 2 + sw_d), rod_z - sw_h / 2])
                cube([sw_w + 2 * fdm_hole_comp, sw_d + 2 * fdm_hole_comp,
                      sw_h + 2 * fdm_hole_comp]);
    }
}

/* GATE — the plate that slides across one leg's two ports. Long enough to reach either, which
   makes it long enough to span both, and THAT middle position is the cooling state. */
module gate() {
    difference() {
        union() {
            linear_extrude(gate_t) rrect2d(gate_len, gate_w, 2);
            translate([0, 0, gate_t - eps])
                cylinder(h = gate_t + eps, d = rod_d + 4 * perim3);
        }
        translate([0, 0, -eps]) cylinder(h = 3 * gate_t, d = rod_d + 2 * fdm_hole_comp);
    }
}

/* FLANGE — outside the wall, two bores, one gasket racetrack around both. */
module flange() {
    difference() {
        rrect(port_plate_w, port_plate_w, port_plate_t, corner_r);
        for (sy = [-1, 1])
            translate([0, sy * port_bore_pitch / 2, -eps])
                cylinder(h = port_plate_t + 2 * eps, d = bore_cut);
        port_bolts(port_plate_t);
        translate([0, 0, port_plate_t - gasket_t])
            linear_extrude(gasket_t + eps)
                difference() {
                    hull() for (sy = [-1, 1])
                        translate([0, sy * port_bore_pitch / 2]) circle(r = groove_out);
                    hull() for (sy = [-1, 1])
                        translate([0, sy * port_bore_pitch / 2]) circle(r = groove_in);
                }
    }
}

/* CLAMP — the other side of the wall. */
module clamp() {
    difference() {
        rrect(port_plate_w, port_plate_w, port_plate_t, corner_r);
        for (sy = [-1, 1])
            translate([0, sy * port_bore_pitch / 2, -eps])
                cylinder(h = port_plate_t + 2 * eps, d = bore_cut);
        port_bolts(port_plate_t);
    }
}

/* LOUVRE — blanks the room side for an absorb-only installation, and keeps debris out of the bores
   when it does not. */
module louvre() {
    difference() {
        rrect(port_plate_w, port_plate_w, port_plate_t, corner_r);
        for (sy = [-1, 1])
            translate([0, sy * port_bore_pitch / 2, 0])
                slots(port_plate_t, n_in, in_span, in_slot_cut, in_pitch, port_bore);
        port_bolts(port_plate_t);
    }
}

draw_model = true;

if (draw_model) {
    if (draw_part == "bay") bay();
    else if (draw_part == "fan") fan_section();
    else if (draw_part == "valve") valve_section();
    else if (draw_part == "lid") lid();
    else if (draw_part == "gate") gate();
    else if (draw_part == "flange") flange();
    else if (draw_part == "clamp") clamp();
    else if (draw_part == "louvre") louvre();
    else {
        valve_section();
        translate([0, 0, valve_h + 2]) fan_section();
        translate([0, 0, valve_h + fan_h + 4]) bay();
        translate([0, 0, valve_h + fan_h + bay_h + 6]) lid();
        translate([stack_w + 10, 0, 0]) flange();
        translate([stack_w + 10, port_plate_w + 10, 0]) clamp();
        translate([stack_w + 10, -(port_plate_w + 10), 0]) louvre();
        translate([-(stack_w / 2 + gate_len), 0, 0]) gate();
    }
}

echo(str("part rendered      : ", draw_part,
         (draw_part == "stack") ? "  -- EIGHT SOLIDS, preview only" : ""));
echo(str("PORT (the standard): 2 bores of ", port_bore, " at ", port_bore_pitch,
         " pitch, 4x M3 on ", port_bolt, " square, plates ", port_plate_w, " x ", port_plate_t));
echo(str("  gasket racetrack : ", gasket_w, " x ", gasket_t, " mm, reaches r", racetrack_reach,
         " of a plate r", port_plate_w / 2, "  (bolts r", port_bolt_r, ")"));
echo(str("stack footprint    : ", stack_w, " x ", stack_d, ", wall ", wall, ", bolts at +-", bx));
echo(str("  bolt -> cavity   : ", bolt_to_cavity, " mm   bolt -> edge: ", bolt_to_edge, " mm"));
echo(str("riser              : ", riser_cut_w, " x ", riser_cut_d, " = ",
         riser_cut_w * riser_cut_d, " mm2 at x", riser_x,
         " - carried through every section, so stacking a bay extends the duct"));
echo(str("  riser -> bolt    : ", riser_to_bolt, " mm"));
echo(str("  riser -> cavity  : ", riser_to_cavity, " mm   riser -> edge: ", riser_to_edge, " mm"));
echo(str("bay section        : ", bay_h, " tall, cavity ", bay_cut, " x ", bay_cut_d, " as cut"));
echo(str("fan section        : ", fan_h, " tall = throat ", throat_t, " + cone ", trans1,
         " + fan ", fan_depth, " + cone ", trans2));
echo(str("valve section      : ", valve_h, " tall, legs at y+-", leg_y,
         ", ports ", sel_cut, " as cut at x", port_x_room, " and x", port_x_cab));
echo(str("  gate             : ", gate_len, " x ", gate_w, " x ", gate_t,
         ", travel ", gate_travel, ", sweep ", gate_sweep));
echo(str("  seals on         : ", sel_gap, " mm between ports, ", gate_over, " mm of lap"));
echo(str("  cabinet grilles  : ", grille_cut_w, " x ", grille_cut_h, " as cut"));
echo(str("lid                : a plain cap, ", lid_t, " + ", turn_clear, " mm of turn-over"));
echo(str("screws to buy      : M3 x ", screw_len_1, " for one cartridge, x ", screw_len_2,
         " for two, plus engagement"));
echo(str("prints             : every part flat, vertical walls, 45 degree cones - no supports"));

/* BLOCK — impossible geometry. */
assert(draw_part == "bay" || draw_part == "fan" || draw_part == "valve" || draw_part == "lid"
       || draw_part == "gate" || draw_part == "flange" || draw_part == "clamp"
       || draw_part == "louvre" || draw_part == "stack",
       "draw_part must be bay, fan, valve, lid, gate, flange, clamp, louvre or stack");
assert(bolt_to_cavity >= perim3,
       "the stack bolts pass through the cartridge cavity, or leave under 3 perimeters beside it");
assert(bolt_to_edge >= perim3,
       "the stack bolts leave under 3 perimeters outboard - they will split the corner out");
assert(riser_to_cavity >= perim3 && riser_to_edge >= perim3,
       "the riser channel breaks into the cartridge cavity or out through the outer wall");
assert(riser_to_bolt >= perim3,
       "the riser channel runs into a stack bolt - widening it for area is what does this, and no other guard here looks at the bolts");
assert(throat_cut < pocket_w,
       "the discharge bore is wider than the fan pocket - the pocket walls would be cut away");
assert(plenum_cut <= bay_cut, "the plenum is wider than the cartridge it feeds");
assert(trans1 >= 0 && trans2 >= 0,
       "a transition inverts - the fan pocket is not between the bore and the plenum");
assert(2 * leg_y + gate_w < stack_d - 2 * wall,
       "the two legs do not fit side by side in the valve section");
assert(gate_sweep < stack_w - 2 * wall,
       "the gate's swept length does not fit - it would hit the wall at one end of its travel");
assert(gate_len > 2 * sel_cut + sel_gap,
       "the gate cannot span both ports, so nothing shuts them both - there is no cooling state");
assert(gate_over >= perim3,
       "the gate laps a port by under 3 perimeters - that is a leak, not a seal");
assert(sel_gap > perim3,
       "no material between a leg's two ports for the gate to seal against");
assert(gate_z + gate_cut_t < valve_h - perim3,
       "the gate slot breaks through the top of the valve section");
assert(rod_z + rod_cut / 2 < valve_h - perim3,
       "the push-rod breaks through the top of the valve section");
assert(sel_cut <= bore_cut + 2 * perim3,
       "the selectable port is wider than the room bore that feeds it");
assert(racetrack_reach < port_plate_w / 2 - perim3,
       "the gasket racetrack runs off the edge of the plate");
assert(groove_in > port_bore / 2, "the gasket groove runs into the bores");
assert(port_bore_pitch / 2 + bore_cut / 2 < port_plate_w / 2 - perim3,
       "the bores run off the edge of the plate");
assert(n_in >= 1, "no grille slot fits");
assert(in_bar_cut > 0, "the grille slots are grown wider than their pitch - no bars left");
assert(servo_w + 4 + sw_w < stack_w / 2,
       "the servo and a microswitch do not fit along the wall they share");

/* WARN — it builds, but. */
warns = [
    if (wall < perim3 - 1e-9)
        str("wall ", wall, " mm is under 3 perimeters (", perim3, ")"),
    if (in_bar_cut < perim3 - 1e-9)
        str("grille bar as cut ", in_bar_cut, " mm is under 3 perimeters (", perim3,
            ") - nominal ", in_bar_w, " hides that, since each slot grows ", fdm_hole_comp,
            " per side"),
    if (bolt_to_cavity < 2 * perim3)
        str("only ", bolt_to_cavity, " mm between bolt and cavity - thin for a hand-tightened joint"),
    if (gate_over < 2 * perim3)
        str("the gate laps a port by only ", gate_over,
            " mm - a printed gate leaks, and that leak is what the buffer sachet absorbs"),
    if (riser_cut_w * riser_cut_d < 3.14159 * pow(bore_cut / 2, 2) * 0.8)
        str("the riser is ", riser_cut_w * riser_cut_d, " mm2 against a bore of ",
            3.14159 * pow(bore_cut / 2, 2), " mm2 - it is the throttle in the purge path"),
    if (abs(valve_h / fdm_layer_h - round(valve_h / fdm_layer_h)) >= 1e-6)
        str("valve_h ", valve_h, " is not a whole number of ", fdm_layer_h, " layers"),
    if (abs(bay_h / fdm_layer_h - round(bay_h / fdm_layer_h)) >= 1e-6)
        str("bay_h ", bay_h, " is not a whole number of ", fdm_layer_h, " layers"),
    if (abs(fan_h / fdm_layer_h - round(fan_h / fdm_layer_h)) >= 1e-6)
        str("fan section height ", fan_h, " is not a whole number of ", fdm_layer_h, " layers"),
    if (sel_cut > gate_travel)
        str("the gate travels ", gate_travel, " mm to clear a ", sel_cut,
            " mm port - it cannot fully uncover one, so the open path is throttled"),
    if (draw_part == "stack")
        str("draw_part is \"stack\" - the STL is eight solids and will fail the single-part check")
];

for (w = warns) echo(str("WARNING: ", w));
echo(len(warns) == 0
     ? "warnings           : none"
     : str("warnings           : ", len(warns), " - the part will build, read them"));
