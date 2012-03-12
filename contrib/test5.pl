#!/usr/local/bin/perl -w 
use strict;

open(IN, "<$ENV{PRFDB_HOME}/data/recode2.txt");
my $cmd = qq"$ENV{PRFDB_HOME}/prf_daemon --accession ";

while (my $line = <IN>) {
    chomp $line;
    my ($accession, $pos) = split(/\s+/, $line);
    if ($accession =~ /\,/) {
	my @accs = split(/\,/, $accession);
	foreach my $acc (@accs) {
	    my $c = $cmd . $acc;
	    system($c);
	}
    } else {
	my $c = $cmd . $accession;
	system($c);
    }
}

close(IN);
