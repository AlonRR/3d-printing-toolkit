# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""Generate a Live adjust Z calibration tag plate for any nozzle, as G-code.

usage: make_live_z_tags.py <out.gcode> [nozzle] [first_layer_h] [extrusion_w] [z_start] [z_step] [n_tags] [filament.ini]
       defaults: 0.8  0.3  0.85  0.40  0.05  11  (profile chosen by nozzle - see below)

WHY THIS EXISTS. The published "PETG Live-Z Calibration Tags" set ships 0.4 and 0.6 variants and no
0.8, and the source model (intermediate.scad.stl) is not distributed - both folders hold G-code
only. The two variants are genuine re-slices, not patched numbers: comparing the 0.4 and 0.6 coarse
files, only 41 of ~7000 XY moves are shared, path spacing differs and total filament differs by
13%. So an 0.8 variant cannot be made by rewriting E values in a 0.4 file. Bead width would be 0.85
laid on 0.45 mm centres - overlapping by half - which on this particular print is not cosmetic: the
whole artifact exists to be read by eye, and uniformly over-squished tags push Live Z the wrong way
while looking authoritative.

HOW THE REFERENCE WORKS, measured rather than assumed. There is no M851, M290 or babystep anywhere
in it. Each tag is ONE layer of constant thickness printed at a DIFFERENT nozzle elevation: the
file steps G1 Z through the ladder and prints one 39 x 9 mm patch at each height. Proven by flow -
E per mm of path is constant across the whole ladder (0.0521 at every Z in the 0.6 set, 0.0317 in
the 0.4 set). Were the tags pads of differing thickness, flow would scale ~3x from 0.300 to 0.800.

WHAT THE LADDER MEANS. The bed is mesh-levelled (G80) and the sheet's Live Z is applied, so
commanded Z is relative to the calibrated zero. If the good-looking tag is at Z 0.500 while the
nominal first layer is 0.200, the nozzle is sitting 0.300 too high and Live Z moves by -0.300.
The ladder deliberately starts ABOVE nominal and climbs: you approach from too-high, so no setting
on the plate can drive the nozzle into the sheet.

LABELS. Each tag has its Z drawn beside it in a seven-segment stroke font sized from the bead, not
from a typed point size - see the block above the font for the measurements behind that. The
reference sets void their labels out of the pad instead, which is what a slicer produces from
debossed text and what stops working once the bead is wide enough to bridge the gap.

FLOW. area = h*(w - h) + pi*(h/2)^2 - a flat bead with semicircular edges, PrusaSlicer's model.
Checked against the 0.4 reference at its first-layer width: predicted 0.03135 E/mm against a
measured 0.03168, 1.0% low. The 0.6 reference reads 3.3% off the same formula because it MIXES
widths (0.65 perimeters, 0.60 top infill) and the measurement averages them. This plate uses ONE
width everywhere, so that error source is absent by construction.
"""

import math
import re
import sys
from dataclasses import dataclass
from pathlib import Path

from preset import read_temperatures

# Geometry copied from the reference set rather than invented - a proven, readable layout.
TAG_W, TAG_D, PITCH = 39.0, 9.0, 12.0
X0, Y0 = 105.5, 40.0
LABEL_X_END = 103.0  # labels are right-aligned to end here, just left of the pad
FIL_AREA = math.pi * (1.75 / 2) ** 2
BED_X, BED_Y = 250.0, 210.0

# Temps are READ FROM THE PROFILE, never typed here, so the profile stays the one source - the same
# rule retarget_filament_temps.py follows. Hardcoding them is how a plate silently keeps printing at
# last month's bed temp after the profile moves. This plate is ENTIRELY first layer, so it is the
# first-layer pair that applies, not the subsequent-layer one. The profile follows the nozzle: the
# base preset's compatible_printers_condition excludes 0.8, so an 0.8 run needs the @0.8 sibling.
T_KEYS = ("first_layer_temperature", "first_layer_bed_temperature")
PROFILES = Path(__file__).resolve().parents[1] / "slicer" / "filament" / "unbranded"

# ---- the label font ---------------------------------------------------------------------------
# WHY STROKES AND NOT VOIDS. The published 0.4 and 0.6 sets carry their labels as voids knocked out
# of a solid pad - measured, by rasterising them: the plastic is the background and the characters
# are the gaps. That is what a slicer emits for debossed text on a model, not a legibility decision,
# and it does not survive a big nozzle. A void only reads as a character if it stays open, and the
# printed void is the centreline gap MINUS one bead width. The 0.4 set's narrowest glyph void is
# 0.70 mm against a 0.45 bead; at a 0.85 bead the same void prints at -0.15 mm, i.e. the two beads
# touch and the character fills in. Generating G-code directly carries no such constraint, so the
# label is DRAWN, one bead wide, in clear space beside the pad - which cannot close up at any bead.
#
# SIZING IS DERIVED FROM THE BEAD, not typed (Plate below). A stroke needs length >= 4 x bead to
# read, and two parallel strokes need >= 2 x bead between them or they merge. Check on that rule: at
# the 0.4 reference's own width of 0.42, 8 x WIDTH predicts a 3.36 mm glyph and the measured
# reference glyph box is 3.2 mm. The formula lands on the reference's size without being fitted to it.
#
# Seven segments on a unit grid of (SEG, SEG); y=0 is the baseline, y=2 the cap height.
SEGMENTS = {"a": (0, 2, 1, 2), "b": (1, 2, 1, 1), "c": (1, 1, 1, 0), "d": (0, 0, 1, 0),
            "e": (0, 0, 0, 1), "f": (0, 1, 0, 2), "g": (0, 1, 1, 1)}
DIGITS = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
          "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg"}


@dataclass(frozen=True)
class Plate:
    """The bead and the ladder, and what follows from them."""

    nozzle: float
    layer_h: float
    width: float
    z_start: float
    z_step: float
    n_tags: int

    @property
    def bead(self):
        return self.layer_h * (self.width - self.layer_h) + math.pi * (self.layer_h / 2) ** 2

    @property
    def e_per_mm(self):
        return self.bead / FIL_AREA

    @property
    def seg(self):  # one segment: half the glyph height, the full glyph width
        return 4.0 * self.width

    @property
    def glyph_gap(self):  # between adjacent characters, so they cannot merge
        return 2.0 * self.width

    @property
    def dot_w(self):
        return 2.0 * self.width

    @property
    def zs(self):
        return [round(self.z_start + i * self.z_step, 3) for i in range(self.n_tags)]


def extrude(p, x0, y0, x1, y1, feed=None):
    """One extruding move, E from the measured bead area: (lines, its length)."""
    d = math.hypot(x1 - x0, y1 - y0)
    lines = [f"G1 F{feed}"] if feed else []
    return [*lines, f"G1 X{x1:.3f} Y{y1:.3f} E{d * p.e_per_mm:.5f}"], d


def glyph(p, ch, x, y):
    """One character with its bottom-left at (x, y): (lines, advance, path drawn)."""
    if ch == ".":
        lines, d = extrude(p, x, y, x + p.dot_w, y, 1200)
        return [f"G1 X{x:.3f} Y{y:.3f} F10800", *lines], p.dot_w, d
    out, drawn = [], 0.0
    for s in DIGITS[ch]:
        sx0, sy0, sx1, sy1 = SEGMENTS[s]
        ax, ay = x + sx0 * p.seg, y + sy0 * p.seg
        bx, by = x + sx1 * p.seg, y + sy1 * p.seg
        lines, d = extrude(p, ax, ay, bx, by, 1200)
        out += [f"G1 X{ax:.3f} Y{ay:.3f} F10800", *lines]  # travel to the stroke start, no extrusion
        drawn += d
    return out, p.seg, drawn


def label(p, text, x_end, y):
    """`text` right-aligned to end at x_end: (lines, path drawn)."""
    widths = [p.dot_w if c == "." else p.seg for c in text]
    x = x_end - (sum(widths) + p.glyph_gap * (len(text) - 1))
    assert x > 0, f"label {text!r} does not fit left of {x_end}: would start at {x:.1f}"
    out, drawn = [], 0.0
    for c, w in zip(text, widths, strict=True):
        lines, _, d = glyph(p, c, x, y)
        out += lines
        drawn += d
        x += w + p.glyph_gap
    return out, drawn


def tag(p, i, z):
    """Tag i at nozzle height z: a meander fill one width wide, boustrophedon along X, and its Z beside it.
    Returns (lines, each extruded length in order - the label's as one subtotal)."""
    y_bot = Y0 + i * PITCH
    out = [f";TAG {i + 1} Z{z:g}", f"G1 Z{z:.3f} F720 ; tag {i + 1}: nozzle {z:g} above the calibrated zero"]
    n_pass = max(2, int(TAG_D / p.width))
    out.append(f"G1 X{X0:.3f} Y{y_bot:.3f} F10800")
    lengths = []
    x_at = X0
    for k in range(n_pass):
        y = y_bot + k * (TAG_D / (n_pass - 1))
        if k:
            lines, d = extrude(p, x_at, y_bot + (k - 1) * (TAG_D / (n_pass - 1)), x_at, y)
            out += lines
            lengths.append(d)
        x_to = X0 + TAG_W if x_at == X0 else X0
        lines, d = extrude(p, x_at, y, x_to, y, 1200 if k == 0 else None)
        out += lines
        lengths.append(d)
        x_at = x_to
    # The tag's own Z, drawn to the LEFT of the pad. This replaces a row of i+1 tick dashes: both
    # identify the row, but a number is read at a glance where eleven dashes have to be counted,
    # and miscounting them puts Live Z out by one whole step of the ladder.
    lines, d = label(p, f"{z:.2f}", LABEL_X_END, y_bot + (TAG_D - 2.0 * p.seg) / 2)
    return out + lines, [*lengths, d]


def plate_gcode(p, nozzle_t, bed_t):
    """The whole plate: (lines, total extruded path)."""
    zs = p.zs
    g = [
        f"; Live adjust Z calibration tags - {p.nozzle:g} mm nozzle, {p.n_tags} tags",
        f"; Ladder Z {zs[0]:g}..{zs[-1]:g} step {p.z_step:g}; nominal first layer {p.layer_h:g}, width {p.width:g}",
        f"; Flow {p.e_per_mm:.5f} E/mm (bead {p.bead:.4f} mm2). One width throughout - no perimeter/infill mix.",
        "; READ IT LIKE THIS: find the tag that looks right, subtract the nominal first layer height",
        "; from its Z, and move Live adjust Z by MINUS that much. Each tag has its own Z printed beside",
        f"; it, so there is nothing to count; Z {zs[0]:g} is the FRONT row.",
        "; The ladder only ever sits ABOVE nominal, so nothing here can drive the nozzle into the sheet.",
        "M201 X1000 Y1000 Z200 E5000",
        "M203 X200 Y200 Z12 E120",
        "M204 S1250 T1250",
        "M205 X8.00 Y8.00 Z0.40 E4.50",
        "M205 S0 T0",
        'M862.3 P "MK3S" ; printer model check',
        f"M862.1 P{p.nozzle:g} ; nozzle diameter check - the printer REFUSES a mismatch",
        "G90",
        "M83",
        f"M104 S{nozzle_t} ; set extruder temp",
        f"M140 S{bed_t} ; set bed temp",
        f"M190 S{bed_t} ; wait for bed temp",
        f"M109 S{nozzle_t} ; wait for extruder temp",
        "G28 W ; home all without mesh bed level",
        "G80 ; mesh bed leveling",
        f"G1 Z{p.layer_h:.3f} F720",
        "G1 Y-3 F1000 ; go outside print area",
        "G92 E0",
        "G1 X60 E9 F1000 ; intro line",
        "G1 X100 E12.5 F1000 ; intro line",
        "G92 E0",
        "M221 S95",
        "G21",
        "G90",
        "M83",
        "M107",
    ]
    total_path = 0.0
    for i, z in enumerate(zs):
        lines, lengths = tag(p, i, z)
        g += lines
        for d in lengths:
            total_path += d
    g += [
        "G1 E-2 F2100 ; retract",
        f"G1 Z{zs[-1] + 10:.3f} F720",
        "M104 S0 ; turn off temperature",
        "M140 S0 ; turn off heatbed",
        "G1 X0 Y200 F6000 ; present print",
        "M107",
        "M84 ; disable motors",
    ]
    return g, total_path


def verify(p, written, total_path):
    """Check the file as written: the ladder, one home and one mesh, no offsets, the nozzle check, every
    extrusion against the path drawn, and every point on the bed. Returns (extrusions, points)."""
    zs = p.zs
    code = [s.split(";")[0].strip() for s in written]
    zcmds = [float(c.split("Z")[1].split()[0]) for c in code if c.startswith("G1 Z")]
    assert zcmds[0] == p.layer_h, "first Z move is not the nominal first layer"
    assert zcmds[1:1 + p.n_tags] == zs, f"ladder in file does not match: {zcmds[1:1 + p.n_tags]}"
    assert zcmds[-1] > zs[-1], "does not lift at the end"
    assert sum(1 for c in code if c.startswith("G28")) == 1, "expected exactly one G28"
    assert sum(1 for c in code if c.startswith("G80")) == 1, "expected exactly one G80"
    assert not any(c.startswith(("G29", "G30", "M851", "M290")) for c in code), "unexpected probing or offset"
    assert any(c == f"M862.1 P{p.nozzle:g}" for c in code), "nozzle check missing or wrong"
    # Parse E with a regex, never a split on "E": the intro lines read "G1 X60 E9 F1000", where E is
    # NOT last on the line, and splitting hands back "9 F1000". Restrict to the tag moves - the ones
    # carrying both X and Y, which are exactly what total_path accumulates. The two intro lines are
    # deliberate, are not part of that sum, and are checked separately below.
    _e = re.compile(r"\bE(-?[\d.]+)")
    tag_moves = [c for c in code if c.startswith("G1 X") and " Y" in c and _e.search(c)]
    es = [float(_e.search(c).group(1)) for c in tag_moves]
    assert es and all(e > 0 for e in es), "a non-positive extrusion was written"
    # The tolerance tracks the QUANTISATION rather than being a round number. E is written with five
    # decimals, so every move carries up to 5e-6 of rounding and N moves accumulate N x 5e-6. A flat
    # 1e-3 held at 275 extrusions and failed at 403 the moment labels were added - not because anything
    # was wrong, but because the bound had been picked by eye instead of derived from the write format.
    # A genuine fault (a dropped stroke, a mis-scaled glyph, a label drawn twice) is orders of magnitude
    # larger than this bound, so deriving it keeps the check strict at any tag count instead of turning
    # it into a threshold that gets relaxed whenever it complains.
    e_tol = len(es) * 5e-6 + 1e-9
    assert abs(sum(es) - total_path * p.e_per_mm) <= e_tol, \
        f"E total {sum(es):.5f} does not match path {total_path * p.e_per_mm:.5f} (tolerance {e_tol:.5f})"
    intro = [c for c in code if c.startswith("G1 X") and " Y" not in c and _e.search(c)]
    assert len(intro) == 2, f"expected exactly 2 intro-line extrusions, found {len(intro)}"
    # Bounds are checked on EVERY point, and the limits are inclusive. The first version of this guard
    # did two things wrong: it used a STRICT 0 < x, which rejects the legitimate X0 park position, and
    # it filtered out y <= 0 before testing - so a Y that ran off the front of the bed was discarded
    # rather than caught. A check that drops the only values capable of failing it cannot fail.
    # Y may legitimately reach -3: that is the front purge line, exactly as the reference set does it.
    _x = re.compile(r"\bX(-?[\d.]+)")
    _y = re.compile(r"\bY(-?[\d.]+)")
    pts = [(float(_x.search(c).group(1)), float(_y.search(c).group(1)))
           for c in code if c.startswith("G1 X") and _y.search(c)]
    assert pts, "no positioned moves found at all"
    off_x = [q for q in pts if not 0 <= q[0] <= BED_X]
    off_y = [q for q in pts if not -3 <= q[1] <= BED_Y]
    assert not off_x, f"an X move leaves the bed: {off_x[:3]}"
    assert not off_y, f"a Y move leaves the bed: {off_y[:3]}"
    return es, pts


def main(argv):
    out = Path(argv[1])
    nozzle = float(argv[2]) if len(argv) > 2 else 0.8
    layer_h = float(argv[3]) if len(argv) > 3 else 0.3
    width = float(argv[4]) if len(argv) > 4 else 0.85
    z_start = float(argv[5]) if len(argv) > 5 else 0.40
    z_step = float(argv[6]) if len(argv) > 6 else 0.05
    n_tags = int(argv[7]) if len(argv) > 7 else 11
    profile = "PETG Basic NPETG087-ZX @0.8 nozzle.ini" if nozzle == 0.8 else "PETG Basic NPETG087-ZX.ini"
    ini = Path(argv[8]) if len(argv) > 8 else PROFILES / profile
    cfg = read_temperatures(ini, T_KEYS)
    assert all(k in cfg for k in T_KEYS), f"{ini.name} lacks {[k for k in T_KEYS if k not in cfg]}"
    nozzle_t, bed_t = cfg["first_layer_temperature"], cfg["first_layer_bed_temperature"]
    print(f"temps from {ini.name}: nozzle {nozzle_t} C, bed {bed_t} C")

    assert 0.1 <= nozzle <= 1.2 and 0.05 <= layer_h <= 0.6, "implausible nozzle or layer height"
    assert width >= nozzle, "extrusion width below nozzle diameter"
    assert layer_h < width, "layer height must be under the extrusion width"
    assert 3 <= n_tags <= 30 and z_step > 0, "implausible ladder"
    assert z_start > layer_h, "ladder must start ABOVE nominal - never approach from below"
    p = Plate(nozzle, layer_h, width, z_start, z_step, n_tags)

    # Control: the same formula must reproduce the 0.4 reference, whose first layer is 0.2 at width
    # 0.42 and which measures 0.03168 E/mm. A flow formula that cannot predict a known-good file is
    # not evidence, it is arithmetic.
    ref = (0.2 * (0.42 - 0.2) + math.pi * 0.1 ** 2) / FIL_AREA
    assert abs(ref - 0.03168) / 0.03168 < 0.05, f"flow model does not match the reference: {ref:.5f}"
    assert p.zs == sorted(p.zs), "ladder not monotonic"

    g, total_path = plate_gcode(p, nozzle_t, bed_t)
    out.write_text("\n".join(g) + "\n", encoding="utf-8", newline="\n")

    # ---- verify what was written -----------------------------------------------------------------
    written = out.read_text(encoding="utf-8").split("\n")
    es, pts = verify(p, written, total_path)
    zs = p.zs
    print(f"wrote {out.name}: {n_tags} tags, Z {zs[0]:g}..{zs[-1]:g} step {z_step:g}")
    print(f"  nozzle {nozzle:g}, first layer {layer_h:g}, width {width:g} -> {p.e_per_mm:.5f} E/mm "
          f"(reference check {ref:.5f} vs measured 0.03168)")
    print(f"  footprint X {min(x for x, _ in pts):.1f}..{max(x for x, _ in pts):.1f}  "
          f"Y {min(y for _, y in pts):.1f}..{max(y for _, y in pts):.1f}")
    print(f"  {len(es)} extrusions, {total_path:.0f} mm of path, {sum(es):.2f} mm filament; "
          f"{len(written)} lines; all checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
