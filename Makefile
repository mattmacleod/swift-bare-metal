BUILDDIR=build

ASM_MODULES=src/boot.o src/long_mode.o
SWIFT_LIB=build/libkernel.a

SWIFTC=swiftc
LD=/usr/local/bin/x86_64-pc-elf-ld
AS=nasm
CC=clang

ASFLAGS=-felf64
LDFLAGS=-n --gc-sections -Tlink.ld -melf_x86_64
SWIFTFLAGS=-emit-ir -parse-as-library
CFLAGS=--target=x86_64-pc-elf -ffreestanding -Wno-override-module


.PHONY: all clean link iso

all: $(ASM_MODULES) $(SWIFT_LIB) link iso

$(SWIFT_LIB):
	$(SWIFTC) $(SWIFTFLAGS) -o build/libkernel.ll src/kernel.swift
	$(CC) $(CFLAGS) -c build/libkernel.ll -o $(SWIFT_LIB)

link:
	$(LD) $(LDFLAGS) -o $(BUILDDIR)/kernel $(ASM_MODULES) $(SWIFT_LIB)

iso:
	mkdir -p iso/boot/grub
	cp $(BUILDDIR)/kernel iso/boot
	cp grub.cfg iso/boot/grub
	grub-mkrescue -o build/kernel.iso iso

clean:
	rm -f $(ASM_MODULES)
	rm -f $(SWIFT_LIB)
