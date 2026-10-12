# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""Upload a resume file to PrusaLink WITHOUT starting it (Print-After-Upload: ?0).

usage: upload_resume.py <file.gcode>
The API key is read from the PrusaSlicer physical-printer profile and never printed.
"""

import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import prusalink


def on_printer(url, key):
    """Whether the printer already has a file at url: a 404 says not, any other error is raised."""
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"X-Api-Key": key}), timeout=15):
            return True
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise
    return False


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


def main(argv):
    f = Path(argv[1])
    base, key = prusalink.connection()
    data = f.read_bytes()
    # Resolve redirects with a small GET BEFORE sending the file. Behind the proxy, plain http answers
    # every request with 308 to https - and on a PUT the server may answer and close while the body is
    # still going out. Measured 2 Oct 2026: the first 2.9 MB upload followed the 308 and landed; the
    # second died mid-body with ConnectionAbortedError and left nothing on the printer. urllib follows
    # a GET's redirects itself, so its final URL gives the scheme and host to PUT to directly.
    status_req = urllib.request.Request(f"{base}/api/v1/status", headers={"X-Api-Key": key})
    with urllib.request.urlopen(status_req, timeout=15) as r:
        base = prusalink.origin(r.geturl())
    # /api/v1/status lists the writable storage as /local (the SD card is read-only)
    url = f"{base}/api/v1/files/local/{urllib.parse.quote(f.name)}"
    # A file of that name already on the printer: with Overwrite off, PrusaLink refuses the PUT, and behind the
    # proxy the refusal arrives as a connection reset mid-body, not as a 409. Measured 11 Oct 2026: three resets
    # for a name uploaded the day before, then a 201 under a new name. So ask first, and say so plainly.
    if on_printer(url, key):
        print(f"{f.name} is already on the printer, and this never overwrites: upload it under another name")
        return 1

    status, final = put(url, data, key)
    # Report the scheme actually used, never the host - this output can end up in a transcript.
    print("PUT", status, len(data), "bytes", f"(via {urllib.parse.urlparse(final).scheme})")

    # read back: the file must be listed and the printer must NOT be printing
    st = urllib.request.Request(f"{base}/api/v1/status", headers={"X-Api-Key": key})
    with urllib.request.urlopen(st, timeout=10) as r:
        print("printer state after upload:", json.load(r)["printer"]["state"])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
