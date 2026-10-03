# The clearance test

**Print [`print-chamber-box-fits.scad`](../print-chamber-box-fits.scad) before the box**, in the same ASA
with the same profile: one flat part, about 49 min and 6.2 g. It tries each fit still untested three
ways. Every piece is the box's own geometry — drawn by the box's own modules, with only the fit changed,
and lying on the bed as it does in the back plate — so it tests exactly what the box will print.

This is the second round. The first, printed 2 Oct 2026, settled every fit it tried — its results are
below — so none of its pieces is printed again; they are in the repository's history.

## Which piece is which

![the clearance test, each group lettered](fits-map.png)

Drawn by [`fits-map.scad`](../fits-map.scad), which includes the test. **Hold the part with the low clips
on your left and the standoffs on your right** — then it matches the picture, with the edge that faced
the printer's front nearest you.

The arrows are the part's own axes, as it lay on the bed: **+x to the right, +y away from the front edge
(up the picture), +z up off the bed, towards you.** A reading given as "in x" or "in y" uses them.

Each try carries **1, 2 or 3 dots**: 1 = a step tighter, 2 = as set, 3 = a step looser — beside the nut
bosses and standoffs, in front of the clips. The values below are for 1 / 2 / 3 dots. The letters go on
from the first round's A–H, skipping I, so that a letter always means one piece.

| | Pieces | Setting | 1 / 2 / 3 dots | Try | Pick |
|---|---|---|---|---|---|
| **J** | the three round bosses in the middle | `nut_fit` | −0.1 / 0 / 0.1 — pockets 5.56 / 5.76 / 5.96 across flats as drawn | from underneath — the face that was on the bed, as the box's nuts go in from the wall side — start an M3 nut square in each hex pocket's mouth. The nut seats 1.4 mm in from the mouth, so a thumb will not get it there: drive an M3 screw in from the top, through the cap and into the nut, and tighten until it draws the nut up to the shoulder. Then take the screw out | the loosest that still holds its nut, screw out, when the part is turned over and tapped. A nut that will not start in the mouth at all is too tight, whatever it does once in |
| **K** | the three blocks on the right, each with a round standoff | `gy_pilot_d` | 2.0 / 2.1 / 2.2 | hold the GY-SGP41 against the standoff's face and drive the M2.5 × 6 cap screw through its hole, fully in, then back out — once per standoff, since the first drive cuts the thread. The pilot is sideways and as deep as the box's | the one that bites firmly without splitting the standoff or taking real force |
| **L** | the three low pairs of clips on the left | `clasp_pinch` | 0.2 / 0.1 / 0 — the catch 0.65 / 0.75 / 0.85 mm over the jaw below, against the 0.85 mm PCB | push the SuperMini's back edge — the one whose first two pins are GPIO5 and GPIO6 — straight down into a pair: USB-C end to the left, antenna end at the right-hand clip's end, parts side towards the front edge | the loosest that snaps the edge past its catches and holds the board upright when the part is tipped. 1 dot is the tightest here: a bigger pinch grips harder |

The keyholes the box hangs by are not tried here: they are sized from the wall screw with room to spare
— the slot 0.6 mm wider than the thread, at least 1 mm of plate under the head each side. The first
round's G confirms the thread's end of that.

The values follow the settings, so after a setting changes, a reprint tries a new ladder round it.

## Turning a result into a setting

Set the value in [`print-chamber-box.params.scad`](../print-chamber-box.params.scad) and delete its name
from `untested_fits`. If even the tighter try is loose, or the looser one still binds, the ladder was in
the wrong place: say so, and it moves.

## Results

**Second round — J, K and L:** not printed yet.

**First round**, all from the one print of 2 Oct 2026. Its groups were: A, the SPS30 frames; B and C,
trays for the two boards; D, bosses for the cover's self-tapping screws; E, upright pilots for the
SGP41's screw; F, the cover's screw holes; G, the mounting tabs' holes; H, a peg and socket.

| Read | Group | Setting | Ladder | Pick | Now |
|---|---|---|---|---|---|
| 2 Oct 2026 | A | `sps_fit` | 0.2 / 0.3 / 0.4 | 1 dot, snug | **0.2** |
| 2 Oct 2026 | B and C | `pocket_fit` | 0.2 / 0.3 / 0.4 | 1 dot for both boards, snug | **0.2** |
| 3 Oct 2026 | A, closer | `sps_fit` | 0.2 / 0.3 / 0.4 | 1 dot: flush in y, across the sensor's thickness; about 0.7 mm loose in x, along its width | **0.2** |
| 3 Oct 2026 | D | `pilot_d` | 2.3 / 2.5 / 2.7 | 2 dots fine; 1 dot a little tight, which may be better for a thread driven again each time the cover comes off. None split | **2.3** |
| 3 Oct 2026 | E | `gy_pilot_d` | 2.0 / 2.1 / 2.2 | 2 dots fine; 1 dot a little tight | **2.1** |
| 3 Oct 2026 | F | `screw_d` | 3.2 / 3.4 / 3.6 | 1 dot: an M3 passes freely | **3.2** |
| 3 Oct 2026 | H | `part_fit` | — | peg 5.98; socket 6.50 in y, 6.55 in x — 0.26 and 0.29 per side | **0.3** |
| 3 Oct 2026 | G | ~~`tab_hole_d`~~ | 3.8 / 4.0 / 4.2 | 3 dots fits the 4 × 20 wall screw | retired; the keyholes' slot is 4.9 as cut |

- **A, B, C, D and F** each took the tightest try, so nothing tighter has been tried.
- **A's x play was the width allowance, not the fit.** The frame's width was the datasheet's 41.2 mm
  across the sensor's side nubs plus the fit; flush in y said the fit itself was right. Measured on
  3 Oct 2026 instead: **41.00 across the nubs, 40.69 across the body**. The box's SPS30 channel now
  takes its width from those, so it is 0.2 mm narrower than the frame that was 0.7 mm loose:

  ![the two widths to measure on the SPS30](sps30-measure.png)

  Drawn by [`sps30-measure.scad`](../sps30-measure.scad), in the clearance test's axes.
- **D's screws stopped about 1 mm short in all three bosses**, because that print's pilots were 13 mm
  deep for a 14 mm screw. The three still compare. `pilot_d` has since gone from the box with the
  self-tapping cover screws: its bottom corners now screw into nuts.
- **E tried the SGP41's pilot upright.** The module now stands on edge and its screw goes in sideways, a
  hole that prints tighter at its top, so the second round's K tries it again.
- **H**'s 0.26–0.29 mm is over the 0.15 mm floor, so `part_fit` stays at 0.3.

**G is retired**: on 3 Oct 2026 the box's mounting tabs, whose holes it tried, gave way to keyholes. It
was still read, with the wall screw that will hang the box: the 4.0 mm thread fits the 4.2 mm hole, so
the keyholes' 4.9 mm slot slides freely.
