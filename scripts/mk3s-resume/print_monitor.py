# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""Watch the MK3S through PrusaLink and log every sample, for one Monitor window.

usage: print_monitor.py <log_dir> [max_seconds=3500] [interval=10]

Appends one JSON line per sample to <log_dir>/<YYYY-MM-DD>.jsonl: time, printer state, Z, bed and
nozzle temperature and target, job progress. Exits (so Monitor notifies) when
  * the printer leaves PRINTING after having been seen printing - finished, stopped, error,
  * max_seconds pass - still printing, re-arm.
Bed readings more than 5 degrees below target while printing are counted and reported: the
thermistor fault that caused the MINTEMP BED stop may show as dips before it trips again.
The API key comes from the PrusaSlicer physical-printer profile and is never printed.
"""

import datetime
import json
import sys
import time
import urllib.request
from dataclasses import dataclass, replace
from pathlib import Path

import prusalink


@dataclass(frozen=True)
class Watch:
    """What the samples so far add up to."""

    seen_printing: bool = False
    dips: int = 0
    blind: int = 0  # samples where the daemon served no temperatures at all
    min_bed: float | None = None
    last: dict | None = None


def get(base, key, path):
    """GET a PrusaLink path's JSON, or None for an empty body."""
    req = urllib.request.Request(base + path, headers={"X-Api-Key": key})
    with urllib.request.urlopen(req, timeout=10) as r:
        body = r.read().decode("utf-8", "replace")
        return json.loads(body) if body.strip() else None


def record(now, p, job):
    """One sample's log line, from the status's printer object and the job."""
    return {
        "t": now.isoformat(timespec="seconds"), "state": p.get("state"), "z": p.get("axis_z"),
        "bed": p.get("temp_bed"), "bed_target": p.get("target_bed"),
        "nozzle": p.get("temp_nozzle"), "nozzle_target": p.get("target_nozzle"),
        "progress": job.get("progress"), "time_remaining": job.get("time_remaining"),
        "file": (job.get("file") or {}).get("display_name"),
    }


def observe(w, rec):
    """The watch after one more sample."""
    w = replace(w, last=rec)
    if rec["state"] != "PRINTING":
        return w
    w = replace(w, seen_printing=True)
    # Both halves must be present: a reduced object gives bed=None, and comparing that against a
    # target raises - which would silently stop the dip count, the one thing this is here for.
    if rec["bed"] is not None and rec["bed_target"]:
        w = replace(w, min_bed=rec["bed"] if w.min_bed is None else min(w.min_bed, rec["bed"]))
        if rec["bed"] < rec["bed_target"] - 5 and rec["progress"] not in (None, 0):
            w = replace(w, dips=w.dips + 1)
    elif rec["bed"] is None:
        w = replace(w, blind=w.blind + 1)
    return w


def blind_note(w):
    return f", {w.blind} blind samples (daemon restarting)" if w.blind else ""


def append(log_dir, now, line):
    with open(log_dir / f"{now:%Y-%m-%d}.jsonl", "a", encoding="utf-8") as f:
        f.write(line + "\n")


def main(argv):
    log_dir = Path(argv[1])
    max_s = float(argv[2]) if len(argv) > 2 else 3500
    interval = float(argv[3]) if len(argv) > 3 else 10
    log_dir.mkdir(parents=True, exist_ok=True)
    base, key = prusalink.connection()

    t0 = time.monotonic()
    w = Watch()
    errors = 0
    while time.monotonic() - t0 < max_s:
        now = datetime.datetime.now().astimezone()
        try:
            # PrusaLink serves 200 with a REDUCED object while the daemon restarts - no temperature
            # or axis fields at all. Measured 17 Sep: ~20 s of it, then the full object returns.
            p = (get(base, key, "/api/v1/status") or {}).get("printer") or {}
            job = get(base, key, "/api/v1/job") or {}
            errors = 0
        except Exception as e:  # noqa: BLE001 - PrusaLink or network hiccup: log and keep going
            errors += 1
            append(log_dir, now, json.dumps({"t": now.isoformat(timespec="seconds"), "error": repr(e)[:200]}))
            if errors >= 30:
                print(f"{now:%H:%M:%S} PrusaLink unreachable for {errors} samples - exiting")
                return 2
            time.sleep(interval)
            continue
        rec = record(now, p, job)
        append(log_dir, now, json.dumps(rec, ensure_ascii=False))
        w = observe(w, rec)
        if rec["state"] != "PRINTING" and w.seen_printing:
            print(f"{now:%H:%M:%S} printer left PRINTING -> {rec['state']}; last Z {rec['z']}, "
                  f"bed {rec['bed']}/{rec['bed_target']}, dips {w.dips}, min bed while printing {w.min_bed}"
                  + blind_note(w))
            return 0
        time.sleep(interval)

    last = w.last
    print(f"window over: state {last and last['state']}, Z {last and last['z']}, progress "
          f"{last and last['progress']}%, bed dips {w.dips}, min bed while printing {w.min_bed}"
          + blind_note(w) + " - re-arm")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
