# The clearance test

**Print [`print-chamber-box-fits.scad`](../print-chamber-box-fits.scad) before the box**, in the same ASA
with the same profile: one flat part, about 1 h 45 min and 15 g. It tries every fit three ways, and every
size comes from the box's own settings, so it tests exactly what the box will print.

Each try carries dots: **1 = a step tighter, 2 = as set, 3 = a step looser.**

## What to try

| Setting | Pieces | Try | Pick |
|---|---|---|---|
| `sps_fit` (0.1 / 0.2 / 0.3) | three open frames | slide the SPS30 through each | the tightest it slides through without forcing |
| `pocket_fit` (0.1 / 0.2 / 0.3) | three SuperMini trays, three GY-SGP41 trays | drop each board in | the tightest that each board drops into and lies flat in, without pressing |
| `pilot_d` (2.3 / 2.5 / 2.7) | the three tall bosses | drive an M3 × 14 self-tapping screw fully in, then back out | the one that bites firmly without splitting the boss or taking real force |
| `gy_pilot_d` (2.0 / 2.1 / 2.2) | the three short bosses | the same with the M2.5 × 8 cap screw | as above |
| `screw_d` (3.2 / 3.4 / 3.6) | the bar, upper row, left to right | an M3 screw | the smallest it passes through freely |
| `tab_hole_d` (3.8 / 4.0 / 4.2) | the bar, lower row, left to right | the wood screws that will hang the box | the smallest they pass through freely |
| `part_fit` (0.3) | the peg, and the socket beside it | calipers: the peg's width and the socket's | the socket is drawn 0.6 mm wider. If (socket − peg) / 2 comes out under 0.15 mm, the box's parts will bind — raise `part_fit` by the shortfall |

The values in brackets are the current ladder; they follow the settings, so they move when a setting does.

## Turning a result into a setting

Set the value in [`print-chamber-box.params.scad`](../print-chamber-box.params.scad) and delete its name
from `untested_fits`. If even the tighter try is loose, or the looser one still binds, the ladder was in
the wrong place: say so, and it moves.

## Results

| Date | Setting | Ladder | Pick | Now |
|---|---|---|---|---|
| 2 Oct 2026 | `sps_fit` | 0.2 / 0.3 / 0.4 | 1 dot | **0.2** |
| 2 Oct 2026 | `pocket_fit` — SuperMini and GY-SGP41 both | 0.2 / 0.3 / 0.4 | 1 dot | **0.2** |

Both picks were the tightest try on that ladder, so nothing tighter was tried. A reprint tries 0.1 /
0.2 / 0.3.

Not yet reported from that print: the bosses (`pilot_d`, `gy_pilot_d`), the holes (`screw_d`,
`tab_hole_d`) and the peg and socket (`part_fit`).
