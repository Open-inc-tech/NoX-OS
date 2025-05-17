;==================================================================
; NoX-OS I/O Routines
;==================================================================
; Basic input/output routines for the kernel
; Provides console I/O via BIOS interrupts

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
; Function: print_char
; Prints a single character
; Input: AL = character to print
;------------------------------------------------------------------
print_char:
    push ax
    push bx
    
    mov ah, 0x0E            ; BIOS teletype function
    mov bh, 0               ; Page number
    mov bl, 0x07            ; Text attribute (white on black)
    int 0x10                ; Print the character
    
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: print_newline
; Prints a carriage return and line feed
;------------------------------------------------------------------
print_newline:
    push ax
    
    mov al, 0x0D            ; Carriage return
    call print_char
    mov al, 0x0A            ; Line feed
    call print_char
    
    pop ax
    ret

;------------------------------------------------------------------
; Function: print_hex
; Prints a 16-bit value in hexadecimal
; Input: AX = value to print
;------------------------------------------------------------------
print_hex:
    push ax
    push bx
    push cx
    push dx
    
    mov cx, 4               ; 4 hex digits in 16-bit number
    mov bx, ax              ; Save value in BX
    
    ; Start with "0x" prefix
    mov al, '0'
    call print_char
    mov al, 'x'
    call print_char
    
.loop:
    ; Get the top 4 bits
    rol bx, 4               ; Rotate so high 4 bits are now low 4 bits
    mov al, bl              ; Copy them to AL
    and al, 0x0F            ; Mask out high bits
    
    ; Convert to ASCII
    cmp al, 10              ; Check if it's A-F or 0-9
    jl .decimal             ; If less than 10, skip to decimal handling
    
    add al, 'A' - 10        ; Convert to A-F
    jmp .print
    
.decimal:
    add al, '0'             ; Convert to 0-9
    
.print:
    call print_char         ; Print the ASCII character
    
    dec cx                  ; Decrement counter
    jnz .loop               ; If not zero, continue
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: read_key
; Waits for a keypress and returns it
; Output: AL = ASCII character, AH = scan code
;------------------------------------------------------------------
read_key:
    mov ah, 0x00            ; BIOS read key function
    int 0x16                ; Call BIOS keyboard service
    ret

;------------------------------------------------------------------
; Function: read_line
; Reads a line of text from the keyboard
; Input: DI = pointer to buffer to store input
; Modifies: Buffer pointed to by DI
;------------------------------------------------------------------
read_line:
    push ax
    push bx
    push dx
    
    mov bx, di              ; Save buffer start in BX
    
.loop:
    ; Read a key
    call read_key
    
    ; Check for Enter key (CR)
    cmp al, 0x0D
    je .done
    
    ; Check for backspace
    cmp al, 0x08
    je .backspace
    
    ; Check if the character is printable
    cmp al, 0x20
    jb .loop
    
    ; Store the character and echo it
    stosb                   ; Store AL at [DI] and increment DI
    call print_char         ; Echo the character
    jmp .loop
    
.backspace:
    ; Only handle backspace if we're not at the start of the line
    cmp di, bx
    je .loop
    
    ; Remove one character from buffer
    dec di
    
    ; Move cursor back, print a space, move cursor back again
    mov al, 0x08
    call print_char
    mov al, ' '
    call print_char
    mov al, 0x08
    call print_char
    
    jmp .loop
    
.done:
    ; Add null terminator to buffer
    mov byte [di], 0
    
    ; Print newline
    call print_newline
    
    pop dx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: clear_screen
; Clears the screen and resets cursor position
;------------------------------------------------------------------
clear_screen:
    push ax
    push bx
    push cx
    push dx
    
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
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: get_cursor_pos
; Gets the cursor position
; Output: DH = row, DL = column
;------------------------------------------------------------------
get_cursor_pos:
    push ax
    push bx
    
    mov ah, 0x03            ; Get cursor position function
    mov bh, 0               ; Page number
    int 0x10                ; Call BIOS video service
    
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: set_cursor_pos
; Sets the cursor position
; Input: DH = row, DL = column
;------------------------------------------------------------------
set_cursor_pos:
    push ax
    push bx
    
    mov ah, 0x02            ; Set cursor position function
    mov bh, 0               ; Page number
    int 0x10                ; Call BIOS video service
    
    pop bx
    pop ax
    ret
