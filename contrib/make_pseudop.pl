#! /usr/bin/perl -w
use strict;
use lib '../lib';
use PRFdb;
use PkParse;
my $db = new PRFdb;
my $parser = new PkParse;

my $select = qq(SELECT id, barcode FROM mfe WHERE id > '207267' and barcode IS NOT null order by id);
my $info = $db->MySelect($select);
foreach my $inf (@{$info}) {
  my $id = $inf->[0];
  my $barcode = $inf->[1];
  my $pseudop = $parser->Barcode_Pseudop($barcode);
  my $update = qq(UPDATE mfe SET knotp = '$pseudop' WHERE id = '$id');
  print "${update};\n";
}
