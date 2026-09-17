# Moisture sorption isotherms — filament and desiccant

**Alon's framing was right and it changes the design conversation:** moisture uptake is not a
threshold, it is a **curve**. A material sitting in air at a given relative humidity comes to an
*equilibrium moisture content* on that curve, and the **shape** of the curve — not any single
number — decides what a filament does when stored and what a desiccant can achieve.

This page is the research behind the numbers used in [drybox-active](drybox-active.md).

## The model

The filament study fits every material to:

> **w<sub>∞</sub> = a · RH<sup>c</sup> + b**

and the exponent **c** is the whole story:

| c | Shape | Meaning |
|---|---|---|
| **c = 1** | straight line | **Henry's law.** Moisture is directly proportional to RH. No threshold, no cliff — halve the RH and you halve the water |
| **c > 1** | curves upward | **BET Type 3.** Uptake accelerates as RH rises; the material is disproportionately punished by damp storage |

## Filament — measured, per material

From a peer-reviewed study that equilibrated samples at 16, 47, 75 and 97 %RH and weighed them to
constancy. Δw is the total swing across that range.

| Material | c | Shape | **Δw over 16→97 %RH** |
|---|---|---|---|
| **PET-G** | **1.0** | **linear** | **0.696 %** |
| PLA | 1.0 | linear | 0.706 % |
| PC | 1.0 | linear | 0.550 % |
| ABS (white) | 1.76 | curved | **0.157 %** |
| **Nylon** | **2.0** | **strongly curved** | **8.127 %** |

Moisture held **above the 16 %RH baseline**, as a percentage of spool weight:

| Material | 20 % | 30 % | 40 % | 50 % | **65 %** | 80 % |
|---|---|---|---|---|---|---|
| PET-G | 0.034 | 0.120 | 0.206 | 0.292 | **0.421** | 0.550 |
| ABS/ASA | 0.003 | 0.014 | 0.028 | 0.044 | **0.074** | 0.110 |
| Nylon | 0.128 | 0.572 | 1.193 | 1.992 | **3.524** | 5.455 |

### Three consequences that actually matter here

**1. For PETG there is no "dry enough" line to cross.** Its isotherm is a straight line, so every
point of RH you remove buys the same fixed amount of water back. This is the direct answer to the
question that prompted this page: the number people quote as a drying threshold is a convention, not
a physical transition. **Storage RH and spool moisture are proportional, all the way down.**

**2. Nylon is a different problem, not a worse version of the same one.** At c = 2 it holds
**8.4× more water than PETG at 65 %RH**, and its curve steepens with humidity — so damp storage hurts
it disproportionately. Any rule of thumb derived from nylon horror stories over-states the PETG case
badly.

**3. ⭐ ASA barely cares, and this is a genuinely useful asymmetry.** ABS — the closest measured proxy
for ASA — swings only **0.157 %** across the entire humidity range, about **⅕ of PETG** and 1/50th of
nylon. The lab's ASA is far more forgiving of imperfect storage than its PETG. **The drybox should
be prioritised for the 10 kg of PETG, not for the ASA.**

### What that means in grams

PETG's slope is **0.0086 % of spool weight per point of RH**. For the lab's actual case — a 4-spool
box, ~4 kg:

| Storage improvement | Per kg | **For a 4 kg box** |
|---|---|---|
| 65 → 45 %RH | 1.7 g | 6.9 g |
| 65 → 30 %RH | 3.0 g | 12.0 g |
| **65 → 15 %RH** | **4.3 g** | **17.2 g** |

**~17 g of water** is the real target: what a drying cycle must drive out, and what the desiccant
must then hold to keep it out.

### ⏳ Equilibration is slow — days, not hours

Time to reach 80 % of equilibrium, for 2.8 mm cylinders at 97 %RH: **PLA 27 h, ABS 101 h, nylon
360 h.** Two practical consequences:

- **A spool left out for an afternoon has not absorbed much.** Moisture panic is usually overdone.
- **But a "quick dry" does not work at room temperature either.** The drybox's 50 °C matters as much
  for *diffusion rate* as for the humidity gradient — warm plastic gives up water far faster.

## Desiccant — three different curve shapes, three different jobs

⚠️ **This section corrects an error made earlier in this project.** I previously wrote that clay is
weaker than silica gel at low RH and that silica gel was the right purchase for a low-RH box.
**That is backwards.** Two manufacturer sources — including one that sells all three materials, so
has no axe to grind — state the opposite:

| Desiccant | Manufacturer's own wording | Curve shape |
|---|---|---|
| **Molecular sieve** | *"relatively high at low humidity levels and remains almost constant as relative humidity increases"* | **Rectangular** — steep, then flat |
| **Bentonite clay** | *"considerable even at low humidity levels & increases as relative humidity rises"* | Rising |
| **Silica gel** | *"relatively small at low humidity levels but increases as humidity rises"* | Rising, back-loaded |

Corroborated by a second supplier's stated peak-efficiency bands, which put them in the same order:
**molecular sieve 0–30 %RH · clay 30–60 % · silica gel 40–70 %.**

### 🔑 The shape decides the job, and it is not "which is best"

- **To HOLD a low RH**, you need capacity where the box already is — a curve that is steep at the
  *left*. That is molecular sieve, then clay. Silica gel is the weakest of the three there.
- **To ABSORB a lot of water from damp air**, you want the right-hand end. That is silica gel.
- Silica gel's popularity comes from the second job. **This box is the first job.**

### ✅ So the bentonite on hand is the better material, not the compromise

For a low-RH drybox, clay outranks silica gel. It is also the cheapest of the three, available in
bulk as cat litter, and regenerates at the lowest temperature of the three.

**Molecular sieve remains the only material that can hold the 5–15 % band comfortably**, and it is
worth knowing that if the band ever becomes a hard requirement. ⛔ **Evaluated 12 Sep 2026 and
deliberately NOT bought** — nothing owned needs that band (no nylon/PVA/PC), and PETG's linear
isotherm means 15→5 %RH recovers only ~3.4 g on a 4 kg load. See the parts table in
[drybox-active](drybox-active.md) and inventory `docs/shopping-list.md` §31. If it is ever bought,
**buy 4A, not the 3A every guide names.**

### 🌡️ Regeneration is a CURVE, not a setpoint

*(Alon, 12 Sep 2026.)* This corrects a fixed-number framing used earlier on this page and in
[drybox-active](drybox-active.md) step 6 — and it dissolves an apparent conflict between our own
documents, which said ~110 °C here and ~125 °C in the HomeBox record. **Both were right.**

| | Release begins | Substantially off | Full |
|---|---|---|---|
| **Bentonite clay** | ~90 °C | **~80 % at 120 °C** | ~150 °C |
| Silica gel | ~90 °C | — | ~150 °C |
| **Molecular sieve** | ~200 °C | — | **400–550 °C** |

⛔ **THE CLAY AND SILICA ROWS ABOVE ARE UNSOURCED — do not design to them.** Flagged 17 Sep 2026 by
the session that took over the module work, and confirmed here. **Three** things are wrong with them
— the struck-through fourth was an argument of mine that turned out not to hold, kept visible rather
than quietly deleted, because a retracted reason is itself worth knowing about:

- **They are not in this page's Sources, or anywhere in this repo.** The figures are reported to come
  from a vendor FAQ (Tropack) that was never cited. *I have not read that page myself* — the
  provenance is theirs; what I verified is that nothing in this repo cites it.
- ~~⭐ **Clay and silica gel carry the IDENTICAL pair, ~90 and ~150 °C.** Two materials with different
  binding energies cannot share regeneration temperatures.~~ ⛔ **RETRACTED 17 Sep 2026 — this
  argument is wrong, and it was mine.** Identical figures for the two materials are *normal* in
  primary sources: the maker's own MIL-D-3464 procedure assigns the **same** temperatures, 118.3 °C
  and 104.4 °C, to silica gel and bentonite clay alike. The physics was sloppy — binding energy
  governs how *much* water comes off at a given temperature, not what temperature a procedure tells
  an operator to set. A shared figure is evidence of nothing either way. **The conclusion stands on
  the other three points below; this one never supported it.**
- **The paragraph below contradicts the table four lines above it.** Süd-Chemie's own sheet says only
  *"Desi Pak products can be reactivated for multiple uses"* — no temperature at all. Read from the
  PDF directly, 17 Sep. So this page tabulated three regeneration figures and then stated that the
  manufacturer publishes none.
- **"~80 % at 120 °C" has no primary source at all.** Attributed by a search snippet to Gore patents;
  the session that chased it reports it appears in neither.

✅ **Use the sourced figures instead — they are already below:** Clariant's own Desi Pak procedure,
**118.3 °C for 24 h**, or **104.4 °C** non-MIL, and a peer-reviewed **150 °C through five cycles**.

⚠️ **This triplet has propagated.** `drybox-active.md` carries the same numbers. That file is owned
by the drybox session as of 17 Sep and has been told.

⭐ **Süd-Chemie, who make the clay, publish no regeneration temperature at all** — only *"can be
reactivated for multiple uses"*. That is precisely why every downstream figure differs. **So the
recorded dry MASS is the done-indicator, not the thermostat**: temperature alone cannot say how far
along the curve a bake got.

### ⚠️ Regeneration by BAKING and regeneration by a low-RH AIR SWEEP are different mechanisms

The table above — whatever its numbers turn out to be — is about **putting clay in an oven**. It is
**not** evidence about what an 80 °C air sweep does, and reading it that way is a category error the
cabinet design nearly inherited.

A sweep works on **relative** humidity, not temperature. Heat room air and its RH collapses: 25 °C at
55 %RH is roughly **4 %RH at 80 °C**. The clay then equilibrates toward that very low RH and gives up
water, at a temperature far below any bake figure. **That mechanism is already described on this
page** — see the drybox setpoint discussion below, where the same effect at 50 °C in ~17 %RH air
partially self-regenerates the bed during a drying cycle. The two sections had simply never been
connected.

⚠️ **One caveat that blocks borrowing Süd-Chemie's capacity curves number-for-number.** Their sheet
describes Desi Pak as *"a calcium-rich montmorillonite"* — verified from the PDF, 17 Sep. The clay on
hand is **sodium** bentonite, which binds water less strongly. The shapes transfer; the values do not.

⛔ **CORRECTED 12 Sep 2026 — "hotter is safe" was WRONG, and Alon caught the mechanism.** The
ceiling is about **degradation, not desorption**: heating immobilises the interlayer cations, and
*"even if water is added, the montmorillonite is not restored to the original state"*. So the clay
does not merely dry out — it stops being a desiccant.

| Activation temperature | Effect on capacity |
|---|---|
| natural → **300 °C** | capacity **rises** |
| **500 °C** | capacity **reduced**; *"dehydroxylation and irreversible modification of the expandable sheet structure were initiated"* |

⭐ **So the rule is BAKE LONGER, NEVER HOTTER.** Clariant's own Desi Pak procedure is **118.3 °C for
24 h**, or **104.4 °C** for non-MIL reactivation; a peer-reviewed study used **150 °C through five
cycles with no structural degradation**. Above ~300 °C you trade capacity away permanently and gain
nothing, because the water is long gone by then.

⛔ **CORRECTED 17 Sep 2026 — this page said "16–24 h", and the "16–" was invented downstream.** The
source is the MIL-D-3464 procedure reproduced in Sea-Bird Application Note 71, verified here by
decrypting the PDF and reading it, not on report. Step 4 is unambiguous: *"Desiccant bags should be
allowed to remain in the oven at the assigned temperature for **24 hours**."* Step 3 is *"Set the
temperature of the oven to **118.3 °C**"*. Searched the whole document: **`16` never appears as a
duration** — only in model numbers and one `40.6 cm (16 inches)` clearance — and `16-24`, `16 to 24`
and `sixteen` are all absent. A range that is not in the source is a range someone added.

⚠️ **Why my first attempt to check this failed, worth knowing before trusting a null result.** The
PDF is **encrypted** (owner-password AES, no user password), so its text sits in encrypted object
streams. Decompressing by hand recovers ~750 characters and looks exactly like a scanned document —
I wrote it off as "pages are images", which was wrong. `pypdf` with the `cryptography` backend reads
it fine: 7 pages, 14,499 characters. **"No text layer" and "I could not decrypt it" are different
findings and they look identical from the outside.**

✅ **The same step settles the retracted argument above, first-hand.** The non-MIL line reads
*"activation or reactivation of **both silica gel and Bentonite clay** … at 104.4 °C"* — one
temperature, two materials, in a primary source. That is the counterexample, and it is now read
rather than relayed.

⚠️ **The trap that produced an earlier error on this page, now visible in the source sentence.** The
118.3 °C setpoint is immediately followed by *"WARNING: Tyvek has a melt temperature of
121.1 – 126.7 °C"* — a limit on the **bag**, not on the clay, sitting a bare 3 °C above the process
temperature. That proximity is exactly how a packaging limit gets read as a material limit, and it
is what once made 400–600 °C look like the only ceiling that existed. The regeneration sheet is full
of such warnings; none of them are about the desiccant.

### Temperature: clay holds where silica gel fades

Between **20 °C and 50 °C at constant RH**, capacity as a function of temperature:

| | |
|---|---|
| Bentonite clay | **constant** |
| Molecular sieve | **constant** |
| Silica gel | **decreases slightly** |

⚠️ **50 °C is clay's boundary, not its comfort zone**, and it is a *separate* limit from
regeneration above — much lower, and **reversible**. Manufacturer wording: *"clay works
satisfactorily below ~50 °C; above that there is a possibility that the clay will **give
up moisture rather than pulling it in**"*, and *"clay gives up moisture readily back into the
container as temperatures rise."*

**The drybox setpoint sits exactly on that edge, and it cuts both ways.** The useful half: at 50 °C
in ~17 %RH air the clay is driven toward its low-RH equilibrium and **partially self-regenerates
during a drying cycle**, the released water leaving via the exhaust — so the desiccant is refreshed
rather than degraded by living in the box. The half that constrains the design: **during a heated
cycle the bentonite is not adsorbing at all.** Two consequences follow —

- ⭐ **The cooldown purge is load-bearing, not tidiness.** Seal the box while warm and the clay has
  just released its water into the air you trapped.
- ⛔ **Raising the setpoint above 50 °C makes the storage phase worse, not better**, however
  attractive "hotter dries faster" sounds.

⚠️ **Source spread, recorded rather than averaged:** sorbentsystems says **~50 °C**; Süd-Chemie
claims constant capacity only *between* 20 and 50 °C, bounding the claim without saying what happens
above it; Multisorb reads as **~32 °C** on a fresh read but is cited as 50 °C earlier on this
page — same source, two readings. Most say ~50 °C.

## Sizing the desiccant

For the 4 kg PETG case moving 65 → 15 %RH, **17.2 g of water**:

| Material | Assumed capacity | Bare minimum |
|---|---|---|
| Clay | 10 % | 172 g |
| Clay (pessimistic) | 5 % | 344 g |
| Molecular sieve | 20 % | 86 g |

⚠️ **"Bare minimum" means fully spent with zero margin, holding nothing back for ingress.** Real
sizing wants **3–5×** that, so **0.5–1.5 kg of bentonite** for this box. At cat-litter prices that is
trivially affordable, and over-sizing costs nothing but volume — it directly extends the interval
between regeneration bakes.

### Bulk density — the mass-to-volume step, and where it lives

Everything above sizes the desiccant by **mass**. A container is built to a **volume**. Bulk density
is the only bridge between the two, so it belongs here with the rest of the physics rather than
buried in a model.

| | |
|---|---|
| **Bentonite, granular, as poured** | **0.80 g/cm³** `<<CONFIRM>>` |
| Usual range for cat-litter clay | 0.7 – 0.9 g/cm³ |

⚠️ **This is an assumed typical figure, not a measurement, and the marker stays until it is one.**
It is carried here with its `<<CONFIRM>>` intact deliberately: a value tends to shed its caveat when
it moves into a document that reads as authoritative, and this one feeds a capacity number that
looks precise.

✅ **It does not have to stay assumed.** There is roughly **20 kg of the actual clay on hand**, so one
measurement settles it: fill a 1 L container as poured, level it off, weigh it. When that figure
exists it replaces the table above as **MEASURED, with the date** — not as a typical value.

**What depends on it.** `models/desiccant-cartridge/` computes
`capacity_g = cavity_cm3 × bulk_density × fill_factor`, which is where the cartridge's **499 g**
comes from, and it carries a WARN guard if the density falls outside 0.7–0.9.

⛔ **This page is the single source for the VALUE; the model necessarily holds a copy of the
NUMBER.** OpenSCAD cannot read Markdown, so `desiccant-cartridge.params.scad` keeps a literal that
is explicitly marked as derived from here. Change it in this table first, then update the params
file to match. Anything else — cabinet specs, firmware, notes — links here and holds no copy at all.

⚠️ **Do not re-derive capacity by hand from this number.** The first attempt at the cartridge sized
a 120 × 120 × 45 box from 500 g ÷ 0.8 = 625 cm³ and got **422 g**, because 625 cm³ of *clay* needs
more than a 625 cm³ *box* once walls, bosses and a 90 % fill factor are taken out. Take capacity from
the model's echo, which accounts for all three.

## Sources

- [Moisture Sorption and Degradation of Polymer Filaments Used in 3D Printing](https://pmc.ncbi.nlm.nih.gov/articles/PMC10304609/) — the isotherm coefficients, Δw values and equilibration times
- [Süd-Chemie / Clariant desiccant performance data](https://www.sisweb.com/art/pdf/desiccant-performance-information.pdf) — the low-RH wording and 20–50 °C temperature behaviour, from a maker of all three materials
- [Clariant — Desiccant Types and Performance](https://www.clariant.com/en/Solutions/Products/2014/09/10/00/28/DESICCANT-TYPES)
- [Multisorb — Comparing Silica Gel, Clay, and Molecular Sieves](https://www.multisorb.com/blog/choose-between-silica-clay-molecular-desiccants/) — peak-efficiency bands, capacity at 50 %RH, the >50 °C clay note
