#!/usr/bin/perl -w -I/usr/share/httpd/prfdb/usr/lib/perl5/site_perl/

use strict;
use DBI;
use lib '../lib';
use PRFConfig;
use PRFdb;
my $config = $PRFConfig::config;
my $db = new PRFdb;

my $species = $ARGV[0];
my $accession_list = $db->MySelect("SELECT distinct(accession) FROM boot WHERE species = '$species'");
my $heptamer_count = 0;
my $accession_count = 0;
foreach my $accessions (@{$accession_list}) {
    my $acc = $accessions->[0];
    $accession_count++;
    my $start_count = $db->MySelect({statement => "SELECT count(distinct(start)) FROM mfe WHERE accession = '$acc'",
				   type => 'single'});

    $heptamer_count = $heptamer_count + $start_count;
    print "$accession_count  $heptamer_count\n";
}
print "$species has $heptamer_count heptamers\n";
