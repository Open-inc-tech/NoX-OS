;==================================================================
; NoX-OS Display Handling
;==================================================================
; Display output routines for the kernel

;------------------------------------------------------------------
; VIDEO CONSTANTS
;------------------------------------------------------------------
%define VIDEO_MEM 0xB800    ; Base address of video memory
%define VIDEO_COLS 80       ; Number of columns
%define VIDEO_ROWS 25       ; Number of rows
%define CHAR_ATTR 0x07      ; Default character attribute (white on black)

;------------------------------------------------------------------
; Function: scroll_screen
; Scrolls the screen up by N lines
; Input: AL = number of lines to scroll
;------------------------------------------------------------------
scroll_screen:
    push ax
    push bx
    push cx
    push dx
    
    ; Use BIOS scroll function
    mov ah, 0x06            ; Scroll window up function
    mov bh, CHAR_ATTR       ; Character attribute
    mov cx, 0               ; Upper left corner (0,0)
    mov dh, VIDEO_ROWS - 1  ; Lower right corner row (bottom of screen)
    mov dl, VIDEO_COLS - 1  ; Lower right corner column (right side of screen)
    int 0x10                ; Call BIOS video service
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: draw_box
; Draws a simple box using BIOS text functions (simplified)
;------------------------------------------------------------------
draw_box:
    ; This is a simplified stub that doesn't actually draw a box
    ; due to the complexities of direct video memory manipulation
    ; in this simple OS
    ret