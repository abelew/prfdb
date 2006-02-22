package Overlap;
use strict;
use lib 'lib';
use SeqMisc;

my $config = $PRFConfig::config;

sub new {
  my ($class, %arg) = @_;
  my $me = bless {
		  genome_id => $arg{genome_id},
		  species => $arg{species},
                  accession => $arg{accession},
                  sequence => $arg{sequence},
                  start => $arg{start},
                 }, $class;
  return ($me);
}

sub Alts {
  my $me = shift;
  my $start = shift;
  my $info = {
              genome_id => $me->{genome_id},
              species => $me->{species},
              accession => $me->{accession},
             };
  my $plus = $me->Alt_Orf($start, 5);
  if (defined($plus)) {
    $info->{plus_length} = $plus->{length};
    $info->{plus_orf} = $plus->{orf};
  }
  my $minus = Alt_Orf($start, 6);
  if (defined($minus)) {
    $info->{minus_length} = $minus->{length};
    $info->{minus_orf} = $minus->{orf};
  }
  return($info);
}

sub Alt_Orf {
  my $me = shift;
  my $start = shift;
  my $offset = shift; ## 5 will go +1, 6 will go -1
  my @seq = split(//, $me->{sequence});
  my $return = {
                orf => '',
                length => 0,
               };
  for my $char (($start + $offset) .. $#seq) {
    $return->{orf} .= "$seq[$char]";
  }
  if ($return->{orf} =~ /^A+$/) {
    return(undef);
  }
  $return->{orf} =~ tr/atgcT/AUGCU/;
  my @plus_one = split(//, $return->{orf});
  my $seqmisc = new SeqMisc(sequence => \@plus_one);
  my $aa_seq = $seqmisc->{aaseq};
  my $new_plus_one = '';
  for my $char (@{$aa_seq}) {
    if ($char eq '*') { last; }
    $new_plus_one .= $char;
  }
  $return->{orf} = $new_plus_one;
  my @new_plus = split(//, $new_plus_one);
  $return->{length} = scalar(@new_plus);
  return($return);
}

1;
