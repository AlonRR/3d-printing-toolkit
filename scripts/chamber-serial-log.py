"""Log the ESP-NOW hub's serial output to CSV. Runs on the server, not here.

    python3 chamber-serial-log.py [--port /dev/ttyACM0] [--csv PATH] [--note TEXT]

The hub C3 is plugged into the server's USB and prints one line per update:

    [12:34:56][I][hub:062]: CHAMBER 24.3 36.7

This reads those and appends to CSV. It exists because the WiFi path could not
stay up: the access point refused the sensor node every 20-50 minutes, and the
poller lived inside an interactive session that dies with the terminal. A USB
cable is not something an access point can refuse, and the server is always on.

Deliberately dependency-light - pyserial only - so it can run under a systemd
unit on a small Linux host without dragging in a toolchain.

Prints sparingly for the same reason the WiFi logger did: a run lasts hours and
a line every 30 s is noise. On start, on a >= 2 C move, and hourly.

Optionally also publishes to MQTT, which is how the readings reach Home
Assistant. HA cannot talk to the hub directly - the hub is a SuperMini on the
end of a USB cable with no usable radio for transmitting (see the chamber-sensor
doc), so this process is the bridge. Pass --mqtt-host to enable it; without that
flag nothing about the original behaviour changes.

MQTT is added HERE, to the existing logger, rather than as a second script, for
one hard reason: only one process can own a serial port. Two readers on the same
tty each receive a fraction of the lines, with no error from either - a failure
mode this project has already paid for once.
"""
import argparse
import csv
import json
import re
import glob
import os
import sys
import time
from datetime import datetime
from pathlib import Path

import serial

# Matches the hub's log line. Anchored on the CHAMBER tag rather than the whole
# ESPHome log format, so a logger level or tag change does not break parsing.
LINE = re.compile(r"CHAMBER\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)")
MOVED_C = 2.0

# The hub enumerates under a by-id path because that path embeds its MAC, so it
# stays correct no matter what else is plugged in or in what order. Plain
# /dev/ttyACM0 is positional, and a second board appearing silently renames it -
# which would point this logger at the wrong device with no error at all.
#
# That MAC used to be hardcoded here. Two problems with that, and only one of
# them is about publication:
#
#   - it is a real device address, in a repo that is published, and
#   - it is WRONG for any other board. Replacing the hub meant editing the
#     script, which is not what a default is for.
#
# So resolve it instead: an explicit --port wins, then CHAMBER_HUB_PORT, then a
# glob over the by-id directory.
PORT_ENV = "CHAMBER_HUB_PORT"
PORT_GLOB = "/dev/serial/by-id/usb-Espressif_USB_JTAG_serial_debug_unit_*-if00"


def resolve_port(explicit):
    """Find the hub's serial device, or fail loudly saying what was actually seen.

    REFUSES TO GUESS when the glob is ambiguous, which is the entire point of
    using a by-id path. Taking matches[0] would silently reintroduce the bug the
    by-id path exists to prevent - logging a different board with no error - and
    would do it only sometimes, depending on USB enumeration order. An
    intermittent wrong answer is worse than a hard failure.
    """
    if explicit:
        return explicit
    env = os.environ.get(PORT_ENV)
    if env:
        return env

    matches = sorted(glob.glob(PORT_GLOB))
    if len(matches) == 1:
        return matches[0]

    where = Path("/dev/serial/by-id")
    seen = sorted(x.name for x in where.iterdir()) if where.is_dir() else []
    if not matches:
        raise SystemExit(
            "no Espressif JTAG device matched " + PORT_GLOB + "\n"
            "  /dev/serial/by-id contains: " + (", ".join(seen) or "(nothing, or no such directory)") + "\n"
            "  pass --port, or set " + PORT_ENV)
    raise SystemExit(
        str(len(matches)) + " Espressif JTAG devices matched - refusing to guess:\n"
        + "".join("    " + m + "\n" for m in matches)
        + "  pass --port, or set " + PORT_ENV + " to the one you want")

# Home Assistant creates the entities from these by itself, so there is no UI
# work to do on the HA side. Retained, so they survive an HA restart.
DISCOVERY = {
    "temp": {
        "name": "Chamber temperature",
        "device_class": "temperature",
        "unit_of_measurement": "\u00b0C",
        "value_template": "{{ value_json.temp_c }}",
        "unique_id": "chamber_temp",
    },
    "rh": {
        "name": "Chamber humidity",
        "device_class": "humidity",
        "unit_of_measurement": "%",
        "value_template": "{{ value_json.rh_pct }}",
        "unique_id": "chamber_rh",
    },
}


def mqtt_connect(a):
    """Return a connected client, or None if MQTT was not requested.

    Imported lazily so the logger keeps working on a machine without paho
    installed - the CSV half has no business failing because of an optional
    dependency.
    """
    if not a.mqtt_host:
        return None

    import paho.mqtt.client as mqtt

    password = Path(a.mqtt_pass_file).read_text(encoding="utf-8").strip()

    state_topic = f"{a.mqtt_prefix}/state"
    avail_topic = f"{a.mqtt_prefix}/availability"

    c = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="chamber-bridge")
    c.username_pw_set(a.mqtt_user, password)

    # The will is what makes this honest. If the bridge dies, or the server
    # reboots, or the USB cable is pulled, HA must show the sensor as
    # unavailable rather than holding the last temperature on screen forever.
    # A stale 45 C reading that looks live is worse than a gap.
    c.will_set(avail_topic, "offline", qos=1, retain=True)
    c.connect(a.mqtt_host, a.mqtt_port, keepalive=60)
    c.loop_start()

    device = {
        "identifiers": ["chamber_sensor"],
        "name": "Print chamber",
        "manufacturer": "Espressif",
        "model": "ESP32-C3-MINI-1 sender + SuperMini USB hub",
    }
    for key, cfg in DISCOVERY.items():
        payload = dict(cfg, state_topic=state_topic,
                       availability_topic=avail_topic, device=device)
        c.publish(f"homeassistant/sensor/chamber_{key}/config",
                  json.dumps(payload), qos=1, retain=True)

    c.publish(avail_topic, "online", qos=1, retain=True)
    print(f"mqtt -> {a.mqtt_host}:{a.mqtt_port} as {a.mqtt_user}, "
          f"topic {state_topic}", flush=True)
    return c


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default=None,
                    help="serial device; default resolves via $"
                         + PORT_ENV + " then a by-id glob")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--csv", default="/opt/chamber-logger/chamber.csv")
    ap.add_argument("--note", default="")
    ap.add_argument("--every", type=float, default=30.0,
                    help="minimum seconds between CSV rows")
    ap.add_argument("--heartbeat", type=float, default=3600.0,
                    help="seconds between routine prints; the CSV is unaffected")
    # Off by default, but when it is switched on the name to use is
    # mqtt.internal.example - the same one Home Assistant's own MQTT integration is
    # configured against, so the two cannot drift apart.
    ap.add_argument("--mqtt-host", default="",
                    help="enable MQTT publishing to this broker "
                         "(mqtt.internal.example); off if unset")
    ap.add_argument("--mqtt-port", type=int, default=1883)
    ap.add_argument("--mqtt-user", default="esp")
    # A path, never the password itself. An argument is visible in `ps` output
    # to every user on the box, and ends up in shell history and systemd unit
    # files. The file should be root-owned and mode 600.
    ap.add_argument("--mqtt-pass-file", default="/etc/chamber-logger/mqtt.pass")
    ap.add_argument("--mqtt-prefix", default="chamber")
    a = ap.parse_args()
    a.port = resolve_port(a.port)

    client = mqtt_connect(a)
    state_topic = f"{a.mqtt_prefix}/state"

    out = Path(a.csv)
    out.parent.mkdir(parents=True, exist_ok=True)
    fresh = not out.exists()
    fh = out.open("a", newline="", encoding="utf-8")
    w = csv.writer(fh)
    if fresh:
        w.writerow(["iso_time", "temp_c", "rh_pct", "note"])
        fh.flush()

    print(f"logging {a.port} -> {out}"
          + (f"   note={a.note!r}" if a.note else ""), flush=True)

    last_row = 0.0
    last_print = 0.0
    last_temp = None

    while True:
        try:
            # Opened inside the loop so unplugging the hub is survivable: the
            # read raises, we sleep, and reconnect when the device reappears.
            with serial.Serial(a.port, a.baud, timeout=10) as ser:
                while True:
                    raw = ser.readline()
                    if not raw:
                        continue
                    m = LINE.search(raw.decode("utf-8", "replace"))
                    if not m:
                        continue
                    temp, rh = float(m.group(1)), float(m.group(2))
                    now = time.time()
                    if now - last_row < a.every:
                        continue
                    stamp = datetime.now().isoformat(timespec="seconds")
                    w.writerow([stamp, temp, rh, a.note])
                    fh.flush()
                    last_row = now

                    if client is not None:
                        # Not retained: a retained reading would be replayed to
                        # HA on every reconnect and shown as current, which is
                        # exactly the stale-value problem the will exists to
                        # avoid.
                        client.publish(state_topic,
                                       json.dumps({"temp_c": temp,
                                                   "rh_pct": rh}), qos=0)

                    moved = last_temp is not None and abs(temp - last_temp) >= MOVED_C
                    if moved or now - last_print >= a.heartbeat or last_print == 0.0:
                        print(f"{stamp}  {temp:.1f} C  {rh:.0f} %RH"
                              + (f"   ({a.note})" if a.note else ""), flush=True)
                        last_print, last_temp = now, temp
        except (serial.SerialException, OSError) as e:
            stamp = datetime.now().isoformat(timespec="seconds")
            print(f"{stamp}  serial error ({type(e).__name__}) - retrying", flush=True)
            time.sleep(5)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("stopped", flush=True)
        sys.exit(0)
