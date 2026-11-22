#!/bin/sh
# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0
#
# The checks a change passes before it is committed, in order; each stops the run on its own exit status. There is
# no CI, so this is run by hand (or by an agent) from the repository's root:  sh tools/check.sh [base]
# The base is the ref new lines and the coverage floor are compared with, gitea/main by default.
# --locked: the floor and the type baseline are figures about uv.lock, so a lock that no longer matches
# pyproject.toml fails here rather than being re-resolved (a bare uv run) or used stale (--frozen).
set -eu
base=${1:-gitea/main}
cd "$(git rev-parse --show-toplevel)"

# diff-cover reads git's diff, so a new .py file not yet added would never be judged.
untracked=$(git ls-files --others --exclude-standard -- '*.py')
if [ -n "$untracked" ]; then
    printf 'check.sh: git add (or ignore) these first, or diff-cover cannot see them:\n%s\n' "$untracked" >&2
    exit 1
fi
uv run --locked ruff check .
uv run --locked ruff format --check .
# Tests, with branch coverage of every script they run; fails under [tool.coverage.report] fail_under.
uv run --locked pytest -p no:cacheprovider --cov --cov-report=term --cov-report=xml --cov-report=json
# Every new or changed line under scripts/ is run by a test (judged on the report the line above just wrote).
uv run --locked diff-cover coverage.xml --compare-branch="$base" --fail-under=100
# The floor is not lower than the base's.
uv run --locked python tools/coverage_ratchet.py guard --against "$base"
# No type error beyond those in pyrefly-baseline.json. basedpyright, with .basedpyright/baseline.json, is kept as a
# weekly report outside the gate (a scheduled weekly job), since Pyrefly's baseline matches file, rule and column only.
uv run --locked pyrefly check --baseline=pyrefly-baseline.json
# Every third-party import is declared in pyproject.toml, and every declared dependency is imported.
uv run --locked deptry .
echo "check.sh: all passed. If coverage rose, raise the floor: uv run python tools/coverage_ratchet.py raise"
