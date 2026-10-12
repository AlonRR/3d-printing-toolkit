#!/bin/sh
# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0
#
# Remake the fixtures made by a tool: box.stl and ell.stl with OpenSCAD 2021.01, and box.gcode with PrusaSlicer
# from the house profiles scad-check uses, the box centred at X50 Y30 so its front wall is where probe_touch.py
# looks. Run from this folder. A new box.gcode changes what the scripts make from it - its first line carries the
# slicing date - so remake tests/golden.json after, from code known to be right (tests/make_golden.py).
set -eu
OPENSCAD=${OPENSCAD:-openscad}
PSLICER=${PSLICER:-/c/Program Files/Prusa3D/PrusaSlicer/prusa-slicer-console.exe}
"$OPENSCAD" -o box.stl box.scad
# LF, as git keeps it: OpenSCAD on Windows writes CRLF, and add_brim_ears.py's refusal names the file's size.
sed -i 's/\r$//' box.stl
"$OPENSCAD" --export-format binstl -o ell.stl ell.scad
"$PSLICER" --export-gcode --datadir "${DATADIR:-$APPDATA/PrusaSlicer}" \
    --printer-profile "Original Prusa i3 MK3S & MK3S+" \
    --print-profile "0.2mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter" \
    --material-profile "Inslogic ASA" --center 50,30 -o box.gcode box.stl
