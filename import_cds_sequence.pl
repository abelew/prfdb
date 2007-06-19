#! /usr/bin/perl -w
use strict;
use lib 'lib';
use PRFConfig;
use PRFdb;

my $config = $PRFConfig::config;
my $db     = new PRFdb;
my @args   = @ARGV;
if ( !$db->Tablep( $PRFConfig::config->{queue_table} ) ) {
  $db->Create_Queue();
}

foreach my $arg (@args) {
  if ( -r $arg ) {
    Read_Accessions($arg);
  } else {
    $db->Import_CDS($arg);
  }
}

sub Read_Accession {
  my $accession_file = shift;
  open( AC, "<$accession_file" );
  while ( my $accession = <AC> ) {
    chomp $accession;
    print "Importing Accession: $accession\n";
    $db->Import_CDS($accession);
  }
}
