// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
PETG temperature tower — one band per nozzle temperature, stacked, each labelled and each carrying the same three features that fail visibly.

WHY THIS EXISTS. The unbranded PETG (SKU NPETG087-ZX) has NO data sheet. The spool label gives "230-260 C" and nothing else: no density, no drying schedule, no mechanical data. Every other filament profile in this repo is transcribed from a vendor TDS; this one cannot be. A 30 C band is far too wide to pick a number out of, so the number has to be measured, and this is the thing that measures it.

WHAT MAKES IT A TEST RATHER THAN A SHAPE. Every band is geometrically IDENTICAL. The only variable between them is the temperature the slicer is running at, which is the whole experimental design — vary one thing. The three features are chosen because each fails in a different direction:

  SHELF   a 90 degree unsupported overhang. Droops when too hot. Deliberately 90 degrees rather than a gentle 45, because a 45 degree overhang prints acceptably across the whole range and would show nothing.
  BRIDGE  the ceiling of a horizontal through-hole, spanning the full depth. Sags when too hot or under-cooled.
  FIN     a thin vertical blade. Strings and blobs when too hot; comes out furry or incomplete when too cold.

Cold failures and hot failures therefore look DIFFERENT, which is what lets a single print pick a number rather than just ranking bands.

ORIENTATION. Authored and printed with band 0 (the coolest) on the bed and the temperature rising with Z. That order is deliberate: PETG adheres better hot, so starting cool puts the least-adhesive band on the bed where failure is most obvious and least messy. It also means a tower that detaches has failed at its coldest, which is the useful direction.

THE SLICER CHANGES THE TEMPERATURE, NOT THE MODEL. Add an M104 at each band boundary via PrusaSlicer's layer slider. The exact Z heights and layer numbers are echoed at the end of a render - read them off rather than counting.
*/

include <petg-temp-tower.params.scad>

/*
DERIVED — computed, never set by hand.
*/
n_bands     = len(temps);
total_h     = n_bands * band_h;
band_layers = band_h / fdm_layer_h;

/*
GUARDS. These block rather than warn, because each one silently destroys the experiment rather than merely degrading it.
*/
assert(n_bands >= 2, "temps needs at least two entries or there is nothing to compare");

/* A band that is not a whole number of layers puts the temperature change mid-band, so the boundary you read on the print is not the boundary the temperature actually changed at. */
assert(abs(band_layers - round(band_layers)) < 1e-6,
       str("band_h (", band_h, ") must be a whole number of layers of fdm_layer_h (",
           fdm_layer_h, "); it is ", band_layers));

/* Below one extrusion width the fin is not a thin feature, it is an absent one. */
assert(fin_w >= fdm_extrusion_w,
       str("fin_w (", fin_w, ") is under one extrusion width (", fdm_extrusion_w,
           ") and will not print"));

/* The shelf and the bridge sit on DIFFERENT faces - shelf on the back, bridge spanning the valley - so they need no vertical separation from each other. Each only has to fit inside its own band, and each has to be far enough above the band boundary to have settled. */
assert(bridge_z * band_h + bridge_t < band_h,
       str("bridge at ", bridge_z, " of a ", band_h, " mm band, plus ", bridge_t,
           " mm thickness, runs into the band above - it would join two temperatures and be unreadable"));

/* M104 does not wait: the first layers of a band still extrude plastic melted
 * at the PREVIOUS temperature, so anything printed there is a blend of two. */
assert(bridge_z * band_h >= 4 * fdm_layer_h,
       "bridge sits too close to the bottom of its band to have settled");

/* The base is the thing that makes this one part; a fractional layer would
 * leave the join to a slicer rounding decision. */
assert(abs(base_t / fdm_layer_h - round(base_t / fdm_layer_h)) < 1e-6,
       str("base_t (", base_t, ") must be a whole number of layers"));

/* The engraving must not cut through the base, or the label becomes a hole and
 * the first layer loses the area that holds the towers down. */
assert(label_depth < base_t - fdm_layer_h,
       str("label_depth (", label_depth, ") leaves under one layer beneath it in a ",
           base_t, " mm base"));
assert(shelf_z * band_h + shelf_t < band_h,
       "shelf runs past the top of its band and would fuse into the band above");

/* Feature x-positions, kept apart so the fin does not sit over the bridge's exit hole. */
bridge_x = body_w * 0.35;
fin_x    = body_w * 0.80;

/*
The body is ONE solid spanning every band, with per-band features added to it and the bridges subtracted from it.

Every feature is buried `weld` deep INTO the body for the same reason the bands are one cube: geometry that merely TOUCHES a face is not fused. Both mistakes were made here first - a stack of touching cubes, then features sitting exactly on the body's faces - and each produced a render of 14 separate volumes that still sliced and still looked right. scripts/scad-check.sh blocks a multi-part STL, correctly: "several solids that happen to touch" and "one solid" behave differently the moment anything moves.
*/
module features(i) {
    base = i * band_h;

    /* Shelf: sticks out into open air with nothing beneath it. On the BACK
     * face, not the sides - the sides face the valley, and anything protruding
     * there shortens the travel move the pair exists to create. */
    translate([0, body_d - weld, base + shelf_z * band_h])
        cube([body_w, shelf_len + weld, shelf_t]);

    /* Fin: a thin blade, also on the back, beside the shelf. */
    translate([fin_x - fin_w / 2, body_d - weld, base + band_h * 0.15])
        cube([fin_w, fin_len + weld, band_h * 0.6]);

    /* Label, embossed OUTWARD on the front face. Engraved text at this size
     * fills in and becomes unreadable, defeating the point of labelling.
     *
     * THE Y START MATTERS. rotate([90,0,0]) maps local +Z onto global -Y, so
     * the extrusion runs AWAY from the body. Starting at -text_depth therefore
     * left every glyph floating in mid-air in front of the plate - the render
     * still reported "Simple: yes", because disjoint components are perfectly
     * valid geometry, and the volume count was the only thing that gave it
     * away. Starting at +weld and extruding text_depth + weld spans
     * -text_depth .. +weld, which buries the glyphs in the face. */
    translate([body_w / 2, weld, base + band_h * 0.68])
        rotate([90, 0, 0])
            linear_extrude(text_depth + weld)
                text(str(temps[i]), size = text_size, halign = "center",
                     valign = "center", $fn = 32);
}

/*
The bridge SPANS the valley between the two towers, rather than being a hole
through one of them.

The earlier version drilled a horizontal hole through each tower body and called
its ceiling a bridge. That is a weak test: the span is only body_d across and it
is surrounded by solid material that carries the heat away. A genuine bridge is
unsupported air on both sides for the full width of the gap, which is what
actually sags when the nozzle is too hot.

This is also what the established all-in-one temperature-and-bridging towers do,
and the reason they are built as two columns rather than one.
*/
module bridge_span(i) {
    base = i * band_h;
    translate([body_w - weld, (body_d - bridge_w) / 2,
               base + bridge_z * band_h])
        cube([gap_clear + 2 * weld, bridge_w, bridge_t]);
}

module tower() {
    cube([body_w, body_d, total_h]);
    for (i = [0 : n_bands - 1]) features(i);
}

/* With the shelves moved to the back, the towers are plain body_w blocks and
 * the clear gap really is tower_gap. */
gap_clear = tower_gap;
span_x    = twin ? 2 * body_w + tower_gap : body_w;

/* The base plate, joining both towers into a single solid, with the filament's
 * identity engraved into its top face in the gap between the towers. */



/* The second tower is MIRRORED, not copied, so its shelf and fin face outward
 * too. A plain copy would put the second tower's shelf into the gap, shortening
 * the travel that this pair exists to create. */

tower();

/* A plain copy, not a mirror. Every protruding feature now lives on the BACK
 * face, so both towers are identical and the valley between them stays empty
 * apart from the bridges. Mirroring was the earlier approach and it pointed
 * BOTH shelves inward, cutting the 40 mm travel gap to 33. */
if (twin) translate([body_w + tower_gap, 0, 0]) tower();

/* The bridges, spanning the gap and tying the two towers into one part. */
if (twin) for (i = [0 : n_bands - 1]) bridge_span(i);

/*
The base plate, spanning both towers, with the filament's identity engraved into
its top face in the valley between them.

This block was silently DELETED once already, by a cleanup regex that matched
"if (twin)" followed by indented lines while removing the old tower placement.
Nothing complained: the bridges alone tie the towers into one solid, so the
model still rendered as a single part and still passed scad-check. The loss was
only visible in the G-code preview, where the plate and the engraving simply
were not there. A part count is not a substitute for looking.
*/
if (twin)
    difference() {
        cube([span_x, body_d, base_t]);

        /* Recessed from the TOP face downward, so the cut opens upward and
         * needs no support. Sat in the valley, where it takes nothing away from
         * either tower's footprint. */
        translate([span_x / 2, body_d / 2, base_t - label_depth])
            linear_extrude(label_depth + 1) {
                translate([0, label_size * 0.62, 0])
                    text(label_line1, size = label_size, halign = "center",
                         valign = "center", $fn = 32);
                translate([0, -label_size * 0.62, 0])
                    text(label_line2, size = label_size, halign = "center",
                         valign = "center", $fn = 32);
            }
    }

/*
ECHOES — the numbers needed at the slicer, so nobody has to count layers.
*/
echo(str("PETG temperature tower: ", n_bands, " bands, ", band_h,
         " mm each, total ", total_h, " mm"));
echo(str("footprint ", span_x, " x ", body_d + shelf_len, " mm",
         twin ? str("  (twin towers, ", tower_gap, " mm clear gap)") : ""));
echo("--- add these in PrusaSlicer via the layer slider, right-click -> Add custom G-code ---");
for (i = [0 : n_bands - 1])
    echo(str("  band ", i, ": ", temps[i], " C   from z ", i * band_h,
             " mm (layer ", i * band_layers + 1, ")",
             i == 0 ? "  <- set in the filament profile, no custom gcode needed"
                    : str("   M104 S", temps[i])));
echo(str("first layer prints at ", temps[0],
         " C, so set the filament profile's temperature to that and let the custom G-code raise it"));
