// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: MPL-2.0
// tests/fixtures/box.scad - a 30 x 20 x 2 mm box, sliced to box.gcode by make.sh: the G-code the resume and
// retarget scripts' tests read. Ten layers of 0.2 mm, its front wall at Y 20 where probe_touch.py looks.
cube([30, 20, 2]);
