#! /usr/bin/perl -w
use strict;
use lib 'lib';
use PRFConfig;
use PRFdb;

my $config = $PRFConfig::config;
my $db = new PRFdb;
my $accession_file = $ARGV[0];
die("NEED ACCESSION") unless defined($accession_file);

open(AC, "<$accession_file");
while (my $accession = <AC>) {
  chomp $accession;
  print "Importing Accession: $accession\n";
  $db->Import_CDS($accession);
}
