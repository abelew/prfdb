#!/usr/local/bin/perl -w
use strict;
#use autodie qw":all";
use autodie;
use Statistics::Basic qw":all";

my $input = $ARGV[0];
open(IN, "<$input");
while (my $line = <IN>) {
    chomp $line;
    my @fields = split(/\,/, $line);
    my $gene = shift @fields;
    my %gene_info = ();
    my $count = 0;
    $gene_info{$gene}{total} = 0;
    my @score_array = ();
    my @healthy_array = ();
    my @cancer_array = ();
    while ($#fields > 0) {
	$count++;
	my $healthy = shift @fields;
	my $cancer = shift @fields;
	my $score = exp($cancer - $healthy);
	$gene_info{$gene}{$count}{score} = $score;
	$gene_info{$gene}{$count}{cancer} = $cancer;
	$gene_info{$gene}{$count}{healthy} = $healthy;
	push(@score_array, $score);
	push(@healthy_array, $healthy);
	push(@cancer_array, $cancer);
    }
    $gene_info{$gene}{avg} = mean(\@score_array);
    my $tmp = $gene_info{$gene}{avg}->query_vector;
    $gene_info{$gene}{stddev} = stddev($tmp);
    $gene_info{$gene}{variance} = variance($tmp);

    my $healthy_vector = vector(\@healthy_array);
    my $cancer_vector = vector(\@cancer_array);
    my $covar = covariance($healthy_vector, $cancer_vector);
    my $corr = correlation($healthy_vector, $cancer_vector);
    print "Avg_Score: $gene_info{$gene}{avg} STDDEV: $gene_info{$gene}{stddev} Cov healthy/cancer: $covar $gene\n";
}
close(IN);
