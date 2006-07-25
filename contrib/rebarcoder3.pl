#! /usr/bin/perl -w
use strict;
use lib '../lib';
use PRFdb;
use PkParse;

my $db = new PRFdb;
my $parser = new PkParse();

my $select = qq(SELECT id, output, parsed FROM mfe order by id);

my $info = $db->MySelect($select);
foreach my $inf (@{$info}) {
  my $mfe_id = $inf->[0];
  my $pk_output = $inf->[1];
  my $pk_parsed = $inf->[2];
  $pk_output =~ s/^\s+//g;
  $pk_output =~ s/\s+/ /g;
  my @start = split(/ /, $pk_output);
  my $struct = $parser->Unzip(\@start);
  my $new_struc = PkParse::ReBarcoder($struct);
  my $condensed = PkParse::Condense($new_struc);
  my $brackets = PkParse::MAKEBRACKETS(\@start);
  my @parens = split(//, $brackets);
  my $parsed_string = '';
  foreach my $char (@{$new_struc}) {
    $parsed_string .= "$char ";
  }
#  my $update_string = qq(UPDATE mfe SET barcode = '$condensed', parsed = '$parsed_string', WHERE id = '$mfe_id');
  my $update_string = qq(UPDATE mfe SET barcode = '$condensed' WHERE id = '$mfe_id');
  print "${update_string};\n";
}
