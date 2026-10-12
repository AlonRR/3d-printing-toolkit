# 3D printing toolkit — profiles, design rules, printer operations

Print-process engineering around a single **Prusa MK3S+**, treated as production equipment rather
than a hobby printer. What lives here:

| | |
|---|---|
| **Tuned slicer profiles** | 20 filament + 9 print + 1 printer preset, every number traced to a vendor datasheet or to a measurement on this machine |
| **Design rules** | FDM constraints calibrated to *this* machine's measured extrusion width, not its nozzle diameter |
| **Printer operations** | Scripts for the jobs the slicer does not do: resuming a print the printer abandoned, annealing parts on the bed, Live adjust Z calibration tags, retargeting a sliced file's temperatures, keeping the presets in step with the house rules |
| **Calibration models** | A PETG temperature tower and a gridfinity foot negative, in OpenSCAD, checked before they print |

Every figure here is either read out of this repo's own sliced output or measured on the machine.
Where a number is inherited or assumed rather than measured, it says so — that distinction is the
point of most of these documents.

---

## ⚠️ Read this first if you are about to write a profile

**PrusaSlicer does not resolve `inherits` in a hand-written user preset.** Missing keys take the
system *default*, not the parent's value — silently, while slicing still succeeds. A correct preset
has about 85 keys. Full explanation and the fix:
[`slicer/filament/inslogic/README.md`](slicer/filament/inslogic/README.md).

Two more from the same day, each of which cost a round trip:

- **A resolved chain drags `renamed_from` into the child**, so four PETG profiles each ended up
  claiming to *be* the renamed `Generic PET`.
- **`Prusament PETG` excludes 0.6 nozzles** in its compatibility condition, so anything inheriting
  it vanishes from the filament list on a 0.6 — which is why every PETG profile here inherits
  `Generic PETG` instead.

---

## What's in the repo

| Path | |
|---|---|
| [`slicer/filament/inslogic/`](slicer/filament/inslogic/) | Profiles derived from real vendor datasheets — ASA, TPU 95A, PLA Pro, PETG Pro |
| [`slicer/filament/yasin3d/`](slicer/filament/yasin3d/) | A vendor that publishes **no** datasheet. Labelled as a starting point, not a calibration |
| [`slicer/filament/unbranded/`](slicer/filament/unbranded/) | Filament with **no manufacturer at all** — the SKU is its only identity, so the SKU is in the filename |
| [`slicer/filament/ultrafuse/`](slicer/filament/ultrafuse/) | A user copy of a system preset, inherited and not validated here |
| [`slicer/print/`](slicer/print/) | The custom print profiles. ⚠️ One, `…lightning`, has `spiral_vase = 1` baked in — deliberate and documented, but it will surprise you if selected blind |
| [`slicer/printer/`](slicer/printer/) | The printer preset itself |
| [`slicer/reference/`](slicer/reference/) | Vendor data transcribed to Markdown, with what was taken and what was overridden |
| [`scripts/`](scripts/) | The printer-operation and profile scripts — see *Scripts* below |
| [`tests/`](tests/) | What every script does, recorded and checked — see *Tests* below |
| [`models/`](models/) | Parametric OpenSCAD sources: the temperature tower and the gridfinity foot negative. The `.scad` is the artefact; STLs are build output and are not tracked |
| [`scad-tools/`](https://github.com/AlonRR/scad-tools) | The shared OpenSCAD tools, a git submodule — see *Part verification* below |
| [`docs/`](docs/) | The written material — see *Documentation* below |

## What's deliberately *not* here

- **Models and G-code.** STL, 3MF and G-code are large binaries and git is the wrong tool for them.
  `.gitignore` enforces it; the tests' small fixtures are the one exception.
- **Physical-printer configs.** They hold PrusaLink API keys in plaintext. Also gitignored.
- **The parametric CAD library** — a separate project.
- **Procurement.** Prices that carry an argument stay; order references, vendors and what was paid
  belong in an inventory system, not a code repo.
- **Projects that outgrew this repository** — see *Moved out* below.

---

## Slicer profiles — `slicer/`

**The difference between the vendors is the point.** Inslogic publishes real technical datasheets,
so those profiles derive every temperature, flow and cooling figure from a documented source.
Yasin3D publishes nothing, and one filament here has no manufacturer at all. Those profiles are
generic values with a name attached, and each directory's README records which is which, so nobody
mistakes an assumption for a measurement.

### A defect worth knowing about

The ASA profile asks for a 15 second minimum layer time. **`min_print_speed` silently caps it at
5 seconds** — the slicer does not warn you, and the symptom is poor small-layer cooling that reads
as a temperature problem. [`docs/asa-print-quality.md`](docs/asa-print-quality.md) covers this and
the rest of the ASA tuning, ordered by payoff.

## Design rules — `docs/fdm-design-rules.md`

The governing dimension on this machine is the **0.45 mm extrusion width, not the 0.4 mm nozzle**,
so wall thicknesses quantise to multiples of 0.45. Designing to the nozzle diameter produces walls
the slicer cannot fill cleanly.

The document also records **claims deliberately not imported** from general design advice — wall
steps that assume a 0.4 mm width, bridging figures well past this machine's measured ceiling, and
text-orientation advice that is backwards here. Each is a generic figure meeting a measured one.

## Scripts — `scripts/`

Each runs on its own, from the repository's root, with [uv](https://docs.astral.sh/uv/):
`uv run scripts/<name>.py`. Each opens with what it does, why, and how to call it.

| | |
|---|---|
| [`flatten_profiles.py`](scripts/flatten_profiles.py) | Regenerates the filament profiles from the vendor chain, because of the `inherits` trap above |
| [`patch_print_profiles.py`](scripts/patch_print_profiles.py) | Applies the house rules — no skirt, no brim, cubic infill — to the print presets, live or in `slicer/print/`, changing nothing else; a dry run unless told `--apply` |
| [`retarget_filament_temps.py`](scripts/retarget_filament_temps.py) | Rewrites a sliced file's temperatures for another filament profile, and proves nothing else changed |
| [`make_live_z_tags.py`](scripts/make_live_z_tags.py) | A Live adjust Z calibration plate for any nozzle, each tag labelled with its height |
| [`bed-anneal-gcode.py`](scripts/bed-anneal-gcode.py) | A G-code "print" that anneals parts on the heated bed: ramp, hold, slow cool — [`docs/annealing-and-hot-service.md`](docs/annealing-and-hot-service.md) |
| [`add_brim_ears.py`](scripts/add_brim_ears.py) | Mouse-ear tabs on the corners of an STL that can lift, in place of a full brim, kept off its holes and its other islands |
| [`mk3s-resume/`](scripts/mk3s-resume/) | Resuming a print the printer abandoned, part still on the bed — [`docs/mk3s-resume.md`](docs/mk3s-resume.md) |

The scripts that talk to the printer read its address and API key from PrusaSlicer's
physical-printer profile, and never print either.

## Tests — `tests/`

```sh
uv run pytest
```

Every script is run on fixed inputs and must do exactly what [`tests/golden.json`](tests/golden.json)
recorded. That covers its exit code, its output, the requests a stub PrusaLink receives, and every file it
writes. Nothing touches PrusaSlicer's own folders or a printer. [`tests/README.md`](tests/README.md) says how,
and how to re-record a script that changed on purpose.

## Part verification — `scad-tools/scripts/scad-check.sh`

CI discipline applied to physical parts. For a given model it renders, runs the model's own asserts,
checks the mesh is manifold, slices it, and **cross-checks the model's declared `fdm_*` parameters
against the slicer profile it was actually sliced with** — then exits non-zero on any mismatch. A
part whose design assumptions have drifted from the profile it gets sliced with fails the check
instead of failing on the bed. It is [scad-tools](https://github.com/AlonRR/scad-tools)', a git submodule here:
clone with `git clone --recurse-submodules`, or run `git submodule update --init` after a plain clone. Then, from
the repository's root:

```sh
sh scad-tools/scripts/scad-check.sh models/petg-temp-tower/petg-temp-tower.scad
```

A ZIP from GitHub comes without it: from the unpacked folder, fetch the version this repository is pinned to.
In PowerShell:

```powershell
$pin = (Invoke-RestMethod https://api.github.com/repos/AlonRR/3d-printing-toolkit/contents/scad-tools).sha
Invoke-WebRequest "https://github.com/AlonRR/scad-tools/archive/$pin.zip" -OutFile scad-tools.zip
Remove-Item -Recurse -ErrorAction SilentlyContinue scad-tools
Expand-Archive scad-tools.zip . ; Rename-Item "scad-tools-$pin" scad-tools ; Remove-Item scad-tools.zip
```

or in a POSIX shell:

```sh
pin=$(curl -s https://api.github.com/repos/AlonRR/3d-printing-toolkit/contents/scad-tools | sed -n 's/.*"sha": *"\([0-9a-f]*\)".*/\1/p')
rm -rf scad-tools && mkdir scad-tools && curl -sL "https://github.com/AlonRR/scad-tools/archive/$pin.tar.gz" | tar xz --strip-components=1 -C scad-tools
```

## Moved out

Work that grew past a corner of this repository moved to one of its own, each with its history:

| | |
|---|---|
| [**printer-enclosure**](https://github.com/AlonRR/printer-enclosure) | The enclosure's sensing and airflow: the chamber node, its measurements, the fan plan and the scrubber. October 2026 |
| [**air-quality-monitor**](https://github.com/AlonRR/air-quality-monitor) | The particle and VOC/NOx monitor that hangs beside the enclosure. October 2026 |
| [**parts**](https://github.com/AlonRR/parts) | Finished small parts, starting with the USB-C panel plate. 12 Oct 2026 |
| **esp32-cam-for-prusa-connect** | The ESP32-S3 camera node for Prusa Connect, in plain ESP-IDF C, and the notes on what the Prusa Connect API can and cannot automate - checked against its live endpoints; the short version is that there is no endpoint to upload a file. Private for now; until it is public, both are in this repository's history, under `firmware/prusa-cam-c/` and `docs/prusa-connect-api.md` (the notes moved 12 Oct 2026) |
| **The printed fan connector** | 2.54 mm, male and female. 9 Oct 2026, ahead of its Printables listing; not public yet |
| **The heated drybox and desiccant module** | September 2026. Not public. What stayed here is what the two share: the annealing page and the mechanical-design-review checklist |

Ideas that are not yet parts are kept in a private workshop repository until they are.

## Documentation — `docs/`

| | |
|---|---|
| [`fdm-design-rules.md`](docs/fdm-design-rules.md) | Design rules calibrated to this printer |
| [`openscad-basics/`](docs/openscad-basics/) | Six hands-on OpenSCAD lessons, ending in a part written the way the models here are — every behaviour described was measured, not recalled |
| [`asa-print-quality.md`](docs/asa-print-quality.md) | Getting better ASA prints, ordered by payoff |
| [`annealing-and-hot-service.md`](docs/annealing-and-hot-service.md) | What annealing does and does not do, and why HDT is not a service temperature once a part is loaded |
| [`mechanical-design-review.md`](docs/mechanical-design-review.md) | The questions a collision check never asks: a checklist for reviewing a printed mechanical assembly |
| [`mk3s-resume.md`](docs/mk3s-resume.md) | Restarting a print the printer has already abandoned |

## Licence

Two licences, because this repository holds two different kinds of work:

| | |
|---|---|
| **Code** — `scripts/`, `tests/`, `pyproject.toml` | **MPL-2.0** |
| **Everything else** — `docs/`, `slicer/`, `models/`, this README and the figures | **CC-BY-4.0** |

The split is deliberate. Creative Commons advises against using a CC licence for software: it carries
no patent grant and says nothing about source availability, and a script consumer needs both. The rest
is documentation, measured profile data and small printable parts, where CC-BY fits and matches the
norm for shared models.

Every file states its own licence, following the [REUSE](https://reuse.software/) specification —
either as an `SPDX-License-Identifier` header or through `REUSE.toml` for files that cannot carry one.
The slicer profiles are in the second group for a concrete reason: PrusaSlicer rewrites a preset when
it saves one and does not preserve comments, so a header written into a profile would vanish the first
time it was edited in the UI. Full licence texts are in [`LICENSES/`](LICENSES/).

⚠️ **Versions published before this change stay CC-BY-4.0.** Everything here was CC-BY-4.0 until
September 2026, and anyone who already has a copy keeps those terms for it. The split applies from
here onward.

---

*Hostnames, addresses and credentials in this repository are placeholders. The printer's own address
and key are read from a PrusaSlicer profile that is gitignored, and are not published here.*

_Parts of this repository were drafted with the help of an LLM agent; reviewed and verified locally._
