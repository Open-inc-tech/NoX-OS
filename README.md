# NoX-OS

NoX-OS is a simple but practical 16-bit operating system inspired by MS-DOS 5, written entirely in x86 assembly language. It runs in real mode on basic PC hardware and provides essential OS features such as a command line interface, file management, and a text editor.

---

## What is NoX-OS?

NoX-OS is a small educational operating system designed to run on real-mode x86 PCs. It features:

- A custom bootloader that loads the kernel from disk
- FAT12 file system support for reading and navigating files
- A command-line shell similar to classic DOS commands
- Basic file management commands like `DIR`, `DEL`, `TYPE`, `CD`
- A simple text editor to create and edit files
- Console I/O handled via BIOS interrupts
- Modular, clean assembly code structure

NoX-OS is a project to learn and demonstrate OS development concepts on very simple hardware.

---

## How to Build NoX-OS

You need the following tools installed on your development machine:

- [NASM](https://www.nasm.us/) assembler
- `dd` (data duplicator) for creating disk images (Linux/macOS) or similar tool on Windows
- [QEMU](https://www.qemu.org/) emulator for testing the OS in a virtual environment

### Steps:

1. Clone or download the repository.

2. Open a terminal in the project directory.

3. Make the build script executable:

    ```bash
    chmod +x build.sh
    ```

4. Run the build script to assemble the bootloader and kernel, and create a bootable floppy image:

    ```bash
    ./build.sh
    ```

This will generate a floppy disk image file `build/noxos.img`.

---

## How to Run NoX-OS

You can run NoX-OS in QEMU, a popular emulator that simulates PC hardware.

1. Make the run script executable:

    ```bash
    chmod +x run.sh
    ```

2. Run NoX-OS inside QEMU with:

    ```bash
    ./run.sh
    ```

This will start the virtual machine and boot NoX-OS from the floppy image.

---

## Using NoX-OS

Once booted, you will see a command prompt similar to DOS. You can use commands like:

- `HELP` — List all available commands
- `DIR` — List files in the current directory
- `TYPE filename` — Display contents of a text file
- `EDIT filename` — Open simple text editor to create or modify a file
- `DEL filename` — Delete a file
- `CD directory` — Change directory
- `CLS` — Clear the screen
- `VER` — Show OS version
- `EXIT` — Restart the system

NoX-OS supports standard 8.3 filename format and FAT12 filesystem, allowing compatibility with other DOS-based systems.

---

## Project Structure

- `src/boot/` — Bootloader code  
- `src/kernel/` — Kernel and core OS functions  
- `src/include/` — Shared constants and macros  
- `build.sh` — Build script (assembles code, creates image)  
- `run.sh` — Runs the OS in QEMU emulator  

---

## Limitations

- NoX-OS runs only in 16-bit real mode (no protected mode)  
- It does not support multitasking or memory protection  
- Maximum file size is limited by available memory  
- Only basic command-line interface is provided  

---

## Future Plans

- Add support for longer filenames  
- Implement protected mode and memory management  
- Add executable file loading and running  
- Provide basic multitasking capabilities  
- Extend the set of commands and utilities  

---

## License

NoX-OS is open source and released under the MIT License.

---

## Acknowledgments

This project is inspired by MS-DOS architecture, various open source OS projects, and educational materials on operating system development and x86 assembly.

---

Feel free to explore, modify, and learn from the NoX-OS codebase! If you find issues or want to contribute, please submit pull requests or open issues.
