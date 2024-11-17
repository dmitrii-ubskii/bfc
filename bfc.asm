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
    mov r15, rax ; r15 := input file fd

    ; open for writing
    syscall3 sys_open, file_addr + out_file, 0o1101, 0o754 ; argv[1], WRONLY + CREAT + TRUNC, rwxr-xr--
    cmp rax, 0
    js exit
    mov r14, rax ; r14 := output file fd

    syscall3 sys_write, r14, file_addr + elf_header, headers_end - elf_header
    syscall3 sys_write, r14, file_addr + bf_setup, bf_setup_end - bf_setup

    sub rsp, 16 ; allocate 16 bytes on the stack
    mov r10, rsp ; r10 := buf

read_loop:
    syscall3 sys_read, r15, r10, 1 ; input file fd, buf, count
    cmp rax, 0
    jle exit

    mov al, [r10]
    
    cmp al, '+'
    je write_inc

    cmp al, '-'
    je write_dec

    cmp al, '>'
    je write_right

    cmp al, '<'
    je write_left

    cmp al, ','
    je write_read

    cmp al, '.'
    je write_write

    cmp al, '['
    je write_loop_start

    cmp al, ']'
    je write_loop_end

    jmp read_loop

write_inc:
    syscall3 sys_write, r14, file_addr + bf_inc, bf_inc_end - bf_inc
    jmp read_loop

write_dec:
    syscall3 sys_write, r14, file_addr + bf_dec, bf_dec_end - bf_dec
    jmp read_loop

write_right:
    syscall3 sys_write, r14, file_addr + bf_right, bf_right_end - bf_right
    jmp read_loop

write_left:
    syscall3 sys_write, r14, file_addr + bf_left, bf_left_end - bf_left
    jmp read_loop

write_read:
    syscall3 sys_write, r14, file_addr + bf_read, bf_read_end - bf_read
    jmp read_loop

write_write:
    syscall3 sys_write, r14, file_addr + bf_write, bf_write_end - bf_write
    jmp read_loop

write_loop_start:
    ; record place to jump back to
    syscall3 sys_lseek, r14, 0, SEEK_CUR
    push rax

    ; write `test`
    syscall3 sys_write, r14, file_addr + bf_test, bf_test_end - bf_test

    jmp read_loop

write_loop_end:
    syscall3 sys_lseek, r14, 0, SEEK_CUR
    add rax, 5 ; account for   E9 cd    JMP near relative

    mov r12, rax ; r12 := location in file past the loop end

    pop r13 ; r13 := location in file of the loop start

    sub eax, r13d ; r12 - r13 == end - start
    neg eax       ; r13 - r12 == start - end
    push rax

    syscall3 sys_write, r14, file_addr + JMP, 1
    syscall3 sys_write, r14, rsp, 4

    pop rax
    neg eax
    sub eax, bf_test_end - bf_test ; account for rip pointing after test and je
    push rax

    add r13, bf_reserve_jz - bf_test
    syscall3 sys_lseek, r14, r13, SEEK_SET

    syscall3 sys_write, r14, file_addr + JE, 2
    syscall3 sys_write, r14, rsp, 4
    pop r11

    syscall3 sys_lseek, r14, r12, SEEK_SET

    jmp read_loop

exit:
    syscall3 sys_write, r14, file_addr + exit_call, exit_call_end - exit_call
    syscall3 sys_lseek, r14, 0, SEEK_CUR
    push rax
    syscall3 sys_write, r14, file_addr + string_table, _end - string_table
    syscall3 sys_lseek, r14, p_filesz, SEEK_SET
    syscall3 sys_write, r14, rsp, 8
    syscall3 sys_write, r14, rsp, 8
    syscall3 sys_lseek, r14, _text_sh_size, SEEK_SET
    syscall3 sys_write, r14, rsp, 8
    syscall3 sys_lseek, r14, _strings_sh_offset, SEEK_SET
    syscall3 sys_write, r14, rsp, 8
    syscall1 sys_close, r14
    syscall1 sys_close, r15

exit_call:
    syscall1 sys_exit, 0
exit_call_end:

bf_setup:
    sub rsp, 2048 ; tape
    mov r14, 1024 ; r14 := tape cursor
    mov r12, rsp  ; r12 := tape start
    xor rax, rax  ; rax := current value at cursor
    sub rsp, 16   ; read buffer, keep aligned to 16 bytes
    mov r13, rsp  ; r13 := read buffer
bf_setup_end:

bf_inc:
    inc al
bf_inc_end:

bf_dec:
    dec al
bf_dec_end:

bf_right:
    mov [r12 + r14], al
    inc r14
    mov al, [r12 + r14]
bf_right_end:

bf_left:
    mov [r12 + r14], al
    dec r14
    mov al, [r12 + r14]
bf_left_end:

bf_read:
    syscall3 sys_read, stdin, r13, 1 ; fd, buf, count
    mov al, [r13]
bf_read_end:

bf_write:
    mov [r13], al
    syscall3 sys_write, stdout, r13, 1 ; fd, buf, count
    mov al, [r13]
bf_write_end:

bf_test:
    test al, al
bf_reserve_jz:
    dw 0 ; 0F 84
    dd 0 ; rel32
bf_test_end:

JMP: db 0xE9
JE: db 0x0F, 0x84

out_file:
    db "a.out", 0

string_table:
_text:
    db ".text", 0
_shstrtab:
    db ".shstrtab", 0

_end:
