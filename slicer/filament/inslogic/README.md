# Inslogic filament profiles — Prusa MK3S+

PrusaSlicer filament profiles for **Inslogic ASA**, **TPU 95A**, **PLA Pro** and **PETG Pro**,
built from Inslogic's own Technical Data Sheets (all rev. 12.02.2024, archived in
[`../../reference/`](../../reference/)).

Inslogic's [download center](https://www.inslogic3d.com/pages/download-center) publishes
**TDS/SDS data sheets only — no slicer profiles**, for any slicer. These were derived from
the data sheets by hand.

**Name the grade, not the material.** Inslogic sells eight different PLA products — PLA Pro,
Matte, Silk PLA+, Silk Dual/Tri/Four Colour, High-Speed Marble, Nebulux, LW-PLA and WoodFill
— and two PETGs, PETG Pro and the carbon-filled PETG-CF10. Each has its own data sheet.
These profiles cover the plain **Pro** grades only, which is why they are named
`Inslogic PLA Pro` and not `Inslogic PLA`: if the spool on the shelf turns out to be Matte or
Silk, the profile name is what surfaces the mismatch before the print does.

> **Print-validated: `Inslogic ASA - thin wall` (29 Jul) and `Inslogic TPU 95A - fast` (30 Jul).**
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

Two things leak *into* a flattened preset that should not, both found on 29 Aug 2026 while
building the PETG profiles:

- **`renamed_from`.** `Generic PETG` carries `renamed_from = "Generic PET"`, a vendor-bundle
  migration key. Resolving the chain drags it into the child, so every PETG profile built this
  way claimed to *be* the renamed `Generic PET` — four of them at once. `flatten_profiles.py`
  now strips it, the same way it strips `inherits`.
- **A parent compatibility condition you didn't read.** `Prusament PETG` sets
  `nozzle_diameter[0]!=0.6` on top of the usual `!=0.8`, so anything inheriting it silently
  vanishes from the filament list on a 0.6 nozzle — which Inslogic's sheet explicitly
  supports. `Generic PETG` has no such clause. That is the *only* reason the PETG profiles here
  inherit Generic rather than Prusament; the two are otherwise identical apart from temperature
  and price, both of which get overridden anyway.

And one thing the key-count check will show that is *not* a fault: a preset PrusaSlicer has
itself rewritten can come back with **more** than 85 keys. The installed `Inslogic ASA` read 87
on 29 Aug 2026 — 2.9.4 had added `filament_flush_speed` and `filament_flush_volume` when it last
saved the file. That is upstream drift, not sparseness; **the number to be alarmed by is a low
one.** (Reinstalling from this folder later that day put it back to 85. Both keys are
multi-material flushing settings, irrelevant on a single-extruder MK3S+, and PrusaSlicer re-adds
them on its next save.)

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

### What a flow cap is worth in mm/s — and the cross-section that converts it

**An extrusion is not a rectangle.** PrusaSlicer models the bead as a rectangle with
semicircular ends, so at `0.45 × 0.2 mm` the cross-section is

    0.2 × (0.45 − 0.2) + π × 0.1² = **0.0814 mm²**

not the 0.090 mm² that width × height suggests — a 10 % error, always in the direction of
*understating* the speed a given flow cap buys. (This paragraph said 0.090 mm² and 44 mm/s until
29 Aug 2026.)

So 4.0 mm³/s buys **49 mm/s**, which sits just *above* this machine's `perimeter_speed = 45`
and well below its 80 mm/s infill.

**Measured, not derived.** Slicing a solid 40 mm cube with this profile emits perimeters at the
full 45 mm/s and infill throttled to exactly **49.1 mm/s**; the stock 1.2 mm³/s profile throttles
everything to **14.7 mm/s**. Both match the formula to three figures, which is what makes the
0.0814 the right number and the 0.090 the wrong one.

The cap therefore binds on infill only — hence 1.73× rather than the 2.16× a thin swatch
predicted. Expect larger gains on infill-heavy parts.

### The same arithmetic for everything else on the shelf

At 0.4 nozzle, 0.2 mm layers, 0.45 mm width:

| Filament | Cap | Top speed it permits | Binds anything in these print profiles? |
|---|---|---|---|
| `Inslogic PLA Pro` | 15 mm³/s | 184 mm/s | No |
| `Inslogic ASA` | 11 mm³/s | 135 mm/s | No |
| `Inslogic PETG Pro` | 8 mm³/s | 98 mm/s | No |
| `Inslogic TPU 95A - fast` | 4.0 mm³/s | 49 mm/s | Infill only |
| `Inslogic TPU 95A` | 1.2 mm³/s | 15 mm/s | Everything, first layer included |

The fastest move any print profile in this repo asks for is **80 mm/s infill, which needs only
6.5 mm³/s**. That is why a solid 40 mm cube takes **1 h 37 m in PLA, ASA *and* PETG — the three
finish within six seconds of each other** (measured 29 Aug 2026). Their flow ceilings are real
but dormant, and the ranking PLA > ASA > PETG only wakes up past ~98 mm/s, where PETG throttles
first.

TPU is the only filament here whose ceiling is doing anything: the same cube is 1 h 39 m on
`- fast` (+3 %) and **3 h 54 m on the stock profile — 2.4×**.

**Not established:** whether 4.0 is the real limit. It was borrowed from Cheetah's rating, not
found by testing this filament to its edge.

## `Inslogic ASA - thin wall` — the one that's been proven on a real print

Built 28 Jul 2026 after a vase-mode stem (21.8 mm tube, 147 mm tall, single wall, 727 layers)
printed non-uniform on its rear face using the general-purpose `Inslogic ASA` profile.

Measured from the sliced G-code, before and after:

| | Layer time | Speed | Fan | Nozzle | Print time |
|---|---|---|---|---|---|
| `Inslogic ASA` | 5.01 s | 13.7 mm/s | 20 % | 255 °C | 1 h 12 m |
| `Inslogic ASA - thin wall` | **10.01 s** | 6.8 mm/s | **70 %** | 250 °C | **2 h 09 m** |

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

## `Inslogic PLA Pro` and `Inslogic PETG Pro` — one rule, two deviations

Added 29 Aug 2026 from the PLA Pro and PETG Pro data sheets. Both are the plain grades sold by
[filamentcenter.co.il](https://filamentcenter.co.il/), Inslogic's Israeli distributor:
**PLA Pro ₪59/kg** and **PETG Pro ₪49/kg**, incl. VAT, checked 29 Aug 2026. Those are the
numbers in `filament_cost`.

### The rule the temperatures follow

Inslogic states nozzle temperature as **speed-dependent bands**, not a single number, so the
only real decisions are which band this printer sits in and where in it to land:

> **Print temperature = the top of the TDS band for the throughput this printer actually runs.
> First layer = whatever the Prusa parent does relative to that, as long as the result is still
> a temperature the sheet sanctions somewhere.**

The reason to trust that rule is not that it sounds tidy — it is that applying it reproduces
the ASA and TPU choices already made in this folder, months earlier and by hand.

| Profile | Band used | Print | First layer | Why that first layer |
|---|---|---|---|---|
| `Inslogic PLA Pro` | 195–205 °C @ 50–100 mm/s | **205** | **210** | Parent does +5, and 210 is inside the sheet's faster band |
| `Inslogic PLA Pro @0.8 nozzle` | 205–220 °C @ 100–300 mm/s | **220** | **220** | Parent's 230 is above anything the sheet sanctions → **clamped** |
| `Inslogic PETG Pro` | 230–240 °C @ 50–100 mm/s | 240 | 240 | Parent already sits exactly there — no override in the file |
| `Inslogic PETG Pro @0.8 nozzle` | 240–255 °C @ 100–300 mm/s | 250 | 240 | Parent runs the first layer *cooler* at 0.8; that is Prusa's own choice for PETG and 240 is the top of the slow band, so it stands |

A 0.8 nozzle moves roughly four times the material per second at the same head speed, which is
why it reads against the faster band even though the head is not moving faster. Same reasoning
as `Inslogic ASA @0.8 nozzle`.

Note what the rule produces for PETG: **nothing**. Both PETG profiles override no temperature
at all, because Prusa's Generic PETG chain already lands on the vendor's numbers. A profile
that changes less than expected is the good outcome, not a sign the work was skipped.

### Deviation 1 — PETG fan stays at 30/50 %, not the sheet's 100 %

The ASA judgment call below calls the sheet's 100 % "what reads like a template default." With
four sheets in hand it is no longer a suspicion: **ASA, TPU 95A, PLA Pro and PETG Pro all say
100 %** — four materials whose cooling needs are nothing alike, one number. It is boilerplate.

PETG therefore keeps Prusa's 30 % min / 50 % max, because heavy part cooling is the standard
way to destroy PETG layer adhesion. **PLA is the one material where the 100 % is right**, and
there the parent already runs 100 %, so no fan override appears in that file either.

### Deviation 2 — PETG bed at 70 °C, against Prusa's 85/90

Inslogic says 60–70 °C; Prusa's PETG profiles run 85 °C first layer / 90 °C. These profiles
take the vendor's ceiling, **70/70** — the same "hottest the vendor sanctions" logic as the ASA
bed below, but with a second argument the ASA case does not have: **PETG bonds to smooth PEI
above roughly 85 °C hard enough to tear PEI off the sheet on removal.** Here the
vendor-faithful number is also the one that protects the sheet.

If the first layer will not stick at 70 °C, raise toward 85/90 — and lay down a thin glue-stick
release layer first. The glue is what makes the hotter bed *safe*; it is not what makes it
work.

---

## Status

ASA and TPU installed 28 Jul 2026; PLA Pro and PETG Pro **29 Aug 2026**. All copied into
`%APPDATA%\PrusaSlicer\filament\` and verified end-to-end: each slices a real part with exit 0
and the G-code carries the intended temperatures and the `M900` Linear Advance line.

| Profile | Nozzle °C | Bed °C | Fan min/max | Max vol. | Density | ₪/kg |
|---|---|---|---|---|---|---|
| `Inslogic ASA` | 255 | 100 | 20 / 20 | 11 | 1.05 | 69 |
| `Inslogic ASA @0.8 nozzle` | 265 | 100 | 20 / 20 | 15 | 1.05 | 69 |
| `Inslogic ASA - thin wall` | 250 | 100 | 70 / 70 | 11 | 1.05 | 69 |
| `Inslogic ASA - thin wall, flat base` | 250 | 100 | 70 / 70 | 11 | 1.05 | 69 |
| `Inslogic TPU 95A` | 210 | 50 | 100 / 100 | 1.2 | 1.23 | 79 |
| `Inslogic TPU 95A @0.8 nozzle` | 215 | 50 | 100 / 100 | 4.3 | 1.23 | 79 |
| `Inslogic TPU 95A - fast` | 225 | 50 | 100 / 100 | 4.0 | 1.23 | 79 |
| `Inslogic PLA Pro` | 205 (first 210) | 60 | 100 / 100 | 15 | 1.20 | 59 |
| `Inslogic PLA Pro @0.8 nozzle` | 220 | 60 | 100 / 100 | 15 | 1.20 | 59 |
| `Inslogic PETG Pro` | 240 | 70 | 30 / 50 | 8 | 1.26 | 49 |
| `Inslogic PETG Pro @0.8 nozzle` | 250 (first 240) | 70 | 30 / 50 | 20 | 1.26 | 49 |

### Prices — fixed 29 Aug 2026, and the reason they were wrong

The four PLA/PETG profiles were built with a real price in them. The seven older ASA and TPU
ones **never set `filament_cost` at all**, and so silently carried whatever their Prusa parent
charged:

| Profile | Was | Where that number came from | Now |
|---|---|---|---|
| all four ASA | ₪35.28 | `Prusament ASA` | **₪69** |
| `Inslogic TPU 95A` (+ @0.8) | ₪82 | `Generic FLEX` | **₪79** |
| `Inslogic TPU 95A - fast` | ₪85 | `NinjaTek Cheetah TPU` | **₪79** |

ASA was costing out at roughly **half** what the spool actually costs. The TPU numbers looked
plausible — 82 and 85 against a real 79 — which is worse than being obviously wrong: a
believable inherited number reads as a deliberate one. The tell was that **all three TPU files
disagreed with each other** while none of the three matched a price anyone had ever paid.

Real prices are Inslogic's Israeli distributor,
[filamentcenter.co.il](https://filamentcenter.co.il/), checked 29 Aug 2026, per 1 kg spool
incl. VAT: **ASA ₪69 · TPU 95A ₪79 · PLA Pro ₪59 · PETG Pro ₪49**.

`filament_cost` is now an explicit override in every sparse master here, so it can no longer be
supplied by a parent without anyone noticing. The general rule: **a key you never set is not a
key with no value.**

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
conditions — it's why each material needs two files rather than one.

---

## What the data sheets actually say

| | **ASA** | **TPU 95A** | **PLA Pro** | **PETG Pro** |
|---|---|---|---|---|
| Diameter | 1.75 ± 0.02 mm | 1.75 ± 0.03 mm | 1.75 ± 0.02 mm | 1.75 ± 0.02 mm |
| Density | 1.05 g/cm³ | 1.23 g/cm³ | 1.20 g/cm³ | 1.26 g/cm³ |
| **Drying** | **80 °C, 4 h** | **50 °C, 4 h** | **50 °C, 4 h** | **50 °C, 4 h** |
| Nozzle sizes | 0.2 / 0.4 / 0.6 mm | 0.4 / 0.6 mm | 0.2 / 0.4 / 0.6 mm | 0.2 / 0.4 / 0.6 mm |
| Nozzle temp | 250–260 °C @ 50–100 mm/s<br>260–280 °C @ 100–200 mm/s | 190–210 °C @ 50–80 mm/s<br>210–230 °C @ 80–120 mm/s | 195–205 °C @ 50–100 mm/s<br>205–220 °C @ 100–300 mm/s | 230–240 °C @ 50–100 mm/s<br>240–255 °C @ 100–300 mm/s<br>255–270 °C @ 300–600 mm/s |
| Bed temp | 80–100 °C | 50–60 °C | 50–60 °C | 60–70 °C |
| Bed type | Smooth PEI / high-temp plate | **Textured PEI** / cool plate | **Textured PEI** / cool plate | Smooth PEI / high-temp plate |
| **Cooling fan** | **100 %** | **100 %** | **100 %** | **100 %** |
| Other | Tg 108 °C · HDT 98 °C · shrinkage 0.4–0.9 % | Shore 95A · HDT 53 °C · elongation 1050 % | Tg 65.3 °C · HDT 55 °C · tensile 56 MPa · Izod 20.1 kJ/m² | Tg 65.5 °C · HDT 72 °C · tensile 50 MPa · Izod 4.8 kJ/m² |

**Read the cooling-fan row across.** Four materials — a warp-prone styrenic, a soft elastomer,
a PLA and a PETG — and one number. That row is a template default, and it is the single figure
on these sheets that gets overridden most.

**No sheet lists a 0.8 mm nozzle.** The `@0.8 nozzle` profiles exist because that's how this
printer is often run here, not because Inslogic supports it.

---

## The judgment calls

Everything else is a straight transcription of the TDS. These are not, and are the places to
look first if a print goes wrong. The PLA/PETG pair — the PETG fan and the PETG bed — has its
own section above; the three below are the ASA and TPU ones.

### 1. ASA fan is 20 %, not the TDS's 100 %

The single biggest deviation, and deliberate. **100 % part cooling on ASA warps and
delaminates parts on an open-frame MK3S+.** ASA wants heat retention; that's the whole
reason the Lack enclosure exists. The 100 % figure appears identically on **all four**
Inslogic sheets — ASA, TPU 95A, PLA Pro and PETG Pro — which settles it as a template default
rather than an ASA-specific recommendation.

Both ASA profiles instead use the Prusament ASA values — **20 % fan, off for the first
4 layers** — which is what the working `Yasin3D ASA @0.8 nozzle` profile on this machine
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
| `Inslogic PLA Pro` | 205 / first layer 210 | 60 / 60 | 0.4 runs 45–80 mm/s → the 195–205 °C band; 205 is its top. The parent's 210 is above what the sheet sanctions at that speed |
| `Inslogic PLA Pro @0.8 nozzle` | 220 / 220 | 60 / 60 | ~4× the throughput → the 205–220 °C band. First layer **clamped** from the parent's 230, which the sheet never sanctions |
| `Inslogic PETG Pro` | 240 / 240 | 70 / 70 | 0.4 sits in the 230–240 °C band; the Generic PETG parent is already exactly there |
| `Inslogic PETG Pro @0.8 nozzle` | 250 / first layer 240 | 70 / 70 | ~4× throughput → the 240–255 °C band. Prusa runs the 0.8 first layer *cooler*; 240 is the slow band's top, so it stands |

Note the TPU numbers are **below** the 225 °C the Ultrafuse profile uses. Inslogic's ceiling
is 230 °C, and only at speeds this printer won't reach.

Note also how little PETG needed: **neither PETG profile overrides a temperature.** The Prusa
chain already lands on the vendor's numbers, and the only real change is the bed.

---

## Before the first print

1. **Dry the filament** — ASA 80 °C/4 h; TPU, PLA Pro and PETG Pro all 50 °C/4 h. All are
   hygroscopic; TPU especially so, and wet TPU prints badly in ways easily mistaken for a bad
   profile.
2. **TPU: fit the textured PEI sheet.** On smooth PEI, TPU can bond hard enough to damage
   the sheet on removal. PLA Pro's sheet asks for the textured sheet too, and **PETG on smooth
   PEI is the other case that damages sheets** — see Deviation 2 above.
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
