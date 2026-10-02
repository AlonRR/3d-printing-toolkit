# The S3's disconnect counter — and reading a counter out of flash (§11)

*Part of the [chamber sensor](../chamber-sensor.md) notes.*

**In short:**

- **The S3's per-boot disconnect counter, declared `total_increasing`, made Home Assistant
  overstate the total** — 50 against the node's 18 — because every reboot looked like a rollover.
- **The fix persisted the counter in NVS.** It was flashed on 10 Sep 2026 and **proven on 12 Sep**,
  against a prediction written down first.
- **The sum was corrected to 18**, and the series is closed: the C3 that replaced the S3 publishes
  no such counter.
- **The method generalises:** a value that exists only in NVS is read from flash in download mode,
  and its *write history*, not just its value, settles whether persistence works. The dump holds
  the WiFi password, so filter it and delete it.
- **Never gate diagnostic publishing on a sensor read.**

## The problem: the node says 18, Home Assistant says 50

Measured 10 Sep 2026, and this is the concrete cost of the `total_increasing` contradiction that
[`f276ff1`](../../firmware/prusa-cam-c/main/wifi.c) fixes:

| Source | Value |
|---|---|
| The node's own counter | **18** |
| HA long-term statistics `sum` | **50** |

**A 178 % overstatement, from exactly two decreases.** `17 → 15` on night 1, and `15 → 0` when the
`state_class` reflash rebooted the board. HA reads any decrease in a `total_increasing` series as a
counter rollover and **adds** the new value to the running sum, so each reboot donated its whole
count a second time. The hourly rows show the jump cleanly: `sum` sat at 32 while the state read 0,
then became 50 the moment the state reached 18.

⚠️ **Nothing here is a measurement error.** Every individual value the node published was
correct. The **declared semantics** were wrong, and a per-boot counter cannot be summed across
reboots without knowing which decreases are reboots — which is why two separate attempts to
reconstruct a lifetime figure by hand both produced numbers the data does not support.

📋 **The fix stops future corruption; it does not repair the past.** The inflated sum stays
inflated, and the flash itself will cause **one final reset** (18 → 0), because the old firmware
never wrote NVS so there is nothing for the new one to load. That is a one-time, understood cost.
Correcting the historical sum is a Home Assistant operation (Developer Tools → Statistics →
*Adjust sum*), so it belongs to homelab, not to this firmware.

## The fix, flashed — 10 Sep 2026, 13:29:46Z

`f276ff1` is running. It had been built and committed but not deployed for a day, while the
per-boot counter carried on inflating the statistics above.

| | |
|---|---|
| Partition | `ota_0` → **`ota_1`** |
| `app_elf_sha256` | **`ca8176f8b61bd346`** |
| Version string | `007e706-dirty` — the tree the image was built from |
| Reply | **`HTTP 200 "ok, rebooting"`** |

⭐ **That clean 200 is itself a result.** Every previous OTA looked like a failure: the board
logged `update accepted` while the client got a connection reset, because the reboot outran the
reply. The `Connection: close` + `httpd_sess_trigger_close()` change in `ota.c` fixed it, and this
is the first flash that reported honestly. **The old rule — "a reset on POST is success" — is
retired; a non-200 now means something.**

### `app_elf_sha256` is the ELF's hash, not the .bin's

Two sessions checked the artifact and briefly disagreed, because they hashed different things:

| What was measured | Value |
|---|---|
| The `app_elf_sha256` **field**, at offset **0xB0 inside the .bin** | `ca8176f8b61bd346` |
| `sha256` of **`prusa_cam_c.elf`** | `ca8176f8b61bd346` ✅ same |
| `sha256` of **`prusa_cam_c.bin`** | `47813091ebfdf869` — a different, correct, irrelevant number |

**The field is the ELF's hash, embedded in the app descriptor.** Hashing the `.bin` answers a
question nobody asked. Getting this backwards produces a discrepancy that looks like a corrupted
artifact and is not one — and the two readings agreeing is *stronger* evidence than either alone,
because they are independent paths to the same value.

### Verified by behaviour, not by the upload returning

The POST's return value is not evidence — that is the whole lesson of the reset-as-success era.
What was actually checked:

- **Read-back**: partition flipped and the running sha matches the built image.
- **Publishing resumed** within seconds — temp 39.0 °C, RSSI −55.
- ⭐ **The new `uptime` entity exists and is counting** (26 → 30 → 33 s). This is the one that
  matters: it proves the **new discovery ran**, not merely that a new image booted. A sha proves
  what is in flash; a new entity proves the new code is doing its job.

### The one-time reset happened as predicted: 18 → 0

At 13:29:46Z the counter went from 18 to 0. **Expected and unavoidable**: the old firmware never
wrote NVS, so the new one had nothing to load. Once only.

📋 **It makes the Home Assistant correction easier, not harder.** A `total_increasing`
rollover adds the *new* value, which was 0, so the inflated sum stays at 50 and from here
`sum = 50 + (node counter)`. The offset is now a **constant +50** against a counter that starts at
zero and is meant to persist — where before it was +32 against a counter that reset unpredictably,
with no stable target to correct to.

✅ **The sum was corrected on 11 Sep, and persistence was proven on 12 Sep.** This note used to
say "do not correct the sum yet" because `drops_save()` might not fire. It does: the counter survived
a reboot with its history intact (see [reading it out of flash](#reading-a-persisted-counter-out-of-flash--the-method-11)). The −50 adjustment was applied to the final hour,
taking the terminal sum from 68 to 18.

## Proven, 12 Sep 2026 — against a prediction made first

**Deployment is not vindication**, so this section originally set out the test rather than claiming
success. It is kept in full because the prediction was made *before* the evidence existed:

1. ~03:00 local should drive the count to roughly **14–18**.
2. `drops_save()` should fire on the reconnect that ends the burst.
3. **The next reboot after that should come back non-zero instead of at 0.**

**All three held.** The count reached **18**. The NVS write history shows four saves, one per outage
episode, exactly as `drops_save()` is designed to do: `0 → 1 → 17 → 18`. And after the reboot the
counter continued from 18 rather than restarting — proven by what is *absent*, since a failed load
would have written a low value and erased the 18, and none exists.

⭐ **Step 3 was the only one that could prove the fix, and it nearly went unanswered.** The board was
reassigned to another project while the question was still open; the answer existed only in flash
that a reflash would have destroyed. Evidence and full reasoning: [reading it out of flash](#reading-a-persisted-counter-out-of-flash--the-method-11).

### The `state_class` fix, verified in the field

All four chamber series now build long-term statistics, where three of them had **zero**:

| Series | Long-term rows |
|---|---|
| `chamber_temperature` | 21 |
| `chamber_humidity` | 21 |
| `chamber_wifi_rssi` | 21 |
| `chamber_wifi_disconnects` | 69 *(it always had `state_class`)* |

The three at 21 are counting from the flash; the history *before* it was recorded as states only
and is on the purge clock. **The data was never missing — it was perishable**, and that distinction
is the whole reason this was worth fixing.

## The sum corrected, and the series closed

`recorder/adjust_sum_statistics`, −50 at the final hour: terminal sum **68 → 18**, matching the
node's own counter.

⚠️ **Earlier rows still read 68, and that is not an oversight.** The inflation accrued over days
from a real semantic bug, and there is **no recoverable true lifetime total** — a per-boot counter
cannot be summed across reboots without knowing which decreases were reboots, which is the whole
reason the bug mattered. The final value is now the one number that *is* knowable. The step from 68
to 18 in the last row is the correction itself, not another reset.

## Reading a persisted counter out of flash — the method (§11)

Kept because the method generalises: a counter that only exists in NVS cannot be verified from the
running firmware, and the obvious checks report success without proving anything. This is how
`drops = 18` was actually established on the S3 before that board was reflashed and released.

**A deployment is not a verification**, and the gap between the two was eight days and one read.

**It can only be read from flash, not from the running firmware.** No HTTP route exposes it, MQTT
publishes it only on a good DHT read, and — contrary to what an earlier version of this repo said —
it is **never printed to the serial console**: the disconnect warnings print a per-episode retry
count that resets on every connect, not the lifetime value. The answer is in the NVS partition
(namespace `wifinet`, key `drops`), read with `esptool read-flash` and parsed with ESP-IDF's
`nvs_tool.py`.

⛔ **Download mode, not a reboot.** The ROM bootloader never runs the app, so NVS is untouched.
Rebooting into the app can change the value — boot-time association failures increment it and the
next IP acquisition saves it. So no serial terminal, no monitor, no power cycle before the read.

⛔ **The dump is a credential.** ESP-IDF persists the WiFi station config to NVS by default, so the
same partition holds the network name and password in plaintext. Filter the parser output to
`wifinet`, never commit the dump, delete it after.

⭐ **Read the WRITE HISTORY, not just the value.** NVS never overwrites in place: each save appends
a new entry and marks the old one `Erased`, and erased entries survive until their page is
reclaimed. This firmware writes far too few entries to fill a page. The history settles the
verdict *regardless of when the read happens*. That matters because the nightly midnight event
causes about 18 disconnects, so a counter that restarted from 0 could climb back to 18 in one
night and pass a value-only check.

The code narrows the failure modes: `nvs_flash_init()` runs before `drops_load()`, both use the
same namespace and key, and `drops_save()` runs on every IP acquisition. The board was on WiFi
after the reboot, so that boot reached one.

| `drops` history (written and erased entries, in order) | Verdict |
|---|---|
| never falls below 18 once it reaches 18 | **persistence works — the fix is proven** |
| a value below 18 appears **after** an 18 | **reading back failed** — a boot restarted from 0 and its reconnect overwrote the saved count |
| no `drops` entries at all | the save never committed |
| only `0` entries | saves work, but the 11 Sep `18` was never written |

⚠️ **`0` is not "never saved".** An earlier version of this table said it was. If reading back
fails, the first reconnect overwrites the saved 18 with a fresh 0. So a current value of 0 is the
fingerprint of a failed load, and only a missing key means the save never worked.

📐 **Why a history exists at all — verified in ESP-IDF 5.5.5 source, not assumed.**
`Page::eraseEntryAndSpan()` only flips the entry-state bits via `alterEntryState()`; it never
overwrites the entry payload, so a superseded value stays physically present and parses as
`Erased`. The history is destroyed only when a page is reclaimed, and
`PageManager::requestNewPage()` reclaims one only when **fewer than two free pages remain in the
whole partition**, then takes the page with the most unused entries. That is whole-partition
space pressure, not "a page filled up".

⚠️ **Correcting an earlier claim in this section.** It said the firmware "writes far too few
entries to fill a page". That ignored the WiFi stack, which writes NVS itself:
`CONFIG_ESP_WIFI_NVS_ENABLED` is on and the firmware calls `esp_wifi_set_config()` on every boot,
so the `sta.*` entries are the stack's, not ours. The conclusion survives for a better reason —
the two-free-pages bar across six pages — but the reasoning was wrong, and it is now checkable
rather than assumed.

✅ **Check it rather than trusting it.** `-d storage_info` prints only counts — Written, Erased,
Empty and Invalid per page, plus page size and total pages. No keys, no values, so it is the one
mode safe to run unfiltered:

```powershell
python $nt -d storage_info --color never s3_nvs.bin
```

Counts-only output confirmed **both** by reading `storage_stats()` and by another session running
it on generated fixtures: no key names, no values, not even the string `drops`.

The partition is `0x6000`, so **6 pages**; at a 4096-byte page and 32-byte entries each page has
**126** slots once its header and entry-state bitmap are taken out, so the partition holds 756.

⛔ **Do not expect the counts to add up to 756 — a healthy dump totals LESS.** A value longer than
32 bytes occupies a header slot plus continuation slots, and the tool counts the value as **one**
`Written` entry while placing its continuation slots in **no bucket at all**. The real partition
stores the WiFi credentials as strings and blobs, so its reported total *will* come in *well* under 756,
and that is normal.

**The general rule, measured:** hidden slots are the sum of `(span - 1)` over all entries, for
**any** multi-entry value — blobs as well as strings. Decomposition of a fixture holding a
realistic WiFi station record, which came up exactly 9 short:

| Entry | Type | Span | Hides |
|---|---|---|---|
| `sta.ssid` | string | 2 | 1 |
| `sta.apinfo` | blob | **6** | **5** |
| `sta.pmk` | blob | 2 | 1 |
| `sta.apsw` | blob | 2 | 1 |
| `sta.pswd` | string | 2 | 1 |
| | | | **9** |

Control from the same fixtures: single-slot values hide nothing — one namespace and two
namespaces both reported exactly 756 — so only payload spanning multiple slots is invisible.
Because the real partition carries `sta.apinfo` with a large span plus the other blobs, expect its
total to fall **well** short. **Do not anchor on any number.**

⚠️ **An earlier version of this section said to expect 756**, which would have made a healthy dump
look anomalous. **The total is not a signal.** `Empty` and `Invalid` are. How to read the counts:

| Reading | Meaning |
|---|---|
| `Erased` **> 0** | ✅ the good case — superseded values are still present, so the history is readable |
| `Erased` = 0 | `drops` has only ever been written **once** — itself informative, and not in a good way |
| `Empty` near zero on every page | ⚠️ a reclaim may have run; the history may be partial, so fall back to the current value |
| `Invalid` **> 0** | ⛔ **STOP.** Invalid means entries whose CRC does not match — corruption. Withhold the verdict rather than record one |

⛔ **`Invalid` is a fourth outcome the rule did not have.** "Works", "failed" and "inconclusive"
all assume the dump is trustworthy. If the CRCs do not check out, none of them applies and the
right answer is to record nothing.

⛔ **The one case that yields a WRONG verdict rather than an unclear one:** a reclaim has run,
only a single `Written` `drops` entry survives, reading back had failed, and the counter climbed
back to 18 or more through midnight bursts. A value-only read then says "works" and is wrong.
`storage_info` is what flags that situation; in every other case the failure is inconclusive
rather than wrong, which is the right way round.

**Verified commands, PowerShell** (not Git Bash, which rewrites `findstr`'s `/B` into a path):

```powershell
esptool --port COM9 --before default-reset --after no-reset read-flash 0x9000 0x6000 s3_nvs.bin
$nt = "$env:LOCALAPPDATA\esphome\Cache\idf\frameworks\5.5.5\components\nvs_flash\nvs_partition_tool\nvs_tool.py"
# current value - prints only drops, or a loud not-found listing namespace NAMES
$j = python $nt -d minimal -f json s3_nvs.bin | ConvertFrom-Json
$hit = $j | Where-Object { $_.namespace -eq 'wifinet' -and $_.key -eq 'drops' }
if ($hit) { "wifinet:drops = $($hit.data)" } else { "NOT FOUND: wifinet:drops absent. Namespaces present: " + (($j | Select-Object -ExpandProperty namespace -Unique) -join ', ') }
# write history - every drops entry, written and erased
$all = python $nt -d all --color never s3_nvs.bin
$h = $all | Select-String -SimpleMatch '| drops:'
if ($h) { $h | ForEach-Object { $_.Line.Trim() } } else { "(no drops entries in -d all)" }
Remove-Item s3_nvs.bin
```

⛔ **Never run `-d minimal` or `-d all` unfiltered.** `minimal` prints the WiFi password as
`key = value`. `all` prints it as a readable ASCII hex dump on a line that does not contain the key
name, so filtering on the key would not even catch it.

📋 **The first filter handed out for this was broken, and silently.** It was
`findstr /B "wifinet:"`, but every `minimal` line begins with a space, so it matched nothing, and
the empty output would have been recorded as "key absent". It was caught only by building a fake
partition (fake password, `drops=18`) and running the exact command on it. Both commands above
passed that test, including a missing-key run that failed loudly. **An untested filter on a
one-time read is a guess with a deadline.**

**A deployment is still not a verification** — and a closure is only as good as the premise it
rests on.

It became unanswerable remotely for a reason worth carrying elsewhere: `main.c`'s `log_dht()`
publishes the **entire** MQTT payload — counter, uptime and BSSID — only on a **good DHT read**.
Removing the sensor took the diagnostics with it. **Never gate diagnostic publishing on a sensor
read**: a failed probe is exactly when you want the device to still be talking.
