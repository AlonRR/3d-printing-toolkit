// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
Everything you SET for the print-chamber box. Render print-chamber-box.scad, not this file.

The box for the node in firmware/print-chamber.yaml: an SPS30 particle sensor standing on edge with its
air face DOWN, the ESP32-C3 SuperMini above it, and the GY-SGP41 between the two. Why that layout,
with a source for each rule, is in README.md.

COORDINATES are the box as INSTALLED: Y out from the mounting surface, Z up, and X - because the
frame is right-handed - pointing to YOUR LEFT as you face the box. "Left" and "right" in the
comments mean as you face it. The USB-C cable leaves the box on your left.
*/

/* [Which part] */
part = "back";   /* "back", "cover", or "assembly" (preview only - several parts, not printable). */

/* [The SPS30 - sourced from its datasheet v2.0, Figure 7] */
sps_w    = 40.6;   /* Along the air face (X). 40.6 +/- 0.3 without the shipping foil, which can stay on. */
sps_h    = 40.6;   /* The other side of the big face (Z). */
sps_t    = 12.2;   /* Thickness (Y). 12.2 +/- 0.3. */
sps_nub  = 0.3;    /* Each side: the plastic nubs on the side faces make it 41.2 across. */

/* [MEASURE THESE - placeholders until then; see `unmeasured` below] */
divider_from_inlet_end = 18.0;   /* Along the air face, from the INLET end to the middle of the gap before the outlet grille. 18.0 is scaled off the datasheet drawing, not measured. */
outlet_at_left = true;           /* Viewed from the front with the label facing you and the air face down: is the outlet grille at the left end? The connector is at the same end as the outlet (datasheet Figure 7). */
sm_l         = 22.5;   /* SuperMini length, USB-C end to antenna end. */
sm_w         = 18.0;   /* SuperMini width. */
sm_pcb_t     = 1.0;    /* Bare PCB thickness. */
sm_t         = 4.0;    /* PCB plus its tallest component, as populated. */
usb_center_h = 2.6;    /* Height of the USB-C receptacle's centre above the BACK of the PCB. */
wire_perpendicular = true;   /* Does the antenna wire's straight 15 mm stand OUT of the board (true) or run along it, past the antenna end (false)? */
wire_h       = 15.0;   /* How far the antenna wire reaches - above the board, or past its end. */
usb_plug_w   = 12.5;   /* The cable's PLUG BODY, not the receptacle: the opening has to pass the overmould. */
usb_plug_h   = 7.0;
gy_l         = 15.0;   /* GY-SGP41 module. */
gy_w         = 12.0;
gy_t         = 3.0;
cable_zone_h = 10.0;   /* Room above the SPS30's connector face for the plug and the bend in the lead. */

unmeasured = ["divider_from_inlet_end", "outlet_at_left", "sm_l", "sm_w", "sm_pcb_t", "sm_t",
              "usb_center_h", "wire_perpendicular", "wire_h", "usb_plug_w", "usb_plug_h",
              "gy_l", "gy_w", "gy_t", "cable_zone_h"];
/* Delete a name from this list once its value is measured. While any remain, the model echoes a
   WARNING and scripts/scad-check.sh exits 2 - which is the INTENDED state until then. */

/* [Fits - untested in ASA on this printer; see `untested_fits` below] */
sps_fit    = 0.3;    /* Clearance per side around the SPS30. fdm-design-rules records NO house default - this is a placeholder. */
pocket_fit = 0.3;    /* Clearance per side around the two boards. */
part_fit   = 0.3;    /* Clearance between a back-plate feature and the cover. */
pilot_d    = 2.5;    /* Pilot hole for the M3 x 14 self-tapping screws that close the cover. */
screw_d    = 3.4;    /* Clearance hole for those screws in the cover. */
tab_hole_d = 4.0;    /* Mounting holes in the tabs, for wood screws up to 3.5 mm. */

untested_fits = ["sps_fit", "pocket_fit", "part_fit", "pilot_d", "screw_d", "tab_hole_d"];
/* ASA shrinks more than PETG, and holes print undersize. Print a clearance ladder before the box, then
   clear this list. */

/* [Walls - widths in beads of fdm_extrusion_w, thicknesses in layers of fdm_layer_h] */
wall      = 1.8;    /* Side, top and bottom walls of the cover: 4 beads. */
back_t    = 2.4;    /* The back plate, printed flat: 12 layers. Carries the mounting tabs. */
front_t   = 1.8;    /* The cover's front, printed flat on the bed: 9 layers. */
cradle_t  = 1.35;   /* The walls of the channel the SPS30 slides into: 3 beads. */
divider_t = 1.35;   /* The divider between the inlet and outlet sides: 3 beads. */
rib_t     = 1.35;   /* The cover's internal ribs: 3 beads. */
rim_t     = 0.9;    /* The rims that locate the two boards: 2 beads. */

/* [Airflow] */
divider_proud = 4.0;   /* How far the divider stands below the box, so the outlet's stream cannot loop straight back to the inlets. */
front_gap_min = 2.5;   /* Least air gap in front of the SPS30's label face - one inlet wraps round onto that face. */
vent_w        = 2.0;   /* Width of each vent slot. */
vent_rib      = 1.8;   /* Material between vent slots: 4 beads. */

/* [Holding the sensor] */
lip    = 1.0;   /* How far the channel's front lips overlap the SPS30's front face. */
ledge  = 1.0;   /* How far the ledges reach under each end of the air face. Must stay clear of the openings. */

/* [Mounting and closing] */
tab_l     = 14.0;   /* How far each mounting tab reaches beyond the box. Long enough that the screwdriver's shaft clears the box's side wall: the hole sits tab_w/2 from the tab's end. */
tab_w     = 12.0;   /* Height of each tab. */
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
