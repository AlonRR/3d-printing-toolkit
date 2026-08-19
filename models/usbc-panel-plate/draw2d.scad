/*
draw2d.scad — the drafting primitives, shared by every diagram in this folder.

Dimension lines, leaders, arrowheads and axes. Nothing here knows anything about the plate; it draws distances between coordinates you give it.

The constants below are DEFAULTS. Assign them again after including this file and the new value wins globally — OpenSCAD resolves a variable to the last assignment in scope, which is the same mechanism parameter-map.scad uses to suppress the model with draw_model.

Kept in its own file because two diagrams now need it. A copy in each would drift, and a drifted drawing is worse than no drawing: it looks exactly as authoritative as a correct one.
*/

/* [Map layout] */
txt   = 0.78; /* text size */
lw    = 0.07; /* line weight */
ah    = 0.55; /* arrowhead length */
sec_y = -38.0; /* where the section view sits */
zs    = 3.0; /* Z exaggeration on the section (and everything drawn on it) */

/* Colour groups. Each family of measurements gets one, and the key repeats it. */
C_OUT  = [0.13, 0.13, 0.13]; /* plate outline */
C_PORT = [0.80, 0.28, 0.10]; /* the port opening / lip */
C_FIX  = [0.10, 0.42, 0.75]; /* fasteners */
C_POCK = [0.45, 0.20, 0.60]; /* pocket and boss */
C_STAGE= [0.05, 0.50, 0.35]; /* the staged bridge layers */
C_PART = [0.62, 0.72, 0.85]; /* the part itself */

module arrow_at(p, ang, col) {
    color(col) translate(p) rotate(ang)
        polygon([[0, 0], [-ah, ah * 0.32], [-ah, -ah * 0.32]]);
}

/*
Horizontal dimension: measures x1..x2, drawn at height y_dim, with extension lines reaching back to the feature at y_feat.
*/
module dim_h(x1, x2, y_dim, y_feat, label, col = C_OUT, above = true) {
    over = (y_dim > y_feat) ? 0.5 : -0.5;
    color(col) {
        for (x = [x1, x2]) /* extension lines */
            translate([x - lw / 2, min(y_feat, y_dim + over)])
                square([lw, abs(y_dim + over - y_feat)]);
        translate([x1, y_dim - lw / 2]) square([x2 - x1, lw]); /* dim line */
    }
    arrow_at([x1, y_dim], 0, col);
    arrow_at([x2, y_dim], 180, col);
    color(col) translate([(x1 + x2) / 2,
                          y_dim + (above ? txt * 0.55 : -txt * 1.5)])
        text(label, size = txt, halign = "center",
             font = "DejaVu Sans:style=Bold");
}

/*
Vertical dimension: measures y1..y2, drawn at x_dim, extensions to x_feat. Text sits beside the line rather than rotated on it — easier to read, and this is a reference drawing rather than a manufacturing print.
*/
module dim_v(y1, y2, x_dim, x_feat, label, col = C_OUT, right = true) {
    over = (x_dim > x_feat) ? 0.5 : -0.5;
    color(col) {
        for (y = [y1, y2]) /* extension lines */
            translate([min(x_feat, x_dim + over), y - lw / 2])
                square([abs(x_dim + over - x_feat), lw]);
        translate([x_dim - lw / 2, y1]) square([lw, y2 - y1]); /* dim line */
    }
    arrow_at([x_dim, y1], 90, col);
    arrow_at([x_dim, y2], 270, col);
    color(col) translate([x_dim + (right ? 0.5 : -0.5), (y1 + y2) / 2 - txt * 0.36])
        text(label, size = txt, halign = right ? "left" : "right",
             font = "DejaVu Sans:style=Bold");
}

/* Leader line — for things that are a feature, not a span (the notches). */
module leader(at, from, label, col = C_OUT) {
    d = from - at; u = d / norm(d);
    color(col) {
        hull() {
            translate(at + u * 0.1) circle(r = lw / 2);
            translate(from - u * ah) circle(r = lw / 2);
        }
        translate(at - [0, txt * 0.36] - u * 0.4)
            text(label, size = txt, halign = (at.x < from.x) ? "right" : "left",
                 font = "DejaVu Sans:style=Bold");
    }
    arrow_at(from, atan2(-u.y, -u.x), col);
}

module heading(t, at, col = C_OUT) {
    color(col) translate(at) text(t, size = txt * 1.25,
                                  font = "DejaVu Sans:style=Bold");
}

module axis(label, ang, len, col = C_OUT) {
    color(col) {
        rotate(ang) translate([0, -lw / 2]) square([len - ah, lw]);
        translate([cos(ang) * (len + 0.85) - txt * 0.32,
                   sin(ang) * (len + 0.85) - txt * 0.4])
            text(label, size = txt, font = "DejaVu Sans:style=Bold");
    }
    arrow_at([cos(ang) * len, sin(ang) * len], ang + 180, col);
}


/*
Dashed run from a to b — the convention for something whose size is NOT known. Everything drawn dashed in these diagrams is a value still to be measured, so a solid line always means "this number is real".
*/
module dashed(a, b, dash = 0.55, gap = 0.34, col = [0.1, 0.1, 0.1]) {
    d = b - a; L = norm(d); n = floor(L / (dash + gap));
    u = d / L;
    color(col) for (i = [0 : max(n, 0)]) {
        s = i * (dash + gap);
        e = min(s + dash, L);
        if (e > s)
            hull() { translate(a + u * s) circle(r = lw / 2);
                     translate(a + u * e) circle(r = lw / 2); }
    }
}

/* Dashed rectangle, centred, for an outline of unknown size. */
module dashed_rect(w, h, col = [0.1, 0.1, 0.1]) {
    dashed([-w/2, -h/2], [ w/2, -h/2], col = col);
    dashed([ w/2, -h/2], [ w/2,  h/2], col = col);
    dashed([ w/2,  h/2], [-w/2,  h/2], col = col);
    dashed([-w/2,  h/2], [-w/2, -h/2], col = col);
}

/* Dashed rectangle centred on an arbitrary point. */
module dashed_rect_at(w, h, at, col = [0.1, 0.1, 0.1]) {
    translate(at) dashed_rect(w, h, col);
}
