#! /usr/bin/perl -w
use strict;
use lib '../lib';
use PRFdb;

my $db     = new PRFdb;

my $select = qq(SELECT id,comment FROM genome WHERE length(genename) = '20' or length(genename) = '40');
my $info = $db->MySelect($select);
foreach my $geneid (@{$info}) {
    my $id = $geneid->[0];
    my $comment = $geneid->[1];
    my @gene_name_info = split(/, mRNA \(/, $comment);
    my $gene_name = $gene_name_info[0];
    my $update = qq(UPDATE genome set genename = '$gene_name' WHERE id = '$id');
    print "Blah: $update\n";
    $db->Execute($update, []);
}


