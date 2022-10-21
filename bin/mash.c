#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <time.h>

int	i;

int main(int argc, char * argv[]){
	printf("fakemash run\n");
	printf("received %d parameters\n" , argc);
	for( i = 0; i < argc; i++ ){
		printf("  param %d: %s\n", i, argv[i]);
	}
	sleep(3);
	srand(time(NULL));
	if( argc == 4 ){
		for( i = 0; i < 32; i++ ){
			printf("%s\t%s\t%.4f\t%.4f\t%d/4096\n", argv[2], argv[3],
			(float)rand() / RAND_MAX, (float)rand() / RAND_MAX,
			rand() % 4096);
		}
	}else{
		printf("Received bad number of parameters: %d\n", argc);
	}
	return 0;
}
