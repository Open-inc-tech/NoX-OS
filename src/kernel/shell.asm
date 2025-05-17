;==================================================================
; NoX-OS Shell
;==================================================================
; Basic command-line shell functionality

;------------------------------------------------------------------
; Shell constants and variables
;------------------------------------------------------------------
MAX_CMD_LEN equ 64          ; Maximum command length

; Shell input buffer (defined in kernel.asm)
; cmd_buffer times MAX_CMD_LEN db 0

;------------------------------------------------------------------
; Function: process_command
; This function is already defined in kernel.asm
; It processes a command string and executes the appropriate action
;------------------------------------------------------------------

;------------------------------------------------------------------
; Function: shell_prompt
; Displays the command prompt
;------------------------------------------------------------------
shell_prompt:
    push si
    
    call print_newline
    mov si, prompt_str
    call print_string
    
    pop si
    ret

;------------------------------------------------------------------
; Function: shell_read_command
; Reads a command from the user
; Output: cmd_buffer filled with user input
;------------------------------------------------------------------
shell_read_command:
    push di
    
    ; Clear the command buffer
    mov di, cmd_buffer
    mov cx, MAX_CMD_LEN
    mov al, 0
    rep stosb
    
    ; Read user input
    mov di, cmd_buffer
    call read_line
    
    pop di
    ret

;------------------------------------------------------------------
; Function: shell_error
; Displays an error message
; Input: SI = pointer to error message
;------------------------------------------------------------------
shell_error:
    push si
    
    call print_newline
    mov si, error_prefix
    call print_string
    pop si
    push si
    call print_string
    
    pop si
    ret

;------------------------------------------------------------------
; Function: shell_success
; Displays a success message
; Input: SI = pointer to success message
;------------------------------------------------------------------
shell_success:
    push si
    
    call print_newline
    mov si, success_prefix
    call print_string
    pop si
    push si
    call print_string
    
    pop si
    ret

;------------------------------------------------------------------
; DATA SECTION
;------------------------------------------------------------------
prompt_str db 'NoX> ', 0
error_prefix db 'Error: ', 0
success_prefix db 'Success: ', 0
