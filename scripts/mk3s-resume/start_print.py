# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""Start a file already uploaded to PrusaLink, then read the job back.

usage: start_print.py <file.gcode>
The local file is the reference: the printer's copy of the same name must have its exact size, and
the printer must be IDLE, READY or FINISHED - otherwise nothing is sent. Upload with
upload_resume.py first, which never starts anything. Exit 0 = started and PRINTING read back,
1 = refused or failed. The API key is read from the PrusaSlicer physical-printer profile and never
printed, nor the host.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

STARTABLE = ("IDLE", "READY", "FINISHED")

f = Path(sys.argv[1])
size = f.stat().st_size
# Same profile, same lazy lookup as upload_resume.py: PRUSA_PRINTER_INI overrides it.
_override = os.environ.get("PRUSA_PRINTER_INI")
ini = Path(_override) if _override else (
    Path(os.environ["APPDATA"]) / "PrusaSlicer" / "physical_printer" / "Prusa mk3S+.ini")
cfg = dict(l.split(" = ", 1) for l in ini.read_text(encoding="utf-8").splitlines() if " = " in l)
host = cfg["print_host"].strip()
base = host if host.startswith("http") else "http://" + host
H = {"X-Api-Key": cfg["printhost_apikey"].strip()}


def get(path):
    with urllib.request.urlopen(urllib.request.Request(base + path, headers=H), timeout=15) as r:
        return r.status, (json.load(r) if r.status != 204 else None), r.geturl()


# A GET follows the proxy's http -> https 308 by itself; urllib will not follow it for the POST
# (upload_resume.py's docstring), so the POST goes straight to the final scheme and host.
_, st, final = get("/api/v1/status")
u = urllib.parse.urlparse(final)
base = f"{u.scheme}://{u.netloc}"

state = st["printer"]["state"]
path = "/api/v1/files/local/" + urllib.parse.quote(f.name)
try:
    _, info, _ = get(path)
except urllib.error.HTTPError as e:
    sys.exit(f"REFUSED: {f.name} is not on the printer (HTTP {e.code}) - upload it first")
print(f"printer has {f.name}, {info.get('size')} bytes; local {size} bytes; printer {state}")
if info.get("size") != size:
    sys.exit("REFUSED: the printer's copy is not the local file - upload it again")
if state not in STARTABLE:
    sys.exit(f"REFUSED: the printer is {state}, not one of {', '.join(STARTABLE)}")

req = urllib.request.Request(base + path, method="POST", headers=H)
try:
    with urllib.request.urlopen(req, timeout=30) as r:
        print("start:", r.status)
except urllib.error.HTTPError as e:
    sys.exit(f"start failed: HTTP {e.code} {e.read().decode('utf-8', 'replace')[:200]}")

# The job can take a moment to appear: 204 = no job yet.
for _ in range(10):
    time.sleep(float(os.environ.get("START_PRINT_POLL", "3")))
    code, job, _ = get("/api/v1/job")
    if code == 200 and job:
        jf = job.get("file") or {}
        name = jf.get("name") or jf.get("display_name")
        print("job:", job.get("state"), "|", name, "| time left", job.get("time_remaining"), "s")
        sys.exit(0 if job.get("state") == "PRINTING" and name == f.name else 1)
sys.exit("no job appeared after the start - look at the printer")
