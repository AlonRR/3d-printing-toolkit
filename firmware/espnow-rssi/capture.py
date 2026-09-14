"""Capture RXR lines from one or two boards at once and summarise RSSI per direction.

    python capture.py SECONDS PORT [PORT ...]

Each board logs `RXR <rssi> <src-mac> PING <n>` for every packet it hears, and
`TEMP <c>` every ~10 packets. For each port this reports, per source MAC:
samples, packet loss (from counter gaps), RSSI min / p10 / median / p90 / max,
and the chip-temperature range. MACs are printed for the chat only.
"""
import re
import statistics
import sys
import threading
import time

import serial

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

RX = re.compile(r"RXR (-?\d+) ([0-9a-f:]{17}) PING (\d+)")
TEMP = re.compile(r"TEMP (-?\d+\.\d)")
TXQ = re.compile(r"txq (-?\d+)")
SENT = re.compile(r"sent (\d+)")
BOOT = re.compile(r"BOOT own ([0-9a-f:]{17}) channel (\d+) txpower_quarter_dbm (-?\d+)")

secs = float(sys.argv[1])
ports = sys.argv[2:]
results = {}


def grab(port):
    s = serial.Serial()
    s.port, s.baudrate, s.timeout = port, 115200, 0.2
    s.dtr = False
    s.rts = False
    s.open()
    end = time.time() + secs
    buf = b""
    while time.time() < end:
        buf += s.read(8192)
    s.close()
    results[port] = buf.decode("utf-8", "replace")


threads = [threading.Thread(target=grab, args=(p,)) for p in ports]
for t in threads:
    t.start()
for t in threads:
    t.join()


def pct(xs, q):
    xs = sorted(xs)
    k = (len(xs) - 1) * q
    lo, hi = int(k), min(int(k) + 1, len(xs) - 1)
    return xs[lo] + (xs[hi] - xs[lo]) * (k - lo)


for port in ports:
    text = results[port]
    print("=== %s (%.0f s) ===" % (port, secs))
    b = BOOT.search(text)
    if b:
        print("  boot: own %s, channel %s, tx power %.2f dBm" % (b.group(1), b.group(2), int(b.group(3)) / 4))
    by_src = {}
    for m in RX.finditer(text):
        by_src.setdefault(m.group(2), []).append((int(m.group(1)), int(m.group(3))))
    if not by_src:
        print("  NO PACKETS RECEIVED")
        tail = text.strip().splitlines()[-5:]
        print("  last lines:", *tail, sep="\n    ")
    for src, rows in by_src.items():
        rssi = [r for r, _ in rows]
        seqs = sorted({n for _, n in rows})
        span = seqs[-1] - seqs[0] + 1
        loss = 100.0 * (1 - len(seqs) / span) if span > 0 else 0.0
        print("  from %s: n=%d  loss %.1f%% (seq %d..%d)" % (src, len(rows), loss, seqs[0], seqs[-1]))
        print("    RSSI dBm  min %d  p10 %.1f  median %.1f  p90 %.1f  max %d  stdev %.1f"
              % (min(rssi), pct(rssi, 0.1), statistics.median(rssi), pct(rssi, 0.9), max(rssi),
                 statistics.pstdev(rssi)))
    temps = [float(t) for t in TEMP.findall(text)]
    if temps:
        print("  chip temp C: %.1f .. %.1f (median %.1f, n=%d)"
              % (min(temps), max(temps), statistics.median(temps), len(temps)))
    txq = sorted({int(q) for q in TXQ.findall(text)})
    sent = [int(x) for x in SENT.findall(text)]
    if txq:
        print("  tx power in force: %s dBm" % ", ".join("%.2f" % (q / 4) for q in txq))
    if sent:
        print("  own packets sent (counter): %d .. %d" % (min(sent), max(sent)))
    if not txq:
        print("  tx power: NOT SEEN in this capture")
