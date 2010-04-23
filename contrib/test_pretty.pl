#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use DBI;
use lib "$ENV{HOME}/usr/lib/perl5";
use lib '../lib';
use lib 'lib';
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile";
use RNAMotif_Search;
use RNAFolders;
use Bootlace;
use Overlap;
use SeqMisc;
use PRFBlast;
use HTMLMisc;

$config = new PRFConfig(config_file => "$ENV{HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
my $accession = 'SGDID:S0000015';
my $info = $db->MySelect(statement => "SELECT mrna_seq, orf_start, orf_stop, direction FROM genome WHERE accession = ?", vars =>[$accession], type => 'row');
my $slipsite_positions = $db->MySelect(statement =>"SELECT DISTINCT start FROM mfe WHERE accession = ? ORDER BY start", vars => [$accession], type =>'flat');
my $string = HTMLMisc::Create_Pretty_mRNA(accession => $accession, mrna_seq => $info->[0], orf_start => $info->[1], orf_stop => $info->[2], slipsites => $slipsite_positions);
print "TESTME: $string\n";


