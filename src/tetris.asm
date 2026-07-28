#####################################################################
# CSCB58 Summer 2025 Assembly Final Project - UTSC
# Serhii Samchenko, s.samchenko@mail.utoronto.ca
# Bitmap Display Configuration:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestones have been reached in this submission?
# - Milestones 1, 2, 3, 4, 5
#
# Which approved features have been implemented? [Scored 11 points in total]
# Easy Features: [7 in total]
# 1. Implement gravity, so that each second that passes will automatically move the tetromino down one row.
# 2. Have the speed of gravity increase after the player completes a certain number of rows (5)
# 3. When the player has reached the “game over” condition, display a Game Over screen in pixels on the screen [no restart option though]
# 4. Add sound effects for different conditions. [only added for game_over, after line has been completed and when move causes collision]
# 7. Start the level with 5 random unfinished rows on the bottom of the playing field.
# 11. Make sure that each tetromino type is a different colour.
# 12. Have a panel on the side that displays a preview of the next tetromino that will appear 
# Hard Features: [2 in total]
# 2. Implement the full set of tetrominoes.
# 4. Add some animation to lines when they are completed 
# 
# How to play:
# Game starts with 5 unfinished rows and a tetromino spawned at top center. Use 'a' to move it left, 'd' to move right, 's' to move down,
# 'w' to rotate and 'q' to finish the game. Commands 'A', 'D', 'W', 'S', 'Q' are equivalent. If spawning a new tetromino causes a collision,
# it's considered the game over.

# Link to video demonstration for final submission: 
# https://www.youtube.com/watch?v=VnhEV3i1An4
# 
# link to Project Design pdf
# https://docs.google.com/document/d/1PMNCZTk4l-XeYBM-uint1vmdsfXQju504vmkj02Uw4A/edit?usp=sharing
# Are you OK with us sharing the video with people outside course staff?
# yes
#
# Any additional information that the TA needs to know:
# I implemented 7 easy features and 2 hard features which is more than was required. So, I guess if e.g. you decide that
# one my features doesn't deserve full marks, you can count the extra feature for my final score instead
#
#####################################################################

#------------------------------------------------------------------------------
# constants
#------------------------------------------------------------------------------
.eqv UNIT_PX 8 # pixels per unit                    
.eqv UNITS_X 32 # units per row/col (256px/8px)             
.eqv BOARD_W 10 # playfield width                  
.eqv BOARD_H 20 # playfield height                
.eqv TL_ROW 4 # top-left row of playfield                  
.eqv TL_COL 4 # top-left col of playfield                  
.eqv CLEAR_SCREEN 1024 # UNITS_X^2 for clear                   
.eqv N_SHAPES 7 # number of free tetromino shapes     

#------------------------------------------------------------------------------
# color constants
#------------------------------------------------------------------------------
.eqv C_BLACK 0x000000 # background black                       
.eqv C_WALL 0x808080  # grey walls                              
.eqv C_GREY_DK 0x202020  # dark grid                               
.eqv C_GREY_LT 0x505050  # light grid                              
.eqv C_I 0x00FFFF  # cyan (I-piece)                          
.eqv C_O 0xFFFF00  # yellow (O-piece)                        
.eqv C_L 0xFFA500  # orange (L-piece)                        
.eqv C_S 0x00FF00  # green (S-piece)                         
.eqv C_T 0xFFC0CB  # pink (T-piece)                        
.eqv C_Z 0xFF0000  # white (Z-piece)                         
.eqv C_J 0x0096FF  # bright blue (J-piece)         
.eqv C_WHITE 0xFFFFFF # white color           
.eqv C_RED 0xFF0000 # red color      

#------------------------------------------------------------------------------
# hardware adresses
#------------------------------------------------------------------------------
.eqv ADDR_DSPL 0x10008000 # VRAM base    
.eqv ADDR_KBD_STAT, 0xffff0000 # Keyboard Status Register: non-zero when a new keypress is available         
.eqv ADDR_KBD_DATA, 0xffff0004 # Keyboard Data Register: read ASCII code of the last keypress        

#------------------------------------------------------------------------------
# action constants
#------------------------------------------------------------------------------
.eqv ACT_LEFT 0
.eqv ACT_RIGHT 1
.eqv ACT_DOWN 2
.eqv ACT_ROTATE 3

#------------------------------------------------------------------------------
# shape codes
#------------------------------------------------------------------------------
.eqv SH_I 0 # I code
.eqv SH_O 1 # O code
.eqv SH_T 2 # T code
.eqv SH_S 3 # S code
.eqv SH_Z 4 # Z code
.eqv SH_L 5 # L code
.eqv SH_J 6 # J code

#------------------------------------------------------------------------------
# next piece panel constants
#------------------------------------------------------------------------------
.eqv PANEL_ROW 10 # location of the panel grid
.eqv PANEL_COL 20 
.eqv PANEL_FRAME_W 4 # size of the panel grid
.eqv PANEL_FRAME_H 3

                .data
cur_shape: .word 0 # 0-6
next_shape: .word -1 # shape of the next tetromino (initially -1)
cur_row: .word TL_ROW # current tetromino's row index
cur_col: .word TL_COL # current tetromino's column index
cur_orient: .word 0 # rotation supporter
op_type: .word # 0 = left, 1 = right, 2 = down, 3 = rotate
.board: .space 800 # Game board storage: 10 columns * 20 rows = 200 cells, each 4 bytes
.board_occupied: .space 800 # stores occupied cells

last_key: .word 0 # stores the ASCII code from the most recent read_char syscall (0 if none)
msg_wall_collision:
    .asciiz "Wall collision happened\n" # debug message
msg_occupancy_collision:
    .asciiz "Occupancy collision happened\n" # debug message
msg_speed_increased:
    .asciiz "Speed was increased\n" # debug message
msg_game_over:
    .asciiz "Game over\n" # debug message
gravity_counter: .word 0 # gravity counter
gravity_step: .word 30 # gravity step, used when filled certain amount of lines
total_lines: .word 0 # total number of lines we have cleared
next_speedup_at: .word 5 # the next milestone of lines when we speed up

#------------------------------------------------------------------------------
# offset tables for tetromino handling
#------------------------------------------------------------------------------

# I-piece offsets (pos=0 vertical, pos=1 horizontal), 16 words total
I_OFF:
    # orientation 0
    .word 0, 0
    .word -1, 0
    .word 1, 0
    .word 2, 0
    # orientation 1
    .word 0, 0
    .word 0, -1
    .word 0, 1
    .word 0, 2
    
# O-piece offset table (1 orientation)
O_OFF:
    .word 0, 0 # dx=0, dy=0
    .word 1, 0 # dx=+1, dy=0
    .word 0, 1 # dx=0,  dy=+1
    .word 1, 1 # dx=+1, dy=+1
    
# T-piece offsets (4 orientations)
T_OFF:
    # orientation 0
    .word 0, 0
    .word -1, 0
    .word 1, 0
    .word 0, 1
    # orientation 1
    .word 0, 0
    .word 0, -1
    .word 0, 1
    .word 1, 0
    # orientation 2
    .word 0, 0
    .word -1, 0
    .word 1, 0
    .word 0, -1
    # orientation 3
    .word 0, 0
    .word 0, -1
    .word 0, 1
    .word -1, 0

# S-piece offsets (2 orientations)
S_OFF:
    # orientation 0
    .word 0, 0
    .word 1, 0
    .word 0, 1
    .word -1, 1
    # orientation 1
    .word 0, 0
    .word 0, 1
    .word 1, 0
    .word 1, -1

# Z-piece offsets (2 orientations)
Z_OFF:
    # orientation 0
    .word 0, 0
    .word -1, 0
    .word 0, 1
    .word 1, 1
    # orientation 1
    .word 0, 0
    .word 0, -1
    .word 1, 0
    .word 1, 1

# L-piece offsets (4 orientations)
L_OFF:
    # orientation 0
    .word 0, 1
    .word 0, 0
    .word 0, 2
    .word 1, 2
    # orientation 1
    .word 0, 1
    .word -1, 1
    .word 1, 1
    .word 1, 0
    # orientation 2
    .word 0, 1
    .word 0, 0
    .word 0, 2
    .word -1, 0
    # orientation 3
    .word 0, 1
    .word -1, 1
    .word 1, 1
    .word -1, 2

# J-piece offsets (4 orientations)
J_OFF:
    # orientation 0
    .word 0, 1
    .word 0, 0
    .word 0, 2
    .word -1, 2
    # orientation 1
    .word 0, 1
    .word -1, 1
    .word 1, 1
    .word 1, 2
    # orientation 2
    .word 0, 1
    .word 0, 0
    .word 0, 2
    .word 1, 0
    # orientation 3
    .word 0, 1
    .word -1, 1
    .word 1, 1
    .word -1, 0

#------------------------------------------------------------------------------
# Fonts to display GAME OVER screen
#------------------------------------------------------------------------------

FONT_G:
    .byte 14 # 01110  
    .byte 17 # 10001  
    .byte 16 # 10000  
    .byte 23 # 10111  
    .byte 17 # 10001  
    .byte 17 # 10001  
    .byte 14 # 01110  

FONT_A:
    .byte 14 # 01110  
    .byte 17 # 10001  
    .byte 17 # 10001  
    .byte 31 # 11111  
    .byte 17 # 10001  
    .byte 17 # 10001  
    .byte 17 # 10001  

FONT_M:
    .byte 17 # 10001  
    .byte 27 # 11011  
    .byte 21 # 10101  
    .byte 21 # 10101  
    .byte 17 # 10001  
    .byte 17 # 10001  
    .byte 17 # 10001  

FONT_E:
    .byte 31 # 11111  
    .byte 16 # 10000  
    .byte 16 # 10000  
    .byte 30 # 11110  
    .byte 16 # 10000  
    .byte 16 # 10000  
    .byte 31 # 11111  

FONT_O:
    .byte 14 # 01110  
    .byte 17 # 10001  
    .byte 17 # 10001  
    .byte 17 # 10001  
    .byte 17 # 10001  
    .byte 17 # 10001  
    .byte 14 # 01110  

FONT_V:
    .byte 17 # 10001  
    .byte 17 # 10001  
    .byte 17 # 10001  
    .byte 17 # 10001  
    .byte 17 # 10001  
    .byte 10 # 01010  
    .byte 4  # 00100  

FONT_R:
    .byte 30 # 11110  
    .byte 17 # 10001  
    .byte 17 # 10001  
    .byte 30 # 11110  
    .byte 20 # 10100  
    .byte 18 # 10010  
    .byte 17 # 10001  

FONT_TABLE:
    .word FONT_G
    .word FONT_A
    .word FONT_M
    .word FONT_E
    .word FONT_O
    .word FONT_V
    .word FONT_E
    .word FONT_R

.text
.globl main

#------------------------------------------------------------------------------
# main: init, draw scene, enter game loop                                        
#------------------------------------------------------------------------------
main:
    # init everything
    jal init_game
    jal draw_walls
    jal draw_grid
    jal draw_panel_walls # draw next tetromino panel
    jal spawn_initial_rows # easy feature 7
    jal simple_delay
    jal clear_lines # clear lines if we generated some full ones
    
    jal init_piece # spawn first tetromino
    
game_loop:
    
    jal handle_input # reads key, sets move/rotate/drop flags
    jal update_piece # calls try_move/try_rotate or locks & spawns
    jal handle_gravity # increment gravity counter
    j game_loop # repeat forever until press quit or game over

#------------------------------------------------------------------------------
# handle_gravity: simulate gravitation by gradually increasing counter.
# if it exceeds the threshold, reset and apply move_down                           
#------------------------------------------------------------------------------
handle_gravity:
    addiu $sp, $sp, -28
    sw $ra, 0($sp)
    sw $t0, 4($sp)
    sw $t1, 8($sp)
    sw $t2, 12($sp)
    sw $t3, 16($sp)
    sw $t4, 20($sp)
    sw $t5, 24($sp)

    # Load & increment gravity_counter
    la $t0, gravity_counter
    lw $t1, 0($t0) # t1 = gravity_counter
    la $t2, gravity_step
    lw $t3, 0($t2) # t3 = gravity_step
    addu $t1, $t1, $t3 # t1 += gravity_step
    sw $t1, 0($t0)

    # Compare t1 > some constant
    li $t4, 1000000
    slt $t5, $t4, $t1
    beqz $t5, hg_done # if t1 <= constant, no drop needed

    # Threshold exceeded: drop and reset counter
    jal simulate_S

    # reset gravity_counter
    li $t1, 0
    sw $t1, 0($t0)

hg_done:
    lw $ra, 0($sp)
    lw $t0, 4($sp)
    lw $t1, 8($sp)
    lw $t2, 12($sp)
    lw $t3, 16($sp)
    lw $t4, 20($sp)
    lw $t5, 24($sp)
    addiu $sp, $sp, 28
    jr $ra
        
simulate_S:
    li $s0, 'S' # pretend the user just hit S
    jr $ra
 
#------------------------------------------------------------------------------
# init_piece: choose cur_shape from next_shape (or random on first call),
# pick a new next_shape, update panel, and spawn piece at top-center
#------------------------------------------------------------------------------
init_piece:
    addiu $sp,$sp,-8
    sw $ra,4($sp)

    # calculate cur_shape
    lw $t0,next_shape # t0 = next_shape
    li $t1,-1 # check if it's first time calling it
    beq $t0,$t1, first_time

    # if next_shape != -1, use it
    sw $t0,cur_shape
    j generate_next

first_time:
    # first time through, pick cur_shape at random
    jal random_shape
    sw $v0, cur_shape

generate_next:
    # pick the next_shape for panel
    jal random_shape
    sw $v0,next_shape

    # redraw preview panel
    jal draw_panel_walls
    jal draw_panel

    # spawn the current piece
    jal spawn_piece_center

    lw $ra,4($sp)
    addiu $sp,$sp,8
    jr $ra

#------------------------------------------------------------------------------
# handle_input: read keyboard MMIO and set action flags
#------------------------------------------------------------------------------
handle_input:
    addiu $sp, $sp, -16
    sw $ra, 0($sp)
    sw $t0, 4($sp)
    sw $t1, 8($sp)
    
    # read keyboard status
    li $t0, ADDR_KBD_STAT
    lw $t1, 0($t0) # t1 = status (0=no key, 1=ready)
    beqz $t1, no_key

    # a new key is waiting; read it
    li $t0, ADDR_KBD_DATA
    lw $t1, 0($t0) # t1 = ASCII code
    move $s0, $t1
no_key:
    lw $ra, 0($sp)
    lw $t0, 4($sp)
    lw $t1, 8($sp)
    addiu $sp, $sp, 16
    jr $ra

#------------------------------------------------------------------------------
# update_piece: based on $s0, calls the corresponding command (move, rotate, quit, etc)
#------------------------------------------------------------------------------
update_piece:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)
    
    move $t0, $s0 # t0 = last key ASCII

    lw $a0, cur_col
    lw $a1, cur_row
    lw $a2, cur_shape
    lw $a3, cur_orient
    # make commands case-insensitive
    # move left on 'A' or 'a'
    li $t1, 'A'
    beq $t0, $t1, do_left
    li $t1, 'a'
    beq $t0, $t1, do_left
    # move right on 'D'
    li $t1, 'D'
    beq $t0, $t1, do_right
    li $t1, 'd'
    beq $t0, $t1, do_right
    # drop on 'S'
    li $t1, 'S'
    beq $t0, $t1, do_drop
    li $t1, 's'
    beq $t0, $t1, do_drop
    # rotate on 'W'
    li $t1, 'W'
    beq $t0, $t1, do_rotate
    li $t1, 'w'
    beq $t0, $t1, do_rotate
    # quit on 'Q'
    li $t1, 'Q'
    beq $t0, $t1, game_over
    li $t1, 'q'
    beq $t0, $t1, game_over

    j up_done # no recognized key

# keyboard handlers
do_left:
    li $t0, ACT_LEFT
    sw $t0, op_type # set op_type
    jal wall_collision
    bnez $v0, w_collision # if collision, skip move
    jal occupancy_collision
    bnez $v0, o_collision
    lw $t2, cur_shape # otherwise, load current shape and proceed with move
    jal move_piece_left
    j up_done # otherwise when didnt recognize anything
 
# same for the other keyboard commands
do_right:
    li $t0, ACT_RIGHT
    sw $t0, op_type
    jal wall_collision
    bnez $v0, w_collision
    jal occupancy_collision
    bnez $v0,o_collision
    lw $t2, cur_shape
    jal move_piece_right
    j up_done

# if pressed and collision happens -> lock the piece
do_drop:
    move $s0, $zero
    li $t0, ACT_DOWN
    sw $t0, op_type
    jal wall_collision
    bnez $v0, lock_piece
    jal occupancy_collision
    bnez $v0, lock_piece
    lw $t2, cur_shape
    jal move_piece_down
    j up_done

do_rotate:
    li $t0, ACT_ROTATE
    sw $t0, op_type
    jal wall_collision
    bnez $v0, w_collision
    jal  occupancy_collision
    bnez $v0,o_collision
    lw $t2, cur_shape
    jal rotate_piece
    j up_done

# debug print
w_collision:
    jal print_wall_collision
    li $v0, 31
    li $a0, 65
    li $a1, 100 # duration
    li $a2, 4 # instrument
    li $a3, 200 # loudness
    syscall
    j up_done

# debug print
o_collision:
    jal print_occupancy_collision
    li $v0, 31
    li $a0, 65
    li $a1, 100 # duration
    li $a2, 4 # instrument
    li $a3, 200 # loudness
    syscall
    j up_done

#------------------------------------------------------------------------------
# lock_piece: handle a landed tetromino
#------------------------------------------------------------------------------
lock_piece:
    jal load_piece
    jal clear_lines # check for line clearing
    jal render_board # redraw everything
    jal init_piece # spawn a new piece & update panel
    j up_done

up_done: 
    move $s0, $zero # clearing the last key register
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra

quit_game:
    j quit # jumps to the quit label

#------------------------------------------------------------------------------
# game_over: plays music after game over and then quits the program
#------------------------------------------------------------------------------
game_over:
    jal print_game_over
    jal init_game
    jal draw_game_over
    li $t9, 5
    
music_loop:
    
    li $v0, 31
    li $a0, 65
    addu $a0, $a0, $t9
    li $a1, 2300 # duration
    li $a2, 37 # instrument
    li $a3, 1000 # loudness
    syscall

    jal simple_delay
    
    li $v0, 31
    li $a0, 70
    addu $a0, $a0, $t9
    syscall
    
    jal simple_delay
    
    li $v0, 31
    li $a0, 65
    addu $a0, $a0, $t9
    syscall
    
    jal simple_delay
    
    addi $t9, $t9, -1
    bnez $t9, music_loop

game_over_done:
    jal quit_game
    
#------------------------------------------------------------------------------
# load_piece: Marks the current piece in .board_occupied
#------------------------------------------------------------------------------
load_piece:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)
    lw $t0, cur_col # t0 = cur_col
    lw $t1, cur_row # t1 = cur_row
    lw $t2, cur_shape # t2 = cur_shape
    lw $t3, cur_orient # t3 = cur_orient

    li $t5,4 # num of cells (all shapes have 4)
    # select shape
    li $t4,SH_I
    beq $t2,$t4,load_I
    li $t4,SH_O
    beq $t2,$t4,load_O
    li $t4,SH_T
    beq $t2,$t4,load_T
    li $t4,SH_S
    beq $t2,$t4,load_S
    li $t4,SH_Z
    beq $t2,$t4,load_Z
    li $t4,SH_L
    beq $t2,$t4,load_L
    j load_J # otherwise J

load_I:
    la $t4, I_OFF
    j load_done
load_O:
    la $t4, O_OFF
    j load_done

load_T:
    la $t4, T_OFF
    j load_done

load_S:
    la $t4, S_OFF
    j load_done

load_Z:
    la $t4, Z_OFF
    j load_done

load_L:
    la $t4, L_OFF
    j load_done

load_J:
    la $t4, J_OFF

load_done:
    # t4 = OFFSET_TABLE[0][0]
    mul $t6, $t3, $t5
    sll $t6, $t6, 3
    addu $t4, $t4, $t6

    # loop over each of the 4 blocks
    li $t6, 0 # index i = 0

load_piece_loop:
    lw $s0, 0($t4) # s0 = dx
    lw $s1, 4($t4) # s1 = dy
    addu $s2, $t1, $s1 # s2 = cur_row + dy
    addu $s3, $t0, $s0 # s3 = cur_col + dx

    # compute idx = row * BOARD_W + col
    li $s4, BOARD_W
    mul $s5, $s2, $s4
    addu $s5, $s5, $s3
    sll $s5,$s5,2

    # store 1 in .board_occupied[idx]
    la $s6, .board_occupied
    addu $s6, $s6, $s5
    li $t7, 1
    sw $t7, 0($s6)

    # advance to next block
    addiu $t4, $t4, 8 # go to next (dx,dy)
    addiu $t6, $t6, 1
    blt $t6, $t5, load_piece_loop
    
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra


#------------------------------------------------------------------------------
# clear_lines: scan each row of .board_occupoed, remove full ones, shift down everything above 
# C++ code: https://ideone.com/8DqKWy
#------------------------------------------------------------------------------
clear_lines:
    addiu $sp,$sp,-4
    sw $ra,0($sp)

    li $t0, 0 # row = 0
    li $t1, 0 # ok = false

clear_lines_loop:
    li $t2,20
    beq $t0,$t2,clear_lines_done

    move $a0,$t0
    jal scan_row
    beqz $v0, clear_lines_next # row is not full

    # full: shift_down(row)
    la $t2, total_lines
    lw $t3, 0($t2)
    addi $t3, $t3, 1 # increment number of cleared rows
    sw $t3, 0($t2) # store back
    
    move $a0, $t0
    jal clear_line_animation
    jal render_board
    li $t1, 1

clear_lines_next:
    addiu $t0,$t0,1
    j clear_lines_loop

clear_lines_done:
    beqz $t1,clear_lines_ret
    jal simple_delay
    jal render_board 
       
    la $t2, total_lines
    lw $t3, 0($t2)
    # check if we reached the milestone
    la $t4, next_speedup_at
    lw $t5, 0($t4) # t5 = next_speedup_at
    slt $t6, $t5, $t3
    beqz $t6, clear_lines_ret # we didn't reach it yet
    # time to speed up
    la $t7, gravity_step
    lw $t8, 0($t7)
    addiu $t8, $t8, 30 # increase step step by 30
    sw $t8, 0($t7)
    jal print_speed_increased

    addiu $t5, $t5, 5 # next_speedup_at += 5
    sw $t5, 0($t4)

clear_lines_ret:
    lw $ra,0($sp)
    addiu $sp,$sp,4
    jr $ra
    
#------------------------------------------------------------------------------
# clear_line_animation: When the line is completed, flash it red, white, and red again
# (with delay) and then delete it
#------------------------------------------------------------------------------
clear_line_animation:
    addiu $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)

    li $s0, BOARD_W
    move $s1, $a0 # row to animate

    # flash sequence: red, white, red
    li $t7, 3 # 3 flashes
flash_loop:
    # pick color: iteration 1 & 3 = red, iteration 2 = white
    li $t8, 2
    beq $t7, $t8, use_white
    li $a2, C_RED
    j color_ready
use_white:
    li $a2, C_WHITE
color_ready:
    li $t0, 0
paint_row:
    move $a0, $s1 # row
    move $a1, $t0 # col
    jal paint_cell
    addiu $t0, $t0, 1
    blt $t0, $s0, paint_row

    jal simple_delay # have a delay

    addiu $t7, $t7, -1
    bgtz $t7, flash_loop

    li $v0, 31
    li $a0, 65
    li $a1, 2300 # duration
    li $a2, 1 # instrument
    li $a3, 1000 # loudness
    syscall
    
    # now shift the row down
    move $a0, $s1
    jal shift_down

    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addiu $sp, $sp, 12
    jr $ra

#------------------------------------------------------------------------------
# scan_row(row): returns v0=1 if row full, otherwise 0
#------------------------------------------------------------------------------
scan_row:
   addiu $sp,$sp,-12
   sw $ra,8($sp)
   sw $s0,4($sp)
   sw $t0,0($sp)

   move $s0,$a0 # s0 = y
   li $t0,0 # sum = 0
   li $t1,0 # x = 0

scan_row_loop:
    li $t2,10
    beq $t1, $t2, scan_row_done

    # idx = y*10 + x
    mul $t3,$s0,$t2 # t3 = y*10
    addu $t3,$t3,$t1 # t3 = idx
    sll $t3,$t3,2 # byte offset

    la $t4, .board_occupied
    addu $t4,$t4,$t3
    lw $t5,0($t4) # flag in occupied
    addu $t0,$t0,$t5 # sum += flag

    addiu $t1,$t1,1
    j scan_row_loop

scan_row_done:
    li $v0,0
    li $t2,10
    beq $t0, $t2, scan_row_full
    j scan_row_ret

scan_row_full:
    li $v0,1

scan_row_ret:
    lw $t0,0($sp)
    lw $s0,4($sp)
    lw $ra,8($sp)
    addiu $sp,$sp,12
    jr $ra

#------------------------------------------------------------------------------
# shift_down(row): shift rows y=row..1 down. Clears row 0
#------------------------------------------------------------------------------
shift_down:
   addiu $sp,$sp,-16
   sw $ra,12($sp)
   sw $s0,8($sp)
   sw $s1,4($sp)

   move $s0,$a0 # s0 = y

   li $t2,BOARD_W

# outer loop: for (y = row; y > 0; --y)
sd_outer:
    blez $s0, sd_clear_top # if y<=0, skip to clear
    li $s1, 0 # x=0
sd_inner:
    beq $s1,$t2,sd_next_row

    # dest = y*10 + x
    mul $t3,$s0,$t2 # t3 = y*10
    addu $t3,$t3,$s1
    sll $t3,$t3,2 # byte offset

    # src = (y-1)*10 + x
    addiu $t4,$s0,-1
    mul $t4,$t4,$t2
    addu $t4,$t4,$s1
    sll $t4,$t4,2

    # board[dest] = board[src]
    la $t5, .board
    addu $t6,$t5,$t4
    lw $t0,0($t6)
    addu $t6,$t5,$t3
    sw $t0,0($t6)

    # board_occupied[dest] = board_occupied[src]
    la $t5,.board_occupied
    addu $t6,$t5,$t4
    lw $t0,0($t6)
    addu $t6,$t5,$t3
    sw $t0,0($t6)

    addiu $s1,$s1,1
    j sd_inner

sd_next_row:
    addiu $s0,$s0,-1
    j sd_outer

# clear row 0
sd_clear_top:
    li $s1,0
sd_clear_top_loop:
    beq $s1,$t2,sd_done

    # idx = 0*10 + x = x
    move $t3,$s1
    sll $t3,$t3,2

    # board[x] = 0
    la $t5,.board
    addu $t6,$t5,$t3
    sw $zero,0($t6)

    # board_occupied[x] = 0
    la $t5, .board_occupied
    addu $t6,$t5,$t3
    sw $zero,0($t6)

    addiu $s1,$s1,1
    j sd_clear_top_loop

sd_done:
    lw $s1,4($sp)
    lw $s0,8($sp)
    lw $ra,12($sp)
    addiu $sp,$sp,16
    jr $ra

#------------------------------------------------------------------------------
#  render_board: redraw grid and every occupied cell
#------------------------------------------------------------------------------
render_board:
    addiu $sp, $sp, -32
    sw $ra, 28($sp)
    sw $t0, 24($sp)
    sw $t1, 20($sp)
    sw $t2, 16($sp)
    sw $t3, 12($sp)
    sw $t4, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)

    la $t0, .board_occupied
    la $t1, .board

    li $s0, 0 # render_row = 0

render_loop_row:
    li $s1, 0 # render_col = 0

render_loop_col:
    li $t2, BOARD_W
    beq $s1, $t2, render_next_row

    # idx = row*BOARD_W + col
    mult $s0, $t2
    mflo $t3
    addu $t3, $t3, $s1
    sll $t3, $t3, 2

    # load occupancy flag
    addu $t4, $t0, $t3
    lw $t4, 0($t4)
    beqz $t4, render_background

    # occupied: load real color
    addu $a2, $t1, $t3
    lw $a2, 0($a2)
    j render_do_paint

render_background:
    li $a2, 0 # DEFAULT: paint_cell picks color

render_do_paint:
   move $a0, $s0 # row
   move $a1, $s1 # col
   jal paint_cell

   addiu $s1, $s1, 1 # col++
   j render_loop_col

render_next_row:
    addiu $s0, $s0, 1 # row++
    li $t2, BOARD_H
    blt $s0, $t2, render_loop_row

    lw $ra, 28($sp)
    lw $t0, 24($sp)
    lw $t1, 20($sp)
    lw $t2, 16($sp)
    lw $t3, 12($sp)
    lw $t4, 8($sp)
    lw $s0, 4($sp)
    lw $s1, 0($sp)
    addiu $sp, $sp, 32
    jr $ra
    
#------------------------------------------------------------------------------
# draw_game_over: display game over in the screen
#------------------------------------------------------------------------------
draw_game_over:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)

    li $t0, 0 # letter index 0..7
    li $t1, 8 # total letters
    li $t2, 5 # starting column
    li $t5, 8 # starting row 

letter_loop:
    blt $t0,4,skip_wrap # if t0 < 4, still drawing "GAME"
    beq $t0,4, do_wrap # otherwise change x,y to draw "OVER"
skip_wrap:
    la $t3,FONT_TABLE
    sll $t4, $t0, 2
    addu $t3, $t3, $t4
    lw $s2, 0($t3) # points to current letter

    li $t6, 0 # row letter (0..6)
    
go_row_loop:
    addu $t7, $s2, $t6
    lb $t7, 0($t7)

    li $t8, 0 # column letter (0..4)
    
go_col_loop:
    li $t9, 1
    sll $t9, $t9, 4
    srlv $t9, $t9, $t8
    and $s0, $t7, $t9
    beqz $s0, skip_pixel
    
    # paint white cell at (t5 + t6, t2 + t8)
    add $a0, $t5, $t6
    add $a1, $t2, $t8
    li $a2, C_WHITE
    jal paint_unit
skip_pixel:
    addiu $t8, $t8, 1
    blt $t8, 5, go_col_loop

    addiu $t6, $t6, 1
    blt $t6, 7, go_row_loop

    # go to next letter
    addiu $t2, $t2, 6
    addiu $t0, $t0, 1
    blt $t0, $t1, letter_loop

    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra
do_wrap:
    li $t2, 5 # reset col to starting
    addiu $t5, $t5, 9 # move down by 9 rows
    j skip_wrap

#------------------------------------------------------------------------------
# simple_delay: just run a loop to imitate a delay
#------------------------------------------------------------------------------
simple_delay:
    li $t0, 500000
delay:
    addiu $t0,$t0,-1
    bgtz $t0,delay
    jr $ra

#------------------------------------------------------------------------------
# quit: exit syscall
#------------------------------------------------------------------------------
quit:
    li $v0,10
    syscall
    
#------------------------------------------------------------------------------
# check_spawn_collision: Returns to caller if no overlap 
# if there is overlap it jumps to game_over
#------------------------------------------------------------------------------
check_spawn_collision:
    addiu $sp,$sp,-32
    sw $ra,28($sp)
    sw $t0,24($sp)
    sw $t1,20($sp)
    sw $t2,16($sp)
    sw $t3,12($sp)
    sw $t4, 8($sp)
    sw $t5, 4($sp)
    sw $t6, 0($sp)

    # load piece state
    lw $t0,cur_shape
    lw $t1,cur_orient
    lw $t2,cur_row
    lw $t3,cur_col

    # pick offset base
    li $t4, SH_I
    beq $t0,$t4, csc_use_I
    li $t4, SH_O
    beq $t0,$t4, csc_use_O
    li $t4, SH_T
    beq $t0,$t4, csc_use_T
    li $t4, SH_S
    beq $t0,$t4, csc_use_S
    li $t4, SH_Z
    beq $t0,$t4, csc_use_Z
    li $t4, SH_L
    beq $t0,$t4, csc_use_L
    la $t5, J_OFF
    j csc_offsets # otherwise J

csc_use_I:
    la $t5, I_OFF
    j csc_offsets

csc_use_O:
    la $t5, O_OFF
    j csc_offsets

csc_use_T:
    la $t5, T_OFF
    j csc_offsets

csc_use_S:
    la $t5, S_OFF
    j csc_offsets

csc_use_Z:
    la $t5, Z_OFF
    j csc_offsets

csc_use_L:
    la $t5, L_OFF
    j csc_offsets
csc_offsets:
    # skip to the correct orient block
    li $t6,4 # blocks per piece
    mul $t7,$t1,$t6 # orient * 4
    sll $t7,$t7,3 # *8 bytes
    addu $t5,$t5,$t7

    li $t6,0 # idx = 0
csc_loop:
    lw $t7,0($t5) # dx
    lw $t8,4($t5) # dy

    # test occupancy at (row+dy, col+dx)
    addu $a0,$t3,$t7 # a0 = col+dx
    addu $a1,$t2,$t8 # a1 = row+dy
    jal occupancy_collision_at_xy
    bnez $v0,csc_game_over
    
    addiu $t5,$t5,8
    addiu $t6,$t6,1
    slti $t7,$t6,4
    bnez $t7,csc_loop

    lw $t6, 0($sp)
    lw $t5, 4($sp)
    lw $t4, 8($sp)
    lw $t3,12($sp)
    lw $t2,16($sp)
    lw $t1,20($sp)
    lw $t0,24($sp)
    lw $ra,28($sp)
    addiu $sp,$sp,32
    jr $ra

csc_game_over:
    jal game_over # game over

#------------------------------------------------------------------------------
# init_game: clear VRAM & board array                                
#------------------------------------------------------------------------------
init_game:
    addiu $sp,$sp,-4
    sw $ra,0($sp)

    # clear loop
    li $t0,ADDR_DSPL # display base
    li $t1,CLEAR_SCREEN # number of cells
    li $t2,C_BLACK # backgroudnd color
clear_loop:
    beq $t1,$zero,clear_done
    sw $t2,0($t0)
    addiu $t0,$t0,4
    addiu $t1,$t1,-1
    b clear_loop
clear_done:
    li $t0, BOARD_W
    li $t1, BOARD_H
    mult $t0, $t1
    mflo $t1 # t1 = BOARD_W * BOARD_H
    la $t2, .board
    la $t4, .board_occupied
    li $t3, 0 # zero constant
board_loop:
    beq $t1, $zero, board_done
    sw $t3, 0($t2) # clear .board
    sw $t3, 0($t4) # clear .board_occupied
    addiu $t2, $t2, 4
    addiu $t1, $t1, -1
    b board_loop
board_done:
    # restore & return
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra

#------------------------------------------------------------------------------
# spawn_initial_rows: creates the 5 bottom rows which are randomly filled in                           
#------------------------------------------------------------------------------
    
spawn_initial_rows:
    addiu $sp,$sp,-36
    sw $ra,32($sp)
    sw $t0,28($sp)
    sw $t1,24($sp)
    sw $t2,20($sp)
    sw $t3,16($sp)
    sw $t4,12($sp)
    sw $t5, 8($sp)
    sw $t6, 4($sp)
    sw $t7, 0($sp)

    li $t4,BOARD_H
    addiu $t4,$t4,-5 # start row = BOARD_H-5

si_row_loop:
    li $t0,0 # col = 0

si_col_loop:
    jal random_shape # get a random number
    li $t6, 2
    ble $t6, $v0, do_fill # we fill around 2/3 cells

skip_fill:
    addiu $t0, $t0, 1
    li $t7, BOARD_W
    blt $t0,$t7, si_col_loop
    addiu $t4,$t4,1
    li $t7,BOARD_H
    blt $t4,$t7,si_row_loop
    j init_rows_done

do_fill:
    move $a0, $t4
    move $a1, $t0
    li $a2, C_WHITE # use white color for default rows
    jal paint_cell

    li $t1,BOARD_W
    mul $t2,$t4,$t1
    addu $t2,$t2,$t0
    sll $t2,$t2,2
    # mark those cells occupied
    la $t3,.board_occupied
    addu $t3,$t3,$t2
    li $t6,1
    sw $t6,0($t3)

    j skip_fill

init_rows_done:
    lw $t7, 0($sp)
    lw $t6, 4($sp)
    lw $t5, 8($sp)
    lw $t4,12($sp)
    lw $t3,16($sp)
    lw $t2,20($sp)
    lw $t1,24($sp)
    lw $t0,28($sp)
    lw $ra,32($sp)
    addiu $sp,$sp,36
    jr $ra

#------------------------------------------------------------
# random_shape: randomly select shape 0..6 using syscall 42
#------------------------------------------------------------
random_shape:
    addiu $sp, $sp, -12
    sw $ra, 8($sp)
    sw $a0, 4($sp)
    sw $a1, 0($sp)

    li $a0, 0
    li $a1, 7 # range [0..6]
    li $v0, 42 # syscall 42 = random int range
    syscall # result in $a0

    move $v0, $a0

    lw $a1, 0($sp)
    lw $a0, 4($sp)
    lw $ra, 8($sp)
    addiu $sp, $sp, 12
    jr $ra

#------------------------------------------------------------------------------
# draw_walls: draws left, right, and bottom walls 
# uses an outdated paint_unit instead of paint_cell because Im dummy and didnt fix the bug                
#------------------------------------------------------------------------------
draw_walls:
    addiu $sp,$sp,-20
    sw $ra,16($sp)
    sw $s0,12($sp)
    sw $s1,8($sp)
    sw $s2,4($sp)

    li $s0,TL_COL # board left column                     
    li $s1,BOARD_W # play field width                      
    addiu $s2,$s1,1 # width + 1 for bottom span             

    li $t0,0 # row counter                            
vert_loop:
    bge $t0,BOARD_H,bot_wall
    li $a0,TL_ROW # row = TL_ROW + t0                   
    addu $a0,$a0,$t0
    addiu $a1,$s0,-1 # left wall col = TL_COL - 1         
    li $a2,C_WALL
    jal paint_unit

    li $a0,TL_ROW
    addu $a0,$a0,$t0 # row = TL_ROW + t0                     
    addu $a1,$s0,$s1 # right wall col = TL_COL + BOARD_W     
    li $a2,C_WALL
    jal paint_unit

    addiu $t0,$t0,1 # next row                              
    b vert_loop

bot_wall:
    li $t1,-1 # bottom offset = -1                     
bot_loop:
    bge $t1,$s2,wall_done
    li $a0,TL_ROW
    addiu $a0,$a0,BOARD_H # bottom row                          
    addu $a1,$s0,$t1 # col = TL_COL + offset                  
    li $a2,C_WALL
    jal paint_unit
    addiu $t1,$t1,1 # next offset                           
    j bot_loop

wall_done:
    lw $s2, 4($sp)
    lw $s1, 8($sp)
    lw $s0, 12($sp)
    lw $ra, 16($sp)
    addiu $sp,$sp,20
    jr $ra

#------------------------------------------------------------------------------
# draw_grid: fill grid with alternating dark/light cells           
#------------------------------------------------------------------------------
draw_grid:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)

    # s1 = # rows, s0 = # cols
    li $s1, BOARD_H # 20
    li $s0, BOARD_W # 10
    li $t2, C_GREY_DK # dark cell
    li $t3, C_GREY_LT # light cell

    li $t0, 0 # row = 0
row_loop:
    bge $t0, $s1, end_grid
    li  $t1, 0 # col = 0
col_loop:
    bge    $t1, $s0, next_row

    # pick color by parity
    addu $t4, $t0, $t1
    andi $t4, $t4, 1
    beq $t4, $zero, use_dark
    move $a2, $t3 # light
    j do_paint
use_dark:
    move $a2, $t2 # dark
do_paint:
    move $a0, $t0 # grid_row
    move $a1, $t1 # grid_col
    jal paint_cell

    addiu $t1, $t1, 1
    j col_loop

next_row:
    addiu $t0, $t0, 1
    j row_loop

end_grid:
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra

#------------------------------------------------------------
# paint_cell: paints the (x, y) cell in the given color
# if color == 0 then choose dark/light automatically based on parity
#------------------------------------------------------------
paint_cell:
    addiu $sp, $sp, -20
    sw $ra, 16($sp)
    sw $t0, 12($sp)
    sw $t1, 8($sp)
    sw $t2, 4($sp)
    sw $t3, 0($sp)
    
    # if color == 0, decide by parity
    beq $a2, $zero, use_checker
    j skip_checker

use_checker:
    addu  $t0, $a0, $a1 # t0 = row + col
    andi  $t0, $t0, 1 # keep last bit
    
    bnez $t0, light_cell # odd = dark
    li $a2, C_GREY_DK # even = light
    j skip_checker 

light_cell:
    li $a2, C_GREY_LT # set light color
    j skip_checker

skip_checker:
    # idx = row * BOARD_W + col
    move $t0, $a0
    li $t1, BOARD_W
    mult $t0, $t1
    mflo $t0
    addu $t0, $t0, $a1

    # store color in .board[idx]
    la $t1, .board
    sll $t2, $t0, 2 # idx * 4
    addu $t1, $t1, $t2
    sw $a2, 0($t1)

    # draw the 8x8 square
    addiu $a0, $a0, TL_ROW
    addiu $a1, $a1, TL_COL
    jal paint_unit

    lw $t3, 0($sp)
    lw $t2, 4($sp)
    lw $t1, 8($sp)
    lw $t0, 12($sp)
    lw $ra, 16($sp)
    addiu $sp, $sp, 20
    jr $ra

#------------------------------------------------------------------------------
# paint_unit: draw a 8x8 pixel unit at specified row/col in VRAM      
#------------------------------------------------------------------------------
paint_unit:
    addiu $sp,$sp,-24           
    sw $ra,0($sp)           
    sw $t7,4($sp)           
    sw $t8,8($sp)           
    sw $t9,12($sp)           
    sw $t5,16($sp)           
    sw $t6,20($sp)

    move $t7,$a0 # t7 = row                          
    move $t8,$a1 # t8 = col                          
    move $t9,$a2 # t9 = color                       

    li $t5,UNITS_X # t5 = 32 units per row           
    mult $t7,$t5                   
    mflo $t7                     
    addu $t7,$t7,$t8                 
    sll $t7,$t7,2 # t7 = (row*32 + col)*4

    li $t6,ADDR_DSPL           
    addu $t6,$t6,$t7 # t6 = VRAM base + byte offset       
    sw $t9,0($t6) # store color into VRAM             

    lw $ra,0($sp)           
    lw $t7,4($sp)           
    lw $t8,8($sp)           
    lw $t9,12($sp)           
    lw $t5,16($sp)           
    lw $t6,20($sp)                    
    addiu $sp,$sp,24                       
    jr $ra   

#------------------------------------------------------------------------------
# Preventing wall collision
# C++ code for referece: https://ideone.com/wEQLAZ
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# bool wall_collision_at_xy(int x, int y)
# returns v0 = 1 if x < 0 || x >= BOARD_W || y < 0 || y >= BOARD_H, otherwise v0 = 0
#------------------------------------------------------------------------------
wall_collision_at_xy:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    sw $t0, 0($sp)

    # COL CHECK 
    bltz $a0, WCXY_hit # x < 0 is collision
    li $t0, BOARD_W
    bge $a0, $t0, WCXY_hit # x >= BOARD_W is collision

    # ROW CHECK
    bltz $a1, WCXY_hit # y < 0 is collision
    li $t0, BOARD_H
    bge $a1, $t0, WCXY_hit # y >= BOARD_H is collision

    li $v0, 0 # in bounds
    j WCXY_done

WCXY_hit:
    li $v0, 1 # collision

WCXY_done:
    lw $t0, 0($sp)
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra

#------------------------------------------------------------------------------
# wall_collision: sets $v0 = 1 if command results in wall collision, otherwise $v0 = 0
#------------------------------------------------------------------------------
wall_collision:
    addiu $sp,$sp,-36
    sw $ra,28($sp)
    sw $a0,24($sp)
    sw $a1,20($sp)
    sw $a2,16($sp)
    sw $a3,12($sp)
    sw $t1, 8($sp)
    sw $t2, 4($sp)
    sw $t3, 0($sp)
    sw $t0,32($sp)
    
    lw $a0, cur_col
    lw $a1, cur_row
    lw $a2, cur_shape
    lw $a3, cur_orient
    lw $t0, op_type

    move $t1,$a2 # t1=shape
    li $t2,4 # num of blocks
    li $t3,0 # offset pointer
    li $t4,1
    li $t5,1 # shape size

    # choose shape
    li $t6, SH_I
    beq $t1,$t6, WC_sel_I
    li $t6, SH_O
    beq $t1,$t6, WC_sel_O
    li $t6, SH_T
    beq $t1,$t6, WC_sel_T
    li $t6, SH_S
    beq $t1,$t6, WC_sel_S
    li $t6, SH_Z
    beq $t1,$t6, WC_sel_Z
    li $t6, SH_L
    beq $t1,$t6, WC_sel_L
    li $t6, SH_J
    beq $t1,$t6, WC_sel_J
    j WC_setup

WC_sel_I:
    la $t3, I_OFF
    li $t5,2 # I has 2 orientations
    j WC_setup

WC_sel_O:
    la $t3, O_OFF
    li $t5,1 # O has 1 orientation
    j WC_setup

WC_sel_T:
    la $t3, T_OFF
    li $t5,4
    j WC_setup

WC_sel_S:
    la $t3, S_OFF
    li $t5,2
    j WC_setup

WC_sel_Z:
    la $t3, Z_OFF
    li $t5,2
    j WC_setup

WC_sel_L:
    la $t3, L_OFF
    li $t5,4
    j WC_setup

WC_sel_J:
    la $t3, J_OFF
    li $t5,4
    j WC_setup

WC_setup:
    # compute base position in t7=x, t8=y
    move $t7,$a0
    move $t8,$a1
    # apply op_type: 0=left, 1=right, 2=down, 3=rotate
    li $t6,ACT_LEFT
    beq $t0,$t6, WC_left
    li $t6,ACT_RIGHT
    beq $t0,$t6, WC_right
    li $t6,ACT_DOWN
    beq $t0,$t6, WC_down
    li $t6,ACT_ROTATE
    beq $t0,$t6, WC_rotate
    j WC_loop
WC_left:
    addiu $t7,$t7,-1 # x--
    j WC_loop
WC_right:
    addiu $t7,$t7, 1 # x++
    j WC_loop
WC_down:
    addiu $t8,$t8, 1 # y++
    j WC_loop
WC_rotate:
   addi $a3, $a3, 1
   bne $a3, $t5, WC_loop
   li $a3, 0

WC_loop:
    # calculate pointer to this orientation (dx,dy)
    mul $t9,$a3,$t2
    sll $t9,$t9,3
    addu $t9,$t3,$t9 
    li $t6,0 # loop index i
WC_loop_body:
    lw $s0,0($t9) # dx
    lw $s1,4($t9) # dy
    addu $s2,$t7,$s0 # test_x
    addu $s3,$t8,$s1 # test_y

    # call wall_collision_at_xy(test_x,test_y)
    move $a0,$s2
    move $a1,$s3
    jal wall_collision_at_xy
    bnez $v0, WC_hit

    addiu $t9,$t9,8
    addiu $t6,$t6,1
    blt $t6,$t2,WC_loop_body

    li $v0,0
    j WC_done

WC_hit:
    li $v0,1
    j WC_done

WC_done:
    lw $t0,32($sp)
    lw $ra,28($sp)
    lw $a0,24($sp)
    lw $a1,20($sp)
    lw $a2,16($sp)
    lw $a3,12($sp)
    lw $t1, 8($sp)
    lw $t2, 4($sp)
    lw $t3, 0($sp)
    addiu $sp,$sp,36
    jr $ra

#------------------------------------------------------------------------------
# Preventing collision with other tetrominos is similar to wall collision
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# occupancy_collision_at_xy: returns v0 = 1 if collision will happen at (x, y)
#------------------------------------------------------------------------------
occupancy_collision_at_xy:
    addiu $sp, $sp, -12
    sw $ra, 8($sp)
    sw $t0, 4($sp)
    sw $t1, 0($sp)

    # idx = y*BOARD_W + x
    li $t0, BOARD_W
    mul $t1, $a1, $t0 # t1 = row * BOARD_W
    addu $t1, $t1, $a0 # t1 = idx
    sll $t1, $t1, 2

    # load from .board_occupied[idx]
    la $t0, .board_occupied
    addu $t0, $t0, $t1
    lw $t1, 0($t0)
    bnez $t1, OCXY_hit
    li $v0, 0
    j OCXY_done

OCXY_hit:
    li $v0, 1

OCXY_done:
    lw $t1, 0($sp)
    lw $t0, 4($sp)
    lw $ra, 8($sp)
    addiu $sp, $sp, 12
    jr $ra

#------------------------------------------------------------------------------
# occupancy_collision: sets $v0 = 1 if command results in occupancy collision, otherwise $v0 = 0
#------------------------------------------------------------------------------
occupancy_collision:
    addiu $sp, $sp, -36
    sw $ra, 28($sp)
    sw $a0, 24($sp)
    sw $a1, 20($sp)
    sw $a2, 16($sp)
    sw $a3, 12($sp)
    sw $t1, 8($sp)
    sw $t2, 4($sp)
    sw $t3, 0($sp)
    sw $t0, 32($sp)

    # load current state
    lw $a0, cur_col # base x
    lw $a1, cur_row # base y
    lw $a2, cur_shape # shape code
    lw $a3, cur_orient # orientation
    lw $t0, op_type # op_type into t0

    move $t1, $a2 # t1 = shape
    li $t2,4 # num of blocks
    li $t3,0 # offset holder
    li $t4,1
    li $t5,1 # shape size

	# select shape
    li $t6, SH_I
    beq $t1,$t6, OC_sel_I
    li $t6, SH_O
    beq $t1,$t6, OC_sel_O
    li $t6, SH_T
    beq $t1,$t6, OC_sel_T
    li $t6, SH_S
    beq $t1,$t6, OC_sel_S
    li $t6, SH_Z
    beq $t1,$t6, OC_sel_Z
    li $t6, SH_L
    beq $t1,$t6, OC_sel_L
    li $t6, SH_J
    beq $t1,$t6, OC_sel_J
    j OC_setup

OC_sel_I:
    la $t3, I_OFF
    li $t5,2 # I has 2 orientations
    j OC_setup

OC_sel_O:
    la $t3, O_OFF
    li $t5,1 # O has 1 orientation
    j OC_setup

OC_sel_T:
    la $t3, T_OFF
    li $t5,4 # T has 4 orientations
    j OC_setup

OC_sel_S:
    la $t3, S_OFF
    li $t5, 2  # S has 2 orientations
    j OC_setup

OC_sel_Z:
    la $t3, Z_OFF
    li $t5,2  # Z has 2 orientations
    j OC_setup

OC_sel_L:
    la $t3, L_OFF
    li $t5, 4 # L has 4 orientations
    j OC_setup

OC_sel_J:
    la $t3, J_OFF
    li $t5, 4 # J has 4 orientations
    j OC_setup

OC_setup:
    # compute base position in t7=x, t8=y
    move $t7,$a0
    move $t8,$a1
    # apply op_type: 0=left,1=right,2=down,3=rotate
    li $t6,ACT_LEFT
    beq $t0,$t6, OC_left
    li $t6,ACT_RIGHT
    beq $t0,$t6, OC_right
    li $t6,ACT_DOWN
    beq $t0,$t6, OC_down
    li $t6,ACT_ROTATE
    beq $t0,$t6, OC_rotate
    j OC_loop
OC_left:
    addiu $t7,$t7,-1 # x--
    j OC_loop
OC_right:
    addiu $t7,$t7, 1 # x++
    j OC_loop
OC_down:
    addiu $t8,$t8, 1 # y++
    j OC_loop
OC_rotate:
   addi $a3, $a3, 1
   bne $a3, $t5, OC_loop
   li $a3, 0

OC_loop:
    mul $t9,$a3,$t2
    sll $t9,$t9,3
    addu $t9,$t3,$t9 
    li $t6,0 # loop index i
OC_loop_body:
    lw $s0,0($t9) # dx
    lw $s1,4($t9) # dy
    addu $s2,$t7,$s0 # test_x
    addu $s3,$t8,$s1 # test_y

    # call occupancy_collision_at_xy(test_x,test_y)
    move $a0,$s2
    move $a1,$s3
    jal occupancy_collision_at_xy
    bnez $v0, OC_hit

    addiu $t9,$t9,8
    addiu $t6,$t6,1
    blt $t6,$t2,OC_loop_body

    li $v0,0
    j OC_done

OC_hit:
    li $v0,1
    j OC_done

OC_done:
    lw $t0, 32($sp)
    lw $t3, 0($sp)
    lw $t2, 4($sp)
    lw $t1, 8($sp)
    lw $a3, 12($sp)
    lw $a2, 16($sp)
    lw $a1, 20($sp)
    lw $a0, 24($sp)
    lw $ra, 28($sp)
    addiu $sp, $sp, 36
    jr $ra

#------------------------------------------------------------------------------
# the functions below perform all the moves/rotations for any tetromino shape and orientation
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# draw_piece: uniform painter for any tetromino
#------------------------------------------------------------------------------
draw_piece:
    addiu $sp,$sp,-32
    sw $ra,28($sp)
    sw $t0,24($sp)
    sw $t1,20($sp)
    sw $t2,16($sp)
    sw $t3,12($sp)
    sw $t4, 8($sp)
    sw $t5, 4($sp)
    sw $t6, 0($sp)

    lw $t0, cur_shape

    # select shape
    li $t1, SH_I
    beq $t0,$t1, .use_I
    li $t1, SH_O
    beq $t0,$t1, .use_O
    li $t1, SH_T
    beq $t0,$t1, .use_T
    li $t1, SH_S
    beq $t0,$t1, .use_S
    li $t1, SH_Z
    beq $t0,$t1, .use_Z
    li $t1, SH_L
    beq $t0,$t1, .use_L
    j .use_J # otherwise it's J

.use_J:
    la $t2, J_OFF
    li $a2, C_J
    j .setup

.use_I:
    la $t2, I_OFF
    li $a2, C_I
    j .setup

.use_O:
    la $t2, O_OFF
    li $a2, C_O
    j .setup

.use_T:
    la $t2, T_OFF
    li $a2, C_T
    j .setup

.use_S:
    la $t2, S_OFF
    li $a2, C_S
    j .setup

.use_Z:
    la $t2, Z_OFF
    li $a2, C_Z
    j .setup

.use_L:
    la $t2, L_OFF
    li $a2, C_L
    j .setup

.setup:
    lw $t0, cur_orient
    sll $t0,$t0,5
    addu $t2,$t2,$t0

    lw $t0, cur_row # cur_row
    lw $t1, cur_col # cor_col

    li $t3, 4
.draw_loop:
    lw $t4, 0($t2) # dx
    lw $t5, 4($t2) # dy
    addu $a0,$t0,$t5
    addu $a1,$t1,$t4
    jal paint_cell
    addiu $t2,$t2,8
    addiu $t3,$t3,-1
    bgtz $t3, .draw_loop

    lw $t6, 0($sp)
    lw $t5, 4($sp)
    lw $t4, 8($sp)
    lw $t3,12($sp)
    lw $t2,16($sp)
    lw $t1,20($sp)
    lw $t0,24($sp)
    lw $ra,28($sp)
    addiu $sp,$sp,32
    jr $ra

#------------------------------------------------------------------------------
# clear_piece: uniform painter for any tetromino
#------------------------------------------------------------------------------
clear_piece:
    addiu $sp,$sp,-32
    sw $ra,28($sp)
    sw $t0,24($sp)
    sw $t1,20($sp)
    sw $t2,16($sp)
    sw $t3,12($sp)
    sw $t4, 8($sp)
    sw $t5, 4($sp)
    sw $t6, 0($sp)

    lw $t0, cur_shape

    li $t1, SH_I
    beq $t0,$t1, clear.use_I
    li $t1, SH_O
    beq $t0,$t1, clear.use_O
    li $t1, SH_T
    beq $t0,$t1, clear.use_T
    li $t1, SH_S
    beq $t0,$t1, clear.use_S
    li $t1, SH_Z
    beq $t0,$t1, clear.use_Z
    li $t1, SH_L
    beq $t0,$t1, clear.use_L
    j clear.use_J
clear.use_J:
    la $t2, J_OFF
    li $a2, C_J
    j clear.setup

clear.use_I:
    la $t2, I_OFF
    li $a2, C_I
    j clear.setup

clear.use_O:
    la $t2, O_OFF
    li $a2, C_O
    j clear.setup

clear.use_T:
    la $t2, T_OFF
    li $a2, C_T
    j clear.setup

clear.use_S:
    la $t2, S_OFF
    li $a2, C_S
    j clear.setup

clear.use_Z:
    la $t2, Z_OFF
    li $a2, C_Z
    j clear.setup

clear.use_L:
    la $t2, L_OFF
    li $a2, C_L
    j clear.setup

clear.setup:
    lw $t0, cur_orient
    sll $t0,$t0,5
    addu $t2,$t2,$t0

    lw $t0, cur_row
    lw $t1, cur_col

    li $t3, 4
.clear_loop:
    lw $t4, 0($t2) # dx
    lw $t5, 4($t2) # dy
    addu $a0,$t0,$t5
    addu $a1,$t1,$t4
    li $a2, 0
    jal paint_cell
    addiu $t2,$t2,8
    addiu $t3,$t3,-1
    bgtz $t3, .clear_loop

    lw $t6, 0($sp)
    lw $t5, 4($sp)
    lw $t4, 8($sp)
    lw $t3,12($sp)
    lw $t2,16($sp)
    lw $t1,20($sp)
    lw $t0,24($sp)
    lw $ra,28($sp)
    addiu $sp,$sp,32
    jr $ra
    
#------------------------------------------------------------------------------
# rotate_piece: uniform rotation for any tetromino
#------------------------------------------------------------------------------
rotate_piece:
    addiu $sp,$sp,-32
    sw $ra,28($sp)
    sw $t0,24($sp)
    sw $t1,20($sp)
    sw $t2,16($sp)
    sw $t3,12($sp)
    sw $t4, 8($sp)
    sw $t5, 4($sp)
    sw $t6, 0($sp)

    lw $t0,cur_shape # t0 = shape
    lw $t1,cur_orient # t1 = orient

    jal clear_piece

    # if O-piece, do nothing (it has only one orientation)
    li $t2, SH_O
    beq $t0,$t2, .skip_rot

    # two-orientation pieces: I,S,Z
    li $t2, SH_I
    beq $t0,$t2, .do_toggle
    li $t2, SH_S
    beq $t0,$t2, .do_toggle
    li $t2, SH_Z
    beq $t0,$t2, .do_toggle

    # otherwise it's T, L, J
    addiu $t1,$t1,1 # t1 = orient+1
    li $t2, 4
    blt $t1,$t2, .store_orient
    li $t1,0 # if orient = 4, make it 0
    j .store_orient

.do_toggle:
    xori $t1,$t1,1

.store_orient:
    sw $t1,cur_orient

.skip_rot:
    jal draw_piece

    lw $t6, 0($sp)
    lw $t5, 4($sp)
    lw $t4, 8($sp)
    lw $t3,12($sp)
    lw $t2,16($sp)
    lw $t1,20($sp)
    lw $t0,24($sp)
    lw $ra,28($sp)
    addiu $sp,$sp,32
    jr $ra


#------------------------------------------------------------------------------
# move_piece_down: uniform move down for any tetromino
#------------------------------------------------------------------------------
move_piece_down:
    addiu $sp,$sp,-24
    sw $ra,20($sp)
    sw $t0,16($sp)
    sw $t1,12($sp)
    sw $t2, 8($sp)
    sw $t3, 4($sp)
    sw $t4, 0($sp)

    lw $t0,cur_row
    jal clear_piece

    addiu $t0,$t0,1 # x++
    sw $t0,cur_row

    jal draw_piece

    lw $t4, 0($sp)
    lw $t3, 4($sp)
    lw $t2, 8($sp)
    lw $t1,12($sp)
    lw $t0,16($sp)
    lw $ra,20($sp)
    addiu $sp,$sp,24
    jr $ra

#------------------------------------------------------------------------------
# move_piece_left: uniform move left for any tetromino
#------------------------------------------------------------------------------
move_piece_left:
    addiu $sp,$sp,-24
    sw $ra,20($sp)
    sw $t0,16($sp)
    sw $t1,12($sp)
    sw $t2, 8($sp)
    sw $t3, 4($sp)
    sw $t4, 0($sp)

    lw $t1,cur_col
    jal clear_piece

    addiu $t1,$t1,-1 # x--
    sw $t1,cur_col

    jal draw_piece

    lw $t4, 0($sp)
    lw $t3, 4($sp)
    lw $t2, 8($sp)
    lw $t1,12($sp)
    lw $t0,16($sp)
    lw $ra,20($sp)
    addiu $sp,$sp,24
    jr    $ra


#------------------------------------------------------------------------------
# move_piece_right: uniform move right for any tetromino
#------------------------------------------------------------------------------
move_piece_right:
    addiu $sp,$sp,-24
    sw $ra,20($sp)
    sw $t0,16($sp)
    sw $t1,12($sp)
    sw $t2, 8($sp)
    sw $t3, 4($sp)
    sw $t4, 0($sp)

    lw $t1,cur_col
    jal clear_piece

    addiu $t1,$t1,1 # y++
    sw $t1,cur_col

    jal draw_piece

    lw $t4, 0($sp)
    lw $t3, 4($sp)
    lw $t2, 8($sp)
    lw $t1,12($sp)
    lw $t0,16($sp)
    lw $ra,20($sp)
    addiu $sp,$sp,24
    jr $ra


#------------------------------------------------------------------------------
# spawn_piece_center: initialize any piece at its spawn location
#------------------------------------------------------------------------------
spawn_piece_center:
    addiu $sp,$sp,-32
    sw $ra,28($sp)
    sw $t0,24($sp)
    sw $t1,20($sp)
    sw $t2,16($sp)
    sw $t3,12($sp)
    sw $t4, 8($sp)
    sw $t5, 4($sp)
    sw $t6, 0($sp)

    lw $t0,cur_shape # choose shape

    # default: 0 orient, row=0, col=(BOARD_W/2 -1)
    li $t1,0
    sw $t1,cur_orient

    li $t2,0
    sw $t2,cur_row

    li $t3,BOARD_W
    sra $t3,$t3,1
    addiu $t3,$t3,-1
    sw $t3,cur_col

    j .common_spawn
    
.common_spawn:
    jal check_spawn_collision
    jal draw_piece

    # restore & return
    lw $t6, 0($sp)
    lw $t5, 4($sp)
    lw $t4, 8($sp)
    lw $t3,12($sp)
    lw $t2,16($sp)
    lw $t1,20($sp)
    lw $t0,24($sp)
    lw $ra,28($sp)
    addiu $sp,$sp,32
    jr $ra
    
#------------------------------------------------------------------------------
# draw_panel: draw the next shape in the panel
#------------------------------------------------------------------------------
draw_panel:
    addiu $sp,$sp,-32
    sw $ra,28($sp)
    sw $t0,24($sp)
    sw $t1,20($sp)
    sw $t2,16($sp)
    sw $t3,12($sp)
    sw $t4, 8($sp)
    sw $t5, 4($sp)
    sw $t6, 0($sp)

    li $t7,PANEL_ROW # y
    li $t8,PANEL_COL # x

    lw $t0,next_shape # shape
    li $t2, 0 # orientation

    # choose shape
    li $t1,SH_I
    beq $t0,$t1,use_I
    li $t1,SH_O
    beq $t0,$t1,use_O
    li $t1,SH_T
    beq $t0,$t1,use_T
    li $t1,SH_S
    beq $t0,$t1,use_S
    li $t1,SH_Z
    beq $t0,$t1,use_Z
    li $t1,SH_L
    beq $t0,$t1,use_L
    j use_J
use_J:
    la $t3,J_OFF
    li $a2,C_J
    j setup

use_I:
    la $t3,I_OFF
    li $a2,C_I
    j setup

use_O:
    la $t3,O_OFF
    li $a2,C_O
    j setup

use_T:
    la $t3,T_OFF
    li $a2,C_T
    j setup

use_S:
    la $t3,S_OFF
    li $a2,C_S
    j setup

use_Z:
    la $t3,Z_OFF
    li $a2,C_Z
    j setup

use_L:
    la $t3,L_OFF
    li $a2,C_L
    j setup

setup:
    sll $t4,$t2,5
    addu $t3,$t3,$t4

    li $t5,4 # number of cells
dp_loop:
    lw $s0,0($t3) # dx
    lw $s1,4($t3) # dy
    addu $a0,$t7,$s1 # a0 = PANEL_ROW + dy
    addu $a1,$t8,$s0 # a1 = PANEL_COL + dx
    addi $a1,$a1,1 # a1++ 
    jal paint_unit
    addiu $t3,$t3,8
    addiu $t5,$t5,-1
    bgtz $t5,dp_loop

    lw $t6, 0($sp)
    lw $t5, 4($sp)
    lw $t4, 8($sp)
    lw $t3,12($sp)
    lw $t2,16($sp)
    lw $t1,20($sp)
    lw $t0,24($sp)
    lw $ra,28($sp)
    addiu $sp,$sp,32
    jr $ra

#------------------------------------------------------------------------------
# draw_panel_walls: draw walls around the panel & fill black everything inside
#------------------------------------------------------------------------------
draw_panel_walls:
    addiu $sp,$sp,-4
    sw $ra,0($sp)

    li $t0,PANEL_COL
    addiu $t0,$t0,-2 # t0 = PANEL_COL-2
    li $t1,PANEL_COL
    addiu $t1,$t1,PANEL_FRAME_W # t1 = PANEL_COL+PANEL_FRAME_W
    li $t2,PANEL_ROW
    addiu $t2,$t2,-1 # t2 = PANEL_ROW-1
    li $t3,PANEL_ROW
    addiu $t3,$t3,PANEL_FRAME_H # t3 = PANEL_ROW+PANEL_FRAME_H

# top wall
draw_top:
    move $a0,$t2 # row = top
    move $a1,$t0
    li $a2,C_GREY_LT # wall color
    jal paint_unit
    addiu $t0,$t0,1
    ble $t0,$t1,draw_top

    li $t0,PANEL_COL
    addiu $t0,$t0,-2 # reset t0 = left

# bottom wall
draw_bot:
    move $a0,$t3 # row = bottom
    move $a1,$t0
    li $a2,C_GREY_LT
    jal paint_unit
    addiu $t0,$t0,1
    ble $t0,$t1,draw_bot
    li  $t4,PANEL_ROW # t4 = current row (start)

# side walls
side_loop:
    # left wall
    move $a0,$t4
    li $a1,PANEL_COL
    addiu $a1,$a1,-2
    li $a2,C_GREY_LT
    jal paint_unit

    # right wall
    move $a0,$t4
    li $a1,PANEL_COL
    addiu $a1,$a1,PANEL_FRAME_W
    li $a2,C_GREY_LT
    jal paint_unit

    addiu $t4,$t4,1
    blt $t4,$t3,side_loop
    
    # fill the inside with black
    li $t5, PANEL_ROW
    li $t6, PANEL_COL
    addiu $t6,$t6,0 
    li $t7, PANEL_FRAME_H
fill_rows:
    li $t8, PANEL_COL
    addiu $t8,$t8,0
    li $t9, PANEL_FRAME_W
fill_cols:
    move $a0,$t5 # row
    move $a1,$t8 # col
    li $a2,C_BLACK
    jal paint_unit
    addiu $t8,$t8,1
    addiu $t9,$t9,-1
    bgtz $t9,fill_cols

    addiu $t5,$t5,1
    addiu $t7,$t7,-1
    bgtz $t7,fill_rows


    lw $ra,0($sp)
    addiu $sp,$sp,4
    jr $ra

#------------------------------------------------------------------------------
# DEBUG HELPER STUFF BELOW
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# print_wall_collision: prints message to the console if wall collision happened
#------------------------------------------------------------------------------
print_wall_collision:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)

    la $a0, msg_wall_collision # address of the message
    li $v0, 4 # syscall: print_string
    syscall

    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra

#------------------------------------------------------------------------------
# print_wall_collision: prints message to the console if occupancy collision happened
#------------------------------------------------------------------------------
print_occupancy_collision:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)

    la $a0, msg_occupancy_collision
    li $v0, 4
    syscall
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra
    
#------------------------------------------------------------------------------
# print_wall_collision: prints message to the console if occupancy collision happened
#------------------------------------------------------------------------------
print_speed_increased:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)

    la $a0, msg_speed_increased
    li $v0, 4
    syscall
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra
    
#------------------------------------------------------------------------------
# print_game_over: prints message to the console if we reached game over state
#------------------------------------------------------------------------------
print_game_over:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)

    la $a0, msg_game_over
    li $v0, 4
    syscall
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra


#------------------------------------------------------------------------------
#  print_board_occupied: prints .board_occupied array to the console.
#  Uses syscall 11 (print_char).
#------------------------------------------------------------------------------
print_board_occupied:
    addiu $sp, $sp, -48
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $t0, 8($sp)
    sw $t1, 12($sp)
    sw $t2, 16($sp)
    sw $t3, 20($sp)
    sw $t4, 24($sp)
    sw $t5, 28($sp)
    sw $t6, 32($sp)
    sw $t7, 36($sp)
    sw $a0, 40($sp)
    sw $v0, 44($sp)

    la $t2, .board_occupied
    li $t6, BOARD_W # BOARD_W
    li $t7, BOARD_H # BOARD_H
    li $s0, 0 # row y = 0

row_loop_pbo:
    li $t0, 0 # col x = 0

col_loop_pbo:
    # idx = y*10 + x
    mul $t1, $s0, $t6
    addu $t1, $t1, $t0
    sll $t1, $t1, 2

    addu $t3, $t2, $t1
    lw $t4, 0($t3)

    # print the digit
    addiu $a0, $t4, 48 # ASCII '0' = 48
    li $v0, 11 # print_char
    syscall

    # print a space
    li $a0, 32 # ' '
    li $v0, 11
    syscall

    addiu $t0, $t0, 1 # x++
    blt $t0, $t6, col_loop_pbo

    # newline at end of row
    li $a0, 10 # '\n'
    li $v0, 11
    syscall

    addiu $s0, $s0, 1 # y++
    blt $s0, $t7, row_loop_pbo

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $t0, 8($sp)
    lw $t1, 12($sp)
    lw $t2, 16($sp)
    lw $t3, 20($sp)
    lw $t4, 24($sp)
    lw $t5, 28($sp)
    lw $t6, 32($sp)
    lw $t7, 36($sp)
    lw $a0, 40($sp)
    lw $v0, 44($sp)
    addiu $sp, $sp, 48
    jr $ra

#------------------------------------------------------------------------------
#  print_board: prints .board array to the console.
#------------------------------------------------------------------------------
print_board:
    addiu $sp, $sp, -56
    sw $ra,  0($sp)
    sw $s0,  4($sp)
    sw $t0,  8($sp)
    sw $t1, 12($sp)
    sw $t2, 16($sp)
    sw $t3, 20($sp)
    sw $t4, 24($sp)
    sw $t5, 28($sp)
    sw $t6, 32($sp)
    sw $t7, 36($sp)
    sw $t8, 40($sp)
    sw $a0, 44($sp)
    sw $v0, 48($sp)

    la $t2, .board # base address of board
    li $t6, BOARD_W # BOARD_W
    li $t7, BOARD_H # BOARD_H
    li $s0, 0 # row y = 0

row_loop_pb:
    li $t0, 0 # col x = 0

col_loop_pb:
    # idx = y*10 + x
    mul $t1, $s0, $t6
    addu $t1, $t1, $t0
    sll $t1, $t1, 2

    addu $t3, $t2, $t1
    lw $t4, 0($t3)

    move $a0, $t4
    li $v0, 1 # syscall: print_int
    syscall

    # print a space
    li $a0, 32 # ASCII ' '
    li $v0, 11 # syscall: print_char
    syscall

    addiu $t0, $t0, 1 # x++
    blt $t0, $t6, col_loop_pb

    # newline at end of row
    li $a0, 10 # ASCII '\n'
    li $v0, 11 # syscall: print_char
    syscall

    addiu $s0, $s0, 1 # y++
    blt $s0, $t7, row_loop_pb
    
    # newline at end of row
    li $a0, 10 # '\n'
    li $v0, 11
    syscall

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $t0, 8($sp)
    lw $t1, 12($sp)
    lw $t2, 16($sp)
    lw $t3, 20($sp)
    lw $t4, 24($sp)
    lw $t5, 28($sp)
    lw $t6, 32($sp)
    lw $t7, 36($sp)
    lw $t8, 40($sp)
    lw $a0, 44($sp)
    lw $v0, 48($sp)
    addiu $sp, $sp, 56
    jr $ra
