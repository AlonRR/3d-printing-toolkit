# Tests

```sh
uv run pytest
```

- **[`test_golden.py`](test_golden.py):** every script under `scripts/` runs on fixed inputs and must do exactly
  what [`golden.json`](golden.json) recorded. That covers its exit code, its output, the last line of any error,
  the requests a stub PrusaLink received with their safety headers, and each file it wrote, by size and hash.
  [`cases.py`](cases.py) holds the cases. They cover each script's normal run, its other options, and the inputs
  it refuses.
- **[`test_stub_scripts.py`](test_stub_scripts.py):** the stub tests in `scripts/mk3s-resume/` pass.

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
