# print-chamber box — enclosure for the printer chamber node

**Status: MODELLED, NOT YET PRINTABLE AS-IS.** The model is complete and passes every check, but one
dimension is still a placeholder (`cable_zone_h`) and six fits are untested in ASA. It says so itself:
`scad-check.sh` **exits 2 on purpose** until both lists are empty. Every dimension has a name, so values
go in against names rather than descriptions.

Decided 1 Oct 2026: upright with the air face down, two screw tabs, a cover held by four screws, ASA.
Settled from photos, 2 Oct 2026: the SPS30's outlet is on your RIGHT as you face the box, and the
antenna wire stands out of the board's component side. Measured the same day: the SuperMini and the
GY-SGP41. Also 2 Oct: the USB-C socket's mouth reaches the outside face, so **no cable needs measuring**
(see [The USB-C end](#the-usb-c-end)).

It houses the node in [`firmware/print-chamber.yaml`](../../firmware/print-chamber.yaml): an ESP32-C3
SuperMini, a Sensirion SPS30 particle sensor and a GY-SGP41 VOC/NOx module.

## The rules that shape it — and where each comes from

Most of the layout is decided by the SPS30, and Sensirion publishes the rules.

| Rule | Source |
|---|---|
| **Two inlets and one outlet, all on one 40.6 × 12.2 mm face.** The large slotted grille is the **outlet**; the two inlets sit at the other end, one of them wrapping round the edge | *Mechanical Design and Assembly Guidelines for SPS30*, §1 figure |
| **Couple that face to the room through a large opening, with minimal depth in front of it.** A constricted volume in front makes outlet air flow back into the inlets | guidelines §2.1 |
| **A tight seal between the inlet side and the outlet side** gives the best performance | guidelines §2.1 |
| **Openings facing down** is the best orientation — it avoids dust settling in the sensor | guidelines §2.2 |
| **Keep it away from heat sources such as microcontrollers, and below them** — convection from a warm board heats the sensor | guidelines §2.4 |
| **Do not cover the entire sensor surface** in an all-round casing, or it overheats | guidelines §3 |
| **Isolate it from airflow faster than 1 m/s** — so not in the fume fan's stream | guidelines §2.3 |
| **The metal housing is tied to GND and must stay electrically floating**; current through that link *"may damage the product and poses a safety risk through overheating"* | datasheet v2.0 §3 |
| **Connector on the face opposite the openings** | datasheet v2.0 §3 |
| **I2C lead under 20 cm** | datasheet v2.0 §3 |

And two from this repository:

- **The SGP41 is rated -10 to +50 °C** and the SPS30 to +60 °C, against a chamber wanted at 40–60 °C.
  So the box sits **outside** the enclosure ([chamber-sensor §3](../../docs/chamber-sensor.md)).
- **The SuperMini carries the 31 mm antenna-wire mod**, whose last **15 mm stand straight up** from the
  board ([chamber-sensor §3x](../../docs/chamber-sensor.md)). It needs free space in plastic, and should
  not run alongside the SPS30's grounded metal case.

## The layout those rules produce

Every rule above points the same way. Stand the SPS30 on edge with its air face **down**; that puts its
connector **up**, facing the board; the board goes **above** the sensor, so its heat rises away; and the
board's antenna end sits in the top compartment, as far from the sensor's metal case as the box allows.

Drawn from the model, as you face the box, for the sensor in hand (`outlet_at_left = false`):

```
                  FRONT, as you face it                                 SIDE SECTION
          |<------------------------ W ------------------------->|     back            front
          +------------------------------------------------------+     +--+----------+--+    ^
          | o                                                  o |     |  |          |  |    |
          |                            +---------------------+   |     |  |board --->|  |    |
          | antenna end - its wire    o|  C3 SuperMini       |====     |  |   wire   |  |    |
          | stands out towards you     |  sm_l x sm_w        |   |     |  |          |  |    |
          |                            +---------------------+   |     |  |  lead    |  |    |
          |                                               |      |     |  |          |  |    |
          |        +---------------+                      |      |     |  |  SGP41   |  |    |  H
          | vents  |   GY-SGP41    |    lead, outlet end  |      |     |  |          |  |    |
          |        +---------------+                      |      |     |  +------+   |  |    |
          |   +--------------------------------------------+     |     |  |      |   |  |    |
          |   |  SPS30 on edge, label facing you,          |     |     |  |SPS30 | gap  |    |
          |   |  connector UP at the outlet end,           |     |     |  |      |   |  |    |
          |   |  air face DOWN                             |     |     |  |      |   |  |    |
          |   +--------------------------------------------+     |     |  +------+   |  |    |
          | o --[  inlet window  ]#[     outlet window     ]-- o |     +--[  window   ]--+    v
          +------------------------------------------------------+
                                   #  the divider: carries the sensor, separates the two
                                      ends, and stands divider_proud below the box
          "=" on the right wall: where the USB-C cable leaves, beside the board
```

The window is one large opening over the whole air face, split by a single divider. That way the box
does not have to hit each grille exactly — it only has to put the divider in the gap between the two
ends, which is one number to measure.

## Parameters

**Sourced** — from the SPS30 datasheet v2.0, Figure 7:

| Name | Value | Note |
|---|---|---|
| `sps_w`, `sps_h` | **40.6 ± 0.3** | without the shipping foil, which can stay on |
| `sps_w_nubs` | **41.2** | including the small plastic nubs on the sides |
| `sps_t` | **12.2 ± 0.3** | |
| `sps_mass` | **26.3 g** | |

**Measured** — 2 Oct 2026, with calipers on the parts in hand, and one value from a photo:

| Name | Value | What |
|---|---|---|
| `divider_from_inlet_end` | **17.7** | from the inlet end to the middle of the blank gap before the outlet grille. Scaled off a straight-on photo against the sensor's 40.6 mm width; three features land within 0.4 mm of the datasheet, so the scale holds. The gap runs from `sps_inlet_end` 15.2 to `sps_outlet_from` 20.2, and an assert keeps the divider inside it |
| `sm_l`, `sm_w` | **22.8 × 18.03** | the SuperMini's PCB, not counting the USB-C shell |
| `sm_pcb_t`, `sm_t` | **0.85**, **4.05** | the bare PCB; the PCB with its tallest part, the USB-C shell, without the antenna |
| `usb_shell_h`, `usb_overhang` | **3.16**, **1.5** | the USB-C shell's height, and how far it overhangs the PCB's edge |
| `ant_h`, `ant_over` | **18.8**, **4.81** | the antenna wire's tip above the PCB's underside; how far its loop reaches past the PCB's antenna end, in the board's plane |
| `gy_l`, `gy_w`, `gy_t` | **13.14 × 10.60 × 3.24** | the GY-SGP41 with its parts. The sensor is on one face and the rest of its electronics on the other |

**Sourced** — from the USB Type-C compliance document, rev 1.2, so that no cable needs measuring:

| Name | Value | Note |
|---|---|---|
| `usb_shell_w` | **8.94** | the receptacle's inside opening is 8.34 × 2.56; the measured 3.16 height against 2.56 gives a 0.30 mm shell wall, so 8.34 + 2 × 0.30 |
| `usb_plug_w`, `usb_plug_h` | **12.35 × 6.5** | the largest a compliant plug's body may be (Figure B-1, dimensions 1 and 14). Used only to check the tabs and the mounting surface, which the plug body is outside the box beside |

**Still to measure:**

| Name | What |
|---|---|
| `cable_zone_h` | hold the SPS30 as it sits in the box — air openings down, connector on top — plug its lead in, and bend the wires over to the side as tightly as they comfortably go. Measure from the sensor's top to the highest point of the bent wires |

Set it in [`print-chamber-box.params.scad`](print-chamber-box.params.scad), then delete its name from
the `unmeasured` list there.

## The two parts

| Part | Prints | What it carries |
|---|---|---|
| **Back plate** — [`print-chamber-box-back.scad`](print-chamber-box-back.scad) | flat | two mounting tabs; a channel the SPS30 slides down into, with lips that keep it against the plate; a ledge under each end of the air face; the divider; pockets that locate the board and the SGP41, the board's with two stops that take the push of plugging in; four bosses for the cover screws |
| **Cover** — [`print-chamber-box-cover.scad`](print-chamber-box-cover.scad) | front face down | the window under the SPS30; the USB-C opening, in a stretch of wall thinned from inside; vents in front of the SGP41 and the board; a partition that continues the divider up the air gap in front of the sensor; a baffle that closes that gap off from the warm compartment above |

Hardware: four **M3 × 14 self-tapping** screws close it, and two wood screws up to 3.5 mm hang it.
**The SuperMini is held along its length** — see below — but **nothing holds either board down onto the
plate yet**. Tape them for now.

**No bridge over air in either part.** Every opening in the cover is a hole in its first layers or a
notch open at its back edge. The slicer does report five *bridge infill* regions in the back plate, and
each was traced: all are internal, the first solid layer over the plate's own sparse infill — PrusaSlicer
uses the same label for both. The cover reports none.

**"Left" and "right" mean as you face the box.** The model's frame is right-handed with Y out of the wall,
so +X points to your left. The board's USB-C end faces the SPS30's connector, so with this sensor the
cable leaves on your right. Every pin the node uses (5V, GND, 3V3, GPIO5, GPIO6) is at that end of the
board, which leaves the antenna end with no wire near it.

## The USB-C end

**The socket's mouth reaches the box's outside face, so a plug's body never enters the box** — any
cable fits, and none needs measuring. A 1.8 mm wall would leave the mouth 0.6 mm inside it, because the
shell overhangs the PCB by only 1.5 mm. So over the board's end the wall is thinned from inside to
`port_wall` (0.9 mm, two beads), and the PCB's end reaches into that recess. The opening through what is
left is the size of the shell, not of a plug.

The board can move `part_fit` either way along its length, and both ends of that travel are stops:

- **Pulling a plug out** draws the board outwards until the PCB's corners, either side of the shell, bear
  on the thinned wall.
- **Pushing a plug in** drives the board inwards, against **two stops over the corners of its antenna
  end**. Without them it would slide away from the plug, and the mouth would retreat into the wall at
  exactly the moment it must not. Each stop reaches `stop_reach` (3 mm) in from its rim; the middle
  12.6 mm of that end stays open for the antenna loop, which lies in the board's plane past the PCB.
  ⚠️ **That the loop fits in those 12.6 mm is assumed, not yet confirmed** — the model draws it 8 mm
  wide.

Pushed in, the mouth is flush with the outside face; pulled out, it stands 0.6 mm proud. An assert
blocks any setting that would leave it inside the wall. The plug's body then sits beside the box, 4.83 mm
from the mounting surface at its centre, so **any body up to 9.66 mm thick clears the wall the box is
screwed to**. A compliant one is at most 6.5 mm. The model echoes both figures.

**Why it was changed** (2 Oct 2026): the first version left the mouth 0.6 mm inside the wall and sized
the opening for a measured plug. Even with the right number, the back plate's edge, which the cover's
opening does not reach, would have stopped a compliant 6.5 mm plug body 0.6 mm short of seating. That was
a 6.1 mm³ overlap, found by drawing that plug into the earlier version.

## Checking it

```sh
scripts/scad-check.sh models/print-chamber-box/print-chamber-box-back.scad \
    "0.2mm QUALITY @MK3 - ASA brim + draft shield" "Inslogic ASA"
scripts/scad-check.sh models/print-chamber-box/print-chamber-box-cover.scad \
    "0.2mm QUALITY @MK3 - ASA brim + draft shield" "Inslogic ASA"
```

Check through these two wrappers, never through `print-chamber-box.scad` itself. `part` in the params
file is also the line you change to view a part, and `scad-check.sh` takes no `-D` - so checked through
the model, the "back plate" check silently checks whatever part is on screen. That happened on
2 Oct 2026: it reported a part 62.8 mm wide, which is the cover.

Both should report one manifold part and `fdm_*` matching the profile - the back plate 90.8 mm wide
with its tabs, the cover 62.8 mm. **Exit 2 is expected** while the
`unmeasured` and `untested_fits` lists are not empty; exit 0 means both are clear.

Two more checks, which `scad-check.sh` does not run:

- `-D 'part="check_parts"'` intersects the two parts. The result must have **zero volume** — they meet at
  the plate's face and the boss tops, and nowhere else. A positive control with `part_fit = -0.6`
  measured 301.8 mm³, so the check does see a real overlap.
- `-D 'part="check_components"'` intersects both parts with the sensor, the boards, the antenna wire
  and loop, the USB-C shell, and the body of the largest compliant plug, seated with the board pushed
  against its stops. It must be **empty**. A positive control with `stop_reach = 8` measured 1.8 mm³
  (the stops reaching into the loop), so the check does see a real collision.

Run both with `outlet_at_left` set each way, too (`-D outlet_at_left=true`). The model mirrors, and a
check run one way only has passed a mirrored mistake before.
