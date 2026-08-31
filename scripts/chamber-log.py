"""Poll the chamber-baseline node over WiFi and log to CSV.

Reads ESPHome's web_server JSON endpoints, appends every sample to a CSV, and
prints only occasionally — this is meant to run for hours under a watcher, and
a line every 30 s would be noise rather than signal.

    python scripts/chamber-log.py [host] [--csv PATH] [--every SECONDS]

Default host is chamber-baseline.local. If mDNS does not resolve on this
machine, pass the IP instead; the node prints it to the serial log on boot.

Prints a line when: it starts, it loses or regains the node, the temperature
has moved >= 2.0 C since the last printed line, or ten minutes have passed.
Everything lands in the CSV regardless, which is the actual record.
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

SENSORS = {
    "temp_c": "/sensor/chamber_temperature",
    "rh_pct": "/sensor/chamber_humidity",
}
HEARTBEAT_S = 600
MOVED_C = 2.0


def read_one(host, path, timeout=5):
    url = f"http://{host}{path}"
    with urllib.request.urlopen(url, timeout=timeout) as r:
        return json.loads(r.read().decode())


def sample(host):
    out = {}
    for key, path in SENSORS.items():
        v = read_one(host, path).get("value")
        out[key] = None if v is None else float(v)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("host", nargs="?", default="chamber-baseline.local")
    ap.add_argument("--csv", default="data/chamber-baseline.csv")
    ap.add_argument("--every", type=float, default=30.0)
    ap.add_argument("--note", default="", help="free text recorded on every row, e.g. 'side open'")
    a = ap.parse_args()

    out = Path(a.csv)
    out.parent.mkdir(parents=True, exist_ok=True)
    fresh = not out.exists()
    fh = out.open("a", newline="", encoding="utf-8")
    w = csv.writer(fh)
    if fresh:
        w.writerow(["iso_time", "temp_c", "rh_pct", "note"])
        fh.flush()

    print(f"logging {a.host} -> {out} every {a.every:g}s", flush=True)
    last_print = 0.0
    last_temp = None
    online = None

    while True:
        now = time.time()
        stamp = datetime.now().isoformat(timespec="seconds")
        try:
            s = sample(a.host)
            t, rh = s["temp_c"], s["rh_pct"]
            w.writerow([stamp, t, rh, a.note])
            fh.flush()
            if online is False:
                print(f"{stamp}  node back", flush=True)
                last_print = 0.0
            online = True
            moved = last_temp is not None and t is not None and abs(t - last_temp) >= MOVED_C
            if moved or now - last_print >= HEARTBEAT_S or last_print == 0.0:
                print(f"{stamp}  {t:.1f} C  {rh:.0f} %RH"
                      + (f"   ({a.note})" if a.note else ""), flush=True)
                last_print, last_temp = now, t
        except (urllib.error.URLError, OSError, ValueError, KeyError, TypeError) as e:
            w.writerow([stamp, "", "", f"unreachable: {type(e).__name__}"])
            fh.flush()
            if online is not False:
                print(f"{stamp}  node unreachable ({type(e).__name__}) - still trying", flush=True)
            online = False
        time.sleep(a.every)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("stopped", flush=True)
        sys.exit(0)
