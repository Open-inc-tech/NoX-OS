;==================================================================
; NoX-OS Bootloader
;==================================================================
; This bootloader initializes the system, sets up the stack,
; displays a welcome message, and loads the kernel from disk.
;
; Real mode bootloader that loads NoX-OS kernel from floppy disk

BITS 16                     ; We're working with 16-bit code
ORG 0x7C00                  ; Standard boot sector loading address

;------------------------------------------------------------------
; CONSTANTS
;------------------------------------------------------------------
%define LOAD_SEGMENT 0x1000 ; Segment where kernel will be loaded
%define LOAD_OFFSET 0x0000  ; Offset where kernel will be loaded
%define KERNEL_SEGMENT 0x1000 ; Segment address to jump to kernel
%define KERNEL_OFFSET 0x0000  ; Offset within the segment for the kernel
%define KERNEL_SIZE 32      ; Size of kernel in sectors (adjust as needed)
%define KERNEL_START_SECTOR 2 ; Starting sector for kernel (boot sector is 1)

; Boot disk drive number (will be set by BIOS)
boot_drive db 0

;------------------------------------------------------------------
; Boot sector entry point
;------------------------------------------------------------------
start:
    cli                     ; Disable interrupts while we set up
    
    ; Set up segment registers
    xor ax, ax              ; Clear AX register
    mov ds, ax              ; Data segment = 0
    mov es, ax              ; Extra segment = 0
    mov ss, ax              ; Stack segment = 0
    mov sp, 0x7C00          ; Stack pointer just below bootloader
    
    sti                     ; Enable interrupts again
    
    ; Store boot drive number
    mov [boot_drive], dl
    
    ; Clear the screen
    call clear_screen
    
    ; Display boot message
    mov si, boot_msg
    call print_string
    
    ; Load the kernel from disk
    call load_kernel
    jc disk_error           ; If carry flag set, we have an error
    
    ; Display kernel loaded message
    mov si, kernel_loaded_msg
    call print_string
    
    ; Wait briefly to show the message
    mov cx, 0x0010          ; Outer loop
    mov dx, 0xFFFF          ; Inner loop
    call delay_loop
    
    ; Set drive number in DL for kernel
    mov dl, [boot_drive]
    
    ; Jump to kernel
    jmp KERNEL_SEGMENT:KERNEL_OFFSET

;------------------------------------------------------------------
; SUBROUTINES
;------------------------------------------------------------------

;------------------------------------------------------------------
; Function: delay_loop
; Simple delay loop to wait a specified time
; Input: CX:DX = delay counter
;------------------------------------------------------------------
delay_loop:
    dec dx
    jnz delay_loop
    dec cx
    jnz delay_loop
    ret

;------------------------------------------------------------------
; Function: clear_screen
; Clears the screen using BIOS video services
;------------------------------------------------------------------
clear_screen:
    push ax
    push bx
    
    mov ah, 0x00            ; Set video mode function
    mov al, 0x03            ; 80x25 text mode
    int 0x10                ; Call BIOS video service
    
    mov ah, 0x06            ; Scroll window up function
    mov al, 0               ; Clear entire window
    mov bh, 0x07            ; Normal attribute (white on black)
    mov cx, 0               ; Upper left corner (0,0)
    mov dh, 24              ; Lower right corner row (bottom of screen)
    mov dl, 79              ; Lower right corner column (right side of screen)
    int 0x10                ; Call BIOS video service
    
    ; Reset cursor position
    mov ah, 0x02            ; Set cursor position function
    mov bh, 0               ; Page number
    mov dh, 0               ; Row
    mov dl, 0               ; Column
    int 0x10                ; Call BIOS video service
    
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
    
    mov ah, 0x0E            ; BIOS teletype function
    mov bh, 0               ; Page number
    mov bl, 0x07            ; Text attribute (white on black)
    
.loop:
    lodsb                   ; Load byte from SI into AL and increment SI
    test al, al             ; Check if character is 0 (end of string)
    jz .done                ; If zero, we're done
    int 0x10                ; Print the character
    jmp .loop               ; Repeat for next character
    
.done:
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
    
    ; Set up ES:BX for memory location to load to
    mov ax, LOAD_SEGMENT
    mov es, ax
    mov bx, LOAD_OFFSET     ; ES:BX -> where the kernel will be loaded
    
    ; Initialize retry counter
    mov di, 3               ; 3 retries
    
.retry:
    ; Prepare to read from disk
    mov ah, 0x02            ; Read sectors function
    mov al, KERNEL_SIZE     ; Number of sectors to read
    mov ch, 0               ; Cylinder 0
    mov cl, KERNEL_START_SECTOR ; Start from sector after boot sector
    mov dh, 0               ; Head 0
    mov dl, [boot_drive]    ; Drive number from boot
    
    ; Read from disk
    int 0x13                ; Call BIOS disk service
    jnc .success            ; If carry flag clear, read was successful
    
    ; Reset disk system and retry
    xor ax, ax
    int 0x13                ; Reset disk system
    
    dec di                  ; Decrement retry counter
    jnz .retry              ; Try again if retries remaining
    
    ; All retries failed
    stc                     ; Set carry flag to indicate error
    jmp .done
    
.success:
    ; Verify correct number of sectors read
    cmp al, KERNEL_SIZE     ; Compare number of sectors actually read
    jne .error              ; If not equal, we have an error
    
    clc                     ; Clear carry flag to indicate success
    jmp .done
    
.error:
    stc                     ; Set carry flag to indicate error
    
.done:
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
    mov si, disk_error_msg
    call print_string
    
    ; Wait for a keypress
.wait_key:
    mov ah, 0x00            ; BIOS get key function
    int 0x16                ; Call BIOS keyboard service
    
    ; Reboot the system
    mov si, reboot_msg
    call print_string
    
    ; Wait briefly
    mov cx, 0x0010          ; Outer loop
    mov dx, 0xFFFF          ; Inner loop
    call delay_loop
    
    ; Jump to reset vector
    jmp 0xFFFF:0x0000

;------------------------------------------------------------------
; DATA SECTION
;------------------------------------------------------------------
boot_msg db 'NoX-OS Bootloader v0.3', 0x0D, 0x0A, 'Loading kernel...', 0x0D, 0x0A, 0
kernel_loaded_msg db 'Kernel loaded successfully, transferring control...', 0x0D, 0x0A, 0
disk_error_msg db 'Error: Failed to load kernel from disk!', 0x0D, 0x0A
              db 'Press any key to reboot...', 0x0D, 0x0A, 0
reboot_msg db 'Rebooting system...', 0x0D, 0x0A, 0

;------------------------------------------------------------------
; Padding and boot signature
;------------------------------------------------------------------
times 510-($-$$) db 0       ; Pad the boot sector to 510 bytes
dw 0xAA55                   ; Boot signature (required by BIOS)