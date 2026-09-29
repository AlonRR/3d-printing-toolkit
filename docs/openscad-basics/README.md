# OpenSCAD basics — six lessons, ending in a part built the way this repository builds them

A hands-on path from nothing to reading and writing the models in [`models/`](../../models/). Each lesson is
a `.scad` file you open, preview, break and fix. Comments explain what you are looking at, and every
lesson ends with a few **TRY** exercises.

Every behaviour the lessons describe was **measured** on the OpenSCAD 2021.01 release and on a 2026
nightly, not recalled. Several things turned out differently from what is commonly said; those are
listed at the end.

## What OpenSCAD is

A program that **describes a solid**. There is no mouse modelling and no undo history: you write
code, OpenSCAD evaluates it into a tree of shapes and operations, and exports the result as a mesh
(STL). Change a number, and the part changes everywhere that number is used.

Two ideas cause most of the early confusion:

- **Names are bound once per scope.** `x = x + 1` does not do what it does in Python — see lesson 3.
- **Geometry is combined, not edited.** You never modify a shape; you union, subtract or intersect
  whole shapes — see lesson 2.

## Setup

**Editor.** Any text editor works. VS Code with an OpenSCAD extension gives syntax highlighting,
completion and hover documentation.

**The loop that makes it pleasant:** open the file in the OpenSCAD application, turn on
**Design → Automatic Reload and Preview**, and edit in your editor. Every save re-previews.

| Key | What it does | When |
|---|---|---|
| **F5** | Preview — fast, approximate | While editing |
| **F6** | Render — computes the real solid | Before exporting an STL, and when a preview looks wrong |

**Read the Console pane.** `echo()` output, warnings and failed asserts appear there, not in the view.

**Which build.** Two are in common use: the **2021.01 release** and the **nightly** snapshots. The
nightly renders far faster, which matters on large models. But when you need to know whether a part
passed its checks, use the release — see *Checking your work*.

## The lessons

| | Lesson | You learn |
|---|---|---|
| 1 | [`01-shapes-and-transforms.scad`](01-shapes-and-transforms.scad) | Primitives, `center`, transforms and why their order matters, and why curves are polygons |
| 2 | [`02-combining-shapes.scad`](02-combining-shapes.scad) | `union` / `difference` / `intersection`, the `#` `%` `!` `*` debug modifiers, cutters that overshoot, parts that only touch, `hull()` |
| 3 | [`03-values-not-variables.scad`](03-values-not-variables.scad) | **The important one.** Why a loop cannot accumulate, scope, `$` variables, and why `0.6 / 0.2 == 3` is false |
| 4 | [`04-modules-and-functions.scad`](04-modules-and-functions.scad) | Modules, functions, `children()`, and `use` versus `include` — with a real library, [`04-library.scad`](04-library.scad) |
| 5 | [`05-loops-lists-and-2d.scad`](05-loops-lists-and-2d.scad) | Ranges, list comprehensions, 2D outlines, `offset()`, `linear_extrude`, `rotate_extrude`, `text()` |
| 6 | [`06-a-real-part/`](06-a-real-part/) | An M3 spacer written the way every model here is: a `.params.scad` settings file, derived values, `assert`s that enforce [`fdm-design-rules`](../fdm-design-rules.md), and a clean pass through `scad-check.sh` |

Do them in order. Lesson 6 uses something from each of the others.

## Checking your work

From the repository root:

```sh
scripts/scad-check.sh docs/openscad-basics/06-a-real-part/m3-spacer.scad
```

That renders the part, runs its asserts, checks the mesh is **one manifold part**, slices it, and
compares the model's `fdm_*` values with the profile it was sliced with. It exits **0** on a pass,
**2** when the model echoed a `WARNING` (it builds, but read why), and **1** when it is blocked.

Measured on lesson 6, each result predicted before running:

| `m3-spacer.params.scad` | Result |
|---|---|
| as shipped | `PASS`, exit 0 |
| `wall = 1.8` | 1 WARNING, exit 2 — four beads, where §1 asks for five |
| `wall = 1.1` | `BLOCKED`, exit 1 — not a whole number of extrusion widths |
| `length = 10.1` | `BLOCKED`, exit 1 — 50.5 layers |
| `length = 10.2` | `PASS`, exit 0 — 51 layers, though `10.2 / 0.2` is not exactly 51 (lesson 3) |

⚠️ **`scad-check.sh` uses the 2021.01 release, and that is deliberate.** On the nightly, a failed
`assert` stopped the build in every simple case tried while writing these lessons — at the top level,
in a module, a function, an `if`, a `for`, and an included file. But in one larger model in a sibling
project, the nightly printed the assertion **and exited 0 with an STL written**, where the release
stopped. The cause was not isolated. So **never read a nightly's exit code as proof that a part
passed** — read its Console, or run the check.

## Resetting a lesson

The lessons are tracked in git, so break them freely:

```sh
git restore docs/openscad-basics/03-values-not-variables.scad
```

`scad-check.sh` leaves an `.stl` and a `.gcode` beside the part. Both are git-ignored.

## Things that turned out differently from what is usually said

Measured while writing these lessons, on both builds:

- **A 3 mm circle at the default settings has five sides.** A pentagon, with 24 % less area than the
  circle asked for — that is an M3 clearance hole. (Lesson 1.)
- **A cutter that stops exactly on a face did not spoil the render.** The flickering skin is a
  *preview* artefact; F6 produced one manifold part of the correct volume. Overshoot anyway, so the
  preview stops misleading you. (Lesson 2.)
- **Solids that touch along a face fused into one part; solids that touch along an edge did not.**
  Only the release warned about the edge case. (Lesson 2.)
- **`0.6 / 0.2` prints as 3 but is not equal to 3.** That is why every layer check here uses a
  tolerance. (Lesson 3.)
- **`offset(r = 2) offset(r = -2)` rounds the outside corners, not the inside ones** — chained
  operations run from the shape outward. (Lesson 5.)
