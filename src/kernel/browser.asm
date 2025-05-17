
;==================================================================
; NoX-OS Web Browser Implementation
;==================================================================

section .data
browser_title db "NoX Browser", 0
url_prompt db "Enter URL: ", 0
loading_msg db "Loading...", 0
error_msg db "Error: Could not load page", 0

section .text
browser_init:
    push ax
    push bx
    
    ; Create browser window
    mov al, 5                    ; X position
    mov ah, 2                    ; Y position
    mov bl, 70                   ; Width
    mov bh, 20                   ; Height
    mov si, browser_title
    call window_create
    mov [browser_window_id], al
    
    ; Initialize network components
    call init_network
    
    pop bx
    pop ax
    ret

browser_main:
    push ax
    push bx
    
    ; Draw URL bar
    mov al, [browser_window_id]
    mov bl, 2                    ; X position
    mov bh, 1                    ; Y position
    mov si, url_prompt
    call window_print
    
    ; Handle input and navigation
    call handle_browser_input
    
    pop bx
    pop ax
    ret

handle_browser_input:
    ; Basic input handling for URLs
    call get_line_input
    call attempt_connection
    ret

section .bss
browser_window_id resb 1
url_buffer resb 256
