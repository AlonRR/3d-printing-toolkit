# Checking it

How to tell that the model is still right after a change. There are two layers: the repo's
`scad-check.sh` on each printed part, and four collision checks in the model, backed by its asserts.
The wire routes and their checks are on [Wiring](wiring.md).

Every check here has a **positive control**: a setting that breaks the thing being checked, with what it
measured. A check that has never been seen to fail is not yet evidence. If a control stops failing after
a change, the check has gone blind and needs a new control.

## Each printed part — `scad-check.sh`

Run from the repository's root:

```sh
P="0.2mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter"
scripts/scad-check.sh models/print-chamber-box/print-chamber-box-back.scad  "$P" "Inslogic ASA"
scripts/scad-check.sh models/print-chamber-box/print-chamber-box-cover.scad "$P" "Inslogic ASA"
scripts/scad-check.sh models/print-chamber-box/print-chamber-box-fits.scad  "$P" "Inslogic ASA"
```

Each should report **one manifold part** and `fdm_*` values matching the profile: the back plate
68.7 × 80.3 mm on the bed — the divider stands 4 mm below the box — and the cover 68.7 × 76.3 mm.

- **Exit 2 is expected** for the back plate and the cover while `untested_fits` is not empty (and
  `unmeasured`, which is empty now); exit 0 means both are clear. The clearance test reports neither, so
  it exits 0.
- `scad-check.sh` also fails a G-code with a skirt or a brim. The profile above has neither.
- **Always check through the three wrapper files, never through `print-chamber-box.scad` itself.** The
  `part` line in the params file is also what you change to look at a part, and `scad-check.sh` takes no
  `-D`, so a check through the model silently checks whichever part is on screen.

## Collisions — in the model

Render each to STL from `models/print-chamber-box/`, for example:

```sh
openscad -o check.stl -D 'part="check_components"' print-chamber-box.scad
```

**Run each with `outlet_at_left` set both ways** (add `-D outlet_at_left=true`). The model mirrors, and a
check run one way only has passed a mirrored mistake before.

| Check | What it intersects | Must be |
|---|---|---|
| `check_parts` | the back plate with the cover | **zero volume** — they meet only where they touch: the cover's back edge on the plate, and the nut bosses' ends on the cover's screw bosses |
| `check_components` | both parts with everything inside: the SPS30; the SuperMini's PCB (less the clips' pinch, which is meant), its parts, USB-C shell, antenna loop and pole; the largest compliant plug's body, seated, with the board pushed against its stops; the column the SPS30's lead rises through; the SGP41 at every board thickness within the bounds, less the bare patch round its hole; its screw's head; and the wall screws' heads behind the plate, all the way from entry to hung | **empty** |
| `check_slide` | the back plate with the SuperMini's way in: each of its pieces swept from in front of the box into its clips | **empty** |
| `check_insert` | the back plate with the SPS30's way in: its outline, nubs included, swept from its seat to the cover's front | **empty** |

"Empty" means OpenSCAD writes no file; "zero volume" means the STL it writes has none.

## Positive controls

Each setting breaks one thing; the check, or an assert, must catch it. Measured 3 Oct 2026.

| Check | Setting | What it breaks | Measured |
|---|---|---|---|
| `check_parts` | `part_fit = -0.6` | the cover's features overlap the plate's | 212.4 mm³ |
| `check_parts` | `bump_z1 = 75` | the bump at the top into the cover's top wall | 14.4 mm³ |
| `check_parts` | `nut_boss_y1 = 21.5` | the nut bosses run into the cover's screw bosses | 190.5 mm³ |
| `check_components` | `z_f0 = 48` | the board lowered into the column the SPS30's lead rises through | 39.5 mm³ |
| `check_components` | `gy_xb = 61.8` | the SGP41's block face into the parts on the module's underside | 40.5 mm³ |
| `check_components` | `gy_standoff_d = 5.6` | the standoff wider than the bare patch round the hole | 7.3 mm³ |
| `check_components` | `key_xs = [6.25, 57]` | the left keyhole moved under the SPS30's channel wall: its screw head runs into it | 44.4 mm³ |
| `check_components` | `clip_g_catch = 0.5` | the clips' catch pressing too far into the PCB | 0.61 mm³ |
| `check_slide` | `stop_x0 = 20` | the stops moved into the board's way in | 2.9 mm³ |
| `check_slide` | `clip_g_mouth = 0.6` | the clips' mouth narrower than the PCB | 0.59 mm³ |
| `check_insert` | `ch_x1 = 50` | the channel's wall moved into the SPS30's way in | 1050 mm³ |

These fire an **assert** instead, which stops the render with an `ERROR: Assertion` line:

| Setting | What it breaks |
|---|---|
| `gy_xs = 63` | the SGP41's screw head reaches the side wall over the thickest board |
| `gy_screw_l = 8` | the SGP41's pilot runs into the SPS30's channel |
| `key_z1 = 25` | the keyholes run into the nut bosses below and the board's clips above |
| `key_shank_d = 5.5` | the keyholes' slots leave the wall screws' heads less than 1 mm to bear on each side |
| `cover_screw_l = 25` | an M3 × 25 through the cover's corner pokes out of the back plate |
| `cb_depth = 2.8` | the cover's screw heads stand proud of its front |
| `clasp_pinch = 0.6` | the clips' catch closes up |
| `clasp_len = 12` | the two back clips run into each other |
| `clip_reach = 3.0` | the clips reach further onto the board than `clip_room` allows |
| `bump_w = 30` | the U at the top reaches the antenna's pole |

**OpenSCAD exits 0 on a failed assert when it writes a picture or an `.echo` file**, and an `.echo`
export puts the `ERROR` line inside the file. Read the output, or render to STL, which does exit 1.
