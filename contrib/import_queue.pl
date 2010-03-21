#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use DBI;
use lib "$ENV{HOME}/usr/lib/perl5";
use lib "$ENV{HOME}/prfdb/lib";
use lib '../lib';
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile";
use RNAMotif_Search;
use RNAFolders;
use Bootlace;
use Overlap;
use SeqMisc;
use PRFBlast;
use PRFGraph;

$config = new PRFConfig(config_file => "$ENV{HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
$db->Create_Import_Queue();
open(IN, "<ac");
while (my $line = <IN>) {
    chomp $line;
    $db->MyExecute(statement => "INSERT INTO import_queue (accession) VALUES('$line')");
}
