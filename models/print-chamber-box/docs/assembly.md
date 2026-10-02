# Assembly

![every part, moved apart along the way it goes in](assembly-exploded.png)

## You need

- the two printed parts, from the fits found by [the clearance test](clearance-test.md);
- the ESP32-C3 SuperMini, the SPS30 with its lead, and the GY-SGP41;
- four **M3 × 14 self-tapping** screws for the cover, and one **M2.5 × 8 socket head cap screw** for the
  SGP41;
- two **wood screws** up to 3.5 mm, to hang it;
- **22 AWG solid hookup wire** for the SGP41's four wires;
- no tape and no glue: everything is held by the printed parts.

## Order

All of this happens before the cover goes on.

1. **Slide the SuperMini in** from its USB-C side, antenna end first, under the rails' lips until it
   meets the stops.
2. **Set the SPS30 in from the front**, between its channel walls and onto its ledges. Nothing on the
   plate overhangs it.
3. **Solder the SGP41's four wires, then screw it down.** The wires come out of the module's back, which
   cannot be reached once it is down. Seat the module in its pocket and check that its mounting hole
   lines up with the pilot, then drive the M2.5 × 8 screw into the standoff.
4. **Wire it** — see [Wiring](wiring.md). The SPS30's five wires press into the cable channel; the
   SGP41's four run from behind it across to the board.
5. **Put the cover on** with the four M3 × 14 screws. Its partition rib keeps the SPS30 from tipping
   forward, and its thinned wall closes behind the SuperMini's USB-C end.

The two "from" directions are not arbitrary. Each part's way in is checked against the back plate in
the model: the SuperMini's slide from its USB-C side, and the SPS30's path in from the front. See
[Checking it](checking.md).

## Hanging it

Two wood screws through the tabs, up to 3.5 mm. The tabs reach 14 mm past the box, so the screwdriver's
shaft clears its side.

**Clip the USB-C cable to the wall 3–5 cm from the plug** with a stick-on cable clip. The box has no cable
clamp: a plug's body runs 2–3 cm out from the wall before the cable starts, and the nearest part of the
box, the tab, ends 14 mm out and 40 mm lower, so anything on the box would force the cable into a loop.
The socket does not need one: its shell-sized opening takes side loads into the wall, and the thinned
wall takes a pull. More in [The USB-C end](usb-c-end.md).
