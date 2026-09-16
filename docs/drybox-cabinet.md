# From a dry box to a dry cabinet

**Asked 16 Sep 2026:** turn the [active drybox](drybox-active.md) — a heated IKEA SAMLA 22 L box
holding four spools — into a cabinet. This page is the design, the parts, and what changes in code.

[drybox-active](drybox-active.md) stays the reference for the **dryer**: the heater assembly, its
safety ladder, and why the element sits outside the box. This page is the **store**, and the two
jobs are deliberately separated below.

---

## 1. The decision that drives everything else

A cabinet is not a bigger box, because two facts collide once the volume grows:

- **Drying needs an exhaust.** Warming sealed air raises its capacity to hold water; the water
  leaves the plastic and then goes straight back in on cooldown. Without a path out, a heated box is
  a machine for cycling moisture in and out of a spool.
- **Bentonite gives up moisture above ~50 °C** ([moisture-isotherms](moisture-isotherms.md)), so
  during a heated cycle the desiccant is not adsorbing at all.

**So a cabinet held permanently at 50 °C is worse than the box, not better.** It would be warm, open
to the room, and carrying a desiccant that is being driven backwards.

The design that follows from that is three modes, not one:

| Mode | Vents | Heater | Fans | When |
|---|---|---|---|---|
| **Dry** | open | modulated to setpoint | circulation continuous | hours, occasionally, after a spool arrives |
| **Purge** | open | **off** | both, hardest | 15–30 min at the end of every dry cycle |
| **Store** | **closed** | off | off | the default — nearly all of the cabinet's life |

⭐ **Purge is the step people leave out, and it is load-bearing.** It flushes the warm wet air out
*while it is still warm and still holding the water*, so what cools down afterwards is dry ambient
air rather than a loaded atmosphere — and so the clay, which has just been releasing water at 50 °C,
is not sealed in with it.

## 2. Heater sizing — 50 W does not scale, but insulation is cheaper than watts

The owned PTC is **12 V 50 W**, sized for 22 L. For a 120–180 L cabinet:

| | |
|---|---|
| **Loss through a bare carcass** | ~1.2–1.6 m² at U ≈ 2–3 W/m²K → **60–120 W** just to hold 25 K above room |
| **Loss with 20–30 mm XPS/PIR** | U ≈ 1 W/m²K → **~30–40 W** |
| **Heating the load itself** | 10 kg of PETG ≈ 12 kJ/K, so a 25 K rise is ~300 kJ ≈ **1.7 h at 50 W**, losses excluded |

**Insulate rather than buy watts.** Insulation keeps the build on the owned 12 V 6 A supply; 150 W
at 12 V is 12.5 A and forces a larger supply and heavier wiring. It also shortens every cycle.

⚠️ **These are estimates, and one bench run replaces them.** Put the owned heater in the actual
cabinet, run it, and record the temperature it holds and the current it draws — that measurement
decides insulate-versus-more-watts with a number.

## 3. ⛔ What not to buy: a Peltier "dry cabinet" module

Commercial electronics dry cabinets often use a Peltier condenser, and it cannot reach filament
humidity. Condensation only removes water while the cold plate is **below the dew point**, and at
15 %RH / 25 °C the dew point is about **−4 °C** — the plate frosts instead of drying. Peltier units
settle around 30–40 %RH. Desiccant remains the right mechanism here.

## 4. Parts

### Already owned — carries straight over

PTC heater 12 V 50 W with its bonded, separately cabled fan · 12 V 6 A supply · 2× 15 A MOSFET
modules · KSD9700 cutout · 85 °C one-shot thermal fuse · inline fuse holder + 7.5 A fuse · lever
connectors · 18 AWG silicone wire · TPS63020 buck-boost · ESP32-C3 boards · resistor kit ·
bentonite · PTFE tube (ID 2.5 × OD 4, 5 m) · 608-2RS bearings ×20 · **BME688**, free now that the
chamber took the AHT20+BMP280.

### To buy

| Part | Why it is on the list | Rough |
|---|---|---|
| Door gasket, self-adhesive EPDM/silicone D-profile, 5–10 m | The seal *is* the cabinet. It decides storage RH more than anything else here | ₪20–40 |
| XPS/PIR sheet, 20–30 mm | Turns a 100 W problem into a 35 W one — see §2 | ₪40–80 |
| **SHT31 or SHT40** | The second climate point. **Not a second AHT20** — see §5 | ₪15–25 |
| 120 mm 12 V PWM fan | Internal circulation. The owned JUMPEAK is the fume extractor's | ₪37 |
| 2× 40 mm 12 V fan | Intake/exhaust, only if the vents are powered | ₪25 |
| 2× SG90 servo **or** printed sliders | The vents must **close** for Store mode, or the room fights the desiccant | ₪20 / ₪0 |
| DS18B20 | Independent over-temperature probe at the heater outlet, for the on-device interlock | ₪6 |
| Reed or micro switch | Door state — logs openings and inhibits heating with the door open | ₪5 |
| Bentonite, 2–4 kg total | Scales with volume and ingress, not only with spool mass | ₪20–40 |
| Mesh trays or sachets | ⛔ Never loose clay in the airstream — it is a fan pointed at a room, and clay carries respirable silica | ₪10 |

⭐ **The desiccant half is no longer part of this build.** It is a bolt-on module with a standard
port, specified in [desiccant-module](desiccant-module.md), so the cabinet provides a Ø62 bore on a
70 mm square of M3 and nothing else. Capacity then scales by adding modules — four to eight
cartridges for a cabinet this size — instead of by designing a desiccant tray into the carcass.
| PC4-M10 bulkhead couplings, one per feeding spool | Dry feeding to the printer — the capability a sealed box cannot have | ₪1.5 ea |
| Cable gland, M12/M16 | The sensor tail through the wall without a leak | ₪5 |

⛔ **Print every part in the heated zone in ASA, not PETG.** Same T₉ argument as the duct in
[drybox-active §ASA](drybox-active.md), and the lab holds 10 kg of PETG to tempt a substitution.

## 5. ⚠️ The I²C trap that would surface at wiring time

**Two AHT20s cannot share a bus.** Their address is fixed at **0x38**, and the ESP32-C3 has one I²C
controller. Two identical parts therefore need a TCA9548A multiplexer or a second node.

Pick unlike parts instead, and the problem disappears: **BME688 at 0x76, SHT31 at 0x44**, and an
AHT20 at 0x38 if a third point is ever wanted.

## 6. Two climate points, not one

A 22 L box is well mixed; a cabinet stratifies. Sensors at the **top and bottom shelves** measure
that directly, and the reading is actionable: a large top-to-bottom split means the air is not being
moved — a finding about the fan, not about the desiccant.

⛔ **Never compare two RH readings taken at different temperatures.** Cooler air at the same
moisture content reads a higher RH. The firmware publishes **dew point** for exactly this reason; it
is the quantity that can be compared across the cabinet, the room and the seasons.

## 7. Code

New file: [`firmware/drybox-cabinet.yaml`](../firmware/drybox-cabinet.yaml). This is **new code
rather than an edit** — every existing config in `firmware/` is sensor-only, and nothing in this
repo has ever switched a load.

What it contains, and why each part is there:

- **Sensors:** SHT31 top, BME688 bottom, DS18B20 at the heater outlet, door contact, plus RSSI and
  uptime. `state_class` on every numeric sensor, without which Home Assistant records states but
  builds no long-term statistics — real, queryable, and on a purge clock.
- **Heater as a template switch** over a PWM output, so every turn-on passes the interlock and a
  three-step soft-start ramp. PWM rather than a relay because a cold PTC's inrush is **thermal** —
  it lasts until the element self-heats, so only current limiting during ramp-up helps.
- **A bang-bang thermostat**, capped at 50 °C in the UI as well as in the safety loop. Not PID: the
  mass is large and slow, the element self-limits, and an untuned PID on a heater is a worse failure
  mode than half a degree of swing.
- **Three scripts** — dry, purge, store — with the ordering the interlock implies: fan on first,
  heater second; heater off first, fans last. The purge ends on a **measured** temperature, with a
  timeout, rather than on a guessed timer.
- **A 5 s safety loop that runs regardless of WiFi, MQTT or HA**, per
  [chamber-sensor §7](chamber-sensor.md). It cuts the heater on a stale reading, a missing or hot
  outlet probe, an over-temperature, or a stopped fan.

⭐ **The fail-safe inverts relative to the chamber.** There, a missing bay reading must mean *fan
on*. Here, a missing reading must mean *heater off*: "no reading" must never read as "not hot".

**None of that replaces the hardware ladder** — KSD9700 in series with the element, a one-shot
thermal fuse above it, and a fused supply. Firmware is the layer that fails first.

### Not in v1, deliberately

**Powered vents.** Store mode needs the vents shut, and in v1 that is a manual slider. Servos are
₪20 and two GPIOs (20 and, if the exhaust fan is dropped, 3), but a vent that fails shut during a
dry cycle traps hot air, so it wants its own interlock and a bench test. Manual first.

## 8. Build order

1. **Bench the owned heater in the actual cabinet**: outlet air and surface temperature, current,
   and the ΔT it holds. This settles §2.
2. **Seal it, then log RH overnight, unheated.** The decay curve gives the ingress rate, which is
   what really sizes the desiccant — spool mass alone does not.
3. Fit the gasket and insulation; re-run step 2 and compare. A seal you have not measured twice is
   an assumption.
4. Wire the safety ladder. **Check the MOSFET module's polarity and fit the pull-down before the
   heater is connected**, so the default state with no firmware running is off.
5. Flash the node, run **open loop** watching the sensors, with the cutout as the only protection.
6. **Prove the interlock fires**: heat the outlet probe by hand and watch the heater cut with HA
   switched off. A safety feature that has never been seen to fire is not one.
7. Only then close the loop and run a real cycle, ending in a purge.
8. Regenerate the bentonite and **weigh it dry** — the recorded mass is the only honest
   done-indicator, since regeneration is a curve rather than a setpoint.

## 9. What is still open

- **The cabinet itself.** Volume, shelf count and door style set the gasket length, the insulation
  area and the fan count. Everything above is written to scale rather than to a specific carcass.
- **Feed-through or storage only.** Bulkhead couplings and roller spindles are cheap, but feeding
  while printing is what makes a cabinet worth building over a box — and it is the one thing
  [drybox-active](drybox-active.md) explicitly cannot do.
- **Whether the 22 L box stays.** Keeping it as the dryer and letting the cabinet be a pure sealed
  store is the lowest-risk split: less power, fewer parts, and the heated volume stays small.
