# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""Build a resume file for a MK3S print stopped mid-print, part still on the bed.

usage: make_resume.py <original.gcode> <wall_z> <top_z> <live_z> <gap_mm> <out.gcode>
  wall_z  layer Z of the left wall's top (calipers, snapped to the 0.2 mm layer grid)
  top_z   highest layer present anywhere on the part (usually == wall_z)
  live_z  the active steel sheet's Live adjust Z value as shown on the LCD, e.g. -1.535
  gap_mm  caliper gap between the nozzle tip and the left wall's top directly below it,
          measured AFTER the last Z move; nothing may move Z between that and the job

Why this sequence (Prusa-Firmware v3.14.1 source, read not recalled):
  * After a reset nothing knows Z: boot clamps it to 0.15, a thermal stop has lifted 10 mm and
    parked, and stalling the carriage at the top is not a reference either (the firmware's own
    Z calibration sets Z "a bit higher than it is" after that stall). So the COARSE reference
    is the measured gap.
  * FINE reference is a paper touch-off with Live adjust Z: 1 knob detent = 1 count = 1/400 mm,
    no acceleration, so it must start within a few tenths of a mm. Its menu is hidden while
    logical Z >= 2.0 mm (babystep_allowed_strict), hence `G92 Z1`. Leaving that menu writes the
    sheet offset to EEPROM, hence `M850 Z<live_z>` afterwards.
  * G28 with only X/Y never moves Z and never probes. M0 without P/S waits for the knob.
  * Idle release (60 s) disables X/Y/Z; `M84 S0` stops that while hands are at the printer.
"""

import os
import re
import sys
from pathlib import Path

from gcode_layers import covered, extruded_segments, layer_range, layer_starts

APPROACH = 0.4  # nominal gap above the wall before the touch-off
HOMING_CLEARANCE = 8.0  # nozzle at least this far above the part top while homing X/Y
PAPER = 0.1  # thickness of the paper used for the touch-off
# Where to touch off: a point that is solid, flat and present in the layers either side. Pick it
# from the G-code, not by eye. Default is this part's left-wall inner band (X18.952 + X19.359),
# mid-length; override as X,Y in RESUME_TOUCH_XY. The script refuses a point with no extrusion under it.
DEFAULT_TOUCH_XY = "19.156,105.5"
TOUCH_NOZZLE = 170  # hot enough to be clean, too cold for PETG to ooze during the dwell
DWELL_S = 420
PRIME_MM = 8.0
STATE_KEYS = ("fan", "M900 LA1.5", "M900 LA1.0", "M205 ST", "M205 XYZE", "M201", "M203", "M204",
              "M221", "M907", "hotend", "bed")


def lead_in(lines, start, nxt, resume_z):
    """The resume layer's lead-in - wipe and retract, then the Z move onto the layer - as (splice, retract,
    first_xy): the line the original resumes from, the retraction to undo, and the first point it travels to."""
    zmove = next(i for i in range(start, nxt) if re.fullmatch(rf"G1 Z{resume_z:g} F\d+", lines[i].strip()))
    retract = -sum(float(m.group(1)) for i in range(start, zmove)
                   for m in [re.search(r"\bE(-[\d.]+)", lines[i].split(";")[0])] if m)
    assert 0.5 <= retract <= 2.0, f"unexpected lead-in retract {retract}"
    splice = zmove + 1
    first_xy = first_unretract = None
    for i in range(splice, nxt):
        c = lines[i].split(";")[0].strip()
        if not c.startswith("G1"):
            continue
        has_xy = re.search(r"\b[XY]-?[\d.]", c)
        e = re.search(r"\bE(-?[\d.]+)", c)
        assert not re.search(r"\bZ", c), f"Z move before first extrusion at line {i + 1}"
        if has_xy and first_xy is None:
            first_xy = (float(re.search(r"X(-?[\d.]+)", c).group(1)), float(re.search(r"Y(-?[\d.]+)", c).group(1)))
        if e and not has_xy and float(e.group(1)) > 0 and first_unretract is None:
            first_unretract = float(e.group(1))
        if e and has_xy and float(e.group(1)) > 0:
            break
    assert first_xy, "no XY travel in the resume layer"
    assert first_unretract is not None and abs(first_unretract - retract) < 1e-3, "E state would not match"
    return splice, retract, first_xy


def machine_state(lines):
    """The machine state in force at the end of lines: fan, acceleration and jerk limits, flow, motor current,
    Linear Advance for both firmware versions, and the hotend and bed targets."""
    state = {}
    for s in lines:
        c = s.split(";")[0].strip()
        if not c:
            continue
        w = c.split()[0]
        if w in ("M106", "M107"):
            state["fan"] = c
        elif w == "M900":
            state["M900 LA1.5" if float(re.search(r"K([\d.]+)", c).group(1)) < 10 else "M900 LA1.0"] = c
        elif w == "M205":
            state["M205 ST" if re.search(r"\bS", c) else "M205 XYZE"] = c
        elif w in ("M201", "M203", "M204", "M221", "M907"):
            state[w] = c
        elif w in ("M104", "M109"):
            state["hotend"] = re.search(r"S(\d+)", c).group(1)
        elif w in ("M140", "M190"):
            state["bed"] = re.search(r"S(\d+)", c).group(1)
    for k in STATE_KEYS:
        assert k in state, f"state {k} not found"
    return state


def header(name, *, wall_z, top_z, live_z, gap, resume_z, start, splice, z, touch, state, retract, first_xy):
    """The resume's header: coarse reference, homing, the touch-off, the restored state, and the move onto the
    resume layer. z holds the reference heights: ref, safe, approach, exact, clear."""
    ref_z, safe_z, approach_z, exact_z, clear_z = z
    tx, ty = touch
    hot, bed = state["hotend"], state["bed"]
    return f"""; ==== RESUME of {name}
; part top at layer Z {top_z:g}, touch-off wall at Z {wall_z:g}; resumes at layer Z {resume_z:g}
; (original line {start + 1}; original G-code is unmodified from line {splice + 1}).
; Needs someone AT the printer: three M0 prompts and one Live adjust Z touch-off.
; PRECONDITION: the nozzle tip was measured {gap:g} mm above the touch point below, and nothing has
; moved Z since. Otherwise press RESET now.
G21
G90
M83
M84 S0 ; no idle stepper release while hands are at the printer
M0 Gap measured? Click
G92 Z{ref_z:g} E0 ; COARSE: nozzle measured {gap:g} mm above the wall top at layer {wall_z:g}
G1 Z{safe_z:g} F720 ; clear of the part before homing X/Y
G28 X Y ; X and Y only - no Z move, no probing
M117 Heating, touch-off
M140 S{bed}
M104 S{TOUCH_NOZZLE}
M190 S{bed}
M109 S{TOUCH_NOZZLE}
G1 X{tx:g} Y{ty:g} F6000 ; over the touch point
G1 Z{approach_z:g} F300 ; nominally {APPROACH:g} mm above the wall top
G92 Z1 ; temporary low Z: Live adjust Z is hidden at Z >= 2 mm
M117 Live adjust Z: paper
G4 S{DWELL_S}
M0 Paper grips? Click
G92 Z{exact_z:g} ; EXACT: nozzle is one paper ({PAPER:g} mm) above the wall top at layer {wall_z:g}
M850 Z{live_z:.3f} ; restore the sheet's Live adjust Z, which the touch-off overwrote
G1 Z{clear_z:g} F720
G28 X Y ; back to the corner, off the part
M117 Heating to print
M104 S{hot}
M109 S{hot}
G1 E{PRIME_MM:g} F150 ; prime into the air at the corner
G1 E-{retract:g} F2100
M0 Remove strand, click
G92 E0
{state['M201']}
{state['M203']}
{state['M204']}
{state['M205 XYZE']}
{state['M205 ST']}
{state['M221']}
{state['M907']}
{state['M900 LA1.5']}
{state['M900 LA1.0']}
{state['fan']}
M117 Printing from Z {resume_z:g}
G1 X{first_xy[0]:g} Y{first_xy[1]:g} F10800
G1 Z{resume_z:g} F720 ; onto the resume layer
; ==== original G-code from line {splice + 1}
"""


def verify(written, head, footer, body, *, z, top_z, resume_z, live_z, hot):
    """Check the file as written: the original tail byte-identical, no probing, only the two X/Y homes, LCD text
    that fits, every Z command in the header and in its order, and nothing below the resume layer."""
    ref_z, safe_z, approach_z, exact_z, clear_z = z
    hl = head.count("\n")
    fl = footer.count("\n")
    assert written[hl:len(written) - fl] == body, "spliced body is not byte-identical to the original tail"
    code = [s.split(";")[0].strip() for s in written]
    h = code[:hl]
    assert [c for c in code if c.startswith("G28")] == ["G28 X Y", "G28 X Y"], "unexpected homing"
    assert not any(re.match(r"G(80|29|30)(\s|$)", c) for c in code), "probing command present"
    for c in h:
        if c.startswith(("M0 ", "M117 ")):
            assert len(c.split(" ", 1)[1]) <= 20, f"LCD text over 20 characters: {c}"
    zcmds = [c for c in h if re.match(r"G(0|1|92)(\s|$)", c) and re.search(r"\bZ-?[\d.]", c)]
    assert zcmds == [f"G92 Z{ref_z:g} E0", f"G1 Z{safe_z:g} F720", f"G1 Z{approach_z:g} F300", "G92 Z1",
                     f"G92 Z{exact_z:g}", f"G1 Z{clear_z:g} F720", f"G1 Z{resume_z:g} F720"], zcmds
    order = ["M84 S0", "M0 Gap measured? Click", f"G92 Z{ref_z:g} E0", f"G1 Z{safe_z:g} F720", "G28 X Y",
             f"M109 S{TOUCH_NOZZLE}", f"G1 Z{approach_z:g} F300", "G92 Z1", f"G4 S{DWELL_S}",
             "M0 Paper grips? Click", f"G92 Z{exact_z:g}", f"M850 Z{live_z:.3f}", f"G1 Z{clear_z:g} F720",
             f"M109 S{hot}", "M0 Remove strand, click", f"G1 Z{resume_z:g} F720"]
    idx = [h.index(c) for c in order]
    assert idx == sorted(idx), f"header order wrong: {list(zip(order, idx, strict=True))}"
    second_home = len(h) - 1 - h[::-1].index("G28 X Y")
    assert h.index(f"G1 Z{clear_z:g} F720") < second_home < h.index(f"M109 S{hot}"), "second XY home misplaced"
    assert not any(c.startswith("G1") for c in h[:h.index(f"G92 Z{ref_z:g} E0")]), "move before the coarse G92"
    assert safe_z >= top_z + HOMING_CLEARANCE and exact_z < approach_z < clear_z < safe_z + 1e-9
    body_z = [float(m.group(1)) for c in code[hl:] for m in [re.match(r"G1 Z(-?[\d.]+)", c)] if m]
    assert min(body_z) >= resume_z - 1e-6, "body goes below the resume layer"
    return hl


def main(argv):
    src, out = Path(argv[1]), Path(argv[6])
    wall_z, top_z, live_z, gap = (float(a) for a in argv[2:6])
    assert top_z >= wall_z, "top_z must be >= wall_z"
    assert -9.99 <= live_z <= 0, "Live adjust Z is between -9.99 and 0"
    assert 1.0 <= gap <= 150, "gap must be a caliper reading between 1 and 150 mm"
    touch = tuple(float(v) for v in os.environ.get("RESUME_TOUCH_XY", DEFAULT_TOUCH_XY).split(","))

    lines = src.read_text(encoding="utf-8").split("\n")
    starts, z_to_line = layer_starts(lines)
    resume_z = round(top_z + 0.2, 3)
    for zz in (wall_z, top_z, resume_z):
        assert round(zz, 3) in z_to_line, f"no layer at Z {zz}"

    # --- the touch point must sit on extruded lines in the wall layer and the one below ---------
    for zz in (wall_z, round(wall_z - 0.2, 3)):
        segs = extruded_segments(lines, *layer_range(starts, z_to_line, zz))
        assert covered(segs, *touch), f"touch point not on an extrusion in layer {zz}"

    # --- the resume layer's lead-in, and the machine state in force when it starts ---------------
    start, nxt = layer_range(starts, z_to_line, resume_z)
    splice, retract, first_xy = lead_in(lines, start, nxt, resume_z)
    state = machine_state(lines[:start])

    ref_z = round(wall_z + gap, 3)
    z = (ref_z, round(max(ref_z, top_z + HOMING_CLEARANCE), 3), round(wall_z + APPROACH, 3),
         round(wall_z + PAPER, 3), round(top_z + 5, 3))
    head = header(src.name, wall_z=wall_z, top_z=top_z, live_z=live_z, gap=gap, resume_z=resume_z, start=start,
                  splice=splice, z=z, touch=touch, state=state, retract=retract, first_xy=first_xy)
    footer = "\nM84 S60 ; restore the default idle stepper release\n"
    body = lines[splice:]
    out.write_text(head + "\n".join(body) + footer, encoding="utf-8", newline="\n")

    # --- verify what was written -----------------------------------------------------------------
    written = out.read_text(encoding="utf-8").split("\n")
    hl = verify(written, head, footer, body, z=z, top_z=top_z, resume_z=resume_z, live_z=live_z,
                hot=state["hotend"])
    ref_z, safe_z, approach_z, exact_z, _ = z
    tx, ty = touch
    print(f"wall {wall_z:g} / top {top_z:g} -> resume {resume_z:g} (orig line {start + 1}, splice {splice + 1})")
    print(f"touch X{tx:g} Y{ty:g} on extrusions in layers {wall_z:g} and {wall_z - 0.2:g}; retract {retract:g}")
    print(f"G92 coarse Z{ref_z:g} (gap {gap:g}) -> safe Z{safe_z:g} -> approach Z{approach_z:g} -> "
          f"exact Z{exact_z:g}; restore live Z {live_z:.3f}")
    print(f"wrote {out.name}: {len(written)} lines, {out.stat().st_size} bytes; header {hl} lines; all checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
