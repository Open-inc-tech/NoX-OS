#!/bin/bash
# NoX-OS Run Script
# This script runs the NoX-OS operating system in QEMU

# Exit on error
set -e

# Configuration
QEMU=${QEMU:-qemu-system-i386}
DISK_IMG="build/noxos.img"

# Check if the image exists
if [ ! -f "${DISK_IMG}" ]; then
    echo "Error: OS image not found at ${DISK_IMG}"
    echo "Please run './build.sh' first to build the OS."
    exit 1
fi

# Check for QEMU
if ! command -v ${QEMU} &> /dev/null; then
    echo "Error: QEMU (${QEMU}) is required but not installed."
    exit 1
fi

# Run the OS in QEMU
echo "Running NoX-OS in QEMU..."
${QEMU} -fda "${DISK_IMG}"
