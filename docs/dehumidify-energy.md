# Dehumidifying — the split AC versus a standalone dehumidifier

**Question asked 12 Sep 2026:** what does it cost to dehumidify with the inverter AC compared with a
dehumidifier? Answered from the unit's **own design & technical manual**, not from generic figures.

## ⭐ The answer, and it is seasonal rather than absolute

Per **litre of water removed** — the only fair unit, since the two machines have different capacities:

| Season | AC | Dehumidifier | Winner |
|---|---|---|---|
| **Summer** (cooling wanted anyway) | **1.85 – 2.31 L/kWh** | **0.90 – 1.41 L/kWh** | ⭐ **AC, by ~1.5–2×** |
| **Winter / shoulder** (heating wanted, or nothing) | **≲1.3 L/kWh** ⚠️ *constructed* | **2.79 – 8.04 L/kWh** | ⭐ **Dehumidifier, by 2–6× or more** |

**The reason is not efficiency, it is where the heat goes.** Both machines are the same device — a
refrigeration loop condensing water on a cold coil. The difference is where the condenser sits:

- **The AC throws its heat outdoors.** In summer that is exactly what you want.
- **A dehumidifier throws all of it back into the room** — its own power input *plus* the ~0.68 kW of
  condensation heat released per litre per hour. It is a heater that drips.

Each one's waste product is the other's problem, and the season decides which one you can afford.

## The machine, from its own manual

Fujitsu **ASYG12LMCE** indoor / **AOYG12LMCE** outdoor, R410A inverter split, manufactured Jul 2017.

| | Value |
|---|---|
| Cooling capacity, rated | **3.40 kW** (min–max **0.9 – 3.9 kW**) |
| Input power, rated | **0.97 kW** (min–max **0.25 – 1.40 kW**) |
| **Sensible** capacity | **2.20 kW** → **SHR 0.65** |
| **Latent** capacity (derived) | **1.20 kW** |
| **Moisture removal** | **1.8 L/h** — stated directly in the manual |
| EER / SEER | 3.50 / 7.00 (class A++) |
| Indoor fan | 6 W quiet … 32 W high — negligible either way |

### ✅ The manual's numbers corroborate each other

Worth checking rather than trusting a single line. Latent capacity is 3.40 − 2.20 = **1.20 kW**; at a
latent heat of vaporisation of ~2450 kJ/kg that predicts **1.76 L/h**. The manual separately states
**1.8 L/h**. The two agree to **2 %**, and they come from different parts of the document — so the
moisture figure is real rather than a marketing number.

The capacity table's 35 °C / 27-19 °C cell reads **3.40 / 2.18 / 0.97**, matching the specification
page exactly. Table and spec sheet are consistent.

## What the AC actually does, across its whole rated range

Computed from every cell of the manual's cooling-capacity table (§4-1, AFR 750 m³/h), as **L/kWh**:

| outdoor ↓ / indoor → | 18 °C | 21 °C | 23 °C | 25 °C | 27 °C | 29 °C | 32 °C |
|---|---|---|---|---|---|---|---|
| **20 °C** | 2.23 | 2.98 | 2.77 | 3.28 | 3.07 | 3.57 | **3.72** |
| **25 °C** | 1.88 | 2.46 | 2.33 | 2.73 | 2.60 | 3.01 | 3.10 |
| **30 °C** | 1.57 | 2.08 | 1.98 | 2.31 | 2.21 | 2.55 | 2.64 |
| **35 °C** | 1.33 | 1.76 | 1.65 | 1.94 | 1.85 | 2.14 | 2.23 |
| **40 °C** | 1.06 | 1.47 | 1.37 | 1.62 | 1.52 | 1.79 | 1.85 |
| **43 °C** | **0.96** | 1.32 | 1.24 | 1.47 | 1.39 | 1.63 | 1.68 |

**A 3.9× spread on one machine, from conditions alone.** Hot day into a cool room is the worst case;
mild day into a warm room the best. Any bare "the AC gets X L/kWh" claim is meaningless without both
temperatures attached.

⚠️ **This table cannot answer the low-humidity question, and that is the one that matters here.**
Every rated point sits at **46–52 %RH**, so the columns vary by *temperature*, not by humidity —
warmer air simply holds more water, so more of it condenses. **Nothing in the manual describes
behaviour at the 30–40 %RH a filament room would be held at**, and moisture removal falls off steeply
as the air dries.

## The thermal asymmetry, computed both ways

Per 1 L/h removed, condensation alone releases **0.68 kW** into whichever room the coil sits in.

**Summer** — the dehumidifier's heat must then be removed again by the AC at EER 3.50:

| Dehumidifier grade | Draws | Dumps into room | AC burns extra | **Effective** |
|---|---|---|---|---|
| Energy Star floor, IEF 1.40 | 714 W | 1.39 kW | 399 W | **0.90 L/kWh** |
| Typical certified, IEF 1.77 | 565 W | 1.25 kW | 356 W | **1.09 L/kWh** |
| Most Efficient, IEF 2.50 | 400 W | 1.08 kW | 309 W | **1.41 L/kWh** |

Against the AC's **1.85–2.31 L/kWh** at realistic local summer conditions, the AC wins throughout —
**even against a best-in-class dehumidifier.**

**Winter** — the same heat is now useful, offsetting heat-pump heating at COP 3.92, while the AC's
dry mode strips out sensible heat that must then be bought back:

| | Effective |
|---|---|
| Dehumidifier, IEF 1.40 | **2.79 L/kWh** |
| Dehumidifier, IEF 1.77 | **4.04 L/kWh** |
| Dehumidifier, IEF 2.50 | **8.04 L/kWh** |
| **AC dry mode**, 0.9 kW min capacity, reheating at COP 3.92 | **≲1.3 L/kWh** ⚠️ |

The ranking inverts completely. That is why "which is cheaper" has no season-free answer.

⚠️ **The AC's winter figure is CONSTRUCTED, and the three dehumidifier rows are not.** Those three are
plain arithmetic on a published IEF. The AC row is not a table cell — it pairs the spec sheet's
minimum capacity (0.9 kW) with its minimum input (0.25 kW) and a full-airflow SHR of 0.62, and **two
of those three assumptions flatter the AC**: the 0.25 kW minimum is the lowest input anywhere in the
envelope rather than the input at 0.9 kW specifically, and SHR at that much turndown is materially
higher than 0.62 — at a warm enough coil much of the surface never reaches dew point at all, so the
latent share could be well under half what is used here.

**Both errors run the same way, so the real winter gap is *wider* than the table shows.** The
conclusion is safe; the precision is not. Read it as "the dehumidifier wins clearly", never as 1.29.

## ⚠️ Three things these numbers do not cover

1. **Neither device is rated where you would actually run it.** The AC's figures are at 46–52 %RH;
   the dehumidifier's IEF is measured at **18.3 °C / 60 %RH** (DOE 10 CFR 430 appendix X1 — 18.3 °C
   dry-bulb, 13.7 °C wet-bulb). Both degrade as the room dries, so **the published numbers flatter
   both of them, roughly equally.**
2. **The AC rows are optimistic at part load.** At reduced compressor speed the evaporator runs
   warmer, less of the coil sits below the dew point, SHR rises and litres-per-kWh **falls**. The
   table is full-airflow data, so real dry-mode performance is worse than shown. The *direction* of
   that error is known; its size is not.
3. **DRY mode's control logic is undocumented.** It appears in neither the design & technical manual
   nor the accessible user-manual pages — only in the feature list. How it modulates compressor and
   fan is therefore **unverified**, and nothing above depends on assuming it.

The unit is also **9 years old**: coil fouling and any refrigerant loss put real performance below the
nameplate.

## ⛔ For filament, this is the wrong question

The moisture target is already quantified in [moisture-isotherms](moisture-isotherms.md): the 4 kg
PETG box needs **17.2 g of water** removed to go from 65 %RH to 15 %RH.

**17.2 g is 0.0172 litres. At the AC's rated efficiency that is 0.0093 kWh — about 0.6 agorot.**

Dehumidifying the *room* to protect filament means paying continuously to dry a large air volume,
most of which leaks straight back in, in order to shift a few grams of water out of some plastic. A
**sealed box with desiccant** attacks the same 17 g directly and costs nothing to run.

⭐ **Room dehumidification is a comfort-and-mould measure, not a filament-storage measure.** If the
room is being dried anyway then filament benefits for free — but it does not justify the machine.

## Practical notes

- **No dehumidifier is recorded in this lab** — zero mentions in this repo, and none in the inventory
  table. Everything above is stated against the Energy Star IEF *range*; if a unit is acquired, its
  nameplate IEF replaces the assumption.
- **Neither machine has a humidistat.** The AC controls temperature, so in dry mode it chases a
  temperature and stops, whatever the humidity is doing. **The Sensibo unit already reads room
  humidity** and Home Assistant can close that loop — the cheapest real improvement available here,
  and it needs no purchase. See the attribute-not-sensor trap in the `home-assistant` skill: Sensibo
  exposes humidity as an *attribute* on `climate.*`, not as its own sensor.
- **Cost per litre at 0.676 ₪/kWh** (household rate, Dec 2025 plus the 1.5 % rise of 1 Jan 2026):
  AC **0.36 ₪/L**; dehumidifier **0.27–0.56 ₪/L** by grade — *before* the seasonal correction above,
  which is the part that actually decides it.

## Sources

- Fujitsu **ASYG07-14LMCE / AOYG07-14LMCE Design & Technical Manual** — specifications (§1) and
  cooling-capacity tables (§4-1). Every AC number above is extracted from it:
  [manual PDF](https://www.viacomvs.com/wf-doc/fujitsu-klima-uredjaj-zidni-inverter-asyg12lmce-aoyg12lmce-technical-manual.pdf)
- [ENERGY STAR — dehumidifier testing and capacity](https://www.energystar.gov/products/dehumidifier_testing_and_capacity)
- [10 CFR part 430 appendix X1](https://www.ecfr.gov/current/title-10/chapter-II/subchapter-D/part-430/subpart-B/appendix-Appendix%20X1%20to%20Subpart%20B%20of%20Part%20430) — the 18.3 °C / 60 %RH test condition
- [Israel electricity tariff, Jan 2026](https://www.timesofisrael.com/wave-of-price-rises-and-tax-hikes-takes-effect-fueling-costs-for-israelis-in-2026/) · [rate per kWh](https://www.globalpetrolprices.com/Israel/electricity_prices/)
