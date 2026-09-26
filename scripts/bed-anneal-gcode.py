# /// script
# requires-python = ">=3.11"
# ///
"""A G-code "print" that anneals parts on the MK3S's heated bed.

    uv run scripts/bed-anneal-gcode.py [--hold 95] [--hours 3] [-o anneal.gcode]

Setting the bed from the LCD does not work for this: the firmware's safety timer switches the heaters
off after ~30 min with no print running. A print keeps them on. This one never moves the head or the
bed and never heats the nozzle. It only:

  1. ramps the bed from cold in steps, waiting at each (the part comes up with the "oven", not into it);
  2. holds the target for --hours;
  3. steps the bed down slowly to --cool-to, then switches it off (a slow cool is what stops new stress
     being frozen in - docs/annealing-and-hot-service.md, on main, sec. 5).

Every wait is a string of short G4 dwells rather than one long one. Streamed from PrusaLink, the
firmware counts a print as running only while commands keep arriving, and a single hour-long dwell
could let the safety timer fire in the middle of it. M73 keeps the LCD's progress and time left right.

During the hold nothing re-sends the bed target, so LCD -> Tune -> Bed adjusts it for the rest of the
hold. The cool-down steps then take over from the hold temperature they were written for.
"""
import argparse
from pathlib import Path

DWELL = 5          # s per G4 line - well under the firmware's "a command arrived recently" window


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hold", type=float, default=95, help="bed target during the hold, °C (MK3S max 120)")
    ap.add_argument("--hours", type=float, default=3, help="hold time at the target")
    ap.add_argument("--ramp-step", type=float, default=10, help="°C per ramp step")
    ap.add_argument("--ramp-min", type=float, default=10, help="minutes held at each ramp step, once reached")
    ap.add_argument("--cool-step", type=float, default=5, help="°C per cool-down step")
    ap.add_argument("--cool-min", type=float, default=10, help="minutes per cool-down step")
    ap.add_argument("--cool-to", type=float, default=40, help="bed off below this")
    ap.add_argument("-o", "--out", type=Path, default=None)
    a = ap.parse_args()
    if not 40 <= a.hold <= 120:
        ap.error("--hold must be 40-120 °C (the MK3S bed's range)")

    ramp = []
    t = 40.0
    while t < a.hold:
        ramp.append(t)
        t += a.ramp_step
    ramp.append(a.hold)
    cool = []
    t = a.hold - a.cool_step
    while t >= a.cool_to:
        cool.append(t)
        t -= a.cool_step
    # planned minutes, for M73 - ramp waits to reach temperature are not counted, so the estimate is low
    total = len(ramp) * a.ramp_min + a.hours * 60 + len(cool) * a.cool_min
    done = 0.0
    out = []

    def say(msg):
        out.append(f"M117 {msg[:20]}")

    def dwell(minutes, label):
        nonlocal done
        n = int(round(minutes * 60 / DWELL))
        for i in range(n):
            if i % int(60 / DWELL) == 0:            # once a minute
                left = max(total - done - i * DWELL / 60, 0)
                out.append(f"M73 P{min(99, int(100 * (done + i * DWELL / 60) / total))} R{int(left)}")
                if i % int(600 / DWELL) == 0:       # every ten minutes
                    say(f"{label} {int(left)}m left")
            out.append(f"G4 S{DWELL}")
        done += minutes

    name = a.out.name if a.out else f"anneal-bed-{a.hold:g}C-{a.hours:g}h.gcode"
    out += [
        f"; {name} - bed anneal: ramp to {a.hold:g} C, hold {a.hours:g} h, cool to {a.cool_to:g} C, off",
        "; written by scripts/bed-anneal-gcode.py. Never moves the head or the bed; never heats the nozzle.",
        "; Place the parts clear of the nozzle before starting. LCD Tune -> Bed adjusts the hold.",
        "M104 S0 ; nozzle off",
        "M107 ; part fan off",
        "M73 P0 R%d" % int(total),
    ]
    for t in ramp:
        say(f"Anneal ramp {t:g}C")
        out.append(f"M190 S{t:g} ; wait for the bed")
        dwell(a.ramp_min if t < a.hold else 0, f"Ramp {t:g}C")
    say(f"Anneal hold {a.hold:g}C")
    dwell(a.hours * 60, f"Hold {a.hold:g}C")
    for t in cool:
        out.append(f"M140 S{t:g} ; step down")
        dwell(a.cool_min, f"Cool {t:g}C")
    out += ["M140 S0 ; bed off", "M73 P100 R0", "M117 Anneal done", ""]

    path = a.out or Path(name)
    path.write_text("\n".join(out), encoding="utf-8", newline="\n")
    print(f"{path}: ramp {', '.join(f'{t:g}' for t in ramp)} C; hold {a.hold:g} C {a.hours:g} h; "
          f"cool in {a.cool_step:g} C steps to {a.cool_to:g} C; ~{total / 60:.1f} h planned, plus the ramp's heating")


if __name__ == "__main__":
    main()
