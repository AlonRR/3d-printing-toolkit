"""Generate find-top.gcode: locate the top of a part to 0.1 mm without calipers.

usage: make_find_top.py <steps> <touch_x> <touch_y> <out.gcode>

Why this exists. docs/mk3s-resume.md takes its COARSE Z reference from a caliper gap between the
nozzle tip and the part. On a real recovery that turned out to be physically impossible: the
extruder body and the caliper jaws foul each other, so the gap cannot be reached at all.

The obvious fallback - jog Z down on the LCD until the nozzle touches - is limited by LCD Move Z's
1 mm step, which brackets contact to 1 mm. That is far too coarse to hand to make_resume.py:

  * it approaches to wall_z + 0.4, so 1 mm of error in the dangerous direction drives the nozzle
    0.6 mm INTO the part;
  * Live adjust Z cannot absorb it either - it is the FINE control at 1/400 mm per detent, and a
    sheet already near the bottom of its range has well under 1 mm of downward room left.

So this walks Z down in 0.1 mm steps, one knob click each, with the nozzle hot enough to be clean.
The operator stops clicking at first contact, and Z is then known to 0.1 mm.

It takes the reference AT THE TOUCH POINT the resume will use, not wherever the head was parked
by hand. That matters when the bed has been off: the part's height varies across the bed, and a
reference taken somewhere else carries that tilt error into the coarse Z. Sequence:

  lift 10 mm (relative - safe from any position) -> G28 X Y (never moves Z, never probes)
  -> travel to the touch point -> drop 8 mm (leaving ~2 mm) -> 0.1 mm steps.

The lift and the drop are both relative, so the 2 mm of remaining margin is real regardless of
where the machine thinks it is.

PRECONDITION: the nozzle is just touching the part. Everything downward is measured from there.

AFTER contact: RESET the printer. A reset does NOT move Z - boot only clamps the COORDINATE to
Z_MIN_POS 0.15 - so the nozzle stays physically at the part top while the number becomes 0.15.
Jog up with LCD Move Z, read the new Z over PrusaLink, and the gap is that reading minus 0.15,
measured by the machine's own leadscrew instead of by eye.
"""
import sys
from pathlib import Path

steps = int(sys.argv[1])
tx, ty = float(sys.argv[2]), float(sys.argv[3])
out = Path(sys.argv[4])
assert 5 <= steps <= 200, "steps must be between 5 and 200"
assert 0 <= tx <= 250 and 0 <= ty <= 210, "touch point outside the MK3S bed"

STEP = 0.1
LIFT = 10.0          # relative, from contact - clears the part for the X/Y home
DROP = 8.0           # back down, leaving LIFT-DROP = 2 mm of margin for bed tilt
TOUCH_NOZZLE = 170   # as make_resume.py: clean tip, same thermal expansion as the real touch-off,
                     # so the two references agree. Too cold for PETG to ooze during the dwell.
assert LIFT - DROP > 0, "the drop must leave margin"
assert steps * STEP > (LIFT - DROP), "not enough fine travel to reach the part"

head = f"""; ==== FIND TOP at X{tx:g} Y{ty:g} - {steps} steps of {STEP:g} mm
; PRECONDITION: the nozzle is JUST TOUCHING a solid, flat part of the print. If it is not, press
; RESET now - every distance below is measured relative to that contact.
; No probing, no Z homing, no bed mesh. Z moves up first, and only ever down in {STEP:g} mm steps after.
; Click through the prompts. STOP CLICKING the moment the nozzle touches the top surface.
; Then RESET (that does not move Z) and read the position off PrusaLink.
M84 S0 ; no idle stepper release while hands are at the printer
G21
G90
M0 At contact? Click
G91
G1 Z{LIFT:g} F720 ; up and clear of the part, relative so it is safe from anywhere
G90
G28 X Y ; X and Y only - never moves Z, never probes
M117 Heating to clean
M104 S{TOUCH_NOZZLE}
M109 S{TOUCH_NOZZLE}
M0 Wipe nozzle, click
G1 X{tx:g} Y{ty:g} F6000 ; the exact point the resume touches off on
G91
G1 Z-{DROP:g} F300 ; back down, leaving {LIFT - DROP:g} mm of margin for bed tilt
M117 0.1mm to contact
M0 Stop at contact
"""
body = "".join(f"G1 Z-{STEP:g} F100\nM0 Click = down {STEP:g}mm\n" for _ in range(steps))
tail = """G90
M104 S0
M117 Travel used up
M0 No contact - stop
"""
out.write_text(head + body + tail, encoding="utf-8", newline="\n")

# --- verify what was written ---------------------------------------------------------------
W = out.read_text(encoding="utf-8").split("\n")
code = [s.split(";")[0].strip() for s in W]
assert not any(c.startswith(("G29", "G30", "G80")) for c in code), "probing command present"
assert [c for c in code if c.startswith("G28")] == ["G28 X Y"], "unexpected homing"
fine = [c for c in code if c == f"G1 Z-{STEP:g} F100"]
assert len(fine) == steps, f"expected {steps} fine steps, wrote {len(fine)}"
zmoves = [c for c in code if c.startswith("G1") and "Z" in c]
assert zmoves == [f"G1 Z{LIFT:g} F720", f"G1 Z-{DROP:g} F300"] + fine, f"unexpected Z sequence: {zmoves[:4]}"
assert not any("X" in c or "Y" in c for c in zmoves), "a Z move carries X or Y"
# the only X/Y travel must happen while the nozzle is lifted, i.e. after the lift and before the drop
xy = [i for i, c in enumerate(code) if c.startswith("G1") and ("X" in c or "Y" in c)]
assert len(xy) == 1, "expected exactly one X/Y travel"
assert code.index(f"G1 Z{LIFT:g} F720") < xy[0] < code.index(f"G1 Z-{DROP:g} F300"), "X/Y travel not while lifted"
assert code.index("G28 X Y") < xy[0], "travel before homing X/Y"
# Mode matters, not the count. Walk the file and check every move happened in the mode it was
# written for. The first version of this guard asserted "3 G90 and 3 G91", which is simply the
# wrong number - the file needs 3 and 2 - so it failed correct output. A count is a proxy; the
# property is that no move is ever interpreted in the wrong frame, and that is what this checks.
mode = None
seen = []
for c in code:
    if c == "G90":
        mode = "abs"
    elif c == "G91":
        mode = "rel"
    elif c.startswith("G1"):
        seen.append((c, mode))
assert seen[0] == (f"G1 Z{LIFT:g} F720", "rel"), f"lift not relative: {seen[0]}"
assert seen[1] == (f"G1 X{tx:g} Y{ty:g} F6000", "abs"), f"X/Y travel not absolute: {seen[1]}"
assert seen[2] == (f"G1 Z-{DROP:g} F300", "rel"), f"drop not relative: {seen[2]}"
assert all(m == "rel" for _, m in seen[3:]), "a fine 0.1 mm step is not in relative mode"
assert len(seen) == steps + 3, f"unexpected move count {len(seen)}"
assert mode == "abs", "file ends in relative mode"
for c in code:
    if c.startswith(("M0 ", "M117 ")):
        assert len(c.split(" ", 1)[1]) <= 20, f"LCD text over 20 characters: {c}"
assert len([c for c in code if c.startswith("M0 ")]) == steps + 4, "prompt count does not match steps"
print(f"wrote {out.name}: reference at X{tx:g} Y{ty:g}; lift {LIFT:g}, drop {DROP:g} "
      f"(margin {LIFT - DROP:g}), then {steps} x {STEP:g} mm = {steps * STEP:g} mm")
print(f"  {len(W)} lines, {out.stat().st_size} bytes; no probing, no Z homing, "
      f"X/Y travel only while lifted; all checks passed")
