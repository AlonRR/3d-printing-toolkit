# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""Find touch-off points that make_resume.py will actually accept, instead of guessing them.

Uses make_resume.py's own test - gcode_layers.covered(), the same segments and the same 0.3 mm tolerance - but
builds each layer's segment list once so thousands of candidates can be tested cheaply.

A candidate must be covered in BOTH the touch layer and the one below it, which is what
make_resume.py demands. Prints, per X column, the contiguous Y window that qualifies.

usage: probe_touch.py <gcode> <wall_z>
"""

import sys
from itertools import pairwise
from pathlib import Path

from gcode_layers import covered, extruded_segments, layer_range, layer_starts


def runs(ys):
    """Split a sorted list of Y values, 0.02 mm apart where they are contiguous, into its contiguous runs."""
    out, cur = [], [ys[0]]
    for a, b in pairwise(ys):
        if round(b - a, 2) <= 0.021:
            cur.append(b)
        else:
            out.append(cur)
            cur = [b]
    out.append(cur)
    return out


def window(top, bot, px):
    """The longest Y window at X px, between 15 and 23 mm, covered in both layers: (width, px, mid, lo, hi), or
    None when nothing there is."""
    ys = []
    y = 15.0
    while y <= 23.0001:
        if covered(top, px, y) and covered(bot, px, y):
            ys.append(round(y, 2))
        y += 0.02
    if not ys:
        return None
    r = max(runs(ys), key=len)
    return round(r[-1] - r[0], 2), px, round((r[0] + r[-1]) / 2, 3), r[0], r[-1]


def main(argv):
    src = Path(argv[1])
    wall_z = float(argv[2])
    below = round(wall_z - 0.2, 3)

    lines = src.read_text(encoding="utf-8").split("\n")
    starts, z_to_line = layer_starts(lines)
    top = extruded_segments(lines, *layer_range(starts, z_to_line, wall_z))
    bot = extruded_segments(lines, *layer_range(starts, z_to_line, below))
    print(f"layer {wall_z:g}: {len(top)} extruded segments;  layer {below:g}: {len(bot)}")

    # The front wall lives at low Y. Sweep each X column and find the Y window covered in BOTH layers.
    print(f"\n X     Y window covered in BOTH layers {wall_z:g} and {below:g}   (width)")
    best = []
    for xi in range(30, 221, 5):
        found = window(top, bot, float(xi))
        if found:
            width, px, mid, lo, hi = found
            best.append(found)
            print(f" {px:6.1f}   {lo:6.2f} .. {hi:6.2f}   mid {mid:6.3f}   ({width:.2f} mm)")

    if best:
        w, px, mid, lo, hi = max(best)
        print(f"\nWIDEST: X{px:g} Y{mid:g}  (covered {lo:g}..{hi:g}, {w:g} mm of margin either side)")
        print(f"  RESUME_TOUCH_XY={px:g},{mid:g}")
    else:
        print("\nNO front-wall point qualifies in both layers - stay on the left wall.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
