;==================================================================
; NoX-OS Kernel
;==================================================================
; The main kernel file for NoX-OS. This handles initialization
; and provides the main execution loop for the system.

BITS 16                     ; We're working with 16-bit code
ORG 0x0000                  ; We're loaded at offset 0 in the segment

%include "src/include/constants.inc"

;------------------------------------------------------------------
; Kernel entry point
;------------------------------------------------------------------
kernel_start:
    ; Set up segment registers and stack
    mov ax, cs              ; Get current segment
    mov ds, ax              ; Set data segment
    mov es, ax              ; Set extra segment
    mov ss, ax              ; Set stack segment
    mov sp, 0xFFF0          ; Set stack pointer
    
    ; Clear the screen
    call clear_screen
    
    ; Display welcome message
    mov si, welcome_msg
    call print_string
    
    ; Initialize system components
    call init_keyboard      ; Initialize keyboard
    call fat_init           ; Initialize FAT file system
    call mem_init           ; Initialize advanced memory management
    call taskbar_init       ; Initialize taskbar
    call window_init        ; Initialize window system
    call task_init          ; Initialize multitasking system
    call mouse_init         ; Initialize mouse driver
    
    ; Display the taskbar
    call taskbar_show
    
    ; Enter the main kernel loop
    jmp main_loop

;------------------------------------------------------------------
; Main kernel execution loop
;------------------------------------------------------------------
main_loop:
    ; Update taskbar (time, memory status, etc.)
    call taskbar_update
    
    ; Update mouse cursor
    call mouse_update
    
    ; Display command prompt
    mov si, prompt
    call print_string
    
    ; Get user input
    mov di, cmd_line
    call read_line
    
    ; Get the command directly from cmd_line
    mov si, cmd_line
    
    ; Process the command
    call process_command
    
    ; Repeat the loop
    jmp main_loop

; Note: process_command is defined in command.asm

;------------------------------------------------------------------
; External Functions - Will be included from other files
;------------------------------------------------------------------
%include "src/kernel/io.asm"
%include "src/kernel/keyboard.asm"
%include "src/kernel/display.asm"
%include "src/kernel/disk.asm"
%include "src/kernel/fat.asm"
%include "src/kernel/memory.asm"
%include "src/kernel/taskbar.asm"
%include "src/kernel/window.asm"
%include "src/kernel/task.asm"
%include "src/kernel/mouse.asm"
%include "src/kernel/command.asm"
%include "src/kernel/editor.asm"

;------------------------------------------------------------------
; DATA SECTION
;------------------------------------------------------------------
welcome_msg db 'NoX-OS v0.3.0 Enhanced Edition', 0x0D, 0x0A
           db 'A practical 16-bit operating system', 0x0D, 0x0A
           db 'Copyright (c) 2023-2025', 0x0D, 0x0A
           db 'Type "help" for commands or "ver" for version info', 0x0D, 0x0A, 0

prompt db 0x0D, 0x0A, 'NoX> ', 0

; Note: unknown_cmd_msg is defined in command.asm