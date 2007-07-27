#!/usr/bin/perl -w
use strict;
use lib '../lib';
use PRFdb;

my $db = new PRFdb;

my $insert = qq/insert into dup(min_id, genome_id, algorithm, slipsite, mfe, seqlength, pairs) SELECT min(id), genome_id , algorithm, slipsite, mfe, seqlength, pairs FROM mfe GROUP BY accession, genome_id, algorithm, slipsite, seqlength, mfe, pairs HAVING count(*) > 1/;
my $in = $db->Execute($insert);

my $select_stmt = qq/SELECT min_id from dup/;
my $inf = $db->MySelect($select_stmt);
my $c = 0;
foreach my $in (@{$inf}) {
    $c++;
    my $id = $in->[0];
    my $del = qq(DELETE FROM mfe WHERE id = '$id');
    my $del2 = qq(DELETE FROM boot WHERE mfe_id = '$id');
    $db->Execute($del);
    $db->Execute($del2);
    print "Done $c\n";
}
my $del = qq/delete from dup/;
$db->Execute($del);
