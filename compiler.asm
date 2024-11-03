[bits 64]

%include "defines.inc"

%include "headers.inc"

_start:
    ; expect filename
    mov rax, [rsp] ; argc
    cmp rax, 2
    jb exit

    ; open for reading
    syscall3 sys_open, [rsp + 8*2], 0, 0 ; argv[1], RDONLY, mode (ignored?)
    cmp rax, 0
    js exit

    mov r15, rax ; r15

    sub rsp, 1 ; allocate 1 byte on the stack

read_loop:
    syscall3 sys_read, r15, rsp, 1 ; input file fd, buf, count
    cmp rax, 0
    je exit
    js exit

    syscall3 sys_write, stdout, rsp, 1 ; fd, buf, count
    jmp read_loop

exit:
    syscall1 sys_close, r15
    syscall1 sys_exit, 0

string_table:
_text:
    db ".text", 0
_shstrtab:
    db ".shstrtab", 0

_end:
