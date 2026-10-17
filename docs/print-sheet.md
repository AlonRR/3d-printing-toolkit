# The print sheet: a Prusa satin sheet

The MK3S+ prints on Prusa's **satin powder-coated PEI sheet**, double-sided. It is not the smooth PEI sheet
the profiles' notes were first written for, and not the textured one. It was identified on 17 Oct 2026 from a
photo of the sheet and a check of it:

- the sheet is dark grey, matte and finely grained, printed "Heatbed Steel Sheet by PRUSA3D.COM";
- it is coated on both faces;
- prints come off it with matte bottoms.

A smooth PEI sheet is coated on one face and gives glossy bottoms. A textured sheet is bronze and pebbled. The
sheet came with the printer.

## What Prusa says each material needs on it

From Prusa's knowledge base, [Satin steel sheet](https://help.prusa3d.com/article/satin-steel-sheet_196526),
read 17 Oct 2026:

| Material | On the satin sheet | Glue stick |
|---|---|---|
| PLA | "an optimal level of adhesion"; small prints may need a brim | not needed |
| PETG | "an optimal level of adhesion" | not needed |
| ASA, PC Blend | **lower adhesion than on the smooth sheet**; prints often need a brim or a draft shield | not asked for |
| PC, printed often | wears the coating over time | recommended, to protect the sheet |
| TPU, TPEE | | **apply a glue stick** |

## What that changes here

- **The smooth-PEI warnings in the profiles' notes do not arise on this printer.** They said that ASA at
  110 °C, PETG at 85-90 °C and TPU bond to a smooth PEI sheet hard enough to tear PEI off it. On satin, Prusa
  prints PETG with no release layer and reports ASA sticking *less* than on smooth PEI. The notes now say
  so, and keep the smooth-sheet case as an aside. No setting changed: each bed temperature stands on its
  other ground - the vendor's range, Prusa's tested ASA numbers, or a measured print.
- **The glue stick that goes down for every print**, on every material, does a different job here. For
  ASA it helps hold the first layer, since no brim, skirt or draft shield is printed; the hotter bed and the
  closed enclosure do the rest ([asa-print-quality.md](asa-print-quality.md)). For TPU it is what Prusa asks
  for. For PLA and PETG it is not needed.
- **The vendors' data sheets name other sheets:** smooth PEI for ASA and PETG, textured PEI for PLA and
  TPU. Those lines are the vendors' words and stay as transcribed. Satin is Prusa's middle sheet, and Prusa
  prints all four on it with the notes in the table above.

## Care

- **Clean it cold**, with about 90 % IPA. If that is not enough, use dish soap and water, then **dry it at
  once**: it has an anti-corrosion layer but is not to be left wet.
- **With glue stick on it, warm water is what lifts the PVA.** IPA only smears it. Wash the sheet off now
  and then and glue it again, rather than topping up over old layers.
- **Never acetone.** Prusa: it makes microfractures in the coating, and the surface deteriorates.
- **A plastic spatula only**: the coating is not scratch-resistant. Let the sheet cool and flex it, and
  prints come off.
- **Fingerprints and grease** mark it and cut adhesion.
- **Set Live Z again** whenever the sheet is changed for another.
