# print-chamber box

An enclosure for the printer chamber node: an ESP32-C3 SuperMini, a Sensirion SPS30 particle sensor and
a GY-SGP41 VOC/NOx module, running [`firmware/print-chamber.yaml`](../../firmware/print-chamber.yaml). It
hangs on the wall outside the printer's enclosure, upright, with the SPS30's air face down. Two parts in
ASA — a back plate and a cover held by four screws — 62.6 × 88.5 × 24 mm, plus a mounting tab each side.

![every part, moved apart along the way it goes in](docs/assembly-exploded.png)

## Status

**Modelled and checked; not printable as-is yet.** Every dimension is measured or sourced, but five fits
are still untested in ASA — `part_fit`, `pilot_d`, `gy_pilot_d`, `screw_d` and `tab_hole_d` — and
`scad-check.sh` exits 2 on purpose until they are. The clearance test that tries them is printed, and
its results for the SPS30's and the boards' fits are in. See [the clearance test](docs/clearance-test.md).

Before printing the back plate, check on the parts the values read off photos rather than calipers:
`sm_edge`, `pin_mid`, `gy_hole_bare_d`, and which edge of its pocket the SGP41's mounting hole sits by
([parameters](docs/parameters.md)).

## Building it

1. **[Print the clearance test](docs/clearance-test.md)** and set the fits it finds.
2. **Print the two parts** — see *Printing* below.
3. **[Assemble it](docs/assembly.md)**, then **[wire it](docs/wiring.md)**.

| Part | File | Prints |
|---|---|---|
| Back plate | [`print-chamber-box-back.scad`](print-chamber-box-back.scad) | flat on its back |
| Cover | [`print-chamber-box-cover.scad`](print-chamber-box-cover.scad) | front face down |
| Clearance test | [`print-chamber-box-fits.scad`](print-chamber-box-fits.scad) | flat |

**Hardware:** four M3 × 14 self-tapping screws for the cover, one M2.5 × 8 socket head cap screw for the
SGP41, two wood screws up to 3.5 mm to hang it, and 22 AWG solid hookup wire for the SGP41. No tape, no
glue.

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
| [`assembly-views.scad`](assembly-views.scad) | the assembly and wiring pictures, and the wire-route checks |
| [`feature-map.scad`](feature-map.scad) | the numbered feature pictures |
| [`fits-map.scad`](fits-map.scad) | the lettered picture of the clearance test |
| [`docs/`](docs/) | the pages above and their pictures |
