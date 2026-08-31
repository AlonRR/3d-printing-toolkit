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

An SSE connection to an ESP is NOT long-lived, and that is normal rather than a
fault: the stream itself carries `retry: 30000`, the server telling clients how
long to wait before reconnecting. Observed here, the socket was cut every ~5.5
minutes like clockwork. So a dropped stream is reconnected immediately and
silently; only a gap that persists past GRACE_S is treated - and recorded - as
the node actually being unreachable. Treating every reconnect as an outage cost
one sample each time and buried real failures in noise.

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
HEARTBEAT_DEFAULT_S = 600
MOVED_C = 2.0
GRACE_DEFAULT_S = 90.0  # tolerate routine SSE reconnects before calling it an outage


def stream(host):
    """Yield (id, value) pairs from the SSE endpoint until the socket drops."""
    req = urllib.request.Request(f"http://{host}/events",
                                 headers={"Accept": "text/event-stream"})
    with urllib.request.urlopen(req, timeout=20) as r:
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
    ap.add_argument("--grace", type=float, default=GRACE_DEFAULT_S,
                    help="seconds offline before it is reported as an outage. This "
                         "network drops the node for ~5 min on a known, self-healing "
                         "cycle; set --grace above that and only real problems speak. "
                         "The gap is still visible in the CSV as a time discontinuity")
    ap.add_argument("--heartbeat", type=float, default=HEARTBEAT_DEFAULT_S,
                    help="seconds between routine prints; the CSV is unaffected. "
                         "Raise it for an unattended overnight run - every print "
                         "costs a notification, and 'still fine' 48 times is noise")
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
    down_since = None

    while True:
        try:
            for ident, value in stream(a.host):
                if was_down:
                    print(f"{datetime.now().isoformat(timespec='seconds')}  node back", flush=True)
                    last_print = 0.0
                was_down = False
                down_since = None
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
                if moved or now - last_print >= a.heartbeat or last_print == 0.0:
                    rh_txt = f"{rh:.0f}" if rh is not None else "--"
                    print(f"{stamp}  {temp:.1f} C  {rh_txt} %RH"
                          + (f"   ({a.note})" if a.note else ""), flush=True)
                    last_print, last_temp = now, temp
        except (urllib.error.URLError, OSError, ValueError) as e:
            # A cut stream is routine - reconnect at once and say nothing. Only
            # complain once the node has been unreachable for longer than the
            # server's own advertised retry window plus slack.
            if down_since is None:
                down_since = time.time()
            elif not was_down and time.time() - down_since > a.grace:
                stamp = datetime.now().isoformat(timespec="seconds")
                w.writerow([stamp, "", "", f"unreachable: {type(e).__name__}"])
                fh.flush()
                print(f"{stamp}  node unreachable for >{a.grace:g}s "
                      f"({type(e).__name__}) - still retrying", flush=True)
                was_down = True
            time.sleep(1)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("stopped", flush=True)
        sys.exit(0)
