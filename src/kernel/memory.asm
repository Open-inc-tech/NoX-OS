;==================================================================
; Enhanced Memory Management System
;==================================================================

section .data
; Memory pool configuration 
MEM_POOL_START    equ 0x10000    ; Start of memory pool
MEM_POOL_SIZE     equ 0xF0000    ; Pool size (960KB)
BLOCK_MIN_SIZE    equ 16         ; Minimum block size
BLOCK_ALIGN       equ 4          ; Block alignment (4 bytes)

; Memory block header structure (16 bytes)
struc MEM_BLOCK
    .size:        resd 1   ; Block size including header
    .flags:       resb 1   ; Status flags
    .checksum:    resb 1   ; Simple corruption detection
    .reserved:    resw 1   ; Reserved for future use
    .prev:        resd 1   ; Previous block pointer 
    .next:        resd 1   ; Next block pointer
endstruc

section .bss
mem_first_block:  resd 1   ; First block in chain
mem_last_block:   resd 1   ; Last block in chain
mem_free_blocks:  resd 1   ; Number of free blocks
mem_total_blocks: resd 1   ; Total number of blocks
mem_largest_free:  resd 1   ; Size of largest free block

section .text
; Initialize memory management
mem_init:
    push ebx
    push ecx

    ; Setup initial block covering entire pool
    mov eax, MEM_POOL_START
    mov [mem_first_block], eax
    mov [mem_last_block], eax

    ; Initialize block header
    mov dword [eax + MEM_BLOCK.size], MEM_POOL_SIZE
    mov byte [eax + MEM_BLOCK.flags], 0     ; Free
    mov dword [eax + MEM_BLOCK.prev], 0     ; No previous
    mov dword [eax + MEM_BLOCK.next], 0     ; No next

    ; Set initial stats
    mov dword [mem_free_blocks], 1
    mov dword [mem_total_blocks], 1
    mov dword [mem_largest_free], MEM_POOL_SIZE

    ; Calculate and set checksum
    call mem_calc_checksum
    mov [eax + MEM_BLOCK.checksum], bl

    pop ecx
    pop ebx
    ret

; Allocate memory block
; Input: EAX = requested size
; Output: EAX = block pointer or 0 if failed
mem_alloc:
    push ebx
    push ecx
    push edx

    ; Align size and add header
    add eax, MEM_BLOCK.size
    add eax, BLOCK_ALIGN - 1
    and eax, ~(BLOCK_ALIGN - 1)

    ; Find suitable free block
    mov ebx, [mem_first_block]

.find_block:
    test ebx, ebx           ; End of chain?
    jz .alloc_failed

    ; Enhanced block verification
    call mem_verify_block
    jc .alloc_failed
    
    ; Additional integrity checks
    cmp dword [ebx + MEM_BLOCK.size], 0
    jz .alloc_failed
    cmp dword [ebx + MEM_BLOCK.size], MEM_POOL_SIZE
    ja .alloc_failed

    ; Check if block is free and large enough
    test byte [ebx + MEM_BLOCK.flags], 1
    jnz .next_block

    cmp [ebx + MEM_BLOCK.size], eax
    jb .next_block

    ; Found suitable block
    mov ecx, [ebx + MEM_BLOCK.size]
    sub ecx, eax            ; Calculate remaining size

    cmp ecx, BLOCK_MIN_SIZE
    jb .use_whole_block

    ; Split block
    push ebx
    add ebx, eax           ; Point to new block
    mov [ebx + MEM_BLOCK.size], ecx
    mov byte [ebx + MEM_BLOCK.flags], 0
    mov edx, [esp]         ; Original block
    mov [ebx + MEM_BLOCK.prev], edx
    mov edx, [edx + MEM_BLOCK.next]
    mov [ebx + MEM_BLOCK.next], edx

    pop edx                ; Original block
    mov [edx + MEM_BLOCK.size], eax
    mov [edx + MEM_BLOCK.next], ebx

    inc dword [mem_total_blocks]

.use_whole_block:
    ; Mark block as used
    or byte [ebx + MEM_BLOCK.flags], 1
    dec dword [mem_free_blocks]

    ; Update largest free block if needed
    call mem_update_largest

    ; Return pointer to usable memory
    lea eax, [ebx + MEM_BLOCK.size]
    jmp .done

.next_block:
    mov ebx, [ebx + MEM_BLOCK.next]
    jmp .find_block

.alloc_failed:
    xor eax, eax

.done:
    pop edx
    pop ecx 
    pop ebx
    ret

; Free memory block
; Input: EAX = pointer to memory block
mem_free:
    push ebx
    push ecx

    ; Convert user pointer to block header
    sub eax, MEM_BLOCK.size
    mov ebx, eax

    ; Verify block
    call mem_verify_block
    jc .invalid_block

    ; Check if already free
    test byte [ebx + MEM_BLOCK.flags], 1
    jz .invalid_block

    ; Mark as free
    and byte [ebx + MEM_BLOCK.flags], ~1
    inc dword [mem_free_blocks]

    ; Try to merge with adjacent blocks
    call mem_merge_blocks

    ; Update largest free block
    call mem_update_largest

.invalid_block:
    pop ecx
    pop ebx
    ret

; Calculate block checksum
; Input: EAX = block pointer
; Output: BL = checksum
mem_calc_checksum:
    push ecx
    push edx

    xor bl, bl
    mov ecx, MEM_BLOCK.size / 4

.checksum_loop:
    xor bl, byte [eax]
    xor bl, byte [eax + 1]
    xor bl, byte [eax + 2]
    xor bl, byte [eax + 3]
    add eax, 4
    loop .checksum_loop

    pop edx
    pop ecx
    ret

; Verify block integrity
; Input: EBX = block pointer
; Output: CF set if invalid
mem_verify_block:
    push eax

    mov eax, ebx
    call mem_calc_checksum
    cmp bl, [ebx + MEM_BLOCK.checksum]

    pop eax
    ret

; Update largest free block size
mem_update_largest:
    push eax
    push ebx
    push ecx

    xor ecx, ecx           ; Track largest size
    mov ebx, [mem_first_block]

.scan_loop:
    test ebx, ebx
    jz .done

    test byte [ebx + MEM_BLOCK.flags], 1
    jnz .next_block

    mov eax, [ebx + MEM_BLOCK.size]
    cmp eax, ecx
    jbe .next_block
    mov ecx, eax

.next_block:
    mov ebx, [ebx + MEM_BLOCK.next]
    jmp .scan_loop

.done:
    mov [mem_largest_free], ecx

    pop ecx
    pop ebx
    pop eax
    ret

; Merge adjacent free blocks
; Input: EBX = block to merge
mem_merge_blocks:
    push eax
    push ecx
    push edx

    ; Try merge with next block
    mov edx, [ebx + MEM_BLOCK.next]
    test edx, edx
    jz .try_prev

    test byte [edx + MEM_BLOCK.flags], 1
    jnz .try_prev

    ; Merge with next
    mov eax, [edx + MEM_BLOCK.size]
    add [ebx + MEM_BLOCK.size], eax
    mov eax, [edx + MEM_BLOCK.next]
    mov [ebx + MEM_BLOCK.next], eax
    dec dword [mem_total_blocks]

.try_prev:
    ; Try merge with previous block
    mov edx, [ebx + MEM_BLOCK.prev]
    test edx, edx
    jz .done

    test byte [edx + MEM_BLOCK.flags], 1
    jnz .done

    ; Merge with previous
    mov eax, [ebx + MEM_BLOCK.size]
    add [edx + MEM_BLOCK.size], eax
    mov eax, [ebx + MEM_BLOCK.next]
    mov [edx + MEM_BLOCK.next], eax
    dec dword [mem_total_blocks]

.done:
    pop edx
    pop ecx
    pop eax
    ret