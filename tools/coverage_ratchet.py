#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: CC-BY-4.0
#
# A copy of engineering-practices' skills/python-testing-practice/scripts/coverage_ratchet.py (13a2728),
# formatted to this repository's style. Fix it there first.
"""A coverage floor that only goes up: coverage.py's `fail_under`, ratcheted.

    coverage_ratchet.py raise [--coverage-json coverage.json] [--pyproject pyproject.toml]
    coverage_ratchet.py guard --against REF [--pyproject pyproject.toml]

raise  Reads the measured total from `coverage json` output and, if it is above the
       `[tool.coverage.report] fail_under` in pyproject.toml, moves the floor up to it, rounded
       down to the configured `precision` (0 decimals unless set). It never lowers the floor, and
       it changes no other byte of the file. Run it after a full, passing run, and commit the
       bump with the change that earned it.
guard  Fails (exit 1) if the floor in the working tree's pyproject.toml is lower than at REF, or
       missing where REF has one: the ratchet's other half, for a commit hook or CI, so the floor
       is never lowered quietly to let a change through.

Exit status: 0 done; 1 guard refused; 2 bad input (no total, unreadable file, unknown REF).
Standard library only (Python 3.11+ for tomllib).
"""

from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
import sys
import tomllib
from pathlib import Path

TABLE = "[tool.coverage.report]"


class BadInput(Exception):
    pass


def report_settings(text: str) -> dict:
    try:
        data = tomllib.loads(text)
    except tomllib.TOMLDecodeError as exc:
        raise BadInput(f"pyproject.toml does not parse: {exc}") from exc
    return data.get("tool", {}).get("coverage", {}).get("report", {})


def floor_to(value: float, digits: int) -> float | int:
    scale = 10**digits
    floored = math.floor(round(value * scale, 6)) / scale
    return int(floored) if digits == 0 else floored


def measured_total(path: Path) -> float:
    try:
        total = json.loads(path.read_text(encoding="utf-8"))["totals"]["percent_covered"]
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise BadInput(f"{path}: no totals.percent_covered ({exc})") from exc
    if not isinstance(total, (int, float)):
        raise BadInput(f"{path}: totals.percent_covered is not a number")
    return float(total)


def set_fail_under(text: str, value) -> str:
    """Return text with fail_under in [tool.coverage.report] set to value, nothing else changed."""
    newline = "\r\n" if "\r\n" in text else "\n"
    lines = text.splitlines(keepends=True)
    start = next((i for i, line in enumerate(lines) if line.strip() == TABLE), None)
    if start is None:
        sep = "" if not text or text.endswith(("\n", "\r\n")) else newline
        return f"{text}{sep}{newline if text.strip() else ''}{TABLE}{newline}fail_under = {value}{newline}"
    end = next((i for i in range(start + 1, len(lines)) if re.match(r"\s*\[", lines[i])), len(lines))
    for i in range(start + 1, end):
        match = re.match(r"(\s*fail_under\s*=\s*)([^#\r\n]*?)(\s*(#.*)?)(\r?\n)?$", lines[i])
        if match:
            lines[i] = f"{match.group(1)}{value}{match.group(3)}{match.group(5) or ''}"
            return "".join(lines)
    lines.insert(start + 1, f"fail_under = {value}{newline}")
    return "".join(lines)


def cmd_raise(args) -> int:
    text = ""
    if args.pyproject.exists():
        with open(args.pyproject, encoding="utf-8", newline="") as fh:  # keep CRLF as it is
            text = fh.read()
    settings = report_settings(text)
    total = measured_total(args.coverage_json)
    digits = int(settings.get("precision", 0))
    current = settings.get("fail_under")
    new = floor_to(total, digits)
    if current is not None and new <= float(current):
        print(f"fail_under stays {current} (measured {total:.2f})")
        return 0
    args.pyproject.write_text(set_fail_under(text, new), encoding="utf-8", newline="")
    print(f"fail_under {current if current is not None else 'unset'} -> {new} (measured {total:.2f})")
    return 0


def cmd_guard(args) -> int:
    rel = args.pyproject.resolve()
    top = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"], check=False, cwd=rel.parent, capture_output=True, text=True
    )
    if top.returncode != 0:
        raise BadInput(f"not in a git repository: {rel.parent}")
    path_in_repo = rel.relative_to(Path(top.stdout.strip()).resolve()).as_posix()
    old = subprocess.run(
        ["git", "show", f"{args.against}:{path_in_repo}"],
        check=False,
        cwd=rel.parent,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if old.returncode != 0:
        raise BadInput(f"cannot read {path_in_repo} at {args.against}: {old.stderr.strip()}")
    before = report_settings(old.stdout).get("fail_under")
    now = report_settings(args.pyproject.read_text(encoding="utf-8")).get("fail_under")
    if before is None:
        print(f"no floor at {args.against}; now {now}")
        return 0
    if now is None or float(now) < float(before):
        print(
            f"REFUSED: fail_under was {before} at {args.against}, is now "
            f"{'unset' if now is None else now}. The floor only goes up."
        )
        return 1
    print(f"fail_under {before} at {args.against}, {now} now: ok")
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("raise", help="move fail_under up to the measured total")
    r.add_argument("--coverage-json", type=Path, default=Path("coverage.json"))
    r.add_argument("--pyproject", type=Path, default=Path("pyproject.toml"))
    g = sub.add_parser("guard", help="refuse a floor lower than at REF")
    g.add_argument("--against", required=True)
    g.add_argument("--pyproject", type=Path, default=Path("pyproject.toml"))
    args = ap.parse_args(argv)
    try:
        return cmd_raise(args) if args.cmd == "raise" else cmd_guard(args)
    except BadInput as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
