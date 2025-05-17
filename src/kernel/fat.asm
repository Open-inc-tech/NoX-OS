;==================================================================
; NoX-OS FAT12 File System Handler
;==================================================================
; Implements basic FAT12 file system operations for a floppy disk

;------------------------------------------------------------------
; FAT12 Constants
;------------------------------------------------------------------
%define SECTOR_SIZE 512     ; Bytes per sector
%define CLUSTER_SIZE 1      ; Sectors per cluster (typically 1 for floppy)
%define ROOT_ENTRIES 224    ; Number of root directory entries (1.44MB floppy)
%define ROOT_DIR_SECTORS 14 ; Root directory sectors (224 * 32 / 512)
%define FAT_COPIES 2        ; Number of FAT copies
%define SECTORS_PER_FAT 9   ; Sectors per FAT (1.44MB floppy)
%define RESERVED_SECTORS 1  ; Reserved sectors (boot sector)
%define BOOT_SECTOR 0       ; Boot sector location

; FAT12 Special Cluster Values
%define FAT_FREE 0x000      ; Free cluster
%define FAT_RESERVED 0xFF0  ; Reserved cluster
%define FAT_BAD 0xFF7       ; Bad cluster
%define FAT_LAST 0xFF8      ; Last cluster in a file (0xFF8-0xFFF)

; FAT File Attributes
%define FAT_ATTR_READ_ONLY 0x01
%define FAT_ATTR_HIDDEN    0x02
%define FAT_ATTR_SYSTEM    0x04
%define FAT_ATTR_VOLUME_ID 0x08
%define FAT_ATTR_DIRECTORY 0x10
%define FAT_ATTR_ARCHIVE   0x20
%define FAT_ATTR_LFN       0x0F    ; Long file name attribute combination

; FAT Boot Sector offsets
%define BS_OEM_NAME 0x03          ; OEM Name (8 bytes)
%define BS_BYTES_PER_SECTOR 0x0B  ; Bytes per sector (2 bytes)
%define BS_SECTORS_PER_CLUSTER 0x0D ; Sectors per cluster (1 byte)
%define BS_RESERVED_SECTORS 0x0E  ; Reserved sectors (2 bytes)
%define BS_FAT_COPIES 0x10        ; Number of FATs (1 byte)
%define BS_ROOT_DIR_ENTRIES 0x11  ; Root directory entries (2 bytes)
%define BS_TOTAL_SECTORS 0x13     ; Total sectors (2 bytes)
%define BS_MEDIA_DESCRIPTOR 0x15  ; Media descriptor (1 byte)
%define BS_SECTORS_PER_FAT 0x16   ; Sectors per FAT (2 bytes)
%define BS_SECTORS_PER_TRACK 0x18 ; Sectors per track (2 bytes)
%define BS_HEADS 0x1A             ; Number of heads (2 bytes)
%define BS_HIDDEN_SECTORS 0x1C    ; Hidden sectors (4 bytes)
%define BS_LARGE_SECTORS 0x20     ; Large sectors (4 bytes)
%define BS_DRIVE_NUMBER 0x24      ; Drive number (1 byte)
%define BS_SIGNATURE 0x26         ; Signature (1 byte)
%define BS_VOLUME_ID 0x27         ; Volume ID (4 bytes)
%define BS_VOLUME_LABEL 0x2B      ; Volume label (11 bytes)
%define BS_FILESYSTEM_TYPE 0x36   ; Filesystem type (8 bytes)

;------------------------------------------------------------------
; FAT12 Data Structures
;------------------------------------------------------------------

; FAT directory entry structure (32 bytes)
struc FAT_ENTRY
    .Filename      resb 8  ; 8.3 filename (without dot)
    .Extension     resb 3  ; File extension (3 chars)
    .Attributes    resb 1  ; File attributes
    .Reserved      resb 10 ; Reserved bytes
    .Time          resw 1  ; Last modified time
    .Date          resw 1  ; Last modified date
    .FirstCluster  resw 1  ; First cluster of file
    .FileSize      resd 1  ; File size in bytes
endstruc
%define FAT_ENTRY_SIZE 32  ; Size of a FAT directory entry

; Attributes
%define ATTR_READ_ONLY  0x01
%define ATTR_HIDDEN     0x02
%define ATTR_SYSTEM     0x04
%define ATTR_VOLUME_ID  0x08
%define ATTR_DIRECTORY  0x10
%define ATTR_ARCHIVE    0x20
%define ATTR_LONG_NAME  (ATTR_READ_ONLY | ATTR_HIDDEN | ATTR_SYSTEM | ATTR_VOLUME_ID)

;------------------------------------------------------------------
; FAT12 File System Variables
;------------------------------------------------------------------
; Global variables for FAT operations
fat_buffer: times SECTOR_SIZE db 0     ; Buffer for FAT sector
dir_buffer: times SECTOR_SIZE db 0     ; Buffer for directory sector
data_buffer: times SECTOR_SIZE db 0    ; Buffer for data sector
fat_info:                              ; Structure to hold FAT information
    .bytes_per_sector      dw 512
    .sectors_per_cluster   db 1 
    .reserved_sectors      dw 1
    .fat_copies            db 2
    .root_entries          dw 224
    .total_sectors         dw 2880     ; 1.44MB floppy
    .media_descriptor      db 0xF0     ; 3.5" floppy
    .sectors_per_fat       dw 9
    .sectors_per_track     dw 18
    .heads                 dw 2
    .hidden_sectors        dd 0
    .drive_number          db 0        ; Floppy A:
    
current_dir_cluster: dw 0      ; Current directory's first cluster (0 = root)
current_path: times 256 db 0   ; Current path string

;------------------------------------------------------------------
; Function: fat_init
; Initializes the FAT file system
; Input: DL = drive number
; Output: CF set on error, AX = error code
;------------------------------------------------------------------
fat_init:
    push bx
    push cx
    push dx
    push es
    push si
    push di
    
    ; Save drive number
    mov [fat_info.drive_number], dl
    
    ; Set current directory to root
    mov word [current_dir_cluster], 0
    
    ; Set current path to root
    mov di, current_path
    mov byte [di], '/'
    mov byte [di+1], 0
    
    ; Read boot sector to get FAT parameters
    mov bx, data_buffer
    push ds
    pop es                      ; Set ES=DS for the buffer
    call disk_read_boot_sector
    jc .error
    
    ; Verify disk signature (0x55, 0xAA at end of boot sector)
    cmp word [data_buffer + 510], 0xAA55
    jne .invalid_fs
    
    ; Extract FAT parameters from boot sector
    mov ax, [data_buffer + BS_BYTES_PER_SECTOR]
    mov [fat_info.bytes_per_sector], ax
    
    mov al, [data_buffer + BS_SECTORS_PER_CLUSTER]
    mov [fat_info.sectors_per_cluster], al
    
    mov ax, [data_buffer + BS_RESERVED_SECTORS]
    mov [fat_info.reserved_sectors], ax
    
    mov al, [data_buffer + BS_FAT_COPIES]
    mov [fat_info.fat_copies], al
    
    mov ax, [data_buffer + BS_ROOT_DIR_ENTRIES]
    mov [fat_info.root_entries], ax
    
    mov ax, [data_buffer + BS_TOTAL_SECTORS]
    test ax, ax
    jnz .small_volume
    mov ax, [data_buffer + BS_LARGE_SECTORS]
.small_volume:
    mov [fat_info.total_sectors], ax
    
    mov al, [data_buffer + BS_MEDIA_DESCRIPTOR]
    mov [fat_info.media_descriptor], al
    
    mov ax, [data_buffer + BS_SECTORS_PER_FAT]
    mov [fat_info.sectors_per_fat], ax
    
    mov ax, [data_buffer + BS_SECTORS_PER_TRACK]
    mov [fat_info.sectors_per_track], ax
    
    mov ax, [data_buffer + BS_HEADS]
    mov [fat_info.heads], ax
    
    ; Load first FAT sector
    mov ax, [fat_info.reserved_sectors]
    mov cl, 1
    mov dl, [fat_info.drive_number]
    mov bx, fat_buffer
    call read_sectors
    jc .error
    
    ; Success
    clc
    jmp .exit
    
.invalid_fs:
    mov ax, 1               ; Error code 1: Invalid file system
    stc
    jmp .exit
    
.error:
    ; AX already contains error code from read_sectors
    stc
    
.exit:
    pop di
    pop si
    pop es
    pop dx
    pop cx
    pop bx
    ret

;------------------------------------------------------------------
; Function: fat_root_dir_sector
; Calculates the first sector of the root directory
; Output: AX = first root directory sector
;------------------------------------------------------------------
fat_root_dir_sector:
    push bx
    
    ; root_dir_sector = reserved_sectors + (fat_copies * sectors_per_fat)
    mov ax, [fat_info.reserved_sectors]
    mov bl, [fat_info.fat_copies]
    movzx bx, bl
    mov cx, [fat_info.sectors_per_fat]
    mul cx
    add ax, [fat_info.reserved_sectors]
    
    pop bx
    ret

;------------------------------------------------------------------
; Function: fat_data_sector
; Calculates the first sector of the data area
; Output: AX = first data area sector
;------------------------------------------------------------------
fat_data_sector:
    push bx
    push cx
    push dx
    
    ; Calculate size of root directory in sectors
    mov ax, [fat_info.root_entries]
    mov cx, 32                  ; Each entry is 32 bytes
    mul cx                      ; AX = root_entries * 32
    mov cx, [fat_info.bytes_per_sector]
    add ax, cx                  ; Round up
    dec ax
    div cx                      ; AX = root_directory_size_in_sectors
    
    ; data_sector = root_dir_sector + root_directory_size_in_sectors
    mov bx, ax                  ; BX = root_directory_size_in_sectors
    call fat_root_dir_sector    ; AX = root_dir_sector
    add ax, bx                  ; AX = data_sector
    
    pop dx
    pop cx
    pop bx
    ret

;------------------------------------------------------------------
; Function: fat_read_root_dir
; Reads the root directory into memory
; Input: none
; Output: CF set on error
;------------------------------------------------------------------
fat_read_root_dir:
    push ax
    push bx
    push cx
    push dx
    push es
    
    ; Calculate location of root directory
    call fat_root_dir_sector    ; AX = root directory sector
    
    ; Read root directory sectors
    mov cl, 1                   ; Read 1 sector at a time
    mov dl, [fat_info.drive_number]
    mov bx, dir_buffer
    push ds
    pop es                      ; ES=DS for buffer
    call read_sectors
    
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: fat_find_file
; Finds a file in the root directory
; Input: 
;   DS:SI = pointer to filename (8.3 format)
;   BX = pointer to FAT_ENTRY to fill with result (can be NULL)
; Output: 
;   CF clear if found, set if not found
;   If found and BX != NULL, BX points to filled FAT_ENTRY
;------------------------------------------------------------------
fat_find_file:
    push ax
    push cx
    push dx
    push di
    push es
    push si
    
    ; Read root directory
    call fat_read_root_dir
    jc .not_found
    
    ; Initialize counters
    mov cx, [fat_info.root_entries]   ; Number of directory entries
    mov di, dir_buffer                ; Pointer to directory buffer
    
.search_loop:
    ; Check if we've gone through all entries
    test cx, cx
    jz .not_found
    
    ; Check if entry is free
    cmp byte [di], 0
    je .not_found                     ; End of directory
    cmp byte [di], 0xE5
    je .next_entry                    ; Deleted entry
    
    ; Check if entry is a volume label or LFN
    test byte [di + FAT_ENTRY.Attributes], ATTR_VOLUME_ID
    jnz .next_entry
    
    ; Compare filenames (11 bytes: 8 for name, 3 for extension)
    push si
    push di
    push cx
    mov cx, 11                        ; 8 chars filename + 3 chars extension
    rep cmpsb                         ; Compare DS:SI with ES:DI for CX bytes
    pop cx
    pop di
    pop si
    je .found
    
.next_entry:
    add di, FAT_ENTRY_SIZE            ; Move to next directory entry
    dec cx
    jmp .search_loop
    
.not_found:
    stc                               ; Set carry flag (not found)
    jmp .exit
    
.found:
    ; If BX is not NULL, copy the entry
    test bx, bx
    jz .skip_copy
    
    ; Copy the entry to the buffer pointed to by BX
    push cx
    push si
    push di
    
    mov cx, FAT_ENTRY_SIZE            ; Size of entry
    mov si, di                        ; Source = directory entry
    mov di, bx                        ; Destination = user buffer
    rep movsb                         ; Copy the entry
    
    pop di
    pop si
    pop cx
    
.skip_copy:
    clc                               ; Clear carry flag (found)
    
.exit:
    pop si
    pop es
    pop di
    pop dx
    pop cx
    pop ax
    ret

;------------------------------------------------------------------
; Function: fat_read_cluster
; Reads a cluster from disk into memory
; Input: 
;   AX = cluster number
;   ES:BX = buffer to load into
; Output: CF set on error
;------------------------------------------------------------------
fat_read_cluster:
    push ax
    push bx
    push cx
    push dx
    
    ; Calculate sector number from cluster
    ; First data sector is cluster 2
    sub ax, 2                         ; Clusters start at 2
    movzx cx, [fat_info.sectors_per_cluster]
    mul cx                            ; AX = (cluster - 2) * sectors_per_cluster
    
    ; Add data area start sector
    push ax
    call fat_data_sector              ; AX = first data sector
    pop dx
    add ax, dx                        ; AX = target sector
    
    ; Read the cluster
    mov cl, [fat_info.sectors_per_cluster]  ; Number of sectors per cluster
    mov dl, [fat_info.drive_number]   ; Drive number
    call read_sectors
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: fat_get_fat_sector
; Gets the FAT sector containing a specific cluster entry
; Input: AX = cluster number
; Output: 
;   AX = FAT sector number
;   BX = byte offset within the sector
;------------------------------------------------------------------
fat_get_fat_sector:
    push cx
    push dx
    
    ; Each FAT12 entry is 12 bits (1.5 bytes)
    ; Offset in bytes = cluster * 1.5
    mov cx, ax                        ; Save cluster number
    shr ax, 1                         ; Divide by 2
    add ax, cx                        ; AX = cluster * 1.5 (byte offset in FAT)
    
    ; Calculate sector and offset
    mov cx, [fat_info.bytes_per_sector]
    mov bx, ax                        ; Save byte offset
    div cx                            ; AX = sector offset from FAT start, DX = byte offset
    
    ; Add FAT start sector
    add ax, [fat_info.reserved_sectors]
    
    ; Set byte offset in BX
    mov bx, dx
    
    pop dx
    pop cx
    ret

;------------------------------------------------------------------
; Function: fat_get_next_cluster
; Gets the next cluster in a FAT chain
; Input: AX = current cluster number
; Output: 
;   AX = next cluster number
;   CF set if end of chain or error
;------------------------------------------------------------------
fat_get_next_cluster:
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    ; Get FAT sector containing this cluster's entry
    call fat_get_fat_sector           ; AX = sector, BX = offset
    push bx                           ; Save offset
    
    ; Read the FAT sector
    mov cx, 1                         ; Read 1 sector
    mov dl, [fat_info.drive_number]
    mov si, bx                        ; Save offset
    mov bx, fat_buffer
    push ds
    pop es                            ; ES=DS for buffer
    call read_sectors
    jc .error
    
    ; Restore offset and get the FAT entry
    pop bx                            ; BX = offset in FAT sector
    
    ; Get the 12-bit cluster value
    mov ax, [fat_buffer + bx]         ; Read a word (16 bits)
    
    ; Check if it's an odd or even cluster number
    mov cx, si                        ; Get original cluster number
    test cx, 1                        ; Check if it's odd
    jz .even_cluster
    
.odd_cluster:
    ; For odd clusters, we need the top 12 bits of the 16-bit word
    shr ax, 4                         ; Shift right 4 bits
    jmp .check_end
    
.even_cluster:
    ; For even clusters, we need the bottom 12 bits
    and ax, 0x0FFF                    ; Mask out top 4 bits
    
.check_end:
    ; Check for end-of-chain markers or bad clusters
    cmp ax, FAT_BAD
    je .error
    
    cmp ax, FAT_LAST
    jae .end_of_chain
    
    ; We got a valid next cluster
    clc
    jmp .exit
    
.error:
.end_of_chain:
    stc                               ; Set carry flag for end of chain/error
    
.exit:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

;------------------------------------------------------------------
; Function: fat_read_file
; Reads a file from disk
; Input: 
;   DS:SI = pointer to filename in 8.3 format
;   ES:DI = buffer to load file into
; Output: 
;   CF set on error, clear on success
;   If success, AX = file size in bytes
;------------------------------------------------------------------
fat_read_file:
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Allocate memory for a FAT_ENTRY on the stack
    sub sp, FAT_ENTRY_SIZE
    mov bx, sp                        ; BX -> FAT_ENTRY
    
    ; Find the file in the directory
    call fat_find_file
    jc .not_found
    
    ; Get file size and first cluster
    mov ax, [bx + FAT_ENTRY.FileSize]
    mov cx, [bx + FAT_ENTRY.FileSize + 2]
    push ax                           ; Save file size (low 16 bits)
    
    mov ax, [bx + FAT_ENTRY.FirstCluster]
    test ax, ax                       ; Check if file is empty
    jz .empty_file
    
    ; Read clusters in a loop
    push di                           ; Save original buffer address
    
.read_loop:
    push ax                           ; Save current cluster
    
    ; Read the cluster
    mov bx, di
    call fat_read_cluster
    jc .read_error
    
    ; Move buffer pointer forward by cluster size
    mov ax, [fat_info.bytes_per_sector]
    movzx cx, [fat_info.sectors_per_cluster]
    mul cx                            ; AX = bytes per cluster
    add di, ax                        ; Move buffer pointer
    
    ; Get next cluster
    pop ax                            ; Restore current cluster
    call fat_get_next_cluster
    jnc .read_loop                    ; If not end of chain, continue
    
    ; End of file reached
    pop di                            ; Restore original buffer address
    pop ax                            ; Get file size
    clc                               ; Clear carry flag (success)
    jmp .cleanup
    
.empty_file:
    pop ax                            ; Get file size (should be 0)
    clc                               ; Clear carry flag (success)
    jmp .cleanup
    
.not_found:
    mov ax, 1                         ; Error code 1: File not found
    stc
    jmp .cleanup
    
.read_error:
    pop ax                            ; Fix stack (remove cluster)
    pop di                            ; Restore original buffer address
    pop ax                            ; Remove file size from stack
    mov ax, 2                         ; Error code 2: Read error
    stc
    
.cleanup:
    ; Free the FAT_ENTRY from the stack
    add sp, FAT_ENTRY_SIZE
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

;------------------------------------------------------------------
; Function: fat_parse_filename
; Parses a filename into 8.3 format
; Input:
;   DS:SI = pointer to filename string
;   ES:DI = pointer to output buffer (11 bytes)
; Output:
;   CF set if invalid filename
;------------------------------------------------------------------
fat_parse_filename:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Initialize output with spaces
    mov cx, 11
    mov al, ' '
    rep stosb
    sub di, 11                        ; Move DI back to start
    
    ; Skip any leading path separators
    mov al, [si]
    cmp al, '/'
    jne .start_copy
    inc si
    
.start_copy:
    ; Copy filename (up to 8 chars)
    mov cx, 8                         ; Maximum 8 chars for name
    
.copy_name:
    mov al, [si]
    test al, al                       ; Check for end of string
    jz .pad_extension
    cmp al, '.'                       ; Check for extension separator
    je .extension
    cmp al, '/'                       ; Check for path separator
    je .pad_extension
    
    ; Convert to uppercase and check if valid
    call to_uppercase
    call is_valid_filename_char
    jc .invalid
    
    ; Store character in output buffer
    mov [di], al
    inc di
    inc si
    
    ; Check if we've copied 8 chars
    dec cx
    jz .find_extension
    jmp .copy_name
    
.find_extension:
    ; Find the extension part
    mov al, [si]
    test al, al                       ; Check for end of string
    jz .pad_extension
    cmp al, '.'                       ; Check for extension separator
    je .extension
    inc si                            ; Skip character
    jmp .find_extension
    
.extension:
    ; Skip the dot
    inc si
    
    ; Move to extension field in output
    mov di, di                        ; DI already pointing to extension
    add di, cx                        ; Skip remaining name positions
    
    ; Copy extension (up to 3 chars)
    mov cx, 3                         ; Maximum 3 chars for extension
    
.copy_ext:
    mov al, [si]
    test al, al                       ; Check for end of string
    jz .done
    cmp al, '/'                       ; Check for path separator
    je .done
    
    ; Convert to uppercase and check if valid
    call to_uppercase
    call is_valid_filename_char
    jc .invalid
    
    ; Store character in output buffer
    mov [di], al
    inc di
    inc si
    
    ; Check if we've copied 3 chars
    dec cx
    jz .skip_ext
    jmp .copy_ext
    
.skip_ext:
    ; Skip remaining characters in extension
    mov al, [si]
    test al, al                       ; Check for end of string
    jz .done
    cmp al, '/'                       ; Check for path separator
    je .done
    inc si
    jmp .skip_ext
    
.pad_extension:
    ; No extension found, already padded with spaces
    
.done:
    ; Success
    clc
    jmp .exit
    
.invalid:
    ; Invalid filename
    stc
    
.exit:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------
; Function: is_valid_filename_char
; Checks if a character is valid in 8.3 filenames
; Input: AL = character to check
; Output: CF clear if valid, set if invalid
;------------------------------------------------------------------
is_valid_filename_char:
    ; Check for invalid characters in 8.3 format
    ; These characters are invalid: < > : " / \ | ? *
    
    cmp al, '<'
    je .invalid
    cmp al, '>'
    je .invalid
    cmp al, ':'
    je .invalid
    cmp al, '"'
    je .invalid
    cmp al, '/'
    je .invalid
    cmp al, '\'
    je .invalid
    cmp al, '|'
    je .invalid
    cmp al, '?'
    je .invalid
    cmp al, '*'
    je .invalid
    
    ; Valid character
    clc
    ret
    
.invalid:
    stc
    ret

;------------------------------------------------------------------
; Function: to_uppercase
; Converts a character to uppercase
; Input: AL = character
; Output: AL = uppercase character
;------------------------------------------------------------------
to_uppercase:
    cmp al, 'a'
    jb .done
    cmp al, 'z'
    ja .done
    sub al, 'a' - 'A'                 ; Convert to uppercase
.done:
    ret

;------------------------------------------------------------------
; Function: cmd_dir
; Lists files in the current directory
; Input: none
;------------------------------------------------------------------
cmd_dir:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    ; Display directory header
    mov si, dir_header_msg
    call print_string
    
    ; Read the root directory
    call fat_read_root_dir
    jc .read_error
    
    ; Initialize counters
    mov cx, [fat_info.root_entries]   ; Number of directory entries
    mov si, dir_buffer                ; Pointer to directory buffer
    xor ax, ax                        ; File count
    xor bx, bx                        ; Directory count
    mov dx, 0                         ; Total bytes count (low 16 bits)
    mov di, 0                         ; Total bytes count (high 16 bits)
    
.dir_loop:
    ; Check if we've gone through all entries
    test cx, cx
    jz .dir_done
    
    ; Check if entry is free
    cmp byte [si], 0
    je .dir_done                      ; End of directory
    cmp byte [si], 0xE5
    je .next_entry                    ; Deleted entry
    
    ; Check if entry is a volume label
    test byte [si + FAT_ENTRY.Attributes], ATTR_VOLUME_ID
    jnz .next_entry                   ; Skip volume labels
    
    ; Display directory entry
    push cx
    push si
    
    ; Print filename (8 chars)
    mov cx, 8
.name_loop:
    mov al, [si]
    cmp al, ' '
    je .name_done
    call print_char
    inc si
    dec cx
    jnz .name_loop
    jmp .print_ext
    
.name_done:
    ; Print spaces to pad the name
    mov al, ' '
.pad_name:
    call print_char
    dec cx
    jnz .pad_name
    add si, cx                        ; Skip remaining spaces in filename
    
.print_ext:
    ; Print a dot for the extension
    mov al, '.'
    call print_char
    
    ; Print extension (3 chars)
    mov cx, 3
.ext_loop:
    mov al, [si + 8 - 8]              ; Extension starts at offset 8
    cmp al, ' '
    je .ext_pad
    call print_char
    inc si
    dec cx
    jnz .ext_loop
    jmp .ext_done
    
.ext_pad:
    ; Pad extension with spaces
    mov al, ' '
.pad_ext:
    call print_char
    dec cx
    jnz .pad_ext
    add si, cx                        ; Skip remaining spaces in extension
    
.ext_done:
    ; Add padding after the name
    mov cx, 3
    mov al, ' '
.post_pad:
    call print_char
    dec cx
    jnz .post_pad
    
    ; Restore SI to the directory entry
    pop si
    push si
    
    ; Check if it's a directory
    test byte [si + FAT_ENTRY.Attributes], ATTR_DIRECTORY
    jz .print_size
    
    ; Print "<DIR>" for directories
    mov si, dir_tag
    call print_string
    inc bx                            ; Increment directory count
    jmp .print_date
    
.print_size:
    ; Print file size
    mov ax, [si + FAT_ENTRY.FileSize]
    call print_dec
    
    ; Add to total bytes
    add dx, ax
    adc di, 0                         ; Handle carry to high 16 bits
    
    ; Increment file count
    inc ax
    
.print_date:
    ; Print newline
    call print_newline
    
    pop si
    pop cx
    
.next_entry:
    add si, FAT_ENTRY_SIZE            ; Move to next directory entry
    dec cx
    jmp .dir_loop
    
.dir_done:
    ; Print summary
    call print_newline
    
    ; Display file count
    mov ax, bx                        ; AX = file count
    call print_dec
    mov si, files_msg
    call print_string
    
    ; Display directory count
    mov ax, bx                        ; AX = directory count
    call print_dec
    mov si, dirs_msg
    call print_string
    
    ; Display total bytes
    mov ax, dx                        ; AX = total bytes (low 16 bits)
    call print_dec
    mov si, bytes_msg
    call print_string
    
    jmp .done
    
.read_error:
    mov si, dir_read_error_msg
    call print_string
    
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
; Function: cmd_type
; Displays the contents of a text file
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_type:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    ; Skip "TYPE" command
    call skip_token
    
    ; Check if a filename was provided
    cmp byte [si], 0
    je .no_file
    
    ; Skip whitespace
    call skip_whitespace
    
    ; Allocate a buffer on the stack for the 8.3 filename
    sub sp, 12                        ; 11 bytes + null terminator
    mov di, sp
    
    ; Convert filename to 8.3 format
    push ds
    pop es                            ; ES=DS for the buffer
    call fat_parse_filename
    jc .invalid_filename
    
    ; Now allocate a file buffer (4KB should be sufficient for text files)
    sub sp, 4096
    mov di, sp
    
    ; Read the file
    mov si, sp
    add si, 4096                      ; SI -> 8.3 filename
    push ds
    pop es                            ; ES=DS for the buffer
    call fat_read_file
    jc .file_error
    
    ; Display the file contents
    mov si, sp                        ; SI -> file buffer
    call print_string
    call print_newline
    
    ; Free the file buffer
    add sp, 4096
    jmp .free_filename
    
.no_file:
    mov si, type_no_filename_msg
    call print_string
    jmp .done
    
.invalid_filename:
    mov si, type_invalid_filename_msg
    call print_string
    jmp .free_filename
    
.file_error:
    cmp ax, 1                         ; Error code 1: File not found
    je .file_not_found
    
    mov si, type_read_error_msg
    call print_string
    
    ; Free the file buffer
    add sp, 4096
    jmp .free_filename
    
.file_not_found:
    mov si, type_file_not_found_msg
    call print_string
    
    ; Free the file buffer
    add sp, 4096
    
.free_filename:
    ; Free the filename buffer
    add sp, 12
    
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
; Function: skip_token
; Skips the current token (word) in a string
; Input: SI = pointer to string
; Output: SI = pointer to position after token
;------------------------------------------------------------------
skip_token:
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
    call skip_whitespace
    
.done:
    pop ax
    ret

;------------------------------------------------------------------
; Function: skip_whitespace
; Skips whitespace characters in a string
; Input: SI = pointer to string
; Output: SI = pointer to next non-whitespace character
;------------------------------------------------------------------
skip_whitespace:
    push ax
    
.loop:
    mov al, [si]
    
    ; Check for end of string
    test al, al
    jz .done
    
    ; Check for whitespace
    cmp al, ' '
    je .skip
    cmp al, 9                         ; Tab
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
; Function: cmd_cd
; Changes the current directory
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_cd:
    push ax
    push si
    
    ; Skip "CD" command
    call skip_token
    
    ; Check if a directory was provided
    cmp byte [si], 0
    je .display_current
    
    ; Skip whitespace
    call skip_whitespace
    
    ; Display a placeholder message for now
    mov si, cd_placeholder_msg
    call print_string
    jmp .done
    
.display_current:
    ; Display the current directory
    mov si, current_path
    call print_string
    call print_newline
    
.done:
    pop si
    pop ax
    ret

;------------------------------------------------------------------
; Function: cmd_del
; Deletes a file
; Input: SI = pointer to command line
;------------------------------------------------------------------
cmd_del:
    push si
    
    ; Skip "DEL" command
    call skip_token
    
    ; Check if a filename was provided
    cmp byte [si], 0
    je .no_file
    
    ; Skip whitespace
    call skip_whitespace
    
    ; Display a placeholder message for now
    mov si, del_placeholder_msg
    call print_string
    jmp .done
    
.no_file:
    mov si, del_no_filename_msg
    call print_string
    
.done:
    pop si
    ret

;------------------------------------------------------------------
; Function: print_dec
; Prints a decimal number
; Input: AX = number to print
;------------------------------------------------------------------
print_dec:
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
; DATA SECTION
;------------------------------------------------------------------
dir_header_msg db 'Directory listing:', 0x0D, 0x0A
               db '==================', 0x0D, 0x0A, 0

dir_tag db '<DIR>     ', 0
files_msg db ' file(s)', 0x0D, 0x0A, 0
dirs_msg db ' dir(s)', 0x0D, 0x0A, 0
bytes_msg db ' bytes total', 0x0D, 0x0A, 0
dir_read_error_msg db 'Error reading directory.', 0x0D, 0x0A, 0

type_no_filename_msg db 'Error: No filename specified.', 0x0D, 0x0A
                     db 'Usage: TYPE filename', 0x0D, 0x0A, 0
type_invalid_filename_msg db 'Error: Invalid filename.', 0x0D, 0x0A, 0
type_file_not_found_msg db 'Error: File not found.', 0x0D, 0x0A, 0
type_read_error_msg db 'Error reading file.', 0x0D, 0x0A, 0

cd_placeholder_msg db 'The CD command will change the current directory.', 0x0D, 0x0A
                   db 'This functionality will be fully implemented in the next version.', 0x0D, 0x0A, 0

del_placeholder_msg db 'The DEL command will delete files.', 0x0D, 0x0A
                    db 'This functionality will be fully implemented in the next version.', 0x0D, 0x0A, 0
del_no_filename_msg db 'Error: No filename specified.', 0x0D, 0x0A
                    db 'Usage: DEL filename', 0x0D, 0x0A, 0