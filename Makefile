# Makefile to compile the storage management assembly tasks

all: task1 task2

# Compile the 1D case (vector.s) into ./task1
task1: vector.s
	gcc -m32 -no-pie vector.s -o task1

# Compile the 2D case (matrice.s) into ./task2
task2: matrice.s
	gcc -m32 -no-pie matrice.s -o task2

# Clean up binaries
clean:
	rm -f task1 task2