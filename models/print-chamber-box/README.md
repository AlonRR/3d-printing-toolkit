# print-chamber box

An enclosure for the printer chamber node: an ESP32-C3 SuperMini, a Sensirion SPS30 particle sensor and
a GY-SGP41 VOC/NOx module, running [`firmware/print-chamber.yaml`](../../firmware/print-chamber.yaml). It
hangs on the wall outside the printer's enclosure, upright, with the SPS30's air face down. Two parts in
ASA, 68.7 × 76.4 × 24 mm: a back plate, and a cover whose top locates on a bump in a U and whose bottom
corners are screwed into nuts, the screws' heads flush in its front. It hangs on two wall screws by
keyholes beside the SPS30's top corners.

The SuperMini lies level above the SPS30's lead, held by its edges, its antenna's pole standing up; the
SGP41 stands on edge beside the SPS30, behind vents in the side wall.

![assembled, cover off](docs/assembly-open.png)

![every part, moved apart along the way it goes in](docs/assembly-exploded.png)

Every picture carries the box's own axes as arrows: **x across it, y out from the wall, z up.** Facing the
box, +x points to your left. They are the model's axes, not the printer's: the back plate prints lying on
its back, so on the bed its y is up.

## Status

**Modelled and checked; not printable as-is yet.** Three fits are untested: `nut_fit`, the press fit
of the M3 nuts' pockets; `gy_pilot_d`, which was tested upright and is now a sideways hole; and
`clasp_pinch`, how hard the clips on the SuperMini's back edge grip it. `scad-check.sh` exits 2 on
purpose until they are settled.

## Building it

1. **[Print the clearance test](docs/clearance-test.md)** and set the fits it finds.
2. **Print the two parts** — see *Printing* below.
3. **[Assemble it](docs/assembly.md)**, then **[wire it](docs/wiring.md)**.

| Part | File | Prints |
|---|---|---|
| Back plate | [`print-chamber-box-back.scad`](print-chamber-box-back.scad) | flat on its back |
| Cover | [`print-chamber-box-cover.scad`](print-chamber-box-cover.scad) | front face down |
| Clearance test | [`print-chamber-box-fits.scad`](print-chamber-box-fits.scad) | flat |

**Hardware:** two M3 × 20 socket head cap screws and two M3 nuts for the cover, one M2.5 × 6 socket head cap screw for
the SGP41, two 4 × 20 chipboard screws and their wall plugs to hang it, and 22 AWG solid hookup wire
for the SGP41. No tape, no glue.

## Printing

Inslogic ASA, with the print profile **"0.2mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter"**.
No skirt, no brim, no draft shield, and no supports: rounded corners keep ASA's corners down, and every
opening is a hole in the first layers or a notch open at an edge.

## How it is designed

| Page | What it covers |
|---|---|
| [Design](docs/design.md) | the rules the SPS30 sets, the layout they produce, and which way is left |
| [What each feature is for](docs/features.md) | both parts, every feature numbered |
| [The USB-C end](docs/usb-c-end.md) | why any cable fits, and what takes a plug's push and pull |
| [The SGP41's mount](docs/sgp41-mount.md) | how the gas sensor sits close to its vents without loading its parts |
| [Parameters](docs/parameters.md) | every measured, sourced and tested value, and where it came from |
| [Checking it](docs/checking.md) | the checks that guard the design, and the controls that prove each can fail |

## Files

| File | |
|---|---|
| [`print-chamber-box.params.scad`](print-chamber-box.params.scad) | every setting, measurement and fit — the one file to edit |
| [`print-chamber-box.scad`](print-chamber-box.scad) | the model, its asserts and its collision checks |
| `print-chamber-box-back.scad`, `-cover.scad`, `-fits.scad` | one part each; check and slice through these |
| [`assembly-views.scad`](assembly-views.scad) | the assembly pictures: exploded, and open with the wiring table |
| [`feature-map.scad`](feature-map.scad) | the numbered feature pictures |
| [`fits-map.scad`](fits-map.scad) | the lettered picture of the clearance test |
| [`sps30-measure.scad`](sps30-measure.scad) | the two widths to measure on the SPS30 |
| [`board-measure.scad`](board-measure.scad) | the three readings taken on the SuperMini and the GY-SGP41 |
| [`docs/`](docs/) | the pages above and their pictures |
