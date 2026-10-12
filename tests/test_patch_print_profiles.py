# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""patch_print_profiles.py --apply patches every preset it should - a key inserted where one was absent included - and
leaves every other byte alone: each preset's other lines, in their order, and its own line endings."""

import re
import subprocess
import sys
from pathlib import Path

from cases import HOUSE, PRESETS, _presets

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "patch_print_profiles.py"
KV = re.compile(r"^([a-z_0-9]+) = (.*)$")
SKIP = {PRESETS[4]: {"fill_pattern"}}  # the lightning preset keeps its infill
EXTRA = {PRESETS[7]: {"complete_objects": "0", "wipe_tower": "1"}}


def keys(text):
    return {m.group(1): m.group(2) for m in (KV.match(x) for x in text.split("\n")) if m}


def test_apply_inserts_absent_keys_and_changes_nothing_else(tmp_path):
    _presets(tmp_path)
    before = {p.name: p.read_bytes() for p in (tmp_path / "print").iterdir()}
    run = subprocess.run(
        [sys.executable, str(SCRIPT), "--dir=print", "--apply"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
    )
    assert run.returncode == 0, run.stdout + run.stderr
    assert "APPLIED: " in run.stdout

    for name in PRESETS:
        path = tmp_path / "print" / f"{name}.ini"
        old, new = before[path.name], path.read_bytes()
        crlf = b"\r\n" in old
        text = new.decode("utf-8").replace("\r\n", "\n")
        want = {k: v for k, v in HOUSE.items() if k not in SKIP.get(name, set())} | EXTRA.get(name, {})
        targets = set(want)
        got = keys(text)
        assert {k: got.get(k) for k in want} == want, name
        # the other lines unchanged, in their order
        others = [
            x
            for x in old.decode("utf-8").replace("\r\n", "\n").split("\n")
            if not ((m := KV.match(x)) and m.group(1) in targets)
        ]
        kept = [x for x in text.split("\n") if not ((m := KV.match(x)) and m.group(1) in targets)]
        assert kept == others, name
        # the keys still in PrusaSlicer's sorted order, an inserted one too
        order = [m.group(1) for m in (KV.match(x) for x in text.split("\n")) if m]
        assert order == sorted(order), name
        # its own line endings, throughout
        assert new.count(b"\r\n") == (new.count(b"\n") if crlf else 0), name

    inserted = tmp_path / "print" / f"{PRESETS[0]}.ini"
    assert "avoid_crossing_perimeters_max_detour = 20" in inserted.read_text(encoding="utf-8")
    # backed up: the five presets that needed a change - 0 and 8 a key absent, 1 and 2 keys wrong, 7 its own extras
    backups = sorted(p.name.split(".ini.bak-")[0] for p in (tmp_path / "print").glob("*.ini.bak-*"))
    assert backups == sorted(PRESETS[i] for i in (0, 1, 2, 7, 8))
