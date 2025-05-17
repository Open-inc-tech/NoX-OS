# NoX-OS Makefile
# Builds the NoX-OS operating system

# Configuration
NASM=nasm
QEMU=qemu-system-i386
DISK_IMG=noxos.img
BOOT_BIN=boot.bin
KERNEL_BIN=kernel.bin

# Directories
SRC_DIR=src
BOOT_DIR=$(SRC_DIR)/boot
KERNEL_DIR=$(SRC_DIR)/kernel
INCLUDE_DIR=$(SRC_DIR)/include
BUILD_DIR=build

# Source files
BOOT_SRC=$(BOOT_DIR)/boot.asm
KERNEL_SRC=$(KERNEL_DIR)/kernel.asm

# Target files
BOOT_TARGET=$(BUILD_DIR)/$(BOOT_BIN)
KERNEL_TARGET=$(BUILD_DIR)/$(KERNEL_BIN)
DISK_TARGET=$(BUILD_DIR)/$(DISK_IMG)

# Floppy disk details
FLOPPY_SIZE=1474560  # 1.44 MB

.PHONY: all clean run

all: $(DISK_TARGET)

# Create build directory if it doesn't exist
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile the bootloader
$(BOOT_TARGET): $(BOOT_SRC) | $(BUILD_DIR)
	$(NASM) -f bin -o $@ $<

# Compile the kernel
$(KERNEL_TARGET): $(KERNEL_SRC) $(KERNEL_DIR)/*.asm $(INCLUDE_DIR)/*.inc | $(BUILD_DIR)
	$(NASM) -f bin -I $(SRC_DIR) -o $@ $<

# Create the disk image
$(DISK_TARGET): $(BOOT_TARGET) $(KERNEL_TARGET) | $(BUILD_DIR)
	# Create an empty disk image
	dd if=/dev/zero of=$@ bs=512 count=2880 # 1.44 MB floppy (2880 * 512 bytes)
	
	# Write bootloader to the first sector
	dd if=$(BOOT_TARGET) of=$@ conv=notrunc bs=512 count=1
	
	# Write kernel to the disk starting at the second sector
	dd if=$(KERNEL_TARGET) of=$@ conv=notrunc bs=512 seek=1

# Run the OS in QEMU
run: $(DISK_TARGET)
	$(QEMU) -fda $(DISK_TARGET)

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
