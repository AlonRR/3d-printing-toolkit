# print-chamber box — enclosure for the printer chamber node

**Status: CONCEPT, awaiting measurements.** No model yet. This page is the labelled diagram that comes
*before* modelling: every dimension the model will need has a name here, so values can be filled in
against names rather than described.

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
antenna points **up**, away from the metal.

```
                    FRONT VIEW (mounting surface behind)                SIDE SECTION
           |<------------------------ box_w ------------------------>|
           +---------------------------------------------------------+   +-----------------+   ^
           |  ||||| vent |||||                      antenna wire ^   |   |      wire ^     |   |
           |  +---------------+      +-----------------------+   |   |   |   +----------+  |   |
           |  |   GY-SGP41    |      |    C3 SuperMini       |---+   |   |   |  board   |  |   |
           |  |   gy_l x gy_w |      |    sm_l x sm_w        |== USB-C   |   +----------+  |   |
           |  +---------------+      +-----------------------+       |   |        | lead   |   |
           |=================== baffle (heat / air) =================|   |========|========|   | box_h
           |    +-----------------------------------------------+    |   |  +----------+   |   |
           |    |                                               |    |   |  |          |   |   |
           |    |  SPS30 on edge, connector UP, air face DOWN   |    |   |  |  SPS30   |   |   |
           |    |         sps_w (40.6) x sps_h (40.6)           |    |   |  |  sps_t   |   |   |
           |    |                                               |    |   |  |  (12.2)  |   |   |
           |    +-----------------------------------------------+    |   |  +----------+   |   |
           +-------[    outlet window    ]#[  inlet window  ]--------+   +--[ window ]-----+   v
                                           #  <- divider rib, sealed to the sensor face,
                                              standing proud of the box so exhaust cannot loop back
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
| `divider_from_inlet_end` | along the air face: from the inlet end to the middle of the gap between the inlets and the outlet grille. Read off the drawing it is roughly **19 mm**, but that is a scaled reading, not a dimension |
| `gy_l`, `gy_w`, `gy_t` | the GY-SGP41 board, and its mounting holes if it has any |
| `sm_l`, `sm_w`, `sm_t` | the SuperMini — about 22 × 18 mm. Thickness depends on whether pin headers are soldered |
| `usb_plug_w`, `usb_plug_h` | the **plug body** of the USB-C cable that will power it — the opening has to pass the overmould, not just the receptacle |
| `wire_h` | how far the antenna wire actually stands above the board |

**To decide** — see below.

## Open decisions

- **Mounting** — where the box hangs and how.
- **Lid** — screws or snaps.
- **Material** — PETG is enough outside the enclosure; ASA if it ends up anywhere hot.
- **Print orientation** — the air-face window must not end up as a long unsupported bridge. A 41 mm
  span is four times this printer's ~10 mm bridging ceiling ([fdm-design-rules §3](../../docs/fdm-design-rules.md)).
  Printing the box air-face-down, with the window simply a hole in the first layers, avoids it with
  permanent geometry.
