;==================================================================
; NoX-OS Disk Handling Module
;==================================================================
; Provides low-level disk I/O routines for reading and writing sectors

; Constants
%define MAX_RETRIES 3       ; Maximum number of retries for disk operations
%define SECTORS_PER_TRACK 18 ; Standard floppy format (1.44MB)
%define HEADS_PER_CYLINDER 2 ; Double-sided floppy
%define FLOPPY_DRIVE 0      ; Drive number for floppy A:

; Global variables
current_drive db 0          ; Currently selected drive

;------------------------------------------------------------------
; Function: disk_init
; Initializes the disk subsystem
; Input: DL = default drive number
;------------------------------------------------------------------
disk_init:
    mov [current_drive], dl
    
    ; Reset the disk controller
    call disk_reset
    
    ret

;------------------------------------------------------------------
; Function: disk_reset
; Resets the disk controller
; Input: DL = drive number (0 = floppy A:, 80h = hard disk C:)
; Output: CF set on error, clear on success
;------------------------------------------------------------------
disk_reset:
    push ax                 ; Save registers
    push dx
    
    mov ah, 0x00            ; Reset disk function
    ; DL already contains drive number
    int 0x13                ; Call BIOS disk service
    
    pop dx
    pop ax                  ; Restore registers
    ret

;------------------------------------------------------------------
; Function: read_sectors
; Reads one or more sectors from disk
; Input: 
;   AX = logical sector number to read
;   CL = number of sectors to read (1-128)
;   DL = drive number (0 = floppy A:, 80h = hard disk C:)
;   ES:BX = destination buffer
; Output: 
;   CF set on error, clear on success
;   If error, AH = error code
;------------------------------------------------------------------
read_sectors:
    push ax                 ; Save registers
    push bx
    push cx
    push dx
    push di
    
    mov di, MAX_RETRIES     ; Set retry counter
    
.retry:
    push ax                 ; Save logical sector
    push bx                 ; Save buffer address
    push cx                 ; Save sector count
    
    ; Convert logical sector to CHS (Cylinder/Head/Sector)
    ; For a standard 1.44MB floppy:
    ; Sectors per track = 18
    ; Heads = 2
    ; Cylinders = 80
    
    ; Sector = (LogicalSector % SectorsPerTrack) + 1
    xor dx, dx              ; Clear DX
    mov cx, SECTORS_PER_TRACK
    div cx                  ; AX = LBA / SPT, DX = remainder
    inc dx                  ; Add 1 to remainder (sectors start at 1)
    mov cl, dl              ; CL = sector number
    
    ; Cylinder = (LogicalSector / SectorsPerTrack) / Heads
    xor dx, dx              ; Clear DX
    mov cx, HEADS_PER_CYLINDER
    div cx                  ; AX = cylinder, DX = head
    mov ch, al              ; CH = cylinder (low 8 bits)
    
    ; Add high bits of cylinder to sector field
    shl ah, 6               ; Move top 2 bits of cylinder to proper position
    or cl, ah               ; Set top 2 bits of CL
    
    ; Head = (LogicalSector / SectorsPerTrack) % Heads
    mov dh, dl              ; DH = head number
    
    ; Prepare read command
    mov ah, 0x02            ; Read sectors function
    ; DL already contains drive number
    pop ax                  ; Restore sector count
    mov al, cl              ; AL = number of sectors to read
    pop bx                  ; Restore buffer address
    
    ; Attempt to read the sector
    int 0x13                ; Call BIOS disk service
    jnc .success            ; If CF clear, read was successful
    
    ; Read failed, try resetting the disk controller
    call disk_reset
    
    ; Decrement retry counter
    dec di
    jz .fail                ; If retry counter is zero, fail
    
    pop ax                  ; Restore logical sector
    jmp .retry              ; Try again
    
.fail:
    pop ax                  ; Restore logical sector
    stc                     ; Set carry flag to indicate error
    jmp .done
    
.success:
    pop ax                  ; Restore logical sector
    clc                     ; Clear carry flag to indicate success
    
.done:
    pop di                  ; Restore registers
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: write_sectors
; Writes one or more sectors to disk
; Input: 
;   AX = logical sector number to write
;   CL = number of sectors to write (1-128)
;   DL = drive number (0 = floppy A:, 80h = hard disk C:)
;   ES:BX = source buffer
; Output: 
;   CF set on error, clear on success
;   If error, AH = error code
;------------------------------------------------------------------
write_sectors:
    push ax                 ; Save registers
    push bx
    push cx
    push dx
    push di
    
    mov di, MAX_RETRIES     ; Set retry counter
    
.retry:
    push ax                 ; Save logical sector
    push bx                 ; Save buffer address
    push cx                 ; Save sector count
    
    ; Convert logical sector to CHS (same as in read_sectors)
    xor dx, dx              ; Clear DX
    mov cx, SECTORS_PER_TRACK
    div cx                  ; AX = LBA / SPT, DX = remainder
    inc dx                  ; Add 1 to remainder (sectors start at 1)
    mov cl, dl              ; CL = sector number
    
    xor dx, dx              ; Clear DX
    mov cx, HEADS_PER_CYLINDER
    div cx                  ; AX = cylinder, DX = head
    mov ch, al              ; CH = cylinder (low 8 bits)
    
    shl ah, 6               ; Move top 2 bits of cylinder to proper position
    or cl, ah               ; Set top 2 bits of CL
    
    mov dh, dl              ; DH = head number
    
    ; Prepare write command
    mov ah, 0x03            ; Write sectors function
    ; DL already contains drive number
    pop ax                  ; Restore sector count
    mov al, cl              ; AL = number of sectors to write
    pop bx                  ; Restore buffer address
    
    ; Attempt to write the sector
    int 0x13                ; Call BIOS disk service
    jnc .success            ; If CF clear, write was successful
    
    ; Write failed, try resetting the disk controller
    call disk_reset
    
    ; Decrement retry counter
    dec di
    jz .fail                ; If retry counter is zero, fail
    
    pop ax                  ; Restore logical sector
    jmp .retry              ; Try again
    
.fail:
    pop ax                  ; Restore logical sector
    stc                     ; Set carry flag to indicate error
    jmp .done
    
.success:
    pop ax                  ; Restore logical sector
    clc                     ; Clear carry flag to indicate success
    
.done:
    pop di                  ; Restore registers
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: disk_get_parameters
; Gets disk parameters
; Input: DL = drive number
; Output: 
;   CF set on error, clear on success
;   If successful:
;     BL = drive type (for floppies)
;     CH = low 8 bits of maximum cylinder number
;     CL = high 2 bits of maximum cylinder number (bits 6-7)
;          and maximum sector number (bits 0-5)
;     DH = maximum head number
;     DL = number of drives
;     ES:DI = pointer to drive parameter table (floppies only)
;------------------------------------------------------------------
disk_get_parameters:
    push ax
    
    mov ah, 0x08            ; Get drive parameters function
    int 0x13                ; Call BIOS disk service
    
    pop ax
    ret

;------------------------------------------------------------------
; Function: disk_read_boot_sector
; Reads the boot sector of a drive into memory
; Input: 
;   DL = drive number
;   ES:BX = destination buffer
; Output: CF set on error, clear on success
;------------------------------------------------------------------
disk_read_boot_sector:
    push ax
    push cx
    
    xor ax, ax              ; Sector 0 (boot sector)
    mov cl, 1               ; Read 1 sector
    call read_sectors
    
    pop cx
    pop ax
    ret