
;==================================================================
; NoX-OS UI Module
;==================================================================

section .data
ui_initialized db 0
desktop_color   db 0x17    ; Blue background, white text
taskbar_height  db 1       ; Height of taskbar in rows

section .text
;------------------------------------------------------------------
; Function: ui_init
; Initializes the user interface
;------------------------------------------------------------------
ui_init:
    push ax
    push bx
    
    ; Check if already initialized
    cmp byte [ui_initialized], 1
    je .done
    
    ; Clear screen with desktop color
    mov ah, 0x06    ; Scroll up function
    mov al, 0       ; Clear entire screen
    mov bh, [desktop_color]
    xor cx, cx      ; Upper left: (0,0)
    mov dx, 0x184F  ; Lower right: (79,24)
    int 0x10
    
    ; Initialize taskbar
    call init_taskbar
    
    ; Initialize window system
    call window_init
    
    ; Mark as initialized
    mov byte [ui_initialized], 1
    
.done:
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: draw_desktop
; Draws the desktop background
;------------------------------------------------------------------
draw_desktop:
    push ax
    push bx
    push cx
    push dx
    
    ; Clear screen with desktop color
    mov ah, 0x06    ; Scroll up function
    mov al, 0       ; Clear entire screen
    mov bh, [desktop_color]
    xor cx, cx      ; Upper left: (0,0)
    mov dx, 0x184F  ; Lower right: (79,24)
    int 0x10
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: draw_status_bar
; Draws the status bar at the bottom of the screen
;------------------------------------------------------------------
draw_status_bar:
    push ax
    push bx
    push cx
    push dx
    push si
    
    ; Position cursor at bottom of screen
    mov ah, 0x02
    mov bh, 0
    mov dh, 24
    mov dl, 0
    int 0x10
    
    ; Draw status bar background
    mov ah, 0x09
    mov al, ' '
    mov bh, 0
    mov bl, 0x70    ; White background, black text
    mov cx, 80      ; Full width
    int 0x10
    
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
