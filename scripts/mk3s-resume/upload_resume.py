"""Upload a resume file to PrusaLink WITHOUT starting it (Print-After-Upload: ?0).

usage: upload_resume.py <file.gcode>
The API key is read from the PrusaSlicer physical-printer profile and never printed.
"""
import json
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path

f = Path(sys.argv[1])
# The PrusaLink host and API key come from a PrusaSlicer physical-printer profile, which is
# gitignored because it holds the key in plaintext. Override the path with PRUSA_PRINTER_INI.
ini = Path(os.environ.get(
    "PRUSA_PRINTER_INI",
    Path(os.environ["APPDATA"]) / "PrusaSlicer" / "physical_printer" / "Prusa mk3S+.ini"))
cfg = dict(l.split(" = ", 1) for l in ini.read_text(encoding="utf-8").splitlines() if " = " in l)
host = cfg["print_host"].strip()
base = host if host.startswith("http") else "http://" + host
key = cfg["printhost_apikey"].strip()

data = f.read_bytes()
# /api/v1/status lists the writable storage as /local (the SD card is read-only)
url = f"{base}/api/v1/files/local/{urllib.parse.quote(f.name)}"
req = urllib.request.Request(url, data=data, method="PUT", headers={
    "X-Api-Key": key,
    "Content-Type": "text/x.gcode",
    "Content-Length": str(len(data)),
    "Print-After-Upload": "?0",
    "Overwrite": "?0",
})
try:
    with urllib.request.urlopen(req, timeout=600) as r:
        print("PUT", r.status, len(data), "bytes")
except urllib.error.HTTPError as e:
    print("PUT failed", e.code, e.read().decode("utf-8", "replace")[:300])
    sys.exit(1)

# read back: the file must be listed and the printer must NOT be printing
st = urllib.request.Request(f"{base}/api/v1/status", headers={"X-Api-Key": key})
with urllib.request.urlopen(st, timeout=10) as r:
    print("printer state after upload:", json.load(r)["printer"]["state"])
