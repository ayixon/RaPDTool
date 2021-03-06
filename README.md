# RaPDTool: Rapid Profiling and Deconvolution Tool for metagenomes

![RaPDTool_pipeline_600ppi](https://user-images.githubusercontent.com/42699236/163837963-9394db95-a232-4b6e-92d7-d5b6bc90cdd2.png)


# RaPDTool offer a simple and easy-to-use tool for microbial communities profiling, contigs binning and "genomic-distance" exploration by connecting a series of bioinformatic tools in a single workflow:

# 1. Generate a taxonomic profile from massive sequencing data (the input file shoul be a metagenome assembly).

RaPDTool use metagenomic assemblies and call FOCUS profiler to report the organisms/abundance present in the metagenome.

*Warning: Taxonomic profiles are usually inferred from raw reads; assembled-contigs profiling is an "special case" in order to explore what part of the community could be assembled into regular genomic composites. Use at your own risk :)

# 2. Deconvolve a metagenome into individual genomes or bins, and refine the set of MAGs.

If the input consist on a metagenome assembly, RaPDTool automatically call Metabat2  to aggregate individual genome bins. The bins are subsequently refined with Binning_refiner
(https://github.com/songweizhi/Binning_refiner) to produce a non-redundant set.

# 3. Estimate Completeness, Redundancy and MAG basic statistics with miComplete
 
 In the version 2.0 of this pipeline, the refined set of bins are automatically processed with miComplete (https://github.com/EricHugo/miComplete), a much faster tool than CheckM for this purpose. 
 
# 4. Evaluate the probable "taxonomic neighborhoods" of each resulting genome bin.

RaPDTool compare each bin against curated taxonomic mash databases like type material genome database (https://figshare.com/ndownloader/files/30851626). Alternatively it can be compared against the database Gtdb-r202 (https://figshare.com/ndownloader/files/30863182). Both databases are offered as representations or sketches that reduce
storage space and computing time.

# Dependencies:

FOCUS (https://github.com/metageni/FOCUS)

Metabat2 (https://bitbucket.org/berkeleylab/metabat/src/master/) (version tested 2:2.15)

Binning_refiner (https://github.com/songweizhi/Binning_refiner)

miComplete (https://github.com/EricHugo/miComplete)

Mash  (https://github.com/marbl/Mash)

RaPDTool also depends on a preconfigured database; for convenience the user can download and use any of the following:

  Databases currently available:
  
                        NCBI Prokaryotic type material genomes (https://figshare.com/ndownloader/files/30851626)
                        
                        Gtdb-r202 (https://figshare.com/ndownloader/files/30863182) 

# How to install:
RaPDTool it is written in python and runs natively by calling the script:
  rapdtool.py
  
  Also you will need the accompanying C scripts and the depenencies installed in your system. 
  
  A simple way to get all the dependencies ready is through the conda package manager:

    $ conda install focus metabat2 binning_refiner miComplete mash 
    
  If you prefer you can create an environment and set everything within it:

    $ conda create -n rapdtool

    $ conda activate rapdtool

    $ conda install focus metabat2 binning_refiner miComplete mash
  
 After that, clone this repository in your prefered folder and excute the python script
    
  
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
                        
                    example : $ ./rapdtool.py -i INPUT.fasta -d DATABASE.msh -r OUTPUT_FOLDER
                        
                      
                        
# Output directories and files

The output of RaPDTool produces 8 main directories:

![image](https://user-images.githubusercontent.com/42699236/170735788-3aed46d1-d593-451a-bf35-cf16c29eaf18.png)

### The fmbm directory

Contains the log file of the RaPDTool execution (logfmbm.txt).

**fmbm** is a kind of acronym that includes the main operations of the pipeline (Focus/Metabat/Binning_refiner/Mash).

### The genomadbfmbm directory

Contains the reference database used for running RaPDTool.

### The processedfmbm directory

Contains the assembly used for running RaPDTool.

***
## What about the results?

### The directory _**profilesfmbm**_ 

Store the FOCUS taxonomic profile inferred from the inputs (metagenome assembly). You should see 
several files -in tabular format (csv)- reporting relative abundance from Kingdom to Species . FOCUS also ventures to infer Strains, but I would be cautious at that taxonomic level.


### Some points to note with this result:

1-We could assume that the short-reads contain a "genomic space" more representative of the community, than that contained in the assembly; the assembly _per se_ supposes a loss of taxonomic information. Assembled contigs profiling only represents an approximation of taxonomic composition at the genomic level, so be cautious with the interpretations.

2-The native FOCUS database plays an important role in the accuracy of the profile. The initial launch of FOCUS considered 2,766 reference genomes to build a kmer frecuencies database ( _k_ = 6; _k_ = 7)  . For the implementation of RaPDTool, we have considered 14,551 genomes from the Type Material to give taxonomic certainty to the profiles, while enriching the initial database. 

The new  _k_ = 6; _k_ = 7 kmer archives for updating FOCUS database will be available on: https://drive.google.com/uc?export=download&id=1AOOwhmhg9Zn5iYrOs9j36cBZZTIupPbC

![image](https://user-images.githubusercontent.com/42699236/170603717-eb9f8047-6bfa-4a89-85b2-0fa34c6c7e7e.png)


***
 ### The directory _**workfmbm**_ 

Contains several relevant subdirectories and files:

**binmetabat**/  > Store Metabat2 binning results. The genome composites aggregated from the initial metagenomic assembly

**outbinningref**/ > Binning_refiner results. All bins obtained with Metabat2 are "refined" with Binning_refiner to produce a set of probable MAGs

**outmicomplete**/ > Hugoson et al, 2020 published a paper with a fairly "generous" alternative to estimate quality of assembled microbial genomes (https://doi.org/10.1093/bioinformatics/btz664). Although the gold standard is still CheckM, miComplete is more resource friendly and offers a weighted calculation. 

The result of miComplete is a table with the quality assessment of the refined bins as shown in the image:
![image](https://user-images.githubusercontent.com/42699236/170597855-29d5167f-0d58-44b9-8d90-dec24825c868.png) 
***

**outmash**/ > **Full** Mash dist comparison for each bin produced, against the input database. Remember that these databases contain a set of genomes curated as Mash representations or sketches. This indicates that _bin1_ is compared against the ~17,000 records in the database (that's extremely fast with Mash), and the result is a table with 5 columns representing the following:

|Query_genome|  Match_in_database|   Genomic_Distance |  p_value| Shared_Hashes|
|-------------|-------------------|-------------------|----------|---------------| 
  |Bin1.fna | GCA_Reference.fna |      0.0327655 |         0   |    471/1000|

The genomic distance in the third column refers to the Mash distance, also defined as mutational distance. You will find more information on the interpretation of these tables in: https://doi.org/10.1186/s13059-016-0997-x. A practical interpretation of this comparison suggests that if two genomic contexts share < 0.05 distance, they are likely to be genomically coherents, and that has implications for the prokaryotic species concept.
This also means that those contexts with smaller genomic distances will potentially be the closest phylogenetic neighbors to your query; very useful if you want to explore the phylogenetic hypothesis.

Other subdirectories contain the log files of each task
***
 
 ### The directory _**allresultsfmbm_**

Contain the ten closest hits from the Mash paired comparison for each genome. This simplifies the interpretation of the results by limiting the Mash comparison to the ten closest neighbors to the query, which can be useful in phylogenetics and taxonomy. The user can take this list as the basis for a finer comparison by estimating the Overall genome relatedness index (OGRI) like ANI...

![image](https://user-images.githubusercontent.com/42699236/170605001-ef960d28-ca11-48dd-8956-9af6e7f3f2d8.png)

As you can see, they are conveniently sorted from smallest to largest, so that it is easy to establish or rule out probable genomic coherence; and use the elements of the reference in subsequent more refined analyzes.

For example, in the previous image the bin *feces_assembly_1.fasta* shares a genomic distance of ~0.075 with the assembly GCF_003287895.1, that belongs to the species _Blautia argi_ (firmicutes); and ~0.095 with the ensemble GCF_002222595.2 that belongs to the species _Blautia hansenii_ . Other hits in this comparison also match elements of the _Blautia_ genus. It is not difficult to hypothesize that the bin *feces_assembly_1.fasta* is related with the clade _Blautia_ (probably at the genus level, although nothing can be said about the species yet). So, presumably *feces_assembly_1.fasta* can be clasified as _Blautia_ sp.

Potential tests could be the estimation of the Average Nucleotide Identity against these close hits and reconstructing a phylogenomic tree in order to place the query in a finer taxonomic context.



# References:

S??nchez-Reyes, A.; Fern??ndez-L??pez, M.G. Mash Sketched Reference Dataset for Genome-Based Taxonomy and Comparative Genomics. Preprints 2021, 2021060368 (doi: http://dx.doi.org/10.20944/preprints202106.0368.v1).

Mash: fast genome and metagenome distance estimation using MinHash. Ondov BD, Treangen TJ, Melsted P, Mallonee AB, Bergman NH, Koren S, Phillippy AM. Genome Biol. 2016 Jun 20;17(1):132. doi: 10.1186/s13059-016-0997-x.

Silva, G. G. Z., D. A. Cuevas, B. E. Dutilh, and R. A. Edwards, 2014: FOCUS: an alignment-free model to identify organisms in metagenomes using non-negative least squares. PeerJ, 2, e425, doi:10.7717/peerj.425.

Song WZ, Thomas T (2017) Binning_refiner: Improving genome bins through the combination of different binning programs. Bioinformatics, 33(12), 1873-1875. 

Kang, D. D., Li, F., Kirton, E., Thomas, A., Egan, R., An, H., & Wang, Z. (2019). MetaBAT 2: an adaptive binning algorithm for robust and efficient genome reconstruction from metagenome assemblies. PeerJ, 7, e7359. https://doi.org/10.7717/peerj.7359.

Eric Hugoson, Wai Tin Lam, Lionel Guy, miComplete: weighted quality evaluation of assembled microbial genomes, Bioinformatics, Volume 36, Issue 3, 1 February 2020, Pages 936???937, https://doi.org/10.1093/bioinformatics/btz664

# Acknowledgments

This work was developed in the group of **Dr. Ayixon S??nchez-Reyes**

  "Researchers for Mexico" Program-(CONACYT)-Institute of Biotechnology-National Autonomous University of Mexico
  
  **Contact personal: ayixon@gmail.com         **Contact institutional: ayixon.sanchez@mail.ibt.unam.mx
  
  Teammates: **M.C. Karel Johan Estrada Guerra (developer); Dra. Luz Bret??n Deval; Dr. Maikel G. Fern??ndez-L??pez**
  
We thank Ing. Roberto Peredo for his help in the development of this tool

This work was funded in part by the project CF 2019 265222 (Fondo Institucional para el Desarrollo Cient??fico, Tecnol??gico y de Innovaci??n FORDECYT-PRONACES CONACYT- M??xico)

