file_addr: equ 0x100000

stdin: equ 0
stdout: equ 1

sys_read: equ 0
sys_write: equ 1
sys_open: equ 2
sys_close: equ 3
sys_lseek: equ 8
sys_exit: equ 60

SEEK_SET: equ 0
SEEK_CUR: equ 1

%macro syscall1 2
    mov rax, %1
    mov rdi, %2
    syscall
%endmacro

%macro syscall3 4
    mov rax, %1
    mov rdi, %2
    mov rsi, %3
    mov rdx, %4
    syscall
%endmacro

