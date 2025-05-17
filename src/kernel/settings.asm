;==================================================================
; NoX-OS Settings Application
;==================================================================

section .data
settings_title db "System Settings", 0
display_opt db "1. Display Settings", 0
sound_opt db "2. Sound Settings", 0
network_opt db "3. Network Settings", 0
exit_opt db "4. Exit", 0

display_settings db 'Display Settings', 0
system_settings db 'System Settings', 0
network_settings db 'Network Settings', 0
sound_settings db 'Sound Settings', 0

; System Settings
enable_multitask db 'Enable Multitasking (Y/N): ', 0
mouse_speed db 'Mouse Speed (1-5): ', 0
system_beep db 'System Beep (Y/N): ', 0
screen_saver db 'Screen Saver (mins, 0=off): ', 0

; Display Settings
text_color db 'Text Color (1-15): ', 0
background_color db 'Background Color (0-7): ', 0
window_style db 'Window Style (1-3): ', 0

; Current Settings Storage
current_settings:
    .multitask_enabled db 1
    .mouse_speed db 3
    .system_beep_enabled db 1
    .screen_saver_time db 5
    .text_color db 7
    .background_color db 0
    .window_style db 1

settings_window_id db 0

section .text
settings_app:
    ; Save registers
    push ax
    push bx
    push cx
    push dx

    ; Draw settings window
    mov ax, 20  ; x position
    mov bx, 5   ; y position
    mov cx, 40  ; width
    mov dx, 15  ; height
    call draw_window

    ; Display options
    mov si, settings_title
    call print_centered

    mov si, display_opt
    call print_option

    mov si, sound_opt
    call print_option

    mov si, network_opt
    call print_option

    mov si, exit_opt
    call print_option

    ; Handle input
.input_loop:
    call get_key
    cmp al, '1'
    je display_settings
    cmp al, '2'
    je sound_settings
    cmp al, '3'
    je network_settings
    cmp al, '4'
    je .exit
    jmp .input_loop

.exit:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Handle Setting Change
;------------------------------------------------------------------
handle_setting_change:
    ; Determine which setting to change based on AL
    cmp al, 1
    je .change_display
    cmp al, 2
    je .change_system
    cmp al, 3
    je .change_network
    ret
    
.change_display:
    ; Handle display settings
    call change_display_settings
    ret
    
.change_system:
    ; Handle system settings
    call change_system_settings
    ret
    
.change_network:
    ; Handle network settings
    call change_network_settings
    ret

;------------------------------------------------------------------
; Display Settings Change Handler
;------------------------------------------------------------------
change_display_settings:
    ; Prompt for text color
    mov si, text_color
    call window_print
    
    ; Get input and validate
    call get_number_input
    cmp al, 15
    ja .invalid
    
    ; Store new text color
    mov [current_settings.text_color], al
    call apply_display_settings
    
.invalid:
    ret

;------------------------------------------------------------------
; Apply Settings Changes
;------------------------------------------------------------------
apply_display_settings:
    ; Apply text color
    mov al, [current_settings.text_color]
    mov ah, [current_settings.background_color]
    shl ah, 4
    or al, ah
    mov [text_attribute], al
    ret