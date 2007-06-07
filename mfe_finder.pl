#!/usr/local/bin/perl -w
use strict;
use DBI;
use Time::HiRes;
use Getopt::Long;

use lib "$ENV{HOME}/usr/lib/perl5";
use lib 'lib';
use PRFConfig;
use PRFdb;
use RNAMotif_Search;
use RNAFolders;
use Bootlace;
use Overlap;
use MoreRandom;
use PRF_Blast;

my $config = $PRFConfig::config;
my $db = new PRFdb;
my $blast = new PRF_Blast;
my %conf = ();
GetOptions(
    'minimum:m' => \$conf{minimum},
    );

foreach my $opt (keys %conf) {
    if (defined($conf{$opt})) {
	$config->{$opt} = $conf{$opt};
    }
}

my @lowest_accessions = $db->Get_Lowest_Accession($config->{minimum});
foreach my $acc (@lowest_accessions) {
    my $new_accessions = $blast->Find_Similar_NR($acc);
    foreach my $new_accession(@{$new_accessions}) {
	$db->Import_CDS($new_accession);
    }
}
