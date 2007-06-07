#! /usr/bin/perl -w
use lib '../lib';
use PRFConfig;
use PRFdb;
use PRFGraph;

my $config = $PRFConfig::config;
my $db = new PRFdb;
my $land = new PRFGraph;
my $type = 'landscape';

my $accessions = qq/SELECT distinct(accession) FROM landscape/;
my $acc = $db->MySelect($accessions);
foreach my $a (@{$acc}) {
  my $accession = $a->[0];
  print "Working on $accession\n";
  my $test_dir = $land->Make_Directory($type, $accession);
  my $test_file = qq($test_dir/$accession.png);
  if (-r $test_file) {
   print "Already have $test_file\n";
   next;
  }
  my $filename = $land->Make_Picture($type, $accession);
  print "Wrote $filename\n";
}

