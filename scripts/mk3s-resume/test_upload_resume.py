# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""upload_resume.py against a stub PrusaLink: it uploads a new name, and refuses plainly, sending nothing, when a file
of that name is already on the printer.

usage: uv run python scripts/mk3s-resume/test_upload_resume.py     (stdlib only; exit 0 = every case passed)
"""
import http.server
import json
import os
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

HERE = Path(__file__).resolve().parent
NAME = "plate.gcode"
BODY = b"G28\n" * 100


class Stub(http.server.BaseHTTPRequestHandler):
    listed, puts = False, []

    def log_message(self, *a):
        pass

    def send(self, code, obj=None):
        data = json.dumps(obj).encode() if obj is not None else b""
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        S = type(self)
        if self.path == "/api/v1/status":
            self.send(200, {"printer": {"state": "READY"}})
        elif self.path == "/api/v1/files/local/" + NAME:
            self.send(200, {"name": NAME, "size": len(BODY)}) if S.listed else self.send(404, {})
        else:
            self.send(404, {})

    def do_PUT(self):
        n = int(self.headers.get("Content-Length", 0))
        self.rfile.read(n)
        type(self).puts.append(self.path)
        # PrusaLink with Overwrite: ?0 refuses a name it already has
        self.send(409, {}) if type(self).listed else self.send(201, {})


def run(**kw):
    Stub.listed, Stub.puts = False, []
    for k, v in kw.items():
        setattr(Stub, k, v)
    srv = http.server.HTTPServer(("127.0.0.1", 0), Stub)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    with tempfile.TemporaryDirectory() as d:
        ini = Path(d) / "printer.ini"
        ini.write_text(f"print_host = 127.0.0.1:{srv.server_port}\nprinthost_apikey = test-key\n")
        g = Path(d) / NAME
        g.write_bytes(BODY)
        env = dict(os.environ, PRUSA_PRINTER_INI=str(ini))
        # -E -s, not -I: isolated from PYTHON* variables and the user's site, but -I's -P would also drop the
        # script's own folder from sys.path, where prusalink.py is.
        p = subprocess.run([sys.executable, "-E", "-s", str(HERE / "upload_resume.py"), str(g)],
                           env=env, capture_output=True, text=True, timeout=60, check=False)
    srv.shutdown()
    return p.returncode, len(Stub.puts), p.stdout + p.stderr


CASES = [   # name, stub settings, expected exit code, expected number of PUTs, text the output must hold
    ("a new name: uploaded", {}, 0, 1, "PUT 201"),
    ("the name already on the printer: refused, nothing sent", {"listed": True}, 1, 0, "already on the printer"),
]
failed = 0
for name, kw, want_rc, want_puts, want_text in CASES:
    rc, puts, out = run(**kw)
    ok = rc == want_rc and puts == want_puts and want_text in out
    failed += not ok
    print(f"{'ok  ' if ok else 'FAIL'}  {name:<56} exit {rc}, {puts} upload(s)  {out.strip().splitlines()[-1:]}")
print(f"{len(CASES) - failed} of {len(CASES)} cases passed")
sys.exit(1 if failed else 0)
