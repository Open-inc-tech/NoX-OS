;==================================================================
; NoX-OS Constants Include File
;==================================================================
; Shared constants used throughout the operating system

;------------------------------------------------------------------
; System Constants
;------------------------------------------------------------------
%define OS_NAME     'NoX-OS'
%define OS_VERSION  '0.3.0'
%define KERNEL_OFFSET 0x0000  ; Offset within the segment for the kernel

;------------------------------------------------------------------
; Memory Layout Constants
;------------------------------------------------------------------
%define BOOT_SEGMENT 0x0000   ; Segment where bootloader runs
%define BOOT_OFFSET  0x7C00   ; Offset where bootloader loads

%define KERNEL_SEGMENT 0x1000 ; Segment where kernel loads
%define KERNEL_OFFSET 0x0000  ; Offset within the segment for the kernel

%define STACK_SEGMENT 0x2000  ; Segment for the stack
%define STACK_SIZE 0x1000     ; Size of the stack (4KB)

; Advanced Memory Management System
%define HEAP_SEGMENT 0x3000       ; Segment for dynamic memory allocation
%define HEAP_SIZE 0x8000          ; Size of the heap (32KB)
%define MAX_MEMORY_BLOCKS 32      ; Maximum number of memory blocks
%define MEMORY_BLOCK_HEADER_SIZE 8 ; Size of memory block header (size + status)

;------------------------------------------------------------------
; Hardware I/O Ports
;------------------------------------------------------------------
%define PIC1_COMMAND 0x20    ; Primary PIC command port
%define PIC1_DATA    0x21    ; Primary PIC data port
%define PIC2_COMMAND 0xA0    ; Secondary PIC command port
%define PIC2_DATA    0xA1    ; Secondary PIC data port

%define KEYBOARD_DATA 0x60   ; Keyboard data port
%define KEYBOARD_STATUS 0x64 ; Keyboard status port

%define RTC_INDEX 0x70      ; Real Time Clock index port
%define RTC_DATA  0x71      ; Real Time Clock data port

;------------------------------------------------------------------
; Disk Constants
;------------------------------------------------------------------
%define DISK_SECTORS_PER_TRACK 18 ; Standard floppy format
%define DISK_HEADS 2              ; Double-sided
%define DISK_CYLINDERS 80         ; 80 tracks

;------------------------------------------------------------------
; ASCII Control Characters
;------------------------------------------------------------------
%define ASCII_NULL 0x00     ; Null character
%define ASCII_SOH  0x01     ; Start of heading
%define ASCII_STX  0x02     ; Start of text
%define ASCII_ETX  0x03     ; End of text
%define ASCII_EOT  0x04     ; End of transmission
%define ASCII_ENQ  0x05     ; Enquiry
%define ASCII_ACK  0x06     ; Acknowledge
%define ASCII_BEL  0x07     ; Bell
%define ASCII_BS   0x08     ; Backspace
%define ASCII_TAB  0x09     ; Horizontal tab
%define ASCII_LF   0x0A     ; Line feed
%define ASCII_VT   0x0B     ; Vertical tab
%define ASCII_FF   0x0C     ; Form feed
%define ASCII_CR   0x0D     ; Carriage return
%define ASCII_SO   0x0E     ; Shift out
%define ASCII_SI   0x0F     ; Shift in
%define ASCII_DLE  0x10     ; Data link escape
%define ASCII_DC1  0x11     ; Device control 1
%define ASCII_DC2  0x12     ; Device control 2
%define ASCII_DC3  0x13     ; Device control 3
%define ASCII_DC4  0x14     ; Device control 4
%define ASCII_NAK  0x15     ; Negative acknowledge
%define ASCII_SYN  0x16     ; Synchronous idle
%define ASCII_ETB  0x17     ; End of transmission block
%define ASCII_CAN  0x18     ; Cancel
%define ASCII_EM   0x19     ; End of medium
%define ASCII_SUB  0x1A     ; Substitute
%define ASCII_ESC  0x1B     ; Escape
%define ASCII_FS   0x1C     ; File separator
%define ASCII_GS   0x1D     ; Group separator
%define ASCII_RS   0x1E     ; Record separator
%define ASCII_US   0x1F     ; Unit separator
%define ASCII_SPACE 0x20    ; Space
%define ASCII_DEL  0x7F     ; Delete
