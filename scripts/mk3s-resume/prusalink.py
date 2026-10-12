# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""Where PrusaLink is and the key it wants, for the scripts beside this one that talk to the printer.

The host and the API key come from a PrusaSlicer physical-printer profile, which is gitignored because it holds
the key in plaintext. PRUSA_PRINTER_INI overrides the profile's path. Neither the host nor the key is ever printed:
these scripts' output can end up in a transcript.
"""

import os
import urllib.parse
from pathlib import Path

PROFILE = Path("PrusaSlicer") / "physical_printer" / "Prusa mk3S+.ini"


def profile_path(environ=os.environ):
    """The physical-printer profile: PRUSA_PRINTER_INI, or PrusaSlicer's own under APPDATA.

    ⚠️ Resolved lazily on purpose. The obvious one-liner puts the APPDATA lookup in environ.get()'s DEFAULT
    argument, which Python evaluates EAGERLY - so it raises on any host without APPDATA even when the override is
    set, which is precisely when someone is pointing this at a stub or a Linux box.
    """
    override = environ.get("PRUSA_PRINTER_INI")
    return Path(override) if override else Path(environ["APPDATA"]) / PROFILE


def read_profile(path):
    """A preset's `key = value` lines, as a dict of strings."""
    return dict(line.split(" = ", 1) for line in path.read_text(encoding="utf-8").splitlines() if " = " in line)


def connection(environ=os.environ):
    """(base URL, API key) from the physical-printer profile; a bare host is taken as http."""
    cfg = read_profile(profile_path(environ))
    host = cfg["print_host"].strip()
    return (host if host.startswith("http") else "http://" + host), cfg["printhost_apikey"].strip()


def origin(url):
    """scheme://host of a URL - the one a GET ended at, after the redirects urllib followed for it.

    Behind a reverse proxy, plain http answers every request with 308 to https. urllib follows that for a GET but
    not for a PUT or a POST, so a script resolves the redirect with a small GET first and sends the rest straight
    to the final scheme and host.
    """
    u = urllib.parse.urlparse(url)
    return f"{u.scheme}://{u.netloc}"
