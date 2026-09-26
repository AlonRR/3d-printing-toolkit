# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""Add mouse-ear brim tabs to the corners of a binary STL, in place of a full brim.

PrusaSlicer has no per-area brim: brim_type/brim_width are object-level, and no
modifier mesh or paint tool localises them. The standard workaround is a disc one
layer tall welded to the corner that lifts. This does that in the geometry so the
placement survives re-slicing, instead of being re-dragged in the GUI each time.

    python scripts/add_brim_ears.py IN.stl [-o OUT.stl] [--preview p.png]

What it does, and why each step is there:

  * Ears go on the CONVEX HULL of the bed-contact faces. The hull is the set of
    corners that can lift; it also drops concave corners and holes for free, so
    there is no contour-orientation or hole-nesting logic to get wrong.
  * A rounded corner is many hull vertices, not one. The hull is split at edges
    longer than --straight, and each surviving run of short edges is one corner.
  * Every ear is checked against a raster of the real first layer:
      - it must not reach a DIFFERENT island (a part whose first layer is
        several separate patches would otherwise get its islands welded
        together by the ear, and that bridge cannot be cut off afterwards),
      - it must not cover an enclosed void (a bolt hole skinned over 0.2 mm
        deep is a defect to drill out, not a tab to snip),
      - it must actually land on material (>= --min-weld mm^2), or it is a
        disc lying next to the part rather than attached to it.
    An ear that fails is retried with less overlap, then a smaller radius,
    and only then dropped -- and a dropped ear is reported, not silenced.

The ear is appended as its own closed shell rather than booleaned in: the
slicer unions overlapping contours per layer, which is the same thing that
happens when you add a part in the GUI. The original triangles are copied
byte-for-byte, so nothing about the part itself can shift.

The output is therefore MULTI-SHELL on purpose -- `--info` reports one part per
ear plus the original. Do not run it through scad-check.sh, whose "number_of_parts
!= 1" guard is right for a .scad export and wrong for this.

Ear height defaults to one first layer (0.2 mm on the MK3S+ profiles here). The
slicer samples a layer at its mid-height, so a 0.2 mm ear appears in layer 1 and
is gone by layer 2 for any first layer from ~0.1 to 0.4 mm.
"""
import argparse
import math
import struct
import sys
from collections import deque
from pathlib import Path

import numpy as np

# ---------------------------------------------------------------- STL I/O

def read_stl(path):
    """Return (raw 50-byte facet records, Nx3x3 vertex array)."""
    with open(path, "rb") as f:
        head = f.read(84)
        if len(head) < 84:
            sys.exit(f"{path}: too short to be a binary STL")
        n = struct.unpack("<I", head[80:84])[0]
        body = f.read(n * 50)
    if len(body) != n * 50:
        sys.exit(f"{path}: not a binary STL, or truncated "
                 f"(header claims {n} facets = {n * 50} bytes, got {len(body)})")
    rec = np.frombuffer(body, dtype=np.uint8).reshape(n, 50)
    tri = rec[:, 12:48].copy().view("<f4").reshape(n, 3, 3)
    return rec, tri


def write_stl(path, rec, extra_tris, header=b""):
    """Copy the original facet records verbatim, append extra triangles."""
    n = len(rec) + len(extra_tris)
    with open(path, "wb") as f:
        f.write(header[:80].ljust(80, b"\0"))
        f.write(struct.pack("<I", n))
        f.write(rec.tobytes())
        for tri in extra_tris:
            a, b, c = tri
            nrm = np.cross(b - a, c - a)
            ln = np.linalg.norm(nrm)
            nrm = nrm / ln if ln else np.zeros(3)
            f.write(struct.pack("<12f", *nrm, *a, *b, *c))
            f.write(b"\0\0")
    return n


def cylinder(cx, cy, z0, z1, r, seg=48):
    """Closed cylinder, outward winding: bottom cap, top cap, side wall."""
    ang = np.linspace(0, 2 * math.pi, seg, endpoint=False)
    x = cx + r * np.cos(ang)
    y = cy + r * np.sin(ang)
    tris = []
    for i in range(seg):
        j = (i + 1) % seg
        bi = np.array([x[i], y[i], z0]); bj = np.array([x[j], y[j], z0])
        ti = np.array([x[i], y[i], z1]); tj = np.array([x[j], y[j], z1])
        cb = np.array([cx, cy, z0]);     ct = np.array([cx, cy, z1])
        tris.append((cb, bj, bi))          # bottom, normal -z
        tris.append((ct, ti, tj))          # top, normal +z
        tris.append((bi, bj, tj))          # side
        tris.append((bi, tj, ti))
    return tris


# ------------------------------------------------------- first-layer raster

def bed_faces(tri, z0, tol):
    """Triangles lying flat on the bed -- the actual first-layer contact."""
    return tri[(tri[:, :, 2] <= z0 + tol).all(1)]


def rasterize(faces, cell, pad):
    """Boolean grid of first-layer material, plus (x0, y0) of cell centre [0,0]."""
    v = faces.reshape(-1, 3)
    lo = v[:, :2].min(0) - pad
    hi = v[:, :2].max(0) + pad
    nx = int(np.ceil((hi[0] - lo[0]) / cell)) + 1
    ny = int(np.ceil((hi[1] - lo[1]) / cell)) + 1
    grid = np.zeros((ny, nx), dtype=bool)
    for t in faces:
        a, b, c = t[0, :2], t[1, :2], t[2, :2]
        det = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(det) < 1e-12:
            continue
        tlo = np.minimum(np.minimum(a, b), c)
        thi = np.maximum(np.maximum(a, b), c)
        i0 = max(0, int((tlo[0] - lo[0]) / cell) - 1)
        i1 = min(nx - 1, int((thi[0] - lo[0]) / cell) + 1)
        j0 = max(0, int((tlo[1] - lo[1]) / cell) - 1)
        j1 = min(ny - 1, int((thi[1] - lo[1]) / cell) + 1)
        if i1 < i0 or j1 < j0:
            continue
        xs = lo[0] + np.arange(i0, i1 + 1) * cell
        ys = lo[1] + np.arange(j0, j1 + 1) * cell
        X, Y = np.meshgrid(xs, ys)
        l1 = ((b[1] - c[1]) * (X - c[0]) + (c[0] - b[0]) * (Y - c[1])) / det
        l2 = ((c[1] - a[1]) * (X - c[0]) + (a[0] - c[0]) * (Y - c[1])) / det
        l3 = 1 - l1 - l2
        grid[j0:j1 + 1, i0:i1 + 1] |= (l1 >= -1e-9) & (l2 >= -1e-9) & (l3 >= -1e-9)
    return grid, lo


def components(mask):
    """Label 4-connected components of a boolean grid. 0 = not in mask."""
    lab = np.zeros(mask.shape, dtype=np.int32)
    ny, nx = mask.shape
    cur = 0
    for sy in range(ny):
        for sx in range(nx):
            if not mask[sy, sx] or lab[sy, sx]:
                continue
            cur += 1
            q = deque([(sy, sx)])
            lab[sy, sx] = cur
            while q:
                y, x = q.popleft()
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny_, nx_ = y + dy, x + dx
                    if 0 <= ny_ < ny and 0 <= nx_ < nx and mask[ny_, nx_] and not lab[ny_, nx_]:
                        lab[ny_, nx_] = cur
                        q.append((ny_, nx_))
    return lab, cur


# ------------------------------------------------------------ corner finding

def convex_hull(pts):
    """Andrew monotone chain, CCW, strict turns (collinear points dropped)."""
    p = np.unique(np.round(pts, 4), axis=0)
    p = p[np.lexsort((p[:, 1], p[:, 0]))]
    if len(p) < 3:
        return p

    def half(points):
        out = []
        for q in points:
            while len(out) >= 2:
                a, b = out[-2], out[-1]
                if (b[0] - a[0]) * (q[1] - a[1]) - (b[1] - a[1]) * (q[0] - a[0]) > 1e-9:
                    break
                out.pop()
            out.append(q)
        return out

    return np.array(half(p)[:-1] + half(p[::-1])[:-1])


def corners(hull, straight, min_turn):
    """Group hull vertices into corners; long edges separate them.

    Returns [(apex xy, outward unit vector, total turn in degrees)].
    """
    n = len(hull)
    edge = np.roll(hull, -1, axis=0) - hull            # edge i: vertex i -> i+1
    elen = np.linalg.norm(edge, axis=1)
    with np.errstate(invalid="ignore", divide="ignore"):
        edir = edge / elen[:, None]
    # A vertex is "broken" when the edge arriving at it is long: that edge is a
    # straight side, so the corner ends there.
    breaks = [i for i in range(n) if elen[i - 1] > straight]
    if not breaks:                                     # a circle: no corners
        return []
    out = []
    for k, start in enumerate(breaks):
        end = breaks[(k + 1) % len(breaks)]
        run = []
        i = start
        while True:
            run.append(i)
            if i == (end - 1) % n:
                break
            i = (i + 1) % n
            if len(run) > n:
                break
        # Turn accumulated across the run: incoming edge before it, outgoing after.
        din = edir[(run[0] - 1) % n]
        dout = edir[run[-1] % n]
        turn = math.degrees(math.atan2(din[0] * dout[1] - din[1] * dout[0],
                                       din @ dout))
        if turn < min_turn:
            continue
        # Apex: vertex at the middle of the run by arc length.
        pts = hull[run]
        if len(pts) == 1:
            apex = pts[0]
        else:
            seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
            cum = np.concatenate([[0], np.cumsum(seg)])
            apex = pts[int(np.argmin(np.abs(cum - cum[-1] / 2)))]
        # Outward bisector: for a CCW hull the outward normal of edge d is (dy,-dx).
        nin = np.array([din[1], -din[0]])
        nout = np.array([dout[1], -dout[0]])
        bis = nin + nout
        bis = bis / np.linalg.norm(bis)
        out.append((apex, bis, turn))
    return out


def edge_tabs(hull, spacing):
    """Anchor points spread along the long straight sides between corners.

    Corners are not always where a part lifts. A long thin part can have both
    ends of an edge blocked -- by a bolt hole, or by a corner too thin to weld
    to -- and then corner-only ears leave that whole side unanchored. These are
    the same disc, placed mid-edge. Off unless --edge-tabs is given, because on
    a large part they multiply fast.

    Returns [(point xy, outward unit vector, 0.0)] to match corners().
    """
    out = []
    n = len(hull)
    for i in range(n):
        a, b = hull[i], hull[(i + 1) % n]
        d = b - a
        ln = float(np.linalg.norm(d))
        if ln < spacing:
            continue
        d = d / ln
        nrm = np.array([d[1], -d[0]])          # outward for a CCW hull
        k = int(ln // spacing)
        for j in range(k):
            out.append((a + d * ln * (j + 0.5) / k, nrm, 0.0))
    return out


# ------------------------------------------------------------------- placing

def disc_cells(grid_shape, lo, cell, cx, cy, r):
    ny, nx = grid_shape
    i0 = max(0, int((cx - r - lo[0]) / cell) - 1)
    i1 = min(nx - 1, int((cx + r - lo[0]) / cell) + 1)
    j0 = max(0, int((cy - r - lo[1]) / cell) - 1)
    j1 = min(ny - 1, int((cy + r - lo[1]) / cell) + 1)
    if i1 < i0 or j1 < j0:
        return None
    xs = lo[0] + np.arange(i0, i1 + 1) * cell
    ys = lo[1] + np.arange(j0, j1 + 1) * cell
    X, Y = np.meshgrid(xs, ys)
    inside = (X - cx) ** 2 + (Y - cy) ** 2 <= r * r
    return (slice(j0, j1 + 1), slice(i0, i1 + 1)), inside


def place(apex, bis, r, overlap, mat_lab, void_lab, exterior, lo, cell, clearance, min_weld):
    """Try one (radius, overlap). Returns (cx, cy, weld mm^2) or a reason string."""
    cx, cy = apex + bis * (r - overlap)
    got = disc_cells(mat_lab.shape, lo, cell, cx, cy, r)
    if got is None:
        return "off-grid"
    box, inside = got
    # Which island is this corner on? The apex sits ON the boundary, so the cell
    # under it is as likely to be void as material -- looking up that one cell
    # returns 0, which then reads as "no island", silently disables the bridging
    # check, and makes the weld measurement count void cells instead. Take the
    # commonest real label in a small neighbourhood instead.
    nb = disc_cells(mat_lab.shape, lo, cell, apex[0], apex[1], max(1.5, 3 * cell))
    if nb is None:
        return "off-grid"
    near_apex = mat_lab[nb[0]][nb[1]]
    near_apex = near_apex[near_apex != 0]
    if not near_apex.size:
        return "corner is not on any island"
    own = int(np.bincount(near_apex).argmax())
    # Grown disc: the clearance check has to see material just outside the ear too.
    gbox, ginside = disc_cells(mat_lab.shape, lo, cell, cx, cy, r + clearance)
    near = mat_lab[gbox][ginside]
    if np.any((near != 0) & (near != own)):
        return "would bridge to another island"
    hit_void = void_lab[gbox][ginside]
    if np.any((hit_void != 0) & (hit_void != exterior)):
        return "would cover an enclosed hole"
    weld = int(np.count_nonzero(mat_lab[box][inside] == own)) * cell * cell
    if weld < min_weld:
        return f"only {weld:.1f} mm^2 of weld"
    return (float(cx), float(cy), weld)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("stl")
    ap.add_argument("-o", "--out")
    ap.add_argument("--preview", help="write a top-view PNG of the placement")
    ap.add_argument("--diameter", type=float, default=12.0, help="ear diameter mm (default 12)")
    ap.add_argument("--overlap", type=float, default=3.0,
                    help="how far the ear reaches into the part, mm (default 3)")
    ap.add_argument("--height", type=float, default=0.2,
                    help="ear height mm = one first layer (default 0.2)")
    ap.add_argument("--straight", type=float, default=5.0,
                    help="hull edge longer than this is a straight side, not a corner (mm)")
    ap.add_argument("--min-turn", type=float, default=30.0,
                    help="ignore hull corners that turn less than this (deg)")
    ap.add_argument("--clearance", type=float, default=1.0,
                    help="keep this clear of other islands and holes (mm)")
    ap.add_argument("--edge-tabs", type=float, default=0.0, metavar="MM",
                    help="also anchor long straight sides, one tab per MM of edge "
                         "(default 0 = corners only)")
    ap.add_argument("--min-weld", type=float, default=5.0,
                    help="reject an ear welded to less than this much material (mm^2)")
    ap.add_argument("--cell", type=float, default=0.4, help="raster cell size mm")
    ap.add_argument("--flat-tol", type=float, default=0.001,
                    help="how far above the lowest point still counts as bed contact")
    ap.add_argument("--segments", type=int, default=48)
    ap.add_argument("--dry-run", action="store_true", help="report placement, write no STL")
    a = ap.parse_args()

    src = Path(a.stl)
    out = Path(a.out) if a.out else src.with_name(src.stem + "-ears.stl")
    rec, tri = read_stl(src)
    z0 = float(tri[:, :, 2].min())
    faces = bed_faces(tri, z0, a.flat_tol)
    if not len(faces):
        sys.exit("no flat bed-contact faces found -- is the part resting on z=min?")

    print(f"{src.name}")
    print(f"  {len(tri)} facets, z rests at {z0:.3f}, {len(faces)} bed-contact facets")

    grid, lo = rasterize(faces, a.cell, pad=a.diameter)
    mat_lab, n_isl = components(grid)
    void_lab, _ = components(~grid)
    exterior = int(void_lab[0, 0])
    print(f"  first layer: {grid.sum() * a.cell ** 2:.0f} mm^2 in {n_isl} island(s)")

    hull = convex_hull(faces.reshape(-1, 3)[:, :2])
    cands = corners(hull, a.straight, a.min_turn)
    msg = f"  {len(cands)} convex corner(s) on the hull"
    if a.edge_tabs:
        tabs = edge_tabs(hull, a.edge_tabs)
        cands += tabs
        msg += f" + {len(tabs)} mid-edge tab site(s) at {a.edge_tabs} mm spacing"
    print(msg + "\n")

    ears, dropped = [], []
    for apex, bis, turn in cands:
        kind = "ear" if turn else "tab"
        placed = None
        for r in (a.diameter / 2, a.diameter / 2 - 1, a.diameter / 2 - 2):
            if r < 2:
                break
            ov = a.overlap
            while ov >= 1.5:
                res = place(apex, bis, r, ov, mat_lab, void_lab, exterior,
                            lo, a.cell, a.clearance, a.min_weld)
                if isinstance(res, tuple):
                    placed = (res[0], res[1], r, ov, res[2])
                    break
                reason = res
                ov -= 0.25
            if placed:
                break
        if placed:
            cx, cy, r, ov, weld = placed
            # Two hull corners a few mm apart (a chamfer, say) give two discs
            # that merge into one blob -- more plastic, no more anchoring, and a
            # shape that no longer snips off cleanly. Keep the better-welded one.
            clash = next(((i, e) for i, e in enumerate(ears)
                          if math.dist((cx, cy), e[:2]) < 0.75 * (r + e[2])), None)
            if clash:
                i, e = clash
                if weld <= e[3]:
                    dropped.append((apex, "overlaps a better-welded ear"))
                    print(f"  SKIPPED  ({apex[0]:8.2f},{apex[1]:8.2f})  "
                          f"{kind}  -- overlaps the ear at ({e[0]:.2f},{e[1]:.2f})")
                    continue
                print(f"  replaced the ear at ({e[0]:.2f},{e[1]:.2f}) "
                      f"-- overlapping, and welded {e[3]:.1f} < {weld:.1f} mm^2")
                ears.pop(i)
            ears.append((cx, cy, r, weld))
            note = "" if (r == a.diameter / 2 and ov == a.overlap) else \
                   f"   [shrunk: d={2 * r:.0f} overlap={ov:.2f}]"
            print(f"  {kind} at ({apex[0]:8.2f},{apex[1]:8.2f})  turn {turn:5.1f} deg  "
                  f"weld {weld:5.1f} mm^2{note}")
        else:
            dropped.append((apex, reason))
            print(f"  SKIPPED  ({apex[0]:8.2f},{apex[1]:8.2f})  turn {turn:5.1f} deg  -- {reason}")

    if a.preview:
        preview(a.preview, src.name, faces, hull, ears, lo, grid, a.cell)
        print(f"\n  preview -> {a.preview}")

    if a.dry_run:
        print("\n  --dry-run: no STL written")
        return 0 if ears else 1

    extra = []
    for cx, cy, r, _ in ears:
        extra += cylinder(cx, cy, z0, z0 + a.height, r, a.segments)
    n = write_stl(out, rec, extra, header=f"{src.stem} + {len(ears)} brim ears".encode())
    print(f"\n  {len(ears)} ear(s), {len(extra)} added facets -> {out}  ({n} facets total)")
    if dropped:
        print(f"  {len(dropped)} corner(s) got no ear (see SKIPPED above)")
    return 0


def preview(path, title, faces, hull, ears, lo, grid, cell):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Circle, Polygon
    from matplotlib.collections import PatchCollection

    fig, ax = plt.subplots(figsize=(11, 10))
    ax.add_collection(PatchCollection([Polygon(t[:, :2]) for t in faces],
                                      facecolor="#9fc0e8", edgecolor="none"))
    ax.plot(*np.vstack([hull, hull[:1]]).T, "-", color="#888", lw=0.8, label="hull")
    for cx, cy, r, _ in ears:
        ax.add_patch(Circle((cx, cy), r, facecolor="#e2504a", alpha=0.65,
                            edgecolor="#8b1a16", lw=1.0))
        ax.plot([cx], [cy], "k+", ms=5)
    v = faces.reshape(-1, 3)
    m = 15
    ax.set_xlim(v[:, 0].min() - m, v[:, 0].max() + m)
    ax.set_ylim(v[:, 1].min() - m, v[:, 1].max() + m)
    ax.set_aspect("equal")
    ax.grid(True, lw=0.3, alpha=0.4)
    ax.set_title(f"{title} — first layer (blue) + {len(ears)} brim ears (red)")
    fig.savefig(path, dpi=110, bbox_inches="tight")
    plt.close(fig)


if __name__ == "__main__":
    sys.exit(main())
