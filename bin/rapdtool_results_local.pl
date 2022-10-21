#!/usr/bin/env perl
use strict;
use Getopt::Std;
use Text::SimpleTable::AutoWidth;

my(%opts);
getopts("h", \%opts);
if ($opts{h}) { help() };

sub help{
print STDERR "Usage: $0 [opts] \n\n";
die <<'ayuda';
-h       This help

-This program summarizes the best Focus and Mash hits in one file (rapdtools_confidence.results). Uses a cutoff of 1 for the relative abundance of Focus results and a cutoff of 0.05 and 0.08 for species and genus taxas respectively of Mash results.

Use output_Species_tabular.csv, found in "profilesfmbm" (Rapdtools output directory) and all '*.txt.out' from "allresultsfmbm" (Rapdtools output directory)

ayuda
}

my (%focus, %species, %genus, $wget, %bin, $taxid);
my ($genus, $species)= (0,0);

my $file_to_open= `find . -type f -name output_Species_tabular.csv`;
open IN, $file_to_open or die "Cant read $file_to_open\n";
while(<IN>){
	next if /^Species/;
	if( /^([^,]+),(\S+)/ ){
    	$focus{$1}= sprintf("%.2f", $2);

    }
}

$/="\n\n";
my $file_to_open2= `find . -type f -name '*.txt.out' -exec cat {}>allmash.txt ';'; echo "allmash.txt"`;
open IN, $file_to_open2 or die "Cant read $file_to_open2\n";

while(<IN>){
	chomp;
	my @lines= split("\n", $_);
	my $best= shift @lines;
	if( $best =~ m/\S+\/([^\/]+)\.fna\s+(G.._[^_]+)_.*genomic.fna.gz\s+(\S+)\s+\S+\s+(\S+)/ ){
		my ($bin, $specie, $dist, $frag)= ($1, $2, $3, $4);
		if( $dist < 0.05 ){
			$species{$specie}{dist}= sprintf("%.3f", $dist);
			$species{$specie}{frag}= $frag;
			$species{$specie}{bin}= $bin;
			next;
        }elsif($dist < 0.08){
			$genus{$specie}{dist}= sprintf("%.3f", $dist);
			$genus{$specie}{frag}= $frag;
			$genus{$specie}{bin}= $bin;
			next;
        }
    }
}

$/="\n";
my $file_to_open3= `find miCompleteRes -type f -name 'miCompleteOut_*.tab' -exec cat {}>miCompleteOut.txt ';'; echo "miCompleteOut.txt"`;
open IN, $file_to_open3 or die "Cant read $file_to_open3\n";
while(<IN>){
	next if /^#/ || /^Name/;
	my($bin, $Completeness, $Redundancy)= (split)[0,4,5];
	$bin{$bin}{Completeness}= $Completeness;
	$bin{$bin}{Redundancy}= $Redundancy;
	$bin{$bin}{scaff} = `find . -type f -name '$bin.fna' -exec sh -c "grep '^>' {} | tr -d '>' | tr '\n' ',' | sed 's/.\$//'" ';'`;
}

unlink "allmash.txt","miCompleteOut.txt";
open OUT, ">rapdtools_confidence.tbl";
open OUT2, ">assemblyID_annot.txt";
open OUT3, ">rapdtools_confidence.txt";

my $g = Text::SimpleTable::AutoWidth->new( max_width => 5000, captions => [qw/ Genus-closest-hit taxID Genomic-distance Shared-hashes Completeness Redundancy Bin Scaffolds_in_Bin /] );

if( %genus ){
	$genus++;
	print OUT"\nGenus with high confidence:\n\n";
	print OUT3"# Genus with high confidence:\n\n";
	foreach my $genu ( sort keys %genus ){
		($wget,$taxid)= getseq($genu);
		print OUT2 "$genu\t$wget\n";
		print OUT3"$wget\t$taxid\t$genus{$genu}{dist}\t$genus{$genu}{frag}\t$bin{$genus{$genu}{bin}}{Completeness}\t$bin{$genus{$genu}{bin}}{Redundancy}\t$genus{$genu}{bin}\t$bin{$genus{$genu}{bin}}{scaff}\n";
		$g->row($wget,$taxid,$genus{$genu}{dist}, $genus{$genu}{frag}, $bin{$genus{$genu}{bin}}{Completeness}, $bin{$genus{$genu}{bin}}{Redundancy}, $genus{$genu}{bin}, $bin{$genus{$genu}{bin}}{scaff});
	}
}
print OUT $g->draw if $genus;

my $s = Text::SimpleTable::AutoWidth->new( max_width => 5000, captions => [qw/ Species taxID Genomic-distance Shared-hashes Completeness Redundancy Bin Scaffolds_in_Bin /] );

if( %species ){
	$species++;
	print OUT"\nSpecies with high confidence:\n\n";
	print OUT3"\n# Species with high confidence:\n\n";
	foreach my $specie ( sort keys %species ){
		($wget,$taxid)= getseq($specie);
		print OUT2 "$specie\t$wget\n";
    	print OUT3"$wget\t$taxid\t$species{$specie}{dist}\t$species{$specie}{frag}\t$bin{$species{$specie}{bin}}{Completeness}\t$bin{$species{$specie}{bin}}{Redundancy}\t$species{$specie}{bin}\t$bin{$species{$specie}{bin}}{scaff}\n";
    	$s->row($wget,$taxid,$species{$specie}{dist}, $species{$specie}{frag}, $bin{$species{$specie}{bin}}{Completeness}, $bin{$species{$specie}{bin}}{Redundancy}, $species{$specie}{bin}, $bin{$species{$specie}{bin}}{scaff});
    }
}
print OUT $s->draw if $species;

my $f = Text::SimpleTable::AutoWidth->new( max_width => 100, captions => [qw/ Species relative_abundance /] );
print OUT"\n\nFOCUS profile\nBe cautious at species taxonomic level:\n";
print OUT3"\n# FOCUS profile (be cautious at species taxonomic level):\n\n";
foreach my $specie ( sort {$focus{$b}<=>$focus{$a}} keys %focus ){
	print OUT3"$specie\t$focus{$specie}\n" if $focus{$specie} > 1;
	$f->row($specie,$focus{$specie}) if $focus{$specie} > 1;
}
print OUT $f->draw;

open OUT3, ">forkrona.txt";
my $file_to_open4= `find profilesfmbm -type f -name 'output_All_levels.csv' -exec cat {}>profilesfmbm.txt ';'; echo "profilesfmbm.txt"`;
open IN, $file_to_open4 or die "Cant read $file_to_open4\n";
while(<IN>){
	next if /^Kingdom/;
	chomp;
	my @camps= split(',', $_);
	my $val= pop(@camps);
	my $strain= pop(@camps); # not use strain
	print OUT3"$val";
	foreach my $camp ( @camps ){
    	print OUT3"\t$camp";
    }
    print OUT3"\n";
}

sub getseq{
	my $acc= shift;
	chop(my $org = `esearch -db assembly -query $acc </dev/null | esummary | grep -i 'speciesName' | cut -d'<' -f2 | cut -c1-12 --complement`);
	chop($taxid = `esearch -db assembly -query $acc </dev/null | esummary | grep SpeciesTaxid | cut -d'>' -f2 | cut -d'<' -f1`);
	#~ return $org;
	return ($org,$taxid);
}


__END__
output_Species_tabular.csv:
	Species,...fasta
	Acinetobacter_calcoaceticus/baumannii_complex,5.203176025411699
	Helicobacter_pylori,0.07920301466810512
	Campylobacter_jejuni,0.26576115466948
	Mesorhizobium_ciceri,2.672199048314339
	Methylotenera_versatilis,1.4325545788480183
	...



*.txt.out from "allresultsfmbm": scaff_non_virus_1.fna.txt.out
..fasta	GCA_014647715.1_genomic.fna.gz	0.0563082	0	181/1000	18742



file: miCompleteOut_scaff_non_virus.tab
## miComplete
## v1.1.1
Name	Length	GC-content	Present	Markers	Completeness	Redundancy	Contigs	N50	L50	N90	L90	CDs
scaff_non_virus_7	624325	65.89	3	0.0286	1.6667	70	20904	9	2928	41	684
scaff_non_virus_6	893036	59.0	4	0.0381	1.0000	195	5901	50	2350	148	1309
scaff_non_virus_5	1533885	44.3	60	0.5714	1.0333	318	6197	74	2231	235	1586
scaff_non_virus_4	2021036	66.84	60	0.5714	1.0167	507	4742	119	1999	391	2288
scaff_non_virus_3	2477566	70.15	13	0.1238	1.0000	142	27749	28	8932	88	2366
scaff_non_virus_1	6613752	38.27	53	0.5048	1.7736	1862	4081	463	1828	1464	7877
scaff_non_virus_2	5430652	64.15	72	0.6857	1.0972	1315	4789	269	1949	1000	6558



outbinningref: scaff_non_virus_Binning_refiner_outputs/scaff_non_virus_refined_bins scaff_non_virus_7.fna (cachar el nombre de las secuencias..)



