# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""gcode_layers.py on G-code written for each rule: which moves count as extrusions, where a layer starts and
ends, and how far from a line a point may be. The sliced fixture never moves with E0, so the golden cases cannot
see the line between extruding and not; these can."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts" / "mk3s-resume"))

from gcode_layers import covered, extruded_segments, layer_range, layer_starts

LINES = """\
;LAYER_CHANGE
;Z:0.2
G1 X10 Y10 F6000
G1 X20 Y10 E1.5 ; extrudes
G1 X20 Y20 E0 ; travels with E0: not an extrusion
G1 X10 Y20 E-0.8 ; a wipe: not an extrusion
G1 E0.8 ; unretracts in place: no X or Y
G1 Z0.4 F720 ; Z only
G1 X10 Y30 E2 ; extrudes ; a comment with X99 in it
M107
;LAYER_CHANGE
;Z:0.4
G1 X0 Y0 E1
;LAYER_CHANGE
;Z:0.6
""".split("\n")


def test_layers_start_at_each_layer_change_and_are_found_by_z():
    starts, z_to_line = layer_starts(LINES)
    assert starts == [0, 10, 13]
    assert z_to_line == {0.2: 0, 0.4: 10, 0.6: 13}
    assert layer_range(starts, z_to_line, 0.2000001) == (0, 10)


def test_only_moves_that_extrude_in_x_or_y_count():
    starts, z_to_line = layer_starts(LINES)
    segs = extruded_segments(LINES, *layer_range(starts, z_to_line, 0.2))
    assert segs == [(10.0, 10.0, 20.0, 10.0), (10.0, 20.0, 10.0, 30.0)]


def test_a_move_from_an_unknown_position_does_not_count():
    assert extruded_segments(["G1 X5 Y5 E1", "G1 X6 Y5 E1"], 0, 2) == [(5.0, 5.0, 6.0, 5.0)]


def test_covered_within_the_tolerance_only():
    segs = [(0.0, 0.0, 10.0, 0.0)]
    assert covered(segs, 5, 0.29)
    assert not covered(segs, 5, 0.31)
    assert covered(segs, 10.2, 0.2)  # past the end, measured from the end point
    assert not covered(segs, 10.31, 0.0)
    assert covered([(1.0, 1.0, 1.0, 1.0)], 1.1, 1.1)  # a zero-length move is a point
