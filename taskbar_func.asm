;------------------------------------------------------------------
; Function: cmd_taskbar
; Controls the visibility of the taskbar
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_taskbar:
    push si
    push di
    push ax
    push bx
    
    ; Skip "TASKBAR" command
    call cmd_skip_token
    
    ; Skip whitespace
    call cmd_skip_whitespace
    
    ; Check if a parameter was provided
    cmp byte [si], 0
    je .show_status
    
    ; Check for ON/OFF parameter
    mov di, si
    
    ; Check for "ON" parameter
    mov si, on_cmd
    call strcmp_nocase
    jc .enable_taskbar
    
    ; Check for "OFF" parameter
    mov si, di                ; Restore position
    mov si, off_cmd
    call strcmp_nocase
    jc .disable_taskbar
    
    ; Invalid parameter
    mov si, taskbar_usage_msg
    call print_string
    jmp .done
    
.show_status:
    ; Display current taskbar status
    mov si, taskbar_status_msg
    call print_string
    
    ; Check current status
    mov al, [taskbar_enabled]
    test al, al
    jz .show_disabled
    
    ; Taskbar is enabled
    mov si, taskbar_on_msg
    call print_string
    jmp .done
    
.show_disabled:
    ; Taskbar is disabled
    mov si, taskbar_off_msg
    call print_string
    jmp .done
    
.enable_taskbar:
    ; Enable the taskbar
    mov byte [taskbar_enabled], 1
    call taskbar_show
    
    ; Display confirmation
    mov si, taskbar_enabled_msg
    call print_string
    jmp .done
    
.disable_taskbar:
    ; Disable the taskbar
    mov byte [taskbar_enabled], 0
    call taskbar_hide
    
    ; Display confirmation
    mov si, taskbar_disabled_msg
    call print_string
    
.done:
    pop bx
    pop ax
    pop di
    pop si
    ret