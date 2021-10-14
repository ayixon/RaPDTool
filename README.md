# RaPDTool

Rapid Profiling and Deconvolution Tool for metagenomes

RaPDTool offer a simple and easy-to-use tool for community profiling, binning and "genome-distance" exploration by connecting a series of bioinformatics tools in a single workflow:

# 1. Generate a taxonomic profile from massive sequencing data (fasta short reads, metagenome assemblies).

RaPDTool use raw reads or metagenomic assemblies and call FOCUS profiler to report the organisms/abundance present in the metagenome.


# 2. Deconvolve a metagenome into individual genomes or bins.

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
                        
# Output files:

The RaPDTool output is stored in the $HOME directory. The -r option allows to assign a name to the output folder.
The pipeline results are stored in subdirectories easily identifiable by the user: 

genomadb: user database 

input: input metagenome

profiles: Focus profiling results 

result: Metabat and Binning_refiner result

workf: Summary mash distance calculation
