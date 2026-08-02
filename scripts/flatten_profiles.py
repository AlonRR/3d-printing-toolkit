"""Flatten hand-written PrusaSlicer user filament presets.

PrusaSlicer does NOT resolve `inherits` when loading a user preset — any key
absent from the file falls back to the system default, not the parent's value.
So a sparse hand-written preset silently loses the parent's tuning (Linear
Advance start gcode, ramming params, cooling logic, retraction...).

This resolves the real inheritance chain out of PrusaResearch.ini and writes
complete presets, with precedence:

    reference template (same material, PrusaSlicer-written -> full key set)
      < resolved parent chain from the vendor bundle
        < the author's explicit overrides from the sparse file
"""
import re
import shutil
from pathlib import Path

APPDATA = Path.home() / "AppData/Roaming/PrusaSlicer"
VENDOR = APPDATA / "vendor/PrusaResearch.ini"
FILAMENT = APPDATA / "filament"
MASTERS = Path(__file__).resolve().parent.parent / "slicer/filament/inslogic"

# profile -> (parent in vendor bundle, reference template for the full key set)
JOBS = {
    "Inslogic ASA":                   ("Prusament ASA",            "YASIN ASA @0.8 nozzle"),
    "Inslogic ASA @0.8 nozzle":       ("Prusament ASA @0.8 nozzle","YASIN ASA @0.8 nozzle"),
    "Inslogic ASA - vase":            ("Prusament ASA",            "YASIN ASA @0.8 nozzle"),
    "Inslogic ASA - leaves":          ("Prusament ASA",            "YASIN ASA @0.8 nozzle"),
    "Inslogic TPU 95A":               ("Generic FLEX",             "Ultrafuse TPU-95A - Copy"),
    "Inslogic TPU 95A @0.8 nozzle":   ("Generic FLEX @0.8 nozzle", "Ultrafuse TPU-95A - Copy"),
    "Inslogic TPU 95A - fast":        ("NinjaTek Cheetah TPU",     "Ultrafuse TPU-95A - Copy"),
}

KV = re.compile(r"^([a-z_0-9]+) = (.*)$")


def parse_ini(path):
    """Read a flat key = value preset, preserving leading comment lines."""
    out, comments = {}, []
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        if line.startswith("#"):
            comments.append(line)
            continue
        m = KV.match(line)
        if m:
            out[m.group(1)] = m.group(2)
    return out, comments


def vendor_blocks():
    txt = VENDOR.read_text(encoding="utf-8", errors="replace")
    return {
        m.group(1): m.group(2)
        for m in re.finditer(r"^\[filament:([^\]]+)\]\r?\n(.*?)(?=^\[|\Z)", txt, re.S | re.M)
    }


def resolve_chain(name, blocks, seen=None):
    """Fully resolve one vendor profile: parents first, child overrides last."""
    seen = seen or set()
    if name not in blocks or name in seen:
        return {}
    seen.add(name)
    body = blocks[name]
    own = {}
    for line in body.splitlines():
        m = KV.match(line)
        if m:
            own[m.group(1)] = m.group(2)
    merged = {}
    for parent in [p.strip() for p in own.get("inherits", "").split(";") if p.strip()]:
        merged.update(resolve_chain(parent, blocks, seen))
    merged.update(own)
    merged.pop("inherits", None)
    return merged


def main():
    blocks = vendor_blocks()
    for name, (parent, template) in JOBS.items():
        sparse_path = MASTERS / f"{name}.ini"
        if not sparse_path.exists():
            print(f"SKIP  {name}  (no master file)")
            continue

        overrides, comments = parse_ini(sparse_path)
        overrides.pop("inherits", None)

        base, _ = parse_ini(FILAMENT / f"{template}.ini")
        base.pop("inherits", None)
        base.pop("filament_settings_id", None)

        resolved = resolve_chain(parent, blocks)
        if not resolved:
            print(f"FAIL  {name}  <- parent '{parent}' not found in vendor bundle")
            continue

        final = {**base, **resolved, **overrides}
        final["inherits"] = parent
        final["filament_settings_id"] = ""

        # back up the sparse original once, then write the flattened version
        bak = sparse_path.with_suffix(".ini.sparse-bak")
        if not bak.exists():
            shutil.copy2(sparse_path, bak)

        lines = comments + [""] if comments else []
        lines += [f"{k} = {final[k]}" for k in sorted(final)]
        sparse_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

        gained = len(final) - len(overrides)
        la = "M900" in final.get("start_filament_gcode", "")
        print(f"OK    {name:<30} {len(overrides):>2} -> {len(final):>3} keys "
              f"(+{gained} from '{parent}')   LinearAdvance={'yes' if la else 'no'}")


if __name__ == "__main__":
    main()
