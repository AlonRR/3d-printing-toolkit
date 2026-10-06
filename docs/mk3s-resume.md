# Resuming a print the printer stopped — with the part still on the bed

**Written 15–16 Sep 2026**, during a real recovery: a 21 h PETG print stopped by **MINTEMP BED**
after 11 h 51 m, at about **10.3 mm** of 58.6 mm. The part stayed stuck to the sheet, so the job was
worth resuming rather than restarting.

Everything about the firmware below was **read from the Prusa-Firmware v3.14.1 source**, not
recalled. Two beliefs held at the start of that session turned out to be wrong, and both would have
produced a crash or a ruined first layer. Re-read the source for another firmware version.

---

## 1. What the printer does when a thermal error stops a print

`MINTEMP BED` → `ThermalStop()` → `print_stop()` → `lcd_print_stop_finish()`, and that last function
is the one that matters:

1. mesh bed levelling is switched **off**,
2. `raise_z(10)` — the nozzle lifts **10 mm**,
3. if X and Y were homed, the head **parks at X50 Y190**.

Heaters go off, and the board needs a reset before it will do anything else. So **the nozzle is not
where it stopped printing**, which rules out the power-panic-style trick of declaring the old layer
height with `G92` and carrying on.

## 2. What must never happen with a part on the bed

- ⛔ **`G28`, `G28 W`, `G29`, `G30` or the LCD's Auto home / Calibrate Z.** Z homing drives the
  PINDA down until it senses **steel**. It cannot see plastic, so the nozzle goes through the part.
- ⛔ **`G80`.** Mesh levelling probes across the bed — the same crash, repeated at every point.
- ✅ **`G28 X Y` is safe.** With only X and Y requested the firmware never moves Z (`raise_z_above`
  runs only when all three axes are homed) and never probes.

## 3. Three things that look like a Z reference and are not

| | Why it is not a reference |
|---|---|
| The Z shown after a reset | Boot clamps Z to the `Z_MIN_POS` soft endstop, 0.15 mm. It is a constant, not a measurement |
| LCD **Move Z** | Moves in **1 mm** steps and its lower limit is the integer cast of 0.15, i.e. 0 — too coarse to set a layer, and it cannot reach below the boot position |
| Stalling the carriage at the top ("reverse homing") | Squares the gantry, but the firmware's own Z calibration sets Z to `Z_MAX_POS + 4` (or `+ 9`) after that stall — deliberately **higher than the truth**, so the number is not a bed-frame coordinate |

## 4. The reference that does work

**A caliper gap, then paper.**

⛔ **The caliper half of this DID NOT WORK on the real recovery — see §9.** The extruder body and the
caliper jaws foul each other, so the gap cannot be reached at all. §9 has the method that replaced
it. The paper touch-off below is unchanged and is still what sets the final gap.

1. Push the head by hand over a flat, solid part of the print — idle steppers release, so it moves.
2. Measure the gap between the nozzle tip and the top surface directly below it, with the calipers'
   inside jaws. Raise Z a few mm first if the gap is too tight to measure.
3. Nothing may move Z after that, because the resume file declares this gap with `G92`.
4. The file approaches to a nominal **0.4 mm** above that surface, and the final gap is set by
   lowering onto a sheet of paper with **Live adjust Z**.

**Live adjust Z is the only fine Z control on this machine**, and it has two traps:

- **One knob detent is one count is 1/400 mm**, with no encoder acceleration — about **400 detents
  per millimetre**. A touch-off must start within a few tenths of a millimetre, which is exactly why
  the caliper measurement carries the coarse half.
- **Its menu is hidden while logical Z ≥ 2.0 mm** (`babystep_allowed_strict`). The resume file works
  around this with a temporary `G92 Z1` during the touch-off, then sets the real height afterwards.
- ⚠️ **Leaving that menu writes the value to the active steel sheet in EEPROM.** The file restores
  the original with `M850 Z<value>`, so read the sheet's Live adjust Z **before** starting and pass
  it to the generator.

## 5. Splicing the G-code

Resume at the **next layer above the highest one present**, from that layer's own `;LAYER_CHANGE`
block, and take everything after its `G1 Z…` move unmodified. What the header has to rebuild:

- **Machine state**, because the original set it once at the top of the file: `M201`, `M203`,
  `M204`, both `M205` forms, `M221` flow, `M907` motor current, both `M900` linear-advance values,
  and the fan command in force at that height.
- **Extruder state.** A layer's lead-in wipes and retracts, and the layer then un-retracts by the
  same amount. The generator asserts those two match, primes off the part, and re-retracts, so the
  spliced code starts in the state it expects.
- **Relative extrusion** (`M83`) and absolute positioning (`G90`).

Deliberately dropped: the start block's `G28 W` and `G80`, and the intro line, which would draw a
purge stripe across the part.

## 6. The procedure

1. **Do not move Z** after the stop, and do not home.
2. Measure the part's height with calipers and snap it to the 0.2 mm layer grid. A wrong guess by
   one layer only changes the finished height by 0.2 mm — the physical first-layer gap is set by the
   touch-off either way.
3. Read the sheet's Live adjust Z value from the LCD.
4. Measure the nozzle-to-part gap as in §4.
5. Generate the file, upload it, and start it **with someone at the printer**.
6. The file prompts three times (`M0` waits for the knob): confirm the gap, confirm paper grip after
   the touch-off, and remove the purge strand.
7. Watch the first resumed layer.

## 7. The tools

[`scripts/mk3s-resume/`](../scripts/mk3s-resume/)

```
make_resume.py  <original.gcode> <wall_z> <top_z> <live_z> <gap_mm> <out.gcode>
upload_resume.py <file.gcode>     # PUT to PrusaLink with Print-After-Upload: ?0 - never auto-starts
print_monitor.py <log_dir> [max_seconds] [interval]
```

`make_resume.py` refuses impossible inputs and verifies its own output: the tail must be
byte-identical to the original, homing must be exactly two `G28 X Y`, no probing command may appear,
the Z commands must occur in the right order, every LCD message must fit the 20-character status
line, and the touch point must have extrusion under it in the layers either side. Override the touch
point with `RESUME_TOUCH_XY=x,y` — the default is one specific part's wall and means nothing
elsewhere.

`print_monitor.py` logs state, Z, temperatures and progress as JSON lines, exits when the printer
leaves `PRINTING` so a watcher is notified, and counts bed readings more than 5 °C below target —
useful when the stop was a bed-thermistor fault.

Both PrusaLink scripts read the host and API key from a PrusaSlicer physical-printer profile, which
is gitignored because it stores the key in plaintext. Point them elsewhere with `PRUSA_PRINTER_INI`:
[`scripts/mk3s-resume/printer.ini.example`](../scripts/mk3s-resume/printer.ini.example) shows the two
settings they read, for a machine without that profile.

## 8. What a resume cannot fix

- **No mesh compensation.** Levelling cannot be re-measured with the part in the way, so the resumed
  layers are flat in machine coordinates while the part below follows the bed's shape. The touch-off
  makes that error zero at one point and leaves it elsewhere.
- **A visible seam**, and a weaker bond, at the resume layer.
- **Gaps where the stopped layer was incomplete.** Whatever that layer had not yet printed is a
  0.4 mm step for the layer above to bridge.
- **The original fault.** A resume buys the hours back; it does not diagnose why the print stopped.

### ✅ The bed probe was repaired — 17 Sep 2026

Alon repaired the heatbed thermistor, the fault behind the `MINTEMP BED` stop that this whole page
exists for. Verified from outside over PrusaLink, passively:

| | |
|---|---|
| ~50 samples over two runs | **26.2 – 26.4 °C**, spread 0.20, sd 0.07 |
| Readings under 15 °C | **none** — MINTEMP fires below 10 |
| Jumps over 1 °C between consecutive samples | **none** |
| Failed reads | none |

⚠️ **That is a COLD, STATIONARY test, and the fault was neither.** It appeared with the bed at 70 °C
and the gantry moving, and an intermittent break at a cable clamp is exactly the kind that hides when
nothing is hot and nothing moves. **The test that settles it is the wiggle test under load** — bed
preheated to 70 °C, flex the harness at the bed end, watch the reading. Until that is done, "repaired"
means "no longer faulting at room temperature".

📋 **`scripts/mk3s-resume/print_monitor.py` is the instrument for the next long print**: it counts bed
readings more than 5 °C below target, which is the shape this fault would take before it trips.

✅ **It is hardened against the reduced object**, which it had to be: a restart mid-print would
otherwise log a few empty samples and then stop counting dips — the one job it has, during exactly
the window a thermistor fault would show. It now treats a status with no temperatures as a **blind
sample**, counts those separately, and reports them alongside the dip count, so a quiet run and a
run where the daemon was restarting are no longer the same output.

⛔ **Do not read a PrusaLink `ERROR` state as a printer fault.** While sampling the above, the printer
showed `ERROR`, then PrusaLink returned 502, then 503 *"not finished initializing"*, then served a
**reduced status object with no temperature fields** for about 20 seconds before recovering. That is
the daemon restarting, not the machine — the printer stayed `IDLE` throughout. Two consequences:
anything polling this API must use `.get()` rather than indexing `temp_bed`, because the reduced
object is a real state; and when the print host sits behind a reverse proxy, a 502 is **the proxy**
answering rather than the printer — check which `Server` header came back before blaming the Pi.

⚠️ **Prefer the printer's SD card over streaming** when the print host is unreliable — a long resume
run through a print server whose storage is failing simply adds a second way to lose the part.
Everything in the generated file behaves the same from SD, and Live adjust Z is easier to reach.

---

## 9. What the real recovery changed — 17 Sep 2026

The resume above was finally run. It worked: the spliced layer bonded, Z advanced normally, and the
job resumed with ~9 h 35 m remaining, matching the estimate derived from the original file's own
`M73` markers. Five things in this page were wrong or missing, and the recovery found all five.

### ⛔ The caliper gap is not measurable — the coarse reference had to be replaced

§4 said to measure nozzle-to-part with the calipers' inside jaws. **On this machine that is
physically impossible**: the extruder body and the jaws foul. No amount of technique fixes it.

What replaced it, and it is better:

1. **Jog Z down to contact in 0.1 mm steps from the print host's web UI.** The LCD's Move Z is
   **1 mm** steps, which brackets contact to 1 mm and is useless here; the web UI jogs 0.1 mm.
2. **Reset is safe and does not move Z** — boot clamps the *coordinate* to `Z_MIN_POS` 0.15 while the
   nozzle stays physically where it was.
3. **Jog back up a known amount** and that is the gap, measured by the machine's own leadscrew
   instead of by eye. Relative motion is exact even though the absolute frame is meaningless.
4. Heat the nozzle to the same temperature the touch-off uses (170) and **wipe it first** — a cold
   blob reads as early contact, and the hotend's thermal expansion should match the later touch-off.

⚠️ **Contact judged by eye reads EARLY.** Measured here: contact reported at 10.83, actual 10.40 —
**0.43 mm early**, so the true gap was 5.43 mm where 5.00 was declared. The coarse reference is
allowed to be wrong by a few tenths; absorbing exactly that is what the paper touch-off is for.
⚠️ Declaring a gap **larger** than the truth is the dangerous direction — it drives the approach
*below* the part. Smaller is safe and merely costs knob-turning.

### ✅ Live adjust Z reaches past −2.0

This page assumed roughly 0.46 mm of downward room from a sheet at −1.535. **Wrong** — the touch-off
ran to **−2.267** without complaint. Lucky, because the 0.43 mm coarse error needed 0.732 mm of
travel where 0.3 mm had been budgeted.

### ✅ `M850` mid-print does not disturb the established Z

The restore step was a live worry: if `M850 Z<v>` re-applied the sheet offset as a physical shift, it
would undo the touch-off and print the resumed layer in the air. **It does not.** Verified by the
print itself — the layer bonded and Z advanced. Consistent with babystep applying through
`babystepsTodo` as motion already spent, which an EEPROM write cannot retract. *(Prusa's own G-code
reference describes M850 as setting/reporting sheet values. The handler was NOT read in source —
`Marlin_main.cpp` is too large to fetch whole and GitHub code search needs auth.)*

### ⭐ The original G-code can survive in the OS temp directory

The print host lost the file completely — PrusaLink storage empty, job history gone, not on the SD
card. It survived as **PrusaSlicer's upload temp file**, `%TEMP%\.<pid>_0.gcode`: "Send to printer"
slices to a temp file and uploads *that*, and the temp copy stays behind on the workstation.

**Check there before concluding a lost print is unrecoverable**, and identify the candidate on
several independent signatures rather than one. Here: layer count × layer height gave the exact
height, the duration matched, the slice timestamp matched the slicer's own config mtime, and the
`M73` remaining-time at the stop height agreed with the elapsed clock to 2.2 %.

⚠️ **Do not identify it by `max Z` from the `G1 Z` moves** — that catches the end-of-print lift, not
the print height, and it wrongly cleared a saved project and wrongly indicted the right file. Use
`;LAYER_CHANGE` count × layer height.

### 🐛 `urllib` will not follow a 308 on PUT

With the print host behind a reverse proxy that upgrades http to https, **every** request answers
`308`. `HTTPRedirectHandler` re-issues only GET and HEAD, so status polling follows silently and
looks perfectly healthy while the upload dies on a redirect it was never going to follow.
`upload_resume.py` now follows one redirect by hand. The same trap hides any PUT/DELETE behind a
proxy while GETs suggest all is well.

### Touch point: put the coarse reference and the touch-off at the SAME place

If the heatbed has been off the machine, the part's height varies across the bed. Taking the coarse
reference at one spot and touching off at another feeds that difference straight into Z. Use
`RESUME_TOUCH_XY` so both happen at one point, and the tilt cancels.

⚠️ **Pick that point from the geometry, not by eye.** A first guess at mid-span landed in a recess
and was correctly refused. `scripts/mk3s-resume/probe_touch.py` replicates the generator's own
`covered()` test and reports which points qualify in both layers; prefer the one with the widest
margin, so hand-positioning error and any X/Y registration residual are absorbed.
