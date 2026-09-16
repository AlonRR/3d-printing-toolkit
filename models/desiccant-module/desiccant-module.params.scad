/*
desiccant-module.params.scad — THE HEADER

Every value you SET lives here and nowhere else. No geometry, no modules, no derived values: nothing here is computed from anything else, so any line can be changed without reading the rest.

The geometry, the derived values, the echoes and the guards are in desiccant-module.scad, which includes this. Render THAT file, not this one.

WHAT THIS IS. The module that carries desiccant cartridges, pulls box air through them, and REGENERATES ITSELF by sealing the filament area and baking the bed out to the room (docs/desiccant-module.md). It is a STACK of printed sections sharing one bolt pattern:

        lid              a PLAIN CAP - it turns the flow from the riser into the bed
        bay section      one cartridge; ADD A SECTION PER CARTRIDGE
        [filter sheet]   HEPA paper, clamped between sections - not printed
        fan section      plenum and fan pocket
        valve section    both barrel valves, both cabinet grilles, both room bores, the sensor
        ---- port ----   flange + clamp through the enclosure wall

The duct is a U: air goes UP the riser, over at the lid, DOWN through the bed, and out at the bottom - so both ends arrive in the valve section and one valve assembly serves all four paths.

⭐ THE PORT IS THE STANDARD, NOT THE MODULE. Every enclosure provides the same two bores and the same four screws; the module body never changes between a 22 L box and a cabinet.

⭐ CAPACITY SCALES BY STACKING. Two cartridges is two bay sections and four longer screws. The riser below is carried through every section at the same place, so stacking a bay extends the duct with it rather than breaking it.

Tags to keep honest as you edit:
    MEASURED      taken off the real part with calipers
    <<CONFIRM>>   assumed, NOT measured, and still feeding the fit
    MIRRORED      copied from another model; nothing here can check it

Comment style: prose is one long line per paragraph inside a block comment. OpenSCAD does not nest block comments - a close token inside prose ends the comment there.
*/

/* [Which part to render] */
/* One solid per render: scad-check.sh asserts a single-part STL. "stack" is a preview and must not be exported. */
draw_part = "bay";  /* "bay" | "fan" | "valve" | "lid" | "flange" | "clamp" | "louvre" | "drum" | "stack" */

/* [THE PORT — the interface every enclosure must provide] */
/*
⚠️ TWO BORES, NOT ONE. Alon's call, 16 Sep 2026. A purge has to take room air IN and push it OUT while the filament area is sealed; through a single bore the module breathes in and out of the same hole and re-inhales its own damp exhaust. Two bores make the purge once-through.

Changing this changes what every future enclosure has to be cut for, which is exactly why it is four numbers in one file and why it was settled before anything was cut.
*/
port_bore = 40;         /* Each of the two bores. */
port_bore_pitch = 46;   /* Centre to centre. Intake low, exhaust high. */
port_bolt = 70;         /* Bolt square, symmetric so orientation never matters. */
port_screw_d = 3.4;     /* M3 clearance. */
/* 110, not 100. Two 40 mm bores on a 46 mm pitch already span 86 mm, and the gasket racetrack
   that has to encircle BOTH reaches r50 from centre - so a 100 mm plate has no edge left. The
   guard checks the groove against the plate rather than trusting this number. */
port_plate_w = 110;     /* Outline of the flange, clamp and louvre plates. */
port_plate_t = 4;       /* Their thickness. */
panel_max = 25;         /* Thickest enclosure wall the screws are specified for. */
gasket_w = 4;           /* Gasket groove width in the flange face. */
gasket_t = 1.4;         /* Groove depth. Size it to the cord you actually have. */
gasket_margin = 5;      /* Groove standoff outside the bores - it encircles BOTH, as a racetrack. */

/* [The stack] */
/* 152, not the 138 this started as, and the reason is the bolts rather than the cartridge. The bay cavity is cart_w + 2 * bay_clear = 131.2 wide, so at 138 the wall is 3.4 mm and a bolt inset 7 from the corner lands at +-62 - INSIDE the cavity, where there is no material to pass through. The guard asserts the relation, so the number is checked rather than trusted. */
stack_w = 152;
stack_d = 152;
wall = 2.4;             /* Section wall. Bolted, handled, and carrying a fan - not a 2-bead wall. */
corner_r = 3;
/* 5, not 7. At 7 the bolt sits 1.4 mm from the cartridge cavity - over the 3-bead floor but thin for a joint tightened by hand, which the guard said and the first render reported. Moving the bolts OUTWARD buys 3.4 mm to the cavity and still leaves 3.15 mm outboard, without growing the footprint. */
bolt_inset = 5;
stack_screw_d = 3.4;    /* M3 clearance; the stack is held by four long screws or studs. */

/* [The riser — room air from the bottom bore to the top of the stack] */
/*
The fan always pulls from the lid end downward. Room air therefore enters at the BOTTOM and has to reach the TOP before it can cross the bed, so every section carries the same channel through one wall. Stack another bay and the duct grows with it.
*/
/* ⚠️ THE RISER IS THE THROTTLE, and the model said so rather than leaving it to be discovered on a
   bench: at 34 x 7 it offered 250 mm2 against a 1276 mm2 bore, so the purge path was choked by the
   channel and not by the ports. Area is what matters here, and depth is the expensive direction -
   it eats the wall band between the cartridge cavity and the outer skin. Widened instead, and the
   guard reports the ratio every render. */
/* ⛔ DEPTH IS THE EXPENSIVE DIRECTION. The wall band between the cartridge cavity and the outer skin
   is only (stack_w - bay_cut) / 2 = 10.25 mm, and the riser is cut INTO it: at 9 mm deep it left
   0.475 mm each side and the guard refused the whole model. Depth stays at 7, which leaves ~1.5 mm
   of skin either side, and the area comes from WIDTH instead - the channel runs along a 152 mm face
   and only has to stay clear of the bolts at +-71. */
riser_w = 96;           /* Channel width, in the mid-face wall. Cheap: it costs no wall thickness. */
riser_d = 7;            /* Channel depth. Expensive: every mm comes off the skin either side. */
riser_face = "left";    /* "left" or "right" - which wall carries it. The shaft takes the other. */

/* [The cartridge this carries — MIRRORED from models/desiccant-cartridge] */
/* ⚠️ Nothing here can read that model. If either changes, check both. */
cart_w = 130;           /* MIRRORED */
cart_d = 130;           /* MIRRORED */
cart_h = 45;            /* MIRRORED */
bay_clear = 0.6;        /* Per side, so a warm cartridge still drops in. */

/* [Fan] */
fan_size = 60;          /* <<CONFIRM>> 60 mm 12 V is the assumption in the doc; nothing is owned yet. */
fan_depth = 25;
/* ⛔ THE FAN IS CLAMPED, NOT SCREWED. A 60 mm fan's mounting holes sit at +-25 in both axes - INSIDE a 61.5 mm pocket - so a pilot for them would be drilled in mid-air. The fan drops into the pocket and the section above traps it, along with the filter sheet. There is consequently no fan_pitch or fan_screw_d: a parameter nothing uses is a promise the model does not keep. */
fan_clear = 0.75;
throat_d = 56;          /* Discharge under the fan. Must stay inside the fan pocket. */
throat_t = 3;
plenum_w = 110;         /* Where the cone stops widening under the cartridge. */

/* [The valve section — where all four paths meet] */
/*
⭐ THE DUCT IS A U, AND THAT IS WHAT MAKES ONE VALVE ENOUGH. The fan pulls from the lid end
downward, so room air entering at the bottom has to climb before it can cross the bed: the riser and
the bed are the two legs, and BOTH ENDS OF THE DUCT THEREFORE ARRIVE AT THE BOTTOM SECTION. The lid
stops being a valve and becomes a plain cap that turns the flow over.

That collapses the hard part. All four paths meet in one section:

        riser leg  <- cabinet intake grille  |  or room intake bore
        bed leg    -> cabinet return grille  |  or room exhaust bore

⭐ THREE STATES FROM ONE MOVING PART, AND A BARREL DRUM IS NOT IT. The first cut used a drum in a
round chamber; the guard refused it on its own defaults, because a window cut through a 44 mm drum
leaves 5 mm of blank and the room bore is 40.3 mm as cut - nothing could ever shut it. A single
window would need the duct to connect AXIALLY, and in a U duct it arrives radially. The mechanism was
wrong, not the numbers.

What works is a SLIDING GATE per leg. The two ports sit side by side in the floor and a plate slides
across them, so the middle state comes free: a gate long enough to reach either port also spans both.

    ABSORBING    gate at one end     room bore shut, cabinet port open
    COOLING      gate in the middle  BOTH shut
    EXHAUSTING   gate at other end   room bore open, cabinet port shut

Both gates ride ONE push-rod off a single servo crank.

⛔ The microswitches sense THE ROD, never the servo: a servo reports the angle it was told to go to,
which is the failure the heater interlock exists to catch.
*/
valve_h = 40;           /* Valve section height - gates, rod and the two plenums live in here. */
sel_port = 34;          /* Each selectable port in the floor: room bore and cabinet port alike. */
sel_gap = 10;           /* Material between a leg's two ports - what the gate seals against. */
gate_t = 2.4;           /* Gate plate. */
gate_clear = 0.35;      /* Gate to its guide, per side. Printed gates do not seal like solenoids;
                           the buffer sachet in the filament area is what makes that acceptable. */
gate_over = 4;          /* How far the gate laps past a port it is covering. */
rod_d = 4;              /* Push-rod, a steel rod rather than a printed one - it takes the load. */
rod_clear = 0.35;
crank_r = 14;           /* Servo crank radius; travel is 2 * crank_r across the three positions. */
partition = 3;          /* Wall between the two legs' plenums. */
grille_w = 40;          /* Cabinet-side opening in the valve section's side wall, per leg. */
grille_h = 26;

/* Servo and switches — <<CONFIRM>> every one against the parts in hand before printing. */
servo_w = 23.0;         /* <<CONFIRM>> SG90 body. */
servo_d = 12.2;         /* <<CONFIRM>> */
servo_h = 22.5;         /* <<CONFIRM>> */
servo_flange = 32.2;    /* <<CONFIRM>> across the mounting ears. */
servo_screw_d = 2.2;    /* <<CONFIRM>> M2 into the ears. */
sw_w = 19.8;            /* <<CONFIRM>> microswitch body. */
sw_d = 6.4;             /* <<CONFIRM>> */
sw_h = 10.2;            /* <<CONFIRM>> */
sw_pitch = 9.5;         /* <<CONFIRM>> mounting hole centres. */
sw_screw_d = 2.4;       /* <<CONFIRM>> */

/* [The lid, and the cabinet grilles] */
/* ⭐ THE LID IS NOW A PLAIN CAP. With the duct folded into a U it only turns the flow from the riser
   into the bed, so it carries no grille and no valve - and the slots that used to be here moved to
   the valve section's cabinet-side openings, which is where box air actually enters. */
lid_t = 3;
turn_clear = 10;        /* Headroom above the cartridge for the flow to turn over. */
in_slot_w = 4;          /* Cabinet grille slots - they only keep fingers and debris out. */
in_bar_w = 2.4;
in_margin = 6;          /* Solid border around a grille field. */

/* [Sensor pocket — at the CABINET INTAKE grille, in box air] */
/* 🔑 In the return path the sensor would read the driest air in the system and call a wet box
   healthy. It sits at the cabinet intake, which is also the one opening that is shut during a purge -
   so a reading taken then describes the module, not the box, and the firmware ignores it. */
sensor_w = 20;          /* <<CONFIRM>> a breakout board's envelope. */
sensor_d = 16;
sensor_h = 5;
sensor_screw_d = 2.2;   /* M2 pilot. */
sensor_pitch = 15;      /* <<CONFIRM>> mounting-hole spacing on the breakout. */
cable_w = 7;

/* [Slicer facts — MIRROR these from the profile, do not invent them] */
fdm_layer_h = 0.2;
fdm_extrusion_w = 0.45;
fdm_hole_comp = 0.15;

perim2 = 2 * fdm_extrusion_w;
perim3 = 3 * fdm_extrusion_w;

/* [Printing] */
/* Every section prints flat with vertical walls: the bay is a plain frame, the lid is a plate, and the fan section's internal transitions are 45 degree cones that grow outward going up. Nothing bridges and nothing needs support - checked by the guards rather than asserted in prose. */
$fn = 64;
