# The USB-C end

**The socket's mouth reaches the box's outside face, so a plug's body never enters the box.** Any cable
fits, and none needs measuring.

## Why the wall is thinned

The socket's shell overhangs the SuperMini's PCB by only 1.5 mm, so a normal 1.8 mm wall would leave the
mouth 0.6 mm inside it. Over the board's end the wall is therefore thinned from inside to `port_wall`
(0.9 mm, two beads), and the PCB's end reaches into that recess. The opening through what is left is the
size of the shell, not of a plug.

The recess is as tall as the board's tallest part, not just as thick as the PCB, because something
besides the socket sits 0.69 mm from the board's USB end on its component side. That makes the thinned
wall the one stretch that a plug's pull bears on across the layer lines, so its step back to the full
wall is a 45° chamfer rather than a square inside corner, where a crack would start.

**Why not just size the opening for a plug?** A plug-sized opening in the cover alone is not enough: the
back plate's edge, which that opening does not reach, would stop a compliant plug body short of seating.
With the mouth at the face, the plug never comes near either part.

## What takes the push and the pull

The board can move `part_fit` either way along its length, and both ends of that travel are stops:

- **Pulling a plug out** draws the board outwards until the PCB's corners, either side of the shell, bear
  on the thinned wall.
- **Pushing a plug in** drives the board inwards, against **two stops over the corners of its antenna
  end**. Without them it would slide away from the plug, and the mouth would retreat into the wall at
  the moment it must not. Each stop reaches `stop_reach` (3 mm) in from its rim, 2.8 mm over the PCB.
  The antenna loop lies in the board's plane past that end and leaves 4.3 mm and 5.45 mm of it free, so
  the stops clear the loop by at least 1.5 mm; an assert keeps it that way.

Pushed in, the mouth stands 0.1 mm proud of the outside face; pulled out, 0.6 mm. An assert blocks any
setting that would leave it inside the wall.

## The plug beside the box

The plug's body sits beside the box, 4.83 mm from the mounting surface at its centre, so **any body up
to 9.66 mm thick clears the wall the box is screwed to**. A compliant one is at most 6.5 mm (USB Type-C
specification). The model echoes both figures.

There is no cable clamp on the box; how to secure the cable is in [Assembly](assembly.md#hanging-it).
