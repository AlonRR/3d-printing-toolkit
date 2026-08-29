# Yasin3D filament profiles — Prusa MK3S+

Six PrusaSlicer profiles for **Yasin3D PLA, PETG and ASA**, at 0.4 and 0.8 nozzle.

**Read this before trusting a number in them.** Unlike the
[Inslogic profiles](../inslogic/README.md), which are transcribed from published data sheets,
**Yasin3D publishes nothing** — no TDS, no SDS, no slicer profile, no printing parameters even
on the retailer's product page. Searched 29 Aug 2026 and found nothing beyond marketing copy.

So the honest description of every one of these files is: **Prusa's generic profile for that
material, with the vendor name, price and spool weight filled in.** They are a correct starting
point, not a calibration. The temperatures, bed, fan, flow ceiling and density are Prusa's
figures for an unknown filament of that type — which is exactly what these are.

## The six profiles

| Profile | Parent | Nozzle °C | Bed °C | Fan | ₪/kg | Added |
|---|---|---|---|---|---|---|
| `Yasin3D PLA` | `Generic PLA` | 210 | 60 | 100 % | 39 ⚠️ | 29 Aug 2026 |
| `Yasin3D PLA @0.8 nozzle` | `Generic PLA @0.8 nozzle` | 220 | 60 | 100 % | 39 ⚠️ | pre-existing |
| `Yasin3D PETG` | `Generic PETG` | 240 | 85 / 90 ⚠️ | 30–50 % | 39 | 29 Aug 2026 |
| `Yasin3D PETG @0.8 nozzle` | `Generic PETG @0.8 nozzle` | 250 (first 240) | 85 / 90 ⚠️ | 30–50 % | 39 | 29 Aug 2026 |
| `Yasin3D ASA` | `Prusament ASA` | 260 | 110 | 20 % | 54 ⚠️ | 29 Aug 2026 |
| `Yasin3D ASA @0.8 nozzle` | `Prusament ASA @0.8 nozzle` | 265 | 110 | 20 % | 54 ⚠️ | pre-existing |

The 0.4-family profiles show up for any nozzle except 0.8; the `@0.8 nozzle` ones only when
the printer profile is set to 0.8. That's why each material needs two files, not one.

## The three things that are actually decisions

### 1. Prices — only PETG is a current listing

Yasin3D's Israeli seller is [filamentcenter.co.il](https://filamentcenter.co.il/). Checked
29 Aug 2026, their **entire** Yasin3D range is two products: **PETG 1 kg at ₪39** and
**ABS 1 kg at ₪49**. There is no Yasin3D PLA and no Yasin3D ASA in the catalogue.

So `filament_cost` splits two ways:

- **PETG — ₪39, verified today** against the live product page.
- **PLA ₪39 and ASA ₪54 — carried over** from the pre-existing `@0.8 nozzle` profiles, marked
  ⚠️ above. Those are historical figures of unknown date, not current prices, and they cannot
  be re-checked because the products are no longer listed.

### 2. The 0.4 profiles mirror the hand edits already in the 0.8 ones

The two pre-existing `@0.8 nozzle` profiles are not pure clones — each carries exactly one
deliberate change away from its Prusa parent, and the new 0.4 siblings reproduce it so the
pair behaves the same way at both nozzle sizes:

| Profile | Parent value | What the file uses | Mirrored into |
|---|---|---|---|
| `Yasin3D PLA @0.8 nozzle` | first layer 230 °C (print 220) | **first layer 220** — equal to print temp | `Yasin3D PLA`: first layer 210, equal to its 210 print temp |
| `Yasin3D ASA @0.8 nozzle` | first-layer bed 105 °C (bed 110) | **first-layer bed 110** — both layers at 110 | `Yasin3D ASA`: first-layer bed 110 |

Everything else in all six files is inherited, including `filament_density` — so the 1.24 /
1.27 / 1.07 figures are Prusa's generic values, never a Yasin3D measurement.

### 3. PETG inherits `Generic PETG`, not `Prusament PETG`

Not a preference. `Prusament PETG` carries `nozzle_diameter[0]!=0.6` in its compatibility
condition on top of the usual `!=0.8`, so a profile inheriting it **silently disappears from
the filament list on a 0.6 nozzle**. `Generic PETG` has no such clause. Beyond that the two
differ only in temperature and price. Same reasoning, same trap, as the
[Inslogic PETG profiles](../inslogic/README.md).

## Before the first print

1. **The PETG bed is 85 °C first layer / 90 °C, inherited.** That is hot enough for PETG to
   bond to a smooth PEI sheet strongly enough to pull PEI off it on removal. Use the textured
   sheet, or a thin glue-stick release layer, or drop the bed to 70–75 °C. The Inslogic PETG
   profiles take the last option because Inslogic's own data sheet sanctions 60–70 °C; there
   is no Yasin3D sheet to sanction anything, so the parent's value is left in place here
   rather than invented.
2. **Dry the filament.** No vendor drying spec exists; the usual figures for the material type
   apply — PLA and PETG around 50 °C, ASA around 80 °C, 4 h.
3. **ASA needs the enclosure and produces fumes worth extracting** — same conditions as the
   Inslogic ASA profiles.
4. **Run a temperature tower or a sample swatch** before committing to a long print. With no
   data sheet behind these numbers, that test *is* the data sheet.

## Building and reinstalling

These are generated, not hand-maintained. The sparse masters (`*.ini.sparse-bak`) hold only
the real overrides; [`../../../scripts/flatten_profiles.py`](../../../scripts/flatten_profiles.py)
resolves the Prusa chain and writes the complete 85-key presets, because **PrusaSlicer does
not resolve `inherits` in a user preset** — the single most important thing to know about this
folder, explained in full in the [Inslogic README](../inslogic/README.md).

```powershell
python scripts\flatten_profiles.py "Yasin3D PLA" "Yasin3D PETG"   # subset; no args = all

# then, with PrusaSlicer CLOSED (it rewrites its config folder on exit):
Copy-Item "$env:USERPROFILE\Tools\3d-printing\slicer\filament\yasin3d\*.ini" `
          "$env:APPDATA\PrusaSlicer\filament\"
```

The two pre-existing `@0.8 nozzle` files are **not** regenerated by that script and are
deliberately absent from its `JOBS` table — they are PrusaSlicer-written originals, not
flattened sparse masters, and running the script over them would rewrite them and leave a
misleading `.sparse-bak` that was never sparse.

---

**Status, 29 Aug 2026:** all six installed in `%APPDATA%\PrusaSlicer\filament\` and verified
by a real CLI slice of `3030-m3-v2.stl` — exit 0, intended temperatures in the G-code, `M900`
Linear Advance line present. **None has been print-validated**; no calibration print has been
run with any Yasin3D profile.
