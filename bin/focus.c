#include <stdio.h>
#include <string.h>

char	filename[128];
int	i;
char	taxa[][32] = { "bacteria", "fungus", "microbe", "plancton", "insect",
	"parasite", "eukariote", "virus", "fungus", "amoeba" };
FILE	* fh, * fg;

int main(int argc, char * argv[]){
	if( argc == 7 && strcmp(argv[5], "-l") == 0 ){
		fh = fopen(argv[6], "w");
		fprintf(fh,"fakefocus run\n");
		fprintf(fh,"received %d parameters\n" , argc);
		for( i = 0; i < argc; i++ ){
			fprintf(fh,"  param %d: %s\n", i, argv[i]);
		}
		if( strcmp(argv[3], "-o") == 0 ){
			strcpy(filename, argv[4]);
			strcat(filename, "output_All_levels.csv");
			fg = fopen(filename, "w");
			fprintf(fg, "Nada\n");
			fclose(fg);
			fprintf(fh,"faking 10 taxa outputs\n");
			for( i = 0; i < 10; i++ ){
				strcpy(filename, argv[4]);
				strcat(filename, "output_");
				strcat(filename, taxa[i]);
				strcat(filename, "_tabular.csv");
				fg = fopen(filename, "w");
				fprintf(fg, "%s content\n", taxa[i]);
				fclose(fg);
			}
			fprintf(fh,"outputs were made\n");
		}
		fclose(fh);
	}else{
		printf("Received bad number of parameters: %d\n", argc);
	}
	return 0;
}
