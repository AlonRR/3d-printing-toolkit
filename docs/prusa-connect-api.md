# Prusa Connect — what can be automated, and what cannot

*Investigated 1 Sep 2026. Every claim below was checked against a live endpoint or a fetched
spec, not read off a forum post.*

Connect is where files actually get sent from here: it has the **queue**, and it shows **progress
on a phone**. So the question is what of that is reachable by API.

**Short answer:** you can read and manage the queue, start prints, and read progress. You
**cannot upload a file** — no endpoint exists for it, in any Prusa API. Uploading stays with
PrusaSlicer or the Connect web UI.

---

## 1. There are two Connect APIs, and only one is officially supported

| API | Status | Base | Use |
|---|---|---|---|
| **Camera API** | ✅ Officially supported and documented | `connect.prusa3d.com/docs/cameras/openapi/` | Publish snapshots from a third-party camera |
| **Mobile gateway** | ⚠️ Real and tagged *Public Endpoints*, but it is the phone app's backend, version `0.0.1-dev` | `connect-mobile-api.prusa3d.com` | Queue, jobs, progress, commands |

There is **no** general Connect API equivalent to PrusaLink's. PrusaLink has a proper published
OpenAPI spec; Connect does not.

---

## 2. The mobile gateway — 43 endpoints, and the one that is missing

Fetched from `https://connect-mobile-api.prusa3d.com/api/docs`, which serves the raw OpenAPI 3.1.0
JSON directly. The useful subset:

**Queue**
```
GET    /api/v1/printers/{printerUuid}/queue            planned jobs
DELETE /api/v1/printers/{printerUuid}/queue/{jobId}    remove one
```

**Start a print — this is how something reaches the queue**
```
PUT /api/v1/printers/{printerUuid}/command/start/cloud       from Connect cloud storage
PUT /api/v1/printers/{printerUuid}/command/start/files       from files already on the printer
PUT /api/v1/printers/{printerUuid}/command/start/printables   from a Printables URL
```
`start/cloud` takes `{hash, teamId, printNow, waitUntil}`. **`printNow: false` is the queue** —
that is queue-for-later rather than print-immediately, and `waitUntil` schedules it.

**Progress and control**
```
GET /api/v1/jobs            /api/v1/jobs/{id}         progress, state, estimatedPrintTime
GET /api/v1/printers        /api/v1/printers/{uuid}/detail
PUT .../command/{pause|resume|stop|ready|unready|control|dialog}
GET /api/v1/storage/{teamId}    /api/v1/storage/printer/{printerUuid}
```

Plus cameras, teams, notifications and user endpoints.

### ⛔ There is no upload endpoint

All 43 paths were enumerated and filtered for `upload`, `file`, `gcode`. The only matches are
`command/start/files` (which *selects* an already-present file) and the two queue paths. **Nothing
accepts a G-code body.**

So the workflow is unavoidably two-stage: **PrusaSlicer or the web UI puts the file into Connect
storage; the API can then queue and start it** by `hash`.

### Verification method

`401` versus `404` distinguishes a real endpoint from a wrong guess, since unauthenticated
requests to a real path are rejected rather than not-found:

```
/api/v1/printers/{uuid}/queue   -> 401   exists
/api/v1/printers                -> 401   exists
/api/v1/nonexistent-path-xyz    -> 404   does not
```

### ⚠️ The practical blocker: authentication

Auth is a **JWT in the `Authorization` header** (`client_jwt_token`). There is **no documented way
to mint one outside the phone app** — no API-key path, no OAuth client flow published. Using this
API means presenting yourself as the mobile app, against a `0.0.1-dev` gateway that can change
without notice or warning. Fine for a personal script that you are willing to repair; not
something to build a dependency on.

---

## 3. Uploading: what actually works

PrusaSlicer, and the key is **not** the PrusaLink one.

**Connect issues a different key from PrusaLink, and mixing them is the classic `401`.** The
`X-Api-Key` header that works against PrusaLink is not what Connect's endpoints use at all —
verified here: sending the stored Connect key as `X-Api-Key` to `connect.prusa3d.com` returns
exactly the same `401` as sending nothing.

### ⚠️ There are THREE key classes, not two — corrected 17 Sep 2026

The paragraph above says "two keys", and that was the shape of the problem it was written about
(PrusaSlicer uploading). **It is incomplete, and the omission has already cost someone a
diagnosis**: a session chasing a Connect `401` on the print host read it, reasonably, and went
looking in the wrong slot. Read from source — Prusa-Link `config.py` and
Prusa-Connect-SDK-Printer `__init__.py` — rather than recalled:

| | Where it lives | How it travels | Who issues it |
|---|---|---|---|
| **1. PrusaLink local API key** | `[service::local]` → `api_key` | `X-Api-Key:` to the Pi | PrusaLink, shown in its own Settings |
| **2. PrusaConnect user API key** | PrusaSlicer's physical-printer entry | Connect's own auth, **account**-scoped | Connect web UI → Settings → API keys |
| **3. PrusaLink→Connect printer token** | `[service::connect]` → `token` | `Token:` **+ `Fingerprint:`** to `connect.prusa3d.com` | **Connect, by handshake — never pasted** |

Class 3 is the one this page previously did not mention. Alongside `token`, that section holds
only `hostname` (default `connect.prusa3d.com`), `tls` and `port`. There is **no `printer_uuid` or
`fingerprint` in the config** — the fingerprint is computed and sent as a header, not stored.

⭐ **`use_connect()` is literally `bool(token)`.** A non-empty token is the only thing that turns
Connect on, which has a consequence worth stating outright: **with the token cleared, a zero
`UNAUTHORIZED` count means zero *attempts*, not zero rejections.** A counter reading zero because
the feature is switched off is not the feature working — and it is an easy thing to mistake for a
fix.

### The handshake never accepts a pasted key

`register()` POSTs to `/p/register`; Connect replies with a **`Code`** header; the SDK re-queues
that `Register` item and polls — `202` means not ready, one-second sleep — until Connect answers
`200` with a **`Token`** header, and *that* is what lands in the slot.

Two consequences:

- **Re-registering cannot introduce a wrong-class token**, because the slot is written from
  Connect's response. A wrong-class value can only arrive by hand-editing the ini or restoring one
  that was — so a restored backup is the vector to suspect, not the registration.
- A stale `401` has two causes that look identical and share one fix: a wrong-class value, or a
  **genuine token Connect has since invalidated** (printer re-added or rotated on Connect's side).
  Comparing `[service::connect] token` against `[service::local] api_key` in the backup tells the
  two apart for the record; it does not change what you do about it.

⛔ **No string-format discriminator is given here on purpose.** The source does not state one and a
recalled "keys of this class look like…" would be a guess presented as a fact. The three axes above
— header, ini section, provenance — are what the source actually supports.

- **Get it from:** Connect web UI → **Settings** → scroll to **API keys**.
- **Physical Printer dialog:** host type `PrusaConnect`, hostname `https://connect.prusa3d.com`,
  authorization type **API Key** (not Digest — Connect does not support Digest through
  PrusaSlicer), key = the **PrusaConnect** key.
- ⚠️ Reported repeatedly since 2024: PrusaLink and PrusaConnect entries **share settings** in
  PrusaSlicer, so a Digest auth-type set on the Link entry can leak into the Connect one and
  produce a `401` that looks like a bad key.

**This path is now "legacy".** PrusaSlicer 2.9.6 (installed here — `connect_polling = 1` is set in
`PrusaSlicer.ini`) has a dedicated **PrusaConnect integration** that logs in with a Prusa account
rather than a pasted key, and Prusa describes it as the fuller feature set. Prefer it.

---

## 4. The camera API is the one supported route — and the hardware is already owned

Three endpoints, auth by `Token` + `Fingerprint` headers, the token issued by Connect:

```
POST /c/snapshot                              publish an image
GET  /c/info
GET  /app/printers/{printer_uuid}/camera
```

This is the only API Prusa officially supports for Connect, and it is a direct match for the
**ESP32-S3 N16R8 CAM with the OV3660** already in the parts inventory. That would put a live view
of the printer next to the progress readout on the phone, through a supported interface rather
than a `0.0.1-dev` one. See [chamber-sensor §3w](chamber-sensor/boards.md#the-arduino-nano-esp32-as-the-bench-reference-3w) for why an S3 is the board to
build a network device on, and §3z for why the C3 SuperMinis are not.

---

## 4a. The camera build — both halves already exist

Investigated 1 Sep 2026 after identifying the board on the bench. **Nothing here needs to be
written or designed**, which was not the expected answer.

### The board

**ESP32-S3-WROOM-1, dual USB-C, camera FPC connector**, shipped with an **OV3660** — the
`ESP32-S3 N16R8 CAM` from the parts inventory. Layout matches the **Freenove ESP32-S3-WROOM CAM**.

⚠️ **Two USB-C ports, and they are not interchangeable** — the same trap as the C3-MINI-1 in
[chamber-sensor §3y](chamber-sensor/boards.md#the-pairing-that-works-3y). One is native USB, one is a **CH343 UART bridge**. Plugged
into the UART side it enumerates as `USB-Enhanced-SERIAL CH343`, which is how to tell which port
you are on without guessing. For ESPHome on the UART port, **do not** set
`hardware_uart: USB_SERIAL_JTAG` — that sends the console out the *other* connector, and a healthy
board then looks dead.

### The firmware — official, and this board is on the list

**[prusa3d/Prusa-Firmware-ESP32-Cam](https://github.com/prusa3d/Prusa-Firmware-ESP32-Cam)** —
Prusa's own firmware, GPL-3.0, with pre-compiled releases per board. Supported boards include
**Freenove ESP32-S3-Wroom** and **ESP32-S3-CAM**.

**Is it really Prusa? Yes — with one caveat stated precisely.** The `prusa3d` GitHub org is **not
domain-verified** (`is_verified: false` from the API). That badge is optional and its absence is
not evidence of anything; what settles it is what the org contains — **PrusaSlicer** (9.3k stars),
**Prusa-Firmware** (2.1k), **Prusa-Firmware-Buddy** (1.6k), **Original-Prusa-i3** (1.7k). Those are
the canonical Prusa codebases. Org created 2015, `info@prusa3d.com`, `prusa3d.com`. The repo is not
a fork.

⚠️ **It is NOT actively maintained, and an earlier version of this page wrongly said it was.**
Last push **2 Jan 2025**, with **63 open issues**. That claim came from a search summary reporting
"168 commits, recent activity"; the API says otherwise. It works, but treat it as parked — nobody
is fixing a board-support bug for you.

### Building it yourself — yes, and it is an Arduino sketch

GPL-3.0 with full source; `ESP32_PrusaConnectCam.ino` builds in the **Arduino IDE** (no PlatformIO,
no ESP-IDF). Pinned dependency versions from the README:

| | |
|---|---|
| Arduino IDE | 2.3.4 |
| arduino-ESP32 | 3.1.0 |
| AsyncTCP | **3.3.1 (mathieucarbou)** |
| ESPAsyncWebServer | **3.4.5 (mathieucarbou)** |
| ArduinoJson | 7.3.0 |
| UniqueID | 1.3.0 |
| DHTnew | 0.5.2 |

⚠️ The README **struck through** the older `dvarrel` `ESPAsyncWebSrv` / `AsyncTCP` libraries in
favour of **mathieucarbou**'s. Same library names, different authors — install the wrong pair and
it will not build. The async ones must be added as **ZIP archives**, not from the Library Manager.

Building is optional: precompiled firmware is published per board with every release.

It authenticates with the **camera token** from Connect — i.e. it uses §4's Camera API, the one
officially supported Connect interface. Setup needs no toolchain beyond flashing:

1. Create the camera in Prusa Connect and copy its **token**.
2. Power the board — it comes up as an AP, `ESP32_camera_UID`, password `12345678`.
3. Browse to `http://192.168.0.1`, set WiFi credentials, paste the token.
4. Choose resolution and trigger interval.

**This is the whole reason the camera route was worth flagging.** It turns the one supported API
into a flash-and-configure job, with no JWT, no `0.0.1-dev` gateway, and nothing to reverse
engineer.

### The DHT11 support is real — and it is local-only

The firmware carries `ExternalTemperatureSensor.*`, wiring diagrams per board, and a
`page_temperature.html`. It uses the **DHTnew** library, which auto-detects the part, and the code
branches explicitly on `"DHT11"` and `"DHT22"`. It reads **temperature *and* humidity**, with a
selectable °C/°F unit.

On the **Freenove ESP32-S3-Wroom** board:

```c
/* -------------- DHT SENSOR CFG ----------------*/
#define DHT_SENSOR_ENABLE           false   ///< enable/disable DHT sensor
#define DHT_SENSOR_PIN              47      ///< GPIO pin for DHT sensor
```

**GPIO47**, and **disabled by default** — both at compile time and in the factory config
(`FACTORY_CFG_ENABLE_EXT_SENSOR 0`). It is switched on at runtime from the web UI, so a stock
precompiled build can use it without recompiling.

⛔ **The reading is NOT sent to Prusa Connect.** Checked: no temperature or humidity reference in
`connect.cpp` or `exif.cpp`. It is not in the telemetry and it is not embedded in the image EXIF.
Anyone assuming "Prusa firmware, therefore it shows up in Connect" would be wrong.

**It surfaces on the device's own web server instead**, which is arguably more useful here:

```
GET /get_temp               -> text/plain, temperature
GET /get_hum                -> text/plain, humidity
GET /page_temperature.html  -> the human page
```

Both are behind HTTP Basic auth (`Server_CheckBasicAuth`). **Two plain-text endpoints are the
easiest possible scrape target** — no JSON, no parsing — and feed straight into the MQTT bridge
already written in `scripts/chamber-serial-log.py`.

### ⭐ Why this matters more than the camera

This collapses the [chamber sensor](chamber-sensor.md) problem. That project currently needs a
transmitter, a USB-tethered receiver, ESP-NOW between them, and a serial bridge on the server — an
architecture forced entirely by the C3 SuperMinis being unable to transmit (§3z).

One S3 CAM board replaces all of it:

- A **real module antenna**, so WiFi simply works — the defect that caused everything is absent.
- **Camera → Prusa Connect** over the one officially supported API.
- **DHT11 on GPIO47 → two plain-text HTTP endpoints** → HA/MQTT.
- It mounts **on the printer**, which is where the chamber measurement belongs anyway.
- **10 DHT11s are already owned**, and so is the board.

No ESP-NOW, no hub, no USB tether, no antenna surgery. The DHT11 accuracy caveat from
[chamber-sensor §2](chamber-sensor/sensors.md) still stands (±2 °C, 1 °C resolution) — fine for "is the
chamber warm", poor for characterising a 40–60 °C ASA chamber precisely.

### The case — exists, fits this exact board, and mounts to an MK3

**[Freemove ESP32-S3 wroom camera case and prusa mount](https://www.printables.com/model/1201384-freemove-esp32-s3-wroom-camera-case-and-prusa-moun)**
by Nico3D (free, updated Mar 2025). Its own description: *a case that fits the new ESP32-S3 wroom
cam **with 2 USB-C holes*** — the dual-port variant, which most ESP32-S3 cases are not.

- Two versions: **V1** with a large air intake, **V2** with an added printing aid.
- **No supports needed** — which matches the house rule on
  [permanent geometry over sacrificial](fdm-design-rules.md).
- Tagged `mk3` / `cameramount`, and remixed from two **Prusa MK3 & MK4** camera mounts, so the
  mount arm targets the right printer. *(A sibling model by the same author is for the XL — do not
  grab that one by mistake.)*
- The model page itself links the Prusa firmware above, which is good corroboration that the
  board, the case and the firmware are the same combination in practice.

⚠️ **Check the fit before printing the whole thing.** "Freemove" is the author's typo for
**Freenove**, and the board here is an AliExpress board of that layout rather than a genuine
Freenove. Measure the board's length and width and compare against the case's internal cavity, or
print the case body alone first — cheaper than discovering a 2 mm error after printing the mount
arm too.

---

## 5. Summary

| Want | Possible? | How |
|---|---|---|
| Upload a G-code | ❌ no API | PrusaSlicer or the web UI |
| Add to the queue | ✅ | `command/start/cloud` with `printNow: false` |
| Read the queue | ✅ | `GET .../queue` |
| Remove from the queue | ✅ | `DELETE .../queue/{jobId}` |
| Read progress | ✅ | `GET /api/v1/jobs` |
| Pause / resume / stop | ✅ | `PUT .../command/*` |
| Publish a camera image | ✅ **supported** | Camera API `/c/snapshot` |
| Get a camera into Connect with no code | ✅ | Official [Prusa ESP32-Cam firmware](https://github.com/prusa3d/Prusa-Firmware-ESP32-Cam) + the owned S3 CAM board |
| Do any of it with a stable, documented, key-based auth | ❌ | JWT only, app-minted |
