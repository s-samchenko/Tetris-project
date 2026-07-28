# Tetris in MIPS Assembly — Design Notes

Serhii Samchenko · CSCB58, University of Toronto Scarborough
Target: MARS 4.5, bitmap display and memory-mapped keyboard

These are my design notes from the project, cleaned up and filled in after the fact.

## Setup

The display is 256x256 pixels at 8 pixels per unit, so a 32x32 grid of units I can
address. The playfield is 10 wide and 20 tall, placed at unit (4, 4), which leaves room on
the right for the next-piece panel.

There's no standard library and no OS underneath. Drawing means storing a color word at a
computed address in the framebuffer at `0x10008000`. Input means polling two registers,
`0xFFFF0000` for status and `0xFFFF0004` for the key, with no blocking read and no key-up
event. There's no timer I can read either, so gravity has to be counted in loop iterations
rather than seconds. Every subroutine manages its own stack and register saving.

## Board

Two arrays, 200 words each, both indexed `row * 10 + col`:

- `.board` — the color of each cell
- `.board_occupied` — 0 or 1, whether the cell blocks a piece

I kept them separate because different code reads them for different reasons. Collision
only cares about occupancy, so `scan_row` sums ten flags and compares against ten with no
color decoding. Rendering needs both: `render_board` checks the flag, paints the stored
color if it's set, and passes color 0 if it isn't. `paint_cell` treats 0 as "pick the
checkerboard shade from the parity of row + col", so the empty background is drawn by the
same path as everything else.

`shift_down` copies both arrays at once, so they can't get out of sync.

## Piece state

`cur_shape` (0-6), `cur_row`, `cur_col`, `cur_orient`, and `op_type` for the pending
action. `next_shape` holds the preview piece and starts at -1 to mark that nothing has
been generated yet.

A falling piece is never written into the board arrays. It's drawn straight to the
framebuffer and only committed to `.board_occupied` by `lock_piece` once it lands, which
means collision tests never see the piece itself and I don't have to exclude it.

## Shapes and rotation

Each tetromino is a table of cell offsets rather than a rotation formula. Four cells, two
words each, so 32 bytes per orientation, with orientations laid out back to back:

```
T_OFF:
    .word  0,  0      # orientation 0
    .word -1,  0
    .word  1,  0
    .word  0,  1
    .word  0,  0      # orientation 1
    ...
```

Orientation n starts at `base + n * 32`. The occupied cells are `(cur_row + dy,
cur_col + dx)` for each of the four entries, and rotating is incrementing `cur_orient`
and wrapping.

The wrap point differs by shape. O has one orientation, I, S and Z have two, and T, L and
J have four. For the two-orientation pieces the wrap is `xori $t1, $t1, 1`.

This costs about 90 lines of `.data` that a formula wouldn't need. In exchange the same
tables drive drawing, clearing, collision, spawn checks and the preview panel, and there's
no arithmetic to get wrong.

## Main loop and gravity

`main` clears the screen, draws the walls, grid and panel frame, fills the bottom five
rows, and spawns the first piece. Then `game_loop` runs three things forever:

- `handle_input` polls the keyboard and puts the ASCII code in `$s0`
- `update_piece` dispatches on `$s0` to a move, a rotation, or quit
- `handle_gravity` advances the gravity counter

Since there's no timer, gravity is an accumulator. Each pass through the loop adds
`gravity_step` to `gravity_counter`, and when the counter passes 1,000,000 it resets and
fires a drop. `clear_lines` raises `gravity_step` by 30 every five lines cleared, which is
the whole difficulty curve.

The drop isn't a direct call to `move_piece_down`. `handle_gravity` sets `$s0` to 'S', so
gravity goes through the same dispatch a keypress does. Both get the same collision checks
and the same lock-on-blocked behavior, and I only had to write it once.

Counting iterations does mean the fall speed depends on how fast the simulator runs rather
than on real seconds.

## Collision

Two levels. The lower one is a pair of predicates on a single coordinate:
`wall_collision_at_xy` returns 1 if x or y falls outside the playfield, and
`occupancy_collision_at_xy` returns 1 if `.board_occupied[y * 10 + x]` is set. Both are
short and hold no state.

The upper level tests the whole piece against a move that hasn't happened yet.
`wall_collision` and `occupancy_collision` read the piece state and `op_type`, work out
what the four cells would be after the operation, and call the predicate on each:

```
x, y, orient = cur_col, cur_row, cur_orient
switch op_type:
    LEFT   -> x -= 1
    RIGHT  -> x += 1
    DOWN   -> y += 1
    ROTATE -> orient = (orient + 1) mod orientations(shape)

for each of the 4 cells:
    if predicate(x + dx, y + dy): return 1
return 0
```

Nothing is modified until both tests come back clean, so there's no undo path anywhere in
the program. That mattered more than I expected when I chose it: undoing a move here means
restoring three globals and repainting the piece at its old position, and that's hard to
debug when it goes wrong.

A blocked move beeps and prints a trace log. The exception is a downward move, which means
the piece has landed, so that jumps to `lock_piece` instead.

## Line clearing

`lock_piece` writes the piece into `.board_occupied` and calls `clear_lines`.

`clear_lines` walks rows 0 through 19 and calls `scan_row` on each. A full row gets the
flash animation — red, white, red, with a delay between each and a beep — and then
`shift_down`, which copies every row above it down by one and zeros row 0. Both arrays
move together.

Going top to bottom handles several full rows in one pass without a second scan. After
clearing row r, the row that slides into r is the old row r-1, which the scan already
checked and found incomplete, so the loop can move straight on to r+1.

## Rendering

Everything on screen goes through `paint_unit(row, col, color)`, which computes
`0x10008000 + (row * 32 + col) * 4` and stores one word. It's the only place the
framebuffer is touched.

`paint_cell` sits above it. It takes playfield coordinates instead of screen coordinates,
records the color in `.board`, applies the checkerboard rule when the color is 0, and adds
the (4, 4) offset before calling `paint_unit`.

`draw_piece` and `clear_piece` are the same loop over a shape's offset table, one passing
the piece color and the other passing 0. Every move is `clear_piece`, update the
coordinate, `draw_piece`.

## Game over

Triggered by pressing Q, or by `check_spawn_collision` finding that a newly spawned piece
overlaps something already on the board.

The screen uses a 5x7 bitmap font I built by hand. Each glyph is 7 bytes, one row per
byte, using the low 5 bits:

```
FONT_G:
    .byte 14   # 01110
    .byte 17   # 10001
    .byte 16   # 10000
    ...
```

`FONT_TABLE` is an array of pointers to the glyphs spelling GAME OVER. `draw_game_over`
walks it, tests each bit, and paints a white unit where the bit is set, wrapping to a
second line after the fourth letter. Then it plays a short descending sequence with
syscall 31 and exits.

## Things I'd change

This was written feature by feature without a cleanup pass, and it shows in a few places.

The seven-way branch chain that picks a shape's offset table appears eight times, in
`load_piece`, `check_spawn_collision`, `wall_collision`, `occupancy_collision`,
`draw_piece`, `clear_piece`, `rotate_piece` and `draw_panel`. That's roughly 130 lines
doing one thing. A `SHAPE_TABLE` array of pointers indexed by shape code replaces each
copy with two instructions, and the same approach handles the per-shape orientation counts
and colors. I already did this for the font and didn't think to go back and apply it to
the shapes.

Gravity should read the system time instead of counting iterations.

The collision debug prints fire on every blocked move and fill the console. They were
useful while writing it and should be behind a flag rather than always on.

Also missing: hard drop, hold, a score display, and restart after game over.

## Reference

| Constant | Value | Meaning |
|---|---|---|
| `UNIT_PX` | 8 | pixels per unit |
| `UNITS_X` | 32 | units per framebuffer row |
| `BOARD_W` / `BOARD_H` | 10 / 20 | playfield size in units |
| `TL_ROW` / `TL_COL` | 4 / 4 | playfield origin |
| `ADDR_DSPL` | `0x10008000` | framebuffer base |
| `ADDR_KBD_STAT` | `0xFFFF0000` | keyboard status register |
| `ADDR_KBD_DATA` | `0xFFFF0004` | keyboard data register |

Syscalls used: 1 (print_int), 10 (exit), 11 (print_char), 31 (MIDI out), 42 (random int
in range).