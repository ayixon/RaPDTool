#!/usr/bin/env perl
use strict;
use Getopt::Std;
use Text::SimpleTable;

my(%opts);
getopts("hp", \%opts);
if ($opts{h}) { help() };
my $profile = $opts{p};   # profile mode: no binning -> drop Completeness/Redundancy/Bin/Scaffolds columns

sub help{
print STDERR "Usage: $0 [opts] \n\n";
die <<'ayuda';
-h       This help

-This program summarizes the best Focus and Mash hits in two files (rapdtool_confidence.tbl|txt). Uses a cutoff of 0.5 for the relative abundance of Focus results and a cutoff of 0.05 and 0.08 for species and genus taxas respectively of Mash results.

Use output_Species_tabular.csv, found in "profilesfmbm" (Rapdtool output directory) and all '*.txt.out' from "allresultsfmbm" (Rapdtool output directory)

ayuda
}

my (%focus, %species, %genus, $wget, %bin, $taxid);
my ($genus, $species)= (0,0);

# Minimum FOCUS relative abundance (%) shown in the report. Measured operating
# point: at 0.5 the profile keeps every species of the benchmark communities with
# no false positives at 10-30 M reads; at 1.0 species between 0.5 and 1 % are lost.
my $FOCUS_MIN_ABUNDANCE = 0.5;

# Overall width budget for the report tables, and the column that may absorb it.
my $TABLE_MAX_WIDTH = 5000;
my $WIDE_COLUMN     = 'Scaffolds_in_Bin';

# Render a table whose columns are as wide as their widest value (caption
# included), so a long species name or taxID is never wrapped onto a second line.
# Only the scaffold list -- unbounded, and reproduced in full in
# rapdtool_confidence.txt -- is narrowed, and only by what is left of the budget.
sub draw_table {
	my ($caps, $rows)= @_;
	my @w= map { length } @$caps;
	foreach my $row ( @$rows ){
		foreach my $i ( 0 .. $#$row ){
			my $len= length( defined $row->[$i] ? $row->[$i] : '' );
			$w[$i]= $len if $len > $w[$i];
		}
	}
	if( $caps->[-1] eq $WIDE_COLUMN ){
		my $fixed= 0;
		$fixed += $w[$_] foreach ( 0 .. $#w - 1 );
		my $room= $TABLE_MAX_WIDTH - $fixed - 3 * scalar(@w);
		$w[-1]= $room if $room > 20 && $w[-1] > $room;
	}
	my $t= Text::SimpleTable->new( map { [ $w[$_], $caps->[$_] ] } 0 .. $#w );
	$t->row( map { defined $_ ? $_ : '' } @$_ ) foreach @$rows;
	return $t->draw;
}

my $file_to_open= `find . -type f -name output_Species_tabular.csv`;
open IN, $file_to_open or warn "Cant read $file_to_open\n";
while(<IN>){
	next if /^Species/;
	if( /^([^,]+),(\S+)/ ){
    	$focus{$1}= sprintf("%.2f", $2);

    }
}

$/="\n\n";
my $file_to_open2= `>allmash.txt; find . -type f -name '*.txt.out' -exec cat {} >>allmash.txt ';'; echo "allmash.txt"`;
open IN, $file_to_open2 or warn "Cant read $file_to_open2\n";

while(<IN>){
	chomp;
	my @lines= split("\n", $_);
	my $best= shift @lines;
	if( $best =~ m/\S+\/([^\/]+)\.fna\s+(G.._[^_]+)_.*genomic.f[an][as][t]?[a]?\s+(\S+)\s+\S+\s+(\S+)/ ){
		my ($bin, $specie, $dist, $frag)= ($1, $2, $3, $4);
		if( $dist < 0.05 ){
			$species{$specie}{dist}= sprintf("%.3f", $dist);
			$species{$specie}{ident}= sprintf("%.4f", 1 - $dist);
			$species{$specie}{frag}= $frag;
			$species{$specie}{bin}= $bin;
			next;
        }elsif($dist < 0.08){
			$genus{$specie}{dist}= sprintf("%.3f", $dist);
			$genus{$specie}{ident}= sprintf("%.4f", 1 - $dist);
			$genus{$specie}{frag}= $frag;
			$genus{$specie}{bin}= $bin;
			next;
        }
    }
}

$/="\n";
my $file_to_open3= `>miCompleteOut.txt; find miCompleteRes -type f -name 'miCompleteOut_*.tab' -exec cat {} >>miCompleteOut.txt ';' 2>/dev/null; echo "miCompleteOut.txt"`;
open IN, $file_to_open3 or warn "Cant read $file_to_open3\n";
while(<IN>){
	next if /^#/ || /^Name/;
	my($bin, $Completeness, $Redundancy)= (split)[0,4,5];
	$bin{$bin}{Completeness}= $Completeness;
	$bin{$bin}{Redundancy}= $Redundancy;
	$bin{$bin}{scaff} = `find . -type f -name '$bin.fna' -exec sh -c "grep '^>' {} | tr -d '>' | tr '\n' ',' | sed 's/.\$//'" ';'`;
}

unlink "allmash.txt","miCompleteOut.txt";
open OUT, ">rapdtool_confidence.tbl";
open OUT2, ">assemblyID_annot.txt";
open OUT3, ">rapdtool_confidence.txt";

my $distcap = $profile ? 'Identity' : 'Genomic-distance';   # profile: identity (1-dist), like screen
my @gcap = ('Genus-closest-hit','Species-closest-hit','taxID',$distcap,'Shared-hashes');
push @gcap, qw/ Completeness Redundancy Bin Scaffolds_in_Bin / unless $profile;
my @grows;

if( %genus ){
	$genus++;
	print OUT"\nGenus with high confidence:\n\n";
	print OUT3"# Genus with high confidence:\n\n";
	print OUT3 join("\t", @gcap)."\n";

	foreach my $genu ( sort keys %genus ){
		($wget,$taxid)= getseq($genu);
		print OUT2 "$genu\t$wget\n";
		(my $onlygenusname=$wget)=~ s/(\S+).*/$1/;
		my $gval = $profile ? $genus{$genu}{ident} : $genus{$genu}{dist};
		my @row = ($onlygenusname,$wget,$taxid,$gval,$genus{$genu}{frag});
		push @row, ($bin{$genus{$genu}{bin}}{Completeness}, $bin{$genus{$genu}{bin}}{Redundancy}, $genus{$genu}{bin}, $bin{$genus{$genu}{bin}}{scaff}) unless $profile;
		print OUT3 join("\t", @row)."\n";
		push @grows, [@row];
	}
}
print OUT draw_table(\@gcap, \@grows) if $genus;

my @scap = ('Species','taxID',$distcap,'Shared-hashes');
push @scap, qw/ Completeness Redundancy Bin Scaffolds_in_Bin / unless $profile;
my @srows;

if( %species ){
	$species++;
	print OUT"\nSpecies with high confidence:\n\n";
	print OUT3"\n# Species with high confidence:\n\n";
	print OUT3 join("\t", @scap)."\n";
	foreach my $specie ( sort keys %species ){
		($wget,$taxid)= getseq($specie);
		print OUT2 "$specie\t$wget\n";
		my $sval = $profile ? $species{$specie}{ident} : $species{$specie}{dist};
		my @row = ($wget,$taxid,$sval,$species{$specie}{frag});
		push @row, ($bin{$species{$specie}{bin}}{Completeness}, $bin{$species{$specie}{bin}}{Redundancy}, $species{$specie}{bin}, $bin{$species{$specie}{bin}}{scaff}) unless $profile;
		print OUT3 join("\t", @row)."\n";
		push @srows, [@row];
    }
}
print OUT draw_table(\@scap, \@srows) if $species;

# mash screen sections (screen mode). The GENUS table is printed BEFORE the species
# one, mirroring full mode's Genus-then-Species order. That order is load-bearing:
# a consumer scoping the species block as everything between "Reference genomes
# detected" and the FOCUS heading still sees species rows only, so adding the genus
# tier in 2.3.2 does not silently inflate anyone's species counts.
if( -s "mashscreen_genus_hits.txt" ){
	open SG, "mashscreen_genus_hits.txt";
	my @gscap= qw/ Genus Closest-species taxID Identity Shared-hashes /;
	my @gsrows;
	print OUT"\nGenus detected (mash screen, identity below the species cutoff):\n\n";
	print OUT3"\n# Genus detected (mash screen, identity below the species cutoff):\n\n";
	print OUT3"Genus\tClosest-species\ttaxID\tIdentity\tShared-hashes\n";
	while(<SG>){
		chomp;
		my($ident,$shared,$ref)= split("\t");
		my $acc= ($ref =~ /(GC[AF]_\d+\.\d+)/) ? $1 : $ref;
		my($org,$taxid)= getseq($acc);
		my($genus)= split(/[\s_]+/, $org);
		print OUT2"$acc\t$org\n";
		print OUT3"$genus\t$org\t$taxid\t$ident\t$shared\n";
		push @gsrows, [$genus,$org,$taxid,$ident,$shared];
	}
	close SG;
	print OUT draw_table(\@gscap, \@gsrows);
}

if( -s "mashscreen_hits.txt" ){
	open SC, "mashscreen_hits.txt";
	my @sccap= qw/ Species taxID Identity Shared-hashes /;
	my @scrows;
	print OUT"\nReference genomes detected (mash screen):\n\n";
	print OUT3"\n# Reference genomes detected (mash screen):\n\n";
	print OUT3"Species\ttaxID\tIdentity\tShared-hashes\n";
	while(<SC>){
		chomp;
		my($ident,$shared,$ref)= split("\t");
		my $acc= ($ref =~ /(GC[AF]_\d+\.\d+)/) ? $1 : $ref;
		my($org,$taxid)= getseq($acc);
		print OUT2"$acc\t$org\n";
		print OUT3"$org\t$taxid\t$ident\t$shared\n";
		push @scrows, [$org,$taxid,$ident,$shared];
	}
	close SC;
	print OUT draw_table(\@sccap, \@scrows);
}

my @fcap= qw/ Species relative_abundance /;
my @frows;
print OUT"\n\nFOCUS profile\nBe cautious at species taxonomic level:\n";
print OUT3"\n# FOCUS profile (be cautious at species taxonomic level):\n\n";
foreach my $specie ( sort {$focus{$b}<=>$focus{$a}} keys %focus ){
	next unless $focus{$specie} >= $FOCUS_MIN_ABUNDANCE;
	print OUT3"$specie\t$focus{$specie}\n";
	push @frows, [$specie,$focus{$specie}];
}
print OUT draw_table(\@fcap, \@frows);

open OUT3, ">forkrona.txt";
my $file_to_open4= `>profilesfmbm.txt; find profilesfmbm -type f -name 'output_All_levels.csv' -exec cat {} >>profilesfmbm.txt ';' 2>/dev/null; echo "profilesfmbm.txt"`;
open IN, $file_to_open4 or warn "Cant read $file_to_open4\n";
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
#~ print STDERR "Generating interactive metagenomic visualization tool (Krona).. [7/7]\n";
#~ system("ktImportText forkrona.txt");
#~ unlink "profilesfmbm.txt", "forkrona.txt";

sub getseq{
	my $acc= shift;
	chop(my $org = `esearch -db assembly -query $acc </dev/null | esummary | grep -i 'speciesName' | cut -d'<' -f2 | cut -c1-12 --complement`);
	chop($taxid = `esearch -db assembly -query $acc </dev/null | esummary | grep SpeciesTaxid | cut -d'>' -f2 | cut -d'<' -f1`);
	#~ return $org;
	return ($org,$taxid);

	# downloading sequence (ANI future upgrade)

	#~ my $command= "esearch -db assembly -query $acc </dev/null | esummary | xtract -pattern DocumentSummary -element FtpPath_GenBank | while read -r url ; do fname=\$(echo \$url | grep -o 'GCA_.*' | sed 's/\$/_genomic.fna.gz/') ;wget -q -O /var/tmp/wget_genomes$acc.fna.gz \"\$url/\$fname\";done";
	#~ system("$command");
	#~ $wget=`zless /var/tmp/wget_genomes$acc.fna.gz | head -1 | tr -d '>' | cut -d',' -f1 | cut -d' ' -f2- | sed 's/genomic.*//g;s/scaffold.*//g;s/supercont.*//g;s/contig.*//g;s/DNA.*//g;s/chromosome.*//g' | tr '\n' ' '`;
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



