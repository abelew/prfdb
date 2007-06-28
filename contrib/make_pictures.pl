#! /usr/bin/perl -w
use lib '../lib';
use PRFConfig;
use PRFdb;
use PRFGraph;

my $config = $PRFConfig::config;
my $db     = new PRFdb;

my $type   = 'landscape';
my $accessions;
if (!defined($ARGV[0])) {
    $acc_stmt = qq/SELECT distinct(accession) FROM landscape/;
    $accessions        = $db->MySelect($acc_stmt);
    foreach my $a ( @{$accessions} ) {
	my $land   = new PRFGraph( {accession => $a, mfe_id => 1});
	my $accession = $a->[0];
	print "Working on $accession\n";
	$land->Make_Landscape($accession);
    }
}
else {
    print "Working on $ARGV[0]\n";
    my $land = new PRFGraph({accession => $ARGV[0], mfe_id => 1});
    $land->Make_Landscape($ARGV[0]);
}

