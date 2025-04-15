#!/bin/sh

set -xue

OBJCOPY=llvm-objcopy


cd $1
pwd 1>&2

$OBJCOPY --set-section-flags .bss=alloc,contents -O binary $2 build_shell.bin
$OBJCOPY -Ibinary -Oelf32-littleriscv build_shell.bin $3
