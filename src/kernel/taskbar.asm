;==================================================================
; NoX-OS Taskbar Module
;==================================================================
; Implements a taskbar-like interface at the bottom of the screen,
; showing system status, time, and active tasks - a feature not
; present in MS-DOS

;------------------------------------------------------------------
; Constants and Variables
;------------------------------------------------------------------
%define TASKBAR_ROW 24           ; Row where taskbar appears (bottom row)
%define TASKBAR_COLOR 0x1F       ; Blue background, white text

; Taskbar state variables
taskbar_enabled db 1             ; Whether taskbar is enabled (1) or disabled (0)
taskbar_visible db 0             ; Whether taskbar is currently visible
taskbar_update_time db 0         ; Counter for time updates
taskbar_clock_format db 0        ; 0 = 24h, 1 = 12h

; Taskbar buffer to store screen content that gets overwritten
taskbar_buffer: times 160 db 0   ; 80 chars x 2 bytes (char+attr)

;------------------------------------------------------------------
; Function: taskbar_init
; Initializes the taskbar system
;------------------------------------------------------------------
taskbar_init:
    push ax
    
    ; Set taskbar as enabled but not visible yet
    mov byte [taskbar_enabled], 1
    mov byte [taskbar_visible], 0
    
    ; Set clock format to 24h by default
    mov byte [taskbar_clock_format], 0
    
    pop ax
    ret

;------------------------------------------------------------------
; Function: taskbar_toggle
; Toggles taskbar visibility
;------------------------------------------------------------------
taskbar_toggle:
    push ax
    
    ; Toggle the enabled flag
    mov al, [taskbar_enabled]
    xor al, 1
    mov [taskbar_enabled], al
    
    ; If we're disabling, hide it
    test al, al
    jz taskbar_hide
    
    ; If we're enabling, show it
    call taskbar_show
    
    pop ax
    ret

;------------------------------------------------------------------
; Function: taskbar_show
; Displays the taskbar
;------------------------------------------------------------------
taskbar_show:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push ds
    
    ; Check if taskbar is enabled
    cmp byte [taskbar_enabled], 0
    je .done
    
    ; Check if taskbar is already visible
    cmp byte [taskbar_visible], 1
    je .done
    
    ; Save screen contents before drawing taskbar
    call taskbar_save_screen
    
    ; Set video memory segment
    mov ax, 0xB800
    mov es, ax
    
    ; Calculate starting position for taskbar (row 24, column 0)
    mov di, (TASKBAR_ROW * 80) * 2
    
    ; Set the attributes for the taskbar (blue background, white text)
    mov ah, TASKBAR_COLOR
    
    ; Draw the taskbar background
    mov cx, 80  ; 80 characters across the screen
    mov al, ' ' ; Fill with spaces
    rep stosw
    
    ; Reset DI to beginning of taskbar
    mov di, (TASKBAR_ROW * 80) * 2
    
    ; Draw the OS name at the left
    mov si, taskbar_os_name
    call taskbar_write_text
    
    ; Draw the separator
    add di, 2
    mov al, '|'
    mov ah, TASKBAR_COLOR
    stosw
    add di, 2
    
    ; Draw the memory status
    call taskbar_draw_memory
    
    ; Draw the separator
    add di, 2
    mov al, '|'
    mov ah, TASKBAR_COLOR
    stosw
    add di, 2
    
    ; Calculate position for the clock (right-aligned)
    mov di, (TASKBAR_ROW * 80 + 80 - 10) * 2
    
    ; Draw the current time
    call taskbar_draw_time
    
    ; Mark taskbar as visible
    mov byte [taskbar_visible], 1
    
.done:
    pop ds
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: taskbar_hide
; Hides the taskbar and restores the original screen content
;------------------------------------------------------------------
taskbar_hide:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push ds
    
    ; Check if taskbar is visible
    cmp byte [taskbar_visible], 0
    je .done
    
    ; Restore the original screen content
    call taskbar_restore_screen
    
    ; Mark taskbar as not visible
    mov byte [taskbar_visible], 0
    
.done:
    pop ds
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: taskbar_save_screen
; Saves the screen area that will be covered by the taskbar
;------------------------------------------------------------------
taskbar_save_screen:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push ds
    
    ; Set up source and destination
    mov ax, 0xB800
    mov ds, ax
    mov si, (TASKBAR_ROW * 80) * 2
    
    mov ax, cs
    mov es, ax
    mov di, taskbar_buffer
    
    ; Copy screen contents to buffer
    mov cx, 80
    rep movsw
    
    pop ds
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: taskbar_restore_screen
; Restores the original screen content that was covered by the taskbar
;------------------------------------------------------------------
taskbar_restore_screen:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push ds
    
    ; Set up source and destination
    mov ax, cs
    mov ds, ax
    mov si, taskbar_buffer
    
    mov ax, 0xB800
    mov es, ax
    mov di, (TASKBAR_ROW * 80) * 2
    
    ; Copy buffer back to screen
    mov cx, 80
    rep movsw
    
    pop ds
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: taskbar_update
; Updates the taskbar (called regularly from main loop)
;------------------------------------------------------------------
taskbar_update:
    push ax
    
    ; Check if taskbar is enabled and visible
    cmp byte [taskbar_enabled], 0
    je .done
    cmp byte [taskbar_visible], 0
    je .done
    
    ; Update counter
    inc byte [taskbar_update_time]
    cmp byte [taskbar_update_time], 18  ; Update approximately every second (18 ticks)
    jb .done
    
    ; Reset counter
    mov byte [taskbar_update_time], 0
    
    ; Update time display
    call taskbar_draw_time
    
.done:
    pop ax
    ret

;------------------------------------------------------------------
; Function: taskbar_draw_time
; Draws the current time on the taskbar
;------------------------------------------------------------------
taskbar_draw_time:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    ; Set video memory segment
    mov ax, 0xB800
    mov es, ax
    
    ; Calculate position for the clock (right-aligned)
    mov di, (TASKBAR_ROW * 80 + 80 - 10) * 2
    
    ; Get current time
    call get_rtc_time
    
    ; Draw time based on format
    cmp byte [taskbar_clock_format], 0
    je .24h_format
    
    ; 12-hour format (TODO)
    jmp .draw_time
    
.24h_format:
    ; Display hours
    mov al, ch                    ; Hour in CH
    call bcd_to_binary
    aam                           ; Convert to BCD for display
    add ax, '00'                 ; Convert to ASCII
    mov es:[di], ah               ; Display tens digit
    mov es:[di+2], al             ; Display ones digit
    add di, 4
    
    ; Display colon
    mov word es:[di], TASKBAR_COLOR * 256 + ':'
    add di, 2
    
    ; Display minutes
    mov al, cl                    ; Minute in CL
    call bcd_to_binary
    aam                           ; Convert to BCD for display
    add ax, '00'                 ; Convert to ASCII
    mov es:[di], ah               ; Display tens digit
    mov es:[di+2], al             ; Display ones digit
    add di, 4
    
    ; Display colon
    mov word es:[di], TASKBAR_COLOR * 256 + ':'
    add di, 2
    
    ; Display seconds
    mov al, dh                    ; Second in DH
    call bcd_to_binary
    aam                           ; Convert to BCD for display
    add ax, '00'                 ; Convert to ASCII
    mov es:[di], ah               ; Display tens digit
    mov es:[di+2], al             ; Display ones digit
    
.draw_time:
    ; Set all the attributes
    mov di, (TASKBAR_ROW * 80 + 80 - 10) * 2
    mov cx, 8                    ; 8 characters (HH:MM:SS)
    
.set_attr_loop:
    inc di                       ; Move to attribute byte
    mov byte es:[di], TASKBAR_COLOR  ; Set attribute
    inc di                       ; Move to next character
    loop .set_attr_loop
    
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: taskbar_draw_memory
; Draws memory usage information on the taskbar
;------------------------------------------------------------------
taskbar_draw_memory:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    ; Set video memory segment
    mov ax, 0xB800
    mov es, ax
    
    ; Position is passed in DI
    
    ; Get memory stats
    call mem_get_stats            ; AX=total, BX=free, CX=used, DX=largest free
    
    ; Display memory usage text
    mov si, taskbar_mem_msg
    call taskbar_write_text
    
    ; Display free memory percentage
    ; Calculate percentage: (free * 100) / total
    mov ax, bx                   ; Free memory
    mov cx, 100
    mul cx
    div word [mem_total_kb]
    
    ; Display percentage
    aam                          ; Convert to BCD for display
    add ax, '00'                 ; Convert to ASCII
    
    ; Check if we need to display tens digit
    cmp ah, '0'
    je .skip_tens
    mov es:[di], ah              ; Display tens digit
    add di, 2
    
.skip_tens:
    mov es:[di], al              ; Display ones digit
    add di, 2
    
    ; Display percent sign
    mov word es:[di], TASKBAR_COLOR * 256 + '%'
    add di, 2
    
    ; Display "Free"
    mov si, taskbar_free_msg
    call taskbar_write_text
    
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: taskbar_write_text
; Writes text to the taskbar with the taskbar attribute
; Input: SI = text to write (null-terminated)
;        DI = destination in video memory
; Output: DI = updated position
;------------------------------------------------------------------
taskbar_write_text:
    push ax
    
    mov ah, TASKBAR_COLOR
    
.loop:
    lodsb                        ; Load next character
    test al, al                  ; Check for end of string
    jz .done
    
    stosw                        ; Write character and attribute
    jmp .loop
    
.done:
    pop ax
    ret

;------------------------------------------------------------------
; Taskbar strings
;------------------------------------------------------------------
taskbar_os_name db ' NoX-OS ', 0
taskbar_mem_msg db 'Mem: ', 0
taskbar_free_msg db ' Free', 0