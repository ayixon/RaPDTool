#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>

char	filename[128], outfolder[64], command[96], rnum[8];
int	i;
FILE	* fh;

int main(int argc, char * argv[]){
	printf("fakeBinning_refiner run\n");
	printf("received %d parameters\n" , argc);
	for( i = 0; i < argc; i++ ){
		printf("  param %d: %s\n", i, argv[i]);
	}
	srand(time(NULL));
	if( argc == 6 && strcmp(argv[3], "-p") == 0 ){
		strcpy(outfolder, argv[4]);
		strcat(outfolder, "_Binning_refiner_outputs/");

		strcpy(command, "mkdir ");
		strcat(command, outfolder);
		system(command);

		strcpy(filename, outfolder);
		strcat(filename, argv[4]);
		strcat(filename, "_sources_and_length.txt");
		fh = fopen(filename, "w");
		fprintf(fh, "%s content\n", filename);
		fclose(fh);

		strcpy(filename, outfolder);
		strcat(filename, argv[4]);
		strcat(filename, "_contigs.txt");
		fh = fopen(filename, "w");
		fprintf(fh, "%s content\n", filename);
		fclose(fh);

		strcpy(filename, outfolder);
		strcat(filename, argv[4]);
		strcat(filename, "_sankey.csv");
		fh = fopen(filename, "w");
		fprintf(fh, "%s content\n", filename);
		fclose(fh);

		strcpy(filename, outfolder);
		strcat(filename, argv[4]);
		strcat(filename, "_sankey.html");
		fh = fopen(filename, "w");
		fprintf(fh, "<html><head><title>sankey</title></head><body>%s content</body></html>\n", filename);
		fclose(fh);

		strcat(outfolder, argv[4]);
		strcat(outfolder, "_refined_bins/");
		strcpy(command, "mkdir ");
		strcat(command, outfolder);
		system(command);

		for( i = 0; i < 6; i++ ){
			strcpy(filename, outfolder);
			strcat(filename, "refined_");
			sprintf(rnum, "%04d", rand() % 10000);
			strcat(filename, rnum);
			strcat(filename, ".fabin");
			fh = fopen(filename, "w");
			fprintf(fh, "%s content\n", filename);
			fclose(fh);
		}
		printf("outputs were made\n");
	}else{
		printf("Received bad number of parameters: %d\n", argc);
	}
	return 0;
}
