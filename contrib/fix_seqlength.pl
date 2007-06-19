#! /usr/bin/perl -w
use strict;
use lib '../lib';

use PRFdb;
my $db     = new PRFdb;
my $select = qq(SELECT mfe_id,id FROM boot WHERE seqlength = '0');
my $ids    = $db->MySelect($select);
foreach my $id ( @{$ids} ) {
  my $update = qq(UPDATE boot set seqlength = (select seqlength from mfe where id = '$id->[0]') WHERE id = '$id->[1]');
  print "${update};\n";
}
