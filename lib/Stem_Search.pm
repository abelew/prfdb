package Stem_Search;
use strict;

my @slippery_sites = (	  'A AAA AAA',
					  'A AAA AAC',
					  'A AAA AAG',
					  'A AAA AAT',
					  'A AAC CCA',
					  'A AAC CCC',
					  'A AAC CCG',
					  'A AAC CCT',
#					  'A AAG GGA',
#					  'A AAG GGC',
#					  'A AAG GGG',
#					  'A AAG GGT',
					  'A AAT TTA',
					  'A AAT TTC',
					  'A AAT TTG',
					  'A AAT TTT',
					  'C CCA AAA',
					  'C CCA AAC',
					  'C CCA AAG',
					  'C CCA AAT',
					  'C CCC CCA',
					  'C CCC CCC',
					  'C CCC CCG',
					  'C CCC CCT',
#					  'C CCG GGA',
#					  'CCC GGG C',
#					  'C CCG GGG',
#					  'C CCG GGT',
					  'C CCT TTA',
					  'C CCT TTC',
					  'C CCT TTG',
					  'C CCT TTT',
					  'G GGA AAA',
					  'G GGA AAC',
					  'G GGA AAG',
					  'G GGA AAT',
					  'G GGC CCA',
					  'G GGC CCC',
					  'G GGC CCG',
					  'G GGC CCT',
#					  'G GGG GGA',
#					  'G GGG GGC',
#					  'G GGG GGG',
#					  'G GGG GGT',
					  'G GGT TTA',
					  'G GGT TTC',
					  'G GGT TTG',
					  'G GGT TTT',
					  'T TTA AAA',
					  'T TTA AAC',
					  'T TTA AAG',
					  'T TTA AAT',
					  'T TTC CCA',
					  'T TTC CCC',
					  'T TTC CCG',
					  'T TTC CCT',
#					  'T TTG GGA',
#					  'T TTG GGC',
#					  'T TTG GGG',
#					  'T TTG GGT',
					  'T TTT TTA',
					  'T TTT TTC',
					  'T TTT TTG',
					  'T TTT TTT',);

sub new {
  my ($class, %arg) = @_;
  my $me = bless {}, $class;
  return($me);
}

sub Search {
  my $me = shift;
  my %args = shift;
  my @information = split(//, $args{sequence});
  my $end_trim = 30;
  my @information = split(//, $sequence);
  my @slipsites = ();

  for my $c (0 .. ($#information - $end_trim)) {  ## Don't bother with the last $end_trim nucleotides
	if ((($c + 1) % 3) == 0) {
	  my $next_seven = "$information[$c] " . $information[$c + 1] . $information[$c + 2] . "$information[$c + 3] " . $information[$c + 4] . $information[$c + 5] . $information[$c + 6];
	  if (Slip_p($next_seven)) {
		push(@slipsites, $c);
#		Five_Prime_Stem_p($c, \@information);
	  }
	}
  }
  return(\@slipsites);
}

## Given a sequence array and position, search the n nucleotides downstream from
## it for a region which will make a perfect nmer stem (4 nucleotides in this case)
sub Five_Prime_Stem_p {
  my $pos = shift;
  my $sequence = shift;
  my $subsequence = SubSeq(($pos + 7), 10, 'forward', $sequence);
  print "TEST: $subsequence\n";
}

sub SubSeq {
  my $pos = shift;
  my $bases = shift;
  my $direction = shift;
  my $sequence = shift;
  my @seq = @{$sequence};
  my $return = '';
  my $count = 1;
  while ($bases >= $count) {
	if ($direction eq 'forward') {
	  $return .= $seq[$pos];
	  $pos++;
	}
	elsif ($direction eq 'reverse') {
	  $return .= $seq[$pos];
	  $pos--;
	}
	$count++;
  }
  return($return);
}

sub Slip_p {
  my $septet = shift;
  foreach my $slip (@slippery_sites) {
	return(1) if ($slip eq $septet);
  }
  return(0);
}


1;
