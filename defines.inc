file_addr: equ 0x100000

stdout: equ 1

sys_read: equ 0
sys_write: equ 1
sys_open: equ 2
sys_close: equ 3
sys_lseek: equ 8
sys_exit: equ 60

SEEK_CUR: equ 1

%macro stackmov 2
    push %2
    pop %1
%endmacro

