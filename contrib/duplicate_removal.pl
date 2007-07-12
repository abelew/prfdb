#!/usr/bin/perl -w
use strict;
use lib '../lib';
use PRFdb;

my $db = new PRFdb;

#my $create_stmt = qq/CREATE table dup (
#id int not null primary key,
#mfe_id int,
#mfe_accession text,
#mfe_mfe text,
#mfe_algorithm text,
#seqlength int,
#pairs int,
#)/;
#$db->Execute($stmt);

my $create_stmt = qq/CREATE temporary table dup (
id int not null auto_increment primary key,  min_id int )/;
$db->Execute($create_stmt);
my $find_dups =        qq/INSERT into dup(min_id) SELECT min(id) FROM mfe 
GROUP BY accession, genome_id, algorithm, slipsite, seqlength, mfe, pairs HAVING count(*) > 1/;
$db->Execute($find_dups);
my $delete_dups = "SELECT id, accession, genome_id, algorithm, slipsite, seqlength, mfe, pairs FROM mfe
WHERE exists (select * from dup where dup.min_id = mfe.id and dup.min_id <> mfe.id)";
my $inf = $db->MySelect($delete_dups);
foreach my $in (@{$inf}) {
    print "$in->[0]\t$in->[1]\t$in->[2]\t$in->[3]\t$in->[4]\t$in->[5]\t$in->[6]\n";
}
