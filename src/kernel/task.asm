
;==================================================================
; Enhanced Task Management System
;==================================================================

section .data
; Task states
TASK_STATE_FREE     equ 0
TASK_STATE_READY    equ 1
TASK_STATE_RUNNING  equ 2
TASK_STATE_WAITING  equ 3
TASK_STATE_BLOCKED  equ 4

; Task priorities
TASK_PRIO_LOW      equ 0
TASK_PRIO_NORMAL   equ 1
TASK_PRIO_HIGH     equ 2

; Task structure (80 bytes)
struc TASK
    .id         resb 1    ; Task ID
    .state      resb 1    ; Current state
    .priority   resb 1    ; Task priority
    .ticks      resb 1    ; Ticks remaining
    .name       resb 32   ; Task name
    .sp         resd 1    ; Stack pointer
    .bp         resd 1    ; Base pointer
    .cs         resw 1    ; Code segment
    .ds         resw 1    ; Data segment
    .ss         resw 1    ; Stack segment
    .ip         resd 1    ; Instruction pointer
    .flags      resw 1    ; CPU flags
    .regs       resb 32   ; General registers
endstruc

section .bss
task_table:      resb TASK_size * 64  ; Support up to 64 tasks
task_count:      resb 1
current_task:    resb 1
scheduler_lock:  resb 1
task_quantum:    resb 1

section .text
; Initialize task system
task_init:
    push eax
    push ecx
    push edi

    ; Clear task table
    mov edi, task_table
    mov ecx, TASK_size * 64
    xor eax, eax
    rep stosb

    ; Initialize variables
    mov byte [task_count], 0
    mov byte [current_task], 0
    mov byte [scheduler_lock], 0
    mov byte [task_quantum], 5    ; Default time slice

    pop edi
    pop ecx
    pop eax
    ret

; Create new task
; Input: ESI = task name, EAX = entry point
; Output: AL = task ID (0 = failed)
task_create:
    push ebx
    push ecx
    push edx
    push edi

    ; Check max tasks
    mov cl, [task_count]
    cmp cl, 64
    jae .create_failed

    ; Find free slot
    xor edx, edx            ; Task ID counter
    mov edi, task_table

.find_slot:
    cmp byte [edi + TASK.id], 0
    je .slot_found
    add edi, TASK_size
    inc edx
    cmp edx, 64
    jb .find_slot
    jmp .create_failed

.slot_found:
    ; Initialize task structure
    push edi

    ; Set task ID
    inc edx
    mov [edi + TASK.id], dl

    ; Copy task name
    push esi
    lea edi, [edi + TASK.name]
    mov ecx, 31

.copy_name:
    lodsb
    test al, al
    jz .name_done
    stosb
    loop .copy_name

.name_done:
    xor al, al
    stosb
    pop esi
    pop edi

    ; Set initial state
    mov byte [edi + TASK.state], TASK_STATE_READY
    mov byte [edi + TASK.priority], TASK_PRIO_NORMAL
    mov byte [edi + TASK.ticks], 0

    ; Setup task segments
    mov word [edi + TASK.cs], cs
    mov word [edi + TASK.ds], ds

    ; Allocate stack (64KB)
    push eax
    mov eax, 65536
    call mem_alloc
    test eax, eax
    jz .alloc_failed

    ; Setup stack
    add eax, 65532           ; Point to top
    mov [edi + TASK.sp], eax
    mov [edi + TASK.bp], eax
    mov word [edi + TASK.ss], ds

    pop eax

    ; Set entry point
    mov [edi + TASK.ip], eax

    ; Set initial flags (interrupts enabled)
    mov word [edi + TASK.flags], 0x200

    ; Clear registers
    lea edi, [edi + TASK.regs]
    push ecx
    mov ecx, 8              ; 8 dwords
    xor eax, eax
    rep stosd
    pop ecx

    ; Update task count
    inc byte [task_count]

    ; Return task ID
    mov al, dl
    jmp .create_done

.alloc_failed:
    pop eax

.create_failed:
    xor al, al              ; Return 0 = failed

.create_done:
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret

; Schedule next task
task_schedule:
    push ebx
    push ecx
    push edx

    ; Check if scheduling is locked
    test byte [scheduler_lock], 1
    jnz .no_switch

    ; Save current task state with enhanced preservation
    movzx ebx, byte [current_task]
    test bl, bl
    jz .find_next
    
    ; Save additional CPU state
    pushfd
    push ds
    push es
    push fs
    push gs

    dec ebx
    imul ebx, TASK_size
    add ebx, task_table

    ; Save registers
    mov [ebx + TASK.sp], esp
    mov [ebx + TASK.bp], ebp
    pushf
    pop dx
    mov [ebx + TASK.flags], dx

    ; Save general registers
    lea edi, [ebx + TASK.regs]
    mov [edi], eax
    mov [edi+4], ecx
    mov [edi+8], edx
    mov [edi+12], ebx
    mov [edi+16], esi
    mov [edi+20], edi

.find_next:
    ; Find next ready task
    movzx ecx, byte [current_task]
    mov dl, cl              ; Save start position

.scan_loop:
    inc cl
    cmp cl, 64
    jbe .check_task
    mov cl, 1              ; Wrap around

.check_task:
    cmp cl, dl
    je .no_switch          ; Back to start, no other tasks

    ; Get task entry
    dec ecx
    push ecx
    imul ecx, TASK_size
    add ecx, task_table

    ; Check if task is ready
    cmp byte [ecx + TASK.state], TASK_STATE_READY
    jne .next_task

    ; Found a task to run
    mov [current_task], cl

    ; Restore task state
    mov esp, [ecx + TASK.sp]
    mov ebp, [ecx + TASK.bp]

    ; Restore general registers
    lea esi, [ecx + TASK.regs]
    mov eax, [esi]
    mov ecx, [esi+4]
    mov edx, [esi+8]
    mov ebx, [esi+12]
    mov edi, [esi+20]
    mov esi, [esi+16]

    ; Switch to task
    push word [ecx + TASK.flags]
    popf
    jmp far [ecx + TASK.ip]

.next_task:
    pop ecx
    jmp .scan_loop

.no_switch:
    pop edx
    pop ecx
    pop ebx
    ret
