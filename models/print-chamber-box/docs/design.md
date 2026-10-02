# Design — why the box looks like this

Most of the layout is decided by the SPS30, and Sensirion publishes the rules. Two more come from
this repository. This page lists them, then shows the layout they add up to.

## The rules

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

From this repository:

- **The box sits outside the printer's enclosure.** The SGP41 is rated −10 to +50 °C and the SPS30 to
  +60 °C, against a chamber wanted at 40–60 °C ([chamber-sensor §3](../../../docs/chamber-sensor.md)).
- **The SuperMini carries a 31 mm antenna-wire mod**, whose last 15 mm stand straight up from the
  board ([chamber-sensor §3x](../../../docs/chamber-sensor.md)). It needs free space in plastic, away
  from the SPS30's grounded metal case.

## The layout

Every rule points the same way. Stand the SPS30 on edge with its air face **down**. That puts its
connector **up**, facing the board. The board goes **above** the sensor, so its heat rises away from
it, and the board's antenna end sits in the top compartment, as far from the sensor's metal case as
the box allows. The SGP41 sits between them, on a pedestal that brings it close behind its own vents.

Drawn from the model, as you face the box:

```
                  FRONT, as you face it                                 SIDE SECTION, through the SGP41
          |<------------------------ W ------------------------->|     back            front
          +------------------------------------------------------+     +--+----------+--+    ^
          | o                                                  o |     |  |          |  |    |
          |                            +---------------------+   |     |  |board     |  |    |
          | antenna end - its wire    o|  C3 SuperMini       |====     |  |  + wire  |  |    |
          | stands out towards you     |  pins at this end ->|   |     |  |          |  |    |
          |                            +---------------------+   |     |  |          |  |    |
          |             +---------------+  : lead :  (channel)   |     |  |   +----+]|  |    |  H
          |      vents  |   GY-SGP41    |  :      :              |     |  |   |ped.|]|  |    |
          |             +--- raised ----+  :      :              |     |  |   +----+]|  |    |
          |   +--------------------------------------------+     |     |  +------+   |  |    |
          |   |  SPS30 on edge, label facing you,          |     |     |  |      |   |  |    |
          |   |  connector UP at the outlet end            |     |     |  |SPS30 | gap  |    |
          |   |  air face DOWN                             |     |     |  |      |   |  |    |
          |   +--------------------------------------------+     |     |  +------+   |  |    |
          | o --[  inlet window  ]#[     outlet window     ]-- o |     +--[  window   ]--+    v
          +------------------------------------------------------+
                                   #  the divider: carries the sensor, separates the two
                                      ends, and stands 4 mm below the box
          "=" on the right wall: where the USB-C cable leaves, beside the board
          ":" the column the SPS30's lead rises through; "(channel)" the cable channel for its wires
          "]" the SGP41 on its pedestal, 2-3 mm behind its vents in the cover's front
```

**One large window, one divider.** The window is a single opening over the whole air face, split by a
single divider. The box does not have to line up with each grille; it only has to put the divider in
the blank gap between the two ends, which is one number to measure.

**Every pin the node uses is at the board's USB-C end** — 5V, GND, 3V3, GPIO5 and GPIO6. That end faces
the SPS30's connector, so the wires are short and none comes near the antenna end.

## Left and right

**"Left" and "right" always mean as you face the box.** The model's frame is right-handed with Y
pointing out of the wall, so +X is your **left**. The layout above is for the SPS30 in hand, whose outlet
is on your right (`outlet_at_left = false`), so the USB-C cable leaves on your right too. The model can
mirror for a sensor the other way round; the wiring drawing cannot, and says so.

## Printing without support

**No bridge over air in either part.** Every opening in the cover is a hole in its first layers or a
notch open at its back edge. The slicer reports seven *bridge infill* regions in the back plate, and
each is internal: the first solid layer over the part's own sparse infill, which PrusaSlicer labels the
same way. Five are in the plate and the bosses, one is the top of the SGP41's pedestal and one the
floor under its screw's blind pilot. The cable channel's 45° lips print with no overhang perimeters.

**No skirt, no brim, no draft shield.** Rounded corners in plan view (`corner_r`) keep ASA's corners
down instead.
