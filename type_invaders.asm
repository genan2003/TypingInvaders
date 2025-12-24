name "TypingInvaders"

org 100h

jmp start_program

; --- DATA SECTION ---
; This section stores all global variables and constants used by the game.

; FILE I/O
; Variables for handling the high score file.
filename        db "HISCORE.TXT", 0         ; Name of the file to store scores
file_handle     dw 0                        ; Buffer to store the file handle after opening
; Default leaderboard values if the file doesn't exist.
default_data    db "CPU 00000", "CPU 00000", "CPU 00000" 
lb_buffer       db 30 dup(' ')              ; Buffer to read/write the top 3 scores (27 bytes + padding)
temp_entry      db "         "              ; Temporary buffer to construct a new score entry

; PLAYER DATA
; Variables related to the player's current state and input.
current_name    db "   ", 0                 ; Buffer for the player's 3-letter name
char_x          db 40                       ; X-position (column) of the falling letter
char_y          db 2                        ; Y-position (row) of the falling letter
current_char    db 'A'                      ; The ASCII character currently falling
current_color   db 0Eh                      ; Color attribute of the falling letter (Yellow default)

; STATS
; Game statistics and configuration.
score           dw 0                        ; Current player score
lives           db 3                        ; Number of lives remaining
fall_speed      dw 15                       ; Speed of falling letters (lower = faster)
tick_count      dw 0                        ; Counter to control game timing
game_active     db 1                        ; Flag: 1 = Game running, 0 = Game Over
has_nuke        db 1                        ; Flag: 1 = Player has a screen-clearing nuke
level           db 1                        ; Current difficulty level
ground_color    db 02h                      ; Color of the ground line

; MECHANICS
; Variables for game mechanics and bonuses.
floor_y         db 24                       ; Y-position of the ground (game over line)
streak          dw 0                        ; Consecutive correct hits
is_combo        db 0                        ; Flag: 1 = Combo active (double points)
has_shield      db 0                        ; Flag: 1 = Shield active (protects from one hit)
is_armored      db 0                        ; Flag: 1 = Current enemy takes 2 hits
freeze_timer    dw 0                        ; Timer for the "Freeze" power-up effect

; UI MESSAGES
; Strings used for displaying text on the screen.
msg_title       db "=== TYPING INVADERS v28 ===$"
msg_instr       db "Type letters! L for Top 3 Ranks.$"
msg_start       db "Press ENTER to Start$"
msg_enter_name  db "ENTER NAME (3 CHARS): $"
msg_leader      db "=== TOP 3 LEADERBOARD ===$"
msg_rank1       db "1. $"
msg_rank2       db "2. $"
msg_rank3       db "3. $"
msg_back        db "Press ESC to Return$"
msg_gameover    db "GAME OVER! Final Score: $"
msg_newrec      db " YOU MADE THE LEADERBOARD!$"
msg_restart     db " Press R to Restart or ESC to Exit.$"
msg_paused      db "PAUSED$"
msg_clear       db "                              $"
newline         db 13, 10, "$"

; VRAM STRINGS
; Strings written directly to Video Memory (0B800h).
v_score         db "SCORE:", 0
v_best          db "BEST:", 0
v_lvl           db "LVL:", 0
v_lives         db "LIVES:", 0
v_nuke          db "[NUKE]  ", 0
v_shield        db "[SHIELD]", 0
v_freeze        db "[FREEZE]", 0
v_combo         db "COMBO 2x", 0
v_blank         db "        ", 0 

initial_tick    dw 0

; MATRIX RAIN DATA
; Used for the intro animation effect.
matrix_cols     db 80 dup(0)    ; Array tracking rain drop position for each column (0=inactive)
rnd_seed        dw 1234h        ; Seed for the pseudo-random number generator

; --- CODE SECTION ---

start_program:
    ; Main entry point. Initializes system and launches the menu.
    call check_and_repair_file  ; Ensure high score file exists
    call load_leaderboard       ; Load high scores into memory
    call matrix_intro           ; Play the "Matrix" intro animation
    jmp main_menu_init          ; Jump to the main menu

; 1. MENU
; Handles drawing the menu and waiting for user input.
main_menu_init:
    mov ax, 0003h               ; Set Video Mode 03h (80x25 Text Mode, Clears Screen)
    int 10h
    mov ah, 01h                 ; Hide the text cursor
    mov ch, 20h
    int 10h

draw_menu:
    mov bh, 0                   ; Ensure we are writing to Video Page 0
    
    ; Draw Title
    mov ah, 02h                 ; Set Cursor Position
    mov dh, 6                   ; Row
    mov dl, 28                  ; Column
    int 10h
    mov dx, offset msg_title    ; Print String
    mov ah, 09h
    int 21h
    
    ; Draw Instructions
    mov ah, 02h
    mov dh, 8
    mov dl, 24      
    int 10h
    mov dx, offset msg_instr
    mov ah, 09h
    int 21h
    
    ; Draw Start Prompt
    mov ah, 02h
    mov dh, 14
    mov dl, 30
    int 10h
    mov dx, offset msg_start
    mov ah, 09h
    int 21h

wait_start_key:
    ; Wait for key press in the menu.
    mov ah, 00h
    int 16h
    cmp al, 13      ; Check for ENTER key (ASCII 13)
    je get_name_screen
    cmp al, 'l'     ; Check for 'L' (Leaderboard)
    je show_leaderboard
    cmp al, 'L'
    je show_leaderboard
    cmp al, 27      ; Check for ESC (Exit)
    je exit_game
    jmp wait_start_key

get_name_screen:
    ; Screen to input player initials.
    mov ax, 0003h               ; Clear screen
    int 10h
    mov ah, 02h                 ; Position cursor
    mov dh, 10
    mov dl, 25
    int 10h
    mov dx, offset msg_enter_name
    mov ah, 09h
    int 21h
    
    ; Position cursor for input
    mov ah, 02h
    mov dh, 10
    mov dl, 48
    int 10h
    
    ; Loop to get 3 characters
    mov cx, 3
    mov di, offset current_name
name_input_loop:
    mov ah, 01h                 ; Get char from stdin with echo
    int 21h
    mov [di], al                ; Store char in buffer
    inc di
    loop name_input_loop
    
    jmp start_game_init

show_leaderboard:
    ; Displays the Top 3 scores from the buffer.
    mov ax, 0003h
    int 10h
    
    mov bh, 0
    
    ; Display Header
    mov ah, 02h
    mov dh, 5
    mov dl, 28
    int 10h
    mov dx, offset msg_leader
    mov ah, 09h
    int 21h
    
    ; -- PRINT RANK 1 --
    mov ah, 02h
    mov dh, 8
    mov dl, 30
    int 10h
    mov dx, offset msg_rank1
    mov ah, 09h
    int 21h
    mov si, offset lb_buffer    ; Point to start of buffer
    call print_entry_9bytes     ; Print first entry
    
    ; -- PRINT RANK 2 --
    mov ah, 02h
    mov dh, 10
    mov dl, 30
    int 10h
    mov dx, offset msg_rank2
    mov ah, 09h
    int 21h
    mov si, offset lb_buffer
    add si, 9                   ; Move pointer 9 bytes forward
    call print_entry_9bytes
    
    ; -- PRINT RANK 3 --
    mov ah, 02h
    mov dh, 12
    mov dl, 30
    int 10h
    mov dx, offset msg_rank3
    mov ah, 09h
    int 21h
    mov si, offset lb_buffer
    add si, 18                  ; Move pointer 18 bytes forward
    call print_entry_9bytes
    
    ; Back prompt
    mov ah, 02h
    mov dh, 16
    mov dl, 30
    int 10h
    mov dx, offset msg_back
    mov ah, 09h
    int 21h
    
wait_lead_key:
    mov ah, 00h
    int 16h
    cmp al, 27 ; ESC
    je main_menu_init
    jmp wait_lead_key

start_game_init:
    ; Initialize all game variables for a new run.
    mov ax, 0003h
    int 10h
    
    mov [score], 0
    mov [lives], 3
    mov [fall_speed], 15
    mov [game_active], 1
    mov [has_nuke], 1
    mov [level], 1
    mov [ground_color], 02h
    mov [floor_y], 24       
    
    mov [streak], 0
    mov [is_combo], 0
    mov [has_shield], 0
    mov [freeze_timer], 0
    mov [is_armored], 0
    
    call draw_ground
    call draw_static_ui_vram
    call spawn_new_letter

game_loop:
    ; The core game loop.
    call update_ui_vram         ; Draw UI elements
    
    mov ah, 01h                 ; Check if key is pressed (non-blocking)
    int 16h
    jz no_key_press             ; If no key, skip to physics
    
    mov ah, 00h                 ; Get the key
    int 16h
    
    ; Global Keys
    cmp al, 27                  ; ESC -> Main Menu
    je main_menu_init   
    cmp al, 32                  ; SPACE -> Pause
    je toggle_pause
    cmp al, 9                   ; TAB -> Use Nuke
    je trigger_nuke
    
    ; Input matching logic
    push ax
    and al, 11011111b           ; Convert to Upper Case (mask bit 5)
    cmp al, [current_char]      ; Compare with enemy letter
    je correct_key
    
    ; Incorrect Key
    mov [streak], 0             ; Reset streak
    mov [is_combo], 0
    jmp ignore_key_pop
    
correct_key:
    pop ax 
    call letter_caught          ; Handle successful hit
    jmp no_key_press

ignore_key_pop:
    pop ax
    jmp no_key_press
    
no_key_press:
    ; Delay loop for timing control
    mov cx, 0
    mov dx, 02000h      
    mov ah, 86h
    int 15h
    
    ; Check freeze timer
    cmp [freeze_timer], 0
    jle update_physics
    dec [freeze_timer]
    jmp game_loop               ; Skip physics if frozen
    
update_physics:
    ; Controls how often the letter moves down.
    inc [tick_count]
    mov ax, [tick_count]
    cmp ax, [fall_speed] 
    jl game_loop                ; Not time to move yet
    
    mov [tick_count], 0  
    call move_letter_down       ; Move letter
    cmp [game_active], 0        ; Check if game ended
    je game_over_screen
    jmp game_loop

trigger_nuke:
    ; Uses the screen-clearing bomb if available.
    cmp [has_nuke], 1
    jne no_key_press    
    
    mov [has_nuke], 0   
    ; Flash Screen White
    mov ax, 0600h       
    mov bh, 70h         
    mov cx, 0000h       
    mov dx, 184Fh       
    int 10h
    
    ; Delay
    mov cx, 0
    mov dx, 04000h
    mov ah, 86h
    int 15h
    
    ; Reset Screen
    mov ax, 0600h
    mov bh, 07h         
    mov cx, 0000h
    mov dx, 184Fh       
    int 10h
    call draw_ground
    call draw_static_ui_vram
    call spawn_new_letter
    jmp game_loop

toggle_pause:
    ; Pauses the game loop until space is pressed again.
    mov ah, 02h
    mov dh, 12
    mov dl, 35      
    int 10h
    mov dx, offset msg_paused
    mov ah, 09h
    int 21h
pause_wait:
    mov ah, 00h
    int 16h
    cmp al, 32                  ; Check for SPACE
    je clear_pause_msg
    jmp pause_wait
clear_pause_msg:
    ; Restore screen after pause
    mov ah, 02h
    mov dh, 12
    mov dl, 35      
    int 10h
    mov dx, offset msg_clear 
    mov ah, 09h
    int 21h
    call draw_char
    call draw_static_ui_vram
    jmp game_loop

; --- LEADERBOARD LOGIC (TOP 3 SORTING) ---

check_and_repair_file proc
    ; Ensures the high score file exists. If not, creates it.
    mov ah, 3Dh
    mov al, 0 
    mov dx, offset filename
    int 21h
    jc create_new_file          ; If open fails (Carry Flag set), create file
    
    ; Check file size/integrity
    mov [file_handle], ax
    mov ah, 3Fh
    mov bx, [file_handle]
    mov cx, 27
    mov dx, offset lb_buffer
    int 21h
    
    push ax ; Save bytes read count
    mov ah, 3Eh                 ; Close file
    mov bx, [file_handle]
    int 21h
    pop ax
    
    cmp ax, 27                  ; If bytes read < 27, file is corrupt
    jl create_new_file
    ret

create_new_file:
    ; Creates a new file with default data.
    mov ah, 3Ch
    mov cx, 0
    mov dx, offset filename
    int 21h
    mov [file_handle], ax
    
    ; Write default scores
    mov ah, 40h
    mov bx, [file_handle]
    mov cx, 27
    mov dx, offset default_data
    int 21h
    
    mov ah, 3Eh                 ; Close file
    mov bx, [file_handle]
    int 21h
    ret
check_and_repair_file endp

load_leaderboard proc
    ; Reads the file content into lb_buffer.
    mov ah, 3Dh
    mov al, 0
    mov dx, offset filename
    int 21h
    mov [file_handle], ax
    
    mov ah, 3Fh
    mov bx, [file_handle]
    mov cx, 27
    mov dx, offset lb_buffer
    int 21h
    
    mov ah, 3Eh
    mov bx, [file_handle]
    int 21h
    ret
load_leaderboard endp

update_leaderboard proc
    ; Handles sorting and saving new high scores.
    
    push ds
    pop es      ; Make ES point to Data Segment (required for string operations)
    

    ; 1. Prepare current entry string (Name + Score) in temp_entry
    mov si, offset temp_entry
    mov di, offset current_name
    ; Copy Name
    mov al, [di]
    mov [si], al
    mov al, [di+1]
    mov [si+1], al
    mov al, [di+2]
    mov [si+2], al
    mov byte ptr [si+3], ' '
    ; Convert Score to String and append
    mov ax, [score]
    add si, 4
    call int_to_string_5
    
    ; 2. Comparison Logic (Bubble Sort Insertion)
    ; Check against Rank 1
    mov si, offset lb_buffer
    add si, 4                   ; Point to score part
    call string_to_int          ; Convert stored score string to integer in AX
    cmp [score], ax
    jg insert_rank_1            ; If current > rank 1, insert
    
    ; Check against Rank 2
    mov si, offset lb_buffer
    add si, 13                  ; Offset for Rank 2 score
    call string_to_int
    cmp [score], ax
    jg insert_rank_2
    
    ; Check against Rank 3
    mov si, offset lb_buffer
    add si, 22                  ; Offset for Rank 3 score
    call string_to_int
    cmp [score], ax
    jg insert_rank_3
    
    jmp save_lb_to_file         ; If no high score, save anyway to be safe

insert_rank_1:
    call copy_entry_2_to_3      ; Shift 2 -> 3
    call copy_entry_1_to_2      ; Shift 1 -> 2
    mov di, offset lb_buffer
    call write_temp_to_di       ; Insert new score at 1
    jmp save_lb_to_file

insert_rank_2:
    call copy_entry_2_to_3      ; Shift 2 -> 3
    mov di, offset lb_buffer
    add di, 9
    call write_temp_to_di       ; Insert new score at 2
    jmp save_lb_to_file

insert_rank_3:
    mov di, offset lb_buffer
    add di, 18
    call write_temp_to_di       ; Insert new score at 3
    jmp save_lb_to_file

save_lb_to_file:
    ; Writes the modified buffer back to disk.
    mov ah, 3Ch
    mov cx, 0
    mov dx, offset filename
    int 21h
    mov [file_handle], ax
    
    mov ah, 40h
    mov bx, [file_handle]
    mov cx, 27
    mov dx, offset lb_buffer
    int 21h
    
    mov ah, 3Eh
    mov bx, [file_handle]
    int 21h
    ret
update_leaderboard endp

; MEMORY HELPERS
; Low-level buffer manipulation routines.

copy_entry_2_to_3 proc
    mov si, offset lb_buffer
    add si, 9                   ; Source: Rank 2
    mov di, offset lb_buffer
    add di, 18                  ; Dest: Rank 3
    mov cx, 9
    rep movsb
    ret
copy_entry_2_to_3 endp

matrix_intro proc
    ; "Digital Rain" intro effect.
    ; Set Text Mode (Clear Screen)
    mov ax, 0003h
    int 10h
    
    ; Hide Cursor
    mov ah, 01h
    mov cx, 2607h
    int 10h

matrix_loop:
    ; 1. Check for Key Press (Exit loop if pressed)
    mov ah, 01h
    int 16h
    jnz matrix_exit_cleanup

    ; 2. Randomly spawn new drops
    call get_random
    and ax, 7Fh                 ; Keep result 0-127
    cmp ax, 80
    jge skip_spawn              ; If > 79, ignore (screen width is 80)
    
    mov si, ax
    cmp byte ptr [matrix_cols + si], 0
    jne skip_spawn              ; If column busy, ignore
    mov byte ptr [matrix_cols + si], 1 ; Start drop at row 1

skip_spawn:
    ; 3. Update all 80 columns
    mov cx, 80
    mov si, 0
    mov ax, 0B800h              ; Point ES to Video Memory
    mov es, ax

col_loop:
    mov al, [matrix_cols + si]  ; Get Y position for this column
    cmp al, 0
    je next_col                 ; If 0, inactive

    ; --- ERASE TAIL (Y - 15) ---
    cmp al, 15
    jl draw_head
    
    push ax             
    sub al, 15                  ; Calculate tail end position
    call get_mat_offset         ; DI = VRAM offset
    mov word ptr es:[di], 0720h ; Draw Black Space (erase)
    pop ax              

draw_head:
    ; --- DRAW HEAD (White Character) ---
    cmp al, 25
    jge reset_col               ; If off screen bottom, reset column
    
    call get_mat_offset         ; DI = current Y offset
    
    push ax             
    call get_random             ; Get random char
    and al, 01111111b           ; ASCII range mask
    add al, 33                  ; Ensure readable char
    mov ah, 0Fh                 ; White color (Head)
    mov es:[di], ax             ; Write char to video memory
    pop ax              

    ; --- DRAW TRAIL (Green Character) ---
    dec al                      ; Go to previous row (Y-1)
    cmp al, 0
    jl update_y                 ; If off top of screen, skip
    
    call get_mat_offset
    ; Keep the character that is already there, just change color
    mov bl, es:[di]             ; Read char
    mov bh, 02h                 ; Dark Green color
    mov es:[di], bx             ; Write back

update_y:
    ; Increment Y position in array
    inc byte ptr [matrix_cols + si]
    jmp next_col

reset_col:
    mov byte ptr [matrix_cols + si], 0

next_col:
    inc si
    loop col_loop

    ; 4. Delay (Control Speed)
    mov cx, 0
    mov dx, 4000h       ; Speed control
    mov ah, 86h
    int 15h

    jmp matrix_loop

matrix_exit_cleanup:
    ; Consume the key press to clear buffer
    mov ah, 00h
    int 16h
    ret

; Helper: Calculates VRAM offset for Matrix
get_mat_offset:
    push ax
    push bx
    mov bl, 160         ; 80 columns * 2 bytes/char
    mul bl              
    mov di, ax          ; Row offset
    mov ax, si
    shl ax, 1           ; Column offset (X * 2)
    add di, ax          ; Total offset
    pop bx
    pop ax
    ret

; Helper: Simple Pseudo-Random Generator (Linear Congruential)
get_random:
    push dx
    mov ax, [rnd_seed]
    mov dx, 351
    mul dx
    add ax, 45
    mov [rnd_seed], ax
    pop dx
    ret
matrix_intro endp

copy_entry_1_to_2 proc
    mov si, offset lb_buffer
    ; Source: Rank 1 (0)
    mov di, offset lb_buffer
    add di, 9  ; Dest: Rank 2
    mov cx, 9
    rep movsb
    ret
copy_entry_1_to_2 endp

write_temp_to_di proc
    ; Copies the constructed score string to the destination in buffer.
    mov si, offset temp_entry
    mov cx, 9
    rep movsb
    ret
write_temp_to_di endp

print_entry_9bytes proc
    ; Prints 9 characters starting at SI to screen.
    mov cx, 9
print_9_loop:
    mov dl, [si]
    mov ah, 02h
    int 21h
    inc si
    loop print_9_loop
    ret
print_entry_9bytes endp

string_to_int proc
    ; Converts a 5-digit ASCII string at SI into an integer in AX.
    mov cx, 5
    mov ax, 0
    mov bx, 0
sti_loop:
    mov bl, [si]
    sub bl, '0'         ; ASCII to digit
    mov dx, 10
    mul dx              ; Multiply current total by 10
    add ax, bx          ; Add new digit
    inc si
    loop sti_loop
    ret
string_to_int endp

int_to_string_5 proc
    ; Converts integer in AX to 5-digit ASCII string at SI (backwards).
    add si, 4 
    mov cx, 5
    mov bx, 10
its_loop:
    mov dx, 0
    div bx              ; Divide by 10
    add dl, '0'         ; Remainder + '0' = ASCII digit
    mov [si], dl
    dec si
    loop its_loop
    ret
int_to_string_5 endp

; --- GAME LOGIC ---

letter_caught proc
    ; Called when player types correct letter.
    cmp [is_armored], 1         ; Armored enemies need 2 hits
    jne normal_hit
    mov [is_armored], 0         ; Remove armor
    mov [current_color], 0Eh 
    call sound_clank       
    call draw_char         
    inc [score]
    inc [streak]
    cmp [streak], 5             ; Combo threshold
    jl armor_ret
    mov [is_combo], 1
armor_ret:
    ret

normal_hit:
    call sound_beep
    cmp [current_color], 02h    ; Check for Toxic (Green) enemy
    je caught_toxic          
    
    ; Draw Explosion
    mov ax, 0B800h
    mov es, ax
    call get_video_offset
    mov al, '*'          
    mov ah, 0Ch          
    mov es:[di], ax
    mov cx, 0
    mov dx, 04000h       
    mov ah, 86h
    int 15h
    call erase_char

    ; Apply power-up logic based on color
    cmp [current_color], 03h    ; Freeze
    jne check_shield_hit
    mov [freeze_timer], 60   
    call sound_beep
    jmp regular_score

check_shield_hit:
    cmp [current_color], 0Fh    ; Shield
    jne check_streak
    mov [has_shield], 1
    call sound_beep
    jmp regular_score

check_streak:
    inc [streak]
    cmp [streak], 5
    jl check_healer
    mov [is_combo], 1   

check_healer:
    cmp [current_color], 0Ch    ; Healer (Red)
    jne check_ice
    cmp [lives], 3
    jge regular_score
    inc [lives]
    call sound_beep      
    jmp regular_score

check_ice:
    cmp [current_color], 0Bh    ; Ice (Slows game)
    jne regular_score
    mov [fall_speed], 15  
    call sound_beep       
    ; Flash Screen Blue
    mov ax, 0600h
    mov bh, 30h         
    mov cx, 0000h
    mov dx, 184Fh
    int 10h
    mov cx, 0
    mov dx, 02000h
    mov ah, 86h
    int 15h
    mov ax, 0600h
    mov bh, 07h         
    mov cx, 0000h
    mov dx, 184Fh       
    int 10h
    call draw_ground
    call draw_static_ui_vram

regular_score:
    inc [score]
    cmp [is_combo], 1
    jne no_bonus
    inc [score]         ; Double points for combo
no_bonus:
    call sound_beep
    jmp update_stats

caught_toxic:
    ; Toxic enemies hurt you if you catch them!
    cmp [has_shield], 1
    jne toxic_damage
    mov [has_shield], 0         ; Shield absorbs hit
    call sound_beep_bad
    mov [streak], 0
    mov [is_combo], 0
    call erase_char
    call spawn_new_letter
    ret

toxic_damage:
    call screen_shake_damage 
    call sound_beep_bad
    dec [lives]
    mov [streak], 0
    mov [is_combo], 0
    cmp [lives], 0
    je game_over_jump
    call erase_char
    call spawn_new_letter
    ret

game_over_jump:
    mov [game_active], 0
    ret

update_stats:
    ; Handles Level Up logic based on score thresholds.
    mov ax, [score]
    
check_speed:
    cmp [score], 40
    jge try_lvl_5
    cmp [score], 30
    jge try_lvl_4
    cmp [score], 20
    jge try_lvl_3
    cmp [score], 10
    jge try_lvl_2
    jmp finish_caught

try_lvl_2:
    cmp [level], 1      
    jne finish_caught
    mov [level], 2
    mov [fall_speed], 10        ; Increase speed
    mov [ground_color], 04h     ; Change floor color
    call apply_level_change
    jmp finish_caught

try_lvl_3:
    cmp [level], 2      
    jne finish_caught
    mov [level], 3
    mov [fall_speed], 6         
    mov [ground_color], 03h     
    call apply_level_change
    jmp finish_caught

try_lvl_4:
    cmp [level], 3      
    jne finish_caught
    mov [level], 4
    mov [fall_speed], 3         
    mov [ground_color], 05h     
    call apply_level_change
    jmp finish_caught

try_lvl_5:
    cmp [level], 4
    jne finish_caught
    mov [level], 5
    mov [fall_speed], 2         
    mov [ground_color], 06h     
    call apply_level_change
    jmp finish_caught

finish_caught:
    call spawn_new_letter
    ret
letter_caught endp

apply_level_change proc
    ; Visual effect for leveling up.
    call sound_beep          
    mov ax, 0600h
    mov bh, 07h
    mov cx, 0000h
    mov dx, 184Fh
    int 10h
    cmp [floor_y], 15
    jle redraw_floor
    dec [floor_y]               ; Move floor up (increases difficulty)
redraw_floor:
    call draw_ground
    call draw_static_ui_vram
    cmp [lives], 3
    jge no_heal_lvl
    inc [lives]                 ; Heal on level up
no_heal_lvl:
    ret
apply_level_change endp

move_letter_down proc
    ; Handles physics update for the falling letter.
    call erase_char 
    
    ; Wind Effect (Randomly move X)
    push ax
    push dx
    mov ah, 2Ch                 ; Get system time
    int 21h      
    test dl, 1      
    jz no_wind   
    test dl, 2      
    jz wind_left
wind_right:
    cmp [char_x], 78 
    jge no_wind
    inc [char_x]
    jmp no_wind
wind_left:
    cmp [char_x], 1  
    jle no_wind
    dec [char_x]
no_wind:
    pop dx
    pop ax

    inc [char_y]                ; Move down
    mov al, [floor_y]
    cmp [char_y], al
    jge hit_floor
    call draw_char
    ret

hit_floor:
    ; Letter hit the ground logic.
    cmp [current_color], 02h    ; Toxic enemies hitting floor is safe
    je safe_despawn
    cmp [has_shield], 1
    jne floor_damage
    mov [has_shield], 0
    call sound_beep_bad
    mov [streak], 0
    mov [is_combo], 0
    jmp safe_despawn

floor_damage:
    call screen_shake_damage 
    call sound_beep_bad
    dec [lives]
    mov [streak], 0
    mov [is_combo], 0
    cmp [lives], 0
    je trigger_game_over
    
safe_despawn:
    call spawn_new_letter
    ret

trigger_game_over:
    mov [game_active], 0
    ret
move_letter_down endp

spawn_new_letter proc
    ; Resets letter to top and picks random attributes.
    mov [char_y], 2     
    mov [is_armored], 0 
    
    ; Random X Position
    mov ah, 2Ch         
    int 21h             
    mov ax, 0
    mov al, dl          
    mov bl, 78          
    div bl              
    add ah, 1           
    mov [char_x], ah
    
    ; Random Character
    mov ax, 0
    mov al, dh
    add al, dl          
    mov bl, 26
    div bl              
    add ah, 'A'         
    mov [current_char], ah
    
    ; Random Type/Color
    mov al, dl
    and al, 0Fh         
    
    cmp al, 1           
    jle make_red        ; Healer
    cmp al, 3
    je make_toxic       ; Toxic
    cmp al, 5
    je make_ice         ; Slow
    cmp al, 7
    je make_shield      ; Shield
    cmp al, 9
    je make_freeze      ; Freeze
    cmp al, 11
    je make_armored     ; Armored
    cmp al, 13
    je make_mystery     ; Mystery
    
    mov byte ptr [current_color], 0Eh ; Default Yellow
    jmp draw_it

make_red:
    mov byte ptr [current_color], 0Ch 
    jmp draw_it
make_toxic:
    mov byte ptr [current_color], 02h 
    jmp draw_it
make_ice:
    mov byte ptr [current_color], 0Bh
    jmp draw_it
make_shield:
    mov byte ptr [current_color], 0Fh 
    jmp draw_it
make_freeze:
    mov byte ptr [current_color], 03h 
    jmp draw_it
make_armored:
    mov byte ptr [current_color], 08h 
    mov [is_armored], 1               
    jmp draw_it
make_mystery:
    mov byte ptr [current_color], 0Dh 
    jmp draw_it

draw_it:
    call draw_char
    ret
spawn_new_letter endp

screen_shake_damage proc
    ; Shakes the screen viewport to simulate impact.
    mov cx, 4 
shake_loop:
    push cx
    mov ax, 0600h
    mov bh, 40h 
    mov cx, 0000h
    mov dx, 184Fh
    int 10h
    mov cx, 0
    mov dx, 01000h
    mov ah, 86h
    int 15h
    mov ax, 0600h
    mov bh, 07h
    mov cx, 0000h
    mov dx, 184Fh
    int 10h
    pop cx
    loop shake_loop
    call draw_ground
    call draw_static_ui_vram
    ret
screen_shake_damage endp

draw_char proc
    ; Draws character directly to video memory.
    mov ax, 0B800h
    mov es, ax
    call get_video_offset
    mov al, [current_char]
    mov ah, [current_color] 
    
    cmp ah, 0Dh
    jne draw_now
    cmp [char_y], 12    ; Mystery letters are hidden below line 12
    jl draw_now
    mov al, '?'
    
draw_now:
    mov es:[di], ax
    ret
draw_char endp

erase_char proc
    ; Overwrites character with blank space.
    mov ax, 0B800h
    mov es, ax
    call get_video_offset
    mov al, ' '         
    mov ah, 07h         
    mov es:[di], ax
    ret
erase_char endp

get_video_offset proc
    ; Calculates VRAM offset from X,Y coords.
    mov al, [char_y]
    mov bl, 160
    mul bl
    mov di, ax
    mov al, [char_x]
    mov bl, 2
    mul bl
    add di, ax
    ret
get_video_offset endp

draw_static_ui_vram proc
    ; Draws static UI labels.
    mov si, offset v_score
    mov di, 0
    call print_vram_str
    
    mov si, offset v_lvl
    mov di, 80
    call print_vram_str
    
    mov si, offset v_lives
    mov di, 110
    call print_vram_str
    ret
draw_static_ui_vram endp

update_ui_vram proc
    ; Updates dynamic UI elements (score numbers, hearts).
    mov ax, [score]
    mov di, 14 
    call print_vram_num
    
    mov ax, 0
    mov al, [level]
    mov di, 90
    call print_vram_num
    
    ; Draw Hearts for lives
    mov ax, 0B800h
    mov es, ax
    mov di, 124 
    mov cl, 3 
    mov ch, [lives]
draw_h_loop:
    cmp ch, 0
    jg draw_real_heart
    mov word ptr es:[di], 0720h ; Blank if lost life
    jmp next_h
draw_real_heart:
    mov byte ptr es:[di], 03h   ; Heart symbol
    mov byte ptr es:[di+1], 0Ch ; Red color
    dec ch
next_h:
    add di, 2
    dec cl
    cmp cl, 0
    jg draw_h_loop
    
    ; Status Indicators
    mov si, offset v_blank
    mov di, 160
    call print_vram_str 
    
    mov di, 160 
    cmp [freeze_timer], 0
    jle check_nuke_vram
    mov si, offset v_freeze
    jmp print_pwr
check_nuke_vram:
    cmp [has_nuke], 1
    jne check_shield_vram
    mov si, offset v_nuke
    jmp print_pwr
check_shield_vram:
    cmp [has_shield], 1
    jne pwr_done
    mov si, offset v_shield
print_pwr:
    call print_vram_str
pwr_done:
    
    mov si, offset v_blank
    mov di, 280
    call print_vram_str 
    
    cmp [is_combo], 1
    jne ui_ret
    
    mov di, 280
    mov si, offset v_combo
    call print_vram_str

ui_ret:
    ret
update_ui_vram endp

print_vram_str proc
    ; Helper: Writes string to VRAM.
    mov ax, 0B800h
    mov es, ax
vstr_loop:
    mov al, [si]
    cmp al, 0
    je vstr_done
    mov es:[di], al
    mov byte ptr es:[di+1], 0Fh 
    inc si
    add di, 2
    jmp vstr_loop
vstr_done:
    ret
print_vram_str endp

print_vram_num proc
    ; Helper: Writes number to VRAM.
    mov bx, 10
    mov cx, 0
vnum_stack:
    mov dx, 0
    div bx
    push dx
    inc cx
    cmp ax, 0
    jne vnum_stack
    mov ax, 0B800h
    mov es, ax
vnum_print:
    pop dx
    add dl, '0'
    mov es:[di], dl
    mov byte ptr es:[di+1], 0Fh
    add di, 2
    loop vnum_print
    mov word ptr es:[di], 0720h 
    ret
print_vram_num endp

draw_ground proc
    ; Draws the floor line using direct video memory.
    mov ax, 0B800h
    mov es, ax
    mov al, [floor_y]
    mov bl, 160
    mul bl
    mov di, ax
    mov cx, 80          
    mov al, 177         ; Hatch character
    mov ah, [ground_color] 
draw_ground_loop:
    mov es:[di], ax
    add di, 2
    loop draw_ground_loop
    ret
draw_ground endp

print_num_bios proc
    ; Prints number using BIOS (for Game Over screen).
    push ax
    push bx
    push cx
    push dx
    mov cx, 0
    mov bx, 10
print_loop:
    mov dx, 0
    div bx
    push dx
    inc cx
    cmp ax, 0
    jne print_loop
print_pop:
    pop dx
    add dl, '0'
    mov ah, 02h
    int 21h
    loop print_pop
    pop dx
    pop cx
    pop bx
    pop ax
    ret
print_num_bios endp

; SOUND PROCEDURES
sound_beep proc
    mov ah, 02h
    mov dl, 07h
    int 21h
    ret
sound_beep endp

sound_clank proc
    mov ah, 02h
    mov dl, 07h
    int 21h
    ret
sound_clank endp

sound_beep_bad proc
    call sound_beep
    call sound_beep
    ret
sound_beep_bad endp

game_over_screen:
    ; Displays final score and prompts for restart.
    mov ax, 0003h
    int 10h
    mov ah, 02h
    mov dh, 10
    mov dl, 10
    int 10h
    mov dx, offset msg_gameover
    mov ah, 09h
    int 21h
    mov ax, [score]
    call print_num_bios
    
    ; Auto Sort into Top 3
    call update_leaderboard
    
    mov ah, 02h
    mov dh, 12
    mov dl, 10
    int 10h
    mov dx, offset msg_restart
    mov ah, 09h
    int 21h

wait_restart:
    mov ah, 00h
    int 16h
    cmp al, 'r'
    je get_name_screen 
    cmp al, 'R'
    je get_name_screen
    cmp al, 27
    je main_menu_init
    jmp wait_restart

exit_game:
    mov ax, 4c00h
    int 21h

end