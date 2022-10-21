#include <stdio.h>
#include <string.h>
#include <stdlib.h>

char	filename[128], rnum[8];
int	i;
FILE	* fh;

int main(int argc, char * argv[]){
	printf("fakemetabat2 run\n");
	printf("received %d parameters\n" , argc);
	for( i = 0; i < argc; i++ ){
		printf("  param %d: %s\n", i, argv[i]);
	}
	if( argc == 7 && strcmp(argv[5], "-o") == 0 ){
		for( i = 0; i < 6; i++ ){
			strcpy(filename, argv[6]);
			strcat(filename, "metabin_");
			sprintf(rnum, "%04d", rand() % 10000);
			strcat(filename, rnum);
			strcat(filename, ".fna");
			fh = fopen(filename, "w");
			fprintf(fh, "%s content\n", filename);
			fclose(fh);
		}
		printf("6 outputs were made\n");
	}else{
		printf("Received bad number of parameters: %d\n", argc);
	}
	return 0;
}
