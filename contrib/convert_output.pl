#!/usr/bin/perl -w
use strict;
use lib '../lib';
use PRFdb;
use PRFConfig;
my $config = $PRFConfig::config;
my $db = new PRFdb;
my $input_stmt = qq(SELECT sequence, output FROM mfe limit 10);
my $input = $db->MySelect($input_stmt, []);
foreach my $datum (@{$input}) {
    my $seq = $datum->[0];
    my $in = $datum->[1];
    print "START:
$seq
$in\n";
    my $output = '';
    my @seq_array = split(//, $seq);
    $in =~ s/^\s//g;
    my @in_array = split(/ /, $in);
    
    foreach my $c (0 .. $#seq_array) {
	if ($in_array[$c] eq '.') {
	    print "$c $seq_array[$c] 0\n";
	}
	else {
	    print "$c $seq_array[$c] $in_array[$c]\n";
	}
	print "\n";
    }
}
