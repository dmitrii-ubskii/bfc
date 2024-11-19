[bits 64]

%include "defines.inc"

%include "headers.inc"

_start:
    ; expect filename
    mov rax, [rsp] ; argc
    cmp rax, 2
    jb exit_call

    ; open for reading
    syscall3 sys_open, [rsp + 8*2], 0, 0 ; argv[1], RDONLY, mode (ignored?)
    test rax, rax
    jz exit_call
    mov r15, rax ; r15 := input file fd

    ; open for writing
    syscall3 sys_open, file_addr + out_file, 0o1101, 0o754 ; argv[1], WRONLY + CREAT + TRUNC, rwxr-xr--
    test rax, rax
    jz exit_call
    mov r14, rax ; r14 := output file fd

    mov rax, sys_write
    mov rdi, r14
    mov rsi, file_addr + elf_header
    mov rdx, headers_end - elf_header
    syscall

    mov rax, sys_write
    mov rsi, file_addr + bf_setup
    mov rdx, bf_setup_end - bf_setup
    syscall

    sub rsp, 16 ; allocate 16 bytes on the stack
    mov r10, rsp ; r10 := buf

read_loop:
    syscall3 sys_read, r15, r10, 1 ; input file fd, buf, count
    cmp rax, 0
    jle exit

    mov al, [r10]
    mov rdi, r14
    
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
    mov rsi, file_addr + bf_inc
    mov rdx, bf_inc_end - bf_inc
    jmp perform_write

write_dec:
    mov rsi, file_addr + bf_dec
    mov rdx, bf_dec_end - bf_dec
    jmp perform_write

write_right:
    mov rsi, file_addr + bf_right
    mov rdx, bf_right_end - bf_right
    jmp perform_write

write_left:
    mov rsi, file_addr + bf_left
    mov rdx, bf_left_end - bf_left
    jmp perform_write

write_read:
    mov rsi, file_addr + bf_read
    mov rdx, bf_read_end - bf_read
    jmp perform_write

write_write:
    mov rsi, file_addr + bf_write
    mov rdx, bf_write_end - bf_write
    jmp perform_write

write_loop_start:
    ; record place to jump back to
    mov rax, sys_lseek
    mov rsi, 0
    mov rdx, SEEK_CUR
    syscall

    push rax

    ; write `test`
    mov rsi, file_addr + bf_test
    mov rdx, bf_test_end - bf_test
perform_write:
    mov rax, sys_write
    syscall
    jmp read_loop

write_loop_end:
    mov rax, sys_lseek
    mov rsi, 0
    mov rdx, SEEK_CUR
    syscall

    add rax, 5 ; account for   E9 cd    JMP near relative

    mov r12, rax ; r12 := location in file past the loop end

    pop r13 ; r13 := location in file of the loop start

    sub eax, r13d ; r12 - r13 == end - start
    neg eax       ; r13 - r12 == start - end
    push rax

    mov rax, sys_write
    mov rsi, file_addr + JMP
    mov rdx, 1
    syscall

    mov rax, sys_write
    mov rsi, rsp
    mov rdx, 4
    syscall

    pop rax
    neg eax
    sub eax, bf_test_end - bf_test ; account for rip pointing after test and je
    push rax

    add r13, bf_reserve_jz - bf_test

    mov rax, sys_lseek
    mov rsi, r13
    xor rdx, rdx ; SEEK_SET
    syscall

    mov rax, sys_write
    mov rsi, file_addr + JE
    mov rdx, 2
    syscall

    mov rax, sys_write
    mov rsi, rsp
    mov rdx, 4
    syscall

    pop r11

    mov rax, sys_lseek
    mov rsi, r12
    xor rdx, rdx ; SEEK_SET
    syscall

    jmp read_loop

exit:
    mov rdi, r14

    mov rax, sys_write
    mov rsi, file_addr + exit_call
    mov rdx, exit_call_end - exit_call
    syscall

    mov rax, sys_lseek
    mov rsi, 0
    mov rdx, SEEK_CUR
    syscall

    push rax

    mov rax, sys_write
    mov rsi, file_addr + string_table
    mov rdx, _end - string_table
    syscall

    mov rax, sys_lseek
    mov rsi, p_filesz
    xor rdx, rdx ; SEEK_SET
    syscall

    mov rax, sys_write
    syscall

    mov rax, sys_write
    syscall

    mov rax, sys_lseek
    mov rsi, _text_sh_size
    xor rdx, rdx ; SEEK_SET
    syscall
    
    mov rax, sys_write
    mov rsi, rsp
    mov rdx, 8
    syscall

    mov rax, sys_lseek
    mov rsi, _strings_sh_offset
    xor rdx, rdx ; SEEK_SET
    syscall

    mov rax, sys_write
    mov rsi, rsp
    mov rdx, 8
    syscall

    mov rax, sys_close
    syscall

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
    xor rax, rax ; sys_read
    xor rdi, rdi ; stdin
    mov rsi, r13
    mov rdx, 1
    syscall

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
