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
my $accession = 'SGDID:S0003410';
my $mt = 'mfe_saccharomyces_cerevisiae';
my $detail_stmt = qq"SELECT $mt.*, gene_info.accession FROM $mt,gene_info WHERE gene_info.accession = ? AND gene_info.accession = $mt.accession ORDER BY start, seqlength DESC, algorithm DESC";
my $info = $db->MySelect(statement => $detail_stmt, vars => [$accession,], type => 'list_of_hashes');
my $count = 0;
foreach my $datum (@{$info}) {
    $count++;
    print "On entry $count: ";
    foreach my $key (keys %{$datum}) {
	print "key: $key value $datum->{$key}\n";
    }
}


