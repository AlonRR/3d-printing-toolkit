# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""The PrusaLink scripts' own stub tests, which docs/mk3s-resume.md names, pass: each runs as a script and exits 0
when every one of its cases passed."""

import subprocess
import sys
from pathlib import Path

import pytest

MK3S = Path(__file__).resolve().parents[1] / "scripts" / "mk3s-resume"


@pytest.mark.parametrize("name", ["test_start_print.py", "test_upload_resume.py"])
def test_stub_script(name):
    p = subprocess.run([sys.executable, str(MK3S / name)], capture_output=True, text=True, timeout=300, check=False)
    assert p.returncode == 0, p.stdout + p.stderr
    last = p.stdout.strip().splitlines()[-1]
    n = last.split(" of ")[0]
    assert last == f"{n} of {n} cases passed"
