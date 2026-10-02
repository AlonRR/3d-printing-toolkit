// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

// The back plate, on its own, for scripts/scad-check.sh. Everything is in print-chamber-box.scad; this
// only pins the part. It exists because `part` in the params file is also the line you change to VIEW
// a part, and scad-check.sh takes no -D: checked through print-chamber-box.scad, the "back plate" check
// silently checked whatever part was on screen. Through this file it cannot.
include <print-chamber-box.scad>
part = "back";
