#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use DBI;
use lib "$ENV{HOME}/usr/lib/perl5";
use lib 'lib';
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile";
use RNAMotif_Search;
use RNAFolders;
use Bootlace;
use Overlap;
use SeqMisc;
use PRFBlast;
use Agree;
$SIG{INT} = 'CLEANUP';
$SIG{BUS} = 'CLEANUP';
$SIG{SEGV} = 'CLEANUP';
$SIG{PIPE} = 'CLEANUP';
$SIG{ABRT} = 'CLEANUP';
$SIG{QUIT} = 'CLEANUP';

$config = new PRFConfig(config_file => "$ENV{HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
my $ids = $db->Grab_Queue();
my $import_accession = $db->Get_Import_Queue();
print "TESTME: $import_accession\n";
if (defined($import_accession)) {
    my $import = $db->Import_CDS($import_accession);
    print "TESTME: $import\n";
    if (defined($import) and $import !=~ m/Error/) {
	print "Imported $import_accession\n";
	$db->MyExecute("DELETE FROM import_queue WHERE accession = '$import_accession'");
    }
}

