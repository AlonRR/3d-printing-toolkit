// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

// 2.54 mm fan connector, printed: a male header and a female plug, 2, 3 or 4 pins, that fit each other and the
// usual 3-pin fan plug of the KK 254 kind. The pins of the male and the contacts of the female are 22 AWG solid
// wire, bared: no crimp terminals.
//
// Drawn from one fan plug measured with calipers (Alon, 9 Oct 2026) and the 2.54 mm pitch; no other model was
// used. One self-contained file: the Customizer's groups are the settings, [Hidden] what is worked out from them.
//
// THE FRAME. The pins run along X at Y = 0, pin 1 at -X, pointing up (+Z). The female's text face is towards +Y,
// its ribs towards -Y. The male prints on its underside; the female prints standing on its back end, the open end
// up. "pair" draws the female seated on the male.

/* [Part] */
part = "male";          // [male, female, coupon, pair]
pins = 3;               // [2, 3, 4]

/* [The plug, measured on a fan's 3-pin plug] */
plug_a3 = 8.0;          // MEASURED: across its pins, 3-pin (A). n pins: this plus a pitch for each pin more.
plug_b = 5.2;           // MEASURED: its thickness without the ribs, over the lip (B).
plug_c = 12.77;         // MEASURED: its length along the wires (C).
plug_d = 2.55;          // MEASURED: from the text face to the near wall of a pin's hole (D).
plug_hole = 1.45;       // MEASURED: a pin's hole in the open end.
rib = [1.1, 5.2, 6.67]; // MEASURED: the ribs on the face opposite the text: width, the gap between them, and the plug's thickness over them.
lip = [0.3, 1.0];       // The lip across the open end between the ribs: its height (MEASURED) and its length along the plug <<CONFIRM>>.
rib_inset_2 = 0.3;      // <<CONFIRM>> 2-pin: the ribs stand this far in from the ends, as the 3-pin's do. 3 and 4 pins keep the 3-pin's ribs over pins 1-3.
pitch = 2.54;

/* [Wire: 22 AWG solid] */
wire = [0.64, 1.6];     // The core, by the gauge (0.644), and the insulation's outside <<CONFIRM>>.

/* [Male] */
male_pin = 6;           // How far each pin stands above the block: a header's mating length.
male_base = [5, 1.5];   // The block: its height, and how much of it at the top holds the core alone - below, a slot takes the insulation.
male_wall = [1.8, 6];   // The wall behind the plug: its thickness, and how far it stands above the block.
male_front = 2.5;       // The block runs on this far past the plug's text face, for pin 1's mark.
play = 0.25;            // Round the plug: to the wall, to the key and between its ribs.

/* [Female] */
interference = 0.05;    // How far the contact wire stands into a pin's way. Print the coupon and pick the one that holds. <<CONFIRM>>
female_depth = 7;       // The cavity's depth from the open end: past a pin's 6 mm.
female_slot = 4;        // The insulation's slot, from the back end.
female_hook = [0.8, 1.2];   // The notch in the open end for the contact's bent-over tip: its depth and its length towards the text face.
female_chamfer = 0.3;   // Each cavity's lead-in.

/* [Printing - mirrors the print profile; scad-check.sh compares the first two with the slicer's] */
fdm_layer_h     = 0.2;
fdm_extrusion_w = 0.45;
fdm_hole_comp   = 0.15; // Added to every hole's radius - docs/fdm-design-rules.md section 2.

/* [Hidden] */
$fn = 24;
eps = 0.01;
coupon_i = [0, 0.05, 0.1, 0.15];
// The plug: across n pins; each pin's X, pin 1 first; the ribs' middle (pin 2's for 3 and 4 pins); the gap between
// them; Y from the pins to the text face, to the face behind the lip, to the lip, to the ribs' tips.
plug_a = plug_a3 + (pins - 3) * pitch;
xs = [for (k = [0 : pins - 1]) (k - (pins - 1) / 2) * pitch];
rib_x = pins == 2 ? 0 : xs[1];
rib_gap = pins == 2 ? plug_a - 2 * (rib_inset_2 + rib[0]) : rib[1];
y_text = plug_d + plug_hole / 2;
y_lip = plug_b - y_text;
y_back = y_lip - lip[0];
y_ribs = rib[2] - y_text;
// The male: its wall's inside, its key's face and width, its holes as cut, its ends, back and front.
m_wall_y = -(y_ribs + play);
m_key_y = -(y_lip + play);
m_key_w = rib_gap - 2 * play;
core_d = wire[0] + 2 * fdm_hole_comp;
ins_d = wire[1] + 2 * fdm_hole_comp;
m_x0 = -plug_a / 2 - play;
m_x1 = plug_a / 2 + play;
m_y0 = m_wall_y - male_wall[0];
m_y1 = y_text + male_front;
m_strip = male_base[1] + male_pin;
// The female: the contact wire's line, out from the pins towards the text face; the cavity, as cut, from the
// pin's far side to the wire's; how much of each wire to bare.
f_wire_y = (wire[0] + wire[0]) / 2 - interference;
f_cav = [wire[0] + 2 * 0.1 + 2 * fdm_hole_comp, -(wire[0] / 2 + 0.1 + fdm_hole_comp)];   // width, and its pin-side wall
f_strip = plug_c - female_slot + female_hook[1];

assert(pins >= 2 && pins <= 4, "pins: 2, 3 or 4");
assert(m_key_w > 2 * fdm_extrusion_w && m_key_y > m_wall_y, "the male's key must be wide enough to print and stand out from its wall");
assert(male_base[0] - male_base[1] > ins_d && pitch - core_d > fdm_extrusion_w,
    "the male's block must hold the insulation's slot under the cores' holes, a line of it between them");
assert(pitch - f_cav[0] > fdm_extrusion_w, "the female's cavities must leave a line of wall between them");
assert(f_cav[1] > -y_back + 2 * fdm_extrusion_w, "the female's cavities must leave two lines of wall to the ribbed face");
assert(f_wire_y + wire[0] / 2 + fdm_hole_comp < y_text - 2 * fdm_extrusion_w && f_wire_y + female_hook[1] < y_text - fdm_extrusion_w,
    "the female's contacts and their hooks must stay inside the text face");
assert(female_depth + eps < plug_c - female_slot, "the female's cavities must stop short of the insulation's slot");
assert(rib_gap > 2 * fdm_extrusion_w + 2 * play && plug_a / 2 - abs(rib_x) >= rib_gap / 2 + rib[0] - eps,
    "the ribs must fit on the plug, with a key between them");

// ------------------------------------------------------------------ the male
// The block and the wall, one L-shaped profile along X: two boxes sharing the back face would meet in a line of
// T-junctions. Each wire comes up its slot from below, its insulation stopping where the slot ends, so it cannot be
// pulled out upwards; its bared core goes on up its hole and stands as the pin. Under the block each wire bends over
// into a groove to the back edge: once the block is fixed down, that bend stops a pin being pushed down.
module male_key() let(h = male_base[0], wh = male_wall[1] - 0.5, d = m_key_y - m_wall_y, e = 0.3)
    // its top chamfered at 45 degrees, a lead-in between the ribs, 0.5 mm under the wall's top; it starts e inside
    // the wall, so the chamfer crosses the wall's face: an edge lying in that face leaves sliver facets
    translate([rib_x - m_key_w / 2, m_wall_y - e, h - eps]) hull() {
        cube([m_key_w, d + e, wh - d - e + eps]);
        cube([m_key_w, eps, wh + eps]);
    }
module male() let(h = male_base[0], c = male_base[1], wh = male_wall[1], s = xs[pins - 1] - xs[0] + ins_d + 0.4)
    difference() {
        union() {
            translate([m_x0, 0, 0]) rotate([90, 0, 90]) linear_extrude(m_x1 - m_x0)
                polygon([[m_y0, 0], [m_y1, 0], [m_y1, h], [m_wall_y, h], [m_wall_y, h + wh], [m_y0, h + wh]]);
            male_key();
        }
        for (x = xs) translate([x, 0, h - c - eps]) cylinder(d = core_d, h = c + 1, $fn = 16);
        translate([0, 0, -1]) linear_extrude(h - c + 1)
            hull() for (x = [xs[0], xs[pins - 1]]) translate([x, 0]) circle(d = ins_d);
        translate([-s / 2, m_y0 - 1, -1]) cube([s, 1 - m_y0, ins_d + 1]);
        // pin 1's mark, in front of where the plug stands
        translate([xs[0], (y_text + m_y1) / 2, h - 0.4]) linear_extrude(1)
            text("1", size = 1.8, halign = "center", valign = "center");
    }
// The male's pins: the wires' bared cores, from where the insulation stops to the tips.
module male_pins() for (x = xs) translate([x, 0, male_base[0] - male_base[1]]) cylinder(d = wire[0], h = m_strip, $fn = 16);

// ------------------------------------------------------------------ the female
// Drawn with its open end at Z = 0 and its back end at Z = plug_c. Each wire comes in from the back: its insulation
// in a slot that stops it going further in, its bared core on through its hole and down the cavity along the text
// side's wall, and its tip bent over into a notch in the open end, which stops it being pulled back out. A pin going
// in squeezes past the wire by `interference`.
// The cavity's text-side wall stands 0.05 mm past the core's hole: level with it, the two would be tangent.
module female_cavity(x, i) let(cy = (wire[0] + wire[0]) / 2 - i, w = f_cav[0], y0 = f_cav[1],
                               y1 = cy + core_d / 2 + 0.05, ch = female_chamfer) {
    // the cavity, with a lead-in at the open end
    translate([x - w / 2, y0, -1]) cube([w, y1 - y0, female_depth + 1]);
    hull() {
        translate([x - w / 2 - ch, y0 - ch, -1]) cube([w + 2 * ch, y1 - y0 + 2 * ch, 1]);
        translate([x - w / 2, y0, ch]) cube([w, y1 - y0, eps]);
    }
    // the core's hole, on from the cavity's end to the insulation's slot
    translate([x, cy, female_depth - eps]) cylinder(d = core_d, h = plug_c - female_slot - female_depth + 2 * eps, $fn = 16);
    // the hook's notch, from the wire's line towards the text face
    translate([x - core_d / 2, cy, -1]) cube([core_d, female_hook[1], female_hook[0] + 1]);
}
module female_body() let(a = plug_a, c = plug_c, rw = rib[0])
    union() {
        translate([-a / 2, -y_back, 0]) cube([a, y_text + y_back, c]);
        // the lip across the open end, between the ribs
        translate([rib_x - rib_gap / 2 - eps, -y_lip, 0]) cube([rib_gap + 2 * eps, lip[0] + eps, lip[1]]);
        for (s = [-1, 1]) translate([rib_x + s * (rib_gap + rw) / 2 - rw / 2, -y_ribs, 0]) cube([rw, y_ribs - y_back + eps, c]);
    }
module female(i = interference) let(cy = (wire[0] + wire[0]) / 2 - i)
    difference() {
        female_body();
        for (x = xs) female_cavity(x, i);
        // the insulation's slot, from the back end
        translate([0, 0, plug_c - female_slot]) linear_extrude(female_slot + 1)
            hull() for (x = [xs[0], xs[pins - 1]]) translate([x, cy]) circle(d = ins_d);
        // pin 1's arrow on the text face
        translate([xs[0], y_text - 0.4, plug_c / 2]) rotate([-90, 0, 0]) linear_extrude(1)
            polygon([[-0.9, 1.2], [0.9, 1.2], [0, -0.6]]);
    }
// The female as it prints: standing on its back end, the open end up.
module female_printing() translate([0, 0, plug_c]) mirror([0, 0, 1]) female();

// ------------------------------------------------------------------ the coupon
// Four single cavities in a row, one at each of coupon_i, numbered 1 to 4 on the text face: thread a wire into each,
// push a pin in, and use the interference of the one that holds firmly and still lets the pin in.
module coupon() let(g = 5, n = len(coupon_i))
    translate([0, 0, plug_c]) mirror([0, 0, 1]) difference() {
        translate([-g / 2, -y_back, 0]) cube([n * g, y_text + y_back, plug_c]);
        for (j = [0 : n - 1]) translate([j * g, 0, 0]) {
            female_cavity(0, coupon_i[j]);
            translate([0, (wire[0] + wire[0]) / 2 - coupon_i[j], plug_c - female_slot]) cylinder(d = ins_d, h = female_slot + 1);
            translate([0, y_text - 0.4, plug_c / 2]) rotate([-90, 0, 0]) linear_extrude(1)
                text(str(j + 1), size = 2.5, halign = "center", valign = "center");
        }
    }

// ------------------------------------------------------------------ what is drawn
module say() echo(str("fan connector, ", pins, " pins: the male's wires bared ", m_strip, " mm, the female's ", f_strip,
    " mm; the female's contacts stand ", interference, " mm into a pin's way"));

if (part == "male") { male(); say(); }
else if (part == "female") { female_printing(); say(); }
else if (part == "coupon") coupon();
else if (part == "pair") {
    color("dimgray") male();
    color("goldenrod") male_pins();
    color("ivory") translate([0, 0, male_base[0]]) female();
}
// The checks: each must come out empty (scripts/fan-connector-checks.py). The female seated 0.01 mm up on the
// male; the male's pins through both, touching neither; a header's square pin in each cavity.
else if (part == "check_pair") intersection() { male(); translate([0, 0, male_base[0] + eps]) female(); }
else if (part == "check_pins") intersection() {
    union() { male(); translate([0, 0, male_base[0] + eps]) female(); }
    male_pins();
}
else if (part == "check_square") intersection() {
    female();
    for (x = xs) translate([x - wire[0] / 2, -wire[0] / 2, -1]) cube([wire[0], wire[0], female_depth]);
}
else if (part == "none") { }   // a file that includes this one, to draw its own
else assert(false, str("unknown part: ", part));
