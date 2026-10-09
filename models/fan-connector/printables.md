<!-- SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz -->
<!-- SPDX-License-Identifier: CC-BY-4.0 -->

# Printables listing - draft

Title: **2.54 mm fan connector, printed: male and female, 2, 3 and 4 pins**

Files to upload: `fan-connector.scad` and the seven STLs `scad-check.sh` makes beside it (`fan-connector-male-2`
to `-4`, `fan-connector-female-2` to `-4`, `fan-connector-coupon`). Pictures: `fan-connector-pair.png`,
`fan-connector-open.png`, `fan-connector-set.png`, then photos of the printed parts.

---

A printed male header and female plug for 2.54 mm fan connectors. The pins and contacts are 22 AWG solid wire: no
crimp terminals.

##### Parts:

- **male-2, male-3, male-4:** the header, with a key the plug's ribs go either side of
- **female-2, female-3, female-4:** the plug
- **coupon:** four trial fits for the female - print it first

##### Fits:

- 3-pin: the usual 3-pin fan plug and header of the KK 254 kind
- 4-pin: keyed as 4-pin fan connectors are, so a 3-pin plug fits it too
- Pin 1 is marked on both

##### Printing:

- 0.2 mm layers, 0.4 mm nozzle
- No supports, no brim
- ASA or PETG
- Each part as its file lies: the male on its underside, the female on its back end

##### Hardware:

| Quantity | Item |
|---|---|
| 1 per pin | 22 AWG solid hookup wire (0.64 mm core) |

##### Assembly:

- **Male:** bare each wire 7.5 mm, push it up from below until the insulation stops, bend it over into the groove
  underneath, and glue the block down
- **Female:** bare each wire 10 mm, feed it in from the back end and out of its cavity, and bend the tip over into
  the notch at the open end
- **Coupon:** thread a wire into each of 1 to 4, try a pin in each, and set `interference` to the one that holds

##### Source:

- OpenSCAD, one file with Customizer settings: pins, the wire's size, the fit
- [Sources and design notes](https://github.com/AlonRR/3d-printing-toolkit/tree/main/models/fan-connector)

_Parts of this model were drafted with the help of an LLM agent; reviewed and verified locally._
