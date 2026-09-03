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

/* The three features have to stay clear of each other or a failure cannot be attributed to one of them. */
assert(bridge_z < shelf_z, "bridge must sit below the shelf within a band");

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

    /* Shelf: sticks out into open air with nothing beneath it. */
    translate([body_w - weld, 0, base + shelf_z * band_h])
        cube([shelf_len + weld, body_d, shelf_t]);

    /* Fin: a thin blade standing off the back face. */
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

module bridge(i) {
    base = i * band_h;
    /* Over-length in Y so both ends are genuinely open rather than skinned. */
    translate([bridge_x, -1, base + bridge_z * band_h + bridge_d / 2])
        rotate([-90, 0, 0])
            cylinder(h = body_d + fin_len + 2, d = bridge_d, $fn = 48);
}

module tower() {
    difference() {
        union() {
            cube([body_w, body_d, total_h]);
            for (i = [0 : n_bands - 1]) features(i);
        }
        for (i = [0 : n_bands - 1]) bridge(i);
    }
}

span_x = twin ? 2 * (body_w + shelf_len) + tower_gap - shelf_len
              : body_w + shelf_len;

/* The base plate, joining both towers into a single solid, with the filament's
 * identity engraved into its top face in the gap between the towers. */
if (twin)
    difference() {
        cube([span_x, body_d, base_t]);

        /* Recessed from the TOP face down, so the cut is open upward and needs
         * no support. Placed in the gap so it does not eat into either tower's
         * footprint. */
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

tower();

/* The second tower is MIRRORED, not copied, so its shelf and fin face outward
 * too. A plain copy would put the second tower's shelf into the gap, shortening
 * the travel that this pair exists to create. */
if (twin)
    translate([2 * body_w + shelf_len + tower_gap, 0, 0])
        mirror([1, 0, 0])
            tower();

/*
ECHOES — the numbers needed at the slicer, so nobody has to count layers.
*/
echo(str("PETG temperature tower: ", n_bands, " bands, ", band_h,
         " mm each, total ", total_h, " mm"));
echo(str("footprint ", twin ? 2 * (body_w + shelf_len) + tower_gap
                            : body_w + shelf_len,
         " x ", body_d + fin_len, " mm", twin ? "  (twin towers)" : ""));
echo("--- add these in PrusaSlicer via the layer slider, right-click -> Add custom G-code ---");
for (i = [0 : n_bands - 1])
    echo(str("  band ", i, ": ", temps[i], " C   from z ", i * band_h,
             " mm (layer ", i * band_layers + 1, ")",
             i == 0 ? "  <- set in the filament profile, no custom gcode needed"
                    : str("   M104 S", temps[i])));
echo(str("first layer prints at ", temps[0],
         " C, so set the filament profile's temperature to that and let the custom G-code raise it"));
