# Swfit on bare metal

This is a project to experiment with getting Swift to run on bare metal.

At the moment, it uses Multiboot to set up the machine and jump into a function
defined in Swift. Using the Swift compiler to emit LLVM IR, we can then use
Clang to build it bare metal.

Since Swift is heavily dependent on the runtime for things like arrays,
static variables, enumeration etc. this is going to take a looooooot of work,
and it can't currently do anything except print a sassy message.


# Running it

You'll need Clang, a binutils toolchain for x86_64-pc-elf, QEMU and a copy of
Grub installed. This is painful to get set up on a mac (more details to come).

You can then use the makefile and the run_qemu script to boot.
