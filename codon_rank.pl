#! /usr/bin/perl -w
use strict;
use Data::Dumper;
use lib 'lib';
use PRFdb;
use PRFConfig;
my $freq = {};
my $species = 'homo_sapiens';
my $db = new PRFdb;
my $all_sequences = $db->Get_All_Sequences($species);
my $c = 0;
my ($accession, $sequence);
my $num = scalar(@{$all_sequences});
while ($c < $num) {
  $accession = $all_sequences->[$c]->[0];
  $sequence = $all_sequences->[$c]->[1];
  $sequence =~ s/A+$//g;
  my @seq= split(//, $sequence);
  my $position = 0;
  while (scalar(@seq) > 1) {
    $position++;
    my $first = shift @seq;
    my $second = shift @seq;
    my $third = shift @seq;
    my $fourth = $seq[0];
    my $fifth = $seq[1];
    my $zero_frame_codon = join('', $first, $second, $third);
    my $plus_one_codon = join('', $second, $third, $fourth);
    my $minus_one_codon = join('', $third, $fourth, $fifth);

    if (defined($freq->{$position}->{0}->{$zero_frame_codon})) {
      $freq->{$position}->{0}->{$zero_frame_codon}++;
      $freq->{$position}->{-1}->{$minus_one_codon}++;
      $freq->{$position}->{+1}->{$plus_one_codon}++;
    }
    else {
      $freq->{$position}->{0}->{$zero_frame_codon} = 1;
      $freq->{$position}->{-1}->{$minus_one_codon} = 1;
      $freq->{$position}->{'+1'}->{$plus_one_codon} = 1;
    }
  $c++;
  } ## End the while loop
}
print Dumper($freq);
