[org 0x7e00]

start:
    call cls
    call print_prompt

main_loop:
    call read_line
    call execute_command
    jmp main_loop

print_prompt:
    mov si, prompt
    call print_string
    ret

read_line:
    xor cx, cx
.read:
    mov ah, 0
    int 0x16
    cmp al, 13
    je .done
    mov ah, 0x0e
    int 0x10
    mov [cmd_buffer + cx], al
    inc cx
    jmp .read
.done:
    mov byte [cmd_buffer + cx], 0
    ret

execute_command:
    mov si, cmd_buffer
    mov di, echo_cmd
    call str_cmp
    je do_echo

    mov si, cmd_buffer
    mov di, help_cmd
    call str_cmp
    je do_help

    jmp unknown_cmd

do_echo:
    mov si, echo_msg
    call print_string
    ret

do_help:
    mov si, help_msg
    call print_string
    ret

unknown_cmd:
    mov si, unk_msg
    call print_string
    ret

; ------------------------
; Pomocné funkce
; ------------------------

print_string:
.loop:
    lodsb
    cmp al, 0
    je .done
    mov ah, 0x0e
    int 0x10
    jmp .loop
.done:
    ret

str_cmp:
.loop:
    lodsb
    scasb
    jne .ne
    cmp al, 0
    jne .loop
    cmp byte [di], 0
    jne .ne
    mov ax, 1
    ret
.ne:
    xor ax, ax
    ret

cls:
    mov ax, 0x03
    int 0x10
    ret

; ------------------------
; Data
; ------------------------

prompt db "Nox> ", 0
echo_cmd db "echo", 0
echo_msg db "This is Nox-OS!", 13, 10, 0
help_cmd db "help", 0
help_msg db "Available commands: echo, help", 13, 10, 0
unk_msg db "Unknown command", 13, 10, 0
cmd_buffer times 64 db 0
