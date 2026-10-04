// SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
// SPDX-License-Identifier: CC-BY-4.0
// Shared under the Creative Commons Attribution 4.0 International licence
// (LICENSES/CC-BY-4.0.txt): reuse freely, including commercially, with attribution.

/*
The print-chamber box: two printed parts. The cover's top locates on a bump on the back plate, inside a U
hanging from its top wall, and two M3 screws through its bottom corners go into nuts in the back plate.

  BACK PLATE   printed flat. Carries the two keyholes it hangs by, the channel the SPS30 is set into from
               the front, the divider under its air face, the two clips the SuperMini's back edge snaps into,
               the block the GY-SGP41 is screwed to on edge, the two nut bosses and the bump the cover's top
               locates on.
  COVER        printed front-face down. A five-sided shell.

Every opening is a hole in its part's first layers or a notch open at its back edge, except the cover's
USB-C opening and its side vents, which are holes in a wall bridged by at most 4 mm. The nut pockets'
ceilings are printed with the three-layer two-bridge technique (docs/fdm-design-rules.md §3c).

  part = "back"       this file as it stands - what scripts/scad-check.sh checks
  part = "cover"      print-chamber-box-cover.scad sets it
  part = "assembly"   the two parts in place, with the components ghosted in. Not printable.

Settings are in print-chamber-box.params.scad, and why the layout is what it is - with a source for each
rule - is in docs/design.md. The checks it carries, and their controls, are in docs/checking.md.

Everything below is drawn the way the params file's photos settled it - the SPS30's outlet, its connector
and the board's USB-C end on your RIGHT as you face the box, which is low X - and mirrored whole when
outlet_at_left is set.
*/
include <print-chamber-box.params.scad>

draw_model = true;

eps = 0.01;
$fa = 2;
$fs = 0.4;

function hole_r(d) = d / 2 + fdm_hole_comp;
function whole(x) = abs(x - round(x)) < 1e-6;
function up_to_layer(y) = ceil(y / fdm_layer_h - 1e-6) * fdm_layer_h;

// =================================================================== derived: X (across the box)
ch_in_w  = sps_w + 2 * sps_nub + 2 * sps_fit;               // inside of the SPS30 channel
ch_out_w = ch_in_w + 2 * cradle_t;
// The two keyholes the box hangs by: an entry the screw's head passes, and above it a slot the thread
// slides up, so the head ends up behind the plate, bearing on it - a wall clock's keyhole, twice. One
// sits in each column beside the SPS30, so the board above can come down onto the SPS30's lead.
key_entry_d = key_head_d + 1.0;                             // the head passes it
key_slot_w  = key_shank_d + 0.6;                            // the thread slides along it; the head does not
// The cover's bottom corners are screwed into M3 nuts, pressed into hex pockets from the wall side.
nut_ac     = nut_af / cos(30);                              // the nut across its corners
function nut_pocket_r(fit) = nut_ac / 2 + fdm_hole_comp + fit / cos(30);   // the hex pocket, to its corners
nut_pock_r = nut_pocket_r(nut_fit);
nut_boss_d = 2 * nut_pock_r + 4 * fdm_extrusion_w;          // two beads round the pocket's corners
// Each column beside the channel holds a nut boss low down and a keyhole higher up, and the cover's wall.
col_w    = max(nut_boss_d + 2 * part_fit, part_fit + 2 * hole_r(key_entry_d) + gap);
W        = ch_out_w + 2 * col_w + 2 * wall;
ch_x0    = (W - ch_in_w) / 2;
ch_x1    = ch_x0 + ch_in_w;
sps_x0   = ch_x0 + sps_fit + sps_nub;                       // the sensor body, nominally centred
sps_x1   = sps_x0 + sps_w;
x_div    = sps_x1 - divider_from_inlet_end;                 // the inlets are at the high-X end
div_clear_in  = divider_from_inlet_end - divider_t / 2 - sps_inlet_end;     // to the inlets' far end
div_clear_out = sps_outlet_from - (divider_from_inlet_end + divider_t / 2);  // to the outlet grille
key_xs   = [wall + part_fit + hole_r(key_entry_d), W - wall - part_fit - hole_r(key_entry_d)];

// The SPS30's lead: its plug sits on the connector face at the outlet end; the wires rise from it and bend
// over towards the board's pins. Nothing may stand in that column (photo 1, 2 Oct 2026).
lead_x0 = sps_x0 + conn_from;
lead_x1 = sps_x0 + conn_to;

// The board lies level, its USB-C end in the right-hand wall, which is thinned to port_wall over it so the
// socket's mouth reaches the outside face. A plug's body then never enters the wall, whatever its size.
sm_usb_x  = port_wall + part_fit;
sm_x0     = sm_usb_x;
sm_x1     = sm_x0 + sm_l;
sm_ant_x  = sm_x1;                                          // the PCB's antenna end
pole_in   = 1.5;                                            // the pole stands this far in from that end
usb_proud    = usb_overhang - port_wall - part_fit;         // the mouth, past the outside face, board at rest
usb_proud_in = usb_proud - pocket_fit;                      // the same, with a plug pushing the board against its stops
// The USB-C shell is a stadium - a rectangle with round ends - and the wall's opening is the same shape,
// part_fit clear all round. Alon, 3 Oct 2026: "round (or best we can do 3d printing) the usbc port hole".
usb_open_r = usb_shell_h / 2 + part_fit;                    // its ends' radius
usb_open_c = usb_shell_w / 2 - usb_shell_h / 2;             // its ends' centres, either side of the board's middle
// The cover goes on straight back onto the plate, and the shell stands out through the wall before it does,
// so the opening runs on, the shell's height, out to the cover's back edge: the shell slides along it.
// Alon, 4 Oct 2026, on the printed box: "cut the small area past -y the usbc slot in the cover and place a
// makeup to the slot on the back plate". The filler stands on the plate in that slot, behind the shell,
// part_fit clear of the slot's sides and of the shell, and closes the wall again.
usb_notch_y0 = back_t - eps;                                // where the slot opens, at the cover's back edge
usb_fill_h   = usb_open_r - part_fit;                       // the filler's half-height, the slot's less part_fit
// It is held by its long edges, not laid on a shelf, so the pins along them stay open from below. Its back
// edge presses from the front into two clips on the plate - each a lower jaw, and an upper one whose
// underside angles in from a wide mouth to a catch that pinches the PCB, and out again behind it, where the
// edge sits. Lying level with its component side up, its back edge carries GPIO5 and GPIO6 on its first
// two pins, so one clip is at the antenna end and the other just past the second pin. The cover's front
// clasp takes the front edge from its 4th pin, clear of 5V, GND and 3V3 on its first three.
pin_pitch = 2.54;                                           // the SuperMini's 0.1-inch pin pitch
sm_lip_x0 = sm_usb_x + pin_mid + 2 * pin_pitch;             // the cover's front clasp, from the 4th pin
stop_x0   = sm_ant_x + pocket_fit;                          // the stops, just past the antenna end
sm_lip_x1 = stop_x0;
clasp_xs  = [[sm_usb_x + pin_mid + pin_pitch / 2 + 0.5, sm_usb_x + pin_mid + pin_pitch / 2 + 0.5 + clasp_len],
             [sm_ant_x - clasp_len, sm_ant_x]];             // the two clasps' X ranges along the back edge

// =================================================================== derived: Y (out from the wall)
ledge_w = sps_fit + sps_nub + ledge;                        // what each ledge spans, wall to sensor
y_sps1  = back_t + sps_t;                                   // the SPS30's label face
y_b0    = back_t + pocket_fit;                              // the board's back long edge, by the plate
// The clips' upper jaws, from the plate out: a relief where the edge sits, the catch, and the mouth. Each is a
// gap over the PCB's underside.
clip_reach   = clip_room;                                   // all the room there is
clip_catch_y = back_t + clip_reach / 2;
clip_g_open  = sm_pcb_t + 2 * pocket_fit;                   // at the plate, behind the catch
clip_g_catch = sm_pcb_t - clasp_pinch;                      // at the catch: it pinches
clip_g_mouth = sm_pcb_t + 2 * pocket_fit + 0.4;             // at the tip, so the edge finds its way in
y_b1    = y_b0 + sm_w;                                      // its front long edge
y_bc    = (y_b0 + y_b1) / 2;
// The board's width now fills the depth: back edge by the plate, front edge in the cover's rim.
inner_d = max(sps_t + sps_fit + front_gap_min, pocket_fit + sm_w + pocket_fit + rib_t);
D       = back_t + inner_d + front_t;
y_in1   = D - front_t;                                      // inside face of the cover's front
// The channel walls stand 2 * gap proud of the SPS30's face. It goes in from the front - nothing on
// the plate overhangs it - and the cover's partition rib, sps_fit off its face, keeps it from tipping.
y_ch1   = y_sps1 + 2 * gap;

// =================================================================== derived: Z (up)
z_sps0  = wall;                       // the air face sits at the inside of the bottom wall: minimal depth to ambient
z_sps1  = z_sps0 + sps_h;
shelf_t = rib_t;                      // the clasps' lower jaws: printed upright, so a width in beads
z_f0    = z_sps1 + cable_zone_h + gap;   // their underside, just over the SPS30's lead
zu      = z_f0 + shelf_t;             // the PCB's underside
z_uc    = zu + sm_pcb_t + usb_shell_h / 2;   // the USB-C socket's centre: the shell sits on the component side
nut_bz  = wall + part_fit + nut_boss_d / 2;  // the nut bosses' centres, in each bottom corner
nut_bx  = [nut_bz, W - nut_bz];
// The keyholes: the hung heads' tops gap under the clasps, and under the room the wires to the board's
// back pins need; the slots key_level_tol longer, so one screw may sit that much lower than the other and
// its head still clear its entry.
key_travel = key_entry_d / 2 + key_head_d / 2 + 1.0 + key_level_tol;
key_z1  = min(z_f0, zu - back_wire_room) - gap - key_head_d / 2;   // where a screw is once the box hangs
key_z0  = key_z1 - key_travel;            // the entry's centre
H       = zu + ant_h + gap + wall;        // the pole stands under the top wall
// The cover's top locates on one bump in the middle of the plate's top, which stands out into a U hanging
// from the cover's top wall: two arms, part_fit either side of the bump and part_fit over it. They hold the
// cover's top in X and Z; the two bottom screws hold the cover on. The arms run from the cover's front
// to the plate, so on the cover's bed they stand as walls.
bump_x0  = W / 2 - bump_w / 2;
bump_x1  = W / 2 + bump_w / 2;
u_z0     = H - wall - u_drop;            // the U's arms' lower ends, and the bump's underside
bump_z1  = H - wall - part_fit;          // the bump's top

// =================================================================== the GY-SGP41: flat, behind the cover
// Alon, 3 Oct 2026, once the standoff it stood on edge on would not print: "make the sgp41 flat and raised
// up against the cover" (q34 "A"). It lies flat in the left-hand column, its sensor towards vents in the
// cover's front and its pins up. One M2.5 screw holds it from the front, through its mounting hole into a
// post rising from the plate; it lies on the post's top and on a rib under the bare strip along its bottom
// edge, and its bottom edge sits on a ledge. All three stand on the plate, so they print as walls, and the
// pilot is upright. The screw's head sits between the module and the cover, so the module is as far forward
// as that allows. Its edge towards the SPS30 reaches past the end of the SPS30's channel wall, which is
// notched there so the module's underside parts clear it by a gap.
gy_sensor_h = gy_t - gy_back;                   // the sensor, standing off its face
gy_parts_h  = gy_back - gy_pcb_t;               // the parts on its underside
gy_yf   = y_in1 - part_fit - gy_head_h;         // its face: the screw's head between it and the cover
gy_yu   = gy_yf - gy_pcb_t;                     // its underside, on the post and the rib
gy_yp   = gy_yu - gy_parts_h;                   // its underside's parts reach back to here
gy_x0   = W - wall - part_fit - pocket_fit - gy_w;   // its edge towards the SPS30: as far from it as the side wall allows,
                                                     // so the wire from its pin nearest the SPS30 clears the channel wall
gy_x1   = gy_x0 + gy_w;
// Which side its hole is on follows from which way round the module is. Facing the box, its sensor faces
// you with its pins up, and your right is -X: so a hole on the right is at the module's low-X edge, by the
// SPS30. The whole box is mirrored when the outlet is at the left, and a real module cannot be: so the
// canonical drawing takes the mirror image then, and comes out right after it.
gy_hole_lowx = gy_hole_right != outlet_at_left;
gy_z0   = wall + part_fit + nut_boss_d + part_fit + rim_t + pocket_fit;   // its bottom edge, on a ledge over the nut boss
gy_z1   = gy_z0 + gy_l;
gy_hx   = gy_hole_lowx ? gy_x0 + gy_hole_side : gy_x1 - gy_hole_side;   // its mounting hole
gy_hz   = gy_z0 + gy_hole_far;
gy_post_y1 = gy_yu;                             // the post's top, against the module's underside
gy_post_yw = gy_yp - gap;                       // where the post narrows, a gap short of the underside's parts
gy_rib_z1  = gy_z0 + gy_bare - gap / 2;         // the rib's top edge, short of the underside's nearest part
gy_pilot_depth = gy_screw_l - gy_pcb_t + 2 * fdm_layer_h;   // into the post from its top
ch_notch = gy_yp - gap;                          // the SPS30 channel wall's front, where the module overhangs it

// Its four wires leave its back by its pins, turn up the column behind it and, once level, cross over the
// SPS30's top-left corner in a short channel on the plate: a slot open to the front between two ribs, the
// wires side by side across its depth. They press in from the front past a 45-degree lip on each rib, and
// the lips hold them. The ribs print as walls, the lips as 45-degree ledges. Their lanes keep clear of the
// wall screw's head as they rise; each rises above its own pin, but none nearer the SPS30's channel wall
// than a wire's width.
gy_bend_r  = 3.0;                                             // the solid wire's tightest bend
gy_stub    = 1.0;                                             // straight out of a solder joint first
gy_pitch   = gy_wd + 0.34;                                    // the wires' spacing, centre to centre
function gy_pin_x(i) = gy_hole_lowx ? gy_x1 - 1.5 - i * 2.54 : gy_x0 + 1.5 + i * 2.54;   // SDA, SCL, GND, VIN
gy_pin_z   = gy_z1 - 1.3;
function gy_rise_x(i) = max(gy_pin_x(i), ch_x1 + cradle_t + gy_wd / 2 + 0.15);
gy_x_up    = min([for (i = [0 : 3]) gy_rise_x(i)]);            // the riser nearest the SPS30
gy_ch_lane = [for (i = [0 : 3]) back_t + key_slack + key_head_h + 0.1 + gy_wd / 2 + i * gy_pitch];
gy_ch_slot = gy_wd + 0.4;                                     // the slot, across: a wire, 0.2 either side
gy_ch_zc   = z_sps1 + part_fit + rib_t + gy_ch_slot / 2;      // its middle: the floor rib part_fit over the SPS30
gy_ch_x1   = gy_x_up - gy_bend_r - gap / 2;                   // it starts once the wires are level
gy_ch_x0   = gy_ch_x1 - gy_ch_len;
gy_ch_lip  = (gy_ch_slot - gy_ch_lip_gap) / 2;                // each lip's reach into the slot
gy_ch_y0   = gy_ch_lane[3] + gy_wd / 2 + 0.2;                 // where the lips begin
gy_ch_y1   = gy_ch_y0 + 2 * gy_ch_lip;                        // the ribs' front

// =================================================================== the cover's screws and their nuts
// The two bottom screws sit flush: each head in a counterbore in the cover's front, on a floor as thick as
// the front. The front is thinner than a head is tall, so a boss on its inside carries the floor, and the
// nut boss on the back plate stops where that boss starts - the screw clamps the two together.
cb_d     = cover_head_d + (screw_d - 3);   // the counterbore: the head, and the tested screw hole's allowance
cb_depth = up_to_layer(cover_head_h);    // the cover prints front face down: whole layers from the bed
cb_floor = front_t;
head_y   = D - cb_depth;                  // where a screw's head bears
cb_y0    = head_y - cb_floor;             // the cover boss's end, inside
nut_boss_y1 = cb_y0;                      // the nut boss's end, against it
// Pressed into a hex pocket from the wall side, the nut bears on a shoulder towards the cover - a
// bottom-inserted nut, the strongest of the ways a print holds one (docs/mechanical-design-review.md).
// The shoulder sits where the M3 x cover_screw_l, from its head, passes right through the nut.
nut_y1  = up_to_layer(head_y - cover_screw_l + nut_h + 2 * fdm_layer_h);   // the shoulder

// =================================================================== the rules
for (w = [["wall", wall], ["cradle_t", cradle_t], ["divider_t", divider_t], ["rib_t", rib_t],
          ["rim_t", rim_t], ["port_wall", port_wall], ["vent_rib", vent_rib]])
    assert(whole(w[1] / fdm_extrusion_w),
           str(w[0], " (", w[1], ") must be a whole number of ", fdm_extrusion_w,
               " mm beads - fdm-design-rules §1"));

for (t = [["back_t", back_t], ["front_t", front_t], ["the nut's shoulder", nut_y1], ["cb_depth", cb_depth]])
    assert(whole(t[1] / fdm_layer_h),
           str(t[0], " (", t[1], ") is printed flat, so it must be a whole number of ",
               fdm_layer_h, " mm layers"));

assert(wire_perpendicular,
       "the layout lies the board level so its antenna's pole stands up - it needs the pole off the component side");

assert(div_clear_in >= 0.5 && div_clear_out >= 0.5,
       str("the divider must sit in the blank gap between the inlets (to ", sps_inlet_end,
           " mm) and the outlet grille (from ", sps_outlet_from, " mm); it clears them by ",
           div_clear_in, " and ", div_clear_out, " mm"));
assert(x_div - divider_t / 2 > sps_x0 + ledge && x_div + divider_t / 2 < sps_x1 - ledge,
       str("the divider (at ", divider_from_inlet_end, " mm from the inlet end) does not fit between",
           " the two ledges - check divider_from_inlet_end"));

assert(key_slot_w >= 2 && gy_pilot_d >= 2 && screw_d >= 2,
       "a hole under 2 mm distorts or closes up - fdm-design-rules §2");

assert(y_ch1 <= y_in1 - part_fit,
       str("the SPS30 channel's walls (to ", y_ch1, ") reach the cover's front (", y_in1,
           ") - raise front_gap_min"));

assert(usb_proud_in >= -1e-6,
       str("plugging in pushes the board against its stops, and there the USB-C socket's mouth sits ",
           -usb_proud_in, " mm inside the wall - a plug's body would hit the wall before it seats.",
           " Thin port_wall, or tighten part_fit and pocket_fit"));
assert(y_bc - usb_plug_w / 2 >= 0,
       "the USB-C plug would hit the surface the box hangs on - the board sits too close to the wall");
assert(stop_reach - pocket_fit + gap <= ant_loop_free,
       str("the stops at the board's antenna end reach ", stop_reach - pocket_fit, " mm over it, and the",
           " antenna loop leaves only ", ant_loop_free, " mm free - reduce stop_reach"));
assert(sm_lip_over < sm_edge,
       "the cover's front lip would reach past the SuperMini's pad strip onto its parts - check sm_lip_over");
assert(clip_reach <= clip_room + 1e-6, "the back clips reach further onto the board than clip_room allows");
assert(clip_catch_y > y_b0 + 2 * fdm_layer_h,
       "the clips' catch must be over the PCB, past its edge, so it holds the board rather than its corner");
assert(sm_lip_x1 - sm_lip_x0 >= 2 * pin_pitch, "the cover's lip has no length - check pin_mid");
assert(clasp_xs[0][1] + gap <= clasp_xs[1][0],
       "the board's two back clasps run into each other - shorten clasp_len");
assert(clasp_pinch > 0 && clip_g_catch >= sm_pcb_t / 2,
       "the clips' catch must pinch the PCB, but not close up");

assert(key_head_d - 2 * hole_r(key_slot_w) >= 2 * 1.0,
       str("the keyholes' slots (", 2 * hole_r(key_slot_w), " mm as cut) leave the screws' ", key_head_d,
           " mm heads less than 1 mm to bear on each side - they could pull through"));
// signed: negative means the keyhole runs into what is below or above it
key_room_low  = key_z0 - hole_r(key_entry_d) - (wall + part_fit + nut_boss_d);
key_room_high = z_f0 - (key_z1 + key_head_d / 2);
key_room_gy   = key_z0 - hole_r(key_entry_d) - gy_z1;
assert(key_room_low >= gap && key_room_high >= gap,
       str("the keyholes must stand clear of the nut bosses below and the board's clasps above; they leave ",
           key_room_low, " and ", key_room_high, " mm"));
assert(key_room_gy >= gap,
       str("the left keyhole's entry reaches down to the SGP41 - it leaves ", key_room_gy, " mm"));

assert(cb_depth >= cover_head_h - 1e-6, "the cover's screw heads would stand proud of its front - deepen the counterbore");
assert(hole_r(cb_d) + 2 * fdm_extrusion_w <= nut_boss_d / 2,
       "the counterbore leaves the cover's boss less than two beads round it");
assert(head_y - cover_screw_l >= 2 * fdm_layer_h,
       str("an M3 x ", cover_screw_l, " through the cover's corner would poke out of the back plate"));
assert(head_y - cover_screw_l <= nut_y1 - nut_h,
       "the cover's screw stops short of passing right through its nut - raise the shoulder");
assert(nut_y1 + 2 * fdm_layer_h < nut_boss_y1, "the nut's shoulder reaches the cover's boss - the nut boss is too short");

assert(gy_yf + gy_head_h + part_fit <= y_in1 + 1e-6, "the SGP41's screw head would reach the cover's front");
assert(gy_yf + gy_sensor_h + part_fit <= y_in1 + 1e-6, "the SGP41's sensor would reach the cover's front");
assert(gy_x1 + pocket_fit <= W - wall - part_fit + 1e-6, "the SGP41 lying flat does not fit the column's width");
assert(gy_post_y1 - gy_pilot_depth >= back_t + 2 * fdm_layer_h,
       str("the SGP41's pilot would run out of the post into the wall side of the plate - shorten gy_screw_l"));
assert(gy_yp - ch_notch >= gap - 1e-6, "the SGP41's underside parts come within a gap of the SPS30's channel wall");
assert(ch_notch >= y_sps1 + sps_fit + 2 * fdm_layer_h, "the channel wall's notch reaches the SPS30's face");
assert(gy_z0 - pocket_fit - rim_t >= nut_bz + nut_boss_d / 2 + part_fit - 1e-6,
       "the SGP41's ledge comes down onto the nut bosses");
assert(gy_hole_d >= gy_screw_d + 0.1,
       str("the SGP41's mounting hole (", gy_hole_d, " mm) is too small for an M", gy_screw_d,
           " screw - use a smaller one and set gy_screw_d, gy_head_d and gy_head_h"));
assert(hole_r(gy_pilot_d) + 2 * fdm_extrusion_w <= gy_standoff_d / 2,
       "the post round the SGP41's pilot is thinner than two beads - widen gy_standoff_d");
assert(gy_standoff_d > gy_hole_d,
       "the SGP41's post is no wider than its mounting hole - the board would have nothing to rest on");
assert(gy_post_d >= gy_standoff_d, "the SGP41's post narrows the wrong way");

assert(bump_x0 - part_fit - rib_t - (sm_ant_x - pole_in + 0.5) >= gap,
       "the U at the top reaches the antenna's pole - narrow bump_w");
assert(u_drop > part_fit + 2 * fdm_extrusion_w, "the bump the cover's top locates on has no height");

// =================================================================== geometry helpers
// A 2D rectangle with its convex corners rounded: shrink, then grow (lesson 5 of docs/openscad-basics).
module rrect(w, h, r) {
    if (r > 0) offset(r = r) offset(delta = -r) square([w, h]);
    else square([w, h]);
}

// A block spanning the given X, Y and Z ranges, its corners rounded as seen from the front.
module slab_xz(x0, x1, y0, y1, z0, z1, r = 0) {
    translate([0, y1, 0])
        rotate([90, 0, 0])
            linear_extrude(height = y1 - y0)
                translate([x0, z0]) rrect(x1 - x0, z1 - z0, r);
}
// A box from corner to corner.
module box3(a, b) translate(a) cube(b - a);

// A cylinder along Y, and one along X.
module cyl_y(x, z, r, y0, y1, fn = 0) {
    translate([x, y0, z]) rotate([-90, 0, 0])
        if (fn > 0) cylinder(r = r, h = y1 - y0, $fn = fn); else cylinder(r = r, h = y1 - y0);
}
module cyl_x(y, z, r, x0, x1) {
    translate([x0, y, z]) rotate([0, 90, 0]) cylinder(r = r, h = x1 - x0);
}

// Slots through a face, spread across [a0, a1] - in the cover's front (X), or its side wall (Z).
module vent_slots(x0, x1, z0, z1) {
    n     = floor((x1 - x0 + vent_rib) / (vent_w + vent_rib));
    used  = n * vent_w + (n - 1) * vent_rib;
    start = x0 + (x1 - x0 - used) / 2;
    if (n > 0)
        for (i = [0 : n - 1])
            translate([start + i * (vent_w + vent_rib), y_in1 - eps, z0])
                cube([vent_w, front_t + 2 * eps, z1 - z0]);
}
module side_vents(y0, y1, z0, z1) {
    n     = floor((z1 - z0 + vent_rib) / (vent_w + vent_rib));
    used  = n * vent_w + (n - 1) * vent_rib;
    start = z0 + (z1 - z0 - used) / 2;
    if (n > 0)
        for (i = [0 : n - 1])
            translate([W - wall - eps, y0, start + i * (vent_w + vent_rib)])
                cube([wall + 2 * eps, y1 - y0, vent_w]);
}

// The nut's pocket, from the wall side up to its shoulder, and over it the ceiling's three layers:
// a slot the screw hole's width right across the pocket's flats, then a square, then the round hole.
module nut_trap(x, z, r = nut_pock_r) {
    hr = hole_r(screw_d);
    translate([x, -eps, z]) rotate([-90, 0, 0]) rotate([0, 0, 30])
        cylinder(r = r, h = nut_y1 + eps, $fn = 6);
    translate([x - hr, nut_y1 - eps, z - r * cos(30)])
        cube([2 * hr, fdm_layer_h + eps, 2 * r * cos(30)]);
    translate([x - hr, nut_y1 + fdm_layer_h - eps, z - hr]) cube([2 * hr, fdm_layer_h + eps, 2 * hr]);
    cyl_y(x, z, hr, nut_y1 + 2 * fdm_layer_h - eps, nut_boss_y1 + eps);
}

// A bottom screw's way through the cover, from its face in: the counterbore its head sits flush in, then
// the clearance hole on through the boss. The cover prints front face down, so the counterbore's floor is
// a ceiling: its first layer bridges across leaving a slot the hole's width, its second across that
// leaving a square, and the round hole starts on the third - as over the nuts, with no support.
module cover_screw_hole(x, z) {
    hr = hole_r(screw_d);
    cr = hole_r(cb_d);
    cyl_y(x, z, cr, head_y, D + eps);
    translate([x - hr, head_y - fdm_layer_h, z - cr]) cube([2 * hr, fdm_layer_h + eps, 2 * cr]);
    translate([x - hr, head_y - 2 * fdm_layer_h, z - hr]) cube([2 * hr, fdm_layer_h + eps, 2 * hr]);
    cyl_y(x, z, hr, cb_y0 - eps, head_y - 2 * fdm_layer_h + eps);
}

// One of the board's two back clips, over c = [x0, x1] along its back edge: a lower jaw under the edge, and
// an upper jaw over its pad row whose underside angles in from the mouth to the catch - g_catch over the
// PCB's underside - and out again to the plate. Both stand on the plate, so on the bed they are walls; the
// catch's slope leans 30 degrees at most. The clearance test draws it with other catches.
module clip(c, g_catch = clip_g_catch) {
    box3([c[0], back_t - eps, z_f0], [c[1], y_b0 + clasp_low, zu]);
    translate([c[0], 0, 0]) rotate([90, 0, 90]) linear_extrude(height = c[1] - c[0])
        polygon([[back_t - eps, zu + clip_g_open],
                 [clip_catch_y, zu + g_catch],
                 [back_t + clip_reach, zu + clip_g_mouth],
                 [back_t + clip_reach, zu + clip_g_mouth + rim_t],
                 [back_t - eps, zu + clip_g_mouth + rim_t]]);
    box3([c[0], back_t - eps, z_f0], [c[1], back_t + eps, zu + clip_g_mouth + rim_t]);
}

// The SGP41's mount, all standing on the plate: the post its screw goes into - wide, narrowing to
// gy_standoff_d where the module's underside parts are - the rib under the bare strip along its bottom
// edge, and the ledge that edge sits on. And the pilot, straight down into the post. The clearance test
// tries other pilots.
module gy_mount() {
    cyl_y(gy_hx, gy_hz, gy_post_d / 2, back_t - eps, gy_post_yw);
    cyl_y(gy_hx, gy_hz, gy_standoff_d / 2, gy_post_yw - eps, gy_post_y1);
    box3([gy_x0 + gap / 2, back_t - eps, gy_z0 - pocket_fit], [gy_x1 - gap / 2, gy_yu, gy_rib_z1]);
    box3([gy_x0, back_t - eps, gy_z0 - pocket_fit - rim_t], [gy_x1, gy_yf, gy_z0 - pocket_fit]);
}
module gy_pilot(d = gy_pilot_d) cyl_y(gy_hx, gy_hz, hole_r(d), gy_post_y1 - gy_pilot_depth, gy_post_y1 + eps);

// The SGP41 wires' channel over the SPS30's top-left corner: a floor rib and a roof rib standing on the
// plate, each with its lip at the front - a 45-degree ridge into the slot.
module gy_channel() for (k = [-1, 1]) let(zr = gy_ch_zc + k * gy_ch_slot / 2) {
    box3([gy_ch_x0, back_t - eps, k < 0 ? zr - rib_t : zr], [gy_ch_x1, gy_ch_y1, k < 0 ? zr : zr + rib_t]);
    translate([gy_ch_x0, 0, 0]) rotate([90, 0, 90]) linear_extrude(height = gy_ch_x1 - gy_ch_x0)
        polygon([[gy_ch_y0, zr + k * eps], [gy_ch_y0 + gy_ch_lip, zr - k * gy_ch_lip], [gy_ch_y1, zr + k * eps]]);
}

// Mirror everything when the outlet - and so the connector, the board and its cable - is on the left.
module place() {
    if (outlet_at_left) translate([W, 0, 0]) mirror([1, 0, 0]) children();
    else children();
}

// =================================================================== the back plate, as installed
module back_plate() place() difference() {
    union() {
        // the plate
        slab_xz(0, W, 0, back_t, 0, H, corner_r);

        // the channel walls the SPS30 is set between, from the front. No lips: anything overhanging
        // its face would have to be slid past. Down to Z = 0, through the window, so the ledges join them
        // by a FACE - meeting along an edge only is not manifold (docs/openscad-basics, lesson 2).
        // The one by the SGP41 is notched to ch_notch where the module overhangs its front end.
        for (xw = [ch_x0 - cradle_t, ch_x1]) difference() {
            translate([xw, back_t - eps, 0]) cube([cradle_t, y_ch1 - back_t + eps, z_sps1]);
            if (xw == ch_x1 && ch_notch < y_ch1)
                box3([xw - eps, ch_notch, gy_z0 - pocket_fit - rim_t - gap], [xw + cradle_t + eps, y_ch1 + eps, gy_z1 + gap]);
        }

        // the ledges the sensor stands on, one under each end of the air face
        translate([ch_x0 - cradle_t / 2, back_t - eps, 0]) cube([ledge_w + cradle_t / 2, sps_t + eps, z_sps0]);
        translate([ch_x1 - ledge_w, back_t - eps, 0]) cube([ledge_w + cradle_t / 2, sps_t + eps, z_sps0]);

        // the divider: it also carries the sensor, and stands proud below the box. It rises from
        // the very back (Y = 0) so that the part below the plate still starts on the bed.
        translate([x_div - divider_t / 2, 0, -divider_proud])
            cube([divider_t, y_in1 - part_fit, divider_proud + z_sps0]);

        // the board's two back clips
        for (c = clasp_xs) clip(c);
        // the back stop at its antenna end, which takes the push of plugging in
        box3([stop_x0, back_t - eps, z_f0], [stop_x0 + rim_t, y_b0 + stop_reach, zu + sm_pcb_t + 1]);

        // the filler in the cover's USB-C slot, behind the shell: a wall in the cover's wall's plane, its
        // end hollowed round the shell's end
        translate([0, 0, 0]) rotate([90, 0, 90]) linear_extrude(height = port_wall) difference() {
            translate([back_t - eps, z_uc - usb_fill_h]) square([y_bc - usb_open_c - back_t + eps, 2 * usb_fill_h]);
            translate([y_bc - usb_open_c, z_uc]) circle(r = usb_open_r, $fn = 48);
        }
        // the SGP41's post, rib and ledge
        gy_mount();
        // the channel its wires cross the SPS30's top-left corner in
        gy_channel();

        // the nut bosses in the bottom corners
        for (x = nut_bx) cyl_y(x, nut_bz, nut_boss_d / 2, back_t - eps, nut_boss_y1);
        // the bump at the top the cover locates on
        box3([bump_x0, back_t - eps, u_z0], [bump_x1, back_t + bump_out, bump_z1]);
    }
    // the nuts' pockets, open to the wall, and the screw holes over them
    for (x = nut_bx) nut_trap(x, nut_bz);
    // the SGP41's pilot, down into its post
    gy_pilot();
    // the keyholes: each an entry the wall screw's head passes, and the slot above it the head then
    // hangs over. Holes through the plate, so on the bed they are openings in the first layers.
    for (x = key_xs) {
        cyl_y(x, key_z0, hole_r(key_entry_d), -eps, back_t + eps);
        hull() for (z = [key_z0, key_z1]) cyl_y(x, z, hole_r(key_slot_w), -eps, back_t + eps);
    }
}

// =================================================================== the cover, as installed
module cover() place() {
    difference() {
        slab_xz(0, W, back_t, D, 0, H, corner_r);
        // hollow it: four walls and a front
        slab_xz(wall, W - wall, back_t - eps, y_in1, wall, H - wall, max(corner_r - wall, 0));
        // the window over the SPS30's air face - open at the back edge, so it is a notch, not a bridge
        translate([ch_x0 - cradle_t - part_fit, back_t - eps, -eps])
            cube([ch_in_w + 2 * (cradle_t + part_fit), y_in1 - back_t + eps, wall + 2 * eps]);
        // the right-hand wall over the board's USB-C end, thinned from inside to port_wall over the board's
        // whole width and height - a notch open at the back edge. Its steps back to the full wall are 45
        // degrees, not square: pulling the plug loads this stretch of wall, and a crack would start at a
        // sharp inside corner.
        hull() {
            box3([port_wall, back_t - eps, zu - part_fit],
                 [wall + eps, y_b1 + pocket_fit + part_fit, zu + sm_t + part_fit]);
            box3([wall - eps, back_t - eps, zu - part_fit - (wall - port_wall)],
                 [wall + eps, y_b1 + pocket_fit + part_fit + (wall - port_wall),
                  zu + sm_t + part_fit + (wall - port_wall)]);
        }
        // the USB-C opening through it: the shell's stadium, part_fit clear, round at its front end and
        // running on out to the cover's back edge, so the cover slides on past the shell. The cover prints
        // front face down, so that edge is the slot's top on the bed: open, it needs no bridge.
        translate([-eps, 0, 0]) rotate([90, 0, 90]) linear_extrude(height = port_wall + 2 * eps) hull() {
            translate([y_bc + usb_open_c, z_uc]) circle(r = usb_open_r, $fn = 48);
            translate([usb_notch_y0, z_uc - usb_open_r]) square([y_bc - usb_notch_y0, 2 * usb_open_r]);
        }
        // vents in the front: over the SGP41's lower half, where its sensor is, clear of the bottom
        // screw's boss below - and over the board
        vent_slots(gy_x0 + 1, gy_x1 - 1, max(gy_z0, nut_bz + nut_boss_d / 2 + gap), gy_z0 + gy_l / 2 + 2);
        vent_slots(max(sm_x0, wall + gap), min(sm_x1, W - wall - gap), zu + sm_t + gap, zu + sm_t + gap + 10);
        // the two bottom screws' counterbores and holes
        for (x = nut_bx) cover_screw_hole(x, nut_bz);
    }
    // the bosses behind them, which carry the counterbores' floors, the nut bosses' size. Standing on the
    // front, so on the cover's bed they are short columns.
    for (x = nut_bx) difference() {
        cyl_y(x, nut_bz, nut_boss_d / 2, cb_y0, y_in1 + eps);
        cover_screw_hole(x, nut_bz);
    }
    // the U at the top: two arms hanging from the top wall, either side of the plate's bump, from the
    // cover's front back to part_fit off the plate
    for (x = [bump_x0 - part_fit - rib_t, bump_x1 + part_fit])
        box3([x, back_t + part_fit, u_z0], [x + rib_t, y_in1 + eps, H - wall + eps]);
    // the partition between the inlet and outlet sides of the air gap in front of the sensor,
    // part_fit above the divider fin, which it slides past as the cover goes on
    translate([x_div - rib_t / 2, y_sps1 + sps_fit, z_sps0 + part_fit])
        cube([rib_t, y_in1 - y_sps1 - sps_fit + eps, sps_h - part_fit]);
    // the baffle that closes that air gap off from the compartment above, part_fit over the sensor's top.
    // With the partition it also keeps the SPS30 from tipping forward, sps_fit off its face.
    translate([ch_x0, y_sps1 + sps_fit, z_sps1 + part_fit])
        cube([ch_in_w, y_in1 - y_sps1 - sps_fit + eps, rib_t]);
    // the board's front clasp, from its 4th pin to its antenna end: a rim in front of its edge, a lip over
    // its pad strip and a ledge under it, pocket_fit clear - the front edge slips in as the cover goes on.
    // Ribs standing on the front, so on the cover's bed they are walls.
    box3([sm_lip_x0, y_b1 + pocket_fit, z_f0], [sm_lip_x1, y_in1 + eps, zu + sm_pcb_t + 2 * pocket_fit + rim_t]);
    box3([sm_lip_x0, y_b1 - sm_lip_over, zu + sm_pcb_t + 2 * pocket_fit],
         [sm_lip_x1, y_in1 + eps, zu + sm_pcb_t + 2 * pocket_fit + rim_t]);
    box3([sm_lip_x0, y_b1 - clasp_low, z_f0], [sm_lip_x1, y_in1 + eps, zu - pocket_fit]);
    box3([stop_x0, y_b1 - stop_reach, z_f0], [stop_x0 + rim_t, y_in1 + eps, zu + sm_pcb_t + 1]);
}

// =================================================================== the cover's way on
// The cover goes straight back onto the plate, over everything already on it. Relative to the cover, each
// part inside moves back to the plate as it comes on, so each is swept there here, piece by piece - a hull
// of the whole would fill in the gaps between them - and check_cover_on intersects the sweep with the
// cover as it sits. Alon, 4 Oct 2026, on the printed box: the USB-C socket stands out through the side
// wall, and the wall behind its opening ran into it, so the box could not close.
module cover_on_path(s = 0.02) place() {
    for (i = [0, 2, 3, 4]) hull() { sm_piece(i, s); translate([0, -D, 0]) sm_piece(i, s); }
    for (b = parts_boxes(s)) hull() { box3(b[0], b[1]); translate([0, -D, 0]) box3(b[0], b[1]); }
    hull() for (dy = [0, -D]) translate([0, dy, 0])
        box3([sps_x0 + s, back_t + s, z_sps0 + s], [sps_x1 - s, back_t + sps_t - s, z_sps1 - s]);
    hull() for (dy = [0, -D]) translate([0, dy, 0])
        box3([gy_x0 + s, gy_yp + s, gy_z0 + s], [gy_x1 - s, gy_yf + gy_sensor_h - s, gy_z1 - s]);
    hull() for (dy = [0, -D]) translate([0, dy, 0]) cyl_y(gy_hx, gy_hz, gy_head_d / 2 - s, gy_yf + s, gy_yf + gy_head_h - s);
}

// =================================================================== the SPS30's way in
// The sensor goes in from the front, before the cover: its outline, nubs included, swept from its seat to
// the cover's front. Nothing on the back plate may stand in it - check_insert intersects the two.
module sps_insert_path() place()
    translate([sps_x0 - sps_nub, back_t + 0.02, z_sps0 + 0.02])
        cube([sps_w + 2 * sps_nub, y_in1 - back_t, sps_h - 0.04]);

// =================================================================== the SuperMini, piece by piece
// Its parts' envelope as boxes: full depth between and beside the back clips, and where a clip is, only
// past the room it takes.
function parts_boxes(s) = let(
        y0 = y_b0 + sm_edge + s, y1 = y_b1 - sm_edge - s, z0 = zu + sm_pcb_t - s, z1 = zu + sm_t - s,
        xs = [sm_x0 + s, clasp_xs[0][0], clasp_xs[0][1], clasp_xs[1][0], clasp_xs[1][1], sm_x1 - s])
    concat([for (k = [0, 2, 4]) if (xs[k + 1] - xs[k] > 1e-6) [[xs[k], y0, z0], [xs[k + 1], y1, z1]]],
           [for (c = clasp_xs) [[c[0], back_t + clip_room + s, z0], [c[1], y1, z1]]]);
// Five pieces, so the slide-in check can sweep each one on its own.
module sm_piece(i, s) {
    if (i == 0)        // the bare PCB, level, held by its edges. The clips pinch it by clasp_pinch on purpose,
                       // so the checks - which draw it shrunk - take that much off its top as well.
        color("teal") box3([sm_x0 + s, y_b0 + s, zu + s], [sm_x1 - s, y_b1 - s, zu + sm_pcb_t - (s > 0 ? clasp_pinch : 0) - s]);
    else if (i == 1)   // its parts, up to the tallest, clear of the pad strip along each long edge - and, where
                       // the back clips are, of all the room clip_room says they have. Plain boxes, so that
                       // the slide-in check can sweep each one without filling in the clips' notches.
        color("teal") for (b = parts_boxes(s)) box3(b[0], b[1]);
    else if (i == 2)   // the USB-C shell, a stadium, overhanging the PCB through the wall's opening
        color("teal") hull() for (dy = [-1, 1])
            cyl_x(y_bc + dy * usb_open_c, z_uc, usb_shell_h / 2 - s, sm_usb_x - usb_overhang + s, sm_usb_x - s);
    else if (i == 3)   // the antenna loop, in the board's plane past its end
        color("orange") box3([sm_ant_x + s, y_b0 + ant_loop_free + s, zu + sm_pcb_t + s],
                             [sm_ant_x + ant_over - s, y_b1 - ant_loop_free - s, zu + sm_pcb_t + 1 - s]);
    else if (i == 4)   // the antenna's pole, standing up off the component side
        color("orange") translate([sm_ant_x - pole_in, y_bc, zu + sm_pcb_t + s])
            cylinder(r = 0.5 - s, h = ant_h - sm_pcb_t - 2 * s);
}

// The board's way in: each piece swept from in front, along Y, until its back edge is in the clips.
module sm_slide_path(s = 0.02) place() {
    for (i = [0, 2, 3, 4]) hull() { sm_piece(i, s); translate([0, D, 0]) sm_piece(i, s); }
    for (b = parts_boxes(s)) hull() { box3(b[0], b[1]); translate([0, D, 0]) box3(b[0], b[1]); }
}

// =================================================================== the components, for preview and checks
module components(shrink = 0) place() {
    s = shrink;
    color("silver") box3([sps_x0 + s, back_t + s, z_sps0 + s], [sps_x1 - s, back_t + sps_t - s, z_sps1 - s]);
    for (i = [0 : 4]) sm_piece(i, s);   // the SuperMini
    // the body of the largest compliant plug, seated, with the board pushed against its stops. Its
    // face can come right up to the socket's mouth, so that is where it is drawn.
    color("dimgray") box3([-usb_proud_in - 20 + s, y_bc - usb_plug_w / 2 + s, z_uc - usb_plug_h / 2 + s],
                          [-usb_proud_in - s, y_bc + usb_plug_w / 2 - s, z_uc + usb_plug_h / 2 - s]);
    // the GY-SGP41 lying flat: the PCB and its sensor towards the cover, and behind it the parts on its
    // underside - less the bare strip along its bottom edge, where the rib bears, and the bare patch round
    // its mounting hole, where the post does
    color("green") {
        box3([gy_x0 + s, gy_yu + s, gy_z0 + s], [gy_x1 - s, gy_yf + gy_sensor_h - s, gy_z1 - s]);
        difference() {
            box3([gy_x0 + s, gy_yp + s, gy_z0 + gy_bare + s], [gy_x1 - s, gy_yu + s, gy_z1 - s]);
            cyl_y(gy_hx, gy_hz, gy_hole_bare_d / 2 - s, gy_yp, gy_yu + 2 * s);
        }
    }
    // the SGP41 screw's head, between the module and the cover
    color("silver") cyl_y(gy_hx, gy_hz, gy_head_d / 2 - s, gy_yf + s, gy_yf + gy_head_h - s);
    // the SPS30's plug and the column its lead rises through before it bends over
    color("orange") box3([lead_x0 + s, back_t + s, z_sps1 + s], [lead_x1 - s, back_t + sps_t - s, z_sps1 + cable_zone_h - s]);
    // the wall screws' heads behind the plate, each all the way from its entry up to where it hangs,
    // standing off the wall by up to key_slack more than the plate is thick
    for (x = key_xs) color("silver") hull() for (z = [key_z0, key_z1])
        cyl_y(x, z, key_head_d / 2 - s, back_t + s, back_t + key_slack + key_head_h - s);
}

// =================================================================== what gets drawn
// Only when the box itself is drawn: the clearance test and the pictures include this file and say
// draw_model = false, and none of this is theirs to report.
if (draw_model) {
    if (len(unmeasured) > 0)
        echo(str("WARNING: ", len(unmeasured), " dimensions are placeholders, not measurements: ", unmeasured));
    if (len(untested_fits) > 0)
        echo(str("WARNING: these fits have not been tested in ASA on this printer: ", untested_fits));

    echo(str("print-chamber box: ", W, " x ", H, " x ", D, " mm (width x height x depth, installed), and the ",
             "divider ", divider_proud, " mm below"));
    echo(str("outlet at the ", outlet_at_left ? "LEFT" : "RIGHT", " end; divider at ", divider_from_inlet_end,
             " mm from the inlet end"));
    echo(str("keyholes: ", key_xs[1] - key_xs[0], " mm apart, the screws ", key_z1, " mm up once hung; each entry ",
             2 * hole_r(key_entry_d), " mm and slot ", 2 * hole_r(key_slot_w), " mm as cut; set the heads ",
             back_t, " to ", back_t + key_slack, " mm off the wall"));
    echo(str("board: in its clasps ", zu, " mm up, its pole's tip ", zu + ant_h, " mm, the top wall's inside ", H - wall,
             "; SGP41 flat, its sensor ", y_in1 - (gy_yf + gy_sensor_h), " mm behind the cover's vents, held by an M",
             gy_screw_d, " x ", gy_screw_l, " in a ", gy_pilot_depth, " mm pilot down a ", gy_post_y1 - back_t,
             " mm post; its underside parts ", gy_yp - ch_notch, " mm off the notched channel wall"));
    echo(str("cover: two M3 x ", cover_screw_l, ", heads flush in ", 2 * hole_r(cb_d), " mm counterbores ", cb_depth,
             " deep, into nuts whose shoulder is ", nut_y1,
             " mm from the back; its top locates on a ", bump_w, " mm bump in a U"));
    echo(str("USB-C: the socket's mouth stands ", usb_proud_in, " to ", usb_proud + part_fit,
             " mm past the outside face; the plug's body clears the mounting surface by ", y_bc - usb_plug_w / 2, " mm"));
}

if (draw_model) {
    if (part == "back")
        rotate([90, 0, 0]) back_plate();
    else if (part == "cover")
        translate([0, 0, D]) rotate([-90, 0, 0]) cover();
    else if (part == "assembly") {
        back_plate();
        %cover();
        %components();
    }
    else if (part == "check_parts")
        intersection() { back_plate(); cover(); }
    else if (part == "check_components")
        intersection() { union() { back_plate(); cover(); } components(shrink = 0.02); }
    else if (part == "check_insert")
        intersection() { back_plate(); sps_insert_path(); }
    else if (part == "check_slide")
        intersection() { back_plate(); sm_slide_path(); }
    else if (part == "check_cover_on")
        intersection() { cover(); cover_on_path(); }
    else
        assert(false, str("unknown part \"", part, "\" - use back, cover or assembly"));
}
