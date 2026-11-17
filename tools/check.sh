#!/bin/sh
# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0
#
# The checks a change passes before it is committed, in order; each stops the run on its own exit status. There is
# no CI, so this is run by hand (or by an agent) from the repository's root:  sh tools/check.sh [base]
# The base is the ref new lines and the coverage floor are compared with, gitea/main by default.
set -eu
base=${1:-gitea/main}
cd "$(git rev-parse --show-toplevel)"

uv run ruff check .
uv run ruff format --check .
# Tests, with branch coverage of every script they run; fails under [tool.coverage.report] fail_under.
uv run pytest -p no:cacheprovider --cov --cov-report=term --cov-report=xml --cov-report=json
# Every new or changed line under scripts/ is run by a test.
uv run diff-cover coverage.xml --compare-branch="$base" --fail-under=100
# The floor is not lower than the base's.
uv run python tools/coverage_ratchet.py guard --against "$base"
# No type error beyond those in .basedpyright/baseline.json.
uv run basedpyright
echo "check.sh: all passed. If coverage rose, raise the floor: uv run python tools/coverage_ratchet.py raise"
