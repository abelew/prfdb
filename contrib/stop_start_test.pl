#! /usr/bin/perl -w
use lib '../lib';
use PRFConfig;
use PRFdb;
use Overlap;

my $config = $PRFConfig::config;
my $db = new PRFdb;
my $stmt = qq(SELECT accession,mrna_seq, orf_start, orf_stop from genome where species = 'homo_sapiens');
my $data = $db->MySelect($stmt);
print "AC		STR	RRG	STP	PRG\n";
foreach my $datum (@{$data}) {
  my $accession = $datum->[0];
  my $sequence = $datum->[1];
  my $start = $datum->[2] - 1;
  my $stop = $datum->[3] - 3;
  my $seq = $sequence;
  my $start_region = substr($seq, $start, 5);
  $seq = $sequence;
  my $stop_region = substr($seq, $stop, 20);
  my $overlap = new Overlap(sequence => $sequence, start => $stop,);
  my $minus = $overlap->Alt_Orf($stop, 2);
  my $orf = $minus->{orf};
  my $mrna =  $minus->{mrnaseq};
  my $length = $minus->{length};
  print "$accession\t$start\t$start_region\t$stop\t$stop_region\t$length\n";
#  print "S: $mrna\n";
#  print "L: $length ORF: $orf\n";
}

