# Build — the firmware skeleton and the build order (§9, §10)

*Part of the [chamber sensor](../chamber-sensor.md) notes.*

**In short:**

- **The skeleton below is the full three-point node with the fan interlock.** The node actually in
  service is narrower: [`firmware/chamber-c3.yaml`](../../firmware/chamber-c3.yaml), chamber air
  only. The planned full node is `firmware/print-chamber.yaml`, in the print-chamber-box repository.
- **Where the build order stands:** step 1 is done (30 Aug). Step 2 is done in effect: the box
  was nearly closed on 9 Sep and fully closed from 19 Sep, and a short ASA print with it closed
  reached 45–46 °C ([measurements](measurements.md#closed-every-print-since-19-sep-2026)) — a first
  reading toward step 5. Step 3's AHT20 is in service (11 Sep); its two DS18B20s are dropped
  (Alon, 3 Oct 2026) — the room comes from the guest bedroom's climate unit and the bay from the
  Einsy's own thermistor. Step 4, the interlock, therefore has no bay probe to act on, and has not
  started.
- **Build ESPHome from PowerShell, not Git Bash** — and judge a build by the `.bin` it leaves.

## ESPHome skeleton (§9)

Untested — no firmware exists for this node or the fume fan. GPIO numbers match the [pin map](node-design.md#pin-map--esp32-c3-supermini-4); the DS18B20
addresses must be read off the bus on first boot (ESPHome logs them).

```yaml
esphome:
  name: print-chamber
  friendly_name: Print Chamber

esp32:
  board: esp32-c3-devkitm-1
  variant: esp32c3
  framework:
    type: arduino

logger:
  # C3 Super Mini logs over native USB-Serial/JTAG, not a UART bridge.
  hardware_uart: USB_SERIAL_JTAG

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password

mqtt:
  # The name, not a bare IP - Home Assistant's own MQTT integration is
  # configured against this name, so the two agree by construction.
  broker: mqtt.internal.example
  port: 1883
  username: esp
  password: !secret mqtt_esp_password
  topic_prefix: printer
  # Don't hardcode topics elsewhere - ESPHome publishes HA discovery, so drive
  # the resulting entities by name. Same lesson as the fume-fan page.

i2c:
  sda: GPIO5
  scl: GPIO6
  frequency: 100kHz        # down from the rig's 400 kHz for a ~30 cm cable run

one_wire:
  - platform: gpio
    pin: GPIO7             # 4.7k pull-up to 3V3 required

output:
  - platform: ledc
    pin: GPIO10
    id: fan_pwm
    frequency: 25000Hz

fan:
  - platform: speed
    output: fan_pwm
    id: chamber_fan
    name: "Chamber fan"

sensor:
  - platform: aht10
    variant: AHT20
    temperature:
      name: "Chamber temperature"
      id: chamber_temp
    humidity:
      name: "Chamber humidity"
    update_interval: 10s

  - platform: dallas_temp
    address: 0x0000000000000000      # <- read the real address from the boot log
    name: "Electronics bay temperature"
    id: bay_temp
    update_interval: 10s
    on_value_range:
      - above: 50.0
        then: [fan.turn_on: {id: chamber_fan, speed: 100}]
      - below: 45.0
        then: [fan.turn_off: {id: chamber_fan}]

  - platform: dallas_temp
    address: 0x0000000000000000
    name: "Room temperature"
    update_interval: 30s

  - platform: pulse_counter
    pin:
      number: GPIO3
      mode: INPUT_PULLUP
    name: "Chamber fan RPM"
    unit_of_measurement: RPM
    filters:
      - multiply: 0.5      # most 4-pin fans emit 2 pulses per revolution

binary_sensor:
  - platform: template
    name: "Chamber up to temperature"
    lambda: 'return id(chamber_temp).state > 40.0;'

# FAIL-SAFE: no reading must never read as "not hot".
interval:
  - interval: 30s
    then:
      - if:
          condition:
            lambda: 'return isnan(id(bay_temp).state);'
          then:
            - fan.turn_on: {id: chamber_fan, speed: 100}
            - logger.log: "bay sensor unavailable - venting as a precaution"
```

✅ **Settled: ESPHome 2026.8.1 is installed** (via `uv tool install esphome`, 30 Aug 2026), so
the modern spelling above is the right one — `one_wire:` with `platform: dallas_temp`. The old
`dallas:` / `platform: dallas` form was renamed in 2024.6 and now fails with a confusing schema
error rather than a clear one, so do not copy it from an older tutorial.

## Build order (§10)

1. ✅ **RIG WORKING, 30 Aug 2026.** DHT11 on a C3 Super Mini, flashed over COM4, reading
   `chamber 27.1 C  RH 39 %` on the bench — which matches room temperature, so the sensor is
   sane. Board, firmware, sensor and wiring are all proven; what remains is the measurement.
   Two observations worth keeping: it reports in **0.5 °C steps**, better than the DHT11's
   nominal 1 °C resolution, but **the ±2 °C accuracy is unchanged** — do not read meaning into
   small movements. And the `no reading` warning fired correctly while the sensor was miswired,
   which is the fail-safe doing its job: a dead sensor announces itself instead of going quiet.

   **DHT11 on a breadboard, node on USB, no enclosure changes.** Get a number for the chamber as
   it is today, with the side open. This is the baseline everything else is measured against and
   it costs nothing.
   ✅ **Ready to run:** [`firmware/chamber-baseline.yaml`](../../firmware/chamber-baseline.yaml),
   **built and flashable**. Wiring is in its header; DHT11 on GPIO4, chosen so it does not collide with
   the final [pin map](node-design.md#pin-map--esp32-c3-supermini-4). ESPHome 2026.8.1 via `uv tool install esphome`; compiles to 11.4 %
   flash / 16.6 % RAM on a C3, which also settles that `dht` builds under ESP-IDF there.
   ⛔ **Build and flash from PowerShell, not git-bash** — PlatformIO will not install ESP-IDF under
   MSYS (*"MSys/Mingw is not supported"*). **Unsetting `MSYSTEM` is not enough; tried, same
   failure.** `esphome config` passes from either shell, so it surfaces only at compile time.
   ⚠️ **Since 1 Oct 2026 it does not even fail.** Once ESP-IDF is installed, a Git Bash compile
   builds nothing, warns *"Firmware not found"*, then prints *"Successfully compiled program"* and
   exits 0. Judge a build by the `.bin` it leaves, never by that line.
2. **Partially close the open side. Measure again.** If the delta is small, the whole chamber
   theory is weaker than assumed and that is worth knowing before buying anything.
3. **Buy the AHT20 + 2× DS18B20**, build points A/B/C properly, node outside, probes inside.
4. **Wire the interlock and prove it** — heat the bay probe with a hairdryer and watch the fan
   start without HA involved. A safety feature that has never been *seen* to fire is not a safety
   feature.
5. **Only then** close the side fully and run a long ASA print with all three temperatures
   logging to Grafana.
6. **Then** revisit chamber heating — and note the element is **no longer here**. The 12 V 50 W
   PTC was **reallocated to the active drybox on 3 Sep 2026** by Alon's decision, precisely because
   this step is deferred behind steps 1-5 while 10 kg of PETG absorbs humidity now. That build and
   its documents moved to their own repository. Reviving chamber heating therefore starts with
   buying a second element (₪39), which is cheap and was judged better than cannibalising a
   working build.
   The rest of the objection stands regardless: 50 W is modest for a Lack-sized volume, it needs
   **> 4 A at 12 V** which the PD trigger board cannot supply, and it needs a hardware thermal
   cutout. That is a separate power design, not a bolt-on.

Steps 1 and 2 need nothing bought and answer the question that decides whether the rest is worth
doing.
