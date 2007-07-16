#! /usr/bin/perl -w
use strict;
use lib '../lib';

use PRFdb;
use PRFConfig;
my $config = $PRFConfig::config;
my $db     = new PRFdb;

#my $stmt = qq/select mfe.accession, mfe.id, (mfe.start - genome.orf_start) % 3, mfe.start from genome,mfe where genome.accession = mfe.accession/;
#my $info = $db->MySelect($stmt);
#foreach my $ids (@{$info}) {
#    my $accession = $ids->[0];
#    my $id = $ids->[1];
#    my $mod = $ids->[2];
#    my $start = $ids->[3];
#    print "Accession: $accession Start: $start";
#    if ($mod == 1) {
#        print " changed.\n";
#	my $st = qq(UPDATE mfe SET start = start + 1 WHERE id = '$id');
#	$db->Execute($st);
#	my $st2 = qq(UPDATE boot set start = start + 1 where mfe_id = '$id');
#	$db->Execute($st2);
#    }
#    else {
#        print " left alone.\n"; 
#	}
#}

my $stmt = qq/select mfe.accession, mfe.id, mfe.start, genome.orf_start from genome,mfe where mfe.accession = genome.accession and mfe.genome_id = genome.id AND (mfe.start - genome.orf_start) % 3 = '0' ORDER BY mfe.accession/;
my $stuff = $db->MySelect($stmt);
foreach my $s (@{$stuff}) {
    my $accession = $s->[0];
    my $id = $s->[1];
    my $start = $s->[2];
    my $genome_start = $s->[3];
    my $new_start = $start - 1;
    print "Updating $accession start:$start genome_start: $genome_start id:$id\n";
    my $update = qq/update mfe set start = '$new_start' WHERE id = '$id'/;
    $db->Execute($update);
    my $update2 = qq/update boot set start = '$new_start' where mfe_id = '$id'/;
    $db->Execute($update2);
}


$stmt = qq/select mfe.accession, mfe.id, mfe.start, genome.orf_start from genome,mfe where mfe.accession = genome.accession and mfe.genome_id = genome.id AND (mfe.start - genome.orf_start) % 3 = '1'/;
$stuff = $db->MySelect($stmt);
foreach my $s (@{$stuff}) {
    my $accession = $s->[0];
    my $id = $s->[1];
    my $start = $s->[2];
    my $genome_start = $s->[3];
    my $new_start = $start + 1;
    print "Updating $accession start:$start genome_start: $genome_start id:$id\n";
    my $update = qq/update mfe set start = '$new_start' WHERE id = '$id'/;
    $db->Execute($update);
    my $update2 = qq/update boot set start = '$new_start' where mfe_id = '$id'/;
    $db->Execute($update2);
}
