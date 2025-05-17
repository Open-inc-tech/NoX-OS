;==================================================================
; NoX-OS Advanced Memory Management
;==================================================================
; Implements a heap-based dynamic memory allocation system, going
; beyond standard MS-DOS capabilities with more efficient memory usage
; and fragmentation prevention

;------------------------------------------------------------------
; Memory Block Structure (8 bytes)
;------------------------------------------------------------------
; Offset 0: Size of block (2 bytes)
; Offset 2: Status byte (1 = allocated, 0 = free)
; Offset 3: Reserved (for alignment)
; Offset 4: 4 bytes for next block pointer (future expansion)

;------------------------------------------------------------------
; Global Variables
;------------------------------------------------------------------
mem_initialized db 0          ; 0 = not initialized, 1 = initialized
mem_heap_start dw 0           ; Start address of heap
mem_heap_end dw 0             ; End address of heap
mem_next_block dw 0           ; Next free block
mem_total_blocks dw 0         ; Count of allocated blocks
mem_total_free dw 0           ; Total free memory
mem_largest_free dw 0         ; Largest contiguous free block
mem_last_error db 0           ; Last error code

; Memory allocation error codes
%define MEM_ERR_NONE 0        ; No error
%define MEM_ERR_OUT_OF_MEM 1  ; Out of memory
%define MEM_ERR_INVALID_PTR 2 ; Invalid pointer
%define MEM_ERR_CORRUPTED 3   ; Heap corruption detected

;------------------------------------------------------------------
; Function: mem_init
; Initializes the dynamic memory system
;------------------------------------------------------------------
mem_init:
    push ax
    push bx
    push cx
    push es
    
    ; Check if already initialized
    cmp byte [mem_initialized], 1
    je .done
    
    ; Set up ES to point to heap segment
    mov ax, HEAP_SEGMENT
    mov es, ax
    
    ; Initialize the first block (covers entire heap)
    mov word [es:0], HEAP_SIZE - MEMORY_BLOCK_HEADER_SIZE  ; Block size
    mov byte [es:2], 0        ; Status: free
    mov byte [es:3], 0        ; Reserved
    mov word [es:4], 0        ; Next ptr (unused for now)
    mov word [es:6], 0        ; Next ptr high word (unused)
    
    ; Set heap start and end
    mov word [mem_heap_start], 0
    mov word [mem_heap_end], HEAP_SIZE
    
    ; Set next free block
    mov word [mem_next_block], 0
    
    ; Initialize statistics
    mov word [mem_total_blocks], 1
    mov ax, HEAP_SIZE - MEMORY_BLOCK_HEADER_SIZE
    mov word [mem_total_free], ax
    mov word [mem_largest_free], ax
    
    ; Mark as initialized
    mov byte [mem_initialized], 1
    mov byte [mem_last_error], MEM_ERR_NONE
    
.done:
    pop es
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: mem_alloc
; Allocates a block of memory
; Input: BX = size in bytes
; Output: AX = pointer to allocated memory, 0 if failed
;         CF set on error
;------------------------------------------------------------------
mem_alloc:
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    ; Check if memory system is initialized
    cmp byte [mem_initialized], 1
    jne .init_memory
    jmp .continue_alloc
    
.init_memory:
    call mem_init
    
.continue_alloc:
    ; Make sure requested size is not zero
    test bx, bx
    jz .error_out_of_memory
    
    ; Round up the size to nearest word boundary
    add bx, 1
    and bx, 0xFFFE
    
    ; Set up ES to point to heap segment
    mov ax, HEAP_SEGMENT
    mov es, ax
    
    ; Start from the first block
    mov si, word [mem_next_block]
    
.find_block:
    ; Check if we're at the end of the heap
    cmp si, word [mem_heap_end]
    jae .error_out_of_memory
    
    ; Check if block is free
    cmp byte [es:si+2], 0
    jne .next_block
    
    ; Check if block is big enough
    mov ax, word [es:si]      ; Block size
    cmp ax, bx                ; Compare with requested size
    jb .next_block            ; Too small, try next block
    
    ; If block is significantly larger than needed, split it
    ; (Only if free remainder would be at least 16 bytes)
    sub ax, bx                ; AX = extra space
    cmp ax, 16 + MEMORY_BLOCK_HEADER_SIZE  ; Minimum useful size
    jb .use_whole_block       ; Not worth splitting
    
    ; Split the block
    push si                   ; Save current block pointer
    
    ; Calculate address of new block
    mov di, si
    add di, MEMORY_BLOCK_HEADER_SIZE
    add di, bx
    
    ; Set up header for new block
    sub ax, MEMORY_BLOCK_HEADER_SIZE  ; Adjust for header
    mov word [es:di], ax      ; Set size of new block
    mov byte [es:di+2], 0     ; Status: free
    mov byte [es:di+3], 0     ; Reserved
    mov word [es:di+4], 0     ; Next ptr (unused for now)
    mov word [es:di+6], 0     ; Reserved
    
    ; Update size of original block
    mov word [es:si], bx
    
    ; Increment total block count
    inc word [mem_total_blocks]
    
    pop si                    ; Restore current block pointer
    
.use_whole_block:
    ; Mark block as allocated
    mov byte [es:si+2], 1     ; Status: allocated
    
    ; Update memory statistics
    sub word [mem_total_free], bx
    call mem_update_largest_free
    
    ; Calculate pointer to return (skip header)
    mov ax, si
    add ax, MEMORY_BLOCK_HEADER_SIZE
    
    ; Clear memory
    push di
    mov di, ax
    push cx
    mov cx, bx
    shr cx, 1                 ; Convert bytes to words
    xor dx, dx
    rep stosw                 ; Clear memory
    pop cx
    pop di
    
    ; Success
    clc                       ; Clear carry flag
    jmp .done
    
.next_block:
    ; Move to next block
    mov cx, word [es:si]      ; Block size
    add cx, MEMORY_BLOCK_HEADER_SIZE
    add si, cx
    jmp .find_block
    
.error_out_of_memory:
    ; Out of memory
    mov byte [mem_last_error], MEM_ERR_OUT_OF_MEM
    xor ax, ax                ; Return NULL pointer
    stc                       ; Set carry flag (error)
    
.done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

;------------------------------------------------------------------
; Function: mem_free
; Frees a previously allocated block of memory
; Input: AX = pointer to allocated memory
; Output: CF set on error
;------------------------------------------------------------------
mem_free:
    push ax
    push bx
    push si
    push di
    push es
    
    ; Check if memory system is initialized
    cmp byte [mem_initialized], 1
    jne .error_not_initialized
    
    ; Convert pointer to block header
    sub ax, MEMORY_BLOCK_HEADER_SIZE
    mov si, ax
    
    ; Check if pointer is valid
    cmp si, word [mem_heap_start]
    jb .error_invalid_pointer
    cmp si, word [mem_heap_end]
    jae .error_invalid_pointer
    
    ; Set up ES to point to heap segment
    mov ax, HEAP_SEGMENT
    mov es, ax
    
    ; Check if block is already free
    cmp byte [es:si+2], 0
    je .error_invalid_pointer  ; Double free
    
    ; Mark block as free
    mov byte [es:si+2], 0
    
    ; Update memory statistics
    mov ax, word [es:si]       ; Block size
    add word [mem_total_free], ax
    
    ; Update next free block pointer if this is earlier
    cmp si, word [mem_next_block]
    jae .no_update_next_free
    mov word [mem_next_block], si
    
.no_update_next_free:
    ; Try to coalesce with adjacent blocks (future enhancement)
    
    ; Update largest free block info
    call mem_update_largest_free
    
    ; Success
    mov byte [mem_last_error], MEM_ERR_NONE
    clc                        ; Clear carry flag
    jmp .done
    
.error_not_initialized:
    mov byte [mem_last_error], MEM_ERR_CORRUPTED
    stc                        ; Set carry flag (error)
    jmp .done
    
.error_invalid_pointer:
    mov byte [mem_last_error], MEM_ERR_INVALID_PTR
    stc                        ; Set carry flag (error)
    
.done:
    pop es
    pop di
    pop si
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: mem_realloc
; Reallocates a memory block to a new size
; Input: AX = pointer to allocated memory, BX = new size
; Output: AX = pointer to new block, 0 if failed
;         CF set on error
;------------------------------------------------------------------
mem_realloc:
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    ; Check if memory system is initialized
    cmp byte [mem_initialized], 1
    jne .error_not_initialized
    
    ; Special case: if pointer is NULL, just allocate
    test ax, ax
    jz .just_alloc
    
    ; Special case: if new size is 0, free the block and return NULL
    test bx, bx
    jz .just_free
    
    ; Convert pointer to block header
    mov si, ax
    sub si, MEMORY_BLOCK_HEADER_SIZE
    
    ; Set up ES to point to heap segment
    mov cx, HEAP_SEGMENT
    mov es, cx
    
    ; Check if block is allocated
    cmp byte [es:si+2], 1
    jne .error_invalid_pointer
    
    ; Get current block size
    mov cx, word [es:si]
    
    ; If new size is smaller, we can just update the size
    cmp bx, cx
    jbe .shrink_block
    
    ; Need to allocate new block
    push ax                    ; Save original pointer
    push cx                    ; Save original size
    
    call mem_alloc             ; BX already has the size
    
    pop cx                     ; Restore original size
    pop dx                     ; Original pointer in DX
    
    test ax, ax                ; Check if allocation succeeded
    jz .error_out_of_memory
    
    ; Copy data from old block to new
    push ax                    ; Save new pointer
    push di
    
    mov di, ax                 ; Destination
    mov si, dx                 ; Source
    
    ; Set up counter for REP MOVSB
    push cx
    rep movsb                  ; Copy data
    pop cx
    
    pop di                    ; Restore registers
    pop ax                    ; Restore new pointer
    
    ; Free the old block
    push ax                   ; Save new pointer
    mov ax, dx                ; Put old pointer in AX
    call mem_free
    pop ax                    ; Restore new pointer
    
    jmp .done                 ; Return the new pointer
    
.shrink_block:
    ; For now, just return the same block
    ; In a more advanced implementation, we could split the block
    jmp .done
    
.just_alloc:
    call mem_alloc
    jmp .done
    
.just_free:
    call mem_free
    xor ax, ax                ; Return NULL
    jmp .done
    
.error_not_initialized:
    mov byte [mem_last_error], MEM_ERR_CORRUPTED
    stc                        ; Set carry flag (error)
    xor ax, ax                ; Return NULL
    jmp .done
    
.error_invalid_pointer:
    mov byte [mem_last_error], MEM_ERR_INVALID_PTR
    stc                        ; Set carry flag (error)
    xor ax, ax                ; Return NULL
    jmp .done
    
.error_out_of_memory:
    mov byte [mem_last_error], MEM_ERR_OUT_OF_MEM
    stc                        ; Set carry flag (error)
    xor ax, ax                ; Return NULL
    
.done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

;------------------------------------------------------------------
; Function: mem_update_largest_free
; Updates memory statistics for largest free block
;------------------------------------------------------------------
mem_update_largest_free:
    push ax
    push cx
    push si
    push es
    
    ; Set up ES to point to heap segment
    mov ax, HEAP_SEGMENT
    mov es, ax
    
    ; Reset largest free block
    mov word [mem_largest_free], 0
    
    ; Start from the first block
    mov si, word [mem_heap_start]
    
.scan_loop:
    ; Check if we're at the end of the heap
    cmp si, word [mem_heap_end]
    jae .done
    
    ; Check if block is free
    cmp byte [es:si+2], 0
    jne .next_block
    
    ; Check if this is the largest free block
    mov ax, word [es:si]        ; Block size
    cmp ax, word [mem_largest_free]
    jbe .next_block
    
    ; Update largest free block
    mov word [mem_largest_free], ax
    
.next_block:
    ; Move to next block
    mov cx, word [es:si]       ; Block size
    add cx, MEMORY_BLOCK_HEADER_SIZE
    add si, cx
    jmp .scan_loop
    
.done:
    pop es
    pop si
    pop cx
    pop ax
    ret

;------------------------------------------------------------------
; Function: mem_get_stats
; Retrieves memory statistics
; Output: AX = total memory
;         BX = free memory
;         CX = used memory
;         DX = largest free block
;------------------------------------------------------------------
mem_get_stats:
    ; Check if memory system is initialized
    cmp byte [mem_initialized], 1
    jne .not_initialized
    
    ; Calculate total memory (heap size - header of first block)
    mov ax, HEAP_SIZE
    sub ax, MEMORY_BLOCK_HEADER_SIZE
    
    ; Get free memory
    mov bx, word [mem_total_free]
    
    ; Calculate used memory (total - free)
    mov cx, ax
    sub cx, bx
    
    ; Get largest free block
    mov dx, word [mem_largest_free]
    
    jmp .done
    
.not_initialized:
    ; Return zeros for everything
    xor ax, ax
    xor bx, bx
    xor cx, cx
    xor dx, dx
    
.done:
    ret

;------------------------------------------------------------------
; Function: mem_get_last_error
; Returns the last memory operation error
; Output: AL = error code
;------------------------------------------------------------------
mem_get_last_error:
    mov al, byte [mem_last_error]
    ret

;------------------------------------------------------------------
; Function: mem_compaction
; Performs memory compaction to reduce fragmentation
; Output: AX = number of blocks compacted
;------------------------------------------------------------------
mem_compaction:
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    ; Not implemented yet - would move blocks around to defragment
    ; This goes beyond MS-DOS capabilities
    
    ; For now, just return 0 blocks compacted
    xor ax, ax
    
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret