;------------------------------------------------------------------
; Function: cmd_mouse
; Handles mouse-related commands
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_mouse:
    push si
    push di
    push ax
    push bx
    push cx
    
    ; Skip "MOUSE" command
    call cmd_skip_token
    
    ; Skip whitespace
    call cmd_skip_whitespace
    
    ; Check if a subcommand was provided
    cmp byte [si], 0
    je .show_status
    
    ; Check which subcommand
    mov di, si                  ; Save SI for subcommand comparison
    
    ; Check for SHOW subcommand
    mov si, mouse_show_cmd
    call strcmp_nocase
    jc .show_mouse
    
    ; Check for HIDE subcommand
    mov si, mouse_hide_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .hide_mouse
    
    ; Check for STATUS subcommand
    mov si, mouse_status_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .show_status
    
    ; Unknown subcommand
    mov si, mouse_usage_msg
    call print_string
    jmp .done
    
.show_mouse:
    ; Show mouse cursor
    call mouse_show
    
    ; Display confirmation
    mov si, mouse_show_msg
    call print_string
    jmp .done
    
.hide_mouse:
    ; Hide mouse cursor
    call mouse_hide
    
    ; Display confirmation
    mov si, mouse_hide_msg
    call print_string
    jmp .done
    
.show_status:
    ; Display mouse status
    call mouse_is_installed
    test al, al
    jz .not_installed
    
    ; Display status header
    mov si, mouse_status_msg
    call print_string
    
    ; Show if mouse is installed
    mov si, mouse_installed_msg
    call print_string
    mov si, mouse_show_msg      ; "Yes"
    call print_string
    
    ; Display current position
    mov si, mouse_position_msg
    call print_string
    
    ; Show X position
    mov ax, [mouse_x]
    call cmd_print_dec
    
    ; Show Y position
    mov si, mouse_y_pos_msg
    call print_string
    mov ax, [mouse_y]
    call cmd_print_dec
    call print_newline
    
    ; Display button state
    mov si, mouse_buttons_msg
    call print_string
    
    ; Check which buttons are pressed
    mov al, [mouse_buttons]
    test al, al                 ; Check if any buttons pressed
    jz .no_buttons
    
    ; Check left button
    test al, 1
    jz .check_right
    mov si, mouse_left_msg
    call print_string
    
.check_right:
    ; Check right button
    test al, 2
    jz .check_middle
    mov si, mouse_right_msg
    call print_string
    
.check_middle:
    ; Check middle button
    test al, 4
    jz .buttons_done
    mov si, mouse_middle_msg
    call print_string
    
.buttons_done:
    call print_newline
    jmp .done
    
.no_buttons:
    mov si, mouse_none_msg
    call print_string
    call print_newline
    jmp .done
    
.not_installed:
    mov si, mouse_not_installed_msg
    call print_string
    
.done:
    pop cx
    pop bx
    pop ax
    pop di
    pop si
    ret