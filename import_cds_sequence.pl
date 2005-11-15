#! /usr/bin/perl -w
use strict;
use lib 'lib';
use PRFConfig;
use PRFdb;

my $config = $PRFConfig::config;
my $db = new PRFdb;
my $accession = $ARGV[0];
die("NEED ACCESSION") unless defined($accession);

print "Importing: <$accession>\n";
#if (!defined($db->Get_mRNA05($accession))) {
    $db->Import_CDS($accession);
    my $params = '';
    $db->Set_Pubqueue($accession, $params);
#}
