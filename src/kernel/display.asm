
;==================================================================
; NoX-OS Display Handling
;==================================================================

section .data
; Display attributes
ATTR_NORMAL     equ 0x07    ; Light gray on black
ATTR_HIGHLIGHT  equ 0x0F    ; White on black
ATTR_ERROR      equ 0x04    ; Red on black
ATTR_SUCCESS    equ 0x02    ; Green on black
ATTR_INFO       equ 0x09    ; Blue on black

; Screen dimensions
SCREEN_WIDTH    equ 80
SCREEN_HEIGHT   equ 25
VIDEO_MEM       equ 0xB800

section .text
;------------------------------------------------------------------
; Function: clear_screen
; Clears the entire screen with specified attribute
;------------------------------------------------------------------
clear_screen:
    push ax
    push cx
    push di
    push es
    
    mov ax, VIDEO_MEM
    mov es, ax
    xor di, di
    mov ax, 0x0720      ; Space with normal attribute
    mov cx, SCREEN_WIDTH * SCREEN_HEIGHT
    rep stosw
    
    pop es
    pop di
    pop cx
    pop ax
    ret

;------------------------------------------------------------------
; Function: print_string_attr
; Prints a string with specified attribute
; Input: SI = string address, BL = attribute, DH = row, DL = column
;------------------------------------------------------------------
print_string_attr:
    push ax
    push bx
    push cx
    push di
    push es
    
    mov ax, VIDEO_MEM
    mov es, ax
    
    ; Calculate screen position
    movzx ax, dh
    mov cx, SCREEN_WIDTH * 2
    mul cx
    movzx cx, dl
    shl cx, 1
    add ax, cx
    mov di, ax
    
    mov ah, bl          ; Attribute
    
.loop:
    lodsb               ; Load character
    test al, al         ; Check for null terminator
    jz .done
    stosw               ; Write char and attribute
    jmp .loop
    
.done:
    pop es
    pop di
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: scroll_screen
; Scrolls screen up by one line
;------------------------------------------------------------------
scroll_screen:
    push ax
    push cx
    push si
    push di
    push es
    push ds
    
    mov ax, VIDEO_MEM
    mov ds, ax
    mov es, ax
    
    ; Copy lines up
    mov si, SCREEN_WIDTH * 2  ; Source: second line
    xor di, di               ; Destination: first line
    mov cx, (SCREEN_HEIGHT - 1) * SCREEN_WIDTH
    rep movsw
    
    ; Clear bottom line
    mov cx, SCREEN_WIDTH
    mov ax, 0x0720          ; Space with normal attribute
    rep stosw
    
    pop ds
    pop es
    pop di
    pop si
    pop cx
    pop ax
    ret
