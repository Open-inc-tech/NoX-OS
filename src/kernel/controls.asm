
;==================================================================
; NoX-OS UI Controls
;==================================================================

;------------------------------------------------------------------
; Function: create_button
; Creates a clickable button
;------------------------------------------------------------------
create_button:
    push ax
    push bx
    push cx
    push dx
    
    ; Draw button border
    mov al, '['
    call draw_char
    
    ; Draw button text
    mov cx, si          ; Save text pointer
    call print_string
    
    ; Draw button end
    mov al, ']'
    call draw_char
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: create_checkbox
; Creates a checkbox control
;------------------------------------------------------------------
create_checkbox:
    push ax
    
    ; Draw checkbox
    mov al, '['
    call draw_char
    
    ; Draw check state
    mov al, bl
    test al, al
    jz .unchecked
    mov al, 'X'
    jmp .draw_state
.unchecked:
    mov al, ' '
.draw_state:
    call draw_char
    
    ; Draw checkbox end
    mov al, ']'
    call draw_char
    
    pop ax
    ret
