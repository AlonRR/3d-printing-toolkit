#!/usr/bin/env sh
# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0
# The README's pictures, each a full render: without --render a PNG export is OpenSCAD's preview, which fakes
# every cut and leaves wrong colours and broken ribs. "set" imports the STLs, so run scad-check.sh on the parts
# first. OPENSCAD may name the nightly; Manifold keeps each part's colour.
#
#   sh models/fan-connector/figures.sh
set -eu
cd "$(dirname "$0")"
N=${OPENSCAD:-"C:/Program Files/OpenSCAD (Nightly)/openscad.exe"}
fig() {  # name view pins camera
    out=$("$N" --backend=manifold --render --colorscheme=Tomorrow -o "$1.png" --imgsize=1400,1000 --viewall --autocenter \
        --camera="0,0,0,$4,0" -D "view=\"$2\"" -D "pins=$3" -D "cam=[$(echo "$4" | tr ',' ' ' | awk '{print $1", "$2", "$3}')]" \
        fan-connector-figures.scad 2>&1) || { printf '%s\n' "$out"; exit 1; }
    if printf '%s\n' "$out" | grep -E "ERROR|WARNING|failed"; then exit 1; fi
    echo "ok  $1.png"
}
fig fan-connector-pair pair 3 "55,0,25"
fig fan-connector-open open 3 "235,0,25"
fig fan-connector-set set 3 "50,0,20"
