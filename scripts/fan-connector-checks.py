#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0
# /// script
# requires-python = ">=3.11"
# ///
"""The fan connector's fit checks, for 2, 3 and 4 pins, each with its positive controls:

  uv run scripts/fan-connector-checks.py            (OPENSCAD may name the nightly; exit 0 = all as they must be)

A check is one of the model's check_* parts, rendered to an STL: it must come out empty. A control renders the
same check with one value overridden, breaking one side of the fit, and must not: a check never seen to fail is
not known to work. Each control moves the male alone or the female alone - one that moved both could pass by not
looking. Run with Manifold, which an empty intersection leaves with no STL written.
"""
import os
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODEL = ROOT / "models" / "fan-connector" / "fan-connector.scad"
OPENSCAD = os.environ.get("OPENSCAD") or "C:/Program Files/OpenSCAD (Nightly)/openscad.exe"

CHECKS = ["check_pair", "check_pins", "check_square"]
CONTROLS = [
    ("check_pair", "m_key_w=rib_gap+0.4", "the male's key made wider than the gap between the ribs"),
    ("check_pair", "m_wall_y=-(y_ribs-0.2)", "the male's wall moved in onto the ribs' tips"),
    ("check_pair", "m_key_y=-(y_lip-0.2)", "the male's key moved in onto the female's lip"),
    ("check_pins", "core_d=0.5", "the male's core holes made narrower than the core"),
    # Literal values, the model's own with one changed: a -D that names the variable it sets comes out undefined.
    ("check_pins", "f_cav=[1.14,-0.2]", "the female's cavities' pin-side wall moved in onto the pin"),
    ("check_square", "f_cav=[0.5,-0.57]", "the female's cavities made narrower than a header's square pin"),
]


def volume(stl):
    b = stl.read_bytes()
    if b[:5] == b"solid" and b"facet" in b[:400]:
        pts = [tuple(map(float, line.split()[1:4])) for line in b.decode().splitlines() if line.strip().startswith("vertex")]
        tris = [pts[i:i + 3] for i in range(0, len(pts), 3)]
    else:
        n = struct.unpack("<I", b[80:84])[0]
        tris = [[struct.unpack("<3f", b[84 + 50 * i + 12 * k: 96 + 50 * i + 12 * k]) for k in (1, 2, 3)] for i in range(n)]
    v = 0.0
    for a, c, d in tris:
        v += (a[0] * (c[1] * d[2] - c[2] * d[1]) - a[1] * (c[0] * d[2] - c[2] * d[0]) + a[2] * (c[0] * d[1] - c[1] * d[0])) / 6
    return abs(v)


def run(part, pins, extra=None):
    """The check's volume in mm3: 0 when it came out empty. Raises on an OpenSCAD error or a failed assert."""
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "check.stl"
        args = [OPENSCAD, "--backend=manifold", "-o", str(out), "-D", f'part="{part}"', "-D", f"pins={pins}"]
        if extra:
            args += ["-D", extra]
        p = subprocess.run([*args, str(MODEL)], capture_output=True, text=True, check=False)
        log = p.stdout + p.stderr
        bad = [line for line in log.splitlines() if line.startswith("ERROR") or "Assertion" in line]
        if bad:
            raise RuntimeError("; ".join(bad)[:200])
        return volume(out) if out.exists() else 0.0


failed = total = 0
for pins in (2, 3, 4):
    for check in CHECKS:
        total += 1
        v = run(check, pins)
        ok = v < 1e-6
        failed += not ok
        print(f"{pins} pins  {check:14} {'ok    empty' if ok else f'FAIL  {v:.3f} mm3'}")
    for check, extra, what in CONTROLS:
        total += 1
        try:
            v = run(check, pins, extra)
            ok, note = v > 1e-3, f"{v:.3f} mm3"
        except RuntimeError as e:
            ok, note = False, f"tripped instead: {e}"
        failed += not ok
        print(f"{pins} pins  {check:14} {what:62} {'ok    caught, ' + note if ok else 'FAIL  passed unnoticed ' + note}")
print(f"{total - failed} of {total} as they must be")
sys.exit(1 if failed else 0)
