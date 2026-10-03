# Parameters

Every dimension has a name in [`print-chamber-box.params.scad`](../print-chamber-box.params.scad), so a
value goes in against its name rather than a description. This page says where each came from.

If a part changes, set the new value there. A value not yet measured goes in the `unmeasured` list,
and the model warns until it is. The list is empty now.

## Sourced

From the **SPS30 datasheet v2.0**, Figure 7:

| Name | Value | Note |
|---|---|---|
| `sps_h` | **40.6 ± 0.3** | without the shipping foil, which can stay on. The datasheet gives the same for `sps_w`, and 41.2 across the side nubs; both were measured instead, below |
| `sps_t` | **12.2 ± 0.3** | |
| `sps_inlet_end` | **15.2** | where the inlets end, from the inlet end — the one that wraps onto the label face reaches furthest. A photo reads 14.9 |

From the **USB Type-C specification**, rev 1.2, so that no cable needs measuring:

| Name | Value | Note |
|---|---|---|
| `usb_shell_w` | **8.94** | the receptacle's inside opening is 8.34 × 2.56; the measured 3.16 height against 2.56 gives a 0.30 mm shell wall, so 8.34 + 2 × 0.30 |
| `usb_plug_w`, `usb_plug_h` | **12.35 × 6.5** | the largest a compliant plug's body may be (Figure B-1, dimensions 1 and 14). The body stays outside the box, so these only check that it clears the mounting surface |

From **ISO 4762**, the largest socket heads allowed: the SGP41's M2.5 × 6, `gy_head_d` **4.5** and
`gy_head_h` **2.5**; and the cover's M3 × 20, `cover_head_d` **5.5** and `cover_head_h` **3.0**, which
size the counterbores its heads sit flush in.

From **ISO 4032**, the M3 nut: `nut_af` **5.5** across its flats and `nut_h` **2.4** tall, the largest
allowed. The hex pockets are sized from them, and the cover's screw is long enough to pass right through.

## The wall screws

The two 4 × 20 chipboard screws the box hangs on, measured 3 Oct 2026. They size the keyholes: the entry
is the head plus 1 mm (9.2 mm as cut), the slot the thread plus 0.6 mm (4.9 mm as cut), and an assert
keeps at least 1 mm of plate under the head on each side. The first clearance test's G row agrees on the
thread: of 3.8, 4.0 and 4.2 mm holes, the screw fits the 4.2.

| Name | Value | What |
|---|---|---|
| `key_shank_d` | **4.0** | the thread, across |
| `key_head_d` | **7.9** | the head, across |
| `key_head_h` | **2.68** | the head, tall. A chipboard screw's head is usually countersunk; the room behind the plate is drawn as a cylinder the head's full size, which holds for either shape |

## Measured

With calipers on the parts in hand, 2 Oct 2026 unless dated. Three were read off photos first and
measured on 3 Oct 2026 — A, B and C here:

![the three readings taken on the boards](board-measure.png)

Drawn by [`board-measure.scad`](../board-measure.scad), the boards as they lie on the table.

| Name | Value | What |
|---|---|---|
| `sps_w` | **40.69** | across the SPS30's body, beside its side nubs — measured 3 Oct 2026, reading B in [the figure](sps30-measure.png) |
| `sps_nub` | **0.155** | each side: 41.00 across the nubs (reading A), less the body, halved. The datasheet's 41.2 left the first clearance test's frame A about 0.7 mm loose |
| `divider_from_inlet_end` | **17.7** | from the SPS30's inlet end to the middle of the blank gap before the outlet grille. Scaled off a straight-on photo against the sensor's 40.6 mm width; three features land within 0.4 mm of the datasheet, so the scale holds. The gap runs from `sps_inlet_end` 15.2 to `sps_outlet_from` 20.2, and an assert keeps the divider inside it |
| `sm_l`, `sm_w` | **22.8 × 18.03** | the SuperMini's PCB, not counting the USB-C shell |
| `sm_pcb_t`, `sm_t` | **0.85**, **4.05** | the bare PCB; the PCB with its tallest part, the USB-C shell, without the antenna |
| `usb_shell_h`, `usb_overhang` | **3.16**, **1.5** | the USB-C shell's height, and how far it overhangs the PCB's edge |
| `ant_h`, `ant_over` | **18.8**, **4.81** | the antenna wire's tip above the PCB's underside; how far its loop reaches past the PCB's antenna end, in the board's plane |
| `ant_loop_free` | **4.3** | how much of the antenna end the loop leaves free beside it — 4.3 mm one side, 5.45 the other; the smaller is used both sides |
| `sm_edge` | **2.3** | the strip along each long edge of the SuperMini's component side that carries only its castellated pads: from the board's edge to the nearest part. Reading A, on the 5V edge past the 4th pin; the photo had read 1.0. The back edge was not measured — only the clips reach over it, and they keep within `clip_room`. The cover's front lip reaches 0.9 mm over it |
| `pin_mid` | **1.6 + 2.54** | the middle of the SuperMini's three power pins, from its PCB's USB-C end — the board, not the shell that overhangs it. Reading B puts the 5V pin's middle 1.6 mm from that end; the photo had read 2.6, because the shell hides the board's end. The clips and the front clasp are placed from it |
| `cable_zone_h` | **10** | above the SPS30's connector face, with the lead plugged in and bent over as tightly as it comfortably goes |
| `conn_from`, `conn_to` | **2.0**, **10.5** | where the SPS30's plug and lead sit along its top face, from the outlet end: the wires leave 3.0–8.6 mm from that end, and the housing reaches about 1 mm past each |
| `gy_l`, `gy_w`, `gy_t` | **13.14 × 10.60 × 3.24** | the GY-SGP41 with its parts. The sensor is on one face and the rest of its electronics on the other |
| `gy_back` | **2.53** | the GY-SGP41 through its PCB and electronics, clamped beside the sensor: its height lying sensor-up |
| `gy_bare` | **3.31** | from the GY-SGP41's far end (opposite its pins) to the nearest part on its underside |
| `gy_hole_bare_d` | **3.13 + 2 × 1.0** | the bare patch round the mounting hole on the underside: reading C, 1.0 mm from the hole's edge to the nearest part, as the photo had read. The 4 mm standoff bears inside it, and the collision check treats its edge as where the parts begin |
| `gy_hole_d` | **3.13** | the GY-SGP41's mounting hole, across |
| `gy_hole_far`, `gy_hole_side` | **1.32**, **1.25** + half the hole | from the hole's edge to the module's far end, and to the nearer long edge (the one away from the sensor). The file adds half the diameter to put the centre at 2.885 and 2.815 |
| `gy_hole_right` | **true** | which way round the module is: seen from its sensor side with its pins up, the hole is at the bottom right and the sensor at the bottom left — the GY-SGP41 in [the figure](board-measure.png). Read off photo 2, then confirmed on both modules in hand, 3 Oct 2026. Standing on edge with its sensor towards the side wall and its pins up, the module's hole is therefore by its front edge, away from the plate |

## Settled from photos

Which way round the parts go, read off photos and checked against the parts:

| Name | Value | What |
|---|---|---|
| `outlet_at_left` | **false** | facing the box, label towards you, air face down, the SPS30's outlet grille is on your right and its two inlets on your left. The connector is at the outlet end |
| `sps_outlet_from` | **20.2** | where the outlet grille starts, from the inlet end. The divider sits between this and `sps_inlet_end` |
| `wire_perpendicular` | **true** | the antenna's straight part, the pole, stands out of the SuperMini's component side, so with the board level it stands up |

## Bounds, not measurements

The design works anywhere inside these, so none needs measuring:

| Name | Value | Why |
|---|---|---|
| `gy_pcb_min`, `gy_pcb_max` | **0.8**, **1.6** | the GY-SGP41's bare board thickness. GY modules are usually 1.0–1.6 mm |

## Fits

Clearances that depend on the printer and the filament, found with [the clearance test](clearance-test.md):

| Name | Value | Status |
|---|---|---|
| `sps_fit` | **0.2** | tested 2 Oct 2026, snug — clearance per side round the SPS30. Flush across its thickness, about 0.7 mm loose along its width, until the width was measured (`sps_w`, `sps_nub` above) |
| `pocket_fit` | **0.2** | tested 2 Oct 2026, snug — clearance per side round both boards |
| `part_fit` | **0.3** | tested 3 Oct 2026, 0.26–0.29 per side as printed — between a back-plate feature and the cover |
| `gy_pilot_d` | **2.1** | **untested sideways** — pilot for the SGP41's M2.5 screw. Tested upright 3 Oct 2026, fine; the module now stands on edge, so the clearance test's K tries it again |
| `nut_fit` | **0** | **untested** — the M3 nuts' hex pockets, per side on top of the hole compensation: meant as a press fit. The clearance test's J |
| `clasp_pinch` | **0.1** | **untested** — how much the SuperMini's back clips pinch its PCB at their catch. The clearance test's L |
| `screw_d` | **3.2** | tested 3 Oct 2026, passes an M3 freely — clearance hole for the M3 screws in the cover |

The three untested ones are in `untested_fits`, and `scad-check.sh` exits 2 until they are cleared.
Two the first round tested have gone from the box: `pilot_d` with the self-tapping cover screws, and
`tab_hole_d` with the mounting tabs.

## Chosen

Not measured and not tested: sizes the design picks. Widths are whole beads of `fdm_extrusion_w` and
thicknesses whole layers of `fdm_layer_h`, and the model asserts both.

| Name | Value | What |
|---|---|---|
| `wall`, `back_t`, `front_t` | **1.8**, **2.4**, **1.8** | the cover's side, top and bottom walls (4 beads); the back plate (12 layers), which the wall screws' heads bear on; the cover's front (9 layers) |
| `cradle_t`, `divider_t`, `rib_t` | **1.35** | the SPS30 channel's walls, the divider, and the cover's ribs and the clips' lower jaws: 3 beads |
| `rim_t`, `port_wall` | **0.9** | rims, jaws and stops: 2 beads. `port_wall` is the cover's wall thinned over the board's USB-C end, as thick as the shell's 1.5 mm overhang allows |
| `ledge` | **1.0** | how far the ledges reach under each end of the SPS30's air face, clear of its openings |
| `divider_proud` | **4.0** | how far the divider stands below the box, so the outlet's stream cannot loop straight back to the inlets |
| `front_gap_min` | **2.5** | the least air gap in front of the SPS30's label face — one inlet wraps round onto it |
| `vent_w`, `vent_rib` | **2.0**, **1.8** | each vent slot, and the material between two |
| `sm_lip_over` | **0.9** | how far the front clasp's lip reaches over the board's front pad strip; an assert keeps it under `sm_edge` |
| `clip_room` | **2.1** | how far from the plate the back clips may reach over the board's pad row. Alon's figure, not measured; the parts envelope keeps out of it only where the clips are |
| `clasp_len`, `clasp_low` | **5.0**, **3.0** | each back clip's length along the edge, and how far its lower jaw reaches under the board |
| `stop_reach` | **3.0** | how far each stop at the antenna end reaches in from a long edge; the loop leaves 4.3 free |
| `gy_standoff_d`, `gy_screw_l` | **4.0**, **6.0** | the SGP41's standoff, inside the bare patch round its hole; its M2.5 screw's length — an 8 would reach the SPS30's channel |
| `key_slack`, `key_level_tol` | **1.0**, **2.0** | how much further than the plate's thickness a wall screw's head may stand off the wall; how much lower one screw may sit than the other |
| `bump_w`, `bump_out`, `u_drop` | **8.0**, **4.0**, **5.0** | the bump the cover's top locates on: its width, how far it stands out from the plate, and how far the U's arms hang down round it |
| `cover_screw_l` | **20** | the cover's M3 socket head cap screws. The nut's shoulder sits where, from its flush head, the screw passes right through the nut |
| `corner_r`, `gap` | **4.0**, **1.0** | the plan-view corner radius, which keeps ASA's corners down without a brim; the general clearance between internal features |
| `fdm_layer_h`, `fdm_extrusion_w`, `fdm_hole_comp` | **0.2**, **0.45**, **0.15** | the print profile's layer and bead, which `scad-check.sh` cross-checks; and what is added to every hole's radius, which it does not |

## Not in the params file

The SGP41's wires are the lab's **22 AWG solid hookup wire, UL1007, 1.56 mm** over its insulation,
measured 2 Oct 2026. Where they run is in [Wiring](wiring.md).
