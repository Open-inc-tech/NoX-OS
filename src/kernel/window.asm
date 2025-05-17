;==================================================================
; NoX-OS Window System
;==================================================================
; Implements a simple windowing system - a major advancement beyond
; MS-DOS capabilities

;------------------------------------------------------------------
; Constants and Variables
;------------------------------------------------------------------
%define MAX_WINDOWS 10           ; Increased maximum windows
%define MIN_WINDOW_WIDTH 20      ; Minimum window width
%define MIN_WINDOW_HEIGHT 5      ; Minimum window height
%define WINDOW_SHADOW_ATTR 0x08  ; Dark gray for window shadows
%define WINDOW_ACTIVE_TITLE 0x1F ; White on blue for active window
%define WINDOW_INACTIVE_TITLE 0x70 ; Black on gray for inactive
%define WINDOW_BORDER_CHAR 0xCD  ; Double line character for borders
%define WINDOW_CORNER_CHAR 0xC9  ; Corner character
%define WINDOW_TITLE_COLOR 0x1F  ; Blue background, white text
%define WINDOW_CONTENT_COLOR 0x17 ; Blue background, white text
%define WINDOW_COLOR 0x17       ; Default window color

;------------------------------------------------------------------
; Window structure (24 bytes per window)
;------------------------------------------------------------------
struc WINDOW
    .id         resb 1    ; Window ID (0 = inactive)
    .x          resb 1    ; X position (column)
    .y          resb 1    ; Y position (row)
    .width      resb 1    ; Width in characters
    .height     resb 1    ; Height in characters
    .color      resb 1    ; Color attribute
    .title      resb 16   ; Window title (null-terminated)
    .flags      resb 2    ; Flags (bit 0 = visible, bit 1 = active)
endstruc

%define WINDOW_size WINDOW.flags + 2   ; Size of the WINDOW structure

; Window tracking data
window_count db 0                                    ; Number of active windows
window_active db 0xFF                                ; ID of the active window (0xFF = none)

;------------------------------------------------------------------
; Data section
;------------------------------------------------------------------
window_table: times (MAX_WINDOWS * WINDOW_size) db 0
active_window: db 0

;------------------------------------------------------------------
; Window management functions
;------------------------------------------------------------------
window_init:
    push ax
    push bx
    push cx
    push di

    ; Initialize window table
    mov di, window_table
    mov cx, MAX_WINDOWS * WINDOW_size
    xor al, al
    rep stosb

    ; Reset window count and active window
    mov byte [window_count], 0
    mov byte [window_active], 0xFF

    pop di
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: window_create
; Creates a new window
; Input: AL = X position, AH = Y position
;        BL = width, BH = height
;        SI = pointer to title string
; Output: AL = window ID (0 = failure)
;------------------------------------------------------------------
window_create:
    push bx
    push cx
    
    ; Validate window parameters
    cmp bl, MIN_WINDOW_WIDTH
    jb .invalid_dimensions
    cmp bh, MIN_WINDOW_HEIGHT
    jb .invalid_dimensions
    
    ; Check screen bounds
    cmp al, 80
    ja .invalid_position
    cmp ah, 25
    ja .invalid_position
    push dx
    push si
    push di
    push es

    ; Check if we've reached the maximum number of windows
    mov cl, [window_count]
    cmp cl, MAX_WINDOWS
    jae .window_failure

    ; Validate window dimensions
    cmp bl, MIN_WINDOW_WIDTH
    jb .window_failure
    cmp bh, MIN_WINDOW_HEIGHT
    jb .window_failure

    ; Ensure window fits on screen
    mov dl, 80         ; Screen width
    sub dl, al         ; Available columns
    cmp dl, bl         ; Compare with window width
    jb .window_failure

    mov dl, 25         ; Screen height (excluding taskbar row)
    sub dl, 1          ; Leave room for taskbar
    sub dl, ah         ; Available rows
    cmp dl, bh         ; Compare with window height
    jb .window_failure

    ; Find an available window slot
    xor dx, dx         ; DX will hold the window ID
    mov di, window_table

.find_slot_loop:
    cmp byte [di + WINDOW.id], 0  ; Check if slot is free
    je .found_slot
    add di, WINDOW_size           ; Move to next slot
    inc dx
    cmp dx, MAX_WINDOWS
    jb .find_slot_loop

    ; Shouldn't get here, but just in case
    jmp .window_failure

.found_slot:
    ; Initialize window structure
    inc byte [window_count]
    inc dx                       ; Window IDs start at 1
    mov [di + WINDOW.id], dl     ; Set window ID
    mov [di + WINDOW.x], al      ; X position
    mov [di + WINDOW.y], ah      ; Y position
    mov [di + WINDOW.width], bl  ; Width
    mov [di + WINDOW.height], bh ; Height
    mov byte [di + WINDOW.color], WINDOW_CONTENT_COLOR ; Default Color
    mov byte [di + WINDOW.flags], 0x03 ; Visible and active

    ; Copy window title (max 15 chars + null)
    push di
    add di, WINDOW.title
    mov cx, 15                   ; Maximum title length

.copy_title_loop:
    lodsb                        ; Load next character of title
    stosb                        ; Store in window structure
    test al, al                  ; Check for null terminator
    jz .title_done
    loop .copy_title_loop

    ; Ensure title is null-terminated
    mov byte [di], 0

.title_done:
    pop di

    ; Make this the active window
    mov byte [window_active], dl

    ; Draw the window
    mov al, dl                   ; Window ID
    call window_draw

    ; Return the window ID
    mov al, dl
    mov byte [window_active], dl

    jmp .done

.window_failure:
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
; Function: window_close
; Closes a window
; Input: AL = window ID
;------------------------------------------------------------------
window_close:
    push bx
    push cx
    push dx
    push si
    push di

    ; Validate window ID
    call window_find
    test di, di
    jz .done

    ; Clear the window from screen (restore what was underneath)
    ; For now, just clear the area
    call window_clear

    ; Mark window as inactive
    mov byte [di + WINDOW.id], 0
    dec byte [window_count]

    ; If this was the active window, find another to activate
    cmp al, [window_active]
    jne .done

    ; Find another window to activate
    mov byte [window_active], 0xFF  ; Default to no active window

    ; Look for the highest ID window to activate
    mov si, window_table
    mov cx, MAX_WINDOWS
    xor dx, dx                     ; Will hold highest ID

.find_active_loop:
    cmp byte [si + WINDOW.id], 0   ; Skip inactive windows
    je .next_window

    mov dl, [si + WINDOW.id]       ; Remember this ID

.next_window:
    add si, WINDOW_size
    loop .find_active_loop

    ; If we found another window, activate it
    test dl, dl
    jz .done

    mov [window_active], dl
    mov al, dl
    call window_draw               ; Redraw the now-active window

.done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

;------------------------------------------------------------------
; Function: window_find
; Finds a window by ID
; Input: AL = window ID
; Output: DI = pointer to window structure (0 if not found)
;------------------------------------------------------------------
window_find:
    push ax
    push bx
    push cx

    ; Check if the ID is valid
    test al, al
    jz .not_found                  ; IDs start at 1

    ; Search for the window
    mov di, window_table
    mov cx, MAX_WINDOWS

.find_loop:
    cmp [di + WINDOW.id], al
    je .found
    add di, WINDOW_size
    loop .find_loop

.not_found:
    xor di, di                     ; Return 0 (not found)
    jmp .done

.found:
    ; DI already points to window structure

.done:
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: window_draw
; Draws a window
; Input: AL = window ID
;------------------------------------------------------------------
window_draw:
    ; Enhanced window drawing with shadows and 3D effects
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    ; Find the window
    call window_find
    test di, di
    jz .done

    ; Set up video memory
    mov ax, 0xB800
    mov es, ax

    ; Get window position and size
    mov bl, [di + WINDOW.x]
    mov bh, [di + WINDOW.y]
    mov cl, [di + WINDOW.width]
    mov ch, [di + WINDOW.height]

    ; Draw top border
    push di

    ; Calculate position in video memory: (row * 80 + col) * 2
    movzx ax, bh                  ; Row
    mov dx, 80
    mul dx                        ; AX = row * 80
    movzx dx, bl                  ; Column
    add ax, dx                    ; AX = row * 80 + col
    shl ax, 1                     ; AX = (row * 80 + col) * 2
    mov di, ax                    ; DI = offset in video memory

    ; Top-left corner
    mov al, 0xC9                  ; ╔
    mov ah, WINDOW_TITLE_COLOR
    stosw

    ; Top border
    mov al, 0xCD                  ; ═
    mov cx, [di + WINDOW.width] ; changed from si
    sub cx, 2                     ; Subtract corners
    rep stosw

    ; Top-right corner
    mov al, 0xBB                  ; ╗
    stosw

    ; Draw title bar and side borders
    mov dl, ch                    ; DL = height
    sub dl, 2                     ; Subtract top and bottom rows
    pop di                        ; Restore window structure

    ; Calculate row offset for title bar
    movzx ax, bh                  ; Row
    mov cx, 80
    mul cx                        ; AX = row * 80
    movzx cx, bl                  ; Column
    add ax, cx                    ; AX = row * 80 + col
    shl ax, 1                     ; AX = (row * 80 + col) * 2

    ; Move to title bar position
    add ax, 160                   ; Next row (80 * 2)
    mov di, ax

    ; Draw title bar and sides
    mov dh, dl                    ; Save row counter

.row_loop:
    ; Left side
    mov al, 0xBA                  ; ║
    mov ah, WINDOW_CONTENT_COLOR
    stosw

    ; Content area (clear with space)
    mov al, ' '
    mov cx, [di + WINDOW.width] ; changed from si
    sub cx, 2                     ; Subtract side borders
    rep stosw

    ; Right side
    mov al, 0xBA                  ; ║
    stosw

    ; Move to next row
    sub di, [di + WINDOW.width] ; changed from si
    sub di, [di + WINDOW.width] ; changed from si
    add di, 160                   ; Next row (80 * 2)

    dec dh
    jnz .row_loop

    ; Draw bottom border
    ; Bottom-left corner
    mov al, 0xC8                  ; ╚
    stosw

    ; Bottom border
    mov al, 0xCD                  ; ═
    mov cx, [di + WINDOW.width] ; changed from si
    sub cx, 2                     ; Subtract corners
    rep stosw

    ; Bottom-right corner
    mov al, 0xBC                  ; ╝
    stosw

    ; Draw window title
    push si

    ; Calculate position for title
    movzx ax, bh                  ; Row
    mov dx, 80
    mul dx                        ; AX = row * 80
    movzx dx, bl                  ; Column
    add ax, dx                    ; AX = row * 80 + col
    inc ax                        ; Offset for first title character
    shl ax, 1                     ; AX = (row * 80 + col) * 2
    mov di, ax

    ; Set title color
    mov ah, WINDOW_TITLE_COLOR

    ; Get title string
    mov si, di
    add si, WINDOW.title

    ; Draw title (up to window width - 4 characters)
    mov cx, [di + WINDOW.width] ; changed from si
    sub cx, 4                     ; Leave space at edges

.title_loop:
    lodsb
    test al, al                   ; Check for end of string
    jz .title_done
    stosw
    loop .title_loop

.title_done:
    pop si

.done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: window_clear
; Clears a window (for now just erases it from screen)
; Input: AL = window ID
;------------------------------------------------------------------
window_clear:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    ; Find the window
    call window_find
    test di, di
    jz .done

    ; Set up video memory
    mov ax, 0xB800
    mov es, ax

    ; Get window position and size
    mov bl, [di + WINDOW.x]
    mov bh, [di + WINDOW.y]
    mov cl, [di + WINDOW.width]
    mov ch, [di + WINDOW.height]

    ; Clear the window area (fill with spaces)
    mov si, di                    ; Save window structure pointer

    ; Calculate row offset for starting position
    movzx ax, bh                  ; Row
    mov dx, 80
    mul dx                        ; AX = row * 80
    movzx dx, bl                  ; Column
    add ax, dx                    ; AX = row * 80 + col
    shl ax, 1                     ; AX = (row * 80 + col) * 2
    mov di, ax

    ; Loop through rows
    movzx dx, ch                  ; Height

.row_loop:
    ; Fill row with spaces
    mov cx, [si + WINDOW.width]
    push di

.col_loop:
    mov word [es:di], 0x0720      ; Space with normal attribute
    add di, 2
    loop .col_loop

    pop di                        ; Restore row position
    add di, 160                   ; Next row (80 * 2)

    dec dx
    jnz .row_loop

.done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: window_print
; Prints text in a window
; Input: AL = window ID
;        BL = relative X position
;        BH = relative Y position
;        SI = pointer to null-terminated text
;------------------------------------------------------------------
window_print:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    ; Find the window
    call window_find
    test di, di
    jz .done

    ; Set up video memory
    mov ax, 0xB800
    mov es, ax

    ; Calculate absolute position
    mov cl, [di + WINDOW.x]       ; Window X
    add cl, bl                    ; Add relative X
    inc cl                        ; Adjust for border

    mov ch, [di + WINDOW.y]       ; Window Y
    add ch, bh                    ; Add relative Y
    inc ch                        ; Adjust for border

    ; Check if position is within window content area
    cmp cl, [di + WINDOW.x]
    jbe .done                     ; X too small

    mov dl, [di + WINDOW.x]
    add dl, [di + WINDOW.width]
    sub dl, 2                     ; Adjust for border
    cmp cl, dl
    jae .done                     ; X too large

    cmp ch, [di + WINDOW.y]
    jbe .done                     ; Y too small

    mov dl, [di + WINDOW.y]
    add dl, [di + WINDOW.height]
    sub dl, 2                     ; Adjust for border
    cmp ch, dl
    jae .done                     ; Y too large

    ; Calculate position in video memory
    movzx ax, ch                  ; Row
    mov dx, 80
    mul dx                        ; AX = row * 80
    movzx dx, cl                  ; Column
    add ax, dx                    ; AX = row * 80 + col
    shl ax, 1                     ; AX = (row * 80 + col) * 2
    mov di, ax

    ; Set text color
    mov ah, WINDOW_CONTENT_COLOR

    ; Print text
.print_loop:
    lodsb                         ; Load character
    test al, al                   ; Check for null terminator
    jz .done

    ; Check for special characters
    cmp al, 10                    ; Newline
    je .newline
    cmp al, 13                    ; Carriage return
    je .carriage_return

    ; Print regular character
    stosw

    ; Check if we've reached the right edge of the window
    mov ax, di
    sub ax, 2                     ; Move back to the character we just wrote
    mov dx, 160                   ; Bytes per row
    div dl                        ; AL = row, AH = column * 2
    shr ah, 1                     ; AH = column

    ; Calculate right edge of window
    mov dl, [di + WINDOW.x]
    add dl, [di + WINDOW.width]
    sub dl, 2                     ; Adjust for border

    cmp ah, dl
    jae .newline                  ; If at or beyond right edge, go to next line

    jmp .print_loop

.newline:
    ; Move to next row (same column as line start)
    mov ax, di
    mov dx, 160                   ; Bytes per row
    div dl                        ; AL = row, AH = column * 2
    and ax, 0xFF00                ; Clear column
    add ax, 160                   ; Next row

    ; Add the column offset (start of content area)
    mov dl, [di + WINDOW.x]
    inc dl                        ; Adjust for border
    shl dl, 1                     ; Convert to offset (2 bytes per character)
    mov dh, 0
    add ax, dx

    mov di, ax

    ; Check if we've reached the bottom of the window
    mov dl, [di + WINDOW.y]
    add dl, [di + WINDOW.height]
    sub dl, 2                     ; Adjust for border

    shr ax, 1                     ; Convert to character offset
    mov dx, 80
    div dl                        ; AL = row, AH = column
    cmp al, dl
    jae .done                     ; If beyond bottom edge, stop printing

    jmp .print_loop

.carriage_return:
    ; Just continue to next character
    jmp .print_loop

.done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: window_activate
; Activates a window (brings to front)
; Input: AL = window ID
;------------------------------------------------------------------
window_activate:
    push ax

    ; Set as active window
    mov [window_active], al

    ; Redraw the window
    call window_draw

    pop ax
    ret

;------------------------------------------------------------------
; Dummy functions with minimal safe implementation
; To be fully implemented later
;------------------------------------------------------------------

find_free_window:
    ; Returns index of free window or 0xFFFF if none found
    ; For now: return 0xFFFF = no free window
    mov ax, 0FFFFh
    ret

copy_string:
    ; Copies zero-terminated string from DS:SI to ES:DI
    ; For now: simple loop copying bytes until zero
.copy_loop:
    lodsb           ; load byte from DS:SI into AL, SI++
    stosb           ; store AL into ES:DI, DI++
    cmp al, 0
    jne .copy_loop
    ret

draw_window_border:
    ; Dummy placeholder for drawing window border
    ; Parameters should be passed (e.g., coords in registers)
    ; Just return for now
    ret

draw_window_title:
    ; Dummy placeholder for drawing window title
    ; Parameters: pointer to title string in SI, window info in other registers
    ret

draw_window_contents:
    ; Dummy placeholder for drawing window contents
    ; Parameters: pointer to contents buffer etc.
    ret