# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""A PrusaSlicer G-code read by layer: where each layer starts, the moves that extrude in one, and whether a point
lies on one of them. make_resume.py demands a touch point on extrusions in two layers; probe_touch.py searches for
points it will accept - so both read the layers here, the same way.
"""

import re

_X = re.compile(r"X(-?[\d.]+)")
_Y = re.compile(r"Y(-?[\d.]+)")
_E = re.compile(r"E(-?[\d.]+)")


def layer_starts(lines):
    """The index of every ;LAYER_CHANGE line, and each layer's Z - from the ;Z: line after it - to that index."""
    starts = [i for i, s in enumerate(lines) if s.startswith(";LAYER_CHANGE")]
    return starts, {round(float(lines[i + 1][3:]), 3): i for i in starts}


def layer_range(starts, z_to_line, z):
    """The first line of the layer at Z z, and the first line of the layer after it."""
    s = z_to_line[round(z, 3)]
    return s, starts[starts.index(s) + 1]


def extruded_segments(lines, start, end):
    """Every move in lines[start:end] that extrudes while it travels in X or Y, as (x0, y0, x1, y1)."""
    out = []
    x = y = None
    for i in range(start, end):
        c = lines[i].split(";")[0].strip()
        if not c.startswith("G1"):
            continue
        mx, my, me = _X.search(c), _Y.search(c), _E.search(c)
        nx = float(mx.group(1)) if mx else x
        ny = float(my.group(1)) if my else y
        if me and float(me.group(1)) > 0 and x is not None and (mx or my):
            out.append((x, y, nx, ny))
        x, y = nx, ny
    return out


def covered(segs, px, py, tol=0.3):
    """Whether (px, py) lies within tol of one of the segments."""
    for x, y, nx, ny in segs:
        dx, dy = nx - x, ny - y
        l2 = dx * dx + dy * dy
        t = max(0.0, min(1.0, ((px - x) * dx + (py - y) * dy) / l2)) if l2 else 0.0
        if ((x + t * dx - px) ** 2 + (y + t * dy - py) ** 2) ** 0.5 <= tol:
            return True
    return False
