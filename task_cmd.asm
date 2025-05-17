;------------------------------------------------------------------
; Function: cmd_task
; Handles task-related commands
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_task:
    push si
    push di
    push ax
    push bx
    push cx
    push dx
    
    ; Skip "TASK" command
    call cmd_skip_token
    
    ; Skip whitespace
    call cmd_skip_whitespace
    
    ; Check if a subcommand was provided
    cmp byte [si], 0
    je .show_usage
    
    ; Check which subcommand
    mov di, si                  ; Save SI for subcommand comparison
    
    ; Check for LIST subcommand
    mov si, task_list_cmd
    call strcmp_nocase
    jc .list_tasks
    
    ; Check for CREATE subcommand
    mov si, task_create_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .create_task
    
    ; Check for KILL subcommand
    mov si, task_kill_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .kill_task
    
    ; Check for ENABLE subcommand
    mov si, task_enable_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .enable_multitasking
    
    ; Check for DISABLE subcommand
    mov si, task_disable_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .disable_multitasking
    
    ; Unknown subcommand
.show_usage:
    mov si, task_usage_msg
    call print_string
    jmp .done
    
.list_tasks:
    ; Display header
    mov si, task_list_header_msg
    call print_string
    
    ; Check if there are any tasks
    movzx ax, byte [task_count]
    test ax, ax
    jz .no_tasks
    
    ; Display task information
    mov si, task_table
    mov cx, MAX_TASKS
    
.list_loop:
    ; Check if task slot is active
    cmp byte [si + TASK.id], 0
    je .next_task
    
    ; Display task ID
    movzx ax, byte [si + TASK.id]
    call cmd_print_dec
    
    ; Add spacing
    mov al, ' '
    call print_char
    call print_char
    
    ; Display task state
    movzx ax, byte [si + TASK.state]
    cmp al, TASK_STATE_FREE
    je .state_free
    cmp al, TASK_STATE_READY
    je .state_ready
    cmp al, TASK_STATE_RUNNING
    je .state_running
    cmp al, TASK_STATE_WAITING
    je .state_waiting
    cmp al, TASK_STATE_SUSPENDED
    je .state_suspended
    
    ; Unknown state
    mov si, task_unknown_state_msg
    jmp .print_state
    
.state_free:
    mov si, task_free_state_msg
    jmp .print_state
    
.state_ready:
    mov si, task_ready_state_msg
    jmp .print_state
    
.state_running:
    mov si, task_running_state_msg
    jmp .print_state
    
.state_waiting:
    mov si, task_waiting_state_msg
    jmp .print_state
    
.state_suspended:
    mov si, task_suspended_state_msg
    
.print_state:
    call print_string
    
    ; Add spacing
    mov al, ' '
    call print_char
    call print_char
    
    ; Display task name
    push si
    add si, TASK.name
    call print_string
    pop si
    
    call print_newline
    
.next_task:
    add si, TASK_size
    loop .list_loop
    
    jmp .done
    
.no_tasks:
    mov si, task_no_tasks_msg
    call print_string
    jmp .done
    
.create_task:
    ; For now, just show a placeholder message
    ; In a real implementation, we would parse parameters and create a task
    mov si, task_placeholder_msg
    call print_string
    jmp .done
    
.kill_task:
    ; Move SI past the KILL token
    mov si, di
    call cmd_skip_token
    call cmd_skip_whitespace
    
    ; Parse task ID parameter
    cmp byte [si], 0
    je .show_usage
    call parse_number
    jc .show_usage
    
    ; Terminate task
    ; AL already contains task ID
    call task_terminate
    
    ; Display success message
    mov si, task_killed_msg
    call print_string
    
    jmp .done
    
.enable_multitasking:
    ; Enable multitasking
    call task_enable
    
    ; Display confirmation
    mov si, task_enabled_msg
    call print_string
    
    jmp .done
    
.disable_multitasking:
    ; Disable multitasking
    call task_disable
    
    ; Display confirmation
    mov si, task_disabled_msg
    call print_string
    
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    pop di
    pop si
    ret