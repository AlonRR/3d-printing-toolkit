# What each feature is for

Drawn by [`feature-map.scad`](../feature-map.scad), which includes the model, so the numbers move with it.

## The back plate

![the back plate, numbered](feature-map-back.png)

As you face the box with the cover off:

1. **The plate** — the back of the box, flat against the wall. Everything else stands on it, and it
   prints flat on the bed.
2. **Keyhole** — the box hangs on one wall screw, like a wall clock: the screw's head goes in through
   the round opening, and the box drops so the screw rides up the slot, its head behind the plate. On
   the centre line, so the box hangs plumb; above the board, because the centre line below it is taken
   by the SPS30, the SGP41 and the antenna. A hole through the plate, so it prints as an opening in the
   first layers.
3. **Channel walls** — the SPS30 is set between them from the front, and they hold it sideways. They
   have no lips: anything over the sensor's face would block its way in.
4. **Ledges** — the sensor stands on these, one under each end of its air face, clear of the openings.
5. **Divider** — carries the middle of the sensor and splits its inlet side from its outlet side. It
   stands 4 mm below the box, so the outlet's air cannot loop straight back into the inlets.
6. **Rails** — the SuperMini slides in under their 45° lips from its USB-C side, antenna end first,
   until it meets the stops (7). The lips run from its 4th pin to its antenna end, clear of the pins
   its wires are soldered to, and keep it down on the plate. Once the cover is on, the socket in its
   snug opening holds the other end. No tape.
7. **Stops** — over the two corners of the board's antenna end. They take the push of plugging the USB-C
   cable in; the middle stays open for the antenna loop.
8. **Pedestal** — lifts the SGP41 forward, so its sensor sits 2–3 mm behind its vents instead of 16 mm.
   It stands under the module's far half only. Behind the pin half there is nothing down to the plate,
   because the wires come out of the module's back there.
9. **Ledge, standoff and rim** — the SGP41 rests on a strip along its far end, kept 0.5 mm short of the
   parts on its underside, and on a round standoff under its mounting hole. The rim locates it on three
   sides and is open towards the pins.
10. **Pilot** — for the M2.5 × 8 screw through the module's mounting hole into the standoff.
11. **Cable channel** — 6 mm long, upright directly under the board's three power pins. The SPS30's five
    wires press in from the front past a 45° lip on each wall, run up it, and leave its top end straight
    into the 5V, GND and 3V3 pads. No tie needed.
12. **Bosses** — the cover's four M3 × 14 self-tapping screws bite into these. Their pilots are blind, so
    the back of the plate stays whole.

More on 8–10 in [The SGP41's mount](sgp41-mount.md), and on 6 and 7 in [The USB-C end](usb-c-end.md).

## The cover

![the cover from inside, numbered](feature-map-cover.png)

Seen from inside — from the wall — so its left and right are swapped against the box as you face it:

1. **The front** — printed face down, so it comes out flat.
2. **Vents in front of the SGP41** — room air reaches the gas sensor.
3. **Vents in front of the board** — the board's warmth leaves here. With the lower vents they should
   act as a small chimney, drawing fresh air in past the SGP41 (reasoned, not measured).
4. **Screw holes** — clearance for the four M3 screws into the bosses.
5. **Window** — most of the bottom wall is open under the SPS30's air face, so its inlets and outlet
   breathe the room directly. Open at the back edge, so it prints without a bridge.
6. **USB-C opening** — the size of the socket's metal shell. The socket's mouth reaches the outside face,
   so any cable seats fully.
7. **Thinned wall** — 0.9 mm over the board's USB-C end, so the board reaches into it and the socket
   reaches the outside. The board's corners bear on it when a plug is pulled; the 45° step keeps a crack
   from starting.
8. **Partition** — continues the divider up the air gap in front of the sensor, so the inlet air and the
   outlet air stay apart. It stands 0.2 mm off the sensor's face, so it also keeps the SPS30 from tipping
   forward.
9. **Baffle** — closes that air gap off from the compartment above, so the board's warmth does not drift
   down into the sensor's air.
10. **Rounded corners** — ASA lifts at sharp corners; the radius is what lets both parts print without a
    brim.
