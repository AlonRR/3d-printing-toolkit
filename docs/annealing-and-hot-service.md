# Annealing, and plastic parts that carry load while hot

Written 25 Sep 2026 to answer a question from the drybox work: the `spring` insert in
`models/desiccant-module` is ASA, holds a 0.7 mm preload through two 0.9 mm cantilever fingers, and
sits in ~85 °C purge air for hours at a time, repeatedly. Root stress ~9 MPa cold. Should it be
annealed first, and does annealing help?

**Short answer: anneal it, but not for the reason usually given, and do not expect annealing to fix
the load problem. If the preload genuinely has to survive, the spring should not be ASA — and
arguably should not be plastic.**

Claims are marked **[measured]** where a source gives a figure from a test, **[vendor]** where it is
a manufacturer's recommendation without supporting data, and **[inferred]** where it is reasoning
from this repo rather than from a source.

---

## 1. ⛔ HDT is not a service temperature, and the margin here is smaller than it looks

This repo records ASA at **Tg 108 °C, HDT 98 °C** ([drybox-active.md](drybox-active.md)), and that
has been read as "85 °C leaves comfortable margin". It does not, for three reasons.

**HDT is quoted at a specified load, and the number moves a long way with it.** Polycarbonate is
published at **138 °C at 0.45 MPa and 110 °C at 1.82 MPa — a 28 °C spread between the two standard
load cases** [measured]. An HDT figure with no load case attached cannot be compared against a real
part, and the 98 °C recorded here does not carry one.

**This part is loaded far above either test case.** Root stress is ~9 MPa — roughly **five times**
the 1.82 MPa case and **twenty times** the 0.45 MPa case [inferred]. Whatever ASA's 98 °C
corresponds to, the effective softening point under *this* load is materially lower.

**HDT also measures the wrong thing.** It is a short-term deflection test to a fixed small
deflection, not a statement about holding a load for hours. A part can sit well under its HDT and
still relax substantially over a long hold.

⭐ **The useful number is not HDT but the gap to Tg.** At 85 °C the ASA is **23 °C below Tg**, which
is inside the region where glassy polymers show significant time-dependent deformation — the
published physical-ageing creep studies are run at exactly **15–35 °C below Tg** [measured]. This
part operates inside the band those experiments were designed to probe, not below it.

*(Sources vary on ASA's own Tg: this repo has 108 °C, some give ~100 °C. Keep 108 as the working
figure but treat a 5–10 °C spread as real uncertainty.)*

---

## 2. What annealing does to ASA, and what it does not

**ASA is amorphous.** It has no crystalline phase, so the mechanism that makes annealing valuable
for PLA, nylon and other semi-crystalline polymers — growing and reorganising crystallites, which
raises heat resistance — **does not exist here**.

| | Semi-crystalline (PLA, PA) | **Amorphous (ASA, ABS, PETG, PC)** |
|---|---|---|
| Crystallinity | increases on annealing | **none to increase** |
| HDT / Tg | can rise substantially | **essentially unchanged** |
| Residual print stress | relieved | **relieved** |
| Dimensional stability | improved | **improved** |
| Layer adhesion | improved | little, below Tg |

Polymaker states the benefit for amorphous materials is "mainly dimensional stability and residual
stress reduction" [vendor], and the ABS annealing literature agrees that amorphous polymers do not
see comparable HDT gains [measured].

⚠️ **One widely repeated claim is simply wrong.** Several 3D-printing guides say annealing ASA
"improves the crystallinity of the polymer". ASA has no crystallinity to improve. Where that
sentence appears the surrounding temperature advice may still be reasonable, but the stated
mechanism is not, and anything derived from it should be discarded.

**So the working assumption in the drybox facts file — annealing relieves print stress but does not
raise HDT or stop creep — is correct** and can be promoted from `EST` to sourced, with one
refinement in §3.

---

## 3. The one real mechanical benefit: physical ageing — and service already supplies it

Below Tg a glassy polymer slowly densifies toward equilibrium. This is **physical ageing**, and it
**increases modulus and decreases creep compliance, reducing creep and stress-relaxation rates**
[measured]. That is a genuine improvement in the exact property this part needs, so "annealing does
nothing for creep" is too strong.

⚠️ **But this part anneals itself.** It sits at 85 °C for hours, repeatedly. That is a sub-Tg hold —
it *is* a physical-ageing treatment. A pre-anneal does not add a benefit service would not produce;
**it front-loads it** [inferred].

Which leaves the actual reason to do it:

⭐ **Anneal so the dimensional change happens in the oven instead of in the assembly.** Residual
print stress relaxes on the first hot cycle and the part changes shape as it goes. If that happens
after assembly it changes the finger geometry, and therefore the preload — the very quantity being
designed. Annealing **before** final fit moves that change somewhere it can be measured and
compensated. On a flexure whose preload is set by geometry, this is the whole argument [inferred].

**Corollary: anneal above the service temperature.** Annealing at 85 °C and then operating at 85 °C
leaves the part still changing in service.

---

## 4. ⛔ Never anneal a flexure while it is preloaded

Annealing under load is how you *deliberately* relax a spring. Holding the fingers deflected at
elevated temperature is a stress-relaxation soak: the polymer relieves stress by taking a permanent
set toward the held shape, and the preload is what you lose.

**Anneal the spring free and unassembled, every time.**

Worth stating plainly because the planned test — bake it *assembled* at ~85 °C and measure retained
preload — looks superficially similar. That test is correct and should go ahead: it is the service
condition, deliberately applied, to find out what survives. The difference is intent. Annealing is
a free, unloaded, above-service-temperature treatment; the bake is a loaded, at-service-temperature
experiment. **Do not merge the two steps.**

---

## 5. If you anneal: schedule and support

**Temperature: 95 °C** — above the 85 °C service temperature so service does not anneal it further,
and below Tg 108 °C. Polymaker suggests "~95 °C for ASA" [vendor]; other guides give 85 °C for 1–2 h
[vendor] and 80–100 °C for 4–6 h [vendor]. None is backed by published ASA data and they disagree,
so treat the schedule as a starting point to be checked, not a specification.

| | |
|---|---|
| Temperature | **95 °C** (above 85 °C service, below 108 °C Tg) |
| Hold | **2–4 h** at temperature for a 2 mm section |
| Ramp | bring the part up with the oven from cold, not into a hot oven |
| Cool | **in the oven, door shut, to room temperature** — gradual cooling is what stops new stress being frozen in; a fast cool re-creates the problem being fixed |
| Load | **none — free and unassembled** (§4) |

⚠️ **Verify the oven, do not trust its dial.** A domestic oven that overshoots to 120 °C puts the
part above Tg and it will distort. This repo already makes that point about filament drying in
[asa-print-quality.md](asa-print-quality.md) §5; it matters more here, because 95 °C leaves only
13 °C of headroom. Measure with an independent probe first.

### Supporting a thin part

41 × 23 × 2 mm with unsupported cantilever fingers — thin enough to warp as stress releases.

- **Flat plate is the first choice here.** The part prints on its back, so the fingers deflect *in
  the plane of the plate*. Laid flat on glass or aluminium it is fully supported and the fingers
  stay free in the only direction they need [inferred].
- **⛔ Do not clamp it flat.** Clamping forces the fingers into the plate's plane and makes the
  anneal a loaded one — §4.
- **Burial in salt or fine dry sand** is the standard method for parts that would otherwise sag, and
  is reported to work at 100 °C on PLA [vendor]. Pack it in, tap so the medium flows into detail,
  keep a bed underneath, and **cool the part in the medium**. Salt is preferred to sand because it
  rinses off in water [vendor].
- Burial is more than this part needs at 95 °C; keep it in reserve if the flat-plate result warps
  [inferred].

**Measure before and after** — finger free length, thickness, and the preload the assembly actually
develops. If annealing is being done to move the dimensional change out of service, the size of that
change *is* the result, not a side effect.

---

## 6. Creep or stress relaxation? For this part it is relaxation

Different tests of the same viscoelasticity, and the distinction changes what to measure:

- **Creep** — constant *stress*, strain grows.
- **Stress relaxation** — constant *strain*, stress decays.

**A preloaded flexure held at fixed deflection is a stress-relaxation problem.** The bumps hold the
fingers at 0.7 mm; the displacement is imposed by the assembly and it is the *force* that decays.
What is observed on disassembly is permanent set — how much deflection the finger fails to recover.

So the planned measurement is the right one, and the criterion (**0.38 of 0.7 mm, 54 %**) is a
relaxation/recovery criterion. Searching for "creep data" mostly returns constant-stress curves that
do not answer it directly [inferred].

---

## 7. The data gap, stated rather than papered over

**No creep or stress-relaxation data for ASA at 80–90 °C and 5–10 MPa was found.** That is the
honest result of the search, not an omission.

What exists nearby:

- ABS creep limit at room temperature is ~80 % of tensile strength, **decreasing roughly linearly
  with temperature** [measured] — a trend, not a number for 85 °C.
- Creep *modulus* appears in resin datasheets far more often than full isochronous curves [vendor].
  A figure at 85 °C would need a resin maker's data (BASF/INEOS Luran S or equivalent), not a
  filament vendor's sheet.
- Filament datasheets for printed ASA do not publish elevated-temperature creep at all.

⭐ **This is why the coupon test matters more than more searching.** The number does not exist in the
literature at the needed condition, so the test is the source. Print it, bake it, measure it, and
record the result here — it will be the only figure anyone has for this material in this condition.

---

## 8. Material, and the honest recommendation

| Option | Tg | At 85 °C | Verdict |
|---|---|---|---|
| **ASA** (current) | 108 °C | 23 °C below Tg, ~9 MPa | Marginal; relaxation expected over hours |
| **PC** | ~147 °C | **62 °C below Tg** | Best plastic option; best creep resistance of this group [measured] |
| **PC/ABS, PC blends** | ~125–135 °C | comfortable | Easier to print than PC, most of the benefit |
| **PETG** | ~80 °C | **at or above Tg** | ⛔ Out — service temperature exceeds Tg |
| **Nylon** | varies | — | ⛔ Out, and the drybox reasoning is right: it trades water with its environment and Tg falls sharply when wet. In a *dryer* it would cycle |
| **Spring steel / BeCu** | n/a | negligible relaxation | ⭐ See below |

**1. If the preload has to be reliable, use a metal spring.** At 85 °C a steel or beryllium-copper
strip has essentially no relaxation, and this is a 41 × 23 mm insert with two fingers — a shim-steel
strip or a bent music-wire clip would do the job at trivial cost. It also follows the principle
already recorded in this lab's memory: *make heat- and load-exposed features separate small inserts
so they can be re-materialled*. The insert is already separate; changing its material is the
cheapest move available, and it removes the failure mode instead of managing it [inferred].

**2. If it must be printed, PC or a PC blend, not annealed ASA.** 62 °C of margin to Tg beats 23 °C,
and PC has the best creep resistance in this group [measured]. Caveats: PC needs a hotter bed and an
enclosure, and PC's *own* HDT drops 28 °C between load cases [measured] — the margin is real, but do
not re-make the §1 mistake with a different material. Thicker fingers, generous root fillets and
lower root stress all still apply.

**3. Anneal the ASA either way, if ASA is what gets tested first.** Not because it fixes the load
problem — it does not — but because it moves the dimensional change out of service (§3), and because
an un-annealed coupon measures print stress and relaxation together and cannot separate them.

⭐ **Suggested test order**, one extra coupon for an interpretable result: print two, anneal one,
bake both assembled at 85 °C, measure both. The annealed/un-annealed difference *is* the
residual-stress contribution, and the annealed part's retained preload is the number that predicts
service [inferred].

**Better still, run both arms in the SAME coupon** where the assembly has two insert positions —
one annealed, one as printed, one oven, one set of cycles. That removes oven-to-oven and
cycle-count variation between the arms, which the two-coupon version leaves in.

⛔ **But that variant breaks an assumption, and the fix is not optional.** Annealing changes the
part's dimensions — that is the whole point of §3 — so **the two arms do not start at the same
preload**. The bumps impose a fixed displacement, and the annealed finger arrives at it from a
different rest position, so its initial deflection is not 0.7 mm merely because the as-printed
one's is. Measured against a nominal 0.7 mm, the comparison then folds shrinkage into what is
supposed to be a relaxation result, and the 54 % criterion is being applied to a number one arm
never had.

**So measure each insert's own preload after fitting and before baking, and report retention as a
fraction of that** — two numbers per arm, start and end, not one. The gap between the two arms'
*starting* values is itself the dimensional result §3 predicts, and is worth recording separately
[inferred].

**Prediction, recorded so the test can falsify it:** annealed ASA will not hold 54 % of 0.7 mm
through repeated multi-hour 85 °C cycles. 23 °C below Tg at ~9 MPa is inside the regime where glassy
polymers relax measurably, and physical ageing slows that without stopping it [inferred]. If the
coupon does hold 54 %, this section is wrong and should be corrected here.

---

## Sources

Separated by what they actually provide.

**Peer-reviewed / measured**

- [Effect of annealing on FDM-manufactured ABS parts — Int. J. Adv. Manuf. Technol.](https://link.springer.com/article/10.1007/s00170-025-15455-5)
- [Investigating the Effects of Annealing on the Mechanical Properties of FFF-Printed Thermoplastics — MDPI](https://www.mdpi.com/2504-4494/4/2/38) — amorphous vs semi-crystalline, ABS and ASA grouped as amorphous
- [Physical ageing and short-term creep in amorphous and semicrystalline polymers — Polymer](https://www.sciencedirect.com/science/article/abs/pii/003238619090209H) — tests at 15–35 °C below Tg
- [Creep and physical aging of PVC: dependence on stress and temperature — Polymer](https://www.sciencedirect.com/science/article/abs/pii/002230939490488X)
- [Physical Aging in Polymer Glasses](https://www.researchgate.net/publication/6070706_Physical_Aging_in_Polymer_Glasses) — modulus up, creep compliance down
- [A Study of Creep Characteristics of ABS for Different Stress Levels and Temperatures](https://www.researchgate.net/publication/264192616_A_Study_of_Creep_Characteristics_of_ABS_Acrylonitrile_Butadiene_Styrene_for_Different_Stress_Levels_and_Temperatures)

**Vendor guidance — recommendations, not data**

- [Annealing — Polymaker Wiki](https://wiki.polymaker.com/printing-tips/post-processing/annealing) — ~95 °C for ASA; amorphous benefit is dimensional stability and stress reduction
- [Annealing Tips — Polymaker Wiki](https://wiki.polymaker.com/printing-tips/post-processing/annealing/annealing-tips)
- [How to improve your 3D prints with annealing — Prusa](https://blog.prusa3d.com/how-to-improve-your-3d-prints-with-annealing_31088/)
- [Annealing Process Instructions for Different Materials — Eryone](https://www.eryone.com/news/annealing-process-instructions-for-3d-printed-parts-of-different-materials/) — 85 °C, 1–2 h, natural cooling. ⚠️ also carries the "improves crystallinity" error
- [Reforming 3D Prints With Salt And Heat — Hackaday](https://hackaday.com/2020/09/23/reforming-3d-prints-with-salt-and-heat/) and [Guide to Annealing 3D Prints — Unionfab](https://www.unionfab.com/blog/2025/06/annealing-3d-prints) — salt/sand burial

**Material comparison**

- [Heat Resistant Filament: What the Spec Sheet Doesn't Tell You — Sigma](https://sigmafilament.com/heat-resistant-filament/) — PC HDT 138 °C at 0.45 MPa vs 110 °C at 1.82 MPa
- [ASA vs PC — materialref](https://www.materialref.com/compare/asa-vs-pc) · [ASA vs Polycarbonate — filamentcompare](https://filamentcompare.com/asa-vs-pc/) · [Comparing durable filaments: ABS, ASA, PC — Spectrum](https://shop.spectrumfilaments.com/Comparing-durable-filaments-ABS-ASA-PC-blog-eng-1754200097.html)
- [ASA Glass Transition Temperature — Wevolver](https://www.wevolver.com/article/asa-glass-transition-temperature)
