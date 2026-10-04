# The SGP41's mount

The GY-SGP41 is a small module: a 13.1 × 10.6 mm board, 1.5 mm thick, with the gas sensor on one face, its
other parts on the other, and four pins along one short end. Its mount has three jobs: put the sensor close
behind its vents, carry the board without loading its parts, and print without support.

## Where it sits

**Flat in the left-hand column, beside the SPS30, low down**, its sensor towards the cover's front and
2.1 mm behind vents there, its pins up. It sits as far forward as the screw's head in front of it allows,
and as far from the SPS30 as the side wall allows, so that the wire from its pin nearest the SPS30 clears
the channel's wall.

**Which way round is fixed by the module.** Seen from its sensor side with its pins up, its mounting
hole is at the bottom right (`gy_hole_right`). Facing the box, that puts the hole at the module's edge
towards the SPS30, and the sensor at the edge towards the side wall.

**It reaches past the end of the SPS30 channel's wall**, which stops short of the cover. The wall is
notched there, so the parts on the module's underside clear it by a millimetre; an assert holds that gap.

## How it is held

**One M2.5 × 6 socket head screw, from the front**, through its 3.13 mm mounting hole into a post that
rises from the plate, where it cuts its own thread in an upright pilot (`gy_pilot_d`, 2.0 mm), 4.9 mm
deep. Its head sits between the module and the cover, `part_fit` clear of the cover.

**Its parts never bear load.** The module lies on two things: the post's top, 4.6 mm across
(`gy_standoff_d`), inside the bare ring round the hole — 1.0 mm from the hole's edge to the nearest part
(`gy_hole_bare_d`) — and a rib under the bare strip along its bottom edge, which stops short of the
nearest part 3.31 mm in (`gy_bare`). Below the depth of its underside parts the post widens to 6 mm
(`gy_post_d`). Its bottom edge sits on a ledge over the nut boss.

**It prints without support.** The post, the rib and the ledge all stand on the back plate, so on the bed
they are walls and an upright post, and the pilot is an upright hole. The first mount held the module on
edge by a peg standing sideways out of a block; that peg had nothing under it on the bed, and the second
clearance test's three copies of it did not print usably.

The post is narrower round the pilot than the boss the first clearance test tried the pilot in, so the
[clearance test](clearance-test.md)'s third round tried it again in the post itself: 2.0 mm bites
firmly without splitting it.

Its wires to the SuperMini are in [Wiring](wiring.md).
