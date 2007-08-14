#! /usr/bin/perl -w
use strict;
use lib '../lib';

use PRFdb;
use PRFConfig;
my $config = $PRFConfig::config;
my $db     = new PRFdb;

my $genome_stmt = qq(SELECT id, orf_stop FROM genome);
my $genome_info = $db->MySelect($genome_stmt);
foreach my $ids (@{$genome_info}) {
    my $id = $ids->[0];
    my $stop = $ids->[1];
    my $utr_stmt = qq/DELETE FROM mfe WHERE genome_id = '$id' AND start >= '$stop'/;
    print "$utr_stmt\n";
    $db->MyExecute($utr_stmt);
}
