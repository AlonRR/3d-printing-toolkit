# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""The scripts' golden cases: every script under scripts/ run on fixed inputs, and what it did.

Each case runs one script as a user would, in a scratch folder of its own, and records what can be seen from
outside: the exit code, stdout, the last line of stderr (the message an assert or a refusal ends with - the lines
above it name files and line numbers, which a refactor moves), the requests a stub PrusaLink received, and each
output file's size and SHA-256. test_golden.py compares that with golden.json; make_golden.py writes golden.json.

TOOLKIT_ROOT names the tree whose scripts/ and slicer/ are run - the repository by default. Pointing it at an
older commit's files (git archive <sha> scripts slicer) is how golden.json is made from code known to be right,
and how a refactor is compared with the code before it.

Nothing here touches PrusaSlicer's own folders or a printer: flatten_profiles.py runs on a copy of the tree with
a home folder of fixtures, patch_print_profiles.py on presets written for the case, and the PrusaLink scripts
against a stub server on 127.0.0.1.
"""

import hashlib
import http.server
import json
import os
import re
import shutil
import subprocess
import sys
import threading
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
FIXTURES = HERE / "fixtures"
GOLDEN = HERE / "golden.json"


def toolkit_root():
    return Path(os.environ.get("TOOLKIT_ROOT", HERE.parent)).resolve()


@dataclass(frozen=True)
class Case:
    name: str
    script: str  # under scripts/, or under <tmp>/repo/scripts/ when copy_tree is set
    args: tuple = ()  # "{tmp}" is replaced by the scratch folder
    env: dict = field(default_factory=dict)
    setup: object = None  # setup(tmp) - writes the case's inputs
    outputs: tuple = ()  # glob patterns under tmp, recorded by size and hash
    copy_tree: bool = False  # run a copy of scripts/ from <tmp>/repo, for a script that writes beside itself
    stub: object = None  # a PrusaLink stub: stub() -> (handler class, request log)
    normalise: object = None  # normalise(text) for stdout, beyond the scratch folder's path
    jsonl_drop: tuple = ()  # keys removed from each JSON line of a .jsonl output before hashing
    request_set: bool = False  # record the distinct requests only, for a case whose count follows the clock


# ---------------------------------------------------------------- running a case


def _digest(path, drop):
    data = path.read_bytes()
    if drop and path.suffix == ".jsonl":
        rows = [json.loads(line) for line in data.decode("utf-8").splitlines()]
        rows = sorted({json.dumps({k: v for k, v in r.items() if k not in drop}, sort_keys=True) for r in rows})
        data = "\n".join(rows).encode("utf-8")
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def _plain(text, tmp):
    for t in {str(tmp), str(tmp).replace("\\", "/")}:
        text = text.replace(t, "<tmp>")
    return text.replace("\\", "/").replace("\r\n", "\n")


def run_case(case, tmp):
    """Run one case in the empty folder tmp; return what it did, as plain data."""
    root = toolkit_root()
    tmp = Path(tmp)
    if case.copy_tree:
        shutil.copytree(root / "scripts", tmp / "repo" / "scripts", ignore=shutil.ignore_patterns("__pycache__"))
        script = tmp / "repo" / "scripts" / case.script
    else:
        script = root / "scripts" / case.script
    if case.setup:
        case.setup(tmp)
    env = {k: v for k, v in os.environ.items() if k not in ("PRUSA_PRINTER_INI", "RESUME_TOUCH_XY")}
    env.update(PYTHONIOENCODING="utf-8", PYTHONDONTWRITEBYTECODE="1")
    env.update({k: v.replace("{tmp}", str(tmp)) for k, v in case.env.items()})
    srv = log = None
    if case.stub:
        handler, log = case.stub()
        srv = http.server.HTTPServer(("127.0.0.1", 0), handler)
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        ini = tmp / "printer.ini"
        ini.write_text(f"print_host = 127.0.0.1:{srv.server_port}\nprinthost_apikey = test-key\n", encoding="utf-8")
        env["PRUSA_PRINTER_INI"] = str(ini)
    try:
        p = subprocess.run(
            [sys.executable, str(script), *(a.replace("{tmp}", str(tmp)) for a in case.args)],
            cwd=tmp,
            env=env,
            capture_output=True,
            encoding="utf-8",
            errors="replace",
            timeout=300,
            check=False,
        )
    finally:
        if srv:
            srv.shutdown()
            srv.server_close()
    stdout = _plain(p.stdout, tmp)
    if case.normalise:
        stdout = case.normalise(stdout)
    err = [line for line in _plain(p.stderr, tmp).splitlines() if line.strip()]
    files = {}
    for pattern in case.outputs:
        for f in sorted(tmp.glob(pattern)):
            if f.is_file():
                key = re.sub(r"\d{4}-\d{2}-\d{2}", "DATE", f.relative_to(tmp).as_posix())
                files[key] = _digest(f, case.jsonl_drop)
    return {
        "exit": p.returncode,
        "stdout": stdout,
        "stderr_last": err[-1] if err else "",
        "requests": None if log is None else sorted(set(log)) if case.request_set else list(log),
        "files": files,
    }


# ---------------------------------------------------------------- inputs


def _copy(*names):
    def setup(tmp):
        for n in names:
            shutil.copy2(FIXTURES / n, tmp / Path(n).name)

    return setup


def _flatten_tree(tmp):
    """A copy of the repository's layout for flatten_profiles.py, and a home folder holding PrusaSlicer's."""
    masters = tmp / "repo" / "slicer" / "filament" / "inslogic"
    masters.mkdir(parents=True)
    for f in (FIXTURES / "masters").iterdir():
        shutil.copy2(f, masters / f.name)
    shutil.copytree(FIXTURES / "prusaslicer", tmp / "home" / "AppData" / "Roaming" / "PrusaSlicer")


def _flatten_twice(tmp):
    """The PLA job run once already: its backup exists, so a second run must not replace it."""
    _flatten_tree(tmp)
    master = tmp / "repo" / "slicer" / "filament" / "inslogic" / "Inslogic PLA Pro.ini"
    shutil.copy2(master, master.with_suffix(".ini.sparse-bak"))
    master.write_text("inherits = Generic PLA\ntemperature = 207\n", encoding="utf-8")


PRESETS = (
    "0.10mm DETAIL @MK3 - No skirt no brim no perimeter",
    "0.15mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter",
    "0.20mm QUALITY @MK3 no skirt",
    "0.2mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter",
    "0.2mm QUALITY @MK3 - no skirt, no brim, no crossing perimeter, lightning",
    "0.2mm QUALITY @MK3 - ULG, no skirt, no brim, no crossing perimeter",
    "0.30mm DETAIL @0.8 nozzle - NO SKIRT",
    "0.40mm QUALITY @0.8 nozzle - NO Skirt",
    "0.40mm Uber strong @0.8 nozzle",
)
HOUSE = {
    "avoid_crossing_perimeters": "1",
    "avoid_crossing_perimeters_max_detour": "20",
    "brim_type": "no_brim",
    "brim_width": "0",
    "draft_shield": "disabled",
    "fill_pattern": "cubic",
    "skirts": "0",
}


def _presets(tmp, missing=False):
    """The nine presets patch_print_profiles.py knows, small, each needing something different: a key wrong, a key
    absent, LF where PrusaSlicer writes CRLF, the lightning preset's own infill, and one already right."""
    d = tmp / "print"
    d.mkdir()
    for i, name in enumerate(PRESETS):
        keys = dict(HOUSE, complete_objects="0", layer_height="0.2", wipe_tower="1")
        if i == 0:
            del keys["avoid_crossing_perimeters_max_detour"]
        if i == 1:
            keys.update(fill_pattern="gyroid", skirts="1")
        if i == 2:
            keys.update(brim_type="outer_only", brim_width="5", draft_shield="enabled")
        if i == 4:
            keys["fill_pattern"] = "lightning"
        if i == 7:
            keys.update(complete_objects="1", wipe_tower="0")
        if i == 8:
            del keys["draft_shield"]
        eol = "\n" if i in (1, 5) else "\r\n"
        text = eol.join(["# generated by PrusaSlicer 2.9.6", *(f"{k} = {v}" for k, v in sorted(keys.items()))])
        if i != 6 or not missing:
            (d / f"{name}.ini").write_bytes((text + eol).encode("utf-8"))


# ---------------------------------------------------------------- stub PrusaLink


def _stub(respond):
    """A PrusaLink stand-in: respond(method, path, state) -> (code, json or None, headers). Every request is logged
    with the headers that make it safe: the API key, and an upload's Print-After-Upload and Overwrite."""
    log = []
    state = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def _answer(self, method):
            n = int(self.headers.get("Content-Length") or 0)
            if n:
                self.rfile.read(n)
            sent = [
                f"{h}={self.headers[h]}"
                for h in ("X-Api-Key", "Print-After-Upload", "Overwrite")
                if self.headers.get(h) is not None
            ]
            log.append(" ".join([method, self.path, *([f"{n} bytes"] if n else []), *sent]))
            code, obj, headers = respond(method, self.path, state)
            data = json.dumps(obj).encode() if obj is not None else b""
            self.send_response(code)
            for k, v in (headers or {}).items():
                self.send_header(k, v)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            self._answer("GET")

        def do_POST(self):
            self._answer("POST")

        def do_PUT(self):
            self._answer("PUT")

    return Handler, log


PLATE = "plate.gcode"
PLATE_BODY = b"G28\n" * 100
PLATE_SIZE = len(PLATE_BODY)


def _plate(tmp):
    (tmp / PLATE).write_bytes(PLATE_BODY)


def _printer(state="IDLE", size=PLATE_SIZE, listed=True, job_name=PLATE):
    """start_print.py's printer: started by a POST, after which the job reads PRINTING."""

    def respond(method, path, s):
        if method == "POST":
            s["started"] = True
            return 204, None, None
        if path == "/api/v1/status":
            return 200, {"printer": {"state": "PRINTING" if s.get("started") else state}}, None
        if path == "/api/v1/files/local/" + PLATE:
            return (200, {"name": PLATE, "size": size}, None) if listed else (404, {}, None)
        if path == "/api/v1/job":
            if s.get("started"):
                return 200, {"state": "PRINTING", "file": {"name": job_name}, "time_remaining": 60}, None
            return 204, None, None
        return 404, {}, None

    return lambda: _stub(respond)


def _uploader(listed=False, put=201, redirect=False):
    """upload_resume.py's printer: a PUT answered with `put`, or first redirected elsewhere on the same server."""

    def respond(method, path, s):
        if method == "PUT":
            if redirect and not path.startswith("/moved"):
                return 308, {}, {"Location": "/moved" + path}
            return put, ({} if put != 500 else {"error": "disk full"}), None
        if path == "/api/v1/status":
            return 200, {"printer": {"state": "READY"}}, None
        if path == "/api/v1/files/local/" + PLATE:
            return (200, {"name": PLATE, "size": len(PLATE_BODY)}, None) if listed else (404, {}, None)
        return 404, {}, None

    return lambda: _stub(respond)


def _monitor(states, fail=False):
    """print_monitor.py's printer: each status request takes the next of `states` (the last repeats); a state None
    is PrusaLink's reduced object while its daemon restarts - no temperatures."""

    def respond(method, path, s):
        if fail:
            return 500, {}, None
        if path == "/api/v1/status":
            i = s.get("i", 0)
            s["i"] = i + 1
            st = states[min(i, len(states) - 1)]
            if st is None:
                return 200, {"printer": {"state": "PRINTING"}}, None
            name, bed = st
            return (
                200,
                {
                    "printer": {
                        "state": name,
                        "axis_z": 1.8,
                        "temp_bed": bed,
                        "target_bed": 100,
                        "temp_nozzle": 249.6,
                        "target_nozzle": 250,
                    }
                },
                None,
            )
        if path == "/api/v1/job":
            return 200, {"progress": 42, "time_remaining": 600, "file": {"display_name": "part.gcode"}}, None
        return 404, {}, None

    return lambda: _stub(respond)


def _clock(text):
    return re.sub(r"^\d\d:\d\d:\d\d ", "HH:MM:SS ", text, flags=re.M)


# ---------------------------------------------------------------- the cases

RESUME = ("box.gcode", "1.6", "1.6", "-1.2", "5", "resume.gcode")
CASES = [
    # ---- bed-anneal-gcode.py
    Case("anneal-defaults", "bed-anneal-gcode.py", outputs=("*.gcode",)),
    Case(
        "anneal-custom",
        "bed-anneal-gcode.py",
        (
            "--hold",
            "80",
            "--hours",
            "0.5",
            "--ramp-step",
            "15",
            "--cool-step",
            "10",
            "--cool-to",
            "50",
            "-o",
            "a.gcode",
        ),
        outputs=("*.gcode",),
    ),
    Case("anneal-hold-too-hot", "bed-anneal-gcode.py", ("--hold", "130"), outputs=("*.gcode",)),
    # LCD text past the display's 20 characters: "Hold 100.5C 280m left" is cut
    Case("anneal-long-labels", "bed-anneal-gcode.py", ("--hold", "100.5", "--hours", "2.5"), outputs=("*.gcode",)),
    # ---- make_live_z_tags.py
    Case("tags-defaults", "make_live_z_tags.py", ("tags.gcode",), outputs=("*.gcode",)),
    Case(
        "tags-0.4-fixture-profile",
        "make_live_z_tags.py",
        ("tags.gcode", "0.4", "0.2", "0.45", "0.25", "0.025", "9", "filament.ini"),
        setup=_copy("filament.ini"),
        outputs=("*.gcode",),
    ),
    Case(
        "tags-start-below-nominal",
        "make_live_z_tags.py",
        ("tags.gcode", "0.4", "0.3", "0.45", "0.25", "0.05", "9", "filament.ini"),
        setup=_copy("filament.ini"),
        outputs=("*.gcode",),
    ),
    # ---- retarget_filament_temps.py
    Case(
        "retarget",
        "retarget_filament_temps.py",
        ("filament.ini", "out", "box.gcode"),
        setup=_copy("filament.ini", "box.gcode"),
        outputs=("out/*",),
    ),
    Case(
        "retarget-no-header",
        "retarget_filament_temps.py",
        ("--no-header", "filament.ini", "out", "box.gcode"),
        setup=_copy("filament.ini", "box.gcode"),
        outputs=("out/*",),
    ),
    Case(
        "retarget-unknown-flag",
        "retarget_filament_temps.py",
        ("--nohead", "filament.ini", "out", "box.gcode"),
        setup=_copy("filament.ini", "box.gcode"),
        outputs=("out/*",),
    ),
    # ---- flatten_profiles.py
    Case(
        "flatten-all",
        "flatten_profiles.py",
        copy_tree=True,
        setup=_flatten_tree,
        env={"USERPROFILE": "{tmp}/home", "HOME": "{tmp}/home"},
        outputs=("repo/slicer/filament/**/*",),
    ),
    Case(
        "flatten-one-twice",
        "flatten_profiles.py",
        ("Inslogic PLA Pro",),
        copy_tree=True,
        setup=_flatten_twice,
        env={"USERPROFILE": "{tmp}/home", "HOME": "{tmp}/home"},
        outputs=("repo/slicer/filament/**/*",),
    ),
    Case(
        "flatten-unknown",
        "flatten_profiles.py",
        ("Inslogic PLA",),
        copy_tree=True,
        setup=_flatten_tree,
        env={"USERPROFILE": "{tmp}/home", "HOME": "{tmp}/home"},
        outputs=("repo/slicer/filament/**/*",),
    ),
    # ---- patch_print_profiles.py
    Case("patch-dry-run", "patch_print_profiles.py", ("--dir=print",), setup=_presets, outputs=("print/*",)),
    Case("patch-apply", "patch_print_profiles.py", ("--dir=print", "--apply"), setup=_presets, outputs=("print/*",)),
    Case(
        "patch-missing-preset",
        "patch_print_profiles.py",
        ("--dir=print",),
        setup=lambda tmp: _presets(tmp, missing=True),
        outputs=("print/*",),
    ),
    Case("patch-no-such-dir", "patch_print_profiles.py", ("--dir=nowhere",)),
    # ---- add_brim_ears.py
    Case("ears-defaults", "add_brim_ears.py", ("ell.stl",), setup=_copy("ell.stl"), outputs=("*.stl",)),
    Case(
        "ears-edge-tabs",
        "add_brim_ears.py",
        ("ell.stl", "--edge-tabs", "12", "--diameter", "8", "-o", "o.stl"),
        setup=_copy("ell.stl"),
        outputs=("*.stl",),
    ),
    Case(
        "ears-dry-run",
        "add_brim_ears.py",
        ("ell.stl", "--dry-run", "--min-weld", "60"),
        setup=_copy("ell.stl"),
        outputs=("*.stl",),
    ),
    Case("ears-not-binary", "add_brim_ears.py", ("box.stl",), setup=_copy("box.stl"), outputs=("*-ears.stl",)),
    # An ear that only fits once its overlap has stepped down - to 2.00 from 3.75, in quarters
    Case(
        "ears-shrunk",
        "add_brim_ears.py",
        ("ell.stl", "--clearance", "6", "--overlap", "3.75"),
        setup=_copy("ell.stl"),
        outputs=("*.stl",),
    ),
    # Tabs close enough to merge: the better-welded of two keeps its place, and replaces the other
    Case(
        "ears-replaced",
        "add_brim_ears.py",
        ("ell.stl", "--edge-tabs", "5", "-o", "o.stl"),
        setup=_copy("ell.stl"),
        outputs=("*.stl",),
    ),
    # ---- mk3s-resume/make_find_top.py
    Case("find-top", "mk3s-resume/make_find_top.py", ("40", "60", "21.47", "find-top.gcode"), outputs=("*.gcode",)),
    Case(
        "find-top-too-few-steps",
        "mk3s-resume/make_find_top.py",
        ("4", "60", "21.47", "find-top.gcode"),
        outputs=("*.gcode",),
    ),
    # ---- mk3s-resume/make_resume.py
    Case(
        "resume",
        "mk3s-resume/make_resume.py",
        RESUME,
        env={"RESUME_TOUCH_XY": "50,20.2"},
        setup=_copy("box.gcode"),
        outputs=("resume.gcode",),
    ),
    Case(
        "resume-top-above-wall",
        "mk3s-resume/make_resume.py",
        ("box.gcode", "1.4", "1.6", "-1.2", "5", "resume.gcode"),
        env={"RESUME_TOUCH_XY": "50,20.2"},
        setup=_copy("box.gcode"),
        outputs=("resume.gcode",),
    ),
    Case(
        "resume-touch-off-the-part",
        "mk3s-resume/make_resume.py",
        RESUME,
        env={"RESUME_TOUCH_XY": "90,90"},
        setup=_copy("box.gcode"),
        outputs=("resume.gcode",),
    ),
    Case(
        "resume-gap-too-small",
        "mk3s-resume/make_resume.py",
        ("box.gcode", "1.6", "1.6", "-1.2", "0.5", "resume.gcode"),
        setup=_copy("box.gcode"),
        outputs=("resume.gcode",),
    ),
    # ---- mk3s-resume/probe_touch.py
    Case("probe", "mk3s-resume/probe_touch.py", ("box.gcode", "1.6"), setup=_copy("box.gcode")),
    Case("probe-first-layers", "mk3s-resume/probe_touch.py", ("box.gcode", "0.4"), setup=_copy("box.gcode")),
    # ---- mk3s-resume/start_print.py
    *(
        Case(
            f"start-{n}",
            "mk3s-resume/start_print.py",
            (PLATE,),
            env={"START_PRINT_POLL": "0.05"},
            setup=_plate,
            stub=_printer(**kw),
        )
        for n, kw in [
            ("idle", {}),
            ("finished", {"state": "FINISHED"}),
            ("printing", {"state": "PRINTING"}),
            ("paused", {"state": "PAUSED"}),
            ("other-size", {"size": len(PLATE_BODY) - 1}),
            ("not-listed", {"listed": False}),
            ("other-job", {"job_name": "other.gcode"}),
        ]
    ),
    # ---- mk3s-resume/upload_resume.py
    *(
        Case(f"upload-{n}", "mk3s-resume/upload_resume.py", (PLATE,), setup=_plate, stub=_uploader(**kw))
        for n, kw in [
            ("new", {}),
            ("listed", {"listed": True}),
            ("redirect", {"redirect": True}),
            ("refused", {"put": 500}),
        ]
    ),
    # ---- mk3s-resume/print_monitor.py
    Case(
        "monitor-finishes",
        "mk3s-resume/print_monitor.py",
        ("log", "60", "0.01"),
        stub=_monitor([("PRINTING", 100.1), None, ("PRINTING", 93.5), ("PRINTING", 99.8), ("FINISHED", 60.2)]),
        outputs=("log/*",),
        normalise=_clock,
        jsonl_drop=("t",),
    ),
    Case(
        "monitor-window-over",
        "mk3s-resume/print_monitor.py",
        ("log", "0.3", "0.05"),
        stub=_monitor([("PRINTING", 99.9)]),
        outputs=("log/*",),
        normalise=_clock,
        jsonl_drop=("t",),
        request_set=True,
    ),
    Case(
        "monitor-unreachable",
        "mk3s-resume/print_monitor.py",
        ("log", "60", "0.01"),
        stub=_monitor([], fail=True),
        outputs=("log/*",),
        normalise=_clock,
        jsonl_drop=("t",),
    ),
]
