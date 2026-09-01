"""Log the ESP-NOW hub's serial output to CSV. Runs on the server, not here.

    python3 chamber-serial-log.py [--port /dev/ttyACM0] [--csv PATH] [--note TEXT]

The hub C3 is plugged into the server's USB and prints one line per update:

    [12:34:56][I][hub:062]: CHAMBER 24.3 36.7

This reads those and appends to CSV. It exists because the WiFi path could not
stay up: the access point refused the sensor node every 20-50 minutes, and the
poller lived inside an interactive session that dies with the terminal. A USB
cable is not something an access point can refuse, and the server is always on.

Deliberately dependency-light - pyserial only - so it can run under a systemd
unit on a small Linux host without dragging in a toolchain.

Prints sparingly for the same reason the WiFi logger did: a run lasts hours and
a line every 30 s is noise. On start, on a >= 2 C move, and hourly.
"""
import argparse
import csv
import re
import sys
import time
from datetime import datetime
from pathlib import Path

import serial

# Matches the hub's log line. Anchored on the CHAMBER tag rather than the whole
# ESPHome log format, so a logger level or tag change does not break parsing.
LINE = re.compile(r"CHAMBER\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)")
MOVED_C = 2.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyACM0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--csv", default="/opt/chamber-logger/chamber.csv")
    ap.add_argument("--note", default="")
    ap.add_argument("--every", type=float, default=30.0,
                    help="minimum seconds between CSV rows")
    ap.add_argument("--heartbeat", type=float, default=3600.0,
                    help="seconds between routine prints; the CSV is unaffected")
    a = ap.parse_args()

    out = Path(a.csv)
    out.parent.mkdir(parents=True, exist_ok=True)
    fresh = not out.exists()
    fh = out.open("a", newline="", encoding="utf-8")
    w = csv.writer(fh)
    if fresh:
        w.writerow(["iso_time", "temp_c", "rh_pct", "note"])
        fh.flush()

    print(f"logging {a.port} -> {out}"
          + (f"   note={a.note!r}" if a.note else ""), flush=True)

    last_row = 0.0
    last_print = 0.0
    last_temp = None

    while True:
        try:
            # Opened inside the loop so unplugging the hub is survivable: the
            # read raises, we sleep, and reconnect when the device reappears.
            with serial.Serial(a.port, a.baud, timeout=10) as ser:
                while True:
                    raw = ser.readline()
                    if not raw:
                        continue
                    m = LINE.search(raw.decode("utf-8", "replace"))
                    if not m:
                        continue
                    temp, rh = float(m.group(1)), float(m.group(2))
                    now = time.time()
                    if now - last_row < a.every:
                        continue
                    stamp = datetime.now().isoformat(timespec="seconds")
                    w.writerow([stamp, temp, rh, a.note])
                    fh.flush()
                    last_row = now

                    moved = last_temp is not None and abs(temp - last_temp) >= MOVED_C
                    if moved or now - last_print >= a.heartbeat or last_print == 0.0:
                        print(f"{stamp}  {temp:.1f} C  {rh:.0f} %RH"
                              + (f"   ({a.note})" if a.note else ""), flush=True)
                        last_print, last_temp = now, temp
        except (serial.SerialException, OSError) as e:
            stamp = datetime.now().isoformat(timespec="seconds")
            print(f"{stamp}  serial error ({type(e).__name__}) - retrying", flush=True)
            time.sleep(5)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("stopped", flush=True)
        sys.exit(0)
