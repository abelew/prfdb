#! /usr/bin/perl -w
use strict;
use lib '../lib';

use PRFdb;
my $db        = new PRFdb;
my $select    = qq(SELECT DISTINCT slipsite FROM mfe);
my $slipsites = $db->MySelect($select);
foreach my $site ( @{$slipsites} ) {
  my $seq     = $site->[0];
  my $new_seq = $seq;
  $new_seq =~ tr/T/U/;
  my $update_statement = qq(UPDATE mfe SET slipsite='$new_seq' WHERE slipsite='$seq');
  print "${update_statement};\n";
}
