# The USB-C end

**The socket's mouth reaches the box's outside face, so a plug's body never enters the box.** Any cable
fits, and none needs measuring.

## Why the wall is thinned

The socket's shell overhangs the SuperMini's PCB by only 1.5 mm, so a normal 1.8 mm wall would leave the
mouth inside it. Over the board's end the right-hand wall is therefore thinned from inside to `port_wall`
(0.9 mm, two beads) across the board's whole width and height, and the PCB's end reaches into that
recess. The opening through what is left is the size of the shell, not of a plug, and its shape: a
stadium, round at both ends, `part_fit` clear all round. The cover prints front face down, so the end
towards the back plate is the opening's top on the bed; there it closes in a 45° point instead of a
round end, which would be an arch with nothing under it.

The thinned stretch is the one a plug's pull bears on across the layer lines, so its steps back to the
full wall are 45° chamfers rather than square inside corners, where a crack would start.

**Why not just size the opening for a plug?** A plug-sized opening in the cover alone is not enough: the
back plate's edge, which that opening does not reach, would stop a compliant plug body short of seating.
With the mouth at the face, the plug never comes near either part.

## What takes the push and the pull

The board can move a little along its length, and both ends of that travel are stops:

- **Pulling a plug out** draws the board outwards, `part_fit` (0.3 mm), until the PCB's corners, either
  side of the shell, bear on the thinned wall.
- **Pushing a plug in** drives the board inwards, `pocket_fit` (0.2 mm), against **two stops over the
  corners of its antenna end** — one on the back plate, one on the cover. Without them it would slide
  away from the plug, and the mouth would retreat into the wall at the moment it must not. Each reaches
  `stop_reach` (3 mm) in across the board's end from its long edge. The antenna loop lies in the board's plane past that end and leaves
  at least 4.3 mm of it free each side, so the stops clear the loop by 1.3 mm; an assert keeps it that way.

The clips and the front clasp grip the board's edges too, but the stops are what take the push. Pushed
in, the mouth stands 0.1 mm proud of the outside face; pulled out, 0.6 mm. An assert blocks any setting
that would leave it inside the wall.

## The plug beside the box

The plug's body sits beside the box, its centre 11.6 mm from the mounting surface. A compliant body is at
most 12.35 mm wide (USB Type-C specification), so it clears the wall the box hangs on by 5.4 mm. The model
echoes the figure.

There is no cable clamp on the box; how to secure the cable is in [Assembly](assembly.md#hanging-it).
