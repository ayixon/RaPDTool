#!/usr/bin/env perl

use strict;
use warnings;

my $USAGE="$0 depth1.txt depth2.txt [..]

This simple script will combine the depth files as output by jgi_summarize_bam_contig_depths into a single file.

";

if (@ARGV < 2) { die($USAGE); }

my @l_fh = ();
my @l_headers = ();
for my $filename (@ARGV) {
    my $fh;
    open($fh, "<", $filename) || die("Could not open $filename! $!\n"); 
    push @l_fh, $fh;
    my $firstline = <$fh>;
    chomp($firstline);
    my @headers = split("\t", $firstline);
    if (scalar(@l_headers) == 0) {
        push @l_headers, @headers;
    } else {
	shift @headers;
	shift @headers;
	shift @headers;
	push @l_headers, @headers;
   }
}

print join("\t", @l_headers) . "\n";

my $end = 0;
while(not $end) {
    my @line = ();
    my $name = undef;
    my $len = undef;
    my $avg = 0.0;
    foreach my $fh (@l_fh) {
	    my $line = <$fh>;
	    if (not defined $line) { $end = 1; last; }
	    chomp($line);
	    my @fields = split("\t", $line);
	    if (not defined $name) { $name = $fields[0]; $len = $fields[1]; }
	    elsif ($len != $fields[1]) { die("Files do not match! $name $len vs '$line'\n"); }
	    $avg += $fields[2];
	    shift @fields;
	    shift @fields;
	    shift @fields;
	    push @line, @fields;
    }
    if (defined $name) {
        print join("\t", $name, $len, $avg, @line) . "\n";
    }
}

