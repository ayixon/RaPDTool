# RaPDTool: Rapid Profiling and Deconvolution Tool for metagenomes

![image](https://user-images.githubusercontent.com/42699236/138326365-ee9d2440-dc2c-48a9-9b13-ea2bccf0eea1.png)


# RaPDTool offer a simple and easy-to-use tool for microbial communities profiling, contigs binning and "genomic-distance" exploration by connecting a series of bioinformatic tools in a single workflow:

# 1. Generate a taxonomic profile from massive sequencing data (fasta short reads, metagenome assemblies).

RaPDTool use raw reads or metagenomic assemblies and call FOCUS profiler to report the organisms/abundance present in the metagenome.


# 2. Deconvolve a metagenome into individual genomes or bins, and refine the set of MAGs.

If the input consist on a metagenome assembly, RaPDTool automatically call Metabat2  to aggregate individual genome bins. The bins are subsequently refined with Binning_refiner
(https://github.com/songweizhi/Binning_refiner) to produce a non-redundant set.

# 3. Evaluate the probable "taxonomic neighborhoods" of each resulting genome bin.

RaPDTool compare each bin against curated taxonomic mash databases like type material genome database (https://figshare.com/ndownloader/files/30851626). Alternatively it can be compared against the database Gtdb-r202 (https://figshare.com/ndownloader/files/30863182). Both databases are offered as representations or sketches that reduce
storage space and computing time.

# Dependencies:

FOCUS (https://github.com/metageni/FOCUS)

Metabat2 (https://bitbucket.org/berkeleylab/metabat/src/master/)

Binning_refiner (https://github.com/songweizhi/Binning_refiner)

Mash  (https://github.com/marbl/Mash)

# How to install:
RaPDTool it is written in python and runs natively by calling the script:
  rapdtool.py
  
  Also you will need the accompanying C scripts
  
# Usage: 
  rapdtool.py [-h] [-i INPUT] [-d DATABASE] [-r ROOT] [-c COMMENT]

  Focus/Metabat/Binning_refiner/Mash (fmbm) script

  optional arguments:
    -h, --help            show this help message and exit
    
    -i INPUT, --input INPUT
                        process this file
                        
    -d DATABASE, --database DATABASE
                        use this database
                        
    -r ROOT, --root ROOT  fmbm root subdirectory (default: user home)
    
    -c COMMENT, --comment COMMENT
                        "comment for this execution"
                        
                        example : ./rapdtool.py -i INPUT.fasta -d DATABASE.msh -r OUTPUT_FOLDER
                        
                        Database currently available:
                        NCBI Prokaryotic type material genomes (https://figshare.com/ndownloader/files/30851626)
                        Gtdb-r202 (https://figshare.com/ndownloader/files/30863182) 
                        
# Output files:

The RaPDTool output is stored in the $HOME directory. The -r option allows to assign a name to the output folder.
The pipeline results are stored in subdirectories easily identifiable by the user: 

genomadb: user database 

input: input metagenome

profiles: Focus profiling results 

result: Metabat and Binning_refiner result

workf: Summary mash distance calculation

RaPDTool produces individual mash comparisons for every genome bin obtained against the user database (If you select prokaryotic NCBI Type Material DB there will be near to 17,000 records, GTDB contains many more). For this reason, the subdirectory "allresults" contain the ten closest hits from the mash paired comparison for each genome. This simplifies the interpretation of the results by limiting the Mash comparison to the ten closest neighbors to the query, which can be useful in phylogenetics and taxonomy. The user can take this list as the basis for a finer comparison by estimating the Overall genome relatedness index (OGRI) like ANI.

# References:

Sánchez-Reyes, A.; Fernández-López, M.G. Mash Sketched Reference Dataset for Genome-Based Taxonomy and Comparative Genomics. Preprints 2021, 2021060368 (doi: http://dx.doi.org/10.20944/preprints202106.0368.v1).

Mash: fast genome and metagenome distance estimation using MinHash. Ondov BD, Treangen TJ, Melsted P, Mallonee AB, Bergman NH, Koren S, Phillippy AM. Genome Biol. 2016 Jun 20;17(1):132. doi: 10.1186/s13059-016-0997-x.

Silva, G. G. Z., D. A. Cuevas, B. E. Dutilh, and R. A. Edwards, 2014: FOCUS: an alignment-free model to identify organisms in metagenomes using non-negative least squares. PeerJ, 2, e425, doi:10.7717/peerj.425.

Song WZ, Thomas T (2017) Binning_refiner: Improving genome bins through the combination of different binning programs. Bioinformatics, 33(12), 1873-1875. 

Kang, D. D., Li, F., Kirton, E., Thomas, A., Egan, R., An, H., & Wang, Z. (2019). MetaBAT 2: an adaptive binning algorithm for robust and efficient genome reconstruction from metagenome assemblies. PeerJ, 7, e7359. https://doi.org/10.7717/peerj.7359.

