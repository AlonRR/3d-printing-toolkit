# The SGP41's mount

The GY-SGP41 is a small module: a 13.1 × 10.6 mm board with the gas sensor on its front, at the far end,
its other parts on its back, and four pins at the near end. Its mount has three jobs: put the sensor
close behind its vents, carry the board without loading its parts, and leave the wires a way out.

## Where it sits

**Its sensor faces its vents in the cover, 2.1–2.9 mm behind them** (to the sensor's face, which stands
0.71 mm proud of its board; the range is the board's possible thickness). Lying on the plate it would sit
16 mm back and measure the box's own air, warmed by the board, more than the room's.

It stands just left of the SPS30's lead, between the sensor and the SuperMini, with its pins towards
the SuperMini's pin end so its wires head straight there. Its pedestal stands under the SuperMini's
antenna end, 6.4 mm below the antenna loop — the one place it fits between the lead and the loop —
and an assert keeps it at least `gap` below the loop. The space between the SPS30 and the SuperMini is
sized to fit the pedestal above the cover's baffle over the SPS30, and that is what sets the box's
height.

## How it is held

**It rests on two bare patches of its underside, so its parts never bear load:**

- **a ledge** along its far end. The nearest part is 3.31 mm in from that end (`gy_bare`, measured), and
  the ledge stops 0.5 mm short of it;
- **a 4 mm standoff** round the mounting hole, inside the bare patch there (`gy_hole_bare_d`, read off a
  photo; the collision check treats its edge as where the parts begin).

The ledge is tall enough that the parts on the thinnest plausible board clear the pedestal's top by
`gap` (1 mm), since that top prints as a skin over infill and can come out a few tenths uneven. The board
touches nothing but the ledge, the standoff and a rim on three sides, so its thickness does not matter:
anywhere from `gy_pcb_min` to `gy_pcb_max`, the rim catches its edge.

**An M2.5 × 8 socket head screw holds it down**, through its 3.13 mm mounting hole into a blind 7.6 mm
pilot in the standoff, and cuts its own thread there (`gy_pilot_d`, 2.1 mm, tested). The hole is
larger than the screw, so the rim, not the screw, locates the module. Its 4.5 mm head clears the sensor
(checked with the screw in the hole). The room in front of the board is the head's 2.5 mm plus
`part_fit` to the cover.

Which edge of the pocket the hole sits by was read off a photo, so the pilot is only as right as that
reading: **seat the module in the printed pocket and look before driving the screw.** An M2 screw is not
a fallback for a tighter hole — its pilot would be under the 2 mm minimum.

## The wires come out of its back

The pedestal carries only the module's far half. Behind the pin half there is nothing down to the
plate, so the wires can be soldered to leave the back of the board. Each leaves its pad straight for
1 mm, then bends over on a 3 mm radius; where two cross, one lies behind the other. For the lab's 22 AWG
solid hookup wire (1.56 mm thick) that takes 6.4 mm, and `wire_room` keeps 7 mm free behind the pin half — the collision
check holds the pedestal out of it.

Out of the back, the wires cost the sensor nothing. Out of the front they would need that room between
the board and the cover, and the sensor would sit that much further from its vents.

Their routes to the SuperMini are in [Wiring](wiring.md).
