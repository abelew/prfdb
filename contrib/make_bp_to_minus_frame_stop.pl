#!/usr/bin/perl -w -I/usr/share/httpd/prfdb/usr/lib/perl5/site_perl/

use strict;
use DBI;
use lib '../lib';
use PRFConfig;
use PRFdb;
my $config = $PRFConfig::config;
my $db = new PRFdb;

my $mfe_ids = $db->MySelect("SELECT id, genome_id, start, slipsite,accession FROM mfe");
foreach my $datum (@{$mfe_ids}) {
    my $id = $datum->[0];
    my $genome_id = $datum->[1];
    my $start = $datum->[2];
    my $slipsite = $datum->[3];
    my $accession = $datum->[4];
    my $genome_info = $db->MySelect("SELECT mrna_seq, orf_stop FROM genome WHERE id = '$genome_id'");
    my $mrna_seq = $genome_info->[0]->[0];
    my $orf_stop = $genome_info->[0]->[1];
#    print "TEST: id:$id genome_id:$genome_id start:$start slipsite:$slipsite stop:$orf_stop
#sequence: $mrna_seq\n\n";
    my @mrna_seq_array = split(//, $mrna_seq);
    my @mrna_spliced = @mrna_seq_array;
##
## To remove the slipsite
##
    my @snipped_bases = splice(@mrna_spliced, 0, ($start + 6));
##
## To leave the slipsite
##
#    my @snipped_bases = splice(@mrna_spliced, 0, ($start - 1));
    my $remaining_mrna = '';
    foreach my $c (@mrna_spliced) { $remaining_mrna .= $c };
    my @fun = @mrna_spliced;
    shift @fun;
    shift @fun;
#    my $minus_orf_stop = $start + 8;
    my $minus_orf_stop = $start;
    my $c = 2;
    my $codon = '';
#    my $distance = 8;
    my $distance = 8;
    foreach my $char (@fun) {
	$c++;
	$minus_orf_stop++;
#	next if ($c == 3);
	if (($c % 3) == 0) {
#	    print "TESTME: $codon\n";
	    if ($codon eq 'TAG' or $codon eq 'TAA' or $codon eq 'TGA' or
		$codon eq 'tag' or $codon eq 'taa' or $codon eq 'tga') {
		
		$distance = $minus_orf_stop - $start;
		last;
	    }
	    $codon = $char;
	}
	else {
	    $codon .= $char;
	}
    }  ## End foreach char of fun
    my @region_between_prf_minus_stop = @mrna_seq_array;
#    print "TESTME: $minus_orf_stop\n";
    my $start_corrected = $start + 7;
    my $stop_corrected = $minus_orf_stop + 7;
    my @snipped_end = splice(@region_between_prf_minus_stop, $stop_corrected);
    my @snipped_beginning = splice(@region_between_prf_minus_stop, 0, $start_corrected);
    my $rem = '';

    print "Cutting out the region from $start_corrected to $stop_corrected for $accession\n";
    foreach my $c (@region_between_prf_minus_stop) { $rem .= $c };
    print "The remaning bases are and distance is: $distance
$rem
";
    if ($distance > 102) {
	print "accession: $accession start: $start slipsite:$slipsite has distance $distance\n";
    }
}
