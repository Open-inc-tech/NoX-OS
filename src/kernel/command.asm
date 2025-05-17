;==================================================================
; NoX-OS Command Shell Handler
;==================================================================
; Enhanced command shell with DOS-like commands

;------------------------------------------------------------------
; Constants and Data
;------------------------------------------------------------------
%define MAX_CMD_LEN 255         ; Maximum command line length
%define MAX_PATH_LEN 64         ; Maximum path length
%define MAX_HISTORY 10          ; Number of commands to store in history

; Buffer for the command line input
cmd_line: times MAX_CMD_LEN+1 db 0

; Command history
cmd_history_buffer: times (MAX_CMD_LEN+1)*MAX_HISTORY db 0
cmd_history_count: db 0         ; Number of commands in history
cmd_history_position: db 0      ; Current position in history when navigating

; Command table entry structure
struc CMD_ENTRY
    .name      resb 12          ; Command name (null-terminated)
    .function  resw 1           ; Pointer to command function
    .help      resb 64          ; Help text (null-terminated)
endstruc

CMD_ENTRY_size equ 78           ; Total size of a command entry

;------------------------------------------------------------------
; Command Table
;------------------------------------------------------------------
command_table:
    ; Format: command name, handler function, help text
    db 'HELP', 0, 0, 0, 0, 0, 0, 0, 0  ; Name field (12 bytes)
    dw cmd_help                        ; Function pointer (2 bytes)
    db 'Displays help information about available commands', 0  ; Help text (64 bytes)
    times 64 - 44 db 0                 ; Padding for help text
    
    db 'CLS', 0, 0, 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_cls                           ; Function pointer
    db 'Clears the screen', 0            ; Help text
    times 64 - 17 db 0                   ; Padding for help text
    
    db 'VER', 0, 0, 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_ver                           ; Function pointer
    db 'Displays the system version', 0  ; Help text
    times 64 - 28 db 0                   ; Padding for help text
    
    db 'DIR', 0, 0, 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_dir                           ; Function pointer
    db 'Lists files and directories in the current directory', 0  ; Help text
    times 64 - 50 db 0                   ; Padding for help text
    
    db 'TYPE', 0, 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_type                        ; Function pointer
    db 'Displays the contents of a text file', 0  ; Help text
    times 64 - 38 db 0                 ; Padding for help text
    
    db 'CD', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_cd                             ; Function pointer
    db 'Changes the current directory', 0  ; Help text
    times 64 - 30 db 0                    ; Padding for help text
    
    db 'DEL', 0, 0, 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_del                           ; Function pointer
    db 'Deletes one or more files', 0     ; Help text
    times 64 - 26 db 0                   ; Padding for help text
    
    db 'EDIT', 0, 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_edit                        ; Function pointer
    db 'Simple text editor', 0          ; Help text
    times 64 - 19 db 0                 ; Padding for help text
    
    db 'DATE', 0, 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_date                        ; Function pointer
    db 'Displays or sets the system date', 0  ; Help text
    times 64 - 35 db 0                 ; Padding for help text
    
    db 'TIME', 0, 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_time                        ; Function pointer
    db 'Displays or sets the system time', 0  ; Help text
    times 64 - 35 db 0                 ; Padding for help text
    
    db 'COPY', 0, 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_copy                        ; Function pointer
    db 'Copies one or more files to another location', 0  ; Help text
    times 64 - 45 db 0                 ; Padding for help text
    
    db 'MEM', 0, 0, 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_mem                           ; Function pointer
    db 'Displays memory usage information', 0  ; Help text
    times 64 - 35 db 0                   ; Padding for help text
    
    db 'MEMADV', 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_memadv                      ; Function pointer
    db 'Advanced memory management tools', 0  ; Help text
    times 64 - 35 db 0                 ; Padding for help text
    
    db 'FIND', 0, 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_find                        ; Function pointer
    db 'Searches for files matching a pattern', 0  ; Help text
    times 64 - 38 db 0                 ; Padding for help text
    
    db 'PRINT', 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_print                      ; Function pointer
    db 'Prints a text file on the printer', 0  ; Help text
    times 64 - 35 db 0                ; Padding for help text
    
    db 'MENU', 0, 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_menu                        ; Function pointer
    db 'Shows a user-friendly menu interface', 0  ; Help text
    times 64 - 37 db 0                 ; Padding for help text
    
    db 'FORMAT', 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_format                    ; Function pointer
    db 'Formats a disk for use with NoX-OS', 0  ; Help text
    times 64 - 36 db 0               ; Padding for help text
    
    db 'SYS', 0, 0, 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_sys                           ; Function pointer
    db 'Displays system information', 0  ; Help text
    times 64 - 28 db 0                   ; Padding for help text
    
    db 'TASKBAR', 0, 0, 0, 0  ; Name field
    dw cmd_taskbar                     ; Function pointer
    db 'Controls the taskbar display (ON|OFF)', 0  ; Help text
    times 64 - 37 db 0                 ; Padding for help text
    
    db 'WINDOW', 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_window                      ; Function pointer
    db 'Creates and manages windows', 0  ; Help text
    times 64 - 29 db 0                 ; Padding for help text
    
    db 'TASK', 0, 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_task                        ; Function pointer
    db 'Manages multitasking operations', 0  ; Help text
    times 64 - 31 db 0                 ; Padding for help text
    
    db 'MOUSE', 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_mouse                       ; Function pointer
    db 'Controls mouse pointer (SHOW|HIDE|STATUS)', 0  ; Help text
    times 64 - 38 db 0                 ; Padding for help text
    
    db 'EXIT', 0, 0, 0, 0, 0, 0, 0, 0  ; Name field
    dw cmd_exit                        ; Function pointer
    db 'Exits the shell or reboots the system', 0  ; Help text
    times 64 - 39 db 0                 ; Padding for help text
    
    ; End of table marker
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0  ; Empty name field
    dw 0                                   ; Empty function pointer
    times 64 db 0                          ; Empty help text

;------------------------------------------------------------------
; Command Handler Functions
;------------------------------------------------------------------

;------------------------------------------------------------------
; Function: cmd_help
; Displays help for commands
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_help:
    push si
    push di
    
    ; Skip "HELP" command
    call cmd_skip_token
    
    ; Skip whitespace
    call cmd_skip_whitespace
    
    ; Check if a specific command was requested
    cmp byte [si], 0
    je .general_help
    
    ; Get the command name from the argument
    mov di, si
    
    ; Convert to uppercase for comparison
.upper_loop:
    mov al, [di]
    test al, al
    jz .find_command
    cmp al, ' '              ; Stop at first space
    je .find_command
    
    call cmd_to_uppercase
    mov [di], al
    inc di
    jmp .upper_loop
    
.find_command:
    ; Save the original character
    mov al, [di]
    mov byte [di], 0         ; Temporarily null-terminate
    
    ; Find the command in the table
    mov di, command_table
    
.search_loop:
    ; Check if we've reached the end of the table
    cmp byte [di], 0
    je .not_found
    
    ; Compare the command name
    push si
    push di
    call strcmp
    pop di
    pop si
    jnc .next_command
    
    ; Found the command, display its help
    mov si, help_for_msg
    call print_string
    
    mov si, di               ; Point to command name
    call print_string
    call print_newline
    
    add di, 12 + 2           ; Skip name and function pointer
    mov si, di               ; Point to help text
    call print_string
    call print_newline
    
    ; Restore the original character
    pop di                   ; Original DI
    mov byte [di], al        ; Restore character
    
    jmp .done
    
.next_command:
    add di, CMD_ENTRY_size   ; Move to next command
    jmp .search_loop
    
.not_found:
    ; Restore the original character
    mov byte [di], al
    
    mov si, unknown_cmd_msg
    call print_string
    jmp .done
    
.general_help:
    ; Display help for all commands
    mov si, help_header_msg
    call print_string
    
    ; Loop through the command table
    mov di, command_table
    
.help_loop:
    ; Check if we've reached the end of the table
    cmp byte [di], 0
    je .done
    
    ; Display command name (left-aligned)
    mov si, di
    call print_string
    
    ; Add padding after command name
    push di
    mov cx, 12               ; Command field width
    mov di, si               ; DI points to command name
    
.count_loop:
    cmp byte [di], 0         ; Find the null terminator
    je .count_done
    inc di
    dec cx
    jnz .count_loop
    
.count_done:
    ; Print spaces for padding
    mov al, ' '
.pad_loop:
    test cx, cx
    jz .pad_done
    call print_char
    dec cx
    jmp .pad_loop
    
.pad_done:
    pop di
    
    ; Display the help text
    add di, 12 + 2           ; Skip name and function pointer
    mov si, di
    call print_string
    call print_newline
    
    ; Move to next command
    sub di, 12 + 2           ; Move back to start of entry
    add di, CMD_ENTRY_size   ; Move to next entry
    jmp .help_loop
    
.done:
    pop di
    pop si
    ret

;------------------------------------------------------------------
; Function: cmd_cls
; Clears the screen
;------------------------------------------------------------------
cmd_cls:
    call clear_screen
    ret

;------------------------------------------------------------------
; Function: cmd_ver
; Displays the system version
;------------------------------------------------------------------
cmd_ver:
    push ax
    push bx
    push cx
    push dx
    
    ; Display version information
    mov si, version_msg
    call print_string
    
    ; Display CPU information
    call print_newline
    mov si, cpu_info_msg
    call print_string
    
    ; Detect CPU type
    call detect_cpu
    
    ; Display detected CPU
    mov si, detected_cpu_msg
    call print_string
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: detect_cpu
; Detects the CPU type and displays it
;------------------------------------------------------------------
detect_cpu:
    push ax
    push bx
    push cx
    push dx
    
    ; Try to detect CPU type
    ; First check if CPU is at least an 8086/8088
    
    ; Check for 80286 or higher (try to push SP and look for different value when popped)
    pushf                   ; Push original FLAGS
    pop ax                  ; Pop into AX
    mov bx, ax              ; Save original FLAGS
    
    and ax, 0x0FFF          ; Clear bits 12-15
    or ax, 0x7000           ; Set bits 12-14 (they're always 1 on 8086/8088)
    push ax                 ; Push modified FLAGS
    popf                    ; Pop into FLAGS
    pushf                   ; Push FLAGS again
    pop ax                  ; Pop into AX
    
    and ax, 0x7000          ; Check bits 12-14
    cmp ax, 0x7000          ; If they're still set, it's an 8086/8088
    je .cpu_8086
    
    ; At this point, we know it's at least an 80286
    
    ; Restore original FLAGS
    push bx
    popf
    
    ; Check for CPUID support (try to toggle ID bit in EFLAGS)
    pushfd                  ; Push EFLAGS
    pop eax                 ; Pop into EAX
    mov ecx, eax            ; Save original EFLAGS
    
    xor eax, 0x200000       ; Toggle ID bit
    push eax                ; Push modified EFLAGS
    popfd                   ; Pop into EFLAGS
    
    pushfd                  ; Push EFLAGS again
    pop eax                 ; Pop into EAX
    
    ; Restore original EFLAGS
    push ecx
    popfd
    
    ; Check if ID bit was toggled successfully
    xor eax, ecx            ; If different, CPUID is supported
    test eax, 0x200000
    jz .cpu_386             ; If zero, CPUID not supported, assume 80386
    
    ; Execute CPUID instruction to determine CPU type
    mov eax, 0              ; Function 0: Get vendor ID and max CPUID level
    cpuid
    
    cmp eax, 1              ; If max CPUID level is at least 1, we can get family info
    jl .cpu_486             ; If not, assume 80486
    
    mov eax, 1              ; Function 1: Get processor info and feature bits
    cpuid
    
    mov ax, dx              ; Get family/model/stepping from EDX
    
    ; Family ID in bits 8-11
    shr ax, 8
    and ax, 0x0F
    
    cmp ax, 4
    je .cpu_486
    cmp ax, 5
    je .cpu_pentium
    cmp ax, 6
    je .cpu_pentium_pro
    
    ; If we get here, it's newer than Pentium Pro
    mov si, cpu_newer_msg
    call print_string
    jmp .done
    
.cpu_8086:
    mov si, cpu_8086_msg
    call print_string
    jmp .done
    
.cpu_386:
    mov si, cpu_386_msg
    call print_string
    jmp .done
    
.cpu_486:
    mov si, cpu_486_msg
    call print_string
    jmp .done
    
.cpu_pentium:
    mov si, cpu_pentium_msg
    call print_string
    jmp .done
    
.cpu_pentium_pro:
    mov si, cpu_pentium_pro_msg
    call print_string
    
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: cmd_date
; Displays or sets the system date
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_date:
    push si
    push ax
    push bx
    push cx
    push dx
    
    ; Skip "DATE" command
    call cmd_skip_token
    
    ; Skip whitespace
    call cmd_skip_whitespace
    
    ; Check if a date was provided
    cmp byte [si], 0
    je .display_date
    
    ; For now, just display a placeholder message
    mov si, date_placeholder_msg
    call print_string
    jmp .done
    
.display_date:
    ; Get current date from CMOS RTC
    call get_rtc_date
    
    ; Display the date
    mov si, current_date_msg
    call print_string
    
    ; Print month
    mov al, dh               ; Month in DH
    call cmd_print_dec
    
    ; Print separator
    mov al, '/'
    call print_char
    
    ; Print day
    mov al, dl               ; Day in DL
    call cmd_print_dec
    
    ; Print separator
    mov al, '/'
    call print_char
    
    ; Print year
    mov ax, cx               ; Year in CX
    call cmd_print_dec
    
    call print_newline
    
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    pop si
    ret

;------------------------------------------------------------------
; Function: cmd_time
; Displays or sets the system time
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_time:
    push si
    push ax
    push bx
    push cx
    push dx
    
    ; Skip "TIME" command
    call cmd_skip_token
    
    ; Skip whitespace
    call cmd_skip_whitespace
    
    ; Check if a time was provided
    cmp byte [si], 0
    je .display_time
    
    ; For now, just display a placeholder message
    mov si, time_placeholder_msg
    call print_string
    jmp .done
    
.display_time:
    ; Get current time from CMOS RTC
    call get_rtc_time
    
    ; Display the time
    mov si, current_time_msg
    call print_string
    
    ; Print hour
    mov al, ch               ; Hour in CH
    call cmd_print_dec
    
    ; Print separator
    mov al, ':'
    call print_char
    
    ; Print minute
    mov al, cl               ; Minute in CL
    call bcd_to_binary
    cmp al, 10
    jae .skip_zero_min
    mov dl, al
    mov al, '0'
    call print_char
    mov al, dl
.skip_zero_min:
    call cmd_print_dec
    
    ; Print separator
    mov al, ':'
    call print_char
    
    ; Print second
    mov al, dh               ; Second in DH
    call bcd_to_binary
    cmp al, 10
    jae .skip_zero_sec
    mov dl, al
    mov al, '0'
    call print_char
    mov al, dl
.skip_zero_sec:
    call cmd_print_dec
    
    call print_newline
    
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    pop si
    ret

;------------------------------------------------------------------
; Function: cmd_copy
; Copies files
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_copy:
    push si
    
    ; For now, just display a placeholder message
    mov si, copy_placeholder_msg
    call print_string
    
    pop si
    ret

;------------------------------------------------------------------
; Function: cmd_mem
; Displays memory information
;------------------------------------------------------------------
cmd_mem:
    push ax
    push bx
    push cx
    push dx
    
    ; Display memory information header
    mov si, mem_header_msg
    call print_string
    
    ; Get total conventional memory (up to 640K)
    int 0x12                 ; Get conventional memory size in KB (AX)
    mov [mem_total_kb], ax   ; Save total memory for later use
    
    ; Display total memory
    mov si, mem_conventional_msg
    call print_string
    call cmd_print_dec
    mov si, mem_kb_msg
    call print_string
    
    ; Calculate free memory percentage (approximate)
    mov bx, ax               ; Save total KB
    
    ; We'll estimate free memory as total - used by OS
    ; Since our OS is small (<64KB), we'll just subtract 64KB
    ; This is obviously just an approximation
    sub bx, 64               ; Subtract OS size (approximate)
    
    ; Calculate percentage: (free_mem * 100) / total_mem
    mov cx, 100
    mov ax, bx               ; Free memory
    mul cx                   ; AX = free_mem * 100
    
    ; If the original total memory was 0, avoid division by zero
    test bx, bx
    jz .skip_percentage
    
    mov cx, ax               ; Save the product
    int 0x12                 ; Get total memory again in AX
    
    ; Now do the division: (free_mem * 100) / total_mem
    mov dx, 0                ; Clear DX for division
    mov ax, cx               ; Load (free_mem * 100)
    
    ; Avoid division by zero
    cmp word [mem_total_kb], 0
    je .skip_percentage
    
    ; Performance optimization for division
    div word [mem_total_kb]  ; Divide by total memory
    
    ; Display free memory percentage
    call print_newline
    mov si, mem_free_msg
    call print_string
    call cmd_print_dec
    mov si, percent_msg
    call print_string
    
.skip_percentage:
    
    ; Get extended memory (above 1MB)
    mov ah, 0x88            ; Get extended memory size in KB
    int 0x15                ; Call BIOS
    
    ; Display extended memory if available
    jc .no_extended
    
    test ax, ax
    jz .no_extended
    
    ; Save the extended memory size
    mov [mem_extended_kb], ax
    
    call print_newline
    mov si, mem_extended_msg
    call print_string
    call cmd_print_dec
    mov si, mem_kb_msg
    call print_string
    
.no_extended:
    
    ; Try to detect total system memory using other methods
    call detect_total_memory
    
    ; Display memory map information
    call print_newline
    call print_newline
    mov si, mem_map_msg
    call print_string
    
    ; Display the NoX-OS kernel location
    call print_newline
    mov si, mem_kernel_msg
    call print_string
    
    ; Display memory usage details
    call print_newline
    mov si, mem_usage_msg
    call print_string
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
    
;------------------------------------------------------------------
; Function: detect_total_memory
; Tries to detect total system memory using various BIOS methods
;------------------------------------------------------------------
detect_total_memory:
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    
    ; Try INT 15h, AX=E820h (Get System Memory Map)
    mov ax, 0                ; Zero out segment
    mov es, ax
    
    ; Initialize counter
    xor ebx, ebx             ; Start at beginning
    mov di, mem_buffer       ; Set output buffer
    
    ; Set the memory map signature
    mov edx, 0x534D4150      ; 'SMAP'
    
.e820_loop:
    mov eax, 0xE820          ; Function code
    mov ecx, 20              ; Size of buffer
    int 0x15                 ; Call BIOS
    
    jc .e820_done            ; CF set means error or done
    
    ; Check if we got a valid entry
    cmp eax, 0x534D4150      ; Should be 'SMAP'
    jne .e820_done
    
    ; Check entry type (1=usable memory)
    cmp dword [es:di+16], 1
    jne .e820_next
    
    ; Add this region's size to total
    ; For simplicity, we'll just count the largest region
    mov eax, [es:di+8]       ; Region size low dword
    
    cmp eax, [mem_largest_region]
    jbe .e820_next
    
    ; Save this as the largest region
    mov [mem_largest_region], eax
    
.e820_next:
    test ebx, ebx            ; If EBX=0, we're done
    jz .e820_done
    
    ; More entries to process
    add di, 20               ; Move to next output buffer entry
    jmp .e820_loop
    
.e820_done:
    ; Display the detected memory if we found a valid region
    mov eax, [mem_largest_region]
    test eax, eax
    jz .no_e820
    
    ; Convert bytes to KB
    shr eax, 10              ; Divide by 1024
    
    ; Display it
    call print_newline
    mov si, mem_detected_msg
    call print_string
    
    ; Convert EAX to AX for display (might lose precision for large values)
    mov ax, ax               ; Just use the lower word for display
    call cmd_print_dec
    mov si, mem_kb_msg
    call print_string
    
.no_e820:
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: cmd_exit
; Exits the shell or current batch file
;------------------------------------------------------------------
cmd_exit:
    ; Just restart for now, since we can't truly exit the OS
    mov si, restart_msg
    call print_string
    
    ; Wait for keypress
    call read_key
    
    ; Reboot the system
    jmp word 0xFFFF:0x0000
    ret

;------------------------------------------------------------------
; Function: process_command
; Processes a command by looking up in command table and executing
; Input: SI = pointer to command line
;------------------------------------------------------------------
process_command:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Check if line is empty
    call skip_whitespace     ; Skip leading whitespace
    cmp byte [si], 0
    je .done
    
    ; Add command to history
    call add_to_history
    
    ; Find end of command (first space or end of line)
    mov di, si               ; DI = start of command
    
.find_cmd_end:
    mov al, [di]
    test al, al              ; Check for end of string
    jz .found_end
    cmp al, ' '              ; Check for space
    je .found_end
    inc di
    jmp .find_cmd_end
    
.found_end:
    ; Temporarily zero-terminate the command
    mov bl, [di]
    mov byte [di], 0
    
    ; Convert command to uppercase
    push di
    mov di, si
    
.upper_loop:
    mov al, [di]
    test al, al
    jz .search_command
    
    call cmd_to_uppercase
    mov [di], al
    inc di
    jmp .upper_loop
    
.search_command:
    pop di
    
    ; Search for command in command table
    push si
    mov si, di               ; SI now points to end of command
    mov di, command_table
    
.search_loop:
    ; Check if we've reached the end of the table
    cmp byte [di], 0
    je .unknown_command
    
    ; Compare command name
    pop bx                   ; BX = start of command
    push bx
    push di
    mov si, bx
    call strcmp
    pop di
    jnc .next_command
    
    ; Found the command, restore original character
    pop si                   ; Remove BX from stack
    mov [si], bl             ; Restore original character at end of command
    
    ; Get command function address
    add di, 12               ; Skip name field (12 bytes)
    call [di]                ; Call command function
    jmp .done
    
.next_command:
    add di, CMD_ENTRY_size   ; Move to next command
    jmp .search_loop
    
.unknown_command:
    ; Restore original character
    pop si                   ; Remove BX from stack
    mov [di], bl
    
    ; Command not found
    mov si, unknown_cmd_msg
    call print_string
    
.done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: add_to_history
; Adds the current command line to the history
; Input: SI = pointer to command line
;------------------------------------------------------------------
add_to_history:
    push ax
    push bx
    push cx
    push si
    push di
    
    ; Check if command is empty
    mov al, [si]
    test al, al
    jz .done
    
    ; Calculate destination address in history buffer
    movzx bx, [cmd_history_count]
    cmp bx, MAX_HISTORY
    jb .add_new
    
    ; Shift history down by one
    mov cx, MAX_HISTORY - 1
    
.shift_loop:
    ; Compute source and destination addresses
    mov ax, cx
    dec ax
    push ax
    mov ax, MAX_CMD_LEN + 1
    mul ax
    mov si, cmd_history_buffer
    add si, ax               ; SI = source
    
    pop ax
    mov ax, cx
    push ax
    mov ax, MAX_CMD_LEN + 1
    mul ax
    mov di, cmd_history_buffer
    add di, ax               ; DI = destination
    
    ; Copy one history entry
    push cx
    mov cx, MAX_CMD_LEN + 1
    push ds
    pop es                   ; ES=DS for string operations
    rep movsb
    pop cx
    
    pop ax
    
    dec cx
    jnz .shift_loop
    
    mov bx, MAX_HISTORY - 1   ; Use the first slot
    
.add_new:
    ; Copy command to history buffer
    mov ax, bx
    push ax
    mov ax, MAX_CMD_LEN + 1
    mul ax
    mov di, cmd_history_buffer
    add di, ax               ; DI = destination in history
    
    pop ax
    
    ; Copy the command
    mov si, cmd_line
    push cx
    mov cx, MAX_CMD_LEN + 1
    push ds
    pop es                   ; ES=DS for string operations
    rep movsb
    pop cx
    
    ; Update history count if needed
    mov al, [cmd_history_count]
    cmp al, MAX_HISTORY
    jae .done
    inc al
    mov [cmd_history_count], al
    
.done:
    ; Reset history position
    mov byte [cmd_history_position], 0
    
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: get_previous_history
; Gets the previous command from history
; Input: DI = pointer to destination buffer
; Output: CF set if no previous history
;------------------------------------------------------------------
get_previous_history:
    push ax
    push bx
    push cx
    push si
    
    ; Check if we're already at the oldest history entry
    mov al, [cmd_history_position]
    cmp al, [cmd_history_count]
    jae .no_more
    
    ; Increment position
    inc al
    mov [cmd_history_position], al
    
    ; Calculate address of history entry
    dec al                   ; Convert to 0-based index
    push ax
    movzx ax, al
    mov bx, MAX_CMD_LEN + 1
    mul bx
    mov si, cmd_history_buffer
    add si, ax               ; SI = source
    
    pop ax
    
    ; Copy history entry to destination
    push cx
    mov cx, MAX_CMD_LEN + 1
    rep movsb
    pop cx
    
    clc                      ; Clear carry flag (success)
    jmp .done
    
.no_more:
    stc                      ; Set carry flag (no more history)
    
.done:
    pop si
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: get_next_history
; Gets the next command from history
; Input: DI = pointer to destination buffer
; Output: CF set if no next history
;------------------------------------------------------------------
get_next_history:
    push ax
    push bx
    push cx
    push si
    
    ; Check if we're at the newest history entry
    mov al, [cmd_history_position]
    test al, al
    jz .no_more
    
    ; Decrement position
    dec al
    mov [cmd_history_position], al
    
    ; Check if we've reached the input line (position 0)
    test al, al
    jz .clear_line
    
    ; Calculate address of history entry
    dec al                   ; Convert to 0-based index
    push ax
    movzx ax, al
    mov bx, MAX_CMD_LEN + 1
    mul bx
    mov si, cmd_history_buffer
    add si, ax               ; SI = source
    
    pop ax
    
    ; Copy history entry to destination
    push cx
    mov cx, MAX_CMD_LEN + 1
    rep movsb
    pop cx
    
    clc                      ; Clear carry flag (success)
    jmp .done
    
.clear_line:
    ; Clear the input line
    mov cx, MAX_CMD_LEN + 1
    xor al, al
    rep stosb
    
    clc                      ; Clear carry flag (success)
    jmp .done
    
.no_more:
    stc                      ; Set carry flag (no more history)
    
.done:
    pop si
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Helper Functions
;------------------------------------------------------------------

;------------------------------------------------------------------
; Function: cmd_skip_token
; Skips the current token (word) in a string
; Input: SI = pointer to string
; Output: SI = pointer to position after token
;------------------------------------------------------------------
cmd_skip_token:
    push ax
    
    ; Skip non-whitespace characters
.token_loop:
    mov al, [si]
    test al, al                       ; Check for end of string
    jz .done
    
    cmp al, ' '                       ; Check for space
    je .whitespace
    cmp al, 9                         ; Check for tab
    je .whitespace
    
    inc si                            ; Move to next character
    jmp .token_loop
    
.whitespace:
    ; Now skip the whitespace
    call cmd_skip_whitespace
    
.done:
    pop ax
    ret

;------------------------------------------------------------------
; Function: cmd_skip_whitespace
; Skips whitespace characters in a string
; Input: SI = pointer to string
; Output: SI = pointer to next non-whitespace character
;------------------------------------------------------------------
cmd_skip_whitespace:
    push ax
    
.loop:
    mov al, [si]
    
    ; Check for end of string
    test al, al
    jz .done
    
    ; Check for whitespace
    cmp al, ' '
    je .skip
    cmp al, 9               ; Tab
    je .skip
    
    ; Not whitespace, done
    jmp .done
    
.skip:
    inc si
    jmp .loop
    
.done:
    pop ax
    ret

;------------------------------------------------------------------
; Function: strcmp
; Compares two strings
; Input: DS:SI, DS:DI = pointers to strings to compare
; Output: Carry flag set if equal, clear if different
;------------------------------------------------------------------
strcmp:
    push ax
    
.loop:
    mov al, [si]
    cmp al, [di]
    jne .not_equal
    
    ; Check if we've reached the end of the string
    test al, al
    jz .equal
    
    ; Move to next character
    inc si
    inc di
    jmp .loop
    
.equal:
    stc                     ; Set carry flag for equal
    jmp .done
    
.not_equal:
    clc                     ; Clear carry flag for not equal
    
.done:
    pop ax
    ret

;------------------------------------------------------------------
; Function: get_rtc_time
; Gets the current time from the CMOS RTC
; Output: CH = hour (BCD), CL = minute (BCD), DH = second (BCD)
;------------------------------------------------------------------
get_rtc_time:
    push ax
    
    ; Disable interrupts while accessing CMOS
    cli
    
    ; Read seconds
    mov al, 0x00            ; CMOS register for seconds
    out 0x70, al
    in al, 0x71
    mov dh, al              ; Store seconds in DH
    
    ; Read minutes
    mov al, 0x02            ; CMOS register for minutes
    out 0x70, al
    in al, 0x71
    mov cl, al              ; Store minutes in CL
    
    ; Read hours
    mov al, 0x04            ; CMOS register for hours
    out 0x70, al
    in al, 0x71
    mov ch, al              ; Store hours in CH
    
    ; Re-enable interrupts
    sti
    
    pop ax
    ret

;------------------------------------------------------------------
; Function: get_rtc_date
; Gets the current date from the CMOS RTC
; Output: DL = day (BCD), DH = month (BCD), CX = year (binary)
;------------------------------------------------------------------
get_rtc_date:
    push ax
    
    ; Disable interrupts while accessing CMOS
    cli
    
    ; Read day
    mov al, 0x07            ; CMOS register for day
    out 0x70, al
    in al, 0x71
    mov dl, al              ; Store day in DL
    
    ; Read month
    mov al, 0x08            ; CMOS register for month
    out 0x70, al
    in al, 0x71
    mov dh, al              ; Store month in DH
    
    ; Read year
    mov al, 0x09            ; CMOS register for year
    out 0x70, al
    in al, 0x71
    mov cl, al              ; Store year in CL (0-99)
    
    ; Read century
    mov al, 0x32            ; CMOS register for century
    out 0x70, al
    in al, 0x71
    mov ch, al              ; Store century in CH
    
    ; If century is 0, assume 2000's
    test ch, ch
    jnz .century_ok
    mov ch, 0x20
    
.century_ok:
    ; Convert BCD to binary for year
    call bcd_to_binary_word
    
    ; Re-enable interrupts
    sti
    
    pop ax
    ret

;------------------------------------------------------------------
; Function: bcd_to_binary
; Converts a BCD value to binary
; Input: AL = BCD value
; Output: AL = binary value
;------------------------------------------------------------------
bcd_to_binary:
    push bx
    
    mov bl, al              ; Save BCD value
    and bl, 0x0F            ; Isolate ones digit
    shr al, 4               ; Shift tens digit to ones position
    mov bh, 10
    mul bh                  ; Multiply tens digit by 10
    add al, bl              ; Add ones digit
    
    pop bx
    ret

;------------------------------------------------------------------
; Function: bcd_to_binary_word
; Converts a BCD word to binary
; Input: CX = BCD value (CH = hundreds, CL = ones/tens)
; Output: CX = binary value
;------------------------------------------------------------------
bcd_to_binary_word:
    push ax
    push bx
    
    ; Convert the ones/tens digit
    mov al, cl
    call bcd_to_binary
    mov cl, al
    
    ; Convert the hundreds/thousands digit
    mov al, ch
    call bcd_to_binary
    mov ch, al
    
    ; Combine to form 16-bit value
    mov bx, cx              ; Save BCD in BX
    movzx cx, ch            ; CX = hundreds value
    mov ax, 100
    mul cx                  ; AX = hundreds * 100
    movzx cx, bl            ; CX = ones/tens value
    add ax, cx              ; AX = final binary value
    mov cx, ax              ; Store result in CX
    
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: cmd_print_dec
; Prints a decimal number
; Input: AX = number to print
;------------------------------------------------------------------
cmd_print_dec:
    push ax
    push bx
    push cx
    push dx
    
    mov bx, 10                        ; Base 10
    xor cx, cx                        ; Digit counter
    
    ; Handle 0 as a special case
    test ax, ax
    jnz .convert
    
    mov al, '0'
    call print_char
    jmp .done
    
.convert:
    ; Convert to digits
    xor dx, dx                        ; Clear high word
    div bx                            ; Divide by 10
    push dx                           ; Save remainder (digit)
    inc cx                            ; Count digits
    
    test ax, ax                       ; Check if quotient is 0
    jnz .convert                      ; If not, continue converting
    
    ; Print digits in reverse order
.print_loop:
    pop ax                            ; Get digit
    add al, '0'                       ; Convert to ASCII
    call print_char                   ; Print it
    
    loop .print_loop                  ; Decrement CX and loop if not zero
    
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: cmd_to_uppercase
; Converts a character to uppercase
; Input: AL = character
; Output: AL = uppercase character
;------------------------------------------------------------------
cmd_to_uppercase:
    cmp al, 'a'
    jb .done
    cmp al, 'z'
    ja .done
    sub al, 'a' - 'A'                 ; Convert to uppercase
.done:
    ret

;------------------------------------------------------------------
; DATA SECTION
;------------------------------------------------------------------
; Command messages
version_msg db 'NoX-OS Version 0.3.0 Enhanced Edition', 0x0D, 0x0A
           db 'A practical 16-bit operating system', 0x0D, 0x0A
           db 'Copyright (c) 2023-2025', 0x0D, 0x0A
           db 'Build date: May 16, 2025', 0x0D, 0x0A, 0
           
cpu_info_msg db 'System Information:', 0x0D, 0x0A
           db '-------------------', 0x0D, 0x0A, 0

detected_cpu_msg db 'Detecting CPU type...', 0x0D, 0x0A, 0
cpu_8086_msg db 'CPU: Intel 8086/8088', 0x0D, 0x0A, 0
cpu_386_msg db 'CPU: Intel 80386', 0x0D, 0x0A, 0
cpu_486_msg db 'CPU: Intel 80486', 0x0D, 0x0A, 0
cpu_pentium_msg db 'CPU: Intel Pentium', 0x0D, 0x0A, 0
cpu_pentium_pro_msg db 'CPU: Intel Pentium Pro/II/III', 0x0D, 0x0A, 0
cpu_newer_msg db 'CPU: Modern Intel/AMD (Pentium 4 or newer)', 0x0D, 0x0A, 0

help_header_msg db 'NoX-OS v0.3.0 - Available commands:', 0x0D, 0x0A, 0
help_categories_msg db 0x0D, 0x0A, 'Command Categories:', 0x0D, 0x0A
                    db '  File Management: DIR, CD, TYPE, COPY, DEL, FIND', 0x0D, 0x0A
                    db '  System Tools: VER, MEM, SYS, FORMAT, TASK', 0x0D, 0x0A
                    db '  User Interface: CLS, MENU, EDIT, WINDOW, TASKBAR, MOUSE', 0x0D, 0x0A
                    db '  Output Devices: PRINT', 0x0D, 0x0A, 0x0D, 0x0A
                    db 'Type HELP command for detailed help on specific command.', 0x0D, 0x0A, 0
help_for_msg db 'Help for command: ', 0
unknown_cmd_msg db 'Unknown command. Type HELP for a list of commands.', 0x0D, 0x0A, 0

restart_msg db 'System will reboot. Press any key to continue...', 0x0D, 0x0A, 0

current_date_msg db 'Current date: ', 0
current_time_msg db 'Current time: ', 0

date_placeholder_msg db 'The DATE command will allow you to set the system date.', 0x0D, 0x0A
                    db 'This functionality will be fully implemented in the next version.', 0x0D, 0x0A, 0

time_placeholder_msg db 'The TIME command will allow you to set the system time.', 0x0D, 0x0A
                    db 'This functionality will be fully implemented in the next version.', 0x0D, 0x0A, 0

copy_placeholder_msg db 'The COPY command will copy files between locations.', 0x0D, 0x0A
                     db 'This functionality will be fully implemented in the next version.', 0x0D, 0x0A, 0

mem_header_msg db 'Memory Information:', 0x0D, 0x0A
              db '------------------', 0x0D, 0x0A, 0
mem_conventional_msg db 'Conventional Memory: ', 0
mem_extended_msg db 'Extended Memory: ', 0
mem_free_msg db 'Free Memory (estimated): ', 0
percent_msg db '%', 0x0D, 0x0A, 0
mem_detected_msg db 'Total Detected Memory: ', 0
mem_kb_msg db ' KB', 0x0D, 0x0A, 0
mem_map_msg db 'Memory Map:', 0x0D, 0x0A
           db '  0000h - 09FFh: Real Mode Interrupt Vector Table', 0x0D, 0x0A
           db '  0A00h - 7BFFh: Available Conventional Memory', 0x0D, 0x0A
           db '  7C00h - 7DFFh: Boot Sector', 0x0D, 0x0A
           db '  7E00h - 9FFFh: Available Conventional Memory', 0x0D, 0x0A
           db '  A000h - FFFFh: Reserved for Video Memory and ROM BIOS', 0x0D, 0x0A, 0
mem_kernel_msg db '  10000h - 17FFFh: NoX-OS Kernel', 0x0D, 0x0A, 0
mem_usage_msg db 'Memory Usage Details:', 0x0D, 0x0A
           db '  OS Core: ~64 KB', 0x0D, 0x0A
           db '  Available for Applications: Varies by system', 0x0D, 0x0A, 0
           
; Advanced memory management messages
memadv_header_msg db 'NoX-OS Advanced Memory Management', 0x0D, 0x0A
                 db '-------------------------------', 0x0D, 0x0A, 0
memadv_usage_msg db 'Usage: MEMADV [STATS|ALLOC size|FREE addr|COMPACT]', 0x0D, 0x0A, 0
memadv_stats_msg db 'Memory Statistics:', 0x0D, 0x0A, 0
memadv_total_msg db 'Total memory: ', 0
memadv_free_msg db 'Free memory: ', 0
memadv_used_msg db 'Used memory: ', 0
memadv_largest_msg db 'Largest free block: ', 0
memadv_blocks_msg db 'Memory blocks: ', 0
memadv_alloc_msg db 'Memory allocated at address: ', 0
memadv_free_done_msg db 'Memory successfully freed', 0x0D, 0x0A, 0
memadv_compact_msg db 'Memory compaction complete. Blocks compacted: ', 0
memadv_error_msg db 'Error: ', 0
memadv_err_notinit_msg db 'Memory system not initialized', 0x0D, 0x0A, 0
memadv_err_outofmem_msg db 'Out of memory', 0x0D, 0x0A, 0
memadv_err_badptr_msg db 'Invalid pointer or memory block', 0x0D, 0x0A, 0
memadv_err_corrupt_msg db 'Memory corruption detected', 0x0D, 0x0A, 0
memadv_err_badcmd_msg db 'Invalid command', 0x0D, 0x0A, 0
memadv_err_badparam_msg db 'Invalid parameter', 0x0D, 0x0A, 0

; Command strings for advanced memory management
stats_cmd db 'STATS', 0
on_cmd db 'ON', 0
off_cmd db 'OFF', 0

; Memory analysis variables
mem_total_kb dw 0
mem_extended_kb dw 0
mem_largest_region dd 0
mem_buffer: times 256 db 0  ; Buffer for storing memory map information

; FIND command data
find_pattern_buffer: times MAX_PATH_LEN db 0
find_matches dw 0

; Taskbar messages
taskbar_usage_msg db 'Usage: TASKBAR [ON|OFF]', 0x0D, 0x0A
                 db 'Shows or hides the system taskbar', 0x0D, 0x0A, 0
taskbar_enabled_msg db 'Taskbar is now enabled', 0x0D, 0x0A, 0
taskbar_disabled_msg db 'Taskbar is now disabled', 0x0D, 0x0A, 0
taskbar_status_msg db 'Taskbar is currently ', 0
taskbar_on_msg db 'ON', 0x0D, 0x0A, 0
taskbar_off_msg db 'OFF', 0x0D, 0x0A, 0

; Window command messages
window_usage_msg db 'Usage: WINDOW CREATE <width> <height> <title>', 0x0D, 0x0A
                db '       WINDOW CLOSE <id>', 0x0D, 0x0A
                db '       WINDOW LIST', 0x0D, 0x0A
                db '       WINDOW WRITE <id> <text>', 0x0D, 0x0A, 0
                
; Task command messages
task_usage_msg db 'Usage: TASK LIST', 0x0D, 0x0A
              db '       TASK CREATE <name> <entry_point>', 0x0D, 0x0A
              db '       TASK KILL <id>', 0x0D, 0x0A
              db '       TASK ENABLE', 0x0D, 0x0A  
              db '       TASK DISABLE', 0x0D, 0x0A, 0
task_list_header_msg db 'Active Tasks:', 0x0D, 0x0A
                    db 'ID  State     Name', 0x0D, 0x0A
                    db '--------------------------', 0x0D, 0x0A, 0
task_no_tasks_msg db 'No active tasks', 0x0D, 0x0A, 0
task_created_msg db 'Task created with ID: ', 0
task_killed_msg db 'Task terminated', 0x0D, 0x0A, 0
task_not_found_msg db 'Task not found', 0x0D, 0x0A, 0
task_failed_msg db 'Failed to create task', 0x0D, 0x0A, 0
task_enabled_msg db 'Multitasking enabled', 0x0D, 0x0A, 0
task_disabled_msg db 'Multitasking disabled', 0x0D, 0x0A, 0
task_create_cmd db 'CREATE', 0
task_kill_cmd db 'KILL', 0
task_list_cmd db 'LIST', 0
task_enable_cmd db 'ENABLE', 0
task_disable_cmd db 'DISABLE', 0
task_free_state_msg db 'Free     ', 0
task_ready_state_msg db 'Ready    ', 0
task_running_state_msg db 'Running  ', 0
task_waiting_state_msg db 'Waiting  ', 0
task_suspended_state_msg db 'Suspended', 0
task_unknown_state_msg db 'Unknown  ', 0
task_placeholder_msg db 'Task creation feature not fully implemented in this version.', 0x0D, 0x0A, 0

; Mouse command messages
mouse_usage_msg db 'Usage: MOUSE [SHOW|HIDE|STATUS]', 0x0D, 0x0A, 0
mouse_show_msg db 'Mouse cursor enabled', 0x0D, 0x0A, 0
mouse_hide_msg db 'Mouse cursor disabled', 0x0D, 0x0A, 0
mouse_status_msg db 'Mouse status:', 0x0D, 0x0A, 0
mouse_installed_msg db 'Mouse driver installed: ', 0
mouse_position_msg db 'Current position: X=', 0
mouse_y_pos_msg db ', Y=', 0
mouse_buttons_msg db 'Button state: ', 0
mouse_left_msg db 'Left ', 0
mouse_right_msg db 'Right ', 0
mouse_middle_msg db 'Middle', 0
mouse_none_msg db 'None pressed', 0
mouse_not_installed_msg db 'Mouse driver not installed or not available', 0x0D, 0x0A, 0
mouse_show_cmd db 'SHOW', 0
mouse_hide_cmd db 'HIDE', 0
mouse_status_cmd db 'STATUS', 0
window_created_msg db 'Window created with ID: ', 0
window_closed_msg db 'Window closed', 0x0D, 0x0A, 0
window_list_header_msg db 'Active Windows:', 0x0D, 0x0A
                      db 'ID    Size    Title', 0x0D, 0x0A
                      db '--------------------------', 0x0D, 0x0A, 0
window_no_windows_msg db 'No active windows', 0x0D, 0x0A, 0
window_not_found_msg db 'Window not found', 0x0D, 0x0A, 0
window_failed_msg db 'Failed to create window', 0x0D, 0x0A, 0
window_create_cmd db 'CREATE', 0
window_close_cmd db 'CLOSE', 0
window_list_cmd db 'LIST', 0
window_write_cmd db 'WRITE', 0
find_searching_msg db 'Searching for: ', 0
find_complete_msg db 'Search complete. Found ', 0
find_files_msg db ' file(s)', 0x0D, 0x0A, 0
find_size_msg db ' (Size: ', 0
find_bytes_msg db ' bytes)', 0x0D, 0x0A, 0
find_syntax_msg db 'Syntax: FIND <pattern>', 0x0D, 0x0A, 0
find_placeholder_msg db 'Search functionality will be fully implemented in next version.', 0x0D, 0x0A, 0
parent_dir_str db '..', 0
disk_error_msg db 'Disk error or file not found', 0x0D, 0x0A, 0

; MENU command data
menu_header_msg db 0x0D, 0x0A, '=== NoX-OS Command Menu ===', 0x0D, 0x0A, 0
menu_footer_msg db 0x0D, 0x0A, 'Press a number to select, or ESC to exit menu', 0x0D, 0x0A, 0
menu_option_1 db '1. File Management', 0x0D, 0x0A, 0
menu_option_2 db '2. System Information', 0x0D, 0x0A, 0
menu_option_3 db '3. Disk Utilities', 0x0D, 0x0A, 0
menu_option_4 db '4. Print Services', 0x0D, 0x0A, 0
menu_option_5 db '5. Text Editor', 0x0D, 0x0A, 0
menu_option_e db 'E. Exit Menu', 0x0D, 0x0A, 0

; File management submenu
file_menu_header db 0x0D, 0x0A, '--- File Management ---', 0x0D, 0x0A, 0
file_menu_1 db '1. Directory Listing (DIR)', 0x0D, 0x0A, 0
file_menu_2 db '2. Copy Files (COPY)', 0x0D, 0x0A, 0
file_menu_3 db '3. Delete Files (DEL)', 0x0D, 0x0A, 0
file_menu_4 db '4. View File (TYPE)', 0x0D, 0x0A, 0
file_menu_5 db '5. Find Files (FIND)', 0x0D, 0x0A, 0
file_menu_e db 'E. Return to Main Menu', 0x0D, 0x0A, 0

; Printer services submenu
print_menu_header db 0x0D, 0x0A, '--- Print Services ---', 0x0D, 0x0A, 0
print_menu_1 db '1. Print File', 0x0D, 0x0A, 0
print_menu_2 db '2. Check Printer Status', 0x0D, 0x0A, 0
print_menu_3 db '3. Cancel Print Jobs', 0x0D, 0x0A, 0
print_menu_e db 'E. Return to Main Menu', 0x0D, 0x0A, 0

; PRINT command data
print_header_msg db 'NoX-OS Print Service', 0x0D, 0x0A
                 db '-------------------', 0x0D, 0x0A, 0
print_usage_msg db 'Usage: PRINT [filename]', 0x0D, 0x0A, 0
print_status_msg db 'Checking printer status...', 0x0D, 0x0A, 0
print_sending_msg db 'Sending file to printer: ', 0
print_success_msg db 'File sent to printer successfully.', 0x0D, 0x0A, 0
print_error_msg db 'Error: Unable to print file.', 0x0D, 0x0A, 0
print_not_found_msg db 'Error: File not found.', 0x0D, 0x0A, 0
print_cancel_msg db 'Print job(s) canceled.', 0x0D, 0x0A, 0

; FORMAT command data
format_header_msg db 'NoX-OS Disk Formatting Utility', 0x0D, 0x0A
                  db '-----------------------------', 0x0D, 0x0A, 0
format_confirm_msg db 'WARNING: Formatting will erase all data on the disk.', 0x0D, 0x0A
                   db 'Are you sure you want to continue? (Y/N): ', 0
format_progress_msg db 'Formatting disk... ', 0
format_complete_msg db 'Format complete!', 0x0D, 0x0A, 0
format_error_msg db 'Error: Format failed.', 0x0D, 0x0A, 0
format_cancelled_msg db 'Format cancelled.', 0x0D, 0x0A, 0

; SYS command data
sys_header_msg db 0x0D, 0x0A, 'System Information:', 0x0D, 0x0A
              db '------------------', 0x0D, 0x0A, 0
sys_bios_date_msg db 'BIOS Date: ', 0
sys_equipment_msg db 'Equipment: ', 0
sys_floppy_msg db 'Floppy Drive, ', 0
sys_math_msg db 'Math Coprocessor, ', 0
sys_video_msg db 'Video: ', 0
sys_video_0_msg db 'CGA (40x25)', 0x0D, 0x0A, 0
sys_video_1_msg db 'CGA (80x25)', 0x0D, 0x0A, 0
sys_video_2_msg db 'MDA (80x25)', 0x0D, 0x0A, 0
sys_video_other_msg db 'Other/Unknown', 0x0D, 0x0A, 0
sys_keyboard_msg db 'Keyboard: ', 0
sys_scroll_msg db 'SCROLL-LOCK, ', 0
sys_num_msg db 'NUM-LOCK, ', 0
sys_caps_msg db 'CAPS-LOCK, ', 0
press_key_msg db 'Press any key to continue...', 0

;------------------------------------------------------------------
; Function: cmd_find
; Searches for files matching a pattern (simplified version)
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_find:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Skip "FIND" command
    call cmd_skip_token
    
    ; Skip whitespace
    call cmd_skip_whitespace
    
    ; Check if a pattern was provided
    cmp byte [si], 0
    je .syntax_error
    
    ; Store the pattern
    mov di, find_pattern_buffer
    mov cx, MAX_PATH_LEN
    
.copy_pattern:
    mov al, [si]
    test al, al        ; Check for end of string
    jz .end_pattern
    cmp al, ' '        ; Check for space (end of pattern)
    je .end_pattern
    
    ; Copy the character
    mov [di], al
    inc si
    inc di
    
    ; Decrement counter and check if we've exceeded the buffer size
    dec cx
    jz .end_pattern
    
    jmp .copy_pattern
    
.end_pattern:
    ; Null-terminate the pattern
    mov byte [di], 0
    
    ; Reset match counter
    mov word [find_matches], 0
    
    ; Display search header
    mov si, find_searching_msg
    call print_string
    
    mov si, find_pattern_buffer
    call print_string
    call print_newline
    
    mov si, find_placeholder_msg
    call print_string
    
    ; Display completion message
    mov si, find_complete_msg
    call print_string
    
    ; Just display 0 for now until we implement the full search
    mov ax, 0
    call cmd_print_dec
    
    mov si, find_files_msg
    call print_string
    
    jmp .done
    
.syntax_error:
    mov si, find_syntax_msg
    call print_string
    jmp .done
    
.error:
    mov si, disk_error_msg
    call print_string
    
.done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: match_pattern
; Simplified placeholder for pattern matching (will be enhanced later)
; Input: DS:SI = filename, DS:DI = pattern
; Output: Carry flag set if match, clear if no match
;------------------------------------------------------------------
match_pattern:
    push ax
    
    ; Always return no match for now
    clc
    
    pop ax
    ret

;------------------------------------------------------------------
; Function: cmd_menu
; Displays and handles the user-friendly menu interface
;------------------------------------------------------------------
cmd_menu:
    push ax
    push bx
    push cx
    push dx
    
    ; Clear the screen
    call clear_screen
    
    ; Display main menu
    mov si, menu_header_msg
    call print_string
    
    ; Display menu options
    mov si, menu_option_1
    call print_string
    mov si, menu_option_2
    call print_string
    mov si, menu_option_3
    call print_string
    mov si, menu_option_4
    call print_string
    mov si, menu_option_5
    call print_string
    mov si, menu_option_e
    call print_string
    
    ; Display footer
    mov si, menu_footer_msg
    call print_string
    
    ; Get user selection
    mov si, press_key_msg
    call print_string
    
    ; Wait for user to press a key
    mov ah, 0
    int 0x16
    
    call print_newline
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: cmd_print
; Prints a file on a printer
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_print:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Display print service header
    mov si, print_header_msg
    call print_string
    
    ; Skip "PRINT" command
    call cmd_skip_token
    
    ; Skip whitespace
    call cmd_skip_whitespace
    
    ; Check if a filename was provided
    cmp byte [si], 0
    je .show_usage
    
    ; Display printing message
    mov si, print_sending_msg
    call print_string
    
    ; Display filename (actually we'd process the file here)
    call print_string
    call print_newline
    
    ; Show success message
    mov si, print_success_msg
    call print_string
    
    jmp .done
    
.show_usage:
    ; Display usage instructions
    mov si, print_usage_msg
    call print_string
    
.done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: cmd_format
; Formats a disk
;------------------------------------------------------------------
cmd_format:
    push ax
    push bx
    push cx
    push dx
    
    ; Display format utility header
    mov si, format_header_msg
    call print_string
    
    ; In the real implementation, we would prompt for confirmation
    ; and actually perform the disk format operation
    
    ; Display progress message
    mov si, format_progress_msg
    call print_string
    
    ; Display complete message
    mov si, format_complete_msg
    call print_string
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: check_printer_status
; Checks the status of the printer
;------------------------------------------------------------------
check_printer_status:
    push ax
    push dx
    
    ; Display status message
    mov si, print_status_msg
    call print_string
    
    ; Check printer status using port 0x379 (LPT1 status port)
    mov dx, 0x379
    in al, dx
    
    ; Bit 7 = ~Busy
    test al, 0x80
    jz .printer_busy
    
    ; Bit 5 = Out of paper
    test al, 0x20
    jnz .out_of_paper
    
    ; Bit 3 = Error
    test al, 0x08
    jnz .printer_error
    
    ; Bit 4 = Selected
    test al, 0x10
    jz .not_selected
    
    ; Everything looks good
    mov si, print_success_msg
    call print_string
    jmp .done
    
.printer_busy:
    mov si, print_error_msg
    call print_string
    jmp .done
    
.out_of_paper:
    mov si, print_error_msg
    call print_string
    jmp .done
    
.printer_error:
    mov si, print_error_msg
    call print_string
    jmp .done
    
.not_selected:
    mov si, print_error_msg
    call print_string
    
.done:
    pop dx
    pop ax
    ret

;------------------------------------------------------------------
; Function: cancel_print_jobs
; Cancels all pending print jobs
;------------------------------------------------------------------
cancel_print_jobs:
    push ax
    
    ; Just display the cancel message
    mov si, print_cancel_msg
    call print_string
    
    pop ax
    ret

;------------------------------------------------------------------
; Function: cmd_wait_for_key
; Waits for a key press and displays a prompt
;------------------------------------------------------------------
cmd_wait_for_key:
    push ax
    
    ; Display prompt
    mov si, press_key_msg
    call print_string
    
    ; Wait for a keypress
    mov ah, 0
    int 0x16
    
    ; Clear the line
    call print_newline
    
    pop ax
    ret
    
;------------------------------------------------------------------
; Function: cmd_memadv
; Provides advanced memory management tools
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_memadv:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Display header
    mov si, memadv_header_msg
    call print_string
    
    ; Skip "MEMADV" command
    call cmd_skip_token
    
    ; Skip whitespace
    call cmd_skip_whitespace
    
    ; Check if a subcommand was provided
    cmp byte [si], 0
    je .show_usage
    
    ; Compare first subcommand
    mov di, si                  ; Save current position for comparison
    
    ; Check for "STATS" subcommand
    mov si, stats_cmd
    call strcmp_nocase
    jc .stats_command
    
    ; Check for "ALLOC" subcommand
    mov si, di                  ; Restore position
    mov cx, 5                   ; Length of "ALLOC"
    call strncmp_upper
    jc .alloc_command
    
    ; Check for "FREE" subcommand
    mov si, di                  ; Restore position
    mov cx, 4                   ; Length of "FREE"
    call strncmp_upper
    jc .free_command
    
    ; Check for "COMPACT" subcommand
    mov si, di                  ; Restore position
    mov cx, 7                   ; Length of "COMPACT"
    call strncmp_upper
    jc .compact_command
    
    ; Unknown subcommand
    mov si, memadv_err_badcmd_msg
    call print_string
    jmp .done
    
.show_usage:
    ; Display usage information
    mov si, memadv_usage_msg
    call print_string
    jmp .done
    
.stats_command:
    ; Display memory statistics
    call mem_get_stats
    
    ; Display total memory
    call print_newline
    mov si, memadv_stats_msg
    call print_string
    
    ; Total memory
    push ax                     ; Save total memory
    mov si, memadv_total_msg
    call print_string
    pop ax                      ; Restore total memory
    call cmd_print_dec
    mov si, mem_kb_msg
    call print_string
    
    ; Free memory
    push bx                     ; Save free memory
    mov si, memadv_free_msg
    call print_string
    pop ax                      ; Restore free memory to AX
    call cmd_print_dec
    mov si, mem_kb_msg
    call print_string
    
    ; Used memory
    push cx                     ; Save used memory
    mov si, memadv_used_msg
    call print_string
    pop ax                      ; Restore used memory to AX
    call cmd_print_dec
    mov si, mem_kb_msg
    call print_string
    
    ; Largest free block
    push dx                     ; Save largest free block
    mov si, memadv_largest_msg
    call print_string
    pop ax                      ; Restore largest free block to AX
    call cmd_print_dec
    mov si, mem_kb_msg
    call print_string
    
    jmp .done
    
.alloc_command:
    ; Skip "ALLOC" token
    mov si, di
    add si, 5                   ; Length of "ALLOC"
    call cmd_skip_whitespace
    
    ; Check if size parameter was provided
    cmp byte [si], 0
    je .alloc_error
    
    ; Convert size parameter to number
    call parse_number
    jc .alloc_error
    
    ; Size in AX, allocate memory
    mov bx, ax                  ; BX = size to allocate
    call mem_alloc
    jc .alloc_mem_error
    
    ; Display success message
    mov si, memadv_alloc_msg
    call print_string
    call cmd_print_hex
    call print_newline
    
    jmp .done
    
.alloc_error:
    mov si, memadv_err_badparam_msg
    call print_string
    jmp .done
    
.alloc_mem_error:
    mov si, memadv_error_msg
    call print_string
    
    ; Check error code
    call mem_get_last_error
    cmp al, MEM_ERR_OUT_OF_MEM
    je .out_of_mem_error
    
    ; Default error message
    mov si, memadv_err_corrupt_msg
    call print_string
    jmp .done
    
.out_of_mem_error:
    mov si, memadv_err_outofmem_msg
    call print_string
    jmp .done
    
.free_command:
    ; Skip "FREE" token
    mov si, di
    add si, 4                   ; Length of "FREE"
    call cmd_skip_whitespace
    
    ; Check if address parameter was provided
    cmp byte [si], 0
    je .free_error
    
    ; Convert address parameter to number
    call parse_number
    jc .free_error
    
    ; Address in AX, free memory
    call mem_free
    jc .free_mem_error
    
    ; Display success message
    mov si, memadv_free_done_msg
    call print_string
    
    jmp .done
    
.free_error:
    mov si, memadv_err_badparam_msg
    call print_string
    jmp .done
    
.free_mem_error:
    mov si, memadv_error_msg
    call print_string
    
    ; Check error code
    call mem_get_last_error
    cmp al, MEM_ERR_INVALID_PTR
    je .bad_ptr_error
    
    ; Default error message
    mov si, memadv_err_corrupt_msg
    call print_string
    jmp .done
    
.bad_ptr_error:
    mov si, memadv_err_badptr_msg
    call print_string
    jmp .done
    
.compact_command:
    ; Perform memory compaction
    call mem_compaction
    
    ; Display compaction results
    mov si, memadv_compact_msg
    call print_string
    call cmd_print_dec
    call print_newline
    
    jmp .done
    
.done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: strncmp_upper
; Compares SI with DI for CX characters (case insensitive)
; Input: SI, DI = strings to compare, CX = max characters
; Output: CF set if strings match
;------------------------------------------------------------------
strncmp_upper:
    push ax
    push si
    push di
    push cx
    
.loop:
    ; Check if we've reached the count
    test cx, cx
    jz .match
    
    ; Load characters from both strings
    mov al, [si]
    mov ah, [di]
    
    ; Convert both to uppercase
    call cmd_to_uppercase
    mov bl, al                  ; Save uppercase version of [si]
    
    mov al, ah                  ; Move [di] to AL
    call cmd_to_uppercase
    
    ; Compare uppercase characters
    cmp bl, al
    jne .no_match
    
    ; Check for end of string
    test al, al
    jz .match
    
    ; Move to next character
    inc si
    inc di
    dec cx
    jmp .loop
    
.match:
    stc                         ; Set carry flag (strings match)
    jmp .done
    
.no_match:
    clc                         ; Clear carry flag (strings different)
    
.done:
    pop cx
    pop di
    pop si
    pop ax
    ret

;------------------------------------------------------------------
; Function: strcmp_nocase
; Compares strings at SI and DI (case insensitive)
; Input: SI, DI = strings to compare
; Output: CF set if strings match
;------------------------------------------------------------------
strcmp_nocase:
    push ax
    push bx
    push si
    push di
    
.loop:
    ; Load characters from both strings
    mov al, [si]
    mov ah, [di]
    
    ; Convert both to uppercase
    call cmd_to_uppercase
    mov bl, al                  ; Save uppercase version of [si]
    
    mov al, ah                  ; Move [di] to AL
    call cmd_to_uppercase
    
    ; Compare uppercase characters
    cmp bl, al
    jne .no_match
    
    ; Check for end of string
    test al, al
    jz .match
    
    ; Move to next character
    inc si
    inc di
    jmp .loop
    
.match:
    stc                         ; Set carry flag (strings match)
    jmp .done
    
.no_match:
    clc                         ; Clear carry flag (strings different)
    
.done:
    pop di
    pop si
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: parse_number
; Parses a decimal or hex number from string
; Input: SI = string containing number
; Output: AX = parsed number, CF set on error
;------------------------------------------------------------------
parse_number:
    push bx
    push cx
    push dx
    push si
    
    ; Skip leading whitespace
    call cmd_skip_whitespace
    
    ; Check for hex prefix (0x or 0X)
    mov al, [si]
    cmp al, '0'
    jne .parse_decimal
    
    mov al, [si+1]
    cmp al, 'x'
    je .parse_hex
    cmp al, 'X'
    je .parse_hex
    
.parse_decimal:
    xor ax, ax                  ; Start with 0
    xor cx, cx                  ; Digit counter
    
.dec_loop:
    mov bl, [si]                ; Get current character
    
    ; Check for end of string or non-digit
    cmp bl, 0
    je .dec_done
    cmp bl, ' '
    je .dec_done
    
    ; Check if it's a digit
    cmp bl, '0'
    jb .error
    cmp bl, '9'
    ja .error
    
    ; Convert character to digit
    sub bl, '0'
    
    ; Multiply current result by 10
    mov dx, 10
    mul dx
    
    ; Check for overflow
    jc .error
    
    ; Add new digit
    xor bh, bh
    add ax, bx
    jc .error                   ; Check for overflow
    
    ; Move to next character
    inc si
    inc cx
    jmp .dec_loop
    
.dec_done:
    ; Make sure we had at least one digit
    test cx, cx
    jz .error
    
    ; Success - number in AX
    clc
    jmp .done
    
.parse_hex:
    add si, 2                   ; Skip "0x" prefix
    xor ax, ax                  ; Start with 0
    xor cx, cx                  ; Digit counter
    
.hex_loop:
    mov bl, [si]                ; Get current character
    
    ; Check for end of string or non-hex
    cmp bl, 0
    je .hex_done
    cmp bl, ' '
    je .hex_done
    
    ; Check if it's a digit
    cmp bl, '0'
    jb .error
    cmp bl, '9'
    jbe .hex_digit
    
    ; Check if it's A-F
    cmp bl, 'A'
    jb .error
    cmp bl, 'F'
    jbe .hex_upper
    
    ; Check if it's a-f
    cmp bl, 'a'
    jb .error
    cmp bl, 'f'
    ja .error
    
    ; Convert a-f to value
    sub bl, 'a' - 10
    jmp .hex_convert
    
.hex_upper:
    ; Convert A-F to value
    sub bl, 'A' - 10
    jmp .hex_convert
    
.hex_digit:
    ; Convert 0-9 to value
    sub bl, '0'
    
.hex_convert:
    ; Shift current result left by 4 bits
    shl ax, 4
    
    ; Check for overflow
    jc .error
    
    ; Add new digit
    xor bh, bh
    add ax, bx
    jc .error                   ; Check for overflow
    
    ; Move to next character
    inc si
    inc cx
    jmp .hex_loop
    
.hex_done:
    ; Make sure we had at least one digit
    test cx, cx
    jz .error
    
    ; Success - number in AX
    clc
    jmp .done
    
.error:
    stc                         ; Set carry flag (error)
    
.done:
    pop si
    pop dx
    pop cx
    pop bx
    ret

;------------------------------------------------------------------
; Function: cmd_print_hex
; Prints a hexadecimal number
; Input: AX = number to print
;------------------------------------------------------------------
cmd_print_hex:
    push ax
    push bx
    push cx
    push dx
    
    mov cx, 4                   ; 4 digits for 16-bit number
    mov bx, ax                  ; Save value
    
    ; Print "0x" prefix
    mov al, '0'
    call print_char
    mov al, 'x'
    call print_char
    
.print_loop:
    ; Get the next digit
    mov ax, bx
    mov dx, cx
    dec dx
    shl dx, 2                   ; Multiply by 4 to get bit shift
    shr ax, cl                  ; Shift right to isolate digit
    and ax, 0x000F              ; Mask off other digits
    
    ; Convert to ASCII
    cmp al, 10
    jb .decimal_digit
    add al, 'A' - 10            ; A-F
    jmp .print_digit
    
.decimal_digit:
    add al, '0'                 ; 0-9
    
.print_digit:
    call print_char
    
    ; Loop for next digit
    loop .print_loop
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: cmd_sys
; Displays system information
;------------------------------------------------------------------
cmd_sys:
    push ax
    push bx
    push cx
    push dx
    
    ; Display version information
    call cmd_ver
    
    ; Display system information header
    mov si, sys_header_msg
    call print_string
    
    ; Get and display BIOS date
    mov si, sys_bios_date_msg
    call print_string
    
    ; BIOS date is typically at F000:FFF5
    mov ax, 0xF000
    mov es, ax
    mov si, 0xFFF5
    
    ; Display BIOS date string (ends with null or non-printable)
.bios_date_loop:
    mov al, byte [es:si]
    
    ; Check for end conditions
    cmp al, 0
    je .bios_date_done
    cmp al, 32               ; Space or higher is printable
    jb .bios_date_done
    
    ; Print the character
    call print_char
    inc si
    jmp .bios_date_loop
    
.bios_date_done:
    call print_newline
    
    ; Get and display equipment list
    mov si, sys_equipment_msg
    call print_string
    
    ; Get equipment list
    int 0x11                  ; Returns equipment list in AX
    
    ; Display individual equipment items
    test ax, 0x0001
    jz .no_floppy
    mov si, sys_floppy_msg
    call print_string
.no_floppy:
    
    call print_newline
    
    ; Display keyboard type
    mov si, sys_keyboard_msg
    call print_string
    
    ; Get keyboard status flags
    mov ah, 0x02
    int 0x16
    
    ; Display keyboard status
    test al, 0x10             ; Scroll Lock
    jz .no_scroll
    mov si, sys_scroll_msg
    call print_string
.no_scroll:
    
    test al, 0x20             ; Num Lock
    jz .no_num
    mov si, sys_num_msg
    call print_string
.no_num:
    
    test al, 0x40             ; Caps Lock
    jz .no_caps
    mov si, sys_caps_msg
    call print_string
.no_caps:
    
    call print_newline
    
    ; Call MEM command to show memory information too
    call cmd_mem
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret;------------------------------------------------------------------
; Function: cmd_taskbar
; Controls the visibility of the taskbar
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_taskbar:
    push si
    push di
    push ax
    push bx
    
    ; Skip "TASKBAR" command
    call cmd_skip_token
    
    ; Skip whitespace
    call cmd_skip_whitespace
    
    ; Check if a parameter was provided
    cmp byte [si], 0
    je .show_status
    
    ; Check for ON/OFF parameter
    mov di, si
    
    ; Check for "ON" parameter
    mov si, on_cmd
    call strcmp_nocase
    jc .enable_taskbar
    
    ; Check for "OFF" parameter
    mov si, di                ; Restore position
    mov si, off_cmd
    call strcmp_nocase
    jc .disable_taskbar
    
    ; Invalid parameter
    mov si, taskbar_usage_msg
    call print_string
    jmp .done
    
.show_status:
    ; Display current taskbar status
    mov si, taskbar_status_msg
    call print_string
    
    ; Check current status
    mov al, [taskbar_enabled]
    test al, al
    jz .show_disabled
    
    ; Taskbar is enabled
    mov si, taskbar_on_msg
    call print_string
    jmp .done
    
.show_disabled:
    ; Taskbar is disabled
    mov si, taskbar_off_msg
    call print_string
    jmp .done
    
.enable_taskbar:
    ; Enable the taskbar
    mov byte [taskbar_enabled], 1
    call taskbar_show
    
    ; Display confirmation
    mov si, taskbar_enabled_msg
    call print_string
    jmp .done
    
.disable_taskbar:
    ; Disable the taskbar
    mov byte [taskbar_enabled], 0
    call taskbar_hide
    
    ; Display confirmation
    mov si, taskbar_disabled_msg
    call print_string
    
.done:
    pop bx
    pop ax
    pop di
    pop si
    ret;------------------------------------------------------------------
; Function: cmd_window
; Handles window-related commands
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_window:
    push si
    push di
    push ax
    push bx
    push cx
    push dx
    
    ; Skip "WINDOW" command
    call cmd_skip_token
    
    ; Skip whitespace
    call cmd_skip_whitespace
    
    ; Check if a subcommand was provided
    cmp byte [si], 0
    je .show_usage
    
    ; Check which subcommand
    mov di, si                  ; Save SI for subcommand comparison
    
    ; Check for CREATE subcommand
    mov si, window_create_cmd
    call strcmp_nocase
    jc .create_window
    
    ; Check for CLOSE subcommand
    mov si, window_close_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .close_window
    
    ; Check for LIST subcommand
    mov si, window_list_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .list_windows
    
    ; Check for WRITE subcommand
    mov si, window_write_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .write_window
    
    ; Unknown subcommand
.show_usage:
    mov si, window_usage_msg
    call print_string
    jmp .done
    
.create_window:
    ; Move SI past the CREATE token
    mov si, di
    call cmd_skip_token
    call cmd_skip_whitespace
    
    ; Parse width parameter
    cmp byte [si], 0
    je .show_usage
    call parse_number
    jc .show_usage
    mov bl, al                   ; Width in BL
    
    ; Skip to height parameter
    call cmd_skip_token
    call cmd_skip_whitespace
    
    ; Parse height parameter
    cmp byte [si], 0
    je .show_usage
    call parse_number
    jc .show_usage
    mov bh, al                   ; Height in BH
    
    ; Skip to title parameter
    call cmd_skip_token
    call cmd_skip_whitespace
    
    ; Check if title was provided
    cmp byte [si], 0
    je .show_usage
    
    ; Create window
    ; Calculate position (for simplicity, use fixed position for now)
    mov al, 5                    ; X position
    mov ah, 5                    ; Y position
    ; BL, BH already contain width and height
    ; SI already points to the title
    call window_create
    
    ; Check if creation was successful
    test al, al
    jz .create_failed
    
    ; Display success message
    mov si, window_created_msg
    call print_string
    
    movzx ax, al                 ; Window ID
    call cmd_print_dec
    call print_newline
    
    jmp .done
    
.create_failed:
    mov si, window_failed_msg
    call print_string
    jmp .done
    
.close_window:
    ; Move SI past the CLOSE token
    mov si, di
    call cmd_skip_token
    call cmd_skip_whitespace
    
    ; Parse window ID parameter
    cmp byte [si], 0
    je .show_usage
    call parse_number
    jc .show_usage
    
    ; Close window
    ; AL already contains window ID
    call window_close
    
    ; Display success message
    mov si, window_closed_msg
    call print_string
    
    jmp .done
    
.list_windows:
    ; Display header
    mov si, window_list_header_msg
    call print_string
    
    ; Check if there are any windows
    cmp byte [window_count], 0
    je .no_windows
    
    ; Display window information
    mov si, window_table
    mov cx, MAX_WINDOWS
    
.list_loop:
    ; Check if window slot is active
    cmp byte [si + WINDOW.id], 0
    je .next_window
    
    ; Display window ID
    movzx ax, byte [si + WINDOW.id]
    call cmd_print_dec
    
    ; Add spacing
    mov al, ' '
    call print_char
    call print_char
    call print_char
    call print_char
    
    ; Display window size
    movzx ax, byte [si + WINDOW.width]
    call cmd_print_dec
    
    mov al, 'x'
    call print_char
    
    movzx ax, byte [si + WINDOW.height]
    call cmd_print_dec
    
    ; Add spacing
    mov al, ' '
    call print_char
    call print_char
    call print_char
    call print_char
    
    ; Display window title
    push si
    add si, WINDOW.title
    call print_string
    pop si
    
    call print_newline
    
.next_window:
    add si, WINDOW_size
    loop .list_loop
    
    jmp .done
    
.no_windows:
    mov si, window_no_windows_msg
    call print_string
    jmp .done
    
.write_window:
    ; Move SI past the WRITE token
    mov si, di
    call cmd_skip_token
    call cmd_skip_whitespace
    
    ; Parse window ID parameter
    cmp byte [si], 0
    je .show_usage
    call parse_number
    jc .show_usage
    
    ; Save window ID
    push ax
    
    ; Skip to text
    call cmd_skip_token
    call cmd_skip_whitespace
    
    ; Check if text was provided
    cmp byte [si], 0
    je .write_missing_text
    
    ; Write to window
    pop ax                       ; Restore window ID
    mov bl, 1                    ; X position (relative)
    mov bh, 1                    ; Y position (relative)
    ; SI already points to text
    call window_print
    
    jmp .done
    
.write_missing_text:
    pop ax                       ; Clean up stack
    jmp .show_usage
    
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    pop di
    pop si
    ret;------------------------------------------------------------------
; Function: cmd_task
; Handles task-related commands
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_task:
    push si
    push di
    push ax
    push bx
    push cx
    push dx
    
    ; Skip "TASK" command
    call cmd_skip_token
    
    ; Skip whitespace
    call cmd_skip_whitespace
    
    ; Check if a subcommand was provided
    cmp byte [si], 0
    je .show_usage
    
    ; Check which subcommand
    mov di, si                  ; Save SI for subcommand comparison
    
    ; Check for LIST subcommand
    mov si, task_list_cmd
    call strcmp_nocase
    jc .list_tasks
    
    ; Check for CREATE subcommand
    mov si, task_create_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .create_task
    
    ; Check for KILL subcommand
    mov si, task_kill_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .kill_task
    
    ; Check for ENABLE subcommand
    mov si, task_enable_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .enable_multitasking
    
    ; Check for DISABLE subcommand
    mov si, task_disable_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .disable_multitasking
    
    ; Unknown subcommand
.show_usage:
    mov si, task_usage_msg
    call print_string
    jmp .done
    
.list_tasks:
    ; Display header
    mov si, task_list_header_msg
    call print_string
    
    ; Check if there are any tasks
    movzx ax, byte [task_count]
    test ax, ax
    jz .no_tasks
    
    ; Display task information
    mov si, task_table
    mov cx, MAX_TASKS
    
.list_loop:
    ; Check if task slot is active
    cmp byte [si + TASK.id], 0
    je .next_task
    
    ; Display task ID
    movzx ax, byte [si + TASK.id]
    call cmd_print_dec
    
    ; Add spacing
    mov al, ' '
    call print_char
    call print_char
    
    ; Display task state
    movzx ax, byte [si + TASK.state]
    cmp al, TASK_STATE_FREE
    je .state_free
    cmp al, TASK_STATE_READY
    je .state_ready
    cmp al, TASK_STATE_RUNNING
    je .state_running
    cmp al, TASK_STATE_WAITING
    je .state_waiting
    cmp al, TASK_STATE_SUSPENDED
    je .state_suspended
    
    ; Unknown state
    mov si, task_unknown_state_msg
    jmp .print_state
    
.state_free:
    mov si, task_free_state_msg
    jmp .print_state
    
.state_ready:
    mov si, task_ready_state_msg
    jmp .print_state
    
.state_running:
    mov si, task_running_state_msg
    jmp .print_state
    
.state_waiting:
    mov si, task_waiting_state_msg
    jmp .print_state
    
.state_suspended:
    mov si, task_suspended_state_msg
    
.print_state:
    call print_string
    
    ; Add spacing
    mov al, ' '
    call print_char
    call print_char
    
    ; Display task name
    push si
    add si, TASK.name
    call print_string
    pop si
    
    call print_newline
    
.next_task:
    add si, TASK_size
    loop .list_loop
    
    jmp .done
    
.no_tasks:
    mov si, task_no_tasks_msg
    call print_string
    jmp .done
    
.create_task:
    ; For now, just show a placeholder message
    ; In a real implementation, we would parse parameters and create a task
    mov si, task_placeholder_msg
    call print_string
    jmp .done
    
.kill_task:
    ; Move SI past the KILL token
    mov si, di
    call cmd_skip_token
    call cmd_skip_whitespace
    
    ; Parse task ID parameter
    cmp byte [si], 0
    je .show_usage
    call parse_number
    jc .show_usage
    
    ; Terminate task
    ; AL already contains task ID
    call task_terminate
    
    ; Display success message
    mov si, task_killed_msg
    call print_string
    
    jmp .done
    
.enable_multitasking:
    ; Enable multitasking
    call task_enable
    
    ; Display confirmation
    mov si, task_enabled_msg
    call print_string
    
    jmp .done
    
.disable_multitasking:
    ; Disable multitasking
    call task_disable
    
    ; Display confirmation
    mov si, task_disabled_msg
    call print_string
    
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    pop di
    pop si
    ret;------------------------------------------------------------------
; Function: cmd_mouse
; Handles mouse-related commands
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_mouse:
    push si
    push di
    push ax
    push bx
    push cx
    
    ; Skip "MOUSE" command
    call cmd_skip_token
    
    ; Skip whitespace
    call cmd_skip_whitespace
    
    ; Check if a subcommand was provided
    cmp byte [si], 0
    je .show_status
    
    ; Check which subcommand
    mov di, si                  ; Save SI for subcommand comparison
    
    ; Check for SHOW subcommand
    mov si, mouse_show_cmd
    call strcmp_nocase
    jc .show_mouse
    
    ; Check for HIDE subcommand
    mov si, mouse_hide_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .hide_mouse
    
    ; Check for STATUS subcommand
    mov si, mouse_status_cmd
    mov si, di                  ; Restore SI
    call strcmp_nocase
    jc .show_status
    
    ; Unknown subcommand
    mov si, mouse_usage_msg
    call print_string
    jmp .done
    
.show_mouse:
    ; Show mouse cursor
    call mouse_show
    
    ; Display confirmation
    mov si, mouse_show_msg
    call print_string
    jmp .done
    
.hide_mouse:
    ; Hide mouse cursor
    call mouse_hide
    
    ; Display confirmation
    mov si, mouse_hide_msg
    call print_string
    jmp .done
    
.show_status:
    ; Display mouse status
    call mouse_is_installed
    test al, al
    jz .not_installed
    
    ; Display status header
    mov si, mouse_status_msg
    call print_string
    
    ; Show if mouse is installed
    mov si, mouse_installed_msg
    call print_string
    mov si, mouse_show_msg      ; "Yes"
    call print_string
    
    ; Display current position
    mov si, mouse_position_msg
    call print_string
    
    ; Show X position
    mov ax, [mouse_x]
    call cmd_print_dec
    
    ; Show Y position
    mov si, mouse_y_pos_msg
    call print_string
    mov ax, [mouse_y]
    call cmd_print_dec
    call print_newline
    
    ; Display button state
    mov si, mouse_buttons_msg
    call print_string
    
    ; Check which buttons are pressed
    mov al, [mouse_buttons]
    test al, al                 ; Check if any buttons pressed
    jz .no_buttons
    
    ; Check left button
    test al, 1
    jz .check_right
    mov si, mouse_left_msg
    call print_string
    
.check_right:
    ; Check right button
    test al, 2
    jz .check_middle
    mov si, mouse_right_msg
    call print_string
    
.check_middle:
    ; Check middle button
    test al, 4
    jz .buttons_done
    mov si, mouse_middle_msg
    call print_string
    
.buttons_done:
    call print_newline
    jmp .done
    
.no_buttons:
    mov si, mouse_none_msg
    call print_string
    call print_newline
    jmp .done
    
.not_installed:
    mov si, mouse_not_installed_msg
    call print_string
    
.done:
    pop cx
    pop bx
    pop ax
    pop di
    pop si
    ret