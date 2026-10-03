// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
Everything you SET for the print-chamber box. Render print-chamber-box.scad, not this file.

The box for the node in firmware/print-chamber.yaml: an SPS30 particle sensor standing on edge with its
air face DOWN, the ESP32-C3 SuperMini above it, and the GY-SGP41 between the two. Why that layout,
with a source for each rule, is in docs/design.md; where each value came from, in docs/parameters.md.

COORDINATES are the box as INSTALLED: Y out from the mounting surface, Z up, and X - because the
frame is right-handed - pointing to YOUR LEFT as you face the box. "Left" and "right" in the
comments mean as you face it. The board's USB-C end faces the SPS30's connector, so the USB-C cable
leaves at that end - on your RIGHT with the sensor in hand.
*/

/* [Which part] */
part = "back";   /* "back", "cover", or "assembly" (preview only - several parts, not printable). */

/* [The SPS30 - from its datasheet v2.0, Figure 7, and its width measured] */
sps_w    = 40.69;  /* Along the air face (X), across the body beside the nubs. Measured 3 Oct 2026 with calipers (Alon; docs/sps30-measure.png, B). The datasheet gives 40.6 +/- 0.3 without the shipping foil, which can stay on. */
sps_h    = 40.6;   /* The other side of the big face (Z). Datasheet; not measured. */
sps_t    = 12.2;   /* Thickness (Y). 12.2 +/- 0.3. */
sps_nub  = 0.155;  /* Each side: the plastic nubs on the side faces. Measured 41.00 across them on 3 Oct 2026 (Alon; docs/sps30-measure.png, A), so (41.00 - 40.69) / 2. The datasheet's 41.2 across left the clearance test's frame A about 0.7 mm loose in X. */

/* [Measured from the parts in hand - `unmeasured` below lists what is still a placeholder] */
divider_from_inlet_end = 17.7;   /* Along the air face, from the INLET end to the middle of the gap between the inlets and the outlet grille. From photo 3, 2 Oct 2026, scaled against the sensor's 40.6 mm width: three features land within 0.4 mm of the datasheet, so the scale holds. */
sps_inlet_end   = 15.2;          /* Where the inlets END, from the inlet end - the one that wraps onto the label face reaches furthest. Datasheet Figure 7; photo 3 reads 14.9. */
sps_outlet_from = 20.2;          /* Where the outlet grille STARTS, from the inlet end. Photo 3. The divider must sit between these two. */
outlet_at_left = false;          /* SETTLED from photos, 2 Oct 2026: facing the box, label towards you, air face down, the outlet grille is on your RIGHT and the two inlets on your left. The connector is at the outlet end (datasheet Figure 7, and the photos agree). */
sm_l         = 22.8;   /* SuperMini PCB length, not counting the USB-C shell that overhangs it. Measured 2 Oct 2026. */
sm_w         = 18.03;  /* SuperMini width. Measured. */
sm_pcb_t     = 0.85;   /* Bare PCB thickness. Measured. */
sm_t         = 4.05;   /* PCB plus its tallest component - the USB-C shell - without the antenna. Measured. */
usb_shell_h  = 3.16;   /* The USB-C shell's height. Measured. It sits on the component side (0.85 + 3.16 = 4.01, against sm_t 4.05), so its centre is sm_pcb_t + usb_shell_h / 2 above the PCB's underside. */
wire_perpendicular = true;   /* SETTLED from photos, 2 Oct 2026: the straight part stands out of the component side, at an angle - the board leans on it when laid face down. */
ant_h        = 18.8;   /* Height of the antenna wire's tip above the PCB's UNDERSIDE, board lying flat. Measured 2 Oct 2026 - it sets the box's depth. */
ant_over     = 4.81;   /* How far the antenna LOOP reaches past the PCB's antenna end. It lies in the board's plane, so the middle of that end of the pocket is left open for it. Measured. */
ant_loop_free = 4.3;   /* How much of the board's antenna end the loop leaves free beside it: 4.3 mm on one side and 5.45 on the other, measured 2 Oct 2026. The smaller is used on both sides, so the box fits the board either way round. */
pin_mid      = 5.1;    /* The middle of the SuperMini's three power pins (5V, GND, 3V3), from its PCB's USB-C end. Photo 1, scaled against the board, reads 2.6, 5.1 and 7.7 mm. The cable channel stands under it, so the wires leave its top straight into those pads. */
usb_overhang = 1.5;    /* How far the USB-C shell overhangs the PCB's edge. It passes through the wall, and its mouth reaches the outside face (see port_wall). Measured. */
usb_shell_w  = 8.94;   /* The USB-C shell's width. Not measured, derived: the USB Type-C compliance document fixes the receptacle's inside opening at 8.34 x 2.56 mm, and the measured height 3.16 against that 2.56 gives a 0.30 mm shell wall - so 8.34 + 2 x 0.30. */
gy_l        = 13.14;  /* GY-SGP41 module. Measured 2 Oct 2026. */
gy_w         = 10.60;
gy_t         = 3.24;   /* With its parts. The sensor is on one face and the rest of the electronics on the other, so it cannot lie flat on either: sensor towards the vents means electronics towards the plate. */
gy_back      = 2.53;   /* The GY-SGP41 through its PCB and electronics, clamped beside the sensor - its height lying sensor-up on its electronics. Measured 2 Oct 2026. The sensor makes up the rest of gy_t. */
gy_bare      = 3.31;   /* The nearest part on the GY-SGP41's underside, from the end opposite its pins. Measured 2 Oct 2026. The SGP41's ledge stops `gap / 2` short of it, so its parts never bear load. */
gy_standoff_d = 4.0;   /* A round standoff under the mounting hole, which the screw clamps the module onto. It must stay inside gy_hole_bare_d. */
gy_hole_bare_d = 5.2;  /* The bare patch round the mounting hole on the underside: photo 2 puts the nearest parts beside and above the hole about 2.6 mm from its centre. A photo reading, not a measurement; the collision check uses it as the parts' edge. */
gy_hole_d    = 3.13;   /* The GY-SGP41's mounting hole. Measured 2 Oct 2026. It takes the M2.5 screw that holds the module down. */
gy_hole_far  = 1.32 + gy_hole_d / 2;   /* The hole's centre from the module's far end, the short edge opposite its pins: 1.32 to the hole's edge, measured 2 Oct 2026. */
gy_hole_side = 1.25 + gy_hole_d / 2;   /* The hole's centre from the nearer long edge, the one away from the sensor: 1.25 to the hole's edge, measured 2 Oct 2026. */
conn_from    = 2.0;    /* The SPS30's plug and lead, along its top face, from the OUTLET end. Photo 1, 2 Oct 2026, scaled against the 40.6 mm sensor: the wires leave 3.0 to 8.6 mm from that end, and the plug's housing reaches about 1 mm past each. Nothing stands in that column. */
conn_to      = 10.5;
cable_zone_h = 10.0;   /* Room above the SPS30's connector face: lead plugged in and bent over as tightly as it comfortably goes, from the sensor's top to the highest wire. Measured 2 Oct 2026. */

/* The wall screw the box hangs on, by the keyhole in its back plate. Placeholders for a typical 3.5 mm
   wood screw until the screw that will be used is measured. */
key_shank_d = 3.5;   /* Its thread, across. */
key_head_d  = 7.0;   /* Its head, across. */
key_head_h  = 2.6;   /* Its head, tall. */

unmeasured = ["key_shank_d", "key_head_d", "key_head_h"];
/* Delete a name from this list once its value is measured. While any remain, the model echoes a
   WARNING and scripts/scad-check.sh exits 2 - which is the INTENDED state until then. */

/* [The USB-C cable - sourced, so no cable needs measuring] */
usb_plug_w = 12.35;   /* The widest a compliant plug's body may be: USB Type-C compliance document rev 1.2, Figure B-1, dimension 1. */
usb_plug_h = 6.5;     /* The thickest: same table, dimension 14. The socket's mouth reaches the outside face, so the body never enters the box; it only has to clear the mounting surface and the tabs, and the model echoes the thickest body that does. */

/* [Bounds, not measurements - the design works anywhere inside them] */
gy_pcb_min = 0.8;   /* The thinnest the GY-SGP41's bare board could plausibly be; GY modules are usually 1.0-1.6 mm. The ledge is tall enough that parts on a board this thin still clear the floor. */
gy_pcb_max = 1.6;   /* The thickest, for the room left in front of it. */

/* [The SGP41's screw - an M2.5 socket head cap screw, ISO 4762] */
gy_screw_d = 2.5;   /* M2.5. */
gy_screw_l = 8.0;   /* M2.5 x 8, from the M2.5 box. It cuts its own thread in the ledge's pilot. */
gy_head_d  = 4.5;   /* ISO 4762 head diameter for M2.5. */
gy_head_h  = 2.5;   /* ISO 4762 head height for M2.5. */

/* [Fits - the ones still untested in ASA on this printer are listed in `untested_fits` below] */
sps_fit    = 0.2;    /* Clearance per side around the SPS30. Tested 2 Oct 2026 (the clearance test, Inslogic ASA, MK3S): of 0.2, 0.3 and 0.4 the SPS30 took the tightest, 0.2, and it was snug (Alon) - so 0.2 stands, though nothing tighter was tried. Looked at closer on 3 Oct: flush across its thickness (Y), about 0.7 mm loose along its width (X) - the width allowance, sps_nub, is the datasheet's and waits on a caliper reading of the sensor. */
pocket_fit = 0.2;    /* Clearance per side around the two boards. Tested 2 Oct 2026, same print: the SuperMini and the GY-SGP41 each took the tightest of 0.2, 0.3 and 0.4, and both were snug (Alon). */
part_fit   = 0.3;    /* Clearance between a back-plate feature and the cover. Measured 3 Oct 2026 on the same print: peg 5.98, socket 6.50 (Y) and 6.55 (X), so 0.26 and 0.29 per side as printed - over the 0.15 below which the parts would bind. */
pilot_d    = 2.3;    /* Pilot hole for the M3 x 14 self-tapping screws that close the cover. Tested 3 Oct 2026: of 2.3, 2.5 and 2.7, 2.5 was fine and 2.3 a little tight, "which might be preferable" (Alon); none split. 2.3, for a thread that is driven again each time the cover comes off. */
screw_d    = 3.2;    /* Clearance hole for those screws in the cover. Tested 3 Oct 2026: of 3.2, 3.4 and 3.6, an M3 passes 3.2 freely. */
gy_pilot_d = 2.1;    /* Pilot for the SGP41's M2.5 screw, which forms its own thread in it. Tested 3 Oct 2026: of 2.0, 2.1 and 2.2, 2.1 is fine and 2.0 a little tight (Alon). */

untested_fits = [];
/* ASA shrinks more than PETG, and holes print undersize. Print a clearance ladder before the box, then
   clear this list. */

/* [Walls - widths in beads of fdm_extrusion_w, thicknesses in layers of fdm_layer_h] */
wall      = 1.8;    /* Side, top and bottom walls of the cover: 4 beads. */
back_t    = 2.4;    /* The back plate, printed flat: 12 layers. The keyhole runs through it, so it is also what the wall screw's head bears on. */
front_t   = 1.8;    /* The cover's front, printed flat on the bed: 9 layers. */
cradle_t  = 1.35;   /* The walls of the channel the SPS30 slides into: 3 beads. */
divider_t = 1.35;   /* The divider between the inlet and outlet sides: 3 beads. */
rib_t     = 1.35;   /* The cover's internal ribs: 3 beads. */
rim_t     = 0.9;    /* The rims that locate the two boards: 2 beads. */
port_wall = 0.9;    /* The cover's wall where the board's USB-C end meets it, thinned from inside so the socket's mouth reaches the outside face: 2 beads. With the 1.5 mm overhang this is as thick as it can be. */

/* [Airflow] */
divider_proud = 4.0;   /* How far the divider stands below the box, so the outlet's stream cannot loop straight back to the inlets. */
front_gap_min = 2.5;   /* Least air gap in front of the SPS30's label face - one inlet wraps round onto that face. */
vent_w        = 2.0;   /* Width of each vent slot. */
vent_rib      = 1.8;   /* Material between vent slots: 4 beads. */

/* [Holding the sensor, the boards and the wires] */
ledge  = 1.0;   /* How far the ledges reach under each end of the air face. Must stay clear of the openings. The SPS30 is put in from the front and stands on them; the cover's partition rib, 0.3 mm in front of its face, keeps it there. */
sm_edge    = 1.0;   /* The strip along each long edge of the SuperMini's component side that holds only its castellated pads, nothing taller. Photo 1. The rails' lips may reach over it, no further. */
sm_lip_over = 0.6;  /* How far each rail's lip reaches over the board's long edge, onto that pad strip. The board slides in under the lips, and they keep it down on the plate. */
stop_reach = 3.0;   /* The two stops at the board's antenna end take the push of plugging the cable in. Each reaches this far in from the rim over a corner; the middle stays open for the antenna loop. */
wire_room  = 7.0;   /* Room behind the pin half of the SGP41's board, for its four wires. They are the lab's 22 AWG solid hookup wire (Alon, 2 Oct 2026: "solid wire thats owned"; HomeBox has five 10 m coils of 22 AWG solid, UL1007; Alon measured it at 1.56 mm over its insulation). Soldered to come out of its back, each leaves its pad straight for 1 mm, bends over on a 3 mm radius, and where two cross - the module's pins run in the reverse order of the board's - one lies behind the other. That takes 6.4 mm; assembly-views.scad draws the routes and checks them against this, and check_components keeps the pedestal out of it. Alon, 2 Oct 2026: "the wires could be solderd to come out on the back of sgp41. make 8 smaller." Before that they came out of its front, and this was the room in front, which pushed the sensor further from its vents. */
wire_slot_w = 3.5;  /* The cable channel, standing upright under the board's power pins: its slot, across. The SPS30's five wires, about 1 mm each, lie in it; the SGP41's go straight across in front. */
wire_slot_d = 4.0;  /* ... and how deep it is, from the plate. */
wire_ch_l   = 6.0;  /* ... and how long, measured down from just below the board, so the wires leave its top straight into the power pins. Alon, 2 Oct 2026: the full drop from the SPS30 to the board was too long. */
wire_lip_gap = 1.0; /* The opening between the channel's two 45-degree lips: a wire presses in past them and stays. */

/* [Mounting and closing] */
key_slack = 1.0;    /* How much further than back_t the wall screw's head may stand off the wall: the room behind the plate is that much deeper than the head. */
boss_d    = 6.75;   /* The cover-screw bosses. */
corner_r  = 4.0;    /* Plan-view corner radius. ASA lifts at sharp corners; a radius is the permanent cure (fdm-design-rules §5b). */
gap       = 1.0;    /* General clearance between internal features. */

/* [Print reality - cross-checked by scripts/scad-check.sh against the profile used] */
fdm_layer_h     = 0.2;
fdm_extrusion_w = 0.45;
fdm_hole_comp   = 0.15;   /* Added to every hole's radius - fdm-design-rules §2. Not cross-checked. */

/* Opened on its own, this file draws nothing - it only holds numbers. */
if (is_undef(draw_model))
    echo("THIS IS THE SETTINGS FILE - numbers only, so the view stays empty. Open print-chamber-box.scad to see the model.");
