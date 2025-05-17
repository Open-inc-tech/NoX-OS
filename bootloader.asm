[org 0x7c00]

start:
    ; Clear the screen
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    ; Beep on boot
    call beep

    ; Delay for effect
    call delay

    ; Display welcome message
    mov si, welcome_msg
    call print_string

    ; Display version
    mov si, ver_msg
    call print_string

    ; Show ASCII logo
    mov si, logo
    call print_string

    ; Jump to kernel at 0x7E00
    jmp 0x0000:0x7e00

; --------------------------------
; Functions
; --------------------------------

print_string:
.loop:
    lodsb
    cmp al, 0
    je .done
    mov ah, 0x0e
    int 0x10
    jmp .loop
.done:
    ret

beep:
    ; Setup speaker tone
    mov al, 0xB6
    out 0x43, al
    mov ax, 1193
    out 0x42, al
    mov al, ah
    out 0x42, al

    in al, 0x61
    or al, 0x03
    out 0x61, al

    call delay_short

    in al, 0x61
    and al, 0xFC
    out 0x61, al
    ret

delay:
    mov cx, 0xFFFF
.loop:
    loop .loop
    ret

delay_short:
    mov cx, 0x1000
.loop:
    loop .loop
    ret

; --------------------------------
; Data
; --------------------------------

welcome_msg db "Nox-OS is booting...", 13, 10, 0
ver_msg     db "Version 0.2 [Real Mode Loader]", 13, 10, 0

logo db 13, 10
     db "    ____  ___            ____  ____ ", 13, 10
     db "   / __ \/   |  ______  / __ \/ __ \", 13, 10
     db "  / /_/ / /| | / ___/ |/ / / / / / /", 13, 10
     db " / ____/ ___ |/ /  |   / /_/ / /_/ /", 13, 10
     db "/_/   /_/  |_/_/   |_/|_____/____/ ", 13, 10, 0

; Boot sector must end with 0xAA55
times 510 - ($ - $$) db 0
dw 0xAA55
