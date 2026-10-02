# Checking it

How to tell that the model is still right after a change. There are three layers: the repo's
`scad-check.sh` on each printed part, four collision checks in the model, and the wire-route checks
in the wiring drawing.

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
90.6 mm wide with its tabs, the cover 62.6 mm.

- **Exit 2 is expected** for the back plate and the cover while the `unmeasured` and `untested_fits`
  lists are not empty; exit 0 means both are clear. The clearance test has no warnings of its own, so
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
| `check_parts` | the back plate with the cover | **zero volume** — they meet at the plate's face and the boss tops, nowhere else |
| `check_components` | both parts with everything inside: the SPS30, both boards, the antenna wire and loop, the USB-C shell, the largest compliant plug's body (seated, with the board pushed against its stops), the column the SPS30's lead rises through, the SGP41 at every board thickness within the bounds, the room behind its pin half where its wires leave, and its screw's head | **empty** |
| `check_slide` | the back plate with the SuperMini's way in: each of its pieces swept from clear of the plate's USB-C side to its seat against the stops | **empty** |
| `check_insert` | the back plate with the SPS30's way in: its outline, nubs included, swept from its seat to the cover's front | **empty** |

"Empty" means OpenSCAD writes no file.

**Positive controls**, measured 2 Oct 2026:

| Check | Setting | What it breaks | Measured |
|---|---|---|---|
| `check_parts` | `part_fit = -0.6`, with `wch_x0 = 3.2` and `wch_x1 = 9.4` | the cover's features overlap the plate's. The cable channel's walls are held where they are, or the negative fit trips the channel's assert first | 360.0 mm³ |
| `check_parts` | `gz0 = 44.5` | the SGP41's pedestal lowered into the cover's baffle | 10.5 mm³ |
| `check_components` | `sm_pocket_h = 17` | a pocket narrower than the board | 21.6 mm³ |
| `check_components` | `gx0 = 12` | the pedestal moved into the lead's column | 187.1 mm³ |
| `check_components` | `gy_ped_x0 = 22.6` | the pedestal as long as the module again, under its pins | 309.8 mm³ |
| `check_components` | `gy_strip = 4` | the ledge reaching under the SGP41's parts | 6.5 mm³ |
| `check_components` | `gy_standoff_d = 5.6` | the standoff wider than the bare patch round the hole | 2.8 mm³ |
| `check_components` | `wch_cx = 17`, with `wch_x0 = 3.2` and `wch_x1 = 9.4` | the cable channel moved into the lead's column, past its own assert | 19.3 mm³ |
| `check_components` | `gy_floor = 17` | the SGP41 pushed towards the cover, its screw's head into the front | 12.5 mm³ |
| `check_components` | `sm_lip_l = 2.5` | the rails' lips reaching onto the SuperMini's parts | 33.5 mm³ |
| `check_slide` | `stop_x0 = 20` | the stops moved into the board's way in | 5.4 mm³ |
| `check_slide` | `sm_lip_y0 = 2.6` | the lips set too low over the board's edges | 2.1 mm³ |
| `check_insert` | the design before the SPS30 went in from the front, with lips over its face | the sensor could not have been fitted | 131.8 mm³ |

Stops reaching into the antenna loop, and a mounting hole too small for the SGP41's screw, are caught
earlier, by asserts.

## The wire routes

[`assembly-views.scad`](../assembly-views.scad) checks the SGP41's four wire routes whenever it draws the
wiring view:

- no bend tighter than 3 mm;
- the routes inside the room `wire_room` keeps behind the module's pin half;
- no wire running into another — except two that meet at the same pad, within 5 mm of it;
- none in front of the board's antenna half.

**OpenSCAD still exits 0 when one of these fails** (it does for a picture), so read its output for
`ERROR: Assertion`.

The routes are laid out for the sensor as built. With `outlet_at_left = true` both boards turn end for
end, and the wiring view stops with an assert rather than draw routes that do not fit.

`view = "check_wires"`, exported to STL, intersects the back plate with the SGP41's wires. It must be
**empty**.

```sh
openscad -o wiring.png -D 'view="wiring"' assembly-views.scad        # read the output for ERROR
openscad -o wires.stl  -D 'view="check_wires"' assembly-views.scad   # must write no file
```

**Positive controls**, each failing its own check:

| Setting | What it breaks | Result |
|---|---|---|
| `wire_room = 6.0` | less room behind the module than the routes need | 0.5 mm past the room |
| `lay_gap = 0` | both wire layers in one, so the crossing pairs meet | 1.55 mm of overlap |
| `up_dx = -2` | GPIO5 and GPIO6 rising past the board's middle | in front of the antenna half |
| `wire_stub = -1.5` | no straight run before the first bend | a 1.5 mm bend |
| `riser_aside = 0` | the SPS30's white wire rising straight in front of the GND pad, across the SGP41's GND wire | 1.2 mm of overlap |
| `wire_stub = 9`, in `check_wires` | both layers pushed back to about 5 mm from the plate, into the cable channel's walls | 6.0 mm³ |

