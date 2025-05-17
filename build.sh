#!/bin/bash
# NoX-OS Build Script
# This script builds the NoX-OS operating system

# Exit on error
set -e

# Configuration
NASM=${NASM:-nasm}
QEMU=${QEMU:-qemu-system-i386}
DISK_IMG="noxos.img"
BOOT_BIN="boot.bin"
KERNEL_BIN="kernel.bin"

# Directories
SRC_DIR="src"
BOOT_DIR="${SRC_DIR}/boot"
KERNEL_DIR="${SRC_DIR}/kernel"
INCLUDE_DIR="${SRC_DIR}/include"
BUILD_DIR="build"

# Source files
BOOT_SRC="${BOOT_DIR}/boot.asm"
KERNEL_SRC="${KERNEL_DIR}/kernel.asm"

# Target files
BOOT_TARGET="${BUILD_DIR}/${BOOT_BIN}"
KERNEL_TARGET="${BUILD_DIR}/${KERNEL_BIN}"
DISK_TARGET="${BUILD_DIR}/${DISK_IMG}"

# Floppy disk details
FLOPPY_SIZE=1474560  # 1.44 MB

# Check for dependencies
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo "Error: $1 is required but not installed."
        exit 1
    fi
}

check_dependency "${NASM}"
check_dependency dd

# Create build directory
echo "Creating build directory..."
mkdir -p "${BUILD_DIR}"

# Compile bootloader
echo "Compiling bootloader..."
${NASM} -f bin -o "${BOOT_TARGET}" "${BOOT_SRC}"

# Compile kernel
echo "Compiling kernel..."
${NASM} -f bin -I "${SRC_DIR}" -o "${KERNEL_TARGET}" "${KERNEL_SRC}"

# Create disk image
echo "Creating disk image..."
# Create an empty disk image (1.44 MB floppy)
dd if=/dev/zero of="${DISK_TARGET}" bs=512 count=2880

# Write bootloader to the first sector
dd if="${BOOT_TARGET}" of="${DISK_TARGET}" conv=notrunc bs=512 count=1

# Write kernel to the disk starting at the second sector
dd if="${KERNEL_TARGET}" of="${DISK_TARGET}" conv=notrunc bs=512 seek=1

echo ""
echo "Build complete! The OS image is at: ${DISK_TARGET}"
echo ""
echo "To run in QEMU, use: ./run.sh"
echo "or: qemu-system-i386 -fda ${DISK_TARGET}"
