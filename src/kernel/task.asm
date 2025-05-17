;==================================================================
; NoX-OS Multitasking System
;==================================================================
; Implements cooperative multitasking - a feature not present in MS-DOS
; Allows multiple applications to run concurrently

;------------------------------------------------------------------
; Constants and Variables
;------------------------------------------------------------------
%define MAX_TASKS 8              ; Maximum number of concurrent tasks
%define TASK_STATE_FREE 0        ; Task slot is available
%define TASK_STATE_READY 1       ; Task is ready to run
%define TASK_STATE_RUNNING 2     ; Task is currently running
%define TASK_STATE_WAITING 3     ; Task is waiting for an event
%define TASK_STATE_SUSPENDED 4   ; Task is suspended
%define TASK_NAME_LENGTH 16      ; Maximum length of task name

; Task structure (64 bytes per task)
struc TASK
    .id         resb 1    ; Task ID (0 = free slot)
    .state      resb 1    ; Task state
    .name       resb TASK_NAME_LENGTH ; Task name
    .cs         resw 1    ; Code segment
    .ip         resw 1    ; Instruction pointer
    .ss         resw 1    ; Stack segment
    .sp         resw 1    ; Stack pointer
    .ax         resw 1    ; Register values
    .bx         resw 1
    .cx         resw 1
    .dx         resw 1
    .si         resw 1
    .di         resw 1
    .bp         resw 1
    .ds         resw 1
    .es         resw 1
    .flags      resw 1
    .stack_seg  resw 1    ; Segment for task's stack
    .wait_time  resw 1    ; Time to wait (for sleep operations)
    .reserved   resb 10   ; Reserved for future use
endstruc

; Multitasking variables
task_count db 0                                ; Number of active tasks
current_task db 0                              ; Currently running task ID
task_table: times MAX_TASKS * TASK_size db 0   ; Task structures
task_switching_enabled db 0                    ; 1 = multitasking enabled, 0 = disabled
task_time_slice dw 2                           ; Timer ticks per task timeslice
task_timer_counter dw 0                        ; Counter for task switching

;------------------------------------------------------------------
; Function: task_init
; Initializes the multitasking system
;------------------------------------------------------------------
task_init:
    push ax
    push bx
    push cx
    push dx
    
    ; Clear the task table
    mov cx, MAX_TASKS * TASK_size
    mov bx, task_table
    
.clear_loop:
    mov byte [bx], 0
    inc bx
    loop .clear_loop
    
    ; Initialize multitasking variables
    mov byte [task_count], 0
    mov byte [current_task], 0
    mov byte [task_switching_enabled], 0
    mov word [task_time_slice], 2
    mov word [task_timer_counter], 0
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: task_create
; Creates a new task
; Input: SI = pointer to task name
;        BX = code entry point (offset)
;        DX = code segment
; Output: AL = task ID (0 = failure)
;------------------------------------------------------------------
task_create:
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    ; Check if we've reached the maximum number of tasks
    mov cl, [task_count]
    cmp cl, MAX_TASKS
    jae .task_failure
    
    ; Find an available task slot
    mov di, task_table
    xor cx, cx                    ; CX will track task ID
    
.find_slot_loop:
    inc cx                        ; Task IDs start at 1
    cmp byte [di + TASK.id], 0    ; Check if slot is free
    je .found_slot
    add di, TASK_size             ; Move to next slot
    cmp cx, MAX_TASKS
    jb .find_slot_loop
    
    ; Shouldn't get here, but just in case
    jmp .task_failure
    
.found_slot:
    ; Initialize task structure
    mov byte [task_count], cl     ; Update task count
    mov [di + TASK.id], cl        ; Set task ID
    mov byte [di + TASK.state], TASK_STATE_READY  ; Set state to ready
    
    ; Initialize task registers
    mov [di + TASK.ip], bx         ; Entry point (offset)
    mov [di + TASK.cs], dx         ; Code segment
    
    ; Allocate a stack for the task (for now, just use a fixed address)
    ; In a real implementation, we would dynamically allocate memory
    mov ax, 0x6000                ; Stack segment (adjust as needed)
    add ax, cx                    ; Offset by task ID to avoid overlap
    shl ax, 1                     ; Multiply by 2 for more spacing
    mov [di + TASK.ss], ax        ; Stack segment
    mov word [di + TASK.sp], 0xFFFE  ; Initial stack pointer (top of segment)
    mov [di + TASK.stack_seg], ax  ; Remember stack segment for cleanup
    
    ; Initialize other registers with default values
    mov word [di + TASK.ax], 0
    mov word [di + TASK.bx], 0
    mov word [di + TASK.cx], 0
    mov word [di + TASK.dx], 0
    mov word [di + TASK.si], 0
    mov word [di + TASK.di], 0
    mov word [di + TASK.bp], 0
    mov word [di + TASK.ds], 0x1000  ; Same as kernel data segment
    mov word [di + TASK.es], 0x1000  ; Same as kernel data segment
    mov word [di + TASK.flags], 0x0200  ; Enable interrupts
    
    ; Copy task name (max TASK_NAME_LENGTH-1 chars + null)
    push di
    add di, TASK.name
    mov cx, TASK_NAME_LENGTH - 1  ; Maximum name length minus 1
    
.copy_name_loop:
    lodsb                         ; Load next character of name
    test al, al                   ; Check for null terminator
    jz .name_done
    stosb                         ; Store in task structure
    loop .copy_name_loop
    
    ; Ensure name is null-terminated
.name_done:
    mov byte [di], 0
    pop di
    
    ; Return the task ID
    mov al, cl
    jmp .done
    
.task_failure:
    xor al, al                   ; Return 0 (failure)
    
.done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

;------------------------------------------------------------------
; Function: task_terminate
; Terminates a task
; Input: AL = task ID (0 = current task)
;------------------------------------------------------------------
task_terminate:
    push bx
    push cx
    push si
    push di
    
    ; If task ID is 0, use current task
    test al, al
    jnz .find_task
    mov al, [current_task]
    
.find_task:
    ; Find the task
    call task_find
    test di, di
    jz .done
    
    ; Mark task as free
    mov byte [di + TASK.id], 0
    mov byte [di + TASK.state], TASK_STATE_FREE
    dec byte [task_count]
    
    ; If this was the current task, we need to switch to another
    cmp al, [current_task]
    jne .done
    
    ; Find another task to run
    call task_schedule
    
.done:
    pop di
    pop si
    pop cx
    pop bx
    ret

;------------------------------------------------------------------
; Function: task_find
; Finds a task by ID
; Input: AL = task ID
; Output: DI = pointer to task structure (0 if not found)
;------------------------------------------------------------------
task_find:
    push ax
    push bx
    push cx
    
    ; Check if the ID is valid
    test al, al
    jz .not_found                  ; IDs start at 1
    
    ; Calculate offset into task table
    dec al                         ; Convert to 0-based index
    movzx bx, al
    mov ax, TASK_size
    mul bx
    mov di, task_table
    add di, ax
    
    ; Validate that the slot has a matching ID
    mov bl, [di + TASK.id]
    cmp bl, al
    jne .not_found
    
    jmp .done
    
.not_found:
    xor di, di                     ; Return 0 (not found)
    
.done:
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: task_switch
; Switches to the next ready task
;------------------------------------------------------------------
task_switch:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Check if multitasking is enabled
    cmp byte [task_switching_enabled], 0
    je .done
    
    ; Check if any tasks exist
    cmp byte [task_count], 0
    je .done
    
    ; Find the next runnable task
    call task_schedule
    
.done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: task_schedule
; Finds the next task to run
;------------------------------------------------------------------
task_schedule:
    push ax
    push bx
    push cx
    push si
    push di
    
    ; Check if any tasks exist
    cmp byte [task_count], 0
    je .done
    
    ; Start from the current task + 1
    mov al, [current_task]
    inc al
    cmp al, MAX_TASKS
    jbe .check_task
    mov al, 1                    ; Wrap around to first task
    
.check_task:
    ; Find this task
    call task_find
    test di, di                  ; Check if task exists
    jz .next_task
    
    ; Check if task is ready
    cmp byte [di + TASK.state], TASK_STATE_READY
    je .found_task
    
.next_task:
    ; Try the next task
    inc al
    cmp al, MAX_TASKS
    jbe .check_task
    mov al, 1                    ; Wrap around to first task
    
    ; We've checked all tasks - if we get here, try one more full cycle
    mov cx, MAX_TASKS
    
.retry_loop:
    call task_find
    test di, di
    jz .next_retry
    
    ; Check if task exists and is in any runnable state
    cmp byte [di + TASK.state], TASK_STATE_FREE
    je .next_retry
    
    ; Set task to ready state and use it
    mov byte [di + TASK.state], TASK_STATE_READY
    jmp .found_task
    
.next_retry:
    inc al
    cmp al, MAX_TASKS
    jbe .continue_retry
    mov al, 1                    ; Wrap around
    
.continue_retry:
    loop .retry_loop
    
    ; If we reach here, no tasks are ready - just keep the current task
    mov al, [current_task]
    call task_find
    
.found_task:
    ; Update current task
    mov byte [current_task], al
    
    ; Set task state to running
    mov byte [di + TASK.state], TASK_STATE_RUNNING
    
.done:
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: task_enable
; Enables the multitasking system
;------------------------------------------------------------------
task_enable:
    mov byte [task_switching_enabled], 1
    ret

;------------------------------------------------------------------
; Function: task_disable
; Disables the multitasking system
;------------------------------------------------------------------
task_disable:
    mov byte [task_switching_enabled], 0
    ret

;------------------------------------------------------------------
; Function: task_yield
; Voluntarily gives up CPU time
;------------------------------------------------------------------
task_yield:
    call task_switch
    ret

;------------------------------------------------------------------
; Function: task_list
; Lists all active tasks
; Output: AX = number of active tasks
;------------------------------------------------------------------
task_list:
    push bx
    push cx
    push si
    push di
    
    ; Return the task count
    movzx ax, byte [task_count]
    
    pop di
    pop si
    pop cx
    pop bx
    ret

;------------------------------------------------------------------
; Function: task_set_state
; Sets a task's state
; Input: AL = task ID, BL = new state
;------------------------------------------------------------------
task_set_state:
    push di
    
    ; Find the task
    call task_find
    test di, di
    jz .done
    
    ; Update the task state
    mov [di + TASK.state], bl
    
.done:
    pop di
    ret