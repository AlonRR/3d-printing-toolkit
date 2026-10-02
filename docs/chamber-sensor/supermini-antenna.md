# The SuperMini antenna — why they barely transmit, and the wire mod (§3z, §3x)

*Part of the [chamber sensor](../chamber-sensor.md) notes.*

**In short:**

- **The ESP32-C3 SuperMinis have a defective PCB antenna:** they receive well and transmit very
  little. `TX SUCCESS` does not mean anything left the board.
- **Build on a board with a real module antenna** — the ESP32-C3-MINI-1 or the Arduino Nano ESP32 —
  or fix the SuperMini first.
- **The §3x fix is 31 mm of wire on the antenna pads.** Ohm out the feed pad first; leave the
  ceramic antenna in place.
- **Measured here, 14 Sep 2026, on one modded board:** **17–19 dB stronger** than a stock board at a
  receiver across the house, with no loss. At centimetres, full power corrupts its frames, so do not
  mount it beside another radio, or cap it at 8.5 dBm.
- The SuperMini's tiny ground plane is the real limit. A bigger ground plane, or a dipole, are the
  next things to try.
- The wire for it is on hand: UL1007 22 AWG solid.

## The root cause: the SuperMinis barely transmit (§3z)

**Read this before anything else on this page.** It invalidates several
conclusions below and explains an entire night of WiFi debugging.

The two ESP32-C3 **SuperMini** boards this project was built on have the known
defective PCB antenna. They **receive perfectly and transmit almost nothing.**

Measured 1 Sep 2026. Three boards, same plain-C ESP-NOW binary, all on one desk:
two SuperMinis and one board built around an **ESP32-C3-MINI-1** module, which
has a proper shielded antenna.

```
SuperMini-A   RX 30 bytes from aa:bb:cc:dd:ee:01 : PING 22 ...
SuperMini-B   RX 30 bytes from aa:bb:cc:dd:ee:01 : PING 22 ...
MINI-1        (nothing, ever)
```

`aa:bb:cc:dd:ee:01` is the MINI-1 — **the address is redacted here**, and what the test turns on is
that it is the SAME address on both lines. **Both SuperMinis hear it flawlessly, every
ping. It hears neither of them. And they never hear each other** — every
received frame in the capture came from the MINI-1.

### Why this was so hard to see

**`TX SUCCESS` is not evidence of radio.** ESP-NOW's send callback reports that
the MAC layer accepted the frame. A detuned antenna radiates almost nothing
while the MAC stays perfectly happy, and on an *unacknowledged broadcast* there
is no feedback path at all. Both SuperMinis reported `TX SUCCESS` every two
seconds for hours while being effectively mute.

Everything that looked like healthy configuration — matching channels, matching
protocol versions, registered peers, components initialising — was true and
irrelevant. **Initialising is not transmitting**, and nothing in the stack
measures radiated power.

### It probably explains the WiFi failures too

A board that hears well but shouts weakly, talking to an access point, produces
exactly the pattern that consumed the night of 31 Aug:

| Symptom | Explanation |
|---|---|
| Full signal bars | It hears the AP's beacons fine. Receive works |
| `Auth Expired` / `Handshake Failed` | The AP cannot reliably hear *its* replies, so the handshake times out |
| Intermittent, per-radio, self-clearing | A marginal link budget that only sometimes closes |
| Unaffected by moving the boards | Both ends were already close; the deficit is radiated power, not distance |

So **the "hostile mesh" theory in [Which WiFi network](wifi.md#which-wifi-network-3a) was wrong.** Setting the IoT SSID to
WPA2-only did genuinely help — but it removed one obstacle from a link that was
already crippled at the transmitter.

### What to build on

- ✅ **The ESP32-C3-MINI-1 board**, or the **Arduino Nano ESP32** (u-blox
  NORA-W106). Both have real module antennas.
- ❌ **Not the SuperMinis.** Keep them for anything that does not need to be
  heard — USB-attached sensors, bench toys, HIL rig duty where a cable carries
  the data.

### Conclusions this overturns

- Blaming ESPHome's `espnow` component (commit `a925e7d`) — already retracted in
  `7ec50a9`; this identifies the actual cause.
- Calling both radios "provably healthy" (commit `d839179`) because both ends
  initialised and agreed on channel and version. They agreed about everything
  except whether any RF was leaving the board, which nothing measured.

## Rescuing them: the 31 mm wire mod (§3x)

There are 10 C3s here, so it is worth knowing they are repairable. **Optional:
the link above already works without it.**

### Why the board is bad

Espressif's own [C3 PCB layout
guidelines](https://docs.espressif.com/projects/esp-hardware-design-guidelines/en/latest/esp32c3/pcb-layout-design.html)
require **at least 15 mm clearance in all directions** around the antenna, a CLC
matching network, and USB/UART lines kept far away. The SuperMini is about
22 by 18 mm with a USB-C connector millimetres from the antenna. It cannot
satisfy any of them. Reported on top of that: two of the three matching-network
capacitor pads left unpopulated, and some batches with the ceramic antenna
mounted backwards.

**The corroborating symptom is heat.** Two independent observers measured these
boards running hotter than other C3s, one confirming the chip temperature
*dropped* after the mod. That points at reflected power being dissipated in the
die — a **mismatch**, not merely a weak antenna.

### The mod

One piece of **31 mm** of **1.0 mm** wire (about 18 AWG):

- **16 mm** wound into a roughly **8 mm** loop (around a 5 mm drill shank), ends
  spread to reach both chip-antenna pads — the chip antenna itself completes the
  last quarter of the circle.
- **15 mm** continuing straight up from the second pad.
- **Leave the stock ceramic antenna in place.** Tested better that way than
  removed.
- If the board has a visible ~4 mm feed trace before the antenna, use **27 mm**
  instead — the 4 mm difference matters.

**⚠️ The one step that breaks boards: the loop must start on the FEED pad.**
Do **not** trust the white stripe on the ceramic — documented photos show the
same part mounted in opposite orientations on different boards. **Ohm it out:**
the feed pad has continuity to an ESP32 pin, the other pad reads open to
everything. Thirty seconds, and it removes the single most common failure.

### Why 31 mm — and the thing it makes the mod depend on

Source: GreatScott!, *"I Found the Secret to WiFi Antennas! EB#68"*, 24 May 2026
([Q_5bna_cyBw](https://www.youtube.com/watch?v=Q_5bna_cyBw)). Measured with a VNA and RSSI A/B
tests, so the numbers below are his measurements, not theory.

**The 31 mm is not arbitrary and it checks out.** At 2.4 GHz the wavelength is ~12.5 cm:

| Antenna | Conductor length | Needs a ground plane? |
|---|---|---|
| **Dipole** — half wave | **6.25 cm** | No — the second element *is* the other half |
| **Monopole** — quarter wave | **3.125 cm** | **Yes** — the ground plane supplies the missing half |

So **§3x's 31 mm of wire is roughly a quarter wave in total**, and it behaves monopole-like: a
single-ended radiator working against the board's ground. ⚠️ **Do not read it as a plain quarter-wave
whip, though** — the procedure is 16 mm of loop plus 15 mm of straight, with the chip antenna left in
circuit, so most of that length is an impedance-matching structure and only the straight part sticks
out and radiates. The classification is still the useful part, because it names what the mod's
performance rests on: the ground plane.

### Which means the ground plane is the limit, not the wire

His DIY monopole — 3.2 cm of solid core wire on an SMA connector — matched commercial monopoles
**while clamped in a metal vice**. Removing it from the vice, i.e. shrinking its ground plane,
**visibly degraded it**, and on the VNA the same antenna read *"pretty terrible"* until a ground
plane was attached.

**A C3 SuperMini is a 22 × 18 mm board.** Its ground plane is a postage stamp. That is very likely
the real explanation for the ceiling recorded below — that a *modded* SuperMini reaches
-45 dBm where a properly laid-out C3 reads -33 dBm on the same desk. The wire is the right length;
it is standing on almost nothing.

**Consequence for this build:** effort spent on the ground plane is likely worth more than effort
spent on the wire. Anything that enlarges it — a ground pour, a scrap of copper tape bonded to the
board's ground, mounting against a grounded metal surface — attacks the actual limit.

### Three recovery routes, cheapest first

His explicit verdict: *"if you want an easy and reliable WiFi antenna, get yourself a dipole."*
Dipoles beat monopoles across his whole test set, and the reason is exactly this — **a dipole carries
its own second half and does not care about the ground plane.**

Because ten of these boards are owned and recovering them is worth real effort, here are the three
options ranked by effort, with what each actually attacks:

| # | Change | Attacks | Effort | Tested here |
|---|---|---|---|---|
| **A** | §3x wire — one 31 mm element | antenna *absence*; leaves the ground plane tiny | 30 s solder | **one board** — +17–19 dB over stock at the far end, fails at full power at centimetres; see *Measured here* |
| **B** | **Enlarge the ground plane** | the measured limit, directly | copper tape | no |
| **C** | **Dipole** — two 31 mm elements | removes ground-plane dependence entirely | rework | no |

**A — the documented wire.** Already written up above. Expect +10 to +17 dB and a ceiling.

**B — give the monopole a ground plane, which is the cheap win nobody tried.** A quarter-wave
monopole ideally wants a ground plane of about **λ/4 radius — ~3 cm, so a ~6 cm disc**. The
SuperMini's is a 22 × 18 mm board. Copper tape or thin sheet bonded to board ground, or simply
mounting the board flat against a grounded metal surface, closes most of that gap for pennies.
**This is the option I would try first**, because it is reversible, needs no rework of the RF
section, and it is the exact variable his experiment isolated — his DIY monopole matched commercial
ones *in a metal vice* and degraded out of it.

**C — the dipole.** Two ~31 mm elements, one on the antenna feed and one on board ground, extending
in **opposite** directions and **in line** with each other. Each is a quarter wave, so the pair makes
a half-wave dipole, and it stops caring about the ground plane.

### A dipole is not "the §3x mod twice" — the difference is the whole mechanism

The natural reading is that C is A plus one more wire. It is not:

| | §3x mod (A) | Dipole (C) |
|---|---|---|
| Shape | **16 mm loop + 15 mm straight** | **two plain straight elements** |
| Attaches to | both **chip-antenna pads** | one on **feed**, one on **GROUND** |
| Direction | one radiator | **opposite, collinear** |
| Chip antenna | **left in place** — it completes the loop | in the way; see below |

Two consequences, both load-bearing:

- **A second wire soldered to the feed is not a dipole, it is a fatter monopole.** The second element
  must go to **ground**. Ground supplying the other half of the radiator — instead of the board's
  tiny ground plane doing it badly — *is* the mechanism.
- **The §3x loop is a matching structure, not a radiator.** Its 16 mm does impedance work together
  with the chip antenna; only the 15 mm sticks out and radiates. A dipole discards that arrangement
  rather than duplicating it.

📋 **Open question, untested: what to do with the ceramic chip antenna.** §3x found leaving it in
place measured *better* — but that is for the loop mod, which deliberately uses it. Under a dipole it
sits in parallel with the driven element and will pull the match around. Removing it is
irreversible. **Try it in place first**, since that is reversible, and only remove it on a board
already accepted as possibly sacrificial.

### Mobility is the real argument for the dipole

**A monopole's other half is effectively whatever it is sitting near.** Its ground plane is the board
plus any nearby conductive mass. For a fixed node that is merely small; **for a node that moves it is
a variable** — the same board performs differently on a bench, in a plastic box, and beside a printer
frame, and it changes with no warning and no error.

**A dipole is self-contained**: both halves are soldered to it, so it behaves the same wherever it
goes. **For a mobile node that consistency is worth more than raw dB**, because a link budget you
cannot predict is one you cannot design around.

⚠️ **Be honest about what a dipole here is:** the SuperMini's feed is single-ended, so this is a
dipole fed unbalanced with no balun. It works in practice — plenty of cheap dipoles are built this
way — but common-mode current rides the ground element. Do not expect textbook performance; expect
*consistent* performance, which is the point.

### Wire: what matters, and what does not

- **Diameter barely affects the resonant LENGTH.** It sets **bandwidth** — thicker is more forgiving
  of a length error. WiFi's ~80 MHz at 2.4 GHz is undemanding, so **thin wire still works.**
- **Solid beats stranded for mechanical reasons only.** An element must hold a straight 31 mm and
  stay there; stranded wanders and its effective length changes as it is handled.
- ⚠️ **§3x's 1.0 mm spec is largely mechanical** — its loop has to hold an 8 mm circle unaided. **A
  dipole has no loop**, so it tolerates thinner wire than the mod does. Cores too floppy for A are
  perfectly usable for C.
- **Strip individual conductors out of multi-core cable; never use it as a cable.** *(The cable on hand is measured and specified just below.)* Two cores in one
  jacket run parallel and adjacent, and a dipole's elements must be **collinear and opposite** —
  separated, in line, pointing away from each other.

### Which wire: 0.60 mm is preferred, and the reason is the fourth-power law

Two solid wires are on hand and measured. **The thinner one is the better element**, and the margin
is not close:

| Wire | AWG | L/d | Element | **Bending stiffness** |
|---|---|---|---|---|
| **0.60 mm** | 22.6 | 51 | **~29.3 mm** | **1×** |
| 1.00 mm *(§3x spec)* | 18.2 | 31 | ~29.0 mm | 7.7× |
| 1.37 mm *(3-core)* | 15.5 | 22 | ~28.7 mm | **27×** |

**Second moment of area scales with d⁴**, so the 1.37 mm is not "somewhat stiffer" than the
0.60 mm — it is **27× stiffer**, and all of that torque is delivered to an SMD pad. Against ten
boards worth keeping, that dominates every other consideration in the table. The electrical cost of
going thinner is negligible: the element length moves by 0.6 mm, and the higher L/d sits marginally
*closer* to the nominal quarter wave.

**Cut 31 mm, trim toward ~29 mm**, measuring far-end RSSI against an unmodified control.

✅ **The inventory record agrees independently**, noting 22 AWG is *"NOT the gauge for the drybox PTC heater at ~4.2 A"*. ⚠️ **So the 1.37 mm is not waste — it is the right wire for that heater**, where the buy list
calls for 18 AWG to carry 4.2 A continuous and where stiffness is a virtue. That heater belongs to
the drybox build, which moved to its own repository.

### The wire on hand: UL1007 22 AWG solid tinned copper, 5 × 10 m

**`Hookup wire, UL1007 22AWG solid tinned copper - 5 colours, 10m each`**.

| | |
|---|---|
| Conductor | **22 AWG solid tinned copper** — 0.644 mm nominal, measures 0.60 |
| Insulation | PVC |
| Quantity | **5 coils, 10 m each — 50 m total**, in black, red, blue, green, yellow |
| Model | `DXXAW22YL-10M` |

**Every open question about this wire is closed, and all three answers are the good ones:**

- ✅ **Tinned copper, not CCA.** The copper-clad-aluminium worry — brittle, work-hardens, fails at
  the copper/aluminium interface — does not apply. This is real copper.
- ✅ **Pre-tinned, so there is no enamel to strip.** It takes solder directly.
- ✅ **50 m against the ~700 mm ten boards need** — about **70× margin**. Quantity is a non-issue and
  practice attempts cost nothing.

### Use two colours, and let the wire prevent the mistake

Five colours is not decoration here. **The most likely way to build a dipole wrong is to solder both
elements to the feed**, which produces a fatter monopole that looks identical, measures worse, and
gives no visible clue why.

**Pick one colour for the feed element and another for the ground element, and hold that convention
across all ten boards.** The error then becomes visible at a glance instead of needing a meter — and
across a batch, a mistake you can see beats one you have to measure.

### Why two searches missed it — a race, not a search failure

Worth recording, because the obvious lesson would be the wrong one. A full inventory agent and a
direct ten-route search both returned **NOT FOUND**, and **both were correct when they ran**:

| | Entities |
|---|---|
| Agent's sweep | 221 |
| Direct search | 222 |
| The search that found it | **223** |

**The record was created while the searches were running**, by another session working the same
inventory. Nothing was mis-searched and no keyword was wrong — a `hookup` query genuinely returned
zero, minutes before the row existed.

⚠️ **The generalisable point: `NOT FOUND` against a live shared inventory carries a timestamp.** It
describes a moment, not a property of the world, and re-running it costs seconds. The house rule
that *a match proves presence and nothing proves absence* already implies this; this is what it looks
like in practice.

*(What led here was an inventory helper script — **one named
for a part is evidence the part exists, even when the record does not yet.**)*

### If the 1.37 mm is used after all — strain relief is mandatory

⛔ **A 15 AWG solid conductor on an SMD antenna pad is a lever.** Its stiffness means any knock, flex
or tug transfers into a pad measured in fractions of a millimetre, and SMD pads lift. This is the
most likely way to destroy a board in this work — more likely than any RF mistake.

- Anchor the wire to the PCB with epoxy or hot glue **a few millimetres past the solder joint**, so
  load lands in adhesive rather than the pad.
- Better: solder a **short thin flexible section to the pad** and join the heavy element to *that*
  a few millimetres away, making the thin part a deliberate mechanical fuse.
- Do the strain relief **before** the first bend.

**There is no shortage of it:** 4 m of 3-core is **12 m of conductor**, about **195 dipoles' worth**
for 10 boards. Practice is free — **do the first attempt on a board already written off**, because
wire is not the constraint here, pads are.

### How to tell whether it worked

⛔ **Do not measure at 5 cm.** At 2.4 GHz that is inside the reactive near field, where two
mismatched antennas couple in ways that ignore path loss.

- Read **RSSI from the far end** — the AP, or another node — at several metres, through a wall.
- **Keep one unmodified board as a permanent control**, and measure it in the same spot in the same
  session. A number without a control is not a result.
- **Orient the element vertically**, matching the AP's antennas. Simple antennas radiate in a donut —
  strong to the sides, weak off the ends — and he measured co-alignment as clearly best. This is
  free and applies to every option above.
- ⛔ **Do not use a longer wire.** *"Bigger is not always better"* — his largest antenna was a
  monopole that lost to the dipoles. Length has an optimum, not a direction.

**For the drybox and chamber nodes specifically, the node is mounted OUTSIDE the box**, so there is
physical room for a proper antenna and no reason to compromise the geometry to fit a lid.

Expect **+10 to +17 dB**. Then accept the ceiling: the best-documented A/B put a
*modded* SuperMini at -45 dBm where a properly laid-out C3 read -33 dBm on the
same desk. The mod recovers most of the defect; **it does not make the board
good.**

⚠️ **What this source does NOT settle.** He tests SMA-connected wire antennas on boards with uFL
connectors; he explicitly lists **chip antennas and PCB antennas as not yet covered**, and those are
what a SuperMini actually has. The SuperMini's fault is a layout and impedance-matching problem, and
this video does not measure that class of part. Treat the ground-plane finding as a strong
explanation for the observed ceiling, not as a measurement of this board.

### Measured here, 14 Sep 2026 — one modded board against stock controls

⚠️ **Caveats first, because they are real.**

- The boards sat **centimetres apart**, inside the reactive near-field — against the rule directly
  above. That affects more than the RSSI numbers: coupling to a nearby antenna changes the load the
  transmitter sees, so **the corruption itself may be a close-range effect**.
- The modded board's **feed pad was not ohmed**.
- **Nothing records how this board behaved before the mod**, or why it was the one chosen. If it
  was already misbehaving, the result belongs to the board, not to the mod.
- **One board of each kind.** A strong lead, not a verdict on the mod.

**Method.** [`firmware/espnow-rssi`](../../firmware/espnow-rssi) on three boards: the modded SuperMini,
an unmodified SuperMini from the same batch, and an Arduino Nano ESP32 (S3) as a reference radio.
Every board broadcasts a counter every 0.3–0.7 s and logs the RSSI of each packet it decodes;
`capture.py` summarises per direction. The modded board was rebuilt at several transmit powers
(`-D TX_QDBM`).

**Modded board transmitting, Nano receiving:**

| Modded TX power | Decoded at the Nano | Median RSSI |
|---|---|---|
| 2 dBm | 245 in 2 min — essentially all | −44 dBm |
| 8.5 dBm | 120 in 60 s, no gaps | −39 dBm |
| 13 dBm | 71 in 60 s — **42 % lost** | −32 dBm |
| 17 dBm | **0** in 60 s | — |
| 19.5 dBm | **0–2 of ~230**, in three separate runs | — |

**The control — both SuperMinis at 19.5 dBm, captured in the same two minutes:**

| Transmitter | Decoded by the Nano | Decoded by the other SuperMini |
|---|---|---|
| Stock SuperMini | 242, median −31 dBm | 243, median −26 dBm |
| Modded SuperMini | **2** of ~230 | **2** of ~230 |

**What that shows, at this range.**

- **The mod did not cut radiated power.** At low power the modded board is decoded cleanly, and the
  two full-power frames that got through arrived at about −22 dBm — stronger than the stock board's
  −31 dBm. Two packets are too few to put a number on it.
- **Its frames arrive corrupted, not weak.** The cleanest evidence is one receiver at one signal
  level: at 13 dBm the modded board reached the Nano at **−32 dBm and lost 42 %** of its packets; the
  stock board reached the same Nano at **−31 dBm and lost 0.4 %** (separate runs). Same receiver, same
  level, different transmitter. At 19.5 dBm, two different receivers — the S3 and the stock C3 —
  failed on it identically.
- **The failure begins between 8.5 and 13 dBm** and is total by 17 dBm.
- **The stock board transmitted fine at full power.** "SuperMinis receive but do not transmit" did
  not reproduce on this one board — at centimetres. The far end is untested.
- **Chip temperature leans the way §3x predicts and proves nothing:** the stock board read 46–63 °C
  (it had just been flashed), the modded one 55–56 °C — two uncalibrated internal sensors.

**Two experiments were proposed to settle it,** cheapest first:

1. **Ohm the pad.** If the loop is on the ground pad, that is the answer. If it is on the feed pad,
   **remove the wire and re-run the sweep**: stock behaviour returning means the mod caused it;
   failing anyway means the board was bad before the mod. *Less pressing after experiment 2 — a
   wrong-pad loop would not deliver +17–19 dB over a stock board.*
2. **Measure at the far end.** The modded board on a USB power bank, several metres away through a
   wall, with the Nano logging at the PC — only the modded → Nano direction is needed. Then the stock
   board in the same spot. ✅ **Done the same day, at the print station** (below) — and it reversed
   the centimetre-range result.

**Which board to use** *(revised after the print-station comparison below)*. For a node across a
room — the chamber-sensor case — **the modded board**: at the print station it delivered 17–19 dB
more at the Nano than a stock board, with no loss. The close-range failure only matters if it has
to sit centimetres from another radio; then cap it at **8.5 dBm** (`TX_QDBM=34`), the highest
setting decoded cleanly at that range. In ESPHome that is `wifi: output_power: 8.5dB`, not yet
tested with the espnow component. An earlier version of this paragraph said to prefer a stock
board; that rested on the centimetre-range numbers alone, and the print-station comparison
reversed it.

⚠️ **Unexplained, and worth knowing before comparing receive numbers across builds:** the modded
board reported incoming packets about 7 dB stronger (−14 against −21 dBm) whenever its *own* transmit
power was set to 17 dBm or more. The stock board's receive readings at 19.5 dBm were also noisy
(spread 3.3 dB), so this may be C3 radio behaviour at high transmit power rather than this board.

**Far end, first half of experiment 2 — same day, the modded board moved to the print station.**
Still at 19.5 dBm and powered there; distance and walls not yet recorded. Both receivers — the Nano
and the stock SuperMini — stayed at the PC.

| Capture | Decoded at the Nano | Decoded at the stock SuperMini |
|---|---|---|
| 2 min | 125 of ~240 (52 %), median −51 dBm | 124 (52 %), median −56 dBm |
| 2 min, packet by packet | 149 of 244 (61 %) | 154 (63 %) |

- **Distance helped a lot:** from 0–2 decoded at centimetres to about half or more. Much of the
  close-range failure was the close range — the first caveat above was right to worry.
- **It is still a bad link.** Losing a third to a half of the packets at −51 dBm is not normal; next
  to the PC, the stock board lost none in the same capture.
- **Both receivers lost mostly the SAME packets:** 81 lost by both, where independent losses would
  give about 35; 140 decoded by both, against about 94. So packets are lost *before* they reach the
  receivers — at the transmitter, or on the way. ⚠️ **That does not separate the two**: both
  receivers sit side by side at the PC and share almost the whole path. Lost packets were mostly
  isolated (34 single, 11 double, 7 triple, one run of four), with no odd/even pattern.
- **What settles it is the second half of experiment 2:** the stock SuperMini in the same spot,
  powered the same way.

**A second stock board, beside the PC first.** Another unmodified SuperMini from the batch, same
firmware at 19.5 dBm, captured at centimetres while the modded board kept transmitting from the
print station:

| Transmitter, same 2 min | Lost at the Nano | Lost at stock #1 |
|---|---|---|
| Stock #2, beside the PC | 5 %, median −32 dBm | 2.5 %, −37 dBm |
| Stock #1, beside the PC | 0.4 %, −30 dBm | — |
| Modded, at the print station | 16.7 %, −56 dBm | 14.3 %, −61 dBm |

- Stock #2 works at full power at centimetres, like stock #1, with slightly more loss.
- **The modded board's loss at the print station changes with nothing moved:** 33–48 % in the
  first two captures, 14–17 % in this one. Conditions there vary — one more reason the comparison
  has to be a stock board in that spot *at the same time*.

**Both at the print station, same two minutes — and the result reverses.** Stock #2 was set down at
the print station beside the modded board (exact placement and orientation not recorded), both at
19.5 dBm, both receivers at the PC:

| Capture | Modded — Nano / stock #1 | Stock #2 — Nano / stock #1 |
|---|---|---|
| 1st, 2 min | 0 % lost, −59 dBm / 0.4 %, −62 dBm | 24 % lost, −76 dBm / 13 %, −69 dBm |
| 2nd, 2 min | 0 %, −56 dBm / 0 %, −61 dBm | 6 %, −75 dBm / 2 %, −70 dBm |

- **At a real distance the modded board is the better one:** 17–19 dB stronger at the Nano and
  8–9 dB at stock #1, with no loss, while the stock board lost 2–24 %. That is the +10 to +17 dB this
  section predicts, arriving at receivers in another part of the house.
- **So the close-range failure is a close-range effect.** A stronger antenna couples harder into a
  radio centimetres away, and at full power that corrupts its frames. It is a reason not to mount a
  modded board beside another radio — not a reason to avoid the mod. It also makes a wrong-pad loop
  unlikely: that would not perform like this.
- **The stock board's losses are mostly on the way, not at its transmitter:** only 3 packets were
  lost by both receivers in the second capture.
- **The modded board's earlier 14–48 % loss at the station** did not recur once both boards were
  measured together. What changed is not known; the placement when stock #2 was set down is a
  candidate.
- **Board-to-board spread is small beside this:** next to the PC, stock #2 read −32 dBm at the Nano
  and stock #1 −30 dBm.

⚠️ **Still one modded board**, and the two station boards were not confirmed to share position and
orientation. 20 dB is a lot for placement to explain, but a repeat with the two boards swapped
would rule it out.

### Known ways it goes wrong

Several people report WiFi going *dead* after the mod, or the board raising RSSI
yet refusing to associate. The fallback is a different topology — remove the
ceramic antenna and fit about **62 mm** end-fed on the feed pad — and the
reported lengths for it genuinely conflict (32 mm also worked for one person),
because nobody has resolved it with a VNA. Do the reversible 31 mm version
first; removing the ceramic antenna is **not** reversible without a spare.

The other real risk is mechanical: the vertical wire snagging has torn the
ceramic antenna off a board along with its traces. Strain-relieve it where it
leaves any enclosure, and keep §3z's keep-out in mind — do not bury a modded C3
next to the fan, the PD board, or metal.
