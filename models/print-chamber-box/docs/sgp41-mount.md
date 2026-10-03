# The SGP41's mount

The GY-SGP41 is a small module: a 13.1 × 10.6 mm board with the gas sensor on one face, its other parts on
the other, and four pins along one short end. Its mount has three jobs: put the sensor close behind its
vents, carry the board without loading its parts, and turn its pins towards the SuperMini.

## Where it sits

**On edge in the left-hand column, beside the SPS30, low down.** Its sensor faces the side wall's vents,
2.1–2.9 mm behind them (to the sensor's face, which stands 0.71 mm proud of its board; the range is the
board's possible thickness, `gy_pcb_min` to `gy_pcb_max`). Its pins point up, towards the board. The
left-hand keyhole is 7.7 mm above it, and an assert keeps the keyhole clear of it.

**Which way round is fixed by the module.** Seen from its sensor side with its pins up, its mounting
hole is at the bottom right (`gy_hole_right`). Standing with its sensor towards the side wall, that puts
the hole by the module's front edge, away from the plate, and the sensor by its back edge.

## How it is held

**One M2.5 × 6 socket head screw, sideways**, through its 3.13 mm mounting hole into a 4 mm round
standoff, where it cuts its own thread in a 5.6 mm pilot (`gy_pilot_d`, 2.1 mm). The screw goes in from
the sensor side, so its head sits between the module and the side wall; an assert keeps room for it there
over the thickest board.

**Its parts never bear load.** The standoff bears only on the bare patch round the hole — 1.0 mm from the
hole's edge to the nearest part (`gy_hole_bare_d`) — and the block it stands on stays 1 mm clear of the
parts on the module's underside, at the thinnest board. The module's bottom edge sits on a ledge over the
nut boss; the ledge and the clamped screw hold it square.

**The block backs onto the SPS30 channel's wall.** The pilot stops 1.85 mm short of the channel's inside,
and an assert keeps at least two beads there — an M2.5 × 8 would break through.

The pilot is a horizontal hole on the bed, which prints tighter at its top than the upright one the first
clearance test tried, so `gy_pilot_d` is untested again; the [clearance test](clearance-test.md)'s K tries
it.

Its wires to the SuperMini are in [Wiring](wiring.md).
