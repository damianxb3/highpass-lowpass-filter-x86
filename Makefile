all: filter32 filter64

filter32: func32 main32
	gcc -g -m32 func.o main.o -o filter32  `pkg-config --cflags gtk+-2.0 pkg-config --libs gtk+-2.0`
	rm func.o main.o
main32: main.c
	gcc -g -m32 -c main.c -o main.o -Wall `pkg-config --cflags gtk+-2.0 pkg-config --libs gtk+-2.0`
func32: func32.s
	nasm -g -f elf32 func32.s -o func.o

filter64: func64 main64
	gcc -g func.o main.o -o filter64 `pkg-config --cflags gtk+-2.0 pkg-config --libs gtk+-2.0`
	rm func.o main.o
main64: main.c
	gcc -g -c main.c -o main.o -Wall `pkg-config --cflags gtk+-2.0 pkg-config --libs gtk+-2.0`

func64: func64.s
	nasm -g -f elf64 func64.s -o func.o

debug: func64
	gcc -g -c main_old.c -o main_old.o -Wall
	gcc -g func.o main_old.o -o filter_debug64