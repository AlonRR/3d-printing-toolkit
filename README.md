# 3D printing

Documentation and slicer configuration for a **Prusa MK3S+**. Filament on hand: **Inslogic**
(ASA, TPU 95A) and **Yasin3D**.

Two things live here and nowhere else — the tuned filament profiles with the reasoning behind
every number, and the hard-won gotchas that took a wasted print or a wasted round-trip to find.

## What's in the repo

| Path | |
|---|---|
| [`slicer/filament/inslogic/`](slicer/filament/inslogic/) | The 7 Inslogic profiles + [their README](slicer/filament/inslogic/README.md) — build reasoning, what's print-validated, and the flattening trap |
| [`slicer/print/`](slicer/print/) | The 8 custom print profiles. **One of them, `…lightning`, has `spiral_vase = 1` baked in** — see §6 |
| [`slicer/reference/`](slicer/reference/) | Inslogic ASA + TPU 95A technical data sheets (the source for every temperature here) |
| [`scripts/flatten_profiles.py`](scripts/flatten_profiles.py) | Regenerates the filament profiles from the vendor chain. Needed because PrusaSlicer ignores `inherits` in hand-written presets |
| [`docs/fdm-design-rules.md`](docs/fdm-design-rules.md) | Design rules calibrated to **this** printer — the governing number is the 0.45 mm extrusion width, not the 0.4 mm nozzle, so walls quantise to multiples of 0.45 |
| [`models/`](models/) | Parametric OpenSCAD sources for one-off parts. STLs stay in OneDrive; the `.scad` is the artefact |

## What's deliberately *not* here

- **Models and G-code** — STL/3MF/gcode stay in `OneDrive\3D printing\`; they're large binaries
  and git is the wrong tool. `.gitignore` enforces it.
- **`physical_printer/` configs** — they hold PrusaLink API keys in plaintext. Also gitignored.
- **The parametric CAD library** — its own repo, `alon/print_scripts_tree_d`.
- **Print-station / homelab infrastructure** — lives in `alon/homelab`
  (`docs/manual/print-station.md`, `fume-fan-esp32.md`).

## Read this first if you're about to write a profile

**PrusaSlicer does not resolve `inherits` in a hand-written user preset.** Missing keys take the
system *default*, not the parent's value — silently, while slicing still succeeds. A correct
preset has ~85 keys. Full explanation and the fix:
[`slicer/filament/inslogic/README.md`](slicer/filament/inslogic/README.md).

---

*Index below gathered 28 Jul 2026. Sections describing `OneDrive\3D printing\` are a map of
what lives there, not a copy of it.*

---

## 1. Model library — `OneDrive\3D printing\`

The main archive. 165 STL · 68 3MF · 36 G-code · 1 STEP · 1 SCAD.

| Folder | What's in it |
|---|---|
| *(root)* | Loose working files — dry-box parts, filament-spool stands, Gridfinity contacts, breadboard bridges, PTFE tube guide |
| `For the printer\` | **Printer's own upgrades/spares** — filament guide, spool holder, x-end-motor, screen cover, bowden connector, cable clips, plus the 4 Live-Z adjust G-codes (`1_initial` → `4_ultrafine`) |
| `Gridfinity\` | Largest section. Full baseplate set (1x2…7x7, plain + weighted), ultralight bins, `sortfinity` small-part sorters, `sortfinity_minnie` (parametric, has the `.scad` source), drawer/shelf, hex-bit storage |
| `Ikea lack printer encloser\` | Lack-table enclosure — hinges, bottom-corner passthroughs, 3mm corner parts. `printed\` = the ones already run |
| `usefull\` | Calibration + shop tools — **PETG Live-Z calibration tags (0.4 and 0.6)**, filament sample swatches (PLA/PLA+/PETG/TPU/ASA), radius gauge, Bento box 120mm fan, hex-nut sorter, 3030 T-nuts |
| `toys\` | Brio/Lego adapters, guinea pigs, disc shooter |
| `Flower_vase_mode\` | Vase-mode roses + stem |
| `gcode_works\` | Known-good sliced output |
| `lack hinge with tightening\` | Enclosure hinge variant |
| ~~`print_scripts_tree_d\`~~ | Removed 2 Aug 2026 — was a stale duplicate; see §5 |

Also at root: `PrusaSlicer_config_bundle.ini` (84 KB) — an exported full config backup.

---

## 2. Slicer configuration — `%APPDATA%\PrusaSlicer\`

PrusaSlicer **2.9.4**. Default output path is already set to `OneDrive\3D printing`.

**Currently selected:** printer `Original Prusa i3 MK3S & MK3S+` · print `0.2mm QUALITY @MK3 — no skirt, no brim, no crossing perimeter, lightning` · filament `Ultrafuse TPU-95A - Copy`.

### Custom print profiles (8) — you run both a 0.4 and a 0.8 nozzle

| 0.4 nozzle | 0.8 nozzle |
|---|---|
| `0.10mm DETAIL @MK3 - No skirt no brim no perimeter` | `0.30mm DETAIL @0.8 nozzle - NO SKIRT` |
| `0.15mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter` | `0.40mm QUALITY @0.8 nozzle - NO Skirt` |
| `0.20mm QUALITY @MK3 no skirt` | `0.40mm Uber strong @0.8 nozzle` |
| `0.2mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter` | |
| `0.2mm QUALITY @MK3 - …, lightning` | |

The through-line: you strip skirt/brim and avoid crossing perimeters on nearly everything.

### Custom filament profiles (7)

| Profile | Type | Nozzle / Bed | Inherits | Notes |
|---|---|---|---|---|
| `Yasin3D PLA @0.8 nozzle` | PLA | 220 / 60 °C | `Generic PLA @0.8 nozzle` | Cost 39, density 1.24. Renamed from `Yasi3D…` and vendor corrected from "Generic" (2 Aug) |
| `Yasin3D ASA @0.8 nozzle` | ASA | 265 / 110 °C | `Prusament ASA @0.8 nozzle` | Cost 54, density 1.07. Fan pinned 20 %, off for first 4 layers. Renamed from `YASIN…` and vendor corrected from "Prusa Polymers" (2 Aug) |
| `Ultrafuse TPU-95A - Copy` | FLEX | 225 (first layer 230) / 40 °C | `Ultrafuse TPU-95A` | Stock BASF notes retained. ⚠️ Inherits a 15 mm³/s flow ceiling from a rigid-copolyester ancestor — see §6 |
| `Inslogic ASA` | ASA | 255 / 100 °C | `Prusament ASA` | Added 28 Jul 2026 from TDS |
| `Inslogic ASA @0.8 nozzle` | ASA | 265 / 100 °C | `Prusament ASA @0.8 nozzle` | Added 28 Jul 2026 from TDS |
| `Inslogic TPU 95A` | FLEX | 210 / 50 °C | `Generic FLEX` | Added 28 Jul 2026 from TDS. Fan 100 % |
| `Inslogic TPU 95A @0.8 nozzle` | FLEX | 215 / 50 °C | `Generic FLEX @0.8 nozzle` | Added 28 Jul 2026 from TDS. Fan 100 % |
| **`Inslogic ASA - thin wall`** | ASA | 250 / 100 °C | `Prusament ASA` | **✅ Print-validated 29 Jul 2026.** Fan **70 %**, layer time forced to 10 s. Spiral-vase / single-wall only; 70 % fan would split layers on bulk ASA. Renamed from `- vase` (2 Aug) — it is not vase-mode-specific |
| `Inslogic ASA - thin wall, flat base` | ASA | 250 / 100 °C | `Prusament ASA` | As above but `disable_fan_first_layers = 10`, so a wide flat base prints in still air. Renamed from `- leaves` (2 Aug) |
| **`Inslogic TPU 95A - fast`** | FLEX | 225 / 50 °C | `NinjaTek Cheetah TPU` | **✅ Print-validated 30 Jul 2026** — 4.0 mm³/s and 1.5 mm retraction; 2h53m → 1h40m on the same model |

Full reasoning for the Inslogic profiles: [`slicer/filament/inslogic/README.md`](slicer/filament/inslogic/README.md).

### Physical printers (3) — all one machine, three entries

| Entry | Host | Type | Bound preset |
|---|---|---|---|
| `Prusa mk3S+` | `192.0.2.128` | PrusaLink | `Original Prusa i3 MK3` ⚠️ |
| `Mk` | `prusalink.local` | PrusaLink | `Original Prusa i3 MK3S & MK3S+ 0.8 nozzle` |
| `Prusa mk3` | `connect.prusa3d.com` | PrusaConnect | `Original Prusa i3 MK3` ⚠️ |

`192.0.2.128` and `prusalink.local` are the same Pi 4 — one entry per nozzle size, reached two different ways. API keys are stored in plaintext in these files (normal for PrusaSlicer; just don't commit them).

---

## 3. Parametric CAD library — `Code\print_scripts_tree_d\`

A genuinely developed Python project, not a scratch folder. **This is the most valuable 3D-printing asset on the machine.**

- **Stack:** [build123d](https://github.com/gumyr/build123d) (OpenCASCADE) · Python 3.13 · **uv** · pytest + ruff + mypy strict
- **Remotes:** `gitea` → `git@example:alon/print_scripts_tree_d.git` ✅ and `origin` → GitHub
- **HEAD:** `b1d94d0 chore: track repo-specific Claude skills`
- **Docs:** `CLAUDE.md` (274 lines — design principles), `ARCHITECTURE.md`, `README.md`
- **Shapes:** `boxes.py` (rounded box) · `clips.py` (cylinder clip, magnet attachment) · `panels.py` (hex mesh, magnet ring) · `furniture.py` (column, table) · `primitives.py` (washer, magnet, screw/thread)
- **Iteration workflow:** `scratch/try_<name>.py` with `%autoreload` in VS Code Interactive, plus `sandbox.ipynb`
- **Gate:** `save_stl()` asserts watertight + positive volume before anything is written

The `CLAUDE.md` encodes hard-won OCC fillet knowledge worth not relosing — bake vertical corner rounding into the profile via `RectangleRounded`, skip arc edges and edges shorter than `2*r`, and never stage fillets that share a vertex.

Two repo-local Claude skills exist: `new-shape` and `watertight-debug`.

**Uncommitted right now:** `.claude/settings.json`, `export.py`, `params.py`, `shapes/` show as untracked at the repo root — worth a look, since tracked copies also exist under `print_scripts_tree_d/`.

---

## 4. Homelab / print-station docs — `Tools\homelab\docs\manual\`

- **`print-station.md`** — Pi 4 print server + planned Home Assistant link. ⚠️ Contains a factual error, see §6.
- **`fume-fan-esp32.md`** — the ASA/ABS fume extractor: 12 V 4-pin PWM fan + USB-C PD trigger board + ESP32, driven over MQTT from HA. All three hardware parts owned; open unknown is whether the USB-C charger negotiates a 12 V PD profile.
- Supporting: `home-assistant.md`, `mqtt-mosquitto.md`, `edge-ai-and-ml.md`
- `CLAUDE.md` → "Print station (Prusa MK3 area)" is the top-level summary.

---

## 5. Loose / unfiled

- **`Downloads\`** — **213** STL/3MF/G-code files plus model folders: `bento-box-air-filter-for-120mm-fan-hepa-carbon-trays`, `Bentobox V2.0 Remix`, `double-filament-spool-roller`, `gridfinity-hss-hex-bit-storage`, `Radius_Gauge_STL`, and the PrusaSlicer 2.9.4 installer. Overlaps the curated library in places.
- ~~**`OneDrive\3D printing\print_scripts_tree_d\`** — a stale copy with the live repo nested inside it.~~ **Resolved 2 Aug 2026.** `ods` was remapped from `3D printing\print_scripts_tree_d\print_scripts_tree_d` → **`Tools\print_scripts_tree_d`**, alongside every other repo, and reseeded (383 files). The stale outer copy (`11bf03b`, GitHub-only remote, untouched since 9 Jun) was verified to hold no unique commits, then deleted. Its uncommitted diff turned out to be sync bleed rather than human work — the live repo's own refactor showing as "modified" against a June-era HEAD — and is archived anyway at `OneDrive\Backups\print_scripts_tree_d-stale-copy-uncommitted-2026-08-02.patch`.

---

## 6. Open items

1. ~~**`print-station.md` documents the wrong software.**~~ **Fixed upstream in `alon/homelab` on 29 Jul 2026** — the doc now covers PrusaLink correctly, with a live-verified evidence section. Kept here for the reasoning: It says *OctoPrint* throughout, but every physical-printer entry in PrusaSlicer is `host_type = prusalink`, and the top-level `CLAUDE.md` says "confirmed running **PrusaLink** (not OctoPrint)". The doc's HA integration steps are OctoPrint-specific and won't work: port 5000, "Settings → API → Application Key", and entities like `binary_sensor.octoprint_printing`. PrusaLink needs the HA **PrusaLink** integration and different entity names. Everything downstream of that — including the fume-fan automation trigger — inherits the error.
2. **Two physical-printer entries are bound to the plain `Original Prusa i3 MK3` preset**, not MK3S+. Worth correcting given the MK3S+ (SuperPINDA temperature compensation differs). Consistent with the mixed `_MK3_` / `_MK3S_` suffixes across sliced G-code.
3. ~~**No Inslogic filament profile.**~~ **Built and installed 28 Jul 2026** — source in [`slicer/filament/inslogic/`](slicer/filament/inslogic/), live in `%APPDATA%\PrusaSlicer\filament\`. Four profiles (ASA and TPU 95A, each at 0.4 and 0.8 nozzle) derived from Inslogic's TDS PDFs, archived alongside them. Inslogic publishes data sheets only, no slicer profiles. Each verified by a real CLI slice. **Temperatures are TDS-derived, not yet confirmed by a printed part.**
   - Related: the existing **`Ultrafuse TPU-95A - Copy`** profile inherits `filament_max_volumetric_speed = 15` and a 40 °C bed from `Ultrafuse TPC-45D`, a near-rigid copolyester four levels up its inheritance chain. Prusa's soft-TPU chain (`Generic FLEX`) uses 1.2 mm³/s and a 50 °C bed. Worth revisiting.
4. ~~**Nested stale repo copy**~~ — **done 2 Aug 2026**, see §5.
5. ~~**`OneDrive\3D printing\` is not version controlled.**~~ **Done 2 Aug 2026** — this repo, `alon/3d-printing`, synced back to `OneDrive\Tools\3d-printing` via `ods`. Documentation and slicer config are versioned; models and G-code deliberately stay in OneDrive as binaries. Still unversioned and remaining candidates: `PrusaSlicer_config_bundle.ini` and the `.scad` sources.
6. **Yasin PLA profile is a bare clone** of `Generic PLA @0.8 nozzle` at stock 220/60 with `filament_vendor = Generic` and empty notes — no calibration of its own. The ASA profile, by contrast, is properly tuned.
7. **The stored PrusaLink API key is stale — remote upload is broken** (found 17 Aug 2026). Both
   `physical_printer` entries (`Prusa mk3S+` → `192.0.2.128`, `Mk` → `prusalink.local`) hold the
   *same* 14-character key, and both endpoints reject it with `403 Bad X-Api-Key`. The printer
   itself is fine: it answers ping and serves a proper `401` challenge.
   - **Not** a CRLF/extraction artefact — the key was verified clean (no trailing `\r`), and the
     403 persists on both hosts.
   - **Not** an auth-*mode* problem. `GET /` returns
     `WWW-Authenticate: Digest realm="Administrator"`, which is the **web UI** login and is easy to
     misread as "PrusaLink switched to Digest". It hasn't — a `403 Bad X-Api-Key` on `/api/*` proves
     the API-key path exists and was evaluated. The key is simply wrong.
   - **Fix:** read the current key from the PrusaLink web UI at `http://192.0.2.128` → Settings,
     and paste it into *both* physical-printer entries. Don't change
     `printhost_authorization_type`; `key` is correct.
   - Workaround meanwhile: drag the `.gcode` into the PrusaLink web UI, or use the SD card.

---

## Quick paths

```
Models          C:\Users\<user>\OneDrive\3D printing\
Slicer config   C:\Users\<user>\AppData\Roaming\PrusaSlicer\
CAD library     C:\Users\<user>\Code\print_scripts_tree_d\
Print station   C:\Users\<user>\Tools\homelab\docs\manual\print-station.md
Fume fan        C:\Users\<user>\Tools\homelab\docs\manual\fume-fan-esp32.md
PrusaLink       http://prusalink.local  /  http://192.0.2.128
```
