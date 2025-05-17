
;==================================================================
; NoX-OS System Monitor
;==================================================================

section .data
sysmon_title db "System Monitor", 0
cpu_label db "CPU Usage: ", 0
mem_label db "Memory Usage: ", 0
disk_label db "Disk Space: ", 0
net_label db "Network Status: ", 0

section .text
sysmon_init:
    push ax
    push bx
    
    ; Create system monitor window
    mov al, 50                   ; X position
    mov ah, 2                    ; Y position
    mov bl, 25                   ; Width
    mov bh, 15                   ; Height
    mov si, sysmon_title
    call window_create
    mov [sysmon_window_id], al
    
    pop bx
    pop ax
    ret

update_sysmon:
    push ax
    push bx
    
    ; Update system statistics
    call update_cpu_usage
    call update_memory_usage
    call update_disk_space
    call update_network_status
    
    pop bx
    pop ax
    ret

section .bss
sysmon_window_id resb 1
cpu_usage resb 1
mem_usage resw 1
disk_free resw 1
