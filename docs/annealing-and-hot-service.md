# Annealing, and plastic parts that carry load while hot — moved

This page was a reference on printed parts that carry load while hot: why HDT is not a service temperature and
the gap to the glass transition is the number that matters, what annealing does and does not do to an amorphous
plastic such as ASA, why a preloaded flexure must never be annealed under load, creep against stress relaxation,
a starting annealing schedule with how to support a thin part, which material holds a preload when hot, and how
to design the coupon test that measures it.

**Its general content is now the skill `printed-part-engineering`**, in the owner's engineering-practices
collection (private for now): the principles in the skill itself, and the long form with its sources - the
schedule and the test design included - in its `references/heat-annealing-creep.md`.

**The dated case it was written from** - a heated drybox's ASA spring insert, its preload, its bake and the
prediction recorded for it, in September 2026 - is kept with that project's own docs, in its own repository.

What stays in this repository: [`scripts/bed-anneal-gcode.py`](../scripts/bed-anneal-gcode.py), which anneals
parts on the printer's heated bed (ramp from cold, hold, slow cool), and the data sheets of the filaments on this
printer's shelf, in [fdm-design-rules](fdm-design-rules.md) §6b.
