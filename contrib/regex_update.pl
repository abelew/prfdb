#!/usr/bin/perl -w -I/usr/share/httpd/prfdb/usr/lib/perl5/site_perl/

use strict;
use DBI;
use lib '../lib';
use PRFConfig;
use PRFdb;
my $config = $PRFConfig::config;
my $db = new PRFdb;

my $species = $ARGV[0];
my $string = $species;
my @tmp = split(/_/, $string);
my @tmp2 = split(//, $tmp[0]);
$string = $tmp2[0] . $tmp[1];

my $info = $db->MySelect("SELECT accession FROM genome WHERE species = '$species'");
foreach my $datum (@{$info}) {
    my $new_string = $datum->[0];
    $new_string =~ s/Skud_Contig//g;
    my $new_string = $string . $new_string;
    my $update_string = qq(UPDATE genome set accession = '$new_string' WHERE accession = '$datum->[0]');
    print "$update_string\n";
    $db->MyExecute($update_string);
}


