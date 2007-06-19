#! /usr/bin/perl -w
use strict;
use lib '../lib';
use PRFConfig;
use PRFdb;

my $config  = $PRFConfig::config;
my $db      = new PRFdb;
my $species = $ARGV[0];
die("NEED SPECIES") unless defined($species);

open( IN, "<accessions" );
while ( my $accession = <IN> ) {
  chomp $accession;
  print "Importing: <$accession>\n";
  if ( !defined( $db->Get_Sequence05( $species, $accession ) ) ) {
    sleep(5);
    $db->Import_CDS($accession);
  }
}
