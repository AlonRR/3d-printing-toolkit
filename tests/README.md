# Tests

```sh
uv run pytest
sh tools/check.sh      # before every commit: the whole gate, below
```

## The gate

[`tools/check.sh`](../tools/check.sh) runs these in order, and stops at the first that fails:

- ruff's lint and format checks;
- the tests, with branch coverage of every script they run, child processes included. A run under
  `fail_under` in `pyproject.toml` fails. The floor started at the measured 94 % and only rises: after a
  passing run that measured more, `uv run python tools/coverage_ratchet.py raise` moves it up, and the
  bump goes in the commit that earned it;
- `diff-cover`: every new or changed line under `scripts/` since `gitea/main` is run by a test;
- the ratchet's guard: the floor is not lower than on `gitea/main`;
- basedpyright in standard mode: no type error beyond those in `.basedpyright/baseline.json`. Rewrite the
  baseline (`uv run basedpyright --writebaseline`) only to drop errors that were fixed.

How and why each gate works: the `python-testing-practice` skill in engineering-practices, where
`tools/coverage_ratchet.py` comes from.

- **[`test_golden.py`](test_golden.py):** every script under `scripts/` runs on fixed inputs and must do exactly
  what [`golden.json`](golden.json) recorded. That covers its exit code, its output, the last line of any error,
  the requests a stub PrusaLink received with their safety headers, and each file it wrote, by size and hash.
  [`cases.py`](cases.py) holds the cases. They cover each script's normal run, its other options, and the inputs
  it refuses.
- **[`test_stub_scripts.py`](test_stub_scripts.py):** the stub tests in `scripts/mk3s-resume/` pass.
- **[`test_add_brim_ears.py`](test_add_brim_ears.py):** `add_brim_ears.py` refuses a text STL from the file's
  size, without first asking for the bytes its header seems to claim (about 27 GB for the box fixture).
- **[`test_gcode_layers.py`](test_gcode_layers.py):** `gcode_layers.py` on G-code written for each rule.

Nothing here touches PrusaSlicer's own folders or a printer:
- `flatten_profiles.py` runs on a copy of the tree, with a home folder made of fixtures.
- `patch_print_profiles.py` runs on presets written for each case.
- The PrusaLink scripts talk to a stub server on 127.0.0.1.

## When a script changes on purpose

A changed record is either a bug or a deliberate change. For a deliberate one, re-make the record from the new
code and say in the commit what changed and why:

```sh
uv run python tests/make_golden.py            # all cases; or name some
uv run python tests/make_golden.py --check    # compare without writing
```

To compare with older code, set `TOOLKIT_ROOT` to a folder holding that commit's `scripts/` and `slicer/`:
`git archive <sha> scripts slicer | tar -x -C <dir>`. The record was first made that way, from 6eb1ec1.

## Fixtures

[`fixtures/`](fixtures/) holds:
- a box sliced by the house profiles, `box.gcode`;
- an L-shaped plate as a binary STL, `ell.stl`, and the box as a text STL;
- a filament profile's temperatures;
- a small vendor bundle, two templates and two sparse presets for `flatten_profiles.py`.

[`fixtures/make.sh`](fixtures/make.sh) remakes the three made by a tool.
