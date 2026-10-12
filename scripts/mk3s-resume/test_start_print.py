# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

"""start_print.py against a stub PrusaLink: it starts only when it should, and sends nothing otherwise.

usage: uv run python scripts/mk3s-resume/test_start_print.py     (stdlib only; exit 0 = every case passed)
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
BODY = b"G28\n" * 100                      # the local file: 400 bytes


class Stub(http.server.BaseHTTPRequestHandler):
    state, size, listed, posts, job_name = "IDLE", len(BODY), True, [], NAME

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
            self.send(200, {"printer": {"state": S.state}})
        elif self.path == "/api/v1/files/local/" + NAME:
            self.send(200, {"name": NAME, "size": S.size}) if S.listed else self.send(404, {})
        elif self.path == "/api/v1/job":
            if S.posts:
                self.send(200, {"state": "PRINTING", "file": {"name": S.job_name}, "time_remaining": 60})
            else:
                self.send(204)
        else:
            self.send(404, {})

    def do_POST(self):
        type(self).posts.append(self.path)
        type(self).state = "PRINTING"
        self.send(204)


def run(case, **kw):
    Stub.state, Stub.size, Stub.listed, Stub.posts, Stub.job_name = "IDLE", len(BODY), True, [], NAME
    for k, v in kw.items():
        setattr(Stub, k, v)
    srv = http.server.HTTPServer(("127.0.0.1", 0), Stub)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    with tempfile.TemporaryDirectory() as d:
        ini = Path(d) / "printer.ini"
        ini.write_text(f"print_host = 127.0.0.1:{srv.server_port}\nprinthost_apikey = test-key\n")
        g = Path(d) / NAME
        g.write_bytes(BODY)
        env = dict(os.environ, PRUSA_PRINTER_INI=str(ini), START_PRINT_POLL="0.05")
        # -E -s, not -I: isolated from PYTHON* variables and the user's site, but -I's -P would also drop the
        # script's own folder from sys.path, where prusalink.py is.
        p = subprocess.run([sys.executable, "-E", "-s", str(HERE / "start_print.py"), str(g)],
                           env=env, capture_output=True, text=True, timeout=60, check=False)
    srv.shutdown()
    return p.returncode, len(Stub.posts), (p.stdout + p.stderr).strip().splitlines()[-1:]


CASES = [   # name, stub settings, expected exit code, expected number of POSTs
    ("idle, same size: starts", {}, 0, 1),
    ("finished, same size: starts", {"state": "FINISHED"}, 0, 1),
    ("already printing: refused", {"state": "PRINTING"}, 1, 0),
    ("paused: refused", {"state": "PAUSED"}, 1, 0),
    ("printer's copy a different size: refused", {"size": len(BODY) - 1}, 1, 0),
    ("not on the printer: refused", {"listed": False}, 1, 0),
    ("started, but the job is another file: fails", {"job_name": "other.gcode"}, 1, 1),
]
failed = 0
for name, kw, want_rc, want_posts in CASES:
    rc, posts, last = run(name, **kw)
    ok = rc == want_rc and posts == want_posts
    failed += not ok
    print(f"{'ok  ' if ok else 'FAIL'}  {name:<46} exit {rc}, {posts} start(s)  {last}")
print(f"{len(CASES) - failed} of {len(CASES)} cases passed")
sys.exit(1 if failed else 0)
