# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""Every script does what golden.json recorded: the same exit code, output, requests and files (cases.py).

A difference is either a bug or a deliberate change. For a deliberate one, re-make golden.json with
make_golden.py and say in the commit what changed and why.
"""

import json

import pytest
from cases import CASES, GOLDEN, run_case

WANT = json.loads(GOLDEN.read_text(encoding="utf-8"))


def test_every_case_has_a_golden_record():
    assert sorted(WANT) == sorted(c.name for c in CASES)


@pytest.mark.parametrize("case", CASES, ids=lambda c: c.name)
def test_script(case, tmp_path):
    assert run_case(case, tmp_path) == WANT[case.name]
