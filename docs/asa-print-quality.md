# Getting better ASA prints — Prusa MK3S+ in a Lack enclosure

Researched 29 Aug 2026. Ordered by expected payoff per unit of effort, not by topic. Nothing
here has been applied — no profile was changed and no setting was touched.

The setup this is written against: **Prusa MK3S+, open frame, inside an IKEA Lack enclosure
with one side deliberately left open for venting, no temperature sensing inside it, printing
Inslogic ASA at 255 °C / 100 °C bed with 20 % fan.** Some of the advice below is generic ASA
practice; the first item is specific to these profiles and is the one worth reading first.

---

## 1. The minimum layer time in the ASA profile is unreachable — free fix, biggest effect

`Inslogic ASA` sets `slowdown_below_layer_time = 15`, meaning *"never let a layer finish in
under 15 seconds."* It also sets `min_print_speed = 15`, meaning *"never slow below 15 mm/s to
achieve that."* **The second setting silently overrides the first on any small part.**

The proof is already in this repo. The vase stem that printed badly was a 21.8 mm single-wall
tube, so each layer is one loop of

    π × (21.8 − 0.45) = 67.1 mm of extrusion

| | Longest layer time the floor allows | What the profile asked for | Measured |
|---|---|---|---|
| `Inslogic ASA` (`min_print_speed = 15`) | 67.1 / 15 = **4.47 s** | 15 s | **5.01 s** |
| `Inslogic ASA - thin wall` (`min_print_speed = 5`) | 67.1 / 5 = **13.4 s** | 10 s | **10.01 s** |

Both measurements land exactly where the arithmetic puts them — the base profile a little over
4.47 s once acceleration and the Z move are added, the thin-wall profile at precisely its 10 s
target because 10 s needs 6.71 mm/s, which clears the 5 mm/s floor.

So the general ASA profile has been asking for a 15 s minimum layer time and **getting 5** — a
3.4× shortfall — on exactly the parts that need it most. Small cross-sections are where heat
accumulates fastest and where a bead lands on a layer that has not set.

**This also revises what the thin-wall experiment proved.** [The Inslogic
README](../slicer/filament/inslogic/README.md) records three changes — fan 20 → 70 %, layer
time → 10 s, temperature 255 → 250 °C — and concludes the cause was under-solidification. That
conclusion stands. But the change that *did the work* is a fourth one the write-up never
mentions: `min_print_speed` 15 → 5. Without it the 10 s layer time is unreachable too, and
`slowdown_below_layer_time` was actually *lowered* (15 → 10), which reads like a reduction in
cooling time and is the opposite of what happened.

### The change

| Key | Was | Now | Status |
|---|---|---|---|
| `min_print_speed` | 15 | **5** | ✅ **Applied 29 Aug 2026** to `Inslogic ASA` and `Inslogic ASA @0.8 nozzle` |
| `max_fan_speed` | 20 | 45 | ❌ **Not applied.** See below |
| `min_fan_speed` | 20 | 20 | Unchanged either way — bulk ASA must not get more cooling |

Measured by slicing a 21.8 mm single-wall tube — the vase-stem geometry — with everything held
constant except the floor, using the CLI's `--min-print-speed` override so exactly one variable
moved:

| | Floor | Layer-time target | Fan | Slowest move | Actual layer time | Print time |
|---|---|---|---|---|---|---|
| `Inslogic ASA`, before | 15 | 15 s | 20 % | 15.00 mm/s | **4.47 s** | 9 m 28 s |
| `Inslogic ASA`, after | **5** | 15 s | 20 % | 5.00 mm/s | **13.41 s** | 23 m 43 s |
| `- thin wall`, for reference | 5 | 10 s | 70 % | 6.70 mm/s | 10.01 s | 18 m 14 s |

**It costs nothing on ordinary parts.** A 40 mm solid cube and a mid-size probe holder slice to
*identical* times either way — 1 h 37 m 03 s and 41 m 30 s respectively, before and after. The
floor only engages once a layer is small enough to hit it, which is exactly where it should.

The 2.5× on the tube is not a cost of the fix; it is the cooling time the profile has been
asking for since July and silently not getting.

### The fan half was deliberately left out

The original proposal paired the floor with `max_fan_speed = 45`, so that
`fan_below_layer_time = 20` would ramp cooling on short layers only. **That was not applied**,
because 45 % is an interpolation between two proven points — 70 % validated on a single wall
with no cross-section to delaminate, 20 % validated on bulk ASA — and not a result.

Leaving it out is safe on its own terms: more layer time at the same fan speed is strictly more
solidification, since the nozzle deposits the same energy per layer either way and the part is
cooling throughout. The fan ramp would make short layers better still. It needs a test print
first.

---

## 2. The bed is 5–10 °C below what Prusa uses — free

Currently 100/100 °C, the top of Inslogic's 80–100 range. [Prusa's own ASA
guidance](https://help.prusa3d.com/article/asa_1809) is **105 °C first layer / 110 °C after**,
and the general consensus for ASA is 105–110. A hotter bed keeps the lower layers soft longer,
so the part relieves stress instead of curling the corners up.

The Inslogic README already names this as the first thing to try if parts lift. It is worth
trying *before* parts lift.

**One real risk that comes with it:** ASA on a **smooth PEI** sheet at 110 °C can bond hard
enough to tear PEI off the sheet on removal — [a documented Prusa-forum
failure](https://forum.prusa3d.com/forum/original-prusa-i3-mk3s-mk3-how-do-i-print-this-printing-help/prusament-asa-sticking-too-well-on-pei-sheet/),
and the same over-adhesion mechanism the PETG profiles in this repo avoid by running a 70 °C
bed. Prusa's answer is a **thin glue-stick layer as a release agent**, not a lower bed. Apply
it before raising the bed, not after the first sheet is damaged.

---

## 3. Bed preparation and brim — free, and the most common actual cause

- **Clean the sheet with IPA before every ASA print.** ASA is far less forgiving of finger oil
  than PLA. When IPA stops working, wash with warm water and a few drops of dish soap —
  [Prusa's own escalation](https://help.prusa3d.com/article/first-layer-issues_1804), because
  IPA redistributes oils rather than removing them once they build up.
- **Brim, at least 5 mm**, on anything tall or with a small footprint. Prusa recommends ≥ 3 mm
  as a baseline; ASA earns more.
- **Use PrusaSlicer's draft shield** (*Print Settings → Skirt and Brim → Draft shield*). It
  prints a wall around the part that holds a pocket of warm still air against it. On an
  enclosure with an open side this is the cheapest partial substitute for closing the side, and
  it costs only filament.

Every print profile in `slicer/print/` strips skirt and brim by default — that is the right
call for most parts and the wrong one for ASA. Worth an ASA-specific print profile rather than
remembering to tick the box.

---

## 4. Chamber temperature — the real ceiling, and it is gated on a measurement

ASA wants a **warm, still chamber: 40–50 °C is the usual target**, and sources go as high as
70. The enclosure currently has **one side deliberately open**, so the chamber is near room
temperature and the airflow across the part is asymmetric. That is the largest remaining
variable, and no slicer setting substitutes for it.

**Do not simply close it.** The Einsy board and the PSU sit *inside* the Lack frame. The
failure mode is documented and specific: users printing ABS/ASA in a closed enclosure report
**`TMC DRIVER OVERTEMP`** faults, and the practical advice is either active cooling on the
electronics box or moving the board outside the enclosure. Reports conflict on whether an
MK3S+ tolerates a closed enclosure — some run doors-closed without trouble — which is exactly
the situation where measuring beats reading forum posts.

**The gating step is the chamber sensor that `CLAUDE.md` already lists as a future project.**
The fume-fan ESP32 is at the printer with spare inputs and is the natural host.

⚠️ **The DHT11 is marginal for this specific job.** Ten are on hand, but its range tops out at
**50 °C** — the top of the target band — with ±2 °C accuracy and 1 °C resolution. It will tell
you "the chamber is 44, not 24", which is enough to decide whether closing the side did
anything. It will not characterise a 50 °C chamber, and it saturates precisely where the
interesting reading is. An AHT20 or SHT31 (±0.3 °C, to 120 °C) is the right part if this
becomes more than a yes/no check.

A staged approach that needs no purchase: close the open side **partially**, print, and let the
printer's own `TMC DRIVER OVERTEMP` guard be the safety net — it is a real firmware check, not
something that has to be inferred. Increase closure until either the print quality stops
improving or the printer complains.

---

## 5. Dry the filament — 80 °C for 4–6 h

Inslogic's data sheet says **80 °C, 4 h**; general ASA guidance says 80–90 °C for 4–6 h. ASA
absorbs roughly **0.2–0.4 % water in 24 h at 50 % RH** — less desperate than nylon or TPU, but
enough to matter on a spool that has been open for weeks.

Wet ASA looks like a bad profile, which is why it is worth ruling out first: **popping or
hissing at the nozzle, stringing, rough or pitted walls, small bubbles, inconsistent extrusion,
weak layers.** If a print has gone worse over time with no setting changed, moisture is the
first suspect, not the profile.

There is no dryer in this lab. The options, cheapest first:

- A kitchen oven at its lowest setting, if it will hold 80 °C — many will not go that low
  accurately, and ASA's Tg is 108 °C so there is margin, but an oven that overshoots to 120 °C
  will fuse the spool.
- The **12 V 50 W PTC heater already owned** (bought for the enclosure) in a sealed box. 50 W
  is modest but a small insulated box is a small volume. Needs a >4 A 12 V supply, which the
  PD trigger board is not.
- Desiccant storage to stop the problem recurring: filamentcenter sells 2 kg alumina at ₪89 and
  2 kg indicating silica gel at ₪69, orange-to-clear so it shows when it is spent.

Drying fixes a wet spool. Storage stops you needing to.

---

## 6. Things to leave alone

- **Do not raise the fan on bulk ASA.** The 20 % is deliberate and the reason is written up in
  the Inslogic README. The 100 % on Inslogic's data sheet is boilerplate — it appears
  identically on all four of their sheets, for four materials whose cooling needs are nothing
  alike. Item 1 above raises the fan *only for short layers*, which is a different thing.
- **Do not chase nozzle temperature first.** 255 °C sits mid-band for the speeds this printer
  runs and 260 is available if layer bonding is genuinely weak — but temperature is the knob
  people reach for when the real problem is a cold chamber or a wet spool, and it is the one
  most likely to trade one defect for another (stringing, blobs).
- **Do not seal the enclosure before item 4's measurement.** The electronics are inside it.

---

## Order to actually do this in

1. **Raise the bed to 105/110 with a glue-stick release layer.** Free, one profile edit, and
   the failure mode it prevents is the most common ASA failure there is.
2. ~~**Fix `min_print_speed`** (item 1).~~ ✅ **Done 29 Aug 2026** — applied to both Inslogic ASA
   profiles in this repo and verified by slice. ⚠️ **Not yet installed into
   `%APPDATA%\PrusaSlicer\filament\`** — PrusaSlicer was open at the time, and it rewrites its
   config folder on exit, so copying would have been silently undone. Copy it in with the
   slicer closed (command in the [Inslogic README](../slicer/filament/inslogic/README.md)).
3. **Brim and draft shield** on the next tall ASA part. Free.
4. **Dry a spool** and reprint something that came out badly. Rules out the variable that
   masquerades as everything else.
5. **Then** the chamber sensor and closing the enclosure side — the biggest effect, the most
   work, and the only one that can damage hardware if done in the wrong order.

Steps 1–4 need no purchase and no hardware. Step 5 needs a sensor wired to an ESP32 that is
already at the printer.

---

## Sources

- [ASA — Prusa Knowledge Base](https://help.prusa3d.com/article/asa_1809) — 105/110 bed, enclosure, glue stick on smooth PEI, brim ≥ 3 mm
- [First layer issues — Prusa Knowledge Base](https://help.prusa3d.com/article/first-layer-issues_1804) — IPA, then dish soap
- [Prusament ASA sticking too well on PEI](https://forum.prusa3d.com/forum/original-prusa-i3-mk3s-mk3-how-do-i-print-this-printing-help/prusament-asa-sticking-too-well-on-pei-sheet/) — the over-adhesion failure
- [How to succeed when 3D printing with ASA — MatterHackers](https://www.matterhackers.com/articles/how-to-succeed-when-3d-printing-with-asa-filament)
- [How to stop warping in ABS & ASA — Eolas Prints](https://eolasprints.com/en-us/blogs/advanced-3d-printing/fix-warping-abs-asa-guide) — chamber 50–70 °C, fan off or very low
- [Understanding chamber heating — ThreeDimensionPrinters](https://threedimensionprinters.com/understanding-chamber-heating-why-ambient-temperature-matters-for-abs-and-asa/) — 40–50 °C enclosure, no drafts
- [How hot can enclosure get? — Prusa forum](https://forum.prusa3d.com/forum/original-prusa-i3-mk3s-mk3-user-mods-octoprint-enclosures-nozzles/how-hot-can-enclosure-get/) and [Electronics in or out the enclosure?](https://forum.prusa3d.com/forum/original-prusa-i3-mk3s-mk3-improvements-archive/electronics-in-or-out-the-enclosure/) — `TMC DRIVER OVERTEMP`, Einsy placement
- [Does ASA filament need drying? — goodprints3d](https://www.goodprints3d.com/blogs/3d/does-asa-filament-need-to-stay-dry-or-do-people-overstate-the-moisture-problem) and [ASA drying temperature — 3dtrcek](https://3dtrcek.com/en/blog/post/asa-drying-temperature-how-to-properly-dry-filament-for-best-prints-2) — 0.2–0.4 % water in 24 h, 80–90 °C, wet symptoms
- Inslogic ASA Technical Data Sheet rev. 12.02.2024, archived at [`../slicer/reference/inslogic_asa_tds.pdf`](../slicer/reference/inslogic_asa_tds.pdf)
