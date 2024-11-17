.PHONY: build
build: bfc
bfc: bfc.asm *.inc
	nasm -f bin -o bfc bfc.asm
	chmod +x bfc
