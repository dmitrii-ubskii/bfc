.PHONY: build
build: compiler
compiler: compiler.asm *.inc
	nasm -f bin -o compiler compiler.asm
	chmod +x compiler
