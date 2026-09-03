# Unbranded OEM filament profiles — Prusa MK3S+

Profiles for filament that **has no manufacturer**. The folder is called `unbranded` because that
is the literal finding, not a placeholder for a brand nobody looked up.

## Why this folder exists

The repo's naming rule is *"name the grade, not the material"* — the profile name is what surfaces
a mismatch before the print does. That rule assumes a brand to name. Here there isn't one, so
**the SKU carries the identity instead**, and it goes in the filename: if a future carton arrives
with a different SKU, the mismatch shows up in the file listing rather than in a failed print.

## The profiles

| Profile | Parent | Nozzle °C | Bed °C | Fan | ₪/kg | Added |
|---|---|---|---|---|---|---|
| `PETG Basic NPETG087-ZX` | `Generic PETG` | 240 | 70 | 30–50 % | 36 | 3 Sep 2026 |
| `PETG Basic NPETG087-ZX @0.8 nozzle` | `Generic PETG @0.8 nozzle` | 240 | 70 | 30–50 % | 36 | 3 Sep 2026 |

Derived from [`Inslogic PETG Pro`](../inslogic/README.md) — same material, same `Generic PETG`
parent, same printer — with only the values this spool actually differs on changed. Deriving from a
known-complete flattened profile rather than writing one from scratch is deliberate: a hand-written
profile silently drops keys, and `inherits` is **not** resolved in user presets.

## ⚠️ PETG Basic NPETG087-ZX — read before trusting a number

**There is no brand.** Verified from the packaging, 3 Sep 2026: no manufacturer on the spool label,
none on the carton, none in the carton's parameter table. The carton is generic OEM — a printed
checklist of product lines (PLA Basic / PLA+ / PLA Pro / PLA Matte / PLA HS / PLA Rainbow / PLA Silk
/ PETG Basic / PETG HS / ABS / ASA / PA / TPU 95A) with a tick-box for whichever is inside.

```
SKU: NPETG087-ZX    Batch: B2204001W    Made in China, CE / RoHS / FCC / REACH
```

**It is not Fillamentum**, though it was described that way. Ruled out three ways:

1. Fillamentum *names* its PETG colours — Black Soul, Ghost White, Vertigo Grey — never "Basic".
2. Fillamentum publishes **235–255 °C / 65–75 °C at ±0.05 mm**; this spool says **230–260 °C /
   70–90 °C at ±0.03 mm**. Three mismatches.
3. 36 ₪/kg against a premium Czech brand selling at several times that.

### There is no TDS, and that changes the method

Every other profile in this repo is transcribed from a vendor data sheet. This vendor publishes
**none** — the product tabs are boilerplate ("store in a dry shaded place", "settings vary by
printer"). No density, no drying schedule, no mechanical data, no glass transition.

The spool label is the only real source:

| | |
|---|---|
| Printing temp | 230–260 °C |
| Bed temp | 70–90 °C |
| Diameter | 1.75 mm, ±0.03 mm *(carton)* |

**So this profile has to be settled by a calibration print, not by a document.** The numbers in it
are a defensible starting point and nothing more. `filament_notes` says so, and says
`UNTESTED` — as it should until a print has actually been run.

### Density is an assumption

`filament_density = 1.27` is the generic figure for PETG, **not a spec**. It feeds cost-per-volume
and the filament-used estimate, so if either matters, weigh a known length and correct it.

### The bed temperature is the one real judgement call

The label permits **90 °C**, and that is more tempting than the Inslogic case precisely because it
is *inside* vendor spec. Being inside spec changes nothing about the sheet: PETG at that
temperature bonds to a smooth PEI sheet strongly enough to **tear PEI off it on removal**.

These profiles start at **70/70 °C**, the bottom of the label's range and the same number the
Inslogic PETG profile settled on. If the first layer will not stick, raise toward 85/90 — and put
down a thin glue-stick release layer first, which is what makes the higher bed *safe* rather than
what makes it *work*.

## Cost

36 ₪/kg — at the assumed 1.27 g/cm³ that is **0.046 ₪/cm³, the cheapest filament in this repo by
volume**, about 8 % under Yasin3D PETG which previously held that position.

Bought as a 10 kg bundle: *"PETG Basic — Black & White"*, a bundle order, 29 Aug 2026,
360 ₪ at a bundle rate. Five black spools and five white.

⚠️ **10 kg of PETG is now the largest single holding in the lab, and PETG is hygroscopic.** No
drying schedule is published for it. Storage matters more than it did.
