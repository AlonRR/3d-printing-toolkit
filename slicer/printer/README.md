# Printer presets

One file, and it is the only printer preset this machine has.

## `Original Prusa i3 MK3S & MK3S+ - Copy`

**The "- Copy" suffix is PrusaSlicer's, not a mistake.** When you modify a *system* preset and
save it, PrusaSlicer writes a user preset named `<system name> - Copy`. That is why no user preset
called `Original Prusa i3 MK3S & MK3S+` exists to be a copy *of*: the original is in the vendor
bundle, not in `AppData`.

**Do not rename it here.** The filename is the preset's identity — PrusaSlicer matches by name, and
the repo-vs-live comparison matches by basename. Renaming the master would make it look like a
different preset and hide any future drift.

| | |
|---|---|
| Inherits | `Original Prusa i3 MK3S & MK3S+` (system) |
| Printer model | MK3S, variant 0.4 |
| Nozzle | 0.4 mm |
| Keys | 91 |

**Why it is versioned.** It was unversioned until 23 Sep 2026 and it is the *only* printer preset
present, so a PrusaSlicer reinstall or a new machine would have lost the printer configuration
outright with nothing to restore from. It is stored LF per `.gitattributes`; the live copy is CRLF,
which PrusaSlicer writes and which is not drift — compare with `diff --strip-trailing-cr`, or every
line reads as changed.
