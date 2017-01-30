; boot.s
;
; Initial OS boot code
;;;;;;;;;;;;;;;;;;;;;;

; x86_64 CPUs start in 32-bit protected mode. We run in this mode
; and define a seperate long mode (64-bit) entry point in an external
; file so it's kept separate.
bits 32
extern long_mode_start

; Define some useful constants to make the code below more readable
MULTIBOOT_HEADER_MAGIC equ 0xE85250D6
MULTIBOOT_ARCH         equ 0
MULTIBOOT_HEADER_SIZE  equ multiboot_header_end - multiboot_header_start
MULTIBOOT_CHECKSUM     equ 0x100000000 - (MULTIBOOT_HEADER_MAGIC + MULTIBOOT_ARCH + MULTIBOOT_HEADER_SIZE)

MULTIBOOT_MAGIC_TEST equ 0x36d76289

; Error codes for debug output if bootstrap fails
ERR_NO_MULTIBOOT equ 0x0
ERR_NO_LONG_MODE equ 0x1

; Create a multiboot2-compliant header as the first set of values
; in the kernel binary. This indicates to our bootloader (i.e. GRUB)
; that this binary is compliant.
section .multiboot_header
multiboot_header_start:
  dd  MULTIBOOT_HEADER_MAGIC ; A magic value to indicate we are MB-compliant
  dd  MULTIBOOT_ARCH         ; The architecture of this file
  dd  MULTIBOOT_HEADER_SIZE  ; The total size of the header
  dd  MULTIBOOT_CHECKSUM     ; Checksum as calculated above

  ; Additional multiboot tags would go here.
  ; http://nongnu.askapache.com/grub/phcoder/multiboot.pdf for details
multiboot_header_end:


; This is the main entry point that the bootloader will call.
section .text
global start
start:
    ; Check that bootstrapping will be successful
    ;   - Were we booted with a multiboot-compliant loader?
    ;   - Does the CPU support long mode?
    ;
    ; If either of these tests fail then we will error out.
    call test_multiboot
    call test_long_mode

    ; Move the stack pointer to the top of our stack
    mov esp, stack_top

    ; In order to switch to long mode, we have to build our page tables – the
    ; CPU will immediately start using paging when we switch, so we need the
    ; setup in-place.
    call setup_page_tables
    call enable_paging

    lgdt [gdt64.pointer]
    mov ax, 16
    mov ss, ax
    mov ds, ax
    mov es, ax
    jmp gdt64.code:long_mode_start


; Checks that we were actually loaded by a multiboot-compliant bootloader, as
; we are about to use some multiboot-specific options
test_multiboot:
    cmp eax, MULTIBOOT_MAGIC_TEST
    jne test_multiboot_failed
    ret
test_multiboot_failed:
    mov al, ERR_NO_MULTIBOOT
    jmp error


; Uses CPUID to check that long mode (64-bit) is supported. Note that this
; could potentially fail if we try to boot it on a 486 or lower processor, since
; these do not include the CPUID instruction. But I think we can assume we
; aren't going to do that.
test_long_mode:
    ; Request extent of CPUID support first.
    mov eax, 0x80000000
    cpuid

    ; If CPUID does not set an extended response value, we know there is no
    ; long mode available anyway.
    cmp eax, 0x80000001
    jb test_long_mode_failed

    ; Request the extended CPU feature flag set
    mov eax, 0x80000001
    cpuid

    ; Bit 29 in EDX now indicates if long mode is supported
    test edx, 1 << 29
    jz test_long_mode_failed
    ret

test_long_mode_failed:
    mov al, ERR_NO_LONG_MODE
    jmp error


; Basic error handler – display the word error and an 8-bit error code.
; The code is offset by 0x30 to become an ASCII character that we can print –
; this would give us up to 10 error codes.
error:
    add al, 0x30
    mov byte  [0xb800f], 0x4f         ; Set color to white-on-red
    mov byte  [0xb800e], al           ; Display the error code
    mov dword [0xb800a], 0x4f204f20   ; Display the string 'ERROR: '
    mov dword [0xb8008], 0x4f3a4f52   ;
    mov dword [0xb8004], 0x4f4F4f52   ;
    mov dword [0xb8000], 0x4f524f45   ;
    hlt                               ; Goodnight, sweet prince


setup_page_tables:
    ; Map the first page of the PDP table into the PML4 table, and set the
    ; 'present' and 'writable' flags (bits 0 and 1)
    mov eax, pdp_table
    or eax, 0b11
    mov [pml4_table], eax

    ; Map the first entry of the PD table into the PDP table, also marking it
    ; as 'present' and 'writeable'
    mov eax, pd_table
    or eax, 0b11
    mov [pdp_table], eax

    ; Use ECX as the counter for the loop we are about to start
    mov ecx, 0


; Loop through each entry in the PD table and map it to a memory page. We are
; using 2MB pages (i.e. with the 'huge' flag in bit 7 set)
map_pd_table:
    mov eax, 0x200000  ; 2MiB pages
    mul ecx            ; counter * page size = page start address
    or eax, 0b10000011
    mov [pd_table + ecx * 8], eax

    ; Loop over the whole PD table until it's mapped (512 entries)
    inc ecx
    cmp ecx, 512       
    jne map_pd_table

    ; The page tables are now set up
    ret


enable_paging:
    ; enable PAE so we can support up to 64GB of RAM
    ; TODO: PSE? PGE?
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; Store the entry address of the PML4 table
    mov eax, pml4_table
    mov cr3, eax

    ; Enable long mode in the MSR (model-specific register)
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Turn on paging
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ; Paging is enabled!
    ret


; We need to define an empty GDT. For whatever legacy reason, this is
; required.
;
; The GDT is
;   - One zero entry
;   - n additional segment entries
;
; in the case of a long mode GDT, these are zero with the appropriate flags
; set to indicate what they do
section .rodata
gdt64:
    dq 0
.code: equ $ - gdt64
    dq (1<<44) | (1<<47) | (1<<41) | (1<<43) | (1<<53)
.data: equ $ - gdt64
    dq (1<<44) | (1<<47) | (1<<41)
.pointer:
    dw $ - gdt64 - 1
    dq gdt64


; Create the stack and page tables at the end of the image
section .bss
align 4096
pml4_table:
    resb 4096
pdp_table:
    resb 4096
pd_table:
    resb 4096
stack_bottom:
    resb 4096
stack_top:
