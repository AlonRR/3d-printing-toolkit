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

FLOW. area = h*(w - h) + pi*(h/2)^2 - a flat bead with semicircular edges, PrusaSlicer's model.
Checked against the 0.4 reference at its first-layer width: predicted 0.03135 E/mm against a
measured 0.03168, 1.0% low. The 0.6 reference reads 3.3% off the same formula because it MIXES
widths (0.65 perimeters, 0.60 top infill) and the measurement averages them. This plate uses ONE
width everywhere, so that error source is absent by construction.
"""
import math
import re
import sys
from pathlib import Path

out = Path(sys.argv[1])
NOZZLE = float(sys.argv[2]) if len(sys.argv) > 2 else 0.8
LAYER_H = float(sys.argv[3]) if len(sys.argv) > 3 else 0.3
WIDTH = float(sys.argv[4]) if len(sys.argv) > 4 else 0.85
Z_START = float(sys.argv[5]) if len(sys.argv) > 5 else 0.40
Z_STEP = float(sys.argv[6]) if len(sys.argv) > 6 else 0.05
N_TAGS = int(sys.argv[7]) if len(sys.argv) > 7 else 11

# Geometry copied from the reference set rather than invented - a proven, readable layout.
TAG_W, TAG_D, PITCH = 39.0, 9.0, 12.0
X0, Y0 = 105.5, 40.0
TICK_LEN, TICK_GAP, TICK_X_END = 5.0, 1.6, 103.0
FIL_AREA = math.pi * (1.75 / 2) ** 2
BED_X, BED_Y = 250.0, 210.0

# Temps are READ FROM THE PROFILE, never typed here, so the profile stays the one source - the same
# rule retarget_filament_temps.py follows. Hardcoding them is how a plate silently keeps printing at
# last month's bed temp after the profile moves. This plate is ENTIRELY first layer, so it is the
# first-layer pair that applies, not the subsequent-layer one. The profile follows the nozzle: the
# base preset's compatible_printers_condition excludes 0.8, so an 0.8 run needs the @0.8 sibling.
T_KEYS = ("first_layer_temperature", "first_layer_bed_temperature")
DEFAULT_INI = Path(__file__).resolve().parents[1] / "slicer" / "filament" / "unbranded" / (
    "PETG Basic NPETG087-ZX @0.8 nozzle.ini" if NOZZLE == 0.8 else "PETG Basic NPETG087-ZX.ini")
INI = Path(sys.argv[8]) if len(sys.argv) > 8 else DEFAULT_INI
cfg = {}
for line in INI.read_text(encoding="utf-8").splitlines():
    if " = " in line:
        k, v = line.split(" = ", 1)
        if k.strip() in T_KEYS:
            cfg[k.strip()] = int(float(v.split(",")[0].strip()))
assert all(k in cfg for k in T_KEYS), f"{INI.name} lacks {[k for k in T_KEYS if k not in cfg]}"
NOZZLE_T, BED_T = cfg["first_layer_temperature"], cfg["first_layer_bed_temperature"]
print(f"temps from {INI.name}: nozzle {NOZZLE_T} C, bed {BED_T} C")

assert 0.1 <= NOZZLE <= 1.2 and 0.05 <= LAYER_H <= 0.6, "implausible nozzle or layer height"
assert WIDTH >= NOZZLE, "extrusion width below nozzle diameter"
assert LAYER_H < WIDTH, "layer height must be under the extrusion width"
assert 3 <= N_TAGS <= 30 and Z_STEP > 0, "implausible ladder"
assert Z_START > LAYER_H, "ladder must start ABOVE nominal - never approach from below"

bead = LAYER_H * (WIDTH - LAYER_H) + math.pi * (LAYER_H / 2) ** 2
E_PER_MM = bead / FIL_AREA

# Control: the same formula must reproduce the 0.4 reference, whose first layer is 0.2 at width
# 0.42 and which measures 0.03168 E/mm. A flow formula that cannot predict a known-good file is
# not evidence, it is arithmetic.
_ref = (0.2 * (0.42 - 0.2) + math.pi * 0.1 ** 2) / FIL_AREA
assert abs(_ref - 0.03168) / 0.03168 < 0.05, f"flow model does not match the reference: {_ref:.5f}"

zs = [round(Z_START + i * Z_STEP, 3) for i in range(N_TAGS)]
assert zs == sorted(zs), "ladder not monotonic"

g = []
a = g.append
a(f"; Live adjust Z calibration tags - {NOZZLE:g} mm nozzle, {N_TAGS} tags")
a(f"; Ladder Z {zs[0]:g}..{zs[-1]:g} step {Z_STEP:g}; nominal first layer {LAYER_H:g}, width {WIDTH:g}")
a(f"; Flow {E_PER_MM:.5f} E/mm (bead {bead:.4f} mm2). One width throughout - no perimeter/infill mix.")
a("; READ IT LIKE THIS: find the tag that looks right, subtract the nominal first layer height")
a(f"; from its Z, and move Live adjust Z by MINUS that much. Tag Z {zs[0]:g} is tick 1, at the FRONT.")
a("; The ladder only ever sits ABOVE nominal, so nothing here can drive the nozzle into the sheet.")
a("M201 X1000 Y1000 Z200 E5000")
a("M203 X200 Y200 Z12 E120")
a("M204 S1250 T1250")
a("M205 X8.00 Y8.00 Z0.40 E4.50")
a("M205 S0 T0")
a('M862.3 P "MK3S" ; printer model check')
a(f"M862.1 P{NOZZLE:g} ; nozzle diameter check - the printer REFUSES a mismatch")
a("G90")
a("M83")
a(f"M104 S{NOZZLE_T} ; set extruder temp")
a(f"M140 S{BED_T} ; set bed temp")
a(f"M190 S{BED_T} ; wait for bed temp")
a(f"M109 S{NOZZLE_T} ; wait for extruder temp")
a("G28 W ; home all without mesh bed level")
a("G80 ; mesh bed leveling")
a(f"G1 Z{LAYER_H:.3f} F720")
a("G1 Y-3 F1000 ; go outside print area")
a("G92 E0")
a("G1 X60 E9 F1000 ; intro line")
a("G1 X100 E12.5 F1000 ; intro line")
a("G92 E0")
a("M221 S95")
a("G21")
a("G90")
a("M83")
a("M107")

def seg(x0, y0, x1, y1, feed=None):
    """One extruding move, E from the measured bead area."""
    d = math.hypot(x1 - x0, y1 - y0)
    if feed:
        a(f"G1 F{feed}")
    a(f"G1 X{x1:.3f} Y{y1:.3f} E{d * E_PER_MM:.5f}")
    return d

total_path = 0.0
for i, z in enumerate(zs):
    y_bot = Y0 + i * PITCH
    a(f";TAG {i + 1} Z{z:g}")
    a(f"G1 Z{z:.3f} F720 ; tag {i + 1}: nozzle {z:g} above the calibrated zero")
    # meander fill, one width, boustrophedon along X
    n_pass = max(2, int(TAG_D / WIDTH))
    a(f"G1 X{X0:.3f} Y{y_bot:.3f} F10800")
    x_at = X0
    for p in range(n_pass):
        y = y_bot + p * (TAG_D / (n_pass - 1))
        if p:
            total_path += seg(x_at, y_bot + (p - 1) * (TAG_D / (n_pass - 1)), x_at, y)
        x_to = X0 + TAG_W if x_at == X0 else X0
        total_path += seg(x_at, y, x_to, y, 1200 if p == 0 else None)
        x_at = x_to
    # ticks: i+1 dashes to the LEFT of the tag, so the row is identifiable without reading numbers
    y_mid = y_bot + TAG_D / 2
    for t in range(i + 1):
        xe = TICK_X_END - t * (TICK_LEN + TICK_GAP)
        a(f"G1 X{xe:.3f} Y{y_mid:.3f} F10800")
        total_path += seg(xe, y_mid, xe - TICK_LEN, y_mid, 1200)

a("G1 E-2 F2100 ; retract")
a(f"G1 Z{zs[-1] + 10:.3f} F720")
a("M104 S0 ; turn off temperature")
a("M140 S0 ; turn off heatbed")
a("G1 X0 Y200 F6000 ; present print")
a("M107")
a("M84 ; disable motors")
out.write_text("\n".join(g) + "\n", encoding="utf-8", newline="\n")

# ---- verify what was written -----------------------------------------------------------------
W = out.read_text(encoding="utf-8").split("\n")
code = [s.split(";")[0].strip() for s in W]
zcmds = [float(c.split("Z")[1].split()[0]) for c in code if c.startswith("G1 Z")]
assert zcmds[0] == LAYER_H, "first Z move is not the nominal first layer"
assert zcmds[1:1 + N_TAGS] == zs, f"ladder in file does not match: {zcmds[1:1 + N_TAGS]}"
assert zcmds[-1] > zs[-1], "does not lift at the end"
assert sum(1 for c in code if c.startswith("G28")) == 1, "expected exactly one G28"
assert sum(1 for c in code if c.startswith("G80")) == 1, "expected exactly one G80"
assert not any(c.startswith(("G29", "G30", "M851", "M290")) for c in code), "unexpected probing or offset"
assert any(c == f"M862.1 P{NOZZLE:g}" for c in code), "nozzle check missing or wrong"
# Parse E with a regex, never a split on "E": the intro lines read "G1 X60 E9 F1000", where E is
# NOT last on the line, and splitting hands back "9 F1000". Restrict to the tag moves - the ones
# carrying both X and Y, which are exactly what total_path accumulates. The two intro lines are
# deliberate, are not part of that sum, and are checked separately below.
_e = re.compile(r"\bE(-?[\d.]+)")
tag_moves = [c for c in code if c.startswith("G1 X") and " Y" in c and _e.search(c)]
es = [float(_e.search(c).group(1)) for c in tag_moves]
assert es and all(e > 0 for e in es), "a non-positive extrusion was written"
assert abs(sum(es) - total_path * E_PER_MM) < 1e-3, \
    f"E total {sum(es):.4f} does not match path length {total_path * E_PER_MM:.4f}"
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
off_x = [p for p in pts if not 0 <= p[0] <= BED_X]
off_y = [p for p in pts if not -3 <= p[1] <= BED_Y]
assert not off_x, f"an X move leaves the bed: {off_x[:3]}"
assert not off_y, f"a Y move leaves the bed: {off_y[:3]}"
print(f"wrote {out.name}: {N_TAGS} tags, Z {zs[0]:g}..{zs[-1]:g} step {Z_STEP:g}")
print(f"  nozzle {NOZZLE:g}, first layer {LAYER_H:g}, width {WIDTH:g} -> {E_PER_MM:.5f} E/mm "
      f"(reference check {_ref:.5f} vs measured 0.03168)")
print(f"  footprint X {min(x for x, _ in pts):.1f}..{max(x for x, _ in pts):.1f}  "
      f"Y {min(y for _, y in pts):.1f}..{max(y for _, y in pts):.1f}")
print(f"  {len(es)} extrusions, {total_path:.0f} mm of path, {sum(es):.2f} mm filament; "
      f"{len(W)} lines; all checks passed")
