# Inslogic filament profiles — Prusa MK3S+

PrusaSlicer filament profiles for **Inslogic ASA** and **Inslogic TPU 95A**, built from
Inslogic's own Technical Data Sheets (both rev. 12.02.2024, archived here as PDFs).

Inslogic's [download center](https://www.inslogic3d.com/pages/download-center) publishes
**TDS/SDS data sheets only — no slicer profiles**, for any slicer. These were derived from
the data sheets by hand.

> **Print-validated: `Inslogic ASA - vase` (29 Jul) and `Inslogic TPU 95A - fast` (30 Jul).**
> The rest are installed and slice correctly, but their *temperatures* are still derived from
> the data sheet rather than validated against a printed part. Treat those as a well-reasoned
> starting point.

## ⚠️ Hand-written presets MUST be flattened — `inherits` does not fill the gaps

**The single most important thing in this folder.** It broke every profile here silently, and
the failure is invisible to normal checks.

PrusaSlicer records `inherits` for the UI ("modified from X") but does **not** consult the
parent to supply missing keys when loading a user preset. Any key absent from the file takes
the **system default**, not the parent's value. A PrusaSlicer-written preset has **85 keys**;
the sparse `inherits` + overrides files originally written here had 16–22, so ~68 keys per
profile were silently wrong.

What was actually lost, none of it visible in a temperature check:

- **`start_filament_gcode`** — the `M900 K` **Linear Advance** calibration. Reduced to a bare stub.
- `filament_ramming_parameters` — generic instead of ASA/FLEX-specific
- `filament_retract_length` / `_speed`, `extrusion_multiplier`, `cooling_slowdown_logic`

The trap is that slicing *succeeds* and the keys you personally wrote all read back correctly,
so a spot-check passes. The tell is the key count, or a key the parent sets that you didn't.

**Regenerate with `flatten_profiles.py`** (kept alongside these files). It resolves the real
chain out of `PrusaResearch.ini` with precedence: reference template < resolved parent chain <
your explicit overrides. Sparse originals are preserved as `*.ini.sparse-bak`.

Quick check that a preset is sound:

```powershell
Get-ChildItem "$env:APPDATA\PrusaSlicer\filament\*.ini" | ForEach-Object {
  "{0,-32} {1,3}" -f $_.BaseName, (Get-Content $_.FullName | Where-Object { $_ -match '^[a-z_0-9]+ = ' }).Count
}
# anything well under ~85 is sparse and silently running on defaults
```

## `Inslogic TPU 95A - fast` — the flow ceiling was the profile, not the filament

Prusa rates `Generic FLEX` / `Ultrafuse TPU-95A` at **1.2 mm³/s** on MK3-family printers, but
rates the genuine high-speed grades — **NinjaTek Cheetah TPU (95A)** and **Overture High Speed
TPU** — at **4.0 mm³/s**. This profile inherits Cheetah to borrow that ceiling *and* its 1.5 mm
retraction (`Generic FLEX` uses 0), then applies Inslogic's TDS temperatures.

Tested on `VaseRose_5cm`, 30 Jul 2026:

| Profile | mm³/s | Retraction | Print time |
|---|---|---|---|
| `Inslogic TPU 95A` | 1.2 | 0 | 2 h 53 m |
| **`Inslogic TPU 95A - fast`** | **4.0** | **1.5 mm** | **1 h 40 m** — 1.73× faster ✅ |

**Standard Inslogic TPU 95A sustains 4.0 mm³/s on this MK3S+** — clean, no under-extrusion, no
grinding. So a dedicated high-flow grade is **not** needed on speed grounds.

Context for what that speed means: at `0.45 × 0.2 mm` (0.090 mm²), 4.0 mm³/s = **44 mm/s**,
which is essentially this machine's PLA perimeter speed (`perimeter_speed = 45`). PLA infill
runs 80 mm/s, so infill is where the cap still binds — hence 1.73× rather than the 2.16× a
thin swatch predicted. Expect larger gains on infill-heavy parts.

**Not established:** whether 4.0 is the real limit. It was borrowed from Cheetah's rating, not
found by testing this filament to its edge.

## `Inslogic ASA - vase` — the one that's been proven on a real print

Built 28 Jul 2026 after a vase-mode stem (21.8 mm tube, 147 mm tall, single wall, 727 layers)
printed non-uniform on its rear face using the general-purpose `Inslogic ASA` profile.

Measured from the sliced G-code, before and after:

| | Layer time | Speed | Fan | Nozzle | Print time |
|---|---|---|---|---|---|
| `Inslogic ASA` | 5.01 s | 13.7 mm/s | 20 % | 255 °C | 1 h 12 m |
| `Inslogic ASA - vase` | **10.01 s** | 6.8 mm/s | **70 %** | 250 °C | **2 h 09 m** |

**Result: markedly better.** ✅

**What that proves — and what it doesn't.** Three things changed at once (fan, layer time,
temperature), so which one carried the fix isn't isolated. The *direction* is conclusive
though: more cooling plus more solidification time improved it. Had a draft through the
enclosure's open vent side been **over**-cooling the rear face, tripling the fan would have
made it worse. It didn't. So the cause was **under-solidification** — ASA at 255 °C landing on
a bead ~5 seconds old that hadn't set — and the draft theory is ruled out as the primary cause.

Also settled: **70 % fan did not cause the ASA layer-bonding failure** that was the risk of
going that high. The 50 % fallback noted in the profile isn't needed.

Worth remembering for next time: the Inslogic TDS specifies **100 % fan**, and the
general-purpose profile deliberately overrides that to 20 % to stop warping on bulk ASA. For a
single wall with no cross-section to delaminate, the data sheet was closer to right than the
override was.

---

## Status — installed 28 Jul 2026

Copied into `%APPDATA%\PrusaSlicer\filament\` and verified end-to-end: PrusaSlicer lists all
four under `user_filament_profiles`, and each one slices a real part with exit 0 and emits
the intended values.

| Profile | Nozzle °C | Bed °C | Fan min/max | Max vol. | Density |
|---|---|---|---|---|---|
| `Inslogic ASA` | 255 | 100 | 20 / 20 | 0 (unlimited, from parent) | 1.05 |
| `Inslogic ASA @0.8 nozzle` | 265 | 100 | 20 / 20 | 15 | 1.05 |
| `Inslogic TPU 95A` | 210 | 50 | 100 / 100 | 1.2 | 1.23 |
| `Inslogic TPU 95A @0.8 nozzle` | 215 | 50 | 100 / 100 | 4.3 | 1.23 |

Verified with, e.g.:

```powershell
& "C:\Program Files\Prusa3D\PrusaSlicer\prusa-slicer-console.exe" --export-gcode `
  "$env:USERPROFILE\OneDrive\3D printing\usefull\3030-m3-v2.stl" `
  --printer-profile "Original Prusa i3 MK3S & MK3S+ 0.8 nozzle" `
  --print-profile  "0.40mm QUALITY @0.8 nozzle - NO Skirt" `
  --material-profile "Inslogic ASA @0.8 nozzle" `
  --output "$env:TEMP\test.gcode"
```

### Reinstalling (after editing the copies here)

PrusaSlicer rewrites its config folder on exit, so **close PrusaSlicer first** — otherwise
the running instance overwrites the new files when you quit it.

```powershell
Copy-Item "$env:USERPROFILE\Tools\3d-printing\slicer\filament\inslogic\*.ini" `
          "$env:APPDATA\PrusaSlicer\filament\"
```

The 0.4 profiles show up for any nozzle except 0.8; the `@0.8 nozzle` ones only when the
printer profile is set to 0.8. That's inherited from the parent profiles' compatibility
conditions — it's why there are four files and not two.

---

## What the data sheets actually say

| | **ASA** | **TPU 95A** |
|---|---|---|
| Diameter | 1.75 ± 0.02 mm | 1.75 ± 0.03 mm |
| Density | 1.05 g/cm³ | 1.23 g/cm³ |
| **Drying** | **80 °C, 4 h** | **50 °C, 4 h** |
| Nozzle sizes | 0.2 / 0.4 / 0.6 mm | 0.4 / 0.6 mm |
| Nozzle temp | 250–260 °C @ 50–100 mm/s<br>260–280 °C @ 100–200 mm/s | 190–210 °C @ 50–80 mm/s<br>210–230 °C @ 80–120 mm/s |
| Bed temp | 80–100 °C | 50–60 °C |
| Bed type | Smooth PEI / high-temp plate | **Textured PEI** / cool plate |
| Cooling fan | 100 % | 100 % |
| Other | Tg 108 °C · HDT 98 °C · shrinkage 0.4–0.9 % | Shore 95A · HDT 53 °C · elongation 1050 % |

Neither sheet lists a **0.8 mm** nozzle. The `@0.8 nozzle` profiles exist because that's how
this printer is often run here, not because Inslogic supports it.

---

## The three judgment calls

Everything else is a straight transcription of the TDS. These three are not, and are the
places to look first if a print goes wrong.

### 1. ASA fan is 20 %, not the TDS's 100 %

The single biggest deviation, and deliberate. **100 % part cooling on ASA warps and
delaminates parts on an open-frame MK3S+.** ASA wants heat retention; that's the whole
reason the Lack enclosure exists. The 100 % figure appears identically on both the ASA and
the TPU sheet, which reads like a template default rather than an ASA-specific
recommendation.

Both ASA profiles instead use the Prusament ASA values — **20 % fan, off for the first
4 layers** — which is what the working `YASIN ASA @0.8 nozzle` profile on this machine
already runs.

TPU **does** get the full 100 %: TPU doesn't warp, so the TDS is right there.

### 2. ASA bed at 100 °C is the top of vendor range, below Prusa's

Inslogic says 80–100 °C. Prusa's own ASA profile uses **105 first layer / 110 °C**. These
profiles use 100/100 — the hottest the vendor sanctions. If parts still lift, raising the
bed toward Prusa's 110 is the first fix, accepting that it leaves vendor spec.

### 3. TPU inherits `Generic FLEX`, not `Ultrafuse TPU-95A`

Worth understanding, because the existing `Ultrafuse TPU-95A - Copy` profile on this machine
is affected by it.

`Ultrafuse TPU-95A` sits at the end of this inheritance chain:

```
Ultrafuse TPU-95A → TPU-85A → TPU-64D → Ultrafuse TPC-45D → …
```

**TPC-45D is a near-rigid copolyester**, and it's where that branch's `filament_max_volumetric_speed = 15`
and `bed_temperature = 40` come from. Both get inherited all the way down to the soft 95A
profile unchanged.

Prusa's soft-TPU chain — `Generic FLEX` → `*FLEX*` — sets **1.2 mm³/s** and a **50 °C bed**
instead. That's a 12× lower flow ceiling, and the bed temperature matches Inslogic's stated
50–60 °C exactly.

So these profiles use the FLEX chain. Same reason applies at 0.8: **there is no
`Ultrafuse TPU-95A @0.8 nozzle` for the MK3 family at all** (those variants exist only for
MK4/MK4S/XL/COREONE), so `Generic FLEX @0.8 nozzle` is the only valid parent.

**Side effect worth checking:** the existing `Ultrafuse TPU-95A - Copy` profile carries that
inherited `filament_max_volumetric_speed = 15` and a 40 °C bed. For actual soft TPU on an
MK3S+ both are off — 15 mm³/s is unreachable through a Bondtech extruder with soft filament,
so in practice it means "no flow limit at all."

---

## Temperatures chosen, and why

| Profile | Nozzle | Bed | Reasoning |
|---|---|---|---|
| `Inslogic ASA` | 255 / first layer 260 | 100 / 100 | MK3S+ at 0.4 sits in the TDS's 50–100 mm/s band → 250–260 °C |
| `Inslogic ASA @0.8 nozzle` | 265 / 265 | 100 / 100 | 0.8 pushes far more material/sec → the 260–280 °C band. Matches the Prusament ASA @0.8 parent |
| `Inslogic TPU 95A` | 210 / first layer 215 | 50 / 50 | MK3S+ prints TPU well under 80 mm/s → the 190–210 °C band; 210 is its top, for best layer adhesion |
| `Inslogic TPU 95A @0.8 nozzle` | 215 / 220 | 50 / 50 | Higher flow puts it at the boundary between the two bands |

Note the TPU numbers are **below** the 225 °C the Ultrafuse profile uses. Inslogic's ceiling
is 230 °C, and only at speeds this printer won't reach.

---

## Before the first print

1. **Dry the filament** — ASA 80 °C/4 h, TPU 50 °C/4 h. Both are hygroscopic; TPU especially
   so, and wet TPU prints badly in ways easily mistaken for a bad profile.
2. **TPU: fit the textured PEI sheet.** On smooth PEI, TPU can bond hard enough to damage
   the sheet on removal.
3. **ASA: use the enclosure**, and mind the fumes — this is exactly the case the
   [fume-fan](../../../Tools/homelab/docs/manual/fume-fan-esp32.md) project is for.
4. **Print a temperature tower or one of the filament sample swatches** in
   `..\..\usefull\` (`ASA_filament_sample.3mf`, `TPU_filament_sample.stl`) before committing
   to a long print. Note the ASA one is a **.3mf** — it carries its own embedded config, so
   loading it will override the profile selection; re-pick the Inslogic profile after opening.
5. **Run a Live-Z check** if switching sheets — the tags in `..\..\usefull\` cover PETG at
   0.4 and 0.6.

When a profile is confirmed by a real print, replace the "UNTESTED" line in its
`filament_notes` with what was actually verified.
