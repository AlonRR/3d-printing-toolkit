# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""A PrusaSlicer preset's `key = value` lines, for the scripts beside this one that read or rewrite presets."""

import re
from pathlib import Path

KV = re.compile(r"^([a-z_0-9]+) = (.*)$")


def key_values(lines):
    """Each `key = value` line's key and value; a key set twice keeps its last value. Comments do not match."""
    return {m.group(1): m.group(2) for m in (KV.match(line) for line in lines) if m}


def read_temperatures(path, keys):
    """The named keys of a filament profile as whole degrees - the first value of a list, as in
    `first_layer_temperature = 240,240`. A key the profile does not set is left out."""
    cfg = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        if " = " in line:
            k, v = line.split(" = ", 1)
            if k.strip() in keys:
                cfg[k.strip()] = int(float(v.split(",")[0].strip()))
    return cfg
