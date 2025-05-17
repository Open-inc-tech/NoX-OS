;==================================================================
; NoX-OS Enhanced Kernel
;==================================================================

BITS 16
ORG 0x7E00

;------------------------------------------------------------------
; Constants
;------------------------------------------------------------------
%define MAX_WINDOWS 4
%define SCREEN_WIDTH 80
%define SCREEN_HEIGHT 25
%define STATUS_BAR_COLOR 0x70    ; Black on white
%define WINDOW_COLOR 0x1F        ; White on blue

;------------------------------------------------------------------
; Entry point
;------------------------------------------------------------------
start:
    ; Set up segments
    mov ax, cs
    mov ds, ax
    mov es, ax

    ; Initialize system with error checking
    call init_system
    jc system_init_failed

    call init_ui
    jc ui_init_failed

    ; Initialize system timer
    call init_timer

    ; Enable interrupts
    sti

    ; Main system loop
    jmp main_loop

system_init_failed:
    mov si, init_error_msg
    call print_string
    jmp $

ui_init_failed:
    mov si, ui_error_msg
    call print_string
    jmp $

init_error_msg db 'System initialization failed', 13, 10, 0
ui_error_msg db 'UI initialization failed', 13, 10, 0

;------------------------------------------------------------------
; System initialization
;------------------------------------------------------------------
init_system:
    cli                    ; Disable interrupts during init

    ; Set up segments properly
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE        ; Set up stack

    ; Verify system requirements
    call verify_system

    ; Set video mode (80x25 color)
    mov ax, 0x0003
    int 0x10

    ; Initialize system vectors
    call setup_interrupt_vectors

    ; Initialize critical systems in order
    call init_memory
    call init_settings
    call init_taskbar

    ; Add settings to system menu
    mov si, settings_entry
    call add_menu_item
    jc .init_failed

    call init_task
    jc .init_failed

    call init_network
    ; Network failure is non-critical

    call setup_interrupt_handlers

    sti                    ; Re-enable interrupts
    ret

.init_failed:
    mov si, init_error_msg
    call print_string
    jmp $

init_error_msg db 'System initialization failed', 0

    ; Initialize enhanced core systems
    call init_memory       ; Initialize memory management
    call window_init      ; Initialize window system
    call keyboard_init    ; Initialize keyboard handler
    call mouse_init       ; Initialize mouse support
    call init_network     ; Initialize network stack
    call browser_init     ; Initialize web browser
    call sysmon_init      ; Initialize system monitor

    ; Show welcome screen
    call show_welcome_screen

    ; Start system monitor in background
    call start_background_monitor

    ; Show system info
    call show_system_info

show_system_info:
    push ax
    push si

    mov si, sys_info_msg
    call print_string

    ; Show memory info
    mov ax, [mem_blocks]
    call print_number

    mov si, memory_msg
    call print_string

    pop si
    pop ax
    ret

section .data
sys_info_msg db "NoX-OS v2.0", 13, 10
            db "Memory blocks: ", 0
memory_msg  db " blocks allocated", 13, 10, 0

    ret

;------------------------------------------------------------------
; UI initialization
;------------------------------------------------------------------
init_ui:
    ; Draw status bar
    call draw_status_bar

    ; Draw desktop
    call draw_desktop

    ; Show initial window
    call create_main_window

    ret

;------------------------------------------------------------------
; Main program loop
;------------------------------------------------------------------
main_loop:
    ; Check for keyboard input
    call check_keyboard

    ; Update clock in status bar
    call update_clock

    ; Handle window updates
    call update_windows

    ; Continue loop
    jmp main_loop

%include "src/kernel/browser.asm"
%include "src/kernel/command.asm"
%include "src/kernel/controls.asm"
%include "src/kernel/cursor.asm"
%include "src/kernel/disk.asm"
%include "src/kernel/display.asm"
%include "src/kernel/editor.asm"
%include "src/kernel/fat.asm"
%include "src/kernel/io.asm"
%include "src/kernel/kernel.asm"
%include "src/kernel/keyboard.asm"
%include "src/kernel/memory.asm"
%include "src/kernel/mouse.asm"
%include "src/kernel/network.asm"
%include "src/kernel/settings.asm"
%include "src/kernel/shell.asm"
%include "src/kernel/sysmon.asm"
%include "src/kernel/task.asm"
%include "src/kernel/taskbar.asm"
%include "src/kernel/ui.asm"
%include "src/kernel/window.asm"
