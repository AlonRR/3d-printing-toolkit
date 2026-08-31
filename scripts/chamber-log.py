"""Log the chamber-baseline node to CSV over WiFi.

    python scripts/chamber-log.py [host] [--csv PATH] [--every SECONDS] [--note TEXT]

Consumes ESPHome's Server-Sent Events stream at /events rather than polling the
per-entity REST paths. Two reasons:

  * The REST paths are not what you would guess. ESPHome derives the id from the
    entity NAME verbatim, so it is `/sensor/Chamber temperature` - space, capital
    C - not `/sensor/chamber_temperature`. Guessing returns a bare 404 with no
    hint, which is a long way to walk for a typo.
  * /events pushes both sensors down one connection every few seconds, so there
    is no polling interval to tune and no missed samples between polls.

Writes every sample to CSV - that is the record - and prints sparingly, because
a run lasts hours and a line every few seconds is noise. It prints on start, on
losing or regaining the node, on a >= 2 C move since the last printed line, and
every ten minutes regardless.
"""
import argparse
import csv
import json
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path

TEMP_ID = "sensor/Chamber temperature"
RH_ID = "sensor/Chamber humidity"
HEARTBEAT_S = 600
MOVED_C = 2.0


def stream(host):
    """Yield (id, value) pairs from the SSE endpoint until the socket drops."""
    req = urllib.request.Request(f"http://{host}/events",
                                 headers={"Accept": "text/event-stream"})
    with urllib.request.urlopen(req, timeout=30) as r:
        event = None
        for raw in r:
            line = raw.decode("utf-8", "replace").rstrip("\n")
            if line.startswith("event:"):
                event = line[6:].strip()
            elif line.startswith("data:") and event == "state":
                try:
                    d = json.loads(line[5:].strip())
                except ValueError:
                    continue
                if "id" in d:
                    yield d["id"], d.get("value")
            elif not line:
                event = None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("host", nargs="?", default="chamber-baseline.local")
    ap.add_argument("--csv", default="data/chamber-baseline.csv")
    ap.add_argument("--every", type=float, default=30.0,
                    help="minimum seconds between CSV rows")
    ap.add_argument("--note", default="",
                    help="recorded on every row, e.g. 'side open'")
    a = ap.parse_args()

    out = Path(a.csv)
    out.parent.mkdir(parents=True, exist_ok=True)
    fresh = not out.exists()
    fh = out.open("a", newline="", encoding="utf-8")
    w = csv.writer(fh)
    if fresh:
        w.writerow(["iso_time", "temp_c", "rh_pct", "note"])
        fh.flush()

    print(f"logging {a.host} -> {out}"
          + (f"   note={a.note!r}" if a.note else ""), flush=True)

    temp = rh = None
    last_row = 0.0
    last_print = 0.0
    last_temp = None
    was_down = False

    while True:
        try:
            for ident, value in stream(a.host):
                if was_down:
                    print(f"{datetime.now().isoformat(timespec='seconds')}  node back", flush=True)
                    was_down, last_print = False, 0.0
                if ident == TEMP_ID:
                    temp = value
                elif ident == RH_ID:
                    rh = value
                else:
                    continue

                now = time.time()
                # hold the very first row until humidity has arrived too, so the
                # CSV does not open with a half-empty line; after that, log temp
                # even if humidity stops reporting.
                if temp is None or now - last_row < a.every:
                    continue
                if last_row == 0.0 and rh is None:
                    continue
                stamp = datetime.now().isoformat(timespec="seconds")
                w.writerow([stamp, temp, rh, a.note])
                fh.flush()
                last_row = now

                moved = last_temp is not None and abs(temp - last_temp) >= MOVED_C
                if moved or now - last_print >= HEARTBEAT_S or last_print == 0.0:
                    rh_txt = f"{rh:.0f}" if rh is not None else "--"
                    print(f"{stamp}  {temp:.1f} C  {rh_txt} %RH"
                          + (f"   ({a.note})" if a.note else ""), flush=True)
                    last_print, last_temp = now, temp
        except (urllib.error.URLError, OSError, ValueError) as e:
            if not was_down:
                stamp = datetime.now().isoformat(timespec="seconds")
                w.writerow([stamp, "", "", f"unreachable: {type(e).__name__}"])
                fh.flush()
                print(f"{stamp}  node unreachable ({type(e).__name__}) - retrying", flush=True)
                was_down = True
            time.sleep(5)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("stopped", flush=True)
        sys.exit(0)
