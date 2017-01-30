; This file does nothing other than call the kernel entry point.
; We keep it in a separate file so we don't end up calling 32-bit
; functions by accident.
bits 64

global long_mode_start
extern kmain

section .text
long_mode_start:
    call kmain
    hlt
