# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""Write tests/golden.json: what every case in cases.py does, run against TOOLKIT_ROOT's scripts.

usage: uv run python tests/make_golden.py [--check] [case ...]

Make it from code known to be right, never from the code under change: extract a commit's scripts/ and slicer/
(git archive <sha> scripts slicer | tar -x -C <dir>) and set TOOLKIT_ROOT=<dir>. Name that commit in the commit
that changes golden.json. --check compares instead of writing, and lists every case that differs.
"""

import json
import sys
import tempfile

from cases import CASES, GOLDEN, run_case, toolkit_root


def main(argv):
    check = "--check" in argv
    names = [a for a in argv if not a.startswith("--")]
    unknown = sorted(set(names) - {c.name for c in CASES})
    if unknown:
        sys.exit(f"unknown case(s): {', '.join(unknown)}")
    golden = json.loads(GOLDEN.read_text(encoding="utf-8")) if GOLDEN.exists() else {}
    print(f"scripts from {toolkit_root()}")
    differ = []
    for case in CASES:
        if names and case.name not in names:
            continue
        with tempfile.TemporaryDirectory() as tmp:
            got = run_case(case, tmp)
        same = golden.get(case.name) == got
        differ += [] if same else [case.name]
        print(f"{'same' if same else 'DIFFERENT' if check else 'written'}  {case.name}  exit {got['exit']}")
        if not check:
            golden[case.name] = got
    if check:
        listed = f": {', '.join(differ)}" if differ else ""
        print(f"{len(differ)} of {len(names) or len(CASES)} case(s) differ{listed}")
        return 1 if differ else 0
    GOLDEN.write_text(json.dumps(golden, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
