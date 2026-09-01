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
than a `0.0.1-dev` one. See [chamber-sensor](chamber-sensor.md) §3w for why an S3 is the board to
build a network device on, and §3z for why the C3 SuperMinis are not.

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
| Do any of it with a stable, documented, key-based auth | ❌ | JWT only, app-minted |
