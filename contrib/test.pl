#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use lib "$ENV{PRFDB_HOME}/usr/lib/perl5";
use lib "$ENV{PRFDB_HOME}/lib";
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile Callstack Cleanup";
#use RNAMotif;
#use RNAFolders;
#use Bootlace;
#use Overlap;
#use SeqMisc;
#use PRFBlast;
#use Agree;
$config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
print "Here\n";
$SIG{INT} = \&PRFdb::Cleanup;
print "There\n";
#my $ids = $db->Grab_Queue();
#my $import_accession = $db->Get_Import_Queue();
#print "TESTME: $import_accession\n";
#if (defined($import_accession)) {
#    my $import = $db->Import_CDS($import_accession);
#    print "TESTME: $import\n";
#    if (defined($import) and $import !=~ m/Error/) {
#	print "Imported $import_accession\n";
#	$db->MyExecute("DELETE FROM import_queue WHERE accession = '$import_accession'");
#    }
#}
my $species_list = $db->MySelect("
select distinct(species) from gene_info");
foreach my $species_es (@{$species_list}) {
    my $species = $species_es->[0];
    next if ($species =~ /virus/);
    my $mt = "mfe_$species";
    print "Starting $species... ";
    my $delete = $db->MyExecute("DROP TABLE $mt");
    $db->Create_MFE($mt);
    my $insert = $db->MyExecute("INSERT INTO $mt (genome_id, accession, algorithm, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode, compare_mfes, has_snp, bp_mstop) SELECT genome_id, accession, algorithm, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode, compare_mfes, has_snp, bp_mstop FROM mfe WHERE species = '$species'");

#    my $nupack_folds = $db->MySelect(statement => "SELECT count(id) FROM $mt WHERE species = '$species' AND algorithm = 'nupack'", type => 'single');
#    print "$nupack_folds ";
    print "\n";
}

