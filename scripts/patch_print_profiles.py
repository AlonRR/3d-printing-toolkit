"""Apply the house print-profile delta to PrusaSlicer print presets, minimally and verifiably.

usage: patch_print_profiles.py [--apply]     (default is a dry run)

WHY MINIMAL EDITS AND NOT A RE-DERIVE. The obvious approach - rebuild each preset from the vendor
bundle's resolved chain plus the delta - is actively harmful here. A user preset written by
PrusaSlicer 2.9 carries ~198 keys; the resolved vendor chain has ~119. PrusaSlicer does NOT resolve
`inherits` when loading a user preset, so any key absent from the file falls back to the SYSTEM
default rather than the parent's value (same trap scripts/flatten_profiles.py documents on the
filament side). Re-deriving would therefore silently reset ~79 settings. It is also unnecessary:
all seven 0.4 presets already carry the full house delta. So this edits only named keys and leaves
every other byte alone.

THE DELTA, and why each key is in it. Established by comparing the user presets against EACH OTHER
rather than against stock - they share a key set, so PrusaSlicer 2.9's additions cancel out and
only real differences remain. Comparing a single preset against the vendor bundle instead reports
~87 spurious "changes" that are just 2.9 keys the bundle predates.

  skirts = 0 / brim_type = no_brim / brim_width = 0   the profile names say exactly this
  avoid_crossing_perimeters = 1                       set on all seven 0.4 presets, none of the 0.8
  avoid_crossing_perimeters_max_detour = 20           NEW. Not previously set anywhere, and
      PrusaSlicer's own sidetext reads "mm or % (zero to disable)" - so the cap was disabled and
      detours were unbounded. 20 mm keeps the surface benefit without pathological travel.

DELIBERATELY NOT PROPAGATED:
  only_retract_when_crossing_perimeters   set to 1 only on the four 0.2 presets. It suppresses
      retraction except when a travel crosses a perimeter - but avoid_crossing_perimeters=1 exists
      to stop travels crossing perimeters. Together they largely disable retraction, which on PETG
      means oozing inside the part. Treated as a latent bug, not as intent to spread.
  ooze_prevention                         manages standby temperature for IDLE extruders; inert on
      a single-extruder MK3S. Circumstantial support: the vendor's *common* sets it 0 with
      standby_temperature_delta -5, while the only sections enabling it pair with -110, a park
      temperature that only makes sense for a second extruder. NOT verified in source - the
      PrusaSlicer PrintConfig.cpp fetch truncated before reaching the definition.

KNOWN COST, recorded because it argues against part of this. PrusaSlicer's tooltip for
avoid_crossing_perimeters: "mostly useful with Bowden extruders which suffer from oozing. This
feature slows down both the print and the G-code generation." The MK3S is DIRECT DRIVE, and none
of Prusa's 699 print sections enable it. Kept because it was chosen independently on seven presets
and PETG scarring is a real defect - but it is a deliberate deviation, not a default.
"""
import re
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path

PRINT_DIR = Path.home() / "AppData/Roaming/PrusaSlicer/print"

HOUSE = {
    "skirts": "0",
    "brim_type": "no_brim",
    "brim_width": "0",
    "avoid_crossing_perimeters": "1",
    "avoid_crossing_perimeters_max_detour": "20",
}

# skip = keys whose current value is a DELIBERATE exception and must survive untouched.
# extra = additional fixes agreed for that preset alone.
JOBS = {
    "0.10mm DETAIL @MK3 - No skirt no brim no perimeter": {},
    "0.15mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter": {},
    "0.20mm QUALITY @MK3 no skirt": {},
    "0.2mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter": {},
    "0.2mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter, lightning": {},
    "0.2mm QUALITY @MK3 - ULG, no skirt, no brim, no crossing perimeter": {},
    # This preset EXISTS to have a skirt, a brim and a draft shield - for ASA warping.
    # Applying the no-skirt/no-brim half of the delta would destroy its entire purpose.
    "0.2mm QUALITY @MK3 - ASA brim + draft shield": {"skip": ["skirts", "brim_type", "brim_width"]},
    # Its name says NO SKIRT only, and it never received the brim or crossing-perimeter half.
    "0.30mm DETAIL @0.8 nozzle - NO SKIRT": {},
    # complete_objects=1 is SEQUENTIAL printing: the gantry travels between finished parts and can
    # knock them over. Surprising on a general-purpose preset, and confirmed accidental.
    "0.40mm QUALITY @0.8 nozzle - NO Skirt": {"extra": {"complete_objects": "0", "wipe_tower": "1"}},
    # Keeps its brim: this preset is for large/strong parts where a brim is adhesion, not decoration.
    # Its fill_density 40%, external_perimeter_acceleration 400 and complete_objects 1 are its
    # character and are left alone - it was never the preset the brim question was asked about.
    "0.40mm Uber strong @0.8 nozzle": {"skip": ["brim_type", "brim_width"]},
}

KV = re.compile(r"^([a-z_0-9]+) = (.*)$")
apply = "--apply" in sys.argv

# A running PrusaSlicer rewrites its preset files on exit, silently reverting everything here.
try:
    running = subprocess.run(["tasklist"], capture_output=True, text=True, timeout=30).stdout
    assert "prusa-slicer" not in running.lower(), \
        "PrusaSlicer is RUNNING - close it first or it will overwrite these files on exit"
except FileNotFoundError:
    print("  (could not check for a running PrusaSlicer - close it before applying)")

missing = [n for n in JOBS if not (PRINT_DIR / f"{n}.ini").exists()]
assert not missing, f"preset file(s) not found: {missing}"

stamp = date.today().isoformat()
total_changed = 0
for name, rules in JOBS.items():
    path = PRINT_DIR / f"{name}.ini"
    # Detect and reproduce the file's OWN line endings. Presets written by PrusaSlicer are CRLF,
    # but a hand-edited one can be LF - and a default write_text() rewrites every line ending to
    # the platform default. That turned a one-key edit into a 199-line whole-file diff on the one
    # LF preset here, which is exactly the "nothing else changes" promise this script makes.
    raw = path.read_bytes()
    eol = "\r\n" if b"\r\n" in raw else "\n"
    original = raw.decode("utf-8")
    lines = original.replace("\r\n", "\n").split("\n")
    current = {m.group(1): m.group(2) for m in (KV.match(l) for l in lines) if m}

    wanted = {k: v for k, v in HOUSE.items() if k not in rules.get("skip", [])}
    wanted.update(rules.get("extra", {}))
    todo = {k: v for k, v in wanted.items() if current.get(k) != v}
    if not todo:
        print(f"\n{name}\n   already correct - untouched")
        continue

    out, seen = [], set()
    for line in lines:
        m = KV.match(line)
        if m and m.group(1) in todo:
            out.append(f"{m.group(1)} = {todo[m.group(1)]}")
            seen.add(m.group(1))
        else:
            out.append(line)
    # keys absent from the file are inserted in sorted position, as PrusaSlicer writes them
    for k in sorted(set(todo) - seen):
        pos = next((i for i, l in enumerate(out)
                    if (mm := KV.match(l)) and mm.group(1) > k), len(out))
        out.insert(pos, f"{k} = {todo[k]}")
    new = "\n".join(out)

    # ---- verify before writing anything -------------------------------------------------------
    after = {m.group(1): m.group(2) for m in (KV.match(l) for l in new.split("\n")) if m}
    for k, v in todo.items():
        assert after[k] == v, f"{name}: {k} did not take the value {v}"
    changed = {k for k in set(current) | set(after) if current.get(k) != after.get(k)}
    assert changed == set(todo), f"{name}: unexpected keys changed: {changed - set(todo)}"
    assert len(new.split("\n")) == len(lines) + len(set(todo) - seen), f"{name}: line count wrong"
    untouched_before = [l for l in lines if not ((m := KV.match(l)) and m.group(1) in todo)]
    untouched_after = [l for l in new.split("\n")
                       if not ((m := KV.match(l)) and m.group(1) in todo)]
    assert untouched_after == untouched_before + [] or \
        [l for l in untouched_after if l not in untouched_before] == \
        [f"{k} = {todo[k]}" for k in sorted(set(todo) - seen)], f"{name}: a non-target line moved"

    print(f"\n{name}")
    for k in sorted(todo):
        was = current.get(k, "<absent>")
        print(f"   {k:<42} {was:>12}  ->  {todo[k]}")
    total_changed += len(todo)

    if apply:
        bak = path.with_suffix(f".ini.bak-{stamp}")
        if not bak.exists():
            shutil.copy2(path, bak)
        path.write_text(new, encoding="utf-8", newline=eol)
        # Prove the ONLY byte-level difference is the intended keys - not just that the parsed
        # values agree. A whole-file line-ending rewrite passes a key-by-key check untouched.
        before = bak.read_bytes().decode("utf-8").replace("\r\n", "\n").split("\n")
        after = path.read_bytes().decode("utf-8").replace("\r\n", "\n").split("\n")
        moved = [(x, y) for x, y in zip(before, after) if x != y]
        assert all(KV.match(y) and KV.match(y).group(1) in todo for _, y in moved), \
            f"{name}: a non-target line changed: {moved[:3]}"
        assert bak.read_bytes().count(b"\r\n") == path.read_bytes().count(b"\r\n"), \
            f"{name}: line endings were rewritten"
        print(f"   written; backup {bak.name}")

print(f"\n{'APPLIED' if apply else 'DRY RUN'}: {total_changed} key changes across {len(JOBS)} presets")
if not apply:
    print("re-run with --apply to write them")
