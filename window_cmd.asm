;------------------------------------------------------------------
; Function: cmd_window
; Handles window-related commands
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_window:
    push si
    push di
    push ax
    push bx
    push cx
    push dx
    
    ; Skip "WINDOW" command
    call cmd_skip_token
    
    ; Skip whitespace
    call cmd_skip_whitespace
    
    ; Check if a subcommand was provided
    cmp byte [si], 0
    je .show_usage
    
    ; Check which subcommand
    mov di, si                  ; Save SI for subcommand comparison
    
    ; Check for CREATE subcommand
    mov si, window_create_cmd
    call strcmp_nocase
    jc .create_window
    
    ; Check for CLOSE subcommand
    mov si, window_close_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .close_window
    
    ; Check for LIST subcommand
    mov si, window_list_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .list_windows
    
    ; Check for WRITE subcommand
    mov si, window_write_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .write_window
    
    ; Unknown subcommand
.show_usage:
    mov si, window_usage_msg
    call print_string
    jmp .done
    
.create_window:
    ; Move SI past the CREATE token
    mov si, di
    call cmd_skip_token
    call cmd_skip_whitespace
    
    ; Parse width parameter
    cmp byte [si], 0
    je .show_usage
    call parse_number
    jc .show_usage
    mov bl, al                   ; Width in BL
    
    ; Skip to height parameter
    call cmd_skip_token
    call cmd_skip_whitespace
    
    ; Parse height parameter
    cmp byte [si], 0
    je .show_usage
    call parse_number
    jc .show_usage
    mov bh, al                   ; Height in BH
    
    ; Skip to title parameter
    call cmd_skip_token
    call cmd_skip_whitespace
    
    ; Check if title was provided
    cmp byte [si], 0
    je .show_usage
    
    ; Create window
    ; Calculate position (for simplicity, use fixed position for now)
    mov al, 5                    ; X position
    mov ah, 5                    ; Y position
    ; BL, BH already contain width and height
    ; SI already points to the title
    call window_create
    
    ; Check if creation was successful
    test al, al
    jz .create_failed
    
    ; Display success message
    mov si, window_created_msg
    call print_string
    
    movzx ax, al                 ; Window ID
    call cmd_print_dec
    call print_newline
    
    jmp .done
    
.create_failed:
    mov si, window_failed_msg
    call print_string
    jmp .done
    
.close_window:
    ; Move SI past the CLOSE token
    mov si, di
    call cmd_skip_token
    call cmd_skip_whitespace
    
    ; Parse window ID parameter
    cmp byte [si], 0
    je .show_usage
    call parse_number
    jc .show_usage
    
    ; Close window
    ; AL already contains window ID
    call window_close
    
    ; Display success message
    mov si, window_closed_msg
    call print_string
    
    jmp .done
    
.list_windows:
    ; Display header
    mov si, window_list_header_msg
    call print_string
    
    ; Check if there are any windows
    cmp byte [window_count], 0
    je .no_windows
    
    ; Display window information
    mov si, window_table
    mov cx, MAX_WINDOWS
    
.list_loop:
    ; Check if window slot is active
    cmp byte [si + WINDOW.id], 0
    je .next_window
    
    ; Display window ID
    movzx ax, byte [si + WINDOW.id]
    call cmd_print_dec
    
    ; Add spacing
    mov al, ' '
    call print_char
    call print_char
    call print_char
    call print_char
    
    ; Display window size
    movzx ax, byte [si + WINDOW.width]
    call cmd_print_dec
    
    mov al, 'x'
    call print_char
    
    movzx ax, byte [si + WINDOW.height]
    call cmd_print_dec
    
    ; Add spacing
    mov al, ' '
    call print_char
    call print_char
    call print_char
    call print_char
    
    ; Display window title
    push si
    add si, WINDOW.title
    call print_string
    pop si
    
    call print_newline
    
.next_window:
    add si, WINDOW_size
    loop .list_loop
    
    jmp .done
    
.no_windows:
    mov si, window_no_windows_msg
    call print_string
    jmp .done
    
.write_window:
    ; Move SI past the WRITE token
    mov si, di
    call cmd_skip_token
    call cmd_skip_whitespace
    
    ; Parse window ID parameter
    cmp byte [si], 0
    je .show_usage
    call parse_number
    jc .show_usage
    
    ; Save window ID
    push ax
    
    ; Skip to text
    call cmd_skip_token
    call cmd_skip_whitespace
    
    ; Check if text was provided
    cmp byte [si], 0
    je .write_missing_text
    
    ; Write to window
    pop ax                       ; Restore window ID
    mov bl, 1                    ; X position (relative)
    mov bh, 1                    ; Y position (relative)
    ; SI already points to text
    call window_print
    
    jmp .done
    
.write_missing_text:
    pop ax                       ; Clean up stack
    jmp .show_usage
    
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    pop di
    pop si
    ret