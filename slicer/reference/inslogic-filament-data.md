# Inslogic filament data — ASA, PETG Pro, PLA Pro, TPU 95A

Manufacturer figures for the four Inslogic filaments used here, transcribed from Inslogic's
own Technical Data Sheets, **all rev. 12.02.2024**. These are the numbers the profiles in
[`../filament/inslogic/`](../filament/inslogic/) were derived from.

**The PDFs are deliberately not in this repository.** The data is free to use and is
reproduced below; the files themselves are Inslogic's, and a repo is not the place to
redistribute a vendor's documents — they were also ~2.6 MB against ~8 KB for this page.
Get the originals from Inslogic's
[download center](https://www.inslogic3d.com/pages/download-center), which publishes
**TDS/SDS only — no slicer profiles**, for any slicer.

Inslogic's own caveat, in short: these are indicative figures for comparison, measured on
their test specimens, not guaranteed properties and not a substitute for testing your own
parts. A printed part is anisotropic and will not reach an injection-moulded test bar's
numbers — treat the mechanical figures as *relative* ranking between these materials.

---

## Print settings

| | ASA | PETG Pro | PLA Pro | TPU 95A |
|---|---|---|---|---|
| **Nozzle @ 50–100 mm/s** | 250–260 °C | 230–240 °C | 195–205 °C | 190–210 °C @ 50–80 |
| **Nozzle @ higher speed** | 260–280 °C @ 100–200 | 240–255 °C @ 100–300<br>255–270 °C @ 300–600 | 205–220 °C @ 100–300 | 210–230 °C @ 80–120 |
| **Bed** | 80–100 °C | 60–70 °C | 50–60 °C | 50–60 °C |
| **Cooling fan** | 100 % | 100 % | 100 % | 100 % |
| **Bed surface** | Smooth PEI, high-temp plate | Smooth PEI, high-temp plate | Textured PEI, cool plate | Textured PEI, cool plate |
| **Drying** | **80 °C, 4 h** | 50 °C, 4 h | 50 °C, 4 h | 50 °C, 4 h |
| **Nozzle sizes** | 0.2, 0.4, 0.6 mm | 0.2, 0.4, 0.6 mm | 0.2, 0.4, 0.6 mm | **0.4, 0.6 mm** |
| **Diameter** | 1.75 ± 0.02 mm | 1.75 ± 0.02 mm | 1.75 ± 0.02 mm | **1.75 ± 0.03 mm** |
| **Spool** | 1 kg | 1 kg | 1 kg | 1 kg |

Two that matter on an MK3S+: **ASA dries at 80 °C**, well above the 50 °C the other three
want and above what some drybox builds reach; and **TPU has no 0.2 mm entry** — the small
nozzle is not offered for it.

## Physical properties

| Property | Method | ASA | PETG Pro | PLA Pro | TPU 95A |
|---|---|---|---|---|---|
| Density | ISO 1183 | 1.05 g/cm³ | 1.26 g/cm³ | 1.20 g/cm³ | 1.23 g/cm³ |
| Melting temperature (10 °C/min) | ISO 11357-3 | 120 °C | 128 °C | 166 °C | — |
| Glass transition (10 °C/min) | ISO 11357-3 | 108 °C | 65.5 °C | 65.3 °C | — |
| Heat deflection @ 0.45 MPa | ISO 75 | 98 °C | 72 °C | 55.0 °C | 53 °C |
| Shrinkage @ 23 °C | ISO 294 | 0.4–0.9 % | — | — | — |
| Hardness | ISO 868 | — | — | 83 D | 95 A |

## Mechanical properties

| Property | Method | ASA | PETG Pro | PLA Pro | TPU 95A |
|---|---|---|---|---|---|
| Tensile strength | ISO 527/2 | 52.40 MPa | 50.00 MPa | 56.00 MPa | 36.10 MPa |
| Elongation at break | ISO 527/2 | 21.40 % | 34.53 % | 20.30 % | 1050 % |
| Young's modulus | ISO 527/2 | — | — | — | 51.20 MPa |
| Flexural strength | ISO 178 | 75.20 MPa | 81.90 MPa | 85.80 MPa | 4.47 MPa |
| Flexural modulus | ISO 178 | 2162 MPa | 2750 MPa | 2795 MPa | 89.30 MPa |
| Izod impact, notched | ISO 180 | 18.33 kJ/m² | 4.8 kJ/m² | 20.10 kJ/m² | **No break** |

Izod is measured at 23 °C, X–Y orientation, for PETG Pro, PLA Pro and TPU; the ASA sheet
does not state the condition.

## Identity

| | Chemical name |
|---|---|
| ASA | Acrylonitrile Styrene Acrylate |
| PETG Pro | Polyethylene Terephthalate Glycol |
| PLA Pro | Polylactic Acid |
| TPU 95A | Thermoplastic Polyurethane |

---

## Reading the numbers — four things worth knowing

**PETG Pro's impact figure is the outlier, and it is easy to misread.** 4.8 kJ/m² notched
Izod against ASA's 18.33 and PLA Pro's 20.10 makes PETG look brittle, which contradicts its
reputation. Notched Izod is a *notch-sensitivity* measure: PETG is ductile and tears rather
than shattering, so it performs poorly in a test designed around crack propagation from a
notch while still being tough in service. Its 34.53 % elongation at break — the highest of
the three rigid materials — is the better guide for a part that must survive being dropped.

**ASA is the only one with real heat resistance.** 98 °C heat deflection and a 108 °C glass
transition against PLA Pro's 55 °C/65.3 °C. That gap, not the strength figures, is why ASA
is the enclosure and outdoor material here. PLA Pro is *stronger* on paper — 56.00 MPa
tensile against ASA's 52.40 — and still the wrong choice for anything that sits in a car or
near the printer's own heat.

**Three transcription notes, kept because they are the vendor's, not mine:**

- The ASA sheet cites **ISO 11375-3** for melting and glass transition. No such standard
  applies; the other three sheets cite **ISO 11357-3** (DSC), which is the correct one. Recorded
  above as 11357-3.
- The ASA sheet gives a **melting temperature of 120 °C**. ASA is amorphous and has no true
  melting point, so this is a softening figure at best — the 108 °C glass transition is the
  number to design against.
- The TPU sheet's feature list claims **maximum elongation of 1063 %** while its own
  properties table says **1050 %**. Both are the vendor's; the table figure is used above.

**Density is what to price by, not spool weight.** All four ship as 1 kg, but ASA at
1.05 g/cm³ gives ~20 % more printed volume per spool than PETG Pro at 1.26 g/cm³. For a
part specified by volume, ASA is cheaper per part than a per-kilo comparison suggests.
