# Mechanical design review — moved

This page was a reference for reviewing a printed mechanical assembly: the twelve questions a collision check
never asks (assembly, constraint, tolerance stacks, printed plastic under load, fastening, seals, plastic springs
under permanent load, heat, motion, service, moisture, process), each with its sources, and a 22-row checklist to
run against an OpenSCAD model.

**Its general content is now the skill `printed-part-engineering`**, in the owner's engineering-practices
collection (private for now). The principles and their numbers are in the skill itself; the twelve questions in
full, the checklist and the sources are in its `references/design-review.md`. The design choices the review
touched - located before released, wrong-way-round parts, captive nuts, tool access - are in its companion skill,
`printed-part-design`.

**The dated case it was written from** - a desiccant module's spring inserts, which fell over in their first
coupon in September 2026, and the checks that had passed them - is kept with that project's own docs, in its own
repository.

What stays in this repository is the printer's side: wall widths, layer heights, overhangs, bridges, hole
compensation and the fits measured on coupons, in [fdm-design-rules](fdm-design-rules.md).
