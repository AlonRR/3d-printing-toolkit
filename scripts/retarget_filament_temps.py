# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""Retarget a sliced G-code's temperatures to a different filament profile, and prove it.

usage: retarget_filament_temps.py [--no-header] <filament.ini> <out_dir> <file.gcode> [more.gcode ...]

--no-header suppresses the four-line provenance header, so the output differs from its source on
temperature lines and NOTHING else. Use it whenever the result will be diffed against the pristine
original, or when "only the temperatures changed" has to be literally true rather than nearly true.
The header is good provenance for a file read later out of context, but it is still four added
lines, and on a calibration set that gets compared byte-for-byte those four lines are the entire
difference between a clean diff and a suspicious one.

Written for the Live adjust Z calibration set, which was sliced in Dec 2023 against "Generic PETG"
at 230/85 while the filament actually in the machine wants 240/70. Calibrating the first layer at
the wrong temperature calibrates the wrong thing: Live adjust Z is stored per sheet and the squish
you dial in depends on how the plastic flows at that temperature.

The target numbers are READ FROM THE PROFILE, never typed here, so the profile stays the one source
of truth and this cannot drift from it.

Three kinds of temperature command, and conflating them is how you corrupt a file:

  * FIRST-LAYER  - the first M104/M109 (nozzle) and first M140/M190 (bed) with S>0, emitted by the
                   start G-code. These take first_layer_temperature / first_layer_bed_temperature.
  * SUBSEQUENT   - any later command with S>0, emitted at the start of layer 2. Single-layer files
                   have none at all; the 3-layer file has both. Takes temperature / bed_temperature.
  * SHUTDOWN     - M104 S0 / M140 S0 at the end. MUST be left alone. A blanket regex over
                   temperatures rewrites these into a heater that never turns off.

The config comments at the end are updated too, because PrusaLink reads them for display and a file
whose metadata disagrees with its own commands is a trap for the next reader.
"""

import re
import sys
from pathlib import Path

from preset import read_temperatures

KEYS = ("first_layer_temperature", "temperature", "first_layer_bed_temperature", "bed_temperature")
NOZZLE_CMD = re.compile(r"^(M10[49]) S(\d+)")
BED_CMD = re.compile(r"^(M1[49]0) S(\d+)")
META = re.compile(r"^; (" + "|".join(KEYS) + r") = (\d+)")


def retarget(lines, cfg):
    """lines with every heating command and config comment set to the profile's values: (new lines, changes),
    each change (line number, old command, new command)."""
    noz1, noz, bed1, bed = (
        cfg["first_layer_temperature"],
        cfg["temperature"],
        cfg["first_layer_bed_temperature"],
        cfg["bed_temperature"],
    )
    out = []
    seen_noz = seen_bed = False
    changes = []
    for i, line in enumerate(lines):
        new = line
        m = NOZZLE_CMD.match(line)
        b = BED_CMD.match(line)
        g = META.match(line)
        if m and int(m.group(2)) > 0:  # S0 is shutdown - never touched
            want = noz1 if not seen_noz else noz
            seen_noz = True
            new = NOZZLE_CMD.sub(rf"\1 S{want}", line, count=1)
        elif b and int(b.group(2)) > 0:
            want = bed1 if not seen_bed else bed
            seen_bed = True
            new = BED_CMD.sub(rf"\1 S{want}", line, count=1)
        elif g:
            new = f"; {g.group(1)} = {cfg[g.group(1)]}" + line[g.end() :]
        if new != line:
            changes.append(
                (i + 1, line.split(";")[0].strip() or line.strip(), new.split(";")[0].strip() or new.strip())
            )
        out.append(new)
    return out, changes


def verify(lines, written, header, changes, cfg):
    """Check the file as written: the header and the original's lines, only temperature lines changed, every
    heating command one of the four targets, and every shutdown line where it was."""
    noz1, noz, bed1, bed = (
        cfg["first_layer_temperature"],
        cfg["temperature"],
        cfg["first_layer_bed_temperature"],
        cfg["bed_temperature"],
    )
    assert len(written) == len(lines) + len(header), "line count changed beyond the header"
    body = written[len(header) :]
    diff = [(i + 1, a, b_) for i, (a, b_) in enumerate(zip(lines, body, strict=False)) if a != b_]
    assert len(diff) == len(changes), "a line changed that was not recorded"
    for _, a, _ in diff:
        ok = NOZZLE_CMD.match(a) or BED_CMD.match(a) or META.match(a)
        assert ok, f"a NON-temperature line was modified: {a[:60]!r}"
    # every surviving command must now be one of the four targets, or an untouched shutdown
    for line in body:
        m, b = NOZZLE_CMD.match(line), BED_CMD.match(line)
        if m:
            assert int(m.group(2)) in (0, noz1, noz), f"stray nozzle temp: {line}"
        if b:
            assert int(b.group(2)) in (0, bed1, bed), f"stray bed temp: {line}"
    assert sum(1 for x in body if x.startswith("M104 S0")) == sum(1 for x in lines if x.startswith("M104 S0")), (
        "a shutdown line was altered"
    )
    assert sum(1 for x in body if x.startswith("M140 S0")) == sum(1 for x in lines if x.startswith("M140 S0")), (
        "a shutdown line was altered"
    )
    return body


def main(argv):
    # Flags are pulled out BEFORE positional parsing, so adding one can never shift the file arguments
    # out from under an existing call. An unknown flag is rejected rather than silently treated as a
    # path, which is how a typo becomes "no G-code files given" three lines later.
    flags = {a for a in argv[1:] if a.startswith("--")}
    args = [a for a in argv[1:] if not a.startswith("--")]
    assert flags <= {"--no-header"}, f"unknown flag(s): {sorted(flags - {'--no-header'})}"
    no_header = "--no-header" in flags

    ini = Path(args[0])
    out_dir = Path(args[1])
    sources = [Path(p) for p in args[2:]]
    assert sources, "no G-code files given"
    out_dir.mkdir(parents=True, exist_ok=True)

    # --- targets, read from the profile -----------------------------------------------------------
    cfg = read_temperatures(ini, KEYS)
    missing = [k for k in KEYS if k not in cfg]
    assert not missing, f"{ini.name} does not define {missing}"
    noz1, noz, bed1, bed = (
        cfg["first_layer_temperature"],
        cfg["temperature"],
        cfg["first_layer_bed_temperature"],
        cfg["bed_temperature"],
    )
    print(f"target profile: {ini.stem}")
    print(f"  nozzle  first layer {noz1}  then {noz}")
    print(f"  bed     first layer {bed1}  then {bed}")

    for src in sources:
        lines = src.read_text(encoding="utf-8").split("\n")
        out, changes = retarget(lines, cfg)
        # Empty under --no-header. Every check is written against len(header), so suppressing it
        # weakens nothing: the line-count assertion, the body slice and the diff all still hold.
        header = (
            []
            if no_header
            else [
                f"; Temperatures retargeted to {ini.stem} ({noz1}/{noz} nozzle, {bed1}/{bed} bed).",
                f"; Source: {src.name}, sliced against its own profile - geometry is UNCHANGED.",
                "; Only M104/M109/M140/M190 with S>0 and the matching config comments were rewritten;",
                "; the M104 S0 / M140 S0 shutdown lines are untouched.",
            ]
        )
        dst = out_dir / src.name
        dst.write_text("\n".join(header + out), encoding="utf-8", newline="\n")

        # --- verify what was written --------------------------------------------------------------
        body = verify(lines, dst.read_text(encoding="utf-8").split("\n"), header, changes, cfg)
        print(f"\n{src.name} -> {dst}")
        for ln, a, b_ in changes:
            print(f"   line {ln:>6}: {a:<28} ->  {b_}")
        print(f"   {len(changes)} lines changed, {len(body)} body lines identical otherwise; checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
