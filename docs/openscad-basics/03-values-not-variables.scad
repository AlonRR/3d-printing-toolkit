// Lesson 3 - names hold values, not variables
//
// The lesson that saves the most time. If you know Python or Rust, OpenSCAD's
// "variables" behave like none you have used: a name is bound to ONE value in a
// scope, and nothing can change it afterwards.
//
// Every result quoted below was measured on the 2021.01 release and on a 2026
// nightly, and the two agree. Press F5 and read the CONSOLE, not the viewport.

// ---------------------------------------------------------------------------
// 1. One value per scope - the last one assigned
// ---------------------------------------------------------------------------
// Uncomment the two lines below and press F5:
// a = 1;
// a = 2;
// Console:  WARNING: a was assigned on line .. but was overwritten ...
// Every use of `a` in this scope then sees 2.

// ---------------------------------------------------------------------------
// 2. Assignments run first, in order; everything else runs after
// ---------------------------------------------------------------------------
echo(seen_before_assignment = b);    // prints 7
b = 7;
// echo() and geometry see the FINAL value of every name in the scope, wherever
// they are written. Between assignments, though, order does matter:
// `c = d + 1;` written above `d = 5;` gives c = undef and two warnings.

// ---------------------------------------------------------------------------
// 3. A for loop cannot accumulate
// ---------------------------------------------------------------------------
total = 0;
for (i = [1:3]) {
    total = total + i;
    echo(inside_loop = i, total = total);
}
echo(after_loop = total);
// Console:  inside_loop = 1, total = 1
//           inside_loop = 2, total = 2     not 3
//           inside_loop = 3, total = 3     not 6
//           after_loop = 0                 the outer total never changed
//
// Each pass of a loop body is its own scope. There, `total = total + i` reads the
// OUTER total - always 0 - and binds a new inner one that is gone when the pass
// ends. Nothing flows from one pass to the next.

// ---------------------------------------------------------------------------
// 4. What to do instead: compute the value in one expression
// ---------------------------------------------------------------------------
// A recursive function:
function sum(v, i = 0) = i >= len(v) ? 0 : v[i] + sum(v, i + 1);
echo(sum_of_1_2_3 = sum([1, 2, 3]));                 // 6

// Or build the list you need with a list comprehension, then reduce it:
squares = [for (i = [1:3]) i * i];
echo(squares = squares, their_sum = sum(squares));   // [1, 4, 9], 14

// ---------------------------------------------------------------------------
// 5. Scope: a name bound inside a module stays inside it
// ---------------------------------------------------------------------------
module part() {
    inner = 42;
    echo(inside_part = inner);
}
part();
echo(outside_part_it_is_undef = is_undef(inner));    // true

// ---------------------------------------------------------------------------
// 6. The exception: $ variables pass DOWN into what you call
// ---------------------------------------------------------------------------
// $fn, $fa, $fs, and any name you start with $, travel into every module you
// call, as though they were an extra argument.
module disc() {
    echo(fn_inside_disc = $fn);
    cylinder(h = 1, d = 10);
}
disc($fn = 6);        // a hexagon, and the console says fn_inside_disc = 6

// ---------------------------------------------------------------------------
// 7. Overriding a value from an included file is silent - and it is the idiom
// ---------------------------------------------------------------------------
// `include <file>` pastes the file into this one. Binding one of its names again
// AFTER the include replaces it with no warning (measured). The models in this
// repository rely on that: a companion file includes a model, then sets
// `draw_model = false` to borrow its numbers without its geometry.

// ---------------------------------------------------------------------------
// 8. Numbers that print the same are not always equal
// ---------------------------------------------------------------------------
echo(layers_in_0_6 = 0.6 / 0.2);                     // prints 3
echo(exactly_3 = (0.6 / 0.2 == 3));                  // false: it is 2.9999999999999996
echo(close_to_3 = (abs(0.6 / 0.2 - 3) < 1e-6));      // true
// This is why every "is this a whole number of layers?" check in the models here
// compares with a tolerance - abs(x - round(x)) < 1e-6 - and never with ==.

// ---------------------------------------------------------------------------
// 9. Conditionals and let() are expressions
// ---------------------------------------------------------------------------
wall = 2.25;
role = wall >= 1.35 ? "structural" : "cosmetic";
echo(role = role);

area = let (w = 20, h = 10) w * h;
echo(area = area);

// ---------------------------------------------------------------------------
// TRY
// ---------------------------------------------------------------------------
//  1. Uncomment section 1 and read the warning.
//  2. Make section 3's loop print the running totals 1, 3, 6.
//     Hint: inside the loop, sum a list you build fresh on each pass.
//  3. Write a recursive function that returns the largest number in a list, and
//     check it against the built-in max([3, 9, 4]).
//  4. Try other heights in section 8. Which multiples of 0.2 compare exactly?
