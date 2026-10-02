# The clearance test

**Print [`print-chamber-box-fits.scad`](../print-chamber-box-fits.scad) before the box**, in the same ASA
with the same profile: one flat part, about 1 h 45 min and 15 g. It tries every fit three ways, and every
size comes from the box's own settings, so it tests exactly what the box will print.

## Which piece is which

![the clearance test, each group lettered](fits-map.png)

Drawn by [`fits-map.scad`](../fits-map.scad), which includes the test. **Hold the part with the three big
SPS30 frames on your left and the row of bosses on your right** — then it matches the picture, with the
edge that faced the printer's front nearest you.

Each try carries **1, 2 or 3 dots**: 1 = a step tighter, 2 = as set, 3 = a step looser. The values below
are for 1 / 2 / 3 dots.

| | Pieces | Setting | 1 / 2 / 3 dots | Try | Pick |
|---|---|---|---|---|---|
| **A** | the three big open frames | `sps_fit` | 0.1 / 0.2 / 0.3 | slide the SPS30 through each | the tightest it slides through without forcing |
| **B** | the three large trays | `pocket_fit` | 0.1 / 0.2 / 0.3 | drop the SuperMini in | the tightest it drops into and lies flat in, without pressing |
| **C** | the three small trays | `pocket_fit` | 0.1 / 0.2 / 0.3 | drop the GY-SGP41 in | as for B |
| **D** | the three **tall** bosses, nearest the front | `pilot_d` | 2.3 / 2.5 / 2.7 | drive an M3 × 14 self-tapping screw fully in, then back out | the one that bites firmly without splitting the boss or taking real force |
| **E** | the three **short** bosses, behind them | `gy_pilot_d` | 2.0 / 2.1 / 2.2 | the same with the M2.5 × 8 cap screw | as for D |
| **F** | the hole bar's row **next to the C trays** | `screw_d` | 3.2 / 3.4 / 3.6 | an M3 screw | the smallest it passes through freely |
| **G** | the hole bar's **other** row — the larger holes | `tab_hole_d` | 3.8 / 4.0 / 4.2 | the wood screws that will hang the box | the smallest they pass through freely |
| **H** | the peg, and the block with the socket beside it | `part_fit` | — | calipers: the peg's width and the socket's | the socket is drawn 0.6 mm wider. If (socket − peg) / 2 comes out under 0.15 mm, the box's parts will bind — raise `part_fit` by the shortfall |

**The hole bar has one group of dots per column**, between its two rows: it counts for both holes in
that column.

The values follow the settings, so after a setting changes, a reprint tries a new ladder round it. A–C
show the ladder a reprint would try now; the print below tried 0.2 / 0.3 / 0.4.

## Turning a result into a setting

Set the value in [`print-chamber-box.params.scad`](../print-chamber-box.params.scad) and delete its name
from `untested_fits`. If even the tighter try is loose, or the looser one still binds, the ladder was in
the wrong place: say so, and it moves.

## Results

| Date | Group | Setting | Ladder | Pick | Now |
|---|---|---|---|---|---|
| 2 Oct 2026 | A | `sps_fit` | 0.2 / 0.3 / 0.4 | 1 dot, snug | **0.2** |
| 2 Oct 2026 | B and C | `pocket_fit` | 0.2 / 0.3 / 0.4 | 1 dot for both boards, snug | **0.2** |

Both picks were the tightest try, and snug, so 0.2 stands; nothing tighter was tried.

Not yet read from that print: D and E (the bosses), F and G (the holes), and H (the peg and socket).
