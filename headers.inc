elf_header:
    db 0x7f, 'E', 'L', 'F' ; EI_MAG: ELF magic number
    db 2 ; EI_CLASS: 64 bit
    db 1 ; EI_DATA: little-endian
    db 1 ; EI_VERSION: ELF v1
    db 3 ; EI_OSABI: Linux ABI
    dq 0 ; EI_ABIVERSION: ABI version (ignored on Linux) + EI_PAD: padding
    dw 2 ; e_type = ET_EXEC: executable file type
    dw 0x3e ; e_machine: x86-64
    dd 1 ; e_version: ELF v1
    dq _start + file_addr ; e_entry: entry point
    dq program_header ; e_phoff: start of the program header table
    dq section_headers ; e_shoff: start of the section header table
    dd 0 ; e_flags
    dw program_header ; e_ehsize: size of this header
    dw section_headers - program_header ; e_phentsize: size of a program header table entry
    dw 1 ; e_phnum: number of entries in the program header table
    dw strings - section_headers ; e_shentsize: size of a section header table entry
    dw 2 ; e_shnum: number of entries in the section header table
    dw 1 ; e_shstrndx: index of the section header table entry that contains the section names

program_header:
    dd 1 ; p_type = PT_LOAD: loadable segment
    dd 5 ; p_flags = PF_X | PF_R
    dq 0 ; p_offset: offset of the segment
    dq file_addr ; p_vaddr: virtual address of the segment in memory
    dq file_addr ; p_paddr: physical address
p_filesz:
    dq string_table ; p_filesz: size in bytes of the segment in the file
p_memsz:
    dq string_table ; p_memsz: size in bytes of the segment in memory
    dq 0 ; p_align: no alignment

section_headers:

text:
    dd _text - string_table ; section name
    dd 1 ; sh_type = SHT_PROGBITS 
    dq 6 ; sh_flags = SHF_EXECINSTR | SHF_ALLOC
    dq file_addr ; sh_addr 
    dq 0 ; sh_offset
_text_sh_size:
    dq string_table ; sh_size
    dd 0 ; sh_link
    dd 0 ; sh_info
    dq 0x10 ; sh_addralign
    dq 0 ; sh_entsize

strings:
    dd _shstrtab - string_table ; section name
    dd 3 ; sh_type = SHT_STRTAB 
    dq 0 ; sh_flags = NULL
    dq file_addr + string_table ; sh_addr 
_strings_sh_offset:
    dq string_table ; sh_offset
    dq _end - string_table ; sh_size
    dd 0 ; sh_link
    dd 0 ; sh_info
    dq 1 ; sh_addralign
    dq 0 ; sh_entsize

headers_end:
