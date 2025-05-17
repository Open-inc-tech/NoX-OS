;==================================================================
; NoX-OS Enhanced Bootloader
;==================================================================

BITS 16
ORG 0x7C00

;------------------------------------------------------------------
; CONSTANTS
;------------------------------------------------------------------
%define LOAD_SEGMENT 0x0000
%define LOAD_OFFSET 0x7E00
%define KERNEL_SIZE 32
%define SCREEN_WIDTH 80
%define SCREEN_HEIGHT 25
%define COLOR_ATTRIBUTE 0x1F    ; White on blue

; Boot drive number
boot_drive db 0

;------------------------------------------------------------------
; Entry point
;------------------------------------------------------------------
start:
    ; Set up segments and stack
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    ; Store boot drive
    mov [boot_drive], dl

    ; Set video mode (80x25 color text)
    mov ax, 0x0003
    int 0x10

    ; Clear screen and set colors
    call clear_screen

    ; Display welcome banner
    call display_welcome

    ; Show loading animation
    call loading_animation

    ; Load kernel
    call load_kernel
    jc disk_error

    ; Success message
    mov si, kernel_loaded_msg
    call print_centered

    ; Brief delay
    mov cx, 10
    call delay_loop

    ; Jump to kernel
    jmp LOAD_SEGMENT:LOAD_OFFSET

;------------------------------------------------------------------
; Display centered welcome message
;------------------------------------------------------------------
display_welcome:
    push ax
    push bx

    ; Calculate center position
    mov ah, 0x02
    mov bh, 0
    mov dh, 10
    mov dl, (SCREEN_WIDTH - 23) / 2
    int 0x10

    ; Print welcome message
    mov si, welcome_msg
    call print_string

    ; Optional beep
    mov ah, 0x0E
    mov al, 0x07
    int 0x10

    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Loading animation
;------------------------------------------------------------------
loading_animation:
    push ax
    push cx
    push dx

    mov cx, 4          ; Number of animation frames

.loop:
    mov ah, 0x02      ; Set cursor position
    mov bh, 0
    mov dh, 12
    mov dl, (SCREEN_WIDTH - 12) / 2
    int 0x10

    mov si, loading_msg
    call print_string

    push cx
    mov cx, 5         ; Delay duration
    call delay_loop
    pop cx

    loop .loop

    pop dx
    pop cx
    pop ax
    ret

;------------------------------------------------------------------
; Print centered string
; Input: SI = string pointer
;------------------------------------------------------------------
print_centered:
    push ax
    push bx
    push cx
    push dx

    ; Get string length
    mov cx, 0
    mov bx, si
.count:
    lodsb
    test al, al
    jz .done_count
    inc cx
    jmp .count
.done_count:
    mov si, bx        ; Restore SI

    ; Calculate center position
    mov ah, 0x02
    mov bh, 0
    mov dh, 12
    mov dl, (SCREEN_WIDTH - cx) / 2
    int 0x10

    ; Print string
    call print_string

    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: delay_loop
; Simple delay loop to wait a specified time
; Input: CX = delay counter
;------------------------------------------------------------------
delay_loop:
    push dx
.loop_delay:
    mov dx, 0xFFFF
.inner_loop:
    dec dx
    jnz .inner_loop
    loop .loop_delay
    pop dx
    ret

;------------------------------------------------------------------
; Function: clear_screen
; Clears the screen using BIOS video services and sets background color
;------------------------------------------------------------------
clear_screen:
    push ax
    push bx
    push cx
    push dx
    push di
    push es

    ; Set video mode (80x25 color text)
    mov ax, 0x0003
    int 0x10

    ; Clear screen with specified color
    mov ax, 0x0600
    mov bh, COLOR_ATTRIBUTE
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10

    ; Reset cursor position
    mov ah, 0x02
    mov bh, 0x00
    xor dx, dx
    int 0x10

    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: print_string
; Prints a null-terminated string
; Input: SI = pointer to string
;------------------------------------------------------------------
print_string:
    push ax
    push bx
    push bp
    push cx
    push di
    push dx
    push es
    push si

    mov ah, 0x0E      ; BIOS teletype function
    mov bh, 0       ; Page number
    mov bl, COLOR_ATTRIBUTE ; Text attribute (color)

.next_char:
    lodsb             ; Load byte from string
    test al, al       ; Check for end of string (null terminator)
    jz .done          ; If end of string, exit

    int 0x10          ; Print character

    jmp .next_char     ; Loop to next character

.done:
    pop si
    pop es
    pop dx
    pop di
    pop cx
    pop bp
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: load_kernel
; Loads the kernel from disk into memory using BIOS interrupts
; Output: CF set on error, clear on success
;------------------------------------------------------------------
load_kernel:
    push ax
    push bx
    push cx
    push dx
    push es
    push di

    ; Set up ES:BX for memory location to load to
    mov ax, LOAD_SEGMENT
    mov es, ax
    mov bx, LOAD_OFFSET

    ; Initialize retry counter
    mov di, 3

.retry:
    ; Prepare to read from disk
    mov ah, 0x02      ; Read sectors function
    mov al, KERNEL_SIZE     ; Number of sectors to read
    mov ch, 0       ; Cylinder 0
    mov cl, 2       ; Sector to start reading from (2 = after boot sector)
    mov dh, 0       ; Head 0
    mov dl, [boot_drive]    ; Drive number

    ; Read sectors from disk
    int 0x13          ; Call BIOS disk service
    jnc .success      ; Jump if no error (carry flag clear)

    ; Reset disk system and retry
    xor ax, ax
    int 0x13

    dec di            ; Decrement retry counter
    jnz .retry        ; Retry if counter not zero

    ; All retries failed
    stc               ; Set carry flag to indicate error
    jmp .done

.success:
    ; Verify number of sectors read
    cmp al, KERNEL_SIZE
    jne .error

    clc               ; Clear carry flag to indicate success
    jmp .done

.error:
    stc               ; Set carry flag to indicate error

.done:
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: disk_error
; Handles disk read errors
;------------------------------------------------------------------
disk_error:
    mov si, error_msg
    call print_string

    ; Hang the system or reboot
.hang:
    hlt
    jmp .hang

;------------------------------------------------------------------
; Data
;------------------------------------------------------------------
welcome_msg db 'Welcome to NoX-OS v1.0', 0x0D, 0x0A, 0
loading_msg db 'Loading...', 0
kernel_loaded_msg db 'Kernel loaded successfully!', 0
error_msg db 'Error loading kernel', 0

;------------------------------------------------------------------
; Boot sector signature
;------------------------------------------------------------------
times 510-($-$$) db 0
dw 0xAA55