#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use lib "$ENV{PRFDB_HOME}/usr/lib/perl5";
use lib "$ENV{PRFDB_HOME}/lib";
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile Callstack Cleanup";
$config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
$SIG{INT} = \&PRFdb::Cleanup;
my $species_list = $db->MySelect("select distinct(species) from gene_info");
foreach my $species_es (@{$species_list}) {
    my $species = $species_es->[0];
    next if ($species =~ /virus/);
    my $mt = "mfe_$species";
    print "Starting $species... ";
    $db->Create_MFE($mt);
    my $insert = $db->MyExecute("INSERT INTO $mt (genome_id, accession, algorithm, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode, compare_mfes, has_snp, bp_mstop) SELECT genome_id, accession, algorithm, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode, compare_mfes, has_snp, bp_mstop FROM mfe WHERE species = '$species'");
    $insert = $db->MyExecute("Optimize table $mt");
    print "\n";
}

