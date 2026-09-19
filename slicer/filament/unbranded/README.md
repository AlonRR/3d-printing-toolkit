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
| `PETG Basic NPETG087-ZX` | `Generic PETG` | 240 | 75 | 30–50 % | 36 | 3 Sep 2026 |
| `PETG Basic NPETG087-ZX @0.8 nozzle` | `Generic PETG @0.8 nozzle` | 240 | 75 | 30–50 % | 36 | 3 Sep 2026 |

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

### ⏸️ The tower is built and DELIBERATELY not printed yet

`models/petg-temp-tower/petg-temp-tower.gcode` is sliced and ready — 2 h 41 m, 31.3 g, bands
220/230/240/250/260 baked in, base plate laid at 240 °C so adhesion is not the variable.

**Alon's decision, 3 Sep 2026: it waits for the active drybox** ([drybox-active](../../../docs/drybox-active.md)).
This is a sequencing choice, not a delay to work around:

- **Calibrating on wet filament measures the water, not the temperature.** Wet PETG strings and
  bubbles at *every* band, so the print would look decisive and be wrong — and a wrong number here
  gets written into a profile and trusted for months.
- The bed-at-50 °C method documented above genuinely works, but a spool dried that way **starts
  re-absorbing as soon as it comes off the bed**. Drying into a box that then *holds* it dry is what
  makes the tower's answer reproducible rather than a one-off.

So the drybox is now on the **critical path for this profile**, which is worth knowing when
prioritising its parts.

### Drying — 50 °C for 4 h, inherited

This filament publishes **no drying schedule**. The figure used is **50 °C for 4 hours**, taken from
**Inslogic's PETG Pro TDS** — a real vendor number for the same material, which is a better basis
than the 55–65 °C ranges quoted generically online. ⚠️ It is *inherited*, not this spool's own spec.

**Do not go hotter.** PETG's glass transition is around 80 °C, but spools deform and windings **fuse
together** well below that, and a welded spool is unrecoverable. 50 °C leaves 30 °C of headroom, and
the extra drying speed from 65 °C does not pay for the risk.

**Method, with equipment already on hand:** set the printer's **heated bed to 50 °C** from the LCD,
put the spool on it, cardboard box over the top, and leave a gap so moist air can escape rather than
recirculate. The bed is thermostatically controlled, which is exactly what this needs. Then straight
into a bag with desiccant, or straight into the print.

⛔ **Not a kitchen oven** — domestic ovens cycle far outside their setpoint at low temperatures, and
an overshoot to 90 °C is how spools fuse. ⛔ **Not inside the Lack enclosure** — the Einsy board and
PSU sit in that frame, and there is no print here to justify cooking them for six hours.

*Drying fixes a wet spool; storage stops you needing to.*

### Density is an assumption

`filament_density = 1.27` is the generic figure for PETG, **not a spec**. It feeds cost-per-volume
and the filament-used estimate, so if either matters, weigh a known length and correct it.

### The bed temperature is the one number backed by a print

The label permits **90 °C**, and that is more tempting than the Inslogic case precisely because it
is *inside* vendor spec. Being inside spec changes nothing about the sheet: PETG at that
temperature bonds to a smooth PEI sheet strongly enough to **tear PEI off it on removal**.

These profiles run **75/75 °C**, 5 °C above the bottom of the label's range. That number is
measured on this printer rather than inherited: the schubox warped at 70/70, and the lid printed at
75/75 with no warping — same filament, same sheet, same large flat-bottomed geometry, so the bed
temperature is the variable that changed. It is the one setpoint in these profiles backed by a
print instead of by a data sheet; the Inslogic PETG profile settled on 70/70, and this is where the
two deliberately part company. If the first layer will not stick, raise toward 85/90 — and put
down a thin glue-stick release layer first, which is what makes the higher bed *safe* rather than
what makes it *work*.

## Cost

36 ₪/kg — at the assumed 1.27 g/cm³ that is **0.046 ₪/cm³, the cheapest filament in this repo by
volume**, about 8 % under Yasin3D PETG which previously held that position.

Bought as a 10 kg bundle: *"PETG Basic — Black & White"*, a bundle order, 29 Aug 2026,
360 ₪ at a bundle rate. Five black spools and five white.

⚠️ **10 kg of PETG is now the largest single holding in the lab, and PETG is hygroscopic.** No
drying schedule is published for it. Storage matters more than it did.
