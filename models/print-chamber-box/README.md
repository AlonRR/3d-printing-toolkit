# print-chamber box — enclosure for the printer chamber node

**Status: MODELLED, NOT YET PRINTABLE AS-IS.** The model is complete and passes every check, but 15
of its dimensions are placeholders until the parts are measured, and six fits are untested in ASA. It
says so itself: `scad-check.sh` **exits 2 on purpose** until both lists are empty. Every dimension has
a name, so values go in against names rather than descriptions.

Decided 1 Oct 2026: upright with the air face down, two screw tabs, a cover held by four screws, ASA.

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

Drawn from the model, as you face the box (`outlet_at_left = true`):

```
                  FRONT, as you face it                                 SIDE SECTION
          |<------------------------ W ------------------------->|     back            front
          +------------------------------------------------------+     +--+----------+--+    ^
          | o                                                  o |     |  |          |  |    |
          |  +---------------------+                             |     |  |board ---->|  |    |
 USB-C <==|  |  C3 SuperMini       |o  <- antenna end; its wire  |     |  |   wire   |  |    |
          |  |  sm_l x sm_w        |      stands out towards you |     |  |          |  |    |
          |  +---------------------+                             |     |  |  lead    |  |    |
          |    |                         +---------------+       |     |  |  SGP41   |  |    |  H
          |    | lead (outlet end)       |   GY-SGP41    | vents |     |  |          |  |    |
          |    |                         +---------------+       |     |  +------+   |  |    |
          |   +----------------------------------------------+   |     |  |      |   |  |    |
          |   |  SPS30 on edge, label facing you,            |   |     |  |SPS30 | gap  |    |
          |   |  connector UP at the outlet end, air face DOWN   |     |  |      |   |  |    |
          |   +----------------------------------------------+   |     |  +------+   |  |    |
          | o ---[      outlet window      ]#[ inlet window ]--o |     +--[  window   ]--+    v
          +------------------------------------------------------+
                                            #  the divider: carries the sensor, separates the two
                                               ends, and stands divider_proud below the box
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

**To measure** — with calipers, on the parts actually in hand:

| Name | What |
|---|---|
| `divider_from_inlet_end` | along the air face: from the inlet end to the middle of the gap between the inlets and the outlet grille. Read off the drawing it is roughly **18 mm** (the gap spans about 15–21 mm), but that is a scaled reading, not a dimension |
| `outlet_at_left` | facing the box, with the label towards you and the air face down: is the outlet grille on your **left**? The connector is at the same end as the outlet |
| `gy_l`, `gy_w`, `gy_t` | the GY-SGP41 board, and its mounting holes if it has any |
| `sm_l`, `sm_w`, `sm_t` | the SuperMini — about 22 × 18 mm. Thickness depends on whether pin headers are soldered |
| `usb_plug_w`, `usb_plug_h` | the **plug body** of the USB-C cable that will power it — the opening has to pass the overmould, not just the receptacle |
| `wire_h`, `wire_perpendicular` | how far the antenna wire reaches, and whether it stands out of the board or runs along past its end |
| `cable_zone_h` | room above the SPS30's connector face, with the plug fitted and the lead bent over |

Set each in [`print-chamber-box.params.scad`](print-chamber-box.params.scad), then delete its name from
the `unmeasured` list there.

## The two parts

| Part | Prints | What it carries |
|---|---|---|
| **Back plate** — [`print-chamber-box.scad`](print-chamber-box.scad) | flat | two mounting tabs; a channel the SPS30 slides down into, with lips that keep it against the plate; a ledge under each end of the air face; the divider; pockets that locate the board and the SGP41; four bosses for the cover screws |
| **Cover** — [`print-chamber-box-cover.scad`](print-chamber-box-cover.scad) | front face down | the window under the SPS30; the USB-C opening; vents in front of the SGP41 and the board; a partition that continues the divider up the air gap in front of the sensor; a baffle that closes that gap off from the warm compartment above |

Hardware: four **M3 × 14 self-tapping** screws close it, and two wood screws up to 3.5 mm hang it.
**The boards are only located, not held** — tape them for now; retention waits for the measurements.

**No bridge over air in either part.** Every opening in the cover is a hole in its first layers or a
notch open at its back edge. The slicer does report five *bridge infill* regions in the back plate, and
each was traced: all are internal, the first solid layer over the plate's own sparse infill — PrusaSlicer
uses the same label for both. The cover reports none.

**"Left" and "right" mean as you face the box.** The model's frame is right-handed with Y out of the wall,
so +X points to your left; the USB-C cable leaves on your left.

## Checking it

```sh
scripts/scad-check.sh models/print-chamber-box/print-chamber-box.scad     "0.2mm QUALITY @MK3 - ASA brim + draft shield" "Inslogic ASA"
scripts/scad-check.sh models/print-chamber-box/print-chamber-box-cover.scad     "0.2mm QUALITY @MK3 - ASA brim + draft shield" "Inslogic ASA"
```

Both should report one manifold part and `fdm_*` matching the profile. **Exit 2 is expected** while the
`unmeasured` and `untested_fits` lists are not empty; exit 0 means both are clear.

Two more checks, which `scad-check.sh` does not run:

- `-D 'part="check_parts"'` intersects the two parts. The result must have **zero volume** — they meet at
  the plate's face and the boss tops, and nowhere else. A positive control with `part_fit = -0.6`
  measured 301.8 mm³, so the check does see a real overlap.
- `-D 'part="check_components"'` intersects both parts with the sensor, the boards and the antenna
  wire. It must be **empty**.
