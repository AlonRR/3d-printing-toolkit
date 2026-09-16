# Desiccant cartridge

The swappable **500 g unit** of the desiccant module ([`docs/desiccant-module.md`](../../docs/desiccant-module.md)).
A shallow tray with a slotted grille in its floor and a matching slotted lid: box air is pulled
through the bed, so the bed is **wide and thin** rather than long and deep.

Source is split like C:

| File | |
|---|---|
| [`desiccant-cartridge.params.scad`](desiccant-cartridge.params.scad) | **the header** — every value you SET, and nothing else |
| [`desiccant-cartridge.scad`](desiccant-cartridge.scad) | **the body** — derived values, modules, geometry, echoes, guards. Render this one |

```
        130 x 130 x 45 mm, wall 1.8
   +---------------------------------------+
   | ||||||||||||||||||||||||||||||||||||| |   38 slots, 1.8 mm as cut
   | ||||||||||||||||||||||||||||||||||||| |   bars 1.35 as cut = 3 beads
   | O                                   O |   M3 boss, one per corner
   | ||||||||||||||||||||||||||||||||||||| |
   +---------------------------------------+
        lid carries the same slot pattern
```

> **Every number below is regenerated from the model's own echo block.**
> Do not hand-edit them — re-render and paste. A drifted table reads exactly as authoritative as a
> correct one.

## Current geometry

```
part rendered      : tray
envelope           : 130 x 130 x 45 mm, wall 1.8 mm
interior           : 126.4 x 126.4 x 43.8 mm  = 693.048 cm3 (bosses removed)
capacity           : 498.995 g of clay at 0.8 g/cm3, 90% full   [target 500 g]
  holds            : 49.8995 g of water at 10% capacity, 24.9497 g at the pessimistic 5%
grille             : 38 slots of 1.8 mm as cut, pitch 3.15 mm, field 118.05 x 118.4 mm
  bar as cut       : 1.35 mm  (nominal 1.65, each slot grows 0.15 per side)
  open area        : 8098.56 mm2 = 50.689% of the 15977 mm2 face
lid                : 1.2 mm plate, same slot pattern, 3.3 mm clearance holes
bosses             : d7 at +-58, +-58, pilot 2.8 mm as cut (M3 self-tap)
prints             : flat, grille face down - no bridges, no supports
warnings           : none
```

Sliced for reference: **6 h 15 m, 56.5 g** in ASA at 0.2 mm.

## Why the capacity is echoed in grams

The cartridge exists to hold a **mass** of clay, and that mass is what
[`docs/moisture-isotherms.md`](../../docs/moisture-isotherms.md) sizes: 500 g of bentonite holds
about 50 g of water at its nominal 10 % capacity, against the **17.2 g** a 4 kg PETG load releases
going from 65 to 15 %RH. So one cartridge covers a four-spool box with real margin for ingress.

⚠️ **The envelope was wrong first time, and by 78 g.** The spec said 120 × 120 × 45, from
500 g ÷ 0.8 g/cm³ = 625 cm³ — but **625 cm³ of clay needs more than 625 cm³ of box**: the walls,
the four bosses and the 10 % of headroom the granules need all come out of it. That envelope
measures **422 g**. The model's capacity echo caught it; the hand arithmetic did not.

⭐ **It was fixed sideways, not deeper.** 120 × 120 × 53 reaches the same mass and is the wrong
answer: pressure drop through a packed bed rises with depth and falls with cross-section, so the
deeper cartridge is the one a 60 mm fan cannot pull through.

## The bar is narrower than you set it

`slot_w` is grown by `fdm_hole_comp` per side, and that width comes **out of the bar** while the
pitch stays put:

```
bar as cut = (slot_w + bar_w) - (slot_w + 2 * fdm_hole_comp)
           = bar_w - 0.30
```

`bar_w = 1.65` therefore prints **1.35 mm**, which is exactly three beads at 0.45 — the floor for
anything taking load, and the bed's weight sits on these. Set `bar_w = 1.35` "because three
perimeters is the rule" and the real bar is 1.05. The guard reports the as-cut figure for that
reason.

## Guards

| | Count | Meaning | Behaviour |
|---|---:|---|---|
| **BLOCK** — `assert` | 11 | the geometry is impossible: no cavity, no bars, bosses outside the tray, a pilot that splits its boss | render stops |
| **WARN** — `echo "WARNING: …"` | 10 | it builds and prints, but is compromised: a bar under the floor, slots a granule falls through, capacity short, a face landing mid-layer | STL still produced |

**Verified by making each one fire**, because a guard that cannot fail proves nothing:

```
-D bar_w=1.35                  -> "bar as cut 1.05 ... under 3 perimeters"      (fires)
-D slot_w=2.5                  -> "the clay falls through"                      (fires)
-D cart_w=100 -D cart_d=100    -> "more than 5% short"                          (fires)
-D draw_part="both"            -> "the STL is two solids"                       (fires)
-D wall=70                     -> assert: "there is no cavity"                  (blocks)
-D slot_w=3.0 -D bar_w=0.1     -> assert: "no bars at all"                      (blocks)
defaults                       -> 0 warnings                                    (silent)
```

## Printing

**Flat, grille face down.** Every opening is a gap in the bed layer and every wall rises from it,
so there is nothing to bridge and nothing to support — the house rule, not a happy accident
([`docs/fdm-design-rules.md`](../../docs/fdm-design-rules.md) §3b).

**ASA, not PETG**, if the cartridge will ever sit in a heated dryer or be pulled out of one hot;
the glass-transition table is in [`docs/drybox-active.md`](../../docs/drybox-active.md).

⛔ **Never loose clay in an airstream.** The grille retains granules, not dust — clay carries
respirable silica, and the module's filter is what catches the rest.

## Regenerating

```sh
openscad -o desiccant-cartridge.stl desiccant-cartridge.scad                 # tray
openscad -o lid.stl -D 'draw_part="lid"' desiccant-cartridge.scad            # lid
sh ../../scripts/scad-check.sh desiccant-cartridge.scad                      # render -> slice -> cross-check
```

STL and G-code output are gitignored (repo convention — binaries live in `OneDrive\3D printing\`);
the `.scad` is the artefact worth keeping.
