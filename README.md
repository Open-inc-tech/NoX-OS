# NoX-OS

A practical 16-bit operating system inspired by MS-DOS 5, written in x86 assembly.

## Overview

NoX-OS is a bootable 16-bit operating system that runs in real mode on x86 hardware. It consists of a bootloader, kernel, and file system implementation, capable of booting from a floppy disk image and providing practical file management and text editing capabilities.

### Features

- **16-bit real mode operation** - Compatible with basic PC hardware
- **Custom bootloader** - Loads the kernel from disk with error handling
- **FAT12 file system support** - Read and navigate a standard file system
- **Command-line shell** - Familiar DOS-like experience
- **Text editor** - Create and edit text files
- **File management** - Create, read, and delete files
- **Modular architecture** - Clean, well-structured assembly code

### Included Commands

NoX-OS includes the following DOS-like commands:

- `HELP` - Display available commands
- `CLS` - Clear the screen
- `VER` - Display system version
- `DIR` - List files in the current directory
- `TYPE` - Display the contents of a text file
- `DEL` - Delete files
- `CD` - Change directory
- `EDIT` - Simple text editor
- `EXIT` - Restart the system

## Building

### Prerequisites

To build NoX-OS, you need the following tools:

- **NASM** (Netwide Assembler) - For assembly code compilation
- **DD** (Data Duplicator) - For creating disk images
- **QEMU** - For testing the OS in an emulator

### Build Commands

To build the operating system:

```bash
# Make the build script executable
chmod +x build.sh

# Build the OS image
./build.sh
```

This creates a bootable floppy disk image (`build/noxos.img`) that contains the bootloader and kernel.

## Running

To run NoX-OS in QEMU:

```bash
# Make the run script executable
chmod +x run.sh

# Run the OS in QEMU
./run.sh
```

### Running Outside Replit

To run NoX-OS on your local machine:

1. Download the `noxos.img` file from Replit
2. Install QEMU on your system if not already installed
3. Run the image with: `qemu-system-i386 -fda noxos.img`

## Project Structure

- **src/boot/** - Bootloader code
  - **boot.asm** - Main bootloader
- **src/kernel/** - Kernel code
  - **kernel.asm** - Main kernel entry point
  - **io.asm** - Input/output routines
  - **keyboard.asm** - Keyboard handling
  - **display.asm** - Screen output functionality
  - **disk.asm** - Disk I/O routines
  - **fat.asm** - FAT12 file system implementation
  - **command.asm** - Command shell implementation
  - **editor.asm** - Text editor implementation
- **src/include/** - Shared include files
  - **constants.inc** - System-wide constants
- **build.sh** - Build script
- **run.sh** - Run script for QEMU

## File System Structure

NoX-OS implements a FAT12 file system compatible with MS-DOS, allowing files to be shared between NoX-OS and other operating systems. The file system follows the standard FAT12 format:

- **Boot Sector** - Contains the boot code and file system parameters
- **FAT Tables** - File Allocation Tables that track cluster usage
- **Root Directory** - Contains directory entries for files and subdirectories
- **Data Area** - Contains the actual file data

## Technical Details

- **Boot Process** - 512-byte bootloader loads the kernel from disk sectors
- **Memory Layout** - Kernel loaded at segment 0x1000
- **Text Mode** - Uses standard 80x25 text mode with VGA BIOS routines
- **Disk Access** - Uses INT 13h for disk operations
- **File Names** - Supports standard 8.3 format filenames

## Limitations

- NoX-OS currently runs in 16-bit real mode only
- Maximum file size is limited by available memory
- No memory management or protection
- No multitasking support

## Future Enhancements

Future versions may include:

- More robust file system implementation
- Support for more commands and utilities
- Long filename support
- Protected mode support
- Basic executable file support

## License

This project is open source and available under the MIT License.

## Acknowledgments

NoX-OS was inspired by various open-source OS development projects and educational resources.