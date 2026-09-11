# 3D printing

Documentation and slicer configuration for a **Prusa MK3S+**. Filament on hand: **Inslogic**
(ASA, TPU 95A) and **Yasin3D**.

Two things live here and nowhere else — the tuned filament profiles with the reasoning behind
every number, and the hard-won gotchas that took a wasted print or a wasted round-trip to find.

## What's in the repo

| Path | |
|---|---|
| [`slicer/filament/inslogic/`](slicer/filament/inslogic/) | The 11 Inslogic profiles (ASA, TPU 95A, PLA Pro, PETG Pro) + [their README](slicer/filament/inslogic/README.md) — build reasoning, what's print-validated, and the flattening trap |
| [`slicer/filament/yasin3d/`](slicer/filament/yasin3d/) | The 6 Yasin3D profiles (PLA, PETG, ASA) + [their README](slicer/filament/yasin3d/README.md). **Yasin3D publishes no data sheet at all**, so these are Prusa's generic values with a vendor and a price attached — a starting point, not a calibration |
| [`slicer/print/`](slicer/print/) | The 9 custom print profiles. **One of them, `…lightning`, has `spiral_vase = 1` baked in** — see §6 |
| [`slicer/reference/`](slicer/reference/) | [Inslogic filament data](slicer/reference/inslogic-filament-data.md) — ASA, TPU 95A, PLA Pro, PETG Pro figures transcribed from the vendor TDS (the source for every temperature in those profiles) |
| [`scripts/flatten_profiles.py`](scripts/flatten_profiles.py) | Regenerates the filament profiles from the vendor chain. Needed because PrusaSlicer ignores `inherits` in hand-written presets |
| [`docs/chamber-sensor.md`](docs/chamber-sensor.md) | Design for the enclosure temperature sensor — three measurement points not one, the C3 pin map, and why the safety interlock has to run on the ESP32 rather than in Home Assistant |
| [`docs/asa-print-quality.md`](docs/asa-print-quality.md) | How to get better ASA prints on this machine, ordered by payoff. Leads with a real defect: the ASA profile asks for a 15 s minimum layer time and `min_print_speed` silently caps it at 5 |
| [`docs/fdm-design-rules.md`](docs/fdm-design-rules.md) | Design rules calibrated to **this** printer — the governing number is the 0.45 mm extrusion width, not the 0.4 mm nozzle, so walls quantise to multiples of 0.45 |
| [`models/`](models/) | Parametric OpenSCAD sources for one-off parts. STLs stay in OneDrive; the `.scad` is the artefact |
| [`scripts/scad-check.sh`](scripts/scad-check.sh) | Verify a part end to end — render, asserts, manifold, slice — and **cross-check the model's `fdm_*` values against the profile it was actually sliced with**. Non-zero exit on any problem |
| [`scripts/scad-preview.sh`](scripts/scad-preview.sh) | Previews, cross-sections and thin slices. Sections import the **exported STL**, so an export bug cannot hide behind a correct-looking render of the source |

The workflow around these — sequencing, file conventions, the verification loop —
is the user-level **`openscad-printed-part`** skill.

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

Two more that cost a round-trip each on 29 Aug 2026, documented in the same file: **a resolved
chain drags `renamed_from` into the child** (four PETG profiles each claiming to be the renamed
`Generic PET`), and **`Prusament PETG` excludes 0.6 nozzles** in its compatibility condition, so
anything inheriting it vanishes from the filament list on a 0.6 — which is why every PETG
profile here inherits `Generic PETG` instead.

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

### Custom print profiles (9) — you run both a 0.4 and a 0.8 nozzle

| 0.4 nozzle | 0.8 nozzle |
|---|---|
| `0.10mm DETAIL @MK3 - No skirt no brim no perimeter` | `0.30mm DETAIL @0.8 nozzle - NO SKIRT` |
| `0.15mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter` | `0.40mm QUALITY @0.8 nozzle - NO Skirt` |
| `0.20mm QUALITY @MK3 no skirt` | `0.40mm Uber strong @0.8 nozzle` |
| `0.2mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter` | |
| `0.2mm QUALITY @MK3 - …, lightning` | |
| **`0.2mm QUALITY @MK3 - ASA brim + draft shield`** | |

The through-line: you strip skirt/brim and avoid crossing perimeters on nearly everything —
with one deliberate exception, the ASA profile added 30 Aug 2026, where a brim and a full-height
draft shield are exactly what a warp-prone material in a half-open enclosure wants.
⚠️ **A draft shield needs `skirts ≥ 1`**; with the `skirts = 0` these profiles all use, turning
it on prints nothing and reports no error. Measured, see
[asa-print-quality.md](docs/asa-print-quality.md).

### Custom filament profiles (18)

| Profile | Type | Nozzle / Bed | Inherits | Notes |
|---|---|---|---|---|
| `Yasin3D PLA @0.8 nozzle` | PLA | 220 / 60 °C | `Generic PLA @0.8 nozzle` | Cost 39, density 1.24. Renamed from `Yasi3D…` and vendor corrected from "Generic" (2 Aug) |
| `Yasin3D ASA @0.8 nozzle` | ASA | 265 / 110 °C | `Prusament ASA @0.8 nozzle` | Cost 54, density 1.07. Fan pinned 20 %, off for first 4 layers. Renamed from `YASIN…` and vendor corrected from "Prusa Polymers" (2 Aug) |
| `Ultrafuse TPU-95A - Copy` | FLEX | 225 (first layer 230) / 40 °C | `Ultrafuse TPU-95A` | Stock BASF notes retained. ⚠️ Inherits a 15 mm³/s flow ceiling from a rigid-copolyester ancestor — see §6 |
| `Inslogic ASA` | ASA | 255 / **105–110** °C | `Prusament ASA` | Added 28 Jul 2026 from TDS. Bed raised to Prusa's 105/110 on 30 Aug — outside Inslogic's 80–100 spec, safe only because glue goes down every print. `min_print_speed` 15 → 5 the same week |
| `Inslogic ASA @0.8 nozzle` | ASA | 265 / **105–110** °C | `Prusament ASA @0.8 nozzle` | Added 28 Jul 2026 from TDS. Same bed and `min_print_speed` changes |
| `Inslogic TPU 95A` | FLEX | 210 / 50 °C | `Generic FLEX` | Added 28 Jul 2026 from TDS. Fan 100 % |
| `Inslogic TPU 95A @0.8 nozzle` | FLEX | 215 / 50 °C | `Generic FLEX @0.8 nozzle` | Added 28 Jul 2026 from TDS. Fan 100 % |
| **`Inslogic ASA - thin wall`** | ASA | 250 / 100 °C | `Prusament ASA` | **✅ Print-validated 29 Jul 2026.** Fan **70 %**, layer time forced to 10 s. Spiral-vase / single-wall only; 70 % fan would split layers on bulk ASA. Renamed from `- vase` (2 Aug) — it is not vase-mode-specific |
| `Inslogic ASA - thin wall, flat base` | ASA | 250 / 100 °C | `Prusament ASA` | As above but `disable_fan_first_layers = 10`, so a wide flat base prints in still air. Renamed from `- leaves` (2 Aug) |
| **`Inslogic TPU 95A - fast`** | FLEX | 225 / 50 °C | `NinjaTek Cheetah TPU` | **✅ Print-validated 30 Jul 2026** — 4.0 mm³/s and 1.5 mm retraction; 2h53m → 1h40m on the same model |
| `Inslogic PLA Pro` | PLA | 205 (first 210) / 60 °C | `Generic PLA` | Added 29 Aug 2026 from TDS. ₪59/kg. 205 is the top of the vendor band for MK3S+ speeds — the parent's 210 is above it |
| `Inslogic PLA Pro @0.8 nozzle` | PLA | 220 / 60 °C | `Generic PLA @0.8 nozzle` | Added 29 Aug 2026 from TDS. First layer clamped from the parent's 230, which the sheet never sanctions |
| `Inslogic PETG Pro` | PETG | 240 / **70** °C | `Generic PETG` | Added 29 Aug 2026 from TDS. ₪49/kg. Bed is the only real change — vendor says 60–70, Prusa runs 85/90 |
| `Inslogic PETG Pro @0.8 nozzle` | PETG | 250 (first 240) / **70** °C | `Generic PETG @0.8 nozzle` | Added 29 Aug 2026 from TDS. No temperature override at all — the parent already sits in the vendor's band |
| `Yasin3D PLA` | PLA | 210 / 60 °C | `Generic PLA` | Added 29 Aug 2026. No vendor data exists; mirrors the @0.8 profile's first-layer edit |
| `Yasin3D PETG` | PETG | 240 / 85–90 °C | `Generic PETG` | Added 29 Aug 2026. ₪39/kg — the one Yasin3D price that is a current listing |
| `Yasin3D PETG @0.8 nozzle` | PETG | 250 (first 240) / 85–90 °C | `Generic PETG @0.8 nozzle` | Added 29 Aug 2026 |
| `Yasin3D ASA` | ASA | 260 / 110 °C | `Prusament ASA` | Added 29 Aug 2026. Mirrors the @0.8 profile's first-layer bed edit |

Full reasoning: [`slicer/filament/inslogic/README.md`](slicer/filament/inslogic/README.md) and
[`slicer/filament/yasin3d/README.md`](slicer/filament/yasin3d/README.md). The split matters —
the Inslogic numbers come from published data sheets, the Yasin3D ones come from Prusa's
generic profiles because **Yasin3D publishes nothing at all**.

### Physical printers (3) — all one machine, three entries

| Entry | Host | Type | Bound preset |
|---|---|---|---|
| `Prusa mk3S+` | `prusalink.internal.example` | PrusaLink | `Original Prusa i3 MK3` ⚠️ |
| `Mk` | `prusalink.internal.example` | PrusaLink | `Original Prusa i3 MK3S & MK3S+ 0.8 nozzle` |
| `Prusa mk3` | `connect.prusa3d.com` | PrusaConnect | `Original Prusa i3 MK3` ⚠️ |

Both PrusaLink entries now use **`prusalink.internal.example`** (updated 1 Sep 2026) — one entry per nozzle
size, same Pi 4. API keys are stored in plaintext in these files (normal for PrusaSlicer; just
don't commit them).

⛔ **The third entry is PrusaConnect and holds a *different* token.** It is a 17-character key
against `connect.prusa3d.com`, not the 14-character PrusaLink one. "Paste the key into all the
printer entries" would overwrite a working uploader to fix a broken one — two of three, never
three of three.

⚠️ **PrusaSlicer rewrites these files when it exits.** Edit them in the GUI while it is open,
or on disk while it is closed — never on disk underneath a running instance, or the change is
silently discarded on quit.

### ⚠️ Two DNS traps worth knowing before trusting any `.internal.example` name

**1. `*.internal.example` is a wildcard pointing at the reverse proxy, so *every* name resolves.**
Verified: `definitely-not-a-real-name.internal.example` resolves, and so do `mk3.internal.example`,
`prusa.internal.example` and `printer.internal.example` — none of which exists. **Resolving is not serving.**
Confirm a real *response* before depending on a name, rather than a successful lookup. Specific A
records do override the wildcard — `mqtt.internal.example` is a real record and answers a genuine MQTT
`CONNACK`.

**2. Do not read `nslookup` output with "first `Address:` wins".** The first one is the *DNS
server's* address, not the answer. That single mistake made every name here look like it pointed
at the proxy and nearly put a wrong claim in this file. Use `getaddrinfo` (or read the whole
`nslookup` block), which also picks up mDNS — the thing pure DNS cannot see.

The printer is **not** behind the proxy at all: `prusalink.local` is mDNS straight to the Pi (plus a
link-local v6). Pure DNS cannot resolve it; the system resolver can.

### The printer's name, and why it is LAN-only on purpose

Answered and then built by the homelab session, 1 Sep 2026 (`f89f4a2`).

```
prusalink.internal.example  ->  reverse proxy  ->  the Pi
                     tls internal, access-logged
```

**Prefer `prusalink.internal.example`.** `prusalink.local` still works but is mDNS — link-local, invisible to pure
DNS, useless from a container, another VLAN, or off-site. Do not build anything on it.

The lab splits host-name from service-name everywhere (`git.` is the box, `gitea.` the web UI;
`homeassistant.` the CT, `ha.` the UI), so the printer follows suit: `prusalink.internal.example` is the web
UI. If SSH or a direct API path is ever needed, that becomes a separate `prusalink-host.internal.example`.

A vhost rather than a plain DNS record, for a concrete reason: PrusaLink's Digest credentials and
its `X-Api-Key` crossed the LAN **in cleartext** before this. Now they are inside TLS, and the
printer appears in the Caddy access log with the true client IP.

⚠️ **No DNS record was added, and that corrects an assumption both sessions made.** The
`address=/internal.example/<proxy>` wildcard already routes every unclaimed name to the proxy, so
adding the vhost was sufficient on its own. The explicit `address=` lines exist only for the
**direct** names that must bypass the proxy — `git.`, `nas.`, `mqtt.`. `ha.`, `gitea.` and
`grafana.` have no record either. The earlier note here that "a specific record beats the wildcard"
is true in general and was the wrong tool for this job.

**⛔ Never add `rewrite`, `handle_path`, or a stripped prefix to that vhost.** Digest hashes the
request URI, so any of those breaks authentication *while leaving the site apparently up*. Caddy
preserving Host and path by default is the only reason this works.

### ✅ Verification status — complete

Both acceptance criteria agreed with the homelab session are met, 1 Sep 2026:

1. **A complete authenticated Digest login through the vhost** — the PrusaLink Settings page
   renders fully at `https://prusalink.internal.example/#settings`. This is what proves the URI hashing
   survives the proxy; the earlier challenge-only test could not, because **a URI-rewrite failure
   and a bad password are indistinguishable — both return `401`.**
2. **An `/api/*` call carrying `X-Api-Key`** — `GET /api/version` returns `200` through the vhost,
   and a wrong key returns `403`, so the check discriminates.

Supporting evidence: the challenge arrives byte-identical to the direct one (same `realm`, `qop`,
`algorithm`, `nonce`, `opaque`), and the Caddyfile carries a bare `reverse_proxy` with no path
manipulation.

*(Chrome trusts the Caddy internal CA via the Windows store; `curl` in git-bash does not and needs
`-k`. That is a CA-bundle difference, not a problem with the vhost.)*


### ⛔ The printer is permanently LAN/VPN-only — a decision, not a caution

PrusaLink is beta software whose entire purpose is to **move the axes and drive the heaters**. A
compromise is not data loss; it is a physical event next to an ASA enclosure in a flat. TLS at the
proxy protects the transport, but the exposed thing would be the *application*, and that does not
improve. It sits with **pve** and **rc-panel** on the permanent exclusion list and stays off the
remote proxy's upstream allow-list. Reaching the printer from outside means **VPN in first**.

For context on the wider plan: external access is going to a **real domain with split-horizon
DNS** — same names inside and out, because apps like Jellyfin's store a single server URL.
`.internal.example` stays for LAN-only services. There is deliberately **no external wildcard**; the
remote proxy gets an explicit allow-list so it fails closed.

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
6. **Every Yasin3D profile is still vendor-data-free.** Widened 29 Aug 2026 rather than closed.
   The original complaint — `Yasin3D PLA @0.8 nozzle` is a bare clone of `Generic PLA @0.8 nozzle`
   with no calibration of its own — turns out to be the general case, not an oversight: **Yasin3D
   publishes no TDS, no SDS and no printing parameters anywhere**, and the retailer's product pages
   carry none either (searched 29 Aug 2026). The four new profiles added that day are explicit about
   it, and the ASA one is no better off than the PLA one — its "proper tuning" is Prusament ASA's,
   inherited, not measured.
   - What would actually close this: a temperature tower or a sample swatch per material. With no
     data sheet behind the numbers, that test *is* the data sheet.
   - Also unclosable by research: **Yasin3D PLA and ASA are no longer sold** by
     [filamentcenter.co.il](https://filamentcenter.co.il/) — their whole Yasin3D range is now PETG
     (₪39) and ABS (₪49). The ₪39 and ₪54 in those profiles are carried-over historical figures
     that cannot be re-verified.
7. ~~**The Inslogic ASA and TPU profiles carry their parent's price.**~~ **Fixed 29 Aug 2026** —
   kept for the reasoning. Not one of the seven set `filament_cost` at all: the four ASA files
   inherited Prusament ASA's ₪35.28 (about **half** the real price) and the three TPU files
   inherited ₪82 from `Generic FLEX` and ₪85 from `NinjaTek Cheetah TPU`. The TPU ones were the
   more dangerous pair — 82 and 85 against a real 79 look like deliberate figures, and the only
   tell was that all three disagreed with each other. Now set explicitly from
   [filamentcenter.co.il](https://filamentcenter.co.il/): **ASA ₪69, TPU 95A ₪79**, verified in
   the sliced G-code. The lesson worth keeping: **a key you never set is not a key with no
   value** — the flattener will hand it a parent's.
8. ~~**The stored PrusaLink API key is stale — remote upload is broken**~~ (found 17 Aug 2026,
   **FIXED 1 Sep 2026**). Both `physical_printer` entries held the *same* stale 14-character key
   and both endpoints rejected it with `403 Bad X-Api-Key`.
   - The diagnosis held up: not a CRLF artefact, and not an auth-*mode* problem. `GET /` returns
     `WWW-Authenticate: Digest realm="Administrator"`, which is the **web UI** login and is easy to
     misread as "PrusaLink switched to Digest". It hadn't — a `403 Bad X-Api-Key` on `/api/*`
     proves the API-key path existed and was evaluated. The key was simply wrong.
   - **Fixed by** reading the current key from `https://prusalink.internal.example` → Settings → API Key and
     writing it into both PrusaLink entries, which were also repointed at `prusalink.internal.example`.
     `printhost_authorization_type = key` was correct and unchanged.
   - **Verified end to end**, not assumed:
     ```
     GET https://prusalink.internal.example/api/version   X-Api-Key: <new>   -> 200  {"api":"2.0.0",...}
     GET http://<pi-address>/api/version       X-Api-Key: <new>   -> 200
     GET https://prusalink.internal.example/api/version   X-Api-Key: <old>   -> 403
     ```
     The third line is the one that makes the first two mean anything: a check that cannot fail
     proves nothing, so the old key was re-tested to confirm the endpoint still discriminates.

9. ~~**THREE THINGS ARE PENDING A DECISION**~~ — ✅ **9a AND 9b RESOLVED 11 Sep 2026; 9c REOPENED.** Kept for
   the reasoning, which outlived the tasks. Outcomes first:

   | | Outcome |
   |---|---|
   | **9a** Gitea GC | ✅ **DONE.** Repo 17 M → 283 K. Both superseded SHAs now **REFUSED** on fetch, verified from a throwaway clone. SSID and PDFs: 0 in full history. |
   | **9b** −50 statistics | ✅ **DONE.** Terminal sum corrected 68 → **18**, matching the node's own counter. |
   | **9c** persisted counter | 🔄 **REOPENED — answerable with one flash read, not yet read.** Closed at first as unprovable because the S3 was believed never to have rebooted. It has. See below. |

   ⛔ **THE GC DOES NOT MAKE THIS REPO PUBLISHABLE WITH HISTORY, and "9a done" must not be read
   that way.** The rewrites and the GC cleaned the **identifier** class — network name, addresses,
   device MACs, hostnames, and the copyright PDFs, all now 0 in full history. A second class, the
   **deployed-infrastructure inventory**, is **still present in reachable history**: three hardware
   product names, across eight commits, in file content rather than only commit messages.

   ⚠️ **A garbage collection can never fix these.** They live in commits that are **ancestors of
   `main`** — verified with `merge-base --is-ancestor`. Reachable objects are not garbage, so
   pruning does not touch them. Only a `filter-repo --replace-text` pass would, and that decision
   has not been taken.

   📋 **The strings themselves are deliberately NOT listed here.** They are held in the
   homelab repository, which is DO-NOT-PUBLISH. Ask there for the table.

   ⭐ **AND THAT OMISSION IS THE LESSON, LEARNED THE EMBARRASSING WAY.** The first version of this
   very section listed all three names in a table — and so *the commit documenting that the names
   were in history put the names in history*. Its table was wrong the instant it was written: it
   said one name appeared four times, and committing it made five. **A self-invalidating document**,
   and not fixable by correcting the count, because any correction increments it again.

   The rule generalises past redaction, which is where it was first noticed: **in a repository that
   may be published, NAMING the value is the leak — whether you are removing it, documenting it, or
   warning about it.** A removal commit concentrates the value in one labelled, greppable diff; a
   warning commit does the same and advertises itself with the exact words someone would search for
   when asking whether the repo is safe to publish. **Describe the class; never instantiate it.**

   ⚠️ **9c is the one to read — and it was first closed on a false premise.** The fix reached 18
   across a real outage, which only shows it COUNTS. The one thing it changed, that the value survives
   a boot, needed a reboot. This item recorded that the board never rebooted before being handed over,
   and closed as unprovable. **That was wrong:** it has since booted at least once (with an SD card
   inserted, per the session now holding it), so the test has already run. What has not happened is
   anyone reading the result.

   **It can only be read from flash, not from the running firmware.** No HTTP route exposes it, MQTT
   publishes it only on a good DHT read, and — contrary to what an earlier version of this repo said —
   it is **never printed to the serial console**: the disconnect warnings print a per-episode retry
   count that resets on every connect, not the lifetime value. The answer is in the NVS partition
   (namespace `wifinet`, key `drops`), read with `esptool read-flash` and parsed with ESP-IDF's
   `nvs_tool.py`.

   ⛔ **Download mode, not a reboot.** The ROM bootloader never runs the app, so NVS is untouched.
   Rebooting into the app can change the value — boot-time association failures increment it and the
   next IP acquisition saves it. So no serial terminal, no monitor, no power cycle before the read.

   ⛔ **The dump is a credential.** ESP-IDF persists the WiFi station config to NVS by default, so the
   same partition holds the network name and password in plaintext. Filter the parser output to
   `wifinet`, never commit the dump, delete it after.

   | Stored value | Meaning |
   |---|---|
   | **≥ 18** | the 18 survived a reboot — **persistence works, the fix is proven** |
   | 1 – 17 | restarted from 0 and re-accumulated — it writes but does not persist |
   | 0 or key absent | the save never wrote a nonzero value |

   **A deployment is still not a verification** — and a closure is only as good as the premise it
   rests on.

   It became unanswerable remotely for a reason worth carrying elsewhere: `main.c`'s `log_dht()`
   publishes the **entire** MQTT payload — counter, uptime and BSSID — only on a **good DHT read**.
   Removing the sensor took the diagnostics with it. **Never gate diagnostic publishing on a sensor
   read**: a failed probe is exactly when you want the device to still be talking.

   *Original text follows, because the reasoning is the useful part.*

   **9a. The Gitea garbage collection has NOT run, and the obvious commands do not work.**
   Two superseded commits — the pre-rewrite tip (`3f6babb`) and the post-rewrite-1 tip
   (`64e70dc`) — are **still fetchable from Gitea by full 40-char SHA**, and they carry the
   content two deliberate rewrites removed: the network SSID, and the four copyright-encumbered
   filament PDFs. Verified by fetching each into a throwaway repo.

   ⛔ **`git gc --prune=now` is a NO-OP here, and so is the Gitea admin "Garbage collect all
   repositories" button.** Both exit 0 and report success. The objects are unreferenced by any
   branch but **pinned by the reflog**, and gc treats reflog-referenced objects as reachable.
   Proof, on the bare repo: `git prune -n --expire=now` lists 510 objects and *neither SHA is
   among them*. The admin button is weaker still — `GC_ARGS` is unset, so git falls back to
   `gc.pruneExpire`, a 2-week default rather than "now".

   **The working sequence, and the order is the whole point:**
   ```
   git reflog expire --expire=now --expire-unreachable=now --all
   git gc --prune=now
   ```
   ⚠️ **Back up the bare repo as a DIRECTORY COPY first, not a bundle.** A bundle is built
   from refs, so it would capture the current tip and miss precisely the two unreferenced commits
   that are the entire reason for the operation. "Take a backup first" sounds complete, and the
   obvious kind of backup would not be.
   *Reassurance that makes this a smaller decision than it sounds:* the pre-rewrite history
   already survives off-Gitea in two local fallbacks under `Backups\`, so expiring the server
   reflog destroys the **server's** last copy, not the last copy.
   **Verify by result, never by exit code:** success is the fetch of a full SHA being *refused*,
   tested in a **throwaway** repo — never a working clone, because fetching an old SHA pulls those
   objects into the local store where they sit unreferenced and invisible to `git log --all`.

   **9b. The Home Assistant `wifi_disconnects` statistic is inflated by exactly +50.** Measured,
   not inferred: compiled sum 68 against a node counter of 18, through a real disconnect event.
   The cause is a per-boot counter published as `total_increasing`, since fixed in firmware. The
   correction is Developer Tools → Statistics → *Adjust sum*, by −50. **It should wait on 9c**,
   because if persistence turns out not to work the target moves again.

   **9c. The persisted-counter firmware is deployed but NOT PROVEN.** `app_elf_sha256`
   `ca8176f8b61bd346` is running (see [chamber-sensor](docs/chamber-sensor.md)). The counter has
   since reached 18 across a real outage — but *that only proves it counts*, which it did before
   the fix. The one thing the fix changed is that the value survives a reboot, and **the node has
   not rebooted** (15+ h uptime, no decrease). `drops_save()` has written to NVS; nothing has read
   it back.
   **The only test is a reboot**, and the firmware exposes no reboot endpoint — it serves `/`,
   `/ota` and `/raw` and nothing else — so it means a power cycle or re-flashing the same image.
   Comes back **18** → the fix works and 9b can proceed. Comes back **0** → `drops_save()` is not
   firing.


---

## Quick paths

```
Models          %USERPROFILE%\OneDrive\3D printing\
Slicer config   %USERPROFILE%\AppData\Roaming\PrusaSlicer\
CAD library     %USERPROFILE%\Code\print_scripts_tree_d\
Print station   %USERPROFILE%\Tools\homelab\docs\manual\print-station.md
Fume fan        %USERPROFILE%\Tools\homelab\docs\manual\fume-fan-esp32.md
PrusaLink       http://prusalink.local          (mDNS to the Pi)
Home Assistant  https://ha.internal.example
MQTT broker     mqtt.internal.example:1883
```

---

_Parts of this repository were drafted with the help of an LLM agent; reviewed and verified locally._
