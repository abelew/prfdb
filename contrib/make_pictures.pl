#! /usr/bin/perl -w
use lib '../lib';
use PRFConfig;
use PRFdb;
use Overlap;

my $config = $PRFConfig::config;
my $db = new PRFdb;
my $land = new Landscape;

my $accessions = qq(SELECT accession FROM landscape);
my $acc = $db->MySelect($accession);
foreach my $a (@{$acc}) {
  my $accession = $a->[0];
  my $test_dir = $land->Make_Directory($accession);
  my $test_file = qq($test_dir/$accession.png);
  next $a if (-r $test_file);
  $land->Make_Picture($accession);
}

