/*
desiccant-module.params.scad — THE HEADER

Every value you SET lives here and nowhere else. No geometry, no modules, no derived values: nothing here is computed from anything else, so any line can be changed without reading the rest.

The geometry, the derived values, the echoes and the guards are in desiccant-module.scad, which includes this. Render THAT file, not this one.

WHAT THIS IS. The module that carries desiccant cartridges and pulls box air through them (docs/desiccant-module.md). It is a STACK of printed sections sharing one bolt pattern, not a single moulded body:

        inlet lid        grille + the sensor pocket, box air enters here
        bay section      one cartridge; ADD A SECTION PER CARTRIDGE
        [filter sheet]   HEPA paper, clamped between sections - not printed
        fan section      plenum, fan pocket, discharge to the PORT
        ---- port ----   flange + clamp through a wall, or the louvre plate

⭐ THE PORT IS THE STANDARD, NOT THE MODULE. Every enclosure provides the same bore and the same four screws; the module body never changes between a 22 L box and a cabinet. Those four numbers are therefore in ONE place - here - and everything that mates is derived from them.

⭐ CAPACITY SCALES BY STACKING. Two cartridges is two bay sections and four longer screws, not a redesign.

Tags to keep honest as you edit:
    MEASURED      taken off the real part with calipers
    <<CONFIRM>>   assumed, NOT measured, and still feeding the fit
    MIRRORED      copied from another model; nothing here can check it

Comment style: prose is one long line per paragraph inside a block comment. OpenSCAD does not nest block comments - a close token inside prose ends the comment there.
*/

/* [Which part to render] */
/* One solid per render: scad-check.sh asserts a single-part STL. "stack" is a preview of the assembly and must not be exported. */
draw_part = "bay";  /* "bay" | "fan" | "lid" | "flange" | "clamp" | "louvre" | "stack" */

/* [THE PORT — the interface every enclosure must provide] */
/* Change these and you change what every future box has to be cut for. That is the point of them being four numbers in one file. */
port_bore = 62;         /* Bore in the enclosure wall. */
port_bolt = 70;         /* Bolt circle, square pitch, symmetric so orientation never matters. */
port_screw_d = 3.4;     /* M3 clearance. */
port_plate_w = 92;      /* Outline of the flange, clamp and louvre plates. */
port_plate_t = 4;       /* Their thickness. */
panel_max = 25;         /* Thickest enclosure wall the clamp is specified for. Feeds the screw-length echo only - the clamp itself does not change. */
spigot_len = 8;         /* Flange spigot that enters the bore and locates the plate. */
spigot_clear = 0.5;     /* Per side, in the bore. */
gasket_w = 4;           /* Gasket groove width in the flange face. */
gasket_t = 1.4;         /* Groove depth. Size it to the cord you actually have. */

/* [The stack] */
/* 152, not the 138 this started as, and the reason is the bolts rather than the cartridge. The bay cavity is cart_w + 2 * bay_clear = 131.2 wide, so at 138 the wall is 3.4 mm and a bolt inset 7 from the corner lands at +-62 - INSIDE the cavity, where there is no material to pass through. The floor is cavity/2 + screw/2 + 3 beads = 68.65, so the bolt circle has to sit outside that and the outline outside the bolt. The guard asserts exactly this, so the number is checked rather than trusted. */
stack_w = 152;          /* Footprint of the bay, fan and lid sections. */
stack_d = 152;
wall = 2.4;             /* Section wall. Bolted, handled, and carrying a fan - not a 2-bead wall. */
corner_r = 3;
/* 5, not 7. At 7 the bolt sits 1.4 mm from the cartridge cavity - over the 3-bead floor but
   thin for a joint tightened by hand, which the guard said and the first render reported.
   Moving the bolts OUTWARD costs nothing here: it buys 3.4 mm to the cavity and still leaves
   3.15 mm outboard, without growing the footprint. */
bolt_inset = 5;         /* Stack screw centres, in from each outer corner on both axes. */
stack_screw_d = 3.4;    /* M3 clearance; the stack is held by four long screws or studs. */

/* [The cartridge this carries — MIRRORED from models/desiccant-cartridge] */
/* ⚠️ Nothing here can read that model. If either changes, check both: the guard below only knows what is typed here. */
cart_w = 130;           /* MIRRORED */
cart_d = 130;           /* MIRRORED */
cart_h = 45;            /* MIRRORED */
bay_clear = 0.6;        /* Per side, so a warm cartridge still drops in. */

/* [Fan] */
fan_size = 60;          /* <<CONFIRM>> 60 mm 12 V is the assumption in the doc; nothing is owned yet. */
fan_depth = 25;         /* Body thickness of the fan. */
/* ⛔ THE FAN IS CLAMPED, NOT SCREWED, and that is a decision rather than an omission. A 60 mm fan's mounting holes sit at +-25 in both axes - INSIDE a 61.5 mm pocket - so a pilot hole for them would have to be drilled in mid-air. The fan drops into the pocket and the section above traps it, along with the filter sheet. There is consequently no fan_pitch or fan_screw_d here: a parameter nothing uses is a promise the model does not keep. */
fan_clear = 0.75;       /* Per side, in the pocket. */
throat_d = 56;          /* Discharge hole under the fan. Must stay inside the fan pocket. */
throat_t = 3;           /* Straight section before the transition opens out. */
plenum_w = 110;         /* Where the cone stops widening under the cartridge. */

/* [Inlet grille and lid] */
lid_t = 3;              /* Lid plate. */
in_slot_w = 4;          /* Inlet slots. Wider than the cartridge's - this one only keeps fingers and debris out. */
in_bar_w = 2.4;
in_margin = 9;          /* Solid border around the slotted field. */

/* [Sensor pocket — on the INLET side, in box air] */
/* 🔑 In the return path the sensor would read the driest air in the system and call a wet box healthy. It belongs where the air arrives. */
sensor_w = 20;          /* <<CONFIRM>> a breakout board's envelope. */
sensor_d = 16;
sensor_h = 5;
sensor_screw_d = 2.2;   /* M2 pilot. */
sensor_pitch = 15;      /* <<CONFIRM>> mounting-hole spacing on the breakout. */
cable_w = 7;            /* Cable slot out of the pocket. */

/* [Slicer facts — MIRROR these from the profile, do not invent them] */
fdm_layer_h = 0.2;
fdm_extrusion_w = 0.45;
fdm_hole_comp = 0.15;

perim2 = 2 * fdm_extrusion_w;
perim3 = 3 * fdm_extrusion_w;

/* [Printing] */
/* Every section prints flat with vertical walls: the bay is a plain frame, the lid is a plate, and the fan section's internal transitions are 45 degree cones that grow outward going up. Nothing bridges and nothing needs support - checked by the overhang guard rather than asserted in prose. */
$fn = 64;
