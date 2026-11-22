# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""make_resume.py on G-code lines that lack a value it reads. Each must stop with a message naming the line, never an
AttributeError from a regular expression that did not match."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts" / "mk3s-resume"))

import make_resume


@pytest.mark.parametrize(
    ("line", "missing"),
    [
        ("M900 L0", "K"),
        ("M104 R215", "S"),
        ("M109", "S"),
        ("M140", "S"),
        ("M190 R60", "S"),
    ],
)
def test_state_line_without_its_value_is_refused(line, missing):
    with pytest.raises(ValueError, match=rf"{line.split()[0]} without its {missing} value.*{line}"):
        make_resume.machine_state(["M107", line])


def test_state_lines_with_their_values_still_read():
    state = make_resume.machine_state(
        [
            "M107",
            "M900 K0.05",
            "M900 K30",
            "M205 S0 T0",
            "M205 X8 Y8 Z0.4 E4.5",
            *(f"{w} X1" for w in ("M201", "M203", "M204", "M221", "M907")),
            "M104 S215",
            "M140 S60",
        ]
    )
    assert state["hotend"] == "215" and state["bed"] == "60" and "M900 LA1.5" in state


def test_first_travel_with_x_or_y_alone_is_refused():
    lines = ["G1 E-0.8 F2100", "G1 Z0.6 F720", "G1 X10 F9000", "G1 E0.8", "G1 X12 Y5 E0.1"]
    with pytest.raises(ValueError, match=r"line 3 .*X and Y.*G1 X10 F9000"):
        make_resume.lead_in(lines, 0, len(lines), 0.6)


def test_first_travel_with_x_and_y_still_reads():
    lines = ["G1 E-0.8 F2100", "G1 Z0.6 F720", "G1 X10 Y4 F9000", "G1 E0.8", "G1 X12 Y5 E0.1"]
    assert make_resume.lead_in(lines, 0, len(lines), 0.6) == (2, 0.8, (10.0, 4.0))
