# The clearance test

**Every fit is tested now** — the last on 4 Oct 2026 — so the box needs no more of this. The test is
kept for when a setting, the printer or the filament changes: then reprint
[`print-chamber-box-fits.scad`](../print-chamber-box-fits.scad) before the box, in the same ASA with the
same profile — one flat part, about 33 min and 3.2 g. It tries each fit three ways. Every piece is the box's own geometry — drawn by the box's own modules, with only the fit changed,
and lying on the bed as it does in the back plate — so it tests exactly what the box will print.

It holds the third round. The first two, printed 2 and 3 Oct 2026, settled every fit they tried but one —
their results are below — and their pieces are in the repository's history.

## Which piece is which

![the clearance test, lettered](fits-map.png)

Drawn by [`fits-map.scad`](../fits-map.scad), which includes the test. Hold the part with the dots nearest
you — then it matches the picture, with the edge that faced the printer's front nearest you.

The arrows are the part's own axes, as it lay on the bed: **+x to the right, +y away from the front edge
(up the picture), +z up off the bed, towards you.** A reading given as "in x" or "in y" uses them.

Each try carries **1, 2 or 3 dots** in front of it: 1 = a step tighter, 2 = as set, 3 = a step looser. The
values below are for 1 / 2 / 3 dots. The letters go on from the earlier rounds' A–H and J–L, skipping I, so
that a letter always means one piece.

| | Pieces | Setting | 1 / 2 / 3 dots | Try | Pick |
|---|---|---|---|---|---|
| **M** | the three posts, each with its rib and ledge — the SGP41's mount | `gy_pilot_d` | 2.0 / 2.1 / 2.2 | lay the GY-SGP41 on each post, sensor up and its bottom edge on the ledge, and drive the M2.5 × 6 through its hole into the pilot, fully in, then back out — once per post, since the first drive cuts the thread | the one that bites firmly without splitting the post's 4.6 mm top or taking real force. No hole may go under 2 mm, so with the pilot at 2.0 a reprint tries 2.0 / 2.1 / 2.2 again: 1 dot is then the setting |

The keyholes the box hangs by are not tried here: they are sized from the wall screw with room to spare
— the slot 0.6 mm wider than the thread, at least 1 mm of plate under the head each side. The first
round's G confirms the thread's end of that.

The values follow the settings, so after a setting changes, a reprint tries a new ladder round it.

## Turning a result into a setting

Set the value in [`print-chamber-box.params.scad`](../print-chamber-box.params.scad) and delete its name
from `untested_fits`. If even the tighter try is loose, or the looser one still binds, the ladder was in
the wrong place: say so, and it moves.

## Results

**Third round**, printed 4 Oct 2026:

| Read | Group | Setting | Ladder | Pick | Now |
|---|---|---|---|---|---|
| 4 Oct 2026 | M | `gy_pilot_d` | 2.0 / 2.1 / 2.2 | 1 dot | **2.0** |

- **M** took the tightest try, which is also as small as a hole may go, so nothing tighter can be tried.
  It is the flat mount's post, upright, its top 4.6 mm across.

**Second round**, printed 3 Oct 2026. Its groups were: J, the M3 nuts' pockets; K, the SGP41's first
mount, on edge on a sideways standoff; L, pairs of the SuperMini's back clips.

| Read | Group | Setting | Ladder | Pick | Now |
|---|---|---|---|---|---|
| 3 Oct 2026 | J | `nut_fit` | −0.1 / 0 / 0.1 | 2 dots | **0** |
| 3 Oct 2026 | L | `clasp_pinch` | 0.2 / 0.1 / 0 | 2 dots | **0.1** |
| 3 Oct 2026 | K | `gy_pilot_d` | 2.0 / 2.1 / 2.2 | none: no standoff printed usably | untested |

- **J and L** each took the setting as it stood, so it stays.
- **K's standoffs did not print usably**, any of the three. Each is the box's own: a 4 mm peg standing
  2.7 mm out of its block, sideways, with nothing under it on the bed — the one real overhang in the
  back plate. It cannot be propped from below, because the module's own parts are there. The fault was
  the mount, not the pilot's size: the module now lies flat on a post, and the third round's M tries
  the pilot upright in it.

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
- **E tried the SGP41's pilot upright, in a 6 mm boss.** The module stood on edge after that, with its
  screw sideways; it now lies flat with its pilot upright again, in a post only 4.6 mm across at its top,
  so the third round's M tries it there.
- **H**'s 0.26–0.29 mm is over the 0.15 mm floor, so `part_fit` stays at 0.3.

**G is retired**: on 3 Oct 2026 the box's mounting tabs, whose holes it tried, gave way to keyholes. It
was still read, with the wall screw that will hang the box: the 4.0 mm thread fits the 4.2 mm hole, so
the keyholes' 4.9 mm slot slides freely.
