#! /usr/bin/perl -w
use strict;
use lib '../lib';

use PRFConfig;
use PRFdb;

my $config = $PRFConfig::config;
my $db     = new PRFdb;

## First Reconnect the MFE table to the Genome table
Reconnect_MFE();
## Then Reconnect the Boot table
Reconnect_Boot();

sub Reconnect_MFE {
  my $count       = 0;
  my $problem_ids = $db->MySelect("SELECT id, genome_id FROM mfe WHERE accession = ''");
  ## Information we want: accession and species
  foreach my $id ( @{$problem_ids} ) {
    my $mfe_id    = $id->[0];
    my $genome_id = $id->[1];
    my $needed    = $db->MySelect("SELECT accession, species FROM genome where id = '$genome_id'");
    my $accession = $needed->[0]->[0];
    my $species   = $needed->[0]->[1];
    my $final     = qq(UPDATE mfe SET accession='$accession', species='$species' WHERE id = '$mfe_id');

    #    print "TESTME: $final\n";
    $count = $count + $db->Execute($final);
  }
  print "$count entries changed in reconnect_mfe\n";
}

sub Reconnect_Boot {
  my $count       = 0;
  my $problem_ids = $db->MySelect("SELECT id, species, accession FROM boot WHERE mfe_id = ''");
  ## Information we want: accession and species
  foreach my $id ( @{$problem_ids} ) {
    my $boot_id   = $id->[0];
    my $species   = $id->[1];
    my $accession = $id->[2];
    my $needed    = $db->MySelect("SELECT id FROM mfe WHERE species = '$species' AND accession = '$accession'");
    my $mfe_id    = $needed->[0]->[0];
    my $final     = qq(UPDATE boot SET mfe_id = '$mfe_id' WHERE id = '$boot_id');

    #    print "TESTME: $final\n";
    $count = $count + $db->Execute($final);
  }
  print "$count entries changed in reconnect_boot\n";
}
