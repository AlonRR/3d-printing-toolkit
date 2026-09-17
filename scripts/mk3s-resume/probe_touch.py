"""Find touch-off points that make_resume.py will actually accept, instead of guessing them.

Replicates make_resume.covered() EXACTLY - same segment construction, same 0.3 mm tolerance - but
builds each layer's segment list once so thousands of candidates can be tested cheaply.

A candidate must be covered in BOTH the touch layer and the one below it, which is what
make_resume.py demands. Prints, per X column, the contiguous Y window that qualifies.

usage: probe_touch.py <gcode> <wall_z>
"""
import re
import sys
from pathlib import Path

src = Path(sys.argv[1])
wall_z = float(sys.argv[2])
below = round(wall_z - 0.2, 3)

L = src.read_text(encoding="utf-8").split("\n")
layer_idx = [i for i, s in enumerate(L) if s.startswith(";LAYER_CHANGE")]
z_to_line = {round(float(L[i + 1][3:]), 3): i for i in layer_idx}


def segments(z):
    """Exactly the moves make_resume.covered() would consider, as (x0,y0,x1,y1)."""
    s = z_to_line[round(z, 3)]
    e = layer_idx[layer_idx.index(s) + 1]
    out = []
    x = y = None
    for i in range(s, e):
        c = L[i].split(";")[0].strip()
        if not c.startswith("G1"):
            continue
        mx = re.search(r"X(-?[\d.]+)", c)
        my = re.search(r"Y(-?[\d.]+)", c)
        me = re.search(r"E(-?[\d.]+)", c)
        nx = float(mx.group(1)) if mx else x
        ny = float(my.group(1)) if my else y
        if me and float(me.group(1)) > 0 and x is not None and (mx or my):
            out.append((x, y, nx, ny))
        x, y = nx, ny
    return out


def covered(segs, px, py, tol=0.3):
    for (x, y, nx, ny) in segs:
        dx, dy = nx - x, ny - y
        l2 = dx * dx + dy * dy
        t = max(0.0, min(1.0, ((px - x) * dx + (py - y) * dy) / l2)) if l2 else 0.0
        if ((x + t * dx - px) ** 2 + (y + t * dy - py) ** 2) ** 0.5 <= tol:
            return True
    return False


top = segments(wall_z)
bot = segments(below)
print(f"layer {wall_z:g}: {len(top)} extruded segments;  layer {below:g}: {len(bot)}")

# The front wall lives at low Y. Sweep each X column and find the Y window covered in BOTH layers.
print(f"\n X     Y window covered in BOTH layers {wall_z:g} and {below:g}   (width)")
best = []
for xi in range(30, 221, 5):
    px = float(xi)
    ys = []
    y = 15.0
    while y <= 23.0001:
        if covered(top, px, y) and covered(bot, px, y):
            ys.append(round(y, 2))
        y += 0.02
    if not ys:
        continue
    # longest contiguous run
    runs, cur = [], [ys[0]]
    for a, b in zip(ys, ys[1:]):
        (cur.append(b) if round(b - a, 2) <= 0.021 else (runs.append(cur), cur := [b]))
    runs.append(cur)
    r = max(runs, key=len)
    width = round(r[-1] - r[0], 2)
    mid = round((r[0] + r[-1]) / 2, 3)
    best.append((width, px, mid, r[0], r[-1]))
    print(f" {px:6.1f}   {r[0]:6.2f} .. {r[-1]:6.2f}   mid {mid:6.3f}   ({width:.2f} mm)")

if best:
    best.sort(reverse=True)
    w, px, mid, lo, hi = best[0]
    print(f"\nWIDEST: X{px:g} Y{mid:g}  (covered {lo:g}..{hi:g}, {w:g} mm of margin either side)")
    print(f"  RESUME_TOUCH_XY={px:g},{mid:g}")
else:
    print("\nNO front-wall point qualifies in both layers - stay on the left wall.")
