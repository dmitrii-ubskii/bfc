.PHONY: build
build: compiler
compiler: compiler.asm
	nasm -f bin -o compiler compiler.asm
	chmod +x compiler
