[bits 64]

%include "defines.inc"

%include "headers.inc"

_start:
    ; expect filename
    mov rax, [rsp] ; argc
    cmp rax, 2
    jb exit_call

    ; open for reading
    stackmov rax, sys_open 
    mov rdi, [rsp + 8*2] ; argv[1]
    xor rsi, rsi ; RDONLY
    syscall

    test rax, rax
    jz exit_call
    mov r15, rax ; r15 := input file fd

    ; open for writing
    stackmov rax, sys_open 
    stackmov rdi, file_addr + out_file ; "a.out"
    mov rsi, 0o1101 ; WRONLY + CREAT + TRUNC
    mov rdx, 0o754 ; rwxr-xr--
    syscall

    test rax, rax
    jz exit_call
    mov r14, rax ; r14 := output file fd

    stackmov rax, sys_write 
    mov rdi, r14
    stackmov rsi, file_addr + elf_header
    mov rdx, headers_end - elf_header
    syscall

    stackmov rax, sys_write 
    stackmov rsi, file_addr + bf_setup
    stackmov rdx, bf_setup_end - bf_setup
    syscall

    mov r10, rsp ; r10 := buf

read_loop:
    xor rax, rax ; sys_read
    mov rdi, r15 ; input file
    mov rsi, r10 ; buf
    stackmov rdx, 1   ; count
    syscall

    test rax, rax
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
    stackmov rsi, file_addr + bf_inc
    stackmov rdx, bf_inc_end - bf_inc
    jmp perform_write

write_dec:
    stackmov rsi, file_addr + bf_dec
    stackmov rdx, bf_dec_end - bf_dec
    jmp perform_write

write_right:
    stackmov rsi, file_addr + bf_right
    stackmov rdx, bf_right_end - bf_right
    jmp perform_write

write_left:
    stackmov rsi, file_addr + bf_left
    stackmov rdx, bf_left_end - bf_left
    jmp perform_write

write_read:
    stackmov rsi, file_addr + bf_read
    stackmov rdx, bf_read_end - bf_read
    jmp perform_write

write_write:
    stackmov rsi, file_addr + bf_write
    stackmov rdx, bf_write_end - bf_write
    jmp perform_write

write_loop_start:
    ; record place to jump back to
    stackmov rax, sys_lseek 
    xor rsi, rsi
    stackmov rdx, SEEK_CUR
    syscall

    push rax

    ; write `test`
    stackmov rsi, file_addr + bf_test
    stackmov rdx, bf_test_end - bf_test
perform_write:
    stackmov rax, sys_write 
    syscall
    jmp read_loop

write_loop_end:
    stackmov rax, sys_lseek 
    xor rsi, rsi
    stackmov rdx, SEEK_CUR
    syscall

    add rax, 5 ; account for   E9 cd    JMP near relative

    mov r12, rax ; r12 := location in file past the loop end

    pop r13 ; r13 := location in file of the loop start

    sub eax, r13d ; r12 - r13 == end - start
    neg eax       ; r13 - r12 == start - end
    push rax

    stackmov rax, sys_write 
    stackmov rsi, file_addr + JMP
    stackmov rdx, 1
    syscall

    stackmov rax, sys_write 
    stackmov rsi, rsp
    stackmov rdx, 4
    syscall

    pop rax
    neg eax
    sub eax, bf_test_end - bf_test ; account for rip pointing after test and je
    push rax

    add r13, bf_test_jmp_target - bf_test

    stackmov rax, sys_lseek 
    mov rsi, r13
    xor rdx, rdx ; SEEK_SET
    syscall

    stackmov rax, sys_write 
    stackmov rsi, rsp
    stackmov rdx, 4
    syscall

    pop rax

    stackmov rax, sys_lseek 
    mov rsi, r12
    xor rdx, rdx ; SEEK_SET
    syscall

    jmp read_loop

exit:
    mov rdi, r14

    stackmov rax, sys_write 
    stackmov rsi, file_addr + exit_call
    stackmov rdx, exit_call_end - exit_call
    syscall

    stackmov rax, sys_lseek 
    xor rsi, rsi
    stackmov rdx, SEEK_CUR
    syscall

    push rax

    stackmov rax, sys_write 
    stackmov rsi, file_addr + string_table
    stackmov rdx, _end - string_table
    syscall

    stackmov rax, sys_lseek 
    stackmov rsi, p_filesz
    xor rdx, rdx ; SEEK_SET
    syscall

    stackmov rax, sys_write 
    syscall

    stackmov rax, sys_write 
    syscall

    stackmov rax, sys_lseek 
    stackmov rsi, _text_sh_size
    xor rdx, rdx ; SEEK_SET
    syscall
    
    stackmov rax, sys_write 
    mov rsi, rsp
    stackmov rdx, 8
    syscall

    stackmov rax, sys_lseek 
    stackmov rsi, _strings_sh_offset
    xor rdx, rdx ; SEEK_SET
    syscall

    stackmov rax, sys_write 
    stackmov rsi, rsp
    stackmov rdx, 8
    syscall

    stackmov rax, sys_close 
    syscall

    stackmov rax, sys_close 
    mov rdi, r15

exit_call:
    stackmov rax, sys_exit 
    xor rdi, rdi
    syscall
exit_call_end:

bf_setup:
    sub rsp, 1024 ; half tape
    mov r14, rsp  ; r14 := tape cursor
    sub rsp, 1024 ; half tape
    mov r13, rsp  ; r13 := read buffer
    xor al, al    ; al := current value at cursor
bf_setup_end:

bf_inc:
    inc al
bf_inc_end:

bf_dec:
    dec al
bf_dec_end:

bf_right:
    mov [r14], al
    inc r14
    mov al, [r14]
bf_right_end:

bf_left:
    mov [r14], al
    dec r14
    mov al, [r14]
bf_left_end:

bf_read:
    xor rax, rax ; sys_read
    xor rdi, rdi ; stdin
    mov rsi, r13
    stackmov rdx, 1
    syscall

    mov al, [r13]
bf_read_end:

bf_write:
    mov [r13], al
    stackmov rax, sys_write 
    stackmov rdi, stdout 
    mov rsi, r13 ; buf
    stackmov rdx, 1 ; count
    syscall
    mov al, [r13]
bf_write_end:

bf_test:
    test al, al
    db 0x0F, 0x84 ; JZ
bf_test_jmp_target:
    dd 0 ; rel32
bf_test_end:

JMP: db 0xE9
out_file:
    db "a.out", 0

string_table:
_text:
    db ".text", 0
_shstrtab:
    db ".shstrtab", 0

_end:
