all: avalia

avalia: avalia.o meuAlocador.o
		gcc -c avalia.c -g
		gcc -c meuAlocador.s -g
		gcc -no-pie -static avalia.o meuAlocador.o -o avalia -g

clean:
	-rm avalia.o meuAlocador.o

purge: clean
	-rm avalia
