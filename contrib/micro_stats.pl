#!/usr/local/bin/perl -w
use strict;
use vars qw"$db $config";
use lib "$ENV{PRFDB_HOME}/usr/lib/perl5";
use lib "$ENV{PRFDB_HOME}/lib";
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile Callstack Cleanup";
use MicroRNA;
$config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
my $micro = new MicroRNA;

my $results = {};
open(OUTPUT, ">testme.csv");
my $information = $db->MySelect("SELECT accession, sequence, mfe, start FROM mfe_homo_sapiens WHERE seqlength = '100' AND algorithm = 'nupack' AND knotp = '1'");

my $micro_count = 0;
foreach my $info (@{$information}) {
    my ($accession, $sequence, $mfe, $start) = @{$info};
    print "TESTME: Working on $accession $mfe $start\n";
    my $micro_output = $micro->RNAHybrid($accession, $start);
    $results->{$accession}->{$start}->{count} = $micro_count;
    foreach my $mir (sort keys %{$micro_output}) {
      INNER: foreach my $pos (sort keys %{$micro_output->{$mir}}) {
	  next INNER if $micro_output->{$mir}->{$pos}->{mfe} > -25;
	  $micro_count++;
	  my $micro_mfe = $micro_output->{$mir}->{$pos}->{mfe};
	  my $match = $micro_output->{$mir}->{$pos}->{miRNA_match};
	  print OUTPUT "$accession\t$start\t$mir\t$pos\t$mfe\t$micro_mfe\t$match\n";
      }  ## End INNER
    }  ## End looking through micro output
} ## End $information
close(OUTPUT);
