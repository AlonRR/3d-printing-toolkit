// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

// The cover, on its own, for scripts/scad-check.sh. Everything is in print-chamber-box.scad; this only
// picks the part. Assigning `part` after the include replaces it silently - that is the idiom, not a
// mistake (docs/openscad-basics, lesson 3 §7).
include <print-chamber-box.scad>
part = "cover";
