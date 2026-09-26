# 3D printing toolkit — profiles, design rules, part verification, firmware

Print-process engineering around a single **Prusa MK3S+**, treated as production equipment rather
than a hobby printer. Four things live here:

| | |
|---|---|
| **Tuned slicer profiles** | 20 filament + 10 print + 1 printer preset, every number traced to a vendor datasheet or to a measurement on this machine |
| **Design rules** | FDM constraints calibrated to *this* machine's measured extrusion width, not its nozzle diameter |
| **Part verification** | A pipeline that renders, asserts, checks manifold, slices, and cross-checks a model against the profile it was actually sliced with |
| **Firmware** | An ESP32-S3 camera node in plain C on ESP-IDF, plus ESPHome chamber sensor configuration |

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
| [`scripts/flatten_profiles.py`](scripts/flatten_profiles.py) | Regenerates filament profiles from the vendor chain, because of the `inherits` trap above |
| [`scripts/scad-check.sh`](scripts/scad-check.sh) | Verify a part end to end — render, asserts, manifold, slice — and cross-check its declared parameters against the profile actually used |
| [`scripts/scad-preview.sh`](scripts/scad-preview.sh) | Previews and cross-sections. Sections import the **exported STL**, so an export bug cannot hide behind a correct-looking render |
| [`models/`](models/) | Parametric OpenSCAD sources. The `.scad` is the artefact; STLs are build output and are not tracked |
| [`docs/`](docs/) | The written material — see *Documentation* below |
| [`firmware/`](firmware/) | ESP-IDF camera node and ESPHome sensor configuration |

## What's deliberately *not* here

- **Models and G-code.** STL, 3MF and G-code are large binaries and git is the wrong tool for them.
  `.gitignore` enforces it.
- **Physical-printer configs.** They hold PrusaLink API keys in plaintext. Also gitignored.
- **The parametric CAD library** — a separate project.
- **The heated drybox and desiccant module.** Their documents, firmware and models moved to a
  repository of their own in September 2026, once that work had grown into a project rather than a
  corner of this one. It is not public, so there is no link to give. What stayed here is the material
  the two share: the annealing page, the mechanical-design-review checklist, `scad-check.sh` and
  `scad-controls.sh`.
- **Procurement.** Prices that carry an argument stay; order references, vendors and what was paid
  belong in an inventory system, not a code repo.

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

## Part verification — `scripts/scad-check.sh`

CI discipline applied to physical parts. For a given model it renders, runs the model's own asserts,
checks the mesh is manifold, slices it, and **cross-checks the model's declared `fdm_*` parameters
against the slicer profile it was actually sliced with** — then exits non-zero on any mismatch. A
part whose design assumptions have drifted from the profile it gets sliced with fails the check
instead of failing on the bed.

## Firmware — `firmware/`

**`prusa-cam-c/`** — an ESP32-S3 camera node in plain **ESP-IDF 5.5, no Arduino**, written as an
alternative to the vendor's Arduino-based ESP32-Cam firmware.

Bench milestone: 640×480 RGB565 captured and software-encoded to a valid JPEG in roughly 570 ms,
with **byte-identical free heap across every cycle**. That last number is the one that matters in a
camera loop — a leaked frame buffer exhausts a fixed pool and presents as a *hang* minutes later
rather than as an error, so a stable heap is the check, not a nice statistic.

⚠️ The board has **two USB-C ports and they are not interchangeable** — one is native USB, the other
a CH343 UART bridge. Selecting the wrong console target sends every log line out the other
connector, and the board looks dead while running perfectly. `sdkconfig.defaults` pins the console
to UART0 for this reason.

⛔ **GPIO19 and GPIO20 are the native USB pins on the ESP32-S3.** A sensor on either shares its line
with an active differential pair whenever a data-capable cable is attached — so it misbehaves *while
you debug* and recovers when you unplug, which reads as a flaky sensor rather than a pin conflict.
`firmware/prusa-cam-c/main/board_pins.h` records every claimed pin with its reason.

**ESPHome configuration** for the chamber sensors is also here. The chamber node has been
built and run in the enclosure during live prints; the measurements and the reasoning behind the
sensor choices are in [`docs/chamber-sensor.md`](docs/chamber-sensor.md).

## Documentation — `docs/`

| | |
|---|---|
| [`fdm-design-rules.md`](docs/fdm-design-rules.md) | Design rules calibrated to this printer |
| [`asa-print-quality.md`](docs/asa-print-quality.md) | Getting better ASA prints, ordered by payoff |
| [`annealing-and-hot-service.md`](docs/annealing-and-hot-service.md) | What annealing does and does not do, and why HDT is not a service temperature once a part is loaded |
| [`mk3s-resume.md`](docs/mk3s-resume.md) | Restarting a print the printer has already abandoned |
| [`chamber-sensor.md`](docs/chamber-sensor.md) | Enclosure temperature sensing — three measurement points, and why each sensor was chosen |
| [`chamber-airflow.md`](docs/chamber-airflow.md) | Fume extraction and chamber airflow |
| [`prusa-connect-api.md`](docs/prusa-connect-api.md) | What the Prusa Connect API can and cannot automate, checked against live endpoints rather than forum posts. Short version: you can read and manage the queue, start prints and read progress — **there is no endpoint to upload a file** |

## Licence

Two licences, because this repository holds two different kinds of work:

| | |
|---|---|
| **Code** — `firmware/`, `scripts/` | **MPL-2.0** |
| **Everything else** — `docs/`, `slicer/`, `models/`, this README and the figures | **CC-BY-4.0** |

The split is deliberate. Creative Commons advises against using a CC licence for software: it carries
no patent grant and says nothing about source availability, and a firmware or script consumer needs
both. The rest is documentation, measured profile data and small printable parts, where CC-BY fits and
matches the norm for shared models.

Every file states its own licence, following the [REUSE](https://reuse.software/) specification —
either as an `SPDX-License-Identifier` header or through `REUSE.toml` for files that cannot carry one.
The slicer profiles are in the second group for a concrete reason: PrusaSlicer rewrites a preset when
it saves one and does not preserve comments, so a header written into a profile would vanish the first
time it was edited in the UI. Full licence texts are in [`LICENSES/`](LICENSES/).

⚠️ **Versions published before this change stay CC-BY-4.0.** Everything here was CC-BY-4.0 until
September 2026, and anyone who already has a copy keeps those terms for it. The split applies from
here onward.

---

*Hostnames, addresses and credentials in this repository are placeholders. Machine-specific values
are supplied through ESPHome secrets and are not published here.*

_Parts of this repository were drafted with the help of an LLM agent; reviewed and verified locally._
