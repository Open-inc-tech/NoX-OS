
;==================================================================
; NoX-OS Cursor Control
;==================================================================

section .data
cursor_x db 0
cursor_y db 0

section .text
;------------------------------------------------------------------
; Function: set_cursor
; Sets hardware cursor position
; Input: DH = row, DL = column
;------------------------------------------------------------------
set_cursor:
    push ax
    push bx
    push dx
    
    mov ah, 0x02    ; Set cursor position
    xor bh, bh      ; Page 0
    int 0x10
    
    ; Store cursor position
    mov [cursor_x], dl
    mov [cursor_y], dh
    
    pop dx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: get_cursor
; Gets current cursor position
; Output: DH = row, DL = column
;------------------------------------------------------------------
get_cursor:
    mov dh, [cursor_y]
    mov dl, [cursor_x]
    ret

;------------------------------------------------------------------
; Function: cursor_next_line
; Moves cursor to start of next line, scrolling if needed
;------------------------------------------------------------------
cursor_next_line:
    push ax
    
    xor dl, dl          ; Column 0
    mov dh, [cursor_y]
    inc dh              ; Next row
    
    cmp dh, SCREEN_HEIGHT - 1
    jb .set_pos
    
    ; Need to scroll
    call scroll_screen
    mov dh, SCREEN_HEIGHT - 2
    
.set_pos:
    call set_cursor
    
    pop ax
    ret
