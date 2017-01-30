#!/bin/bash

qemu-system-x86_64 -d int -drive format=raw,file=build/kernel.iso -gdb tcp::1234
