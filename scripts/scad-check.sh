#!/usr/bin/env sh
# Verify an OpenSCAD part end to end: render -> STL -> manifold -> slice, and
# cross-check the model's fdm_* values against the profile it was actually
# sliced with.
#
#   scad-check.sh MODEL.scad [PRINT_PROFILE] [FILAMENT_PROFILE]
#
# Two kinds of problem, and the distinction is the point:
#
#   BLOCK  the model asserts — the geometry is impossible or self-contradictory.
#          Also: empty/non-manifold/multi-part STL, a vase-mode profile, or the
#          model disagreeing with the profile it was sliced with.
#
#   WARN   the model echoes WARNING — it builds and prints, but something is
#          compromised (a wall under the perimeter floor, a notch into the case,
#          a stage landing mid-layer). A judgement call, so you get the STL too.
#
# Exit codes:  0 clean   1 will not build / must not print   2 builds, with warnings
#
# WHY THE CROSS-CHECK. The model carries fdm_layer_h / fdm_extrusion_w because
# its geometry depends on them -- staged layers land mid-layer if the layer
# height is wrong, and every wall threshold is a multiple of the bead width.
# Nothing otherwise stops the two drifting apart, and when they do the part
# still slices, still prints, and is quietly weaker than the numbers claim.
# That is the failure this script exists to catch.
set -eu

SCAD=${1:?usage: scad-check.sh MODEL.scad [PRINT_PROFILE] [FILAMENT_PROFILE]}
PRINT_PROFILE=${2:-0.2mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter}
FILAMENT=${3:-Inslogic ASA}
PRINTER=${PRINTER:-Original Prusa i3 MK3S & MK3S+}
DATADIR=${DATADIR:-$APPDATA/PrusaSlicer}

OPENSCAD=${OPENSCAD:-}
if [ -z "$OPENSCAD" ]; then
    if command -v openscad >/dev/null 2>&1; then OPENSCAD=openscad
    else OPENSCAD="/c/Program Files/OpenSCAD/openscad.exe"; fi
fi
PSLICER=${PSLICER:-/c/Program Files/Prusa3D/PrusaSlicer/prusa-slicer-console.exe}

STL="${SCAD%.scad}.stl"
GCODE="${SCAD%.scad}.gcode"
fail=0
note() { printf '  %s\n' "$1"; }
bad()  { printf '  !! %s\n' "$1"; fail=1; }

# --- 1. render, and let the asserts speak ----------------------------------
# Delete the STL FIRST. If the render fails, OpenSCAD leaves the previous one
# untouched, and every step after this would happily validate stale geometry
# and report PASS on a model that does not build.
echo "==> render"
rm -f "$STL"
out=$("$OPENSCAD" -o "$STL" "$SCAD" 2>&1) || true
printf '%s\n' "$out" | grep -E "^ECHO:" | grep -v '"WARNING' | sed 's/^ECHO: /  /' | tr -d '"'

# An assert means the geometry is IMPOSSIBLE — a feature would vanish, invert,
# or cut the part in two. There is no STL worth producing, so stop.
if printf '%s\n' "$out" | grep -qi "ERROR: Assertion"; then
    printf '%s\n' "$out" | grep -i "ERROR: Assertion" | sed 's/^/  !! /'
    echo
    echo "BLOCKED: the model says this configuration is impossible, not merely bad"
    exit 1
fi

# A WARNING means it builds but something is compromised. That is a judgement
# call for the operator, so it is surfaced loudly and the STL is still made.
nwarn=$(printf '%s\n' "$out" | grep -c '^ECHO: "WARNING' || true)
if [ "${nwarn:-0}" -gt 0 ]; then
    printf '%s\n' "$out" | grep '^ECHO: "WARNING' \
        | sed 's/^ECHO: "WARNING: /  ~~ /; s/"$//'
    warned=1
else
    warned=0
fi
# OpenSCAD's OWN warnings — a failed import is only a WARNING and still exits 0,
# so it has to be caught. Anchored to line start: the model's design warnings
# arrive as ECHO: "WARNING: ..." and must not be swept up here, or every
# judgement call becomes a hard failure.
if printf '%s\n' "$out" | grep -q "^WARNING:"; then
    printf '%s\n' "$out" | grep "^WARNING:" | sed 's/^/  !! /'
    fail=1
fi

[ -s "$STL" ] || { echo "FAILED: STL is empty"; exit 1; }

# --- 2. the STL itself, not the preview ------------------------------------
echo "==> STL"
info=$("$PSLICER" --info "$STL" 2>/dev/null || true)
printf '%s\n' "$info" | grep -E "size_|number_of_facets|number_of_parts|manifold" \
    | sed 's/^/  /'
printf '%s\n' "$info" | grep -q "manifold = yes" || bad "not manifold"
parts=$(printf '%s\n' "$info" | awk -F= '/number_of_parts/ {gsub(/ /,"",$2); print $2}')
[ "${parts:-1}" = "1" ] || bad "STL is $parts parts, expected 1"

# --- 3. slice ---------------------------------------------------------------
echo "==> slice  [$PRINT_PROFILE / $FILAMENT]"
"$PSLICER" --export-gcode --datadir "$DATADIR" \
    --printer-profile "$PRINTER" --print-profile "$PRINT_PROFILE" \
    --material-profile "$FILAMENT" -o "$GCODE" "$STL" >/dev/null 2>&1 \
    || { echo "  !! slicing failed"; exit 1; }

g() { grep -E "^; $1 = " "$GCODE" | head -1 | sed 's/.*= //'; }
lh=$(g layer_height); ew=$(g extrusion_width); sv=$(g spiral_vase)
pm=$(g perimeters);  sm=$(g support_material)
note "layer_height $lh   extrusion_width $ew   perimeters $pm"
note "$(grep -E '^; estimated printing time \(normal' "$GCODE" | sed 's/^; //')"
note "$(grep -E '^; total filament used \[g' "$GCODE" | sed 's/^; //')"

[ "$sv" = "0" ] || bad "spiral_vase = $sv -- this profile prints a single-wall shell"
[ "$sm" = "0" ] || note "support_material = $sm (house rule prefers 0)"

# --- 4. does the model agree with the profile it was sliced with? -----------
echo "==> model vs profile"
# Strip the COMMENT FIRST. These declarations carry a trailing "// = layer_height"
# explaining what they mirror, and a greedy .*= happily matches that one instead
# of the assignment -- which reads as a profile mismatch on a file that is fine.
# Search the model AND anything it includes. Parameters commonly live in a
# separate header file, and grepping only the main file made this check report
# "not declared" and pass — a silent degradation that sounds benign while the
# most valuable check in the script has quietly stopped running.
srcs() {
    echo "$SCAD"
    d=$(dirname "$SCAD")
    grep -oE '^[[:space:]]*include[[:space:]]*<[^>]+>' "$SCAD" 2>/dev/null \
        | sed 's/.*<//; s/>.*//' \
        | while read -r f; do [ -f "$d/$f" ] && echo "$d/$f"; done
}
m() {
    # shellcheck disable=SC2046
    grep -hE "^$1[[:space:]]*=" $(srcs) 2>/dev/null | head -1 \
        | sed 's|//.*||' | sed 's/.*=[[:space:]]*//; s/;.*//' | tr -d ' '
}
cmp_fact() {  # name, model value, gcode value
    if [ -z "$2" ]; then
        bad "$1 is not declared anywhere in the model or its includes -- the profile cross-check cannot run"
        return
    fi
    if [ "$2" = "$3" ]; then note "$1 $2 == profile $3"
    else bad "$1 $2 != profile $3 -- the model was designed for a different profile"; fi
}
cmp_fact fdm_layer_h     "$(m fdm_layer_h)"     "$lh"
cmp_fact fdm_extrusion_w "$(m fdm_extrusion_w)" "$ew"

echo
if [ "$fail" != "0" ]; then
    echo "PROBLEMS FOUND (see !! above)"
    exit 1
elif [ "$warned" != "0" ]; then
    echo "BUILDS WITH $nwarn WARNING(S) (see ~~ above)  $STL / $GCODE"
    echo "  These are judgement calls, not impossibilities. Read them, then decide."
    exit 2
else
    echo "PASS  $STL / $GCODE"
    exit 0
fi
