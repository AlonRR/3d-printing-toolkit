# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""Upload a resume file to PrusaLink WITHOUT starting it (Print-After-Upload: ?0).

usage: upload_resume.py <file.gcode>
The API key is read from the PrusaSlicer physical-printer profile and never printed.
"""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

f = Path(sys.argv[1])
# The PrusaLink host and API key come from a PrusaSlicer physical-printer profile, which is
# gitignored because it holds the key in plaintext. Override the path with PRUSA_PRINTER_INI.
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

data = f.read_bytes()
# Resolve redirects with a small GET BEFORE sending the file. Behind the proxy, plain http answers
# every request with 308 to https - and on a PUT the server may answer and close while the body is
# still going out. Measured 2 Oct 2026: the first 2.9 MB upload followed the 308 and landed; the
# second died mid-body with ConnectionAbortedError and left nothing on the printer. urllib follows
# a GET's redirects itself, so its final URL gives the scheme and host to PUT to directly.
with urllib.request.urlopen(urllib.request.Request(f"{base}/api/v1/status", headers={"X-Api-Key": key}),
                            timeout=15) as r:
    final = urllib.parse.urlparse(r.geturl())
    base = f"{final.scheme}://{final.netloc}"
# /api/v1/status lists the writable storage as /local (the SD card is read-only)
url = f"{base}/api/v1/files/local/{urllib.parse.quote(f.name)}"
def put(url, data, key, hops=2):
    """PUT, following a redirect by hand.

    urllib will NOT auto-follow a redirect for PUT: HTTPRedirectHandler only re-issues GET and
    HEAD (plus POST on 301/302/303) and raises HTTPError for anything else. When PrusaLink sits
    behind a reverse proxy that upgrades http to https, EVERY request answers 308 - so GETs follow
    silently and look healthy while the upload dies on a redirect it was never going to follow.
    Measured 17 Sep: status, file listings and the upload all returned 308 to the https form.
    """
    for hop in range(hops):
        req = urllib.request.Request(url, data=data, method="PUT", headers={
            "X-Api-Key": key,
            "Content-Type": "text/x.gcode",
            "Content-Length": str(len(data)),
            "Print-After-Upload": "?0",
            "Overwrite": "?0",
        })
        try:
            with urllib.request.urlopen(req, timeout=600) as r:
                return r.status, url
        except urllib.error.HTTPError as e:
            loc = e.headers.get("Location") if e.headers else None
            if e.code in (301, 302, 307, 308) and loc and hop < hops - 1:
                url = urllib.parse.urljoin(url, loc)   # absolute or relative Location
                continue
            body = e.read().decode("utf-8", "replace")[:300]
            print(f"PUT failed {e.code} {body}")
            sys.exit(1)
    print(f"PUT failed: more than {hops} redirects")
    sys.exit(1)


status, final = put(url, data, key)
# Report the scheme actually used, never the host - this output can end up in a transcript.
print("PUT", status, len(data), "bytes", f"(via {urllib.parse.urlparse(final).scheme})")

# read back: the file must be listed and the printer must NOT be printing
st = urllib.request.Request(f"{base}/api/v1/status", headers={"X-Api-Key": key})
with urllib.request.urlopen(st, timeout=10) as r:
    print("printer state after upload:", json.load(r)["printer"]["state"])
