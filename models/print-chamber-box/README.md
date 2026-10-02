# print-chamber box — enclosure for the printer chamber node

**Status: MODELLED, NOT YET PRINTABLE AS-IS.** The model is complete and passes every check, but three
dimensions — where the GY-SGP41's mounting hole is, and its size — are still read off a photo, and seven
fits are untested in ASA. It says so itself: `scad-check.sh` **exits 2 on purpose** until the
`unmeasured` and `untested_fits` lists are empty. Every dimension has a name, so values go in against
names rather than descriptions.

Decided 1 Oct 2026: upright with the air face down, two screw tabs, a cover held by four screws, ASA.
Settled from photos, 2 Oct 2026: the SPS30's outlet is on your RIGHT as you face the box, and the
antenna wire stands out of the board's component side. Measured the same day: the SuperMini and the
GY-SGP41. Also 2 Oct: the USB-C socket's mouth reaches the outside face, so **no cable needs measuring**
(see [The USB-C end](#the-usb-c-end)); and the wiring round — the SGP41 raised to its vents beside the
SPS30's lead, a tie post for the wires, and where every wire goes (see [Wiring](#wiring)).

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
                  FRONT, as you face it                                 SIDE SECTION, through the SGP41
          |<------------------------ W ------------------------->|     back            front
          +------------------------------------------------------+     +--+----------+--+    ^
          | o                                                  o |     |  |          |  |    |
          |                            +---------------------+   |     |  |board     |  |    |
          | antenna end - its wire    o|  C3 SuperMini       |====     |  |  + wire  |  |    |
          | stands out towards you     |  pins at this end ->|   |     |  |          |  |    |
          |                            +---------------------+   |     |  |          |  |    |
          |             +---------------+  : lead :   (post)     |     |  +--------+]|  |    |  H
          |      vents  |   GY-SGP41    |  :      :              |     |  |pedestal|]|  |    |
          |             +--- raised ----+  :      :              |     |  +--------+]|  |    |
          |   +--------------------------------------------+     |     |  +------+   |  |    |
          |   |  SPS30 on edge, label facing you,          |     |     |  |      |   |  |    |
          |   |  connector UP at the outlet end            |     |     |  |SPS30 | gap  |    |
          |   |  air face DOWN                             |     |     |  |      |   |  |    |
          |   +--------------------------------------------+     |     |  +------+   |  |    |
          | o --[  inlet window  ]#[     outlet window     ]-- o |     +--[  window   ]--+    v
          +------------------------------------------------------+
                                   #  the divider: carries the sensor, separates the two
                                      ends, and stands divider_proud below the box
          "=" on the right wall: where the USB-C cable leaves, beside the board
          ":" the column the SPS30's lead rises through; "(post)" the tie post every wire is tied to
          "]" the SGP41 on its pedestal, a few mm behind its vents in the cover's front
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
| `ant_loop_free` | **4.3** | how much of the antenna end the loop leaves free beside it — 4.3 mm one side, 5.45 the other; the smaller is used both sides |
| `gy_l`, `gy_w`, `gy_t` | **13.14 × 10.60 × 3.24** | the GY-SGP41 with its parts. The sensor is on one face and the rest of its electronics on the other |
| `gy_back` | **2.53** | the GY-SGP41 through its PCB and electronics, clamped beside the sensor: its height lying sensor-up |
| `cable_zone_h` | **10** | above the SPS30's connector face, with the lead plugged in and bent over as tightly as it comfortably goes |
| `conn_from`, `conn_to` | **2.0**, **10.5** | where the SPS30's plug and lead sit along its top face, from the outlet end. From photo 1, scaled against the sensor: the wires leave 3.0–8.6 mm from that end, and the housing reaches about 1 mm past each |
| `gy_bare` | **4.0** | the bare strip at the GY-SGP41's far end, opposite its pins: every part on its underside is on the pin half (photo 2; about 4.5 mm bare) |

**Bounds, not measurements** — the design works anywhere inside them, so none needs measuring:

| Name | Value | Why |
|---|---|---|
| `gy_pcb_min`, `gy_pcb_max` | **0.8**, **1.6** | the GY-SGP41's bare board thickness. GY modules are usually 1.0–1.6 mm |

**Sourced** — the SGP41's screw, an M2.5 × 8 socket head cap screw to ISO 4762: `gy_head_d` **4.5**,
`gy_head_h` **2.5**.

**Sourced** — from the USB Type-C compliance document, rev 1.2, so that no cable needs measuring:

| Name | Value | Note |
|---|---|---|
| `usb_shell_w` | **8.94** | the receptacle's inside opening is 8.34 × 2.56; the measured 3.16 height against 2.56 gives a 0.30 mm shell wall, so 8.34 + 2 × 0.30 |
| `usb_plug_w`, `usb_plug_h` | **12.35 × 6.5** | the largest a compliant plug's body may be (Figure B-1, dimensions 1 and 14). The body stays outside the box, so these only check that it clears the tabs and the mounting surface |

**Still to measure** — read off photo 1 for now, so the model warns until they are measured:

| Name | Photo reading | What |
|---|---|---|
| `gy_hole_d` | 2.7 | the GY-SGP41's mounting hole, across |
| `gy_hole_far` | 2.7 | from the hole's centre to the module's far end — the short edge opposite its pins |
| `gy_hole_side` | 3.4 | from the hole's centre to the nearer long edge — the one away from the sensor |

Set each in [`print-chamber-box.params.scad`](print-chamber-box.params.scad), then delete its name from the
`unmeasured` list there. The screw goes into a pilot printed at that spot, so a reading off by half a
millimetre would make the screw miss it.

## The two parts

| Part | Prints | What it carries |
|---|---|---|
| **Back plate** — [`print-chamber-box-back.scad`](print-chamber-box-back.scad) | flat | two mounting tabs; a channel the SPS30 slides down into, with lips that keep it against the plate; a ledge under each end of the air face; the divider; the board's pocket, with two stops that take the push of plugging in; a pedestal that raises the SGP41 to its vents, with a ledge for its bare strip; a tie post for the wires; four bosses for the cover screws |
| **Cover** — [`print-chamber-box-cover.scad`](print-chamber-box-cover.scad) | front face down | the window under the SPS30; the USB-C opening, in a stretch of wall thinned from inside with a chamfered step; vents in front of the SGP41 and the board; a partition that continues the divider up the air gap in front of the sensor; a baffle that closes that gap off from the warm compartment above |

Hardware: four **M3 × 14 self-tapping** screws close it, and two wood screws up to 3.5 mm hang it. **One
M2.5 × 8 socket head cap screw** holds the SGP41 down through its mounting hole. One small cable tie, or a
few turns of thread, ties the wires to the tie post. Double-sided tape holds the SuperMini on the plate;
it is also held along its length — see below.

**No bridge over air in either part.** Every opening in the cover is a hole in its first layers or a
notch open at its back edge. The slicer does report eight *bridge infill* regions in the back plate, and
each was traced: all are internal, the first solid layer over the part's own sparse infill — PrusaSlicer
uses the same label for both. Five are in the plate and the bosses; the other three (2 Oct 2026) are the
tops of the SGP41's pedestal and of its ledge, and the floor under its screw's blind pilot, each inside
the pedestal. The cover reports none.

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
  exactly the moment it must not. Each stop reaches `stop_reach` (3 mm) in from its rim, 2.7 mm over the
  PCB. The antenna loop lies in the board's plane past that end and leaves 4.3 mm and 5.45 mm of it free
  (measured 2 Oct 2026), so the stops clear it by at least 1.6 mm; an assert keeps it that way.

The recess is as tall as the board's tallest part, not just as thick as the PCB, because something besides
the socket sits 0.69 mm from the board's USB end on the component side (measured 2 Oct 2026). That
makes the thinned wall the one stretch a plug's pull-out force bears on across the layer lines, so its
step back to the full wall is a 45-degree chamfer rather than a square inside corner, where a crack would
start.

Pushed in, the mouth is flush with the outside face; pulled out, it stands 0.6 mm proud. An assert
blocks any setting that would leave it inside the wall. The plug's body then sits beside the box, 4.83 mm
from the mounting surface at its centre, so **any body up to 9.66 mm thick clears the wall the box is
screwed to**. A compliant one is at most 6.5 mm. The model echoes both figures.

**Why it was changed** (2 Oct 2026): the first version left the mouth 0.6 mm inside the wall and sized
the opening for a measured plug. Even with the right number, the back plate's edge, which the cover's
opening does not reach, would have stopped a compliant 6.5 mm plug body 0.6 mm short of seating. That was
a 6.1 mm³ overlap, found by drawing that plug into the earlier version.

## The SGP41's mount

**Its sensor faces the vents, and a pedestal brings it within 2.1–2.9 mm of them** — measured to the
sensor's face, which stands 0.71 mm proud of its board. Lying on the plate it
would sit 16 mm behind its vents and measure the box's own air, warmed by the board, more than the room's.
It stands just left of the SPS30's lead, in the zone between the sensor and the board, with its pins
towards the board's pin end, so its four wires head straight there.

**Only the bare strip at its far end rests on anything.** All the parts on its underside are on the pin
half; the far `gy_bare` (4 mm) is bare. A ledge carries that strip, so the parts never bear load, and its
pin end overhangs. The ledge is tall enough that the parts on the thinnest plausible board clear the floor
by `gap` (1 mm): the floor prints as a solid skin over infill and can come out a few tenths uneven.
Because the board touches nothing but the ledge and a rim on three sides, its thickness does not matter:
anywhere from `gy_pcb_min` to `gy_pcb_max`, the rim catches its edge and the room in front is kept. The
rim is open at the pin end, where the wires leave.

**An M2.5 × 8 screw holds it down, through its mounting hole into a blind 7.6 mm pilot in the ledge.**
The hole is in the bare strip, by the long edge away from the sensor, so the screw clamps only bare board.
Its 4.5 mm head should clear the sensor by about 0.85 mm, but that is a photo reading, and measuring the
hole does not settle it: put the screw through the hole and look before printing. Which edge of the
pocket the hole sits by also comes from photo 1, so the pilot is only as right as that reading. The screw
cuts its own thread in the pilot (`gy_pilot_d`, an untested fit). An M2 screw is not the fallback for a
smaller hole: its pilot would be under the 2 mm minimum. The room in front of the board is set by the screw's head, 2.5 mm tall plus `part_fit` to the cover —
more than the 2.5 mm `wire_room` the wires need.

The pedestal clears the cover's baffle over the sensor; the box grew 0.95 mm taller for that, to 88.9 mm.
It also stands under the board's antenna end, 6.5 mm below the loop. That was the one place it fits
between the lead and the loop, and it keeps the SGP41's wires on the far side of the antenna; an assert
keeps it at least `gap` below the loop, and the model echoes the distance.

## Wiring

**Solder at the board, from its component side, with no headers.** Pin headers and Dupont housings stand
about 22 mm off the board, and there is not that much room in front of it. The sensors keep their own
connectors, or in the SGP41's case its own pins, so either can be swapped without unsoldering the
SuperMini.

| Wire | From | To the SuperMini | Its edge, as installed |
|---|---|---|---|
| SPS30 black | pin 1, VDD | **5V** | lower edge, 1st from the USB-C end |
| SPS30 orange | pin 5, GND | **GND** | lower edge, 2nd |
| SPS30 yellow | pin 4, SEL | **GND** | lower edge, 2nd |
| SGP41 GND | GND | **GND** | lower edge, 2nd |
| SGP41 VIN | VIN | **3V3** — never 5V | lower edge, 3rd |
| SPS30 red | pin 2, SDA | **GPIO5** | upper edge, 1st |
| SGP41 SDA | SDA | **GPIO5** | upper edge, 1st |
| SPS30 white | pin 3, SCL | **GPIO6** | upper edge, 2nd |
| SGP41 SCL | SCL | **GPIO6** | upper edge, 2nd |

The colours are this lead's, found with a meter on 1 Oct 2026 —
[`firmware/print-chamber.yaml`](../../firmware/print-chamber.yaml) says how, and why colours are not to be
trusted on another lead. Three wires share the GND pad: twist the SPS30's orange and yellow together first.
Why the SGP41's VIN must be 3V3 is in the same file.

**The routes:**

- **The SPS30's lead** rises from its plug at the outlet end and bends over towards the right wall. Its
  column is kept clear: the SGP41's pedestal stands to its left, and the tie post above its bend.
  **Shorten the lead** so it reaches the board with about a centimetre to spare, rather than coiling it:
  the SPS30 has a fan, and a slack lead buzzes.
- **The SGP41's wires** are soldered from its sensor side, bent flat towards the right, and run to the tie
  post.
- **At the tie post**, below the board's pin end, tie all the wires to the post with one small cable tie
  or a few turns of thread. A tug on either sensor then stops at the post, not at the SuperMini's pads,
  which are small and lift easily. The post runs from the plate to just short of the cover's front, so a
  tie cannot slide off its end. **Pull the tie snug, not tight:** the post is a 4 mm pillar 19.5 mm tall.
- **From the post to the pins:** 5V, GND and 3V3 are on the board's lower edge, right above the post.
  GPIO5 and GPIO6 are on its upper edge, so their wires cross the board's front **over its USB-C end**.
- **Never:** across the board's antenna half, in front of the antenna wire, or anywhere in the window or
  the air gap in front of the SPS30.

**The USB-C cable has no clamp on the box — a change from the plan.** A plug's body typically runs 2–3 cm
out from the wall, and the cable only starts beyond that; the nearest part of the box, the tab, ends
14 mm out and 40 mm lower. Nothing on the box could hold the cable without forcing it into a loop. The
socket is protected anyway: the shell-sized opening takes side loads into the wall, and the thinned wall
takes a pull. **Clip the cable to the wall 3–5 cm from the plug** with a stick-on cable clip.

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
  the plate's face and the boss tops, and nowhere else. Positive controls: `part_fit = -0.6` measured
  385.1 mm³, and `gz0 = 43.5` (the SGP41's pedestal lowered into the cover's baffle) 48.0 mm³, so the
  check does see a real overlap.
- `-D 'part="check_components"'` intersects both parts with the sensor, the boards, the antenna wire
  and loop, the USB-C shell, the body of the largest compliant plug — seated with the board pushed
  against its stops — the column the SPS30's lead rises through, the SGP41 at every board thickness
  within the bounds, and its screw's head. It must be **empty**. Positive controls: `sm_pocket_h = 17` (a
  pocket narrower than the board) measured 26.8 mm³, `gx0 = 15` (the pedestal moved into the lead's
  column) 642.5 mm³, `gy_ledge_x0 = 26.6` (the ledge reaching under the SGP41's parts) 97.9 mm³, and
  `gy_floor = 17` (the SGP41 pushed towards the cover, its screw's head into the front) 12.5 mm³. Stops
  reaching into the antenna loop, a tie post on the wrong side of the lead, and a mounting hole too small
  for the screw or off the bare strip are caught earlier, by asserts.

Run both with `outlet_at_left` set each way, too (`-D outlet_at_left=true`). The model mirrors, and a
check run one way only has passed a mirrored mistake before.
