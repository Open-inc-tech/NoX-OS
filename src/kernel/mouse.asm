;==================================================================
; NoX-OS Mouse Driver
;==================================================================
; Implements a mouse driver with graphical cursor - a feature not present 
; in standard MS-DOS

;------------------------------------------------------------------
; Constants and Variables
;------------------------------------------------------------------
%define MOUSE_INT 0x33          ; Mouse interrupt

; Mouse data
mouse_installed db 0             ; Whether mouse is installed (1) or not (0)
mouse_x dw 0                     ; Current X position (0-639)
mouse_y dw 0                     ; Current Y position (0-199)
mouse_buttons db 0               ; Button state (bit 0 = left, bit 1 = right, bit 2 = middle)
mouse_old_x dw 0                 ; Previous X position
mouse_old_y dw 0                 ; Previous Y position
mouse_old_buttons db 0           ; Previous button state
mouse_cursor_visible db 0        ; Whether cursor is visible
mouse_screen_buffer: times 32 db 0 ; Buffer to save screen data under cursor

; Mouse cursor shape (16x16 bitmap, 32 bytes)
mouse_cursor_data:
    db 11111111b, 11111111b    ; Row 1: ████████ ████████
    db 10000000b, 00000000b    ; Row 2: █        
    db 10100000b, 00000000b    ; Row 3: █ █      
    db 10110000b, 00000000b    ; Row 4: █ ██     
    db 10111000b, 00000000b    ; Row 5: █ ███    
    db 10111100b, 00000000b    ; Row 6: █ ████   
    db 10111110b, 00000000b    ; Row 7: █ █████  
    db 10111111b, 00000000b    ; Row 8: █ ██████ 
    db 10111111b, 10000000b    ; Row 9: █ ███████
    db 10111110b, 00000000b    ; Row 10: █ █████  
    db 10110110b, 00000000b    ; Row 11: █ ██ ██  
    db 10100011b, 00000000b    ; Row 12: █ █  ██  
    db 10000001b, 10000000b    ; Row 13: █    ███ 
    db 00000001b, 10000000b    ; Row 14:      ███ 
    db 00000000b, 11000000b    ; Row 15:       ██ 
    db 00000000b, 00000000b    ; Row 16:          

;------------------------------------------------------------------
; Function: mouse_init
; Initializes the mouse driver
; Output: AX = 0 if failed, nonzero if successful
;------------------------------------------------------------------
mouse_init:
    push bx
    push cx
    push dx
    
    ; Reset mouse driver
    mov ax, 0
    int MOUSE_INT
    
    ; Check if mouse driver is installed
    test ax, ax
    jz .no_mouse
    
    ; Initialize mouse position to center of screen
    mov ax, 4                    ; Set mouse position
    mov cx, 320                  ; X position (center)
    mov dx, 100                  ; Y position (center)
    int MOUSE_INT
    
    ; Show mouse cursor
    mov ax, 1
    int MOUSE_INT
    
    ; Set mouse cursor visible flag
    mov byte [mouse_cursor_visible], 1
    
    ; Set mouse installed flag
    mov byte [mouse_installed], 1
    
    mov ax, 1                    ; Return success
    jmp .done
    
.no_mouse:
    mov byte [mouse_installed], 0
    xor ax, ax                   ; Return failure
    
.done:
    pop dx
    pop cx
    pop bx
    ret

;------------------------------------------------------------------
; Function: mouse_update
; Updates mouse position and button state
;------------------------------------------------------------------
mouse_update:
    push ax
    push bx
    push cx
    push dx
    
    ; Check if mouse is installed
    cmp byte [mouse_installed], 0
    je .done
    
    ; Save old position and button state
    mov ax, [mouse_x]
    mov [mouse_old_x], ax
    mov ax, [mouse_y]
    mov [mouse_old_y], ax
    mov al, [mouse_buttons]
    mov [mouse_old_buttons], al
    
    ; Get mouse position and button state
    mov ax, 3                    ; Get mouse position and button status
    int MOUSE_INT
    
    ; Save new position and button state
    shr cx, 1                    ; Adjust X coordinate (0-639)
    mov [mouse_x], cx
    mov [mouse_y], dx
    mov [mouse_buttons], bl
    
    ; Update the cursor
    call mouse_draw_cursor
    
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: mouse_draw_cursor
; Draws the mouse cursor at current position
;------------------------------------------------------------------
mouse_draw_cursor:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    ; Check if mouse is installed
    cmp byte [mouse_installed], 0
    je .done
    
    ; Check if cursor is visible
    cmp byte [mouse_cursor_visible], 0
    je .done
    
    ; Set up video memory
    mov ax, 0xB800
    mov es, ax
    
    ; Erase old cursor if position changed
    mov ax, [mouse_x]
    cmp ax, [mouse_old_x]
    jne .erase_old
    mov ax, [mouse_y]
    cmp ax, [mouse_old_y]
    jne .erase_old
    jmp .draw_new
    
.erase_old:
    ; Calculate old screen position (row * 80 + col) * 2
    mov ax, [mouse_old_y]
    shr ax, 3                    ; Divide by 8 to get row (assuming 8x8 character cells)
    mov cx, 80
    mul cx                       ; AX = row * 80
    mov cx, [mouse_old_x]
    shr cx, 3                    ; Divide by 8 to get column
    add ax, cx                   ; AX = row * 80 + col
    shl ax, 1                    ; AX = (row * 80 + col) * 2
    mov di, ax                   ; DI = offset in video memory
    
    ; Restore character at cursor position
    mov word [es:di], 0x0720     ; Space with normal attribute (white on black)
    
.draw_new:
    ; Calculate new screen position (row * 80 + col) * 2
    mov ax, [mouse_y]
    shr ax, 3                    ; Divide by 8 to get row
    mov cx, 80
    mul cx                       ; AX = row * 80
    mov cx, [mouse_x]
    shr cx, 3                    ; Divide by 8 to get column
    add ax, cx                   ; AX = row * 80 + col
    shl ax, 1                    ; AX = (row * 80 + col) * 2
    mov di, ax                   ; DI = offset in video memory
    
    ; Draw cursor character
    mov ax, 0x0F01               ; White on black, ☺ character
    mov [es:di], ax
    
.done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: mouse_show
; Shows the mouse cursor
;------------------------------------------------------------------
mouse_show:
    cmp byte [mouse_installed], 0
    je .done
    
    mov byte [mouse_cursor_visible], 1
    
    ; Show hardware cursor
    mov ax, 1
    int MOUSE_INT
    
    ; Draw the cursor
    call mouse_draw_cursor
    
.done:
    ret

;------------------------------------------------------------------
; Function: mouse_hide
; Hides the mouse cursor
;------------------------------------------------------------------
mouse_hide:
    cmp byte [mouse_installed], 0
    je .done
    
    mov byte [mouse_cursor_visible], 0
    
    ; Hide hardware cursor
    mov ax, 2
    int MOUSE_INT
    
    ; Calculate screen position (row * 80 + col) * 2
    mov ax, [mouse_y]
    shr ax, 3                    ; Divide by 8 to get row
    mov cx, 80
    mul cx                       ; AX = row * 80
    mov cx, [mouse_x]
    shr cx, 3                    ; Divide by 8 to get column
    add ax, cx                   ; AX = row * 80 + col
    shl ax, 1                    ; AX = (row * 80 + col) * 2
    mov di, ax                   ; DI = offset in video memory
    
    ; Restore character at cursor position
    mov ax, 0xB800
    mov es, ax
    mov word [es:di], 0x0720     ; Space with normal attribute
    
.done:
    ret

;------------------------------------------------------------------
; Function: mouse_is_installed
; Checks if mouse is installed
; Output: AL = 1 if installed, 0 if not
;------------------------------------------------------------------
mouse_is_installed:
    mov al, [mouse_installed]
    ret