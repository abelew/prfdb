#!/usr/bin/perl -w
use strict;
use lib '../lib';
use PRFdb;

my $db = new PRFdb;

#my $create_stmt = qq/CREATE table dup ( id int not null auto_increment primary key,  min_id int, genome_id text, algorithm text, slipsite text, mfe text, seqlength text, pairs text )/;
#$db->Execute($create_stmt);
#my $insert_stmt = qq/insert into dup(min_id, genome_id, algorithm, slipsite, mfe, seqlength, pairs) SELECT min(id), genome_id, algorithm, slipsite, mfe, seqlength, pairs FROM mfe GROUP BY accession, genome_id, algorithm, slipsite, seqlength, mfe, pairs HAVING count(*) > 1/;
my $select_stmt = qq/SELECT * from dup/;
my $inf = $db->MySelect($select_stmt);
my $c = 0;
foreach my $in (@{$inf}) {
    print "\n";
    my ($dup_id, $dup_min_id, $dup_genome_id, $dup_algorithm, $dup_slipsite, $dup_mfe, $dup_seqlength, $dup_pairs) = @{$in};
    next if ($dup_algorithm eq 'hotknots');
 #   print @{$in};
    my $test_stmt = qq/SELECT distinct(mfe.id) FROM dup,mfe WHERE mfe.genome_id = '$dup_genome_id' AND mfe.algorithm = '$dup_algorithm' AND mfe.slipsite = '$dup_slipsite' AND mfe.mfe = '$dup_mfe' AND mfe.seqlength = '$dup_seqlength' AND mfe.pairs = '$dup_pairs' AND mfe.id <> '$dup_min_id'/;
    my $fun = $db->MySelect($test_stmt);
    foreach my $f (@{$fun}) {
	my ($final_mfe_id) = @{$f};
#	print "ID:$final_mfe_id, keeping $dup_min_id\n";
	my $del = qq(DELETE FROM mfe WHERE id = '$final_mfe_id');
#	$db->Execute($del);
        print "$del\n";
    }
}

