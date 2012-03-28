#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use lib "$ENV{PRFDB_HOME}/lib";
use local::lib "$ENV{PRFDB_HOME}/usr/perl";
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile Callstack Cleanup";
use SeqMisc;
my $config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
$db = new PRFdb(config => $config);

my $sequences = $db->MySelect("SELECT mrna_seq, orf_start, orf_stop FROM genome,gene_info WHERE gene_info.species = 'homo_sapiens' AND gene_info.genome_id = genome.id LIMIT 1");
my @s = split(//, $sequences->[0]->[0]);
my $start = $sequences->[0]->[1];
my $stop = $sequences->[0]->[2];
my $len = $stop - ($start - 1);
print "TESTME: $start $stop\n";
my @orf = splice(@s, $start - 1, $len);
#my @orf = splice(@s, $start - 1, $stop - 1);
print "@orf";
print "\n";
print "$#orf\n";








