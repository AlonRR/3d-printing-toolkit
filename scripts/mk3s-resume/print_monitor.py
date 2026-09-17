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
import os
import sys
import time
import urllib.request
from pathlib import Path

log_dir = Path(sys.argv[1])
max_s = float(sys.argv[2]) if len(sys.argv) > 2 else 3500
interval = float(sys.argv[3]) if len(sys.argv) > 3 else 10
log_dir.mkdir(parents=True, exist_ok=True)

# The PrusaLink host and API key come from a PrusaSlicer physical-printer profile, which is
# gitignored because it holds the key in plaintext. Override the path with PRUSA_PRINTER_INI.
#
# ⚠️ Resolved lazily on purpose. The obvious one-liner puts the APPDATA lookup in os.environ.get()'s
# DEFAULT argument, which Python evaluates EAGERLY - so it raises on any host without APPDATA even
# when the override is set, which is precisely when someone is pointing this at a stub or a Linux box.
_override = os.environ.get("PRUSA_PRINTER_INI")
ini = Path(_override) if _override else (
    Path(os.environ["APPDATA"]) / "PrusaSlicer" / "physical_printer" / "Prusa mk3S+.ini")
cfg = dict(l.split(" = ", 1) for l in ini.read_text(encoding="utf-8").splitlines() if " = " in l)
host = cfg["print_host"].strip()
base = host if host.startswith("http") else "http://" + host
key = cfg["printhost_apikey"].strip()


def get(path):
    req = urllib.request.Request(base + path, headers={"X-Api-Key": key})
    with urllib.request.urlopen(req, timeout=10) as r:
        body = r.read().decode("utf-8", "replace")
        return json.loads(body) if body.strip() else None


t0 = time.monotonic()
seen_printing = False
dips = 0
blind = 0          # samples where the daemon served no temperatures at all
min_bed = None
last = None
errors = 0
while time.monotonic() - t0 < max_s:
    now = datetime.datetime.now().astimezone()
    try:
        # PrusaLink serves 200 with a REDUCED object while the daemon restarts - no temperature
        # or axis fields at all. Measured 17 Sep: ~20 s of it, then the full object returns.
        p = (get("/api/v1/status") or {}).get("printer") or {}
        job = get("/api/v1/job") or {}
        errors = 0
    except Exception as e:                       # PrusaLink or network hiccup: log and keep going
        errors += 1
        with open(log_dir / f"{now:%Y-%m-%d}.jsonl", "a", encoding="utf-8") as f:
            f.write(json.dumps({"t": now.isoformat(timespec="seconds"), "error": repr(e)[:200]}) + "\n")
        if errors >= 30:
            print(f"{now:%H:%M:%S} PrusaLink unreachable for {errors} samples - exiting")
            sys.exit(2)
        time.sleep(interval)
        continue
    rec = {
        "t": now.isoformat(timespec="seconds"), "state": p.get("state"), "z": p.get("axis_z"),
        "bed": p.get("temp_bed"), "bed_target": p.get("target_bed"),
        "nozzle": p.get("temp_nozzle"), "nozzle_target": p.get("target_nozzle"),
        "progress": job.get("progress"), "time_remaining": job.get("time_remaining"),
        "file": (job.get("file") or {}).get("display_name"),
    }
    with open(log_dir / f"{now:%Y-%m-%d}.jsonl", "a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    last = rec
    if rec["state"] == "PRINTING":
        seen_printing = True
        # Both halves must be present: a reduced object gives bed=None, and comparing that against a
        # target raises - which would silently stop the dip count, the one thing this is here for.
        if rec["bed"] is not None and rec["bed_target"]:
            min_bed = rec["bed"] if min_bed is None else min(min_bed, rec["bed"])
            if rec["bed"] < rec["bed_target"] - 5 and rec["progress"] not in (None, 0):
                dips += 1
        elif rec["bed"] is None:
            blind += 1
    elif seen_printing:
        print(f"{now:%H:%M:%S} printer left PRINTING -> {rec['state']}; last Z {rec['z']}, "
              f"bed {rec['bed']}/{rec['bed_target']}, dips {dips}, min bed while printing {min_bed}"
              + (f", {blind} blind samples (daemon restarting)" if blind else ""))
        sys.exit(0)
    time.sleep(interval)

print(f"window over: state {last and last['state']}, Z {last and last['z']}, progress "
      f"{last and last['progress']}%, bed dips {dips}, min bed while printing {min_bed}"
      + (f", {blind} blind samples (daemon restarting)" if blind else "") + " - re-arm")
