# WiFi — which network, and the midnight event (§3a)

*Part of the [chamber sensor](../chamber-sensor.md) notes.*

**In short:**

- **The main SSID can never work for an ESP32:** it uses WPA3 with GCMP-256, which ESP32 silicon does
  not have. **Use the IoT SSID, which works since it was set to WPA2-only (31 Aug 2026).**
- **Address nodes by name, not IP, and never trust ping** for these links.
- **The midnight event:** at 00:00 UTC (03:00 local) every night, the node is bounced between two
  2.4 GHz BSSIDs for a few minutes. The network itself stays up; it is the access point side —
  likely the mesh's nightly re-optimisation.
- Since the reconnect fix it costs a reconnection, not a multi-day outage.
- **The free test is the night of 25 October 2026**, when Israel leaves DST: if the event moves to
  01:00 UTC, it is scheduled in local time.

## Which WiFi network (§3a)

Two facts about this house's networks decide where the node can live, and neither
is discoverable from the ESP32's error messages.

### The main SSID is permanently impossible for this hardware

It runs **WPA3-Personal with GCMP-256**. ESP32 radios implement **CCMP only** —
GCMP is not a setting being refused, it is a cipher the silicon does not have. The
node reports `Authentication Failed` and `Handshake Failed`, which look exactly
like a wrong password and are not.

Ruled the password out properly rather than by assertion: Windows had a stored
profile for that SSID, and its key matched `secrets.yaml` byte for byte, case
sensitive. Same length, identical string, still refused. **Do not spend time
retyping the password for this network** — no ESP32 will ever join it.

### The IoT SSID works, but only since it was set to WPA2-only

It was **WPA/WPA2 mixed**, offering TKIP alongside AES. That was the root cause of
an evening of the node working for ~17 minutes, then being refused by every radio
for ~17 minutes, then recovering on its own with nothing changed at either end.
Mixed mode lets a client end up on deprecated TKIP, and the resulting failures are
intermittent, per-AP, self-clearing and completely unaffected by signal strength —
which is what made them look like a temporary client ban.

**Alon set that SSID to WPA2-only on 31 Aug 2026 and the node then associated
first time, with no scan-and-fail across the three mesh radios.**

Diagnoses tried and discarded before that, all wrong, listed so nobody repeats
them: dead power supply, a wedged TCP stack, a mesh rate-limiting the client, and
WPA2/WPA3 transition mode. The right *class* of answer — cipher negotiation on a
mixed-mode SSID — arrived last, and the fix was one router setting rather than
anything in this repo. `fast_connect: true` was also tried and **made it strictly
worse**: it skips the scan, so the node only ever retries the remembered AP and
never falls back when that one is the one refusing.

### Two habits that follow from this

- **Address the node by `chamber-baseline.local`, not by IP.** It came back from
  the WPA2 change on a new DHCP lease — `.100` instead of `.103` — and every port
  check against the old address failed while the node was perfectly healthy. The
  logger takes a hostname for this reason.
- **Never trust ping here.** During these failures ICMP answered while all three
  TCP ports refused, and later ICMP failed while all three were open. The serial
  log and a TCP port check are the only signals worth acting on.

## The midnight event

*The investigation, in the order it happened. Its instrument was the S3 node's disconnect counter and association log; that counter has [its own page](s3-disconnect-counter.md).*

### The two multi-day gaps were the WiFi give-up bug, and stopped when it was fixed

Homelab found two holes in the node's series and the pattern that identifies them:

| Gap | Started | Ended |
|---|---|---|
| 16.7 h | **3 Sep 00:00:27Z** | 3 Sep 16:40Z |
| **53.9 h** | **4 Sep 00:00:29Z** | 6 Sep 05:54Z |

**Both start within two seconds of midnight UTC**, on consecutive nights — a schedule, not a roam.
And it was not a recorder outage: the bucket took 1,765–9,339 points per 6 h throughout, so HA and
InfluxDB were up and only this node was absent.

**The duration was `wifi.c`'s give-up bug**, and the dates line up exactly:

- The handler stopped calling `esp_wifi_connect()` after 8 consecutive disconnects, permanently.
- The 53.9 h gap **ends 6 Sep 05:54** — when the node was power-cycled by hand, the only recovery
  that bug left.
- The fix landed **6 Sep 12:22** (`43607f7`).
- Since then the node's longest unbroken stretch runs **7 Sep 17:00Z → 9 Sep 07:00Z**, which
  **contains two midnights**, and it is up now.

**So the trigger is still unexplained but is no longer consequential.** Something at midnight UTC
disturbs this link — a scheduled AP event, a lease renewal, a channel re-selection — and before the
fix that burst exhausted an 8-retry budget and stranded the node for days. It now costs a
reconnection. ⚠️ **Worth chasing as "why does the link blip at midnight", not as "why does the node
vanish".**

📋 **And it bounds what this node's own history can support.** Availability and channel count are
different things: the probes hang off the same board and the same uplink, so *"a DS18B20 goes into
HA automatically"* is true only while the node is up — and it demonstrably was not for 54 of the
140 hours before the fix.

### Caught directly, two nights running — 10 Sep 2026

The section above could only infer the midnight trigger from *gaps*, because the give-up bug turned
every burst into a multi-day outage. With the reconnect fix in and the disconnect counter
published, the event is now visible **directly**, as a counter burst:

| Local time | `wifi_drops` | |
|---|---|---|
| 09-09 03:03:40 | 17 | night 1 — burst, then a reboot resets it |
| 09-09 03:04:06 | 15 | |
| 09-09 15:49:04 | **0** | the `state_class` reflash |
| **10-09 03:00:30** | **1** | ← **night 2 begins, 00:00:30 UTC** |
| 10-09 03:03:06 | 15 | |
| 10-09 03:03:54 | 16 | |
| **10-09 03:04:08** | **18** | ← **ends. ~14 reconnects in 3 m 38 s** |

**So it is confirmed, recurring, and self-healing.** 03:00–03:04 local is **00:00–00:04 UTC**, the
same two-second-of-midnight signature as the 3 and 4 Sep gaps. The node rides it out and is up
now — which is exactly what the reconnect fix was for.

✅ **This narrows the trigger usefully.** It is not a roam and not a chamber-thermal effect: it is
a scheduled event at midnight UTC. ⭐ **It has since been narrowed much further — to the access
point itself. See the next section.** Nothing on this node can fix it; the node's job is only to
survive it, and it does.

### It is the access point, not the network

Homelab ran the other half of the correlation from a **wired** host at 5-minute resolution, across
both midnight windows:

| Target | 00:00Z | 00:05Z | 00:10Z | 00:15Z |
|---|---|---|---|---|
| Gateway | 0 % / 0.70 ms | 0 % / 0.77 ms | 0 % / 0.68 ms | 0 % / 0.83 ms |
| Two public resolvers | 0 % loss | 0 % loss | 0 % loss | 0 % loss |

**The router never stops answering and never slows down.** So the event is not a router reboot, not
a routing or uplink outage, and not congestion. A sweep of the lab found no scheduled task — no
timers, no cron entries — firing at that moment on any host or container.

⚠️ **Stated rather than buried: a wired host cannot observe a WiFi deauthentication.** That
evidence rules out the network; it cannot say what the radio did. For that, the only witness is
this node.

**And this node's own association log is the positive evidence.** It has ever associated with
exactly **two BSSIDs of the same SSID, differing in the final octet alone**, and at the event it
gets bounced between them:

| Night | Association changes in the 02:50–03:20 window |
|---|---|
| 8 Sep | settles on the second BSSID at 03:04:15 |
| 9 Sep | one change, 03:03:40 |
| 10 Sep | three changes — 03:00:27, 03:00:30, 03:03:06 |

So the node is being **re-associated at the moment of the burst**, while routing stays perfect.
That is an access point re-initialising or re-steering, not a network fault.

### Band-steering is impossible — settled by the silicon

I recorded band-steering as "probably right but not proven". **It is not right at all, and the part
number settles it without anyone reading the AP's configuration.**

`sdkconfig` says `CONFIG_IDF_TARGET_ESP32S3=y`. **The ESP32-S3 is 802.11 b/g/n — 2.4 GHz only.
There is no 5 GHz PHY on the die.** A client that cannot receive 5 GHz cannot be steered onto it,
so **both BSSIDs are necessarily 2.4 GHz** and "bouncing between the 2.4 and 5 GHz radios" is
excluded by hardware.

📏 **The RSSI hint was pointing the right way.** A few dB between the two associations is
exactly what two 2.4 GHz BSSIDs look like — which is why the small difference felt wrong for a band
change. The instinct was sound; the silicon is the proof.

### "One physical AP" is withdrawn too — address adjacency proves nothing

The other half of the inference was that five identical octets meant two radios in one box. That
does not hold either:

- The uplink is a **consumer mesh system**, so two 2.4 GHz BSSIDs are as easily **two separate
  units** as two virtual APs on one unit.
- The BSSIDs have the **locally-administered bit set** — they are derived/virtual addresses. Once
  an address is synthesised, **numerical adjacency says nothing about physical identity.**

**So the honest position is: two 2.4 GHz BSSIDs from one vendor allocation, physical topology
undetermined.** Which lands back where the 9 Sep analysis started — **these are roams** — and makes
a **mesh-wide re-optimisation at 03:00 local** the natural candidate, since consumer mesh systems
ship exactly such a scheduled job. That fits every observation and leaves the 25 October test
exactly as decisive.

⭐ **The general lesson, and it caught two sessions in two days:** a plausible mechanism built from
a structural pattern is not evidence. Both "seven flips" and "one physical AP" came from reading
structure — row counts, address adjacency — as if it were observation. **The datasheet was one
lookup away the whole time.**

### The −72 dBm figure, checked against its series

The RSSI series was added so the enclosure's weak spot would stop being a single bench observation.
At **44,378 samples** it can now answer that:

| | |
|---|---|
| Mean | **−56.1 dBm** |
| Max | −46.0 dBm |
| Min | −74.0 dBm |
| At or below −70 dBm | **30 samples — 0.07 %** |

**−72 dBm is real; the enclosure reaches it and worse.** But it is the **extreme tail, not the
level.** Typical is −56, and the box sits below −70 about seven hundredths of one percent of the
time.

⚠️ **Caveat that limits this:** the series begins 7 Sep 12:12Z, so there is **no RSSI data for
4 Sep** and the original spot reading cannot be checked — only the enclosure's general level since.
The 4 Sep observation is not being called wrong.

### The free test: 25 October 2026, when Israel leaves DST

00:00 UTC is **03:00 Israel local**, the classic hour for a consumer AP's nightly maintenance or
channel re-selection. **Israel leaves DST on 25 Oct 2026**, which separates the two hypotheses
cleanly at zero cost:

| What happens that night | What it means |
|---|---|
| The event moves to **01:00 UTC** | The AP schedules in **local** time — a nightly maintenance job |
| The event stays at **00:00 UTC** | It is genuinely **UTC**-scheduled, and the local-time theory is wrong |

📋 **Whoever looks at this in November: that shift is the experiment, not a glitch.** Read the
disconnect counter and the association log for the nights either side of 25 October.

### The C3-MINI-1's signal is 24 dB better — 11 Sep 2026

| | min | max | mean | n |
|---|---|---|---|---|
| **C3-MINI-1, in the chamber** | −46 | −28 | **−32.9** | 22 |
| S3, same enclosure, full history | −75 | −46 | −56.5 | 61,278 |

**The C3's WORST reading so far equals the S3's BEST EVER**, and its mean is ~24 dB better. The
MINI-1 module has a proper shielded antenna where the S3 board did not, and that difference shows
up through the same enclosure wall.

📋 **This bears directly on [which WiFi network](#which-wifi-network-3a)
and the midnight-event work.** A long-running theory was that the enclosure was marginal for
signal. It was marginal *for that board*. Whether the nightly re-association follows the node or
stays with the AP is now a cleanly testable question, because the link budget changed by 24 dB and
the event did not depend on it.
