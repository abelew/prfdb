#! /usr/bin/perl -w
use strict;
use lib '../lib';
use PRFConfig;
use PRFdb;
use RNAFolders;
our $config = $PRFConfig::config;
our $db     = new PRFdb;
my $stmt = qq(SELECT mfe.mfe, mfe.start, mfe.knotp, genome.orf_start, genome.orf_stop, genome.accession FROM mfe, genome WHERE mfe.seqlength = '100' and mfe.species = 'mus_musculus' and mfe.genome_id = genome.id and mfe.slipsite < genome.orf_stop);
my $data = $db->MySelect($stmt);

my (@first, @second, @third, @fourth, @fi, @se, @th, @fo);

foreach my $datum (@{$data}) {
    my $mfe = $datum->[0];
    my $start = $datum->[1];
    my $knotp = $datum->[2];
    my $orf_start = $datum->[3];
    my $orf_stop = $datum->[4];
    my $accession = $datum->[5];

    my $dist = $orf_stop - $orf_start;
    my $relative_start = $start - $orf_start;
    my $percentage = ($relative_start / $dist) * 100.0;

    if ($percentage <= 25) {
	if ($knotp == 1) {
	    push(@fi, $accession);
	}
	push(@first, $accession);
    }
    elsif ($percentage <= 50) {
	if ($knotp == 1) {
	    push(@se, $accession);
	}
	push(@second, $accession);
    }
    elsif ($percentage <= 75) {
	if ($knotp == 1) {
	    push(@th, $accession);
	}
	push(@third, $accession);
    }
    else {
	if ($knotp == 1) {
	    push(@fo, $accession);
	}
	push(@fourth, $accession);
    }
}

my $a = ($#fi / $#first) * 100.0;
my $b = ($#se / $#second) * 100.0;
my $c = ($#th / $#third) * 100.0;
my $d = ($#fo / $#fourth) * 100.0;

print "First quarter: $#first $#fi $a
Second quarter: $#second $#se $b
Third quarter: $#third $#th $c
Fourth quarter: $#fourth $#fo $d
";
