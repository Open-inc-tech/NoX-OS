
; Network Stack Implementation
BITS 16

; Network Constants
%define ETH_P_IP    0x0800
%define IPPROTO_TCP 6
%define IPPROTO_UDP 17

section .data
ip_address      db 192, 168, 1, 1
subnet_mask     db 255, 255, 255, 0
gateway_address db 192, 168, 1, 254
dns_server      db 8, 8, 8, 8

section .text
; Initialize network interface
init_network:
    push ax
    push bx
    push cx
    push dx
    
    mov cx, 3              ; Retry counter
    mov byte [network_status], 0  ; Reset status
    
    ; Initialize network buffers
    call init_network_buffers
    
    ; Setup network interrupt handlers
    call setup_network_handlers
    
.retry:
    ; Check for network card presence (using BIOS)
    mov ax, 0x1000
    int 0x2F
    cmp ax, 0
    jne .network_found
    
    loop .retry            ; Retry up to 3 times
    
    ; Network card detection failed
    mov byte [network_status], 0
    jmp .no_network
    
.network_found:
    mov byte [network_status], 1
    
    ; Configure IP settings
    call configure_ip
    call init_tcp_stack
    
    pop bx
    pop ax
    ret

.no_network:
    mov si, no_network_msg
    call print_string
    ret

; Configure IP settings
configure_ip:
    ; Basic DHCP-like configuration
    push ax
    push bx
    
    ; Set IP configuration
    mov si, ip_address
    mov di, current_ip
    mov cx, 4
    rep movsb
    
    pop bx
    pop ax
    ret

; Initialize TCP Stack
init_tcp_stack:
    push ax
    
    ; Initialize TCP ports
    mov word [tcp_ports], 0
    mov byte [tcp_state], 0
    
    pop ax
    ret

section .data
no_network_msg db "No network interface detected", 0
current_ip     times 4 db 0
tcp_ports      times 128 dw 0
tcp_state      db 0
