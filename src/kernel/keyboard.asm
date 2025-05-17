;==================================================================
; NoX-OS Keyboard Handling
;==================================================================
; Keyboard input routines for the kernel

;------------------------------------------------------------------
; Function: init_keyboard
; Initialize the keyboard subsystem
;------------------------------------------------------------------
init_keyboard:
    ; For now, we'll just use BIOS keyboard services
    ; This is just a placeholder for future expansion
    ret

;------------------------------------------------------------------
; KEYBOARD SCAN CODE CONSTANTS
;------------------------------------------------------------------
; Some common key definitions (scan codes)
%define KEY_ESC     0x01
%define KEY_ENTER   0x1C
%define KEY_SPACE   0x39
%define KEY_BKSP    0x0E
%define KEY_TAB     0x0F
%define KEY_LCTRL   0x1D
%define KEY_LSHIFT  0x2A
%define KEY_RSHIFT  0x36
%define KEY_LALT    0x38
%define KEY_CAPS    0x3A
%define KEY_F1      0x3B
%define KEY_F2      0x3C
%define KEY_F3      0x3D
%define KEY_F4      0x3E
%define KEY_F5      0x3F
%define KEY_F6      0x40
%define KEY_F7      0x41
%define KEY_F8      0x42
%define KEY_F9      0x43
%define KEY_F10     0x44
%define KEY_F11     0x57
%define KEY_F12     0x58
%define KEY_UP      0x48
%define KEY_DOWN    0x50
%define KEY_LEFT    0x4B
%define KEY_RIGHT   0x4D
%define KEY_HOME    0x47
%define KEY_END     0x4F
%define KEY_PGUP    0x49
%define KEY_PGDN    0x51
%define KEY_INS     0x52
%define KEY_DEL     0x53

;------------------------------------------------------------------
; Function: check_key
; Checks if a key is pressed without waiting
; Output: ZF=1 if no key, ZF=0 if key available
;         If key available, AH=scan code, AL=ASCII
;------------------------------------------------------------------
check_key:
    mov ah, 0x01            ; BIOS keyboard status function
    int 0x16                ; Call BIOS keyboard service
    jz .no_key              ; If ZF=1, no key pressed
    
    ; Key is available, get it without removing from buffer
    mov ah, 0x11            ; BIOS peek key function
    int 0x16                ; Call BIOS keyboard service
    
.no_key:
    ret

;------------------------------------------------------------------
; Function: get_key
; Waits for key and returns it (removes from buffer)
; Output: AH=scan code, AL=ASCII
;------------------------------------------------------------------
get_key:
    mov ah, 0x00            ; BIOS get key function
    int 0x16                ; Call BIOS keyboard service
    ret

;------------------------------------------------------------------
; Function: wait_for_key
; Waits until a key is pressed
;------------------------------------------------------------------
wait_for_key:
    ; Just call get_key, discarding the result
    call get_key
    ret

;------------------------------------------------------------------
; Function: flush_keyboard_buffer
; Empties the keyboard buffer
;------------------------------------------------------------------
flush_keyboard_buffer:
    push ax
    
.loop:
    mov ah, 0x01            ; BIOS keyboard status function
    int 0x16                ; Call BIOS keyboard service
    jz .done                ; If ZF=1, no key in buffer
    
    ; Key is available, remove it from buffer
    mov ah, 0x00            ; BIOS get key function
    int 0x16                ; Call BIOS keyboard service
    
    jmp .loop               ; Check for more keys
    
.done:
    pop ax
    ret
