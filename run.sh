#!/bin/bash
set -xue

(cd disk && tar cf ../disk.tar --format=ustar *.txt)                          

mkdir -p build

# QEMU file path
QEMU=qemu-system-riscv32
OBJCOPY=llvm-objcopy

CC=clang
CFLAGS="-std=c11 -O2 -g3 -Wall -Wextra --target=riscv32-unknown-elf -fno-stack-protector -ffreestanding -nostdlib"


# Build the shell (application)
$CC $CFLAGS -Wl,-Tsrc/user.ld -Wl,-Map=build/shell.map -o build/shell.elf \
    src/shell.c src/user.c src/common.c
$OBJCOPY --set-section-flags .bss=alloc,contents -O binary build/shell.elf build/shell.bin
$OBJCOPY -Ibinary -Oelf32-littleriscv build/shell.bin build/shell.bin.o

$CC $CFLAGS -Wl,-Tsrc/kernel.ld -Wl,-Map=build/kernel.map -o build/kernel.elf \
    src/kernel.c src/common.c build/shell.bin.o

# Start QEMU
$QEMU -machine virt -bios default -nographic -serial mon:stdio --no-reboot \
    -d unimp,guest_errors,int,cpu_reset -D qemu.log \
    -drive id=drive0,file=disk.tar,format=raw,if=none \
    -device virtio-blk-device,drive=drive0,bus=virtio-mmio-bus.0 \
    -kernel build/kernel.elf 
