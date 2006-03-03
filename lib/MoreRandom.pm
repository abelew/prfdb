package MoreRandom;
use strict;
use File::Temp qw / tmpnam /;
## Every function here should take as input an array reference
## containing the sequence to be shuffled.

## Coin_Random
## 
## Expect $me to be the MoreRandom obj. It's a place holder for now.
## Expect two array references. First is array ref to sequence, 
## second is array ref to catalog of sequence "characters" 
## (although this could be use for codons, etc. Return same 
## reference to sequence array, but array changed. Just do a 
## pseudo random number randomization of each incoming nucleotide

sub CoinRandom {
    print "COINRANDOM!\n";
  my $seqREF = shift;
  my $catREF = shift;
    if (!defined($catREF) or (scalar(@{$catREF}) == 0)) {
      $catREF = ['A', 'T', 'G', 'C'];
    }
  my @newSeq;
  for (my $i = 0; $i < @$seqREF; $i++) {
    $newSeq[$i] = $$catREF[ int( rand( scalar(@$catREF) ) ) ];	
  }
  return(\@newSeq);
}

## ARRAYSHUFFLE
##
## This shuffles a referenced array like a deck of cards.
## From the Perl cookbook. Uses the Fischer-Yates Shuffle.
sub ArrayShuffle{
	my $seqArrayREF = shift;
	my @arrayREF = @$seqArrayREF;
	for(my $i = @arrayREF; --$i; ){
		my $j = int rand ($i + 1);
		next if $i == $j;
		@arrayREF[$i,$j] = @arrayREF[$j,$i];
	}
	return(\@arrayREF);
}

sub Squid {
  my $inarray = shift;
  my $shuffle = shift;
  my $shuffle_exe;
  my $inseq = '';
  foreach my $char (@{$inarray}) { $inseq = join('', $inseq, $char); }
  if (defined($shuffle)) { $shuffle_exe = $shuffle; }
  else { $shuffle_exe = 'shuffle'; }
  my $out_text;
  {  ## Begin a File::Temp Block
    my $fh = new File::Temp(UNLINK => 1,);
    print $fh ">tmp
$inseq
";
    my $infile = $fh->filename;
    my $command = 'shuffle_exe $infile';
    open(CMD, "$command |") or die("Could not execute shuffle. $!");
    while (my $line = <CMD>) {
      chomp $line;
      next if ($line =~ /^\>/);
      $out_text = join('', $out_text, $line);
    } ## End while
      close(CMD);
  }  ## End a File::Temp Block -- the tempfile should now no longer exist.
  my @out_array = split(//, $out_text);
  return(\@out_array);
}

sub Squid_Dinuc {
  my $inarray = shift;
  my $shuffle = shift;
  my $shuffle_exe;
  my $inseq = '';
  foreach my $char (@{$inarray}) { $inseq = join('', $inseq, $char); }
  if (defined($shuffle)) { $shuffle_exe = $shuffle; }
  else { $shuffle_exe = 'shuffle'; }
  my $out_text;
  {  ## Begin a File::Temp Block
    my $fh = new File::Temp(UNLINK => 1,);
    print $fh ">tmp
$inseq
";
    my $infile = $fh->filename;
    my $command = 'shuffle_exe -d $infile';
    open(CMD, "$command |") or die("Could not execute shuffle. $!");
    while (my $line = <CMD>) {
      chomp $line;
      next if ($line =~ /^\>/);
      $out_text = join('', $out_text, $line);
    } ## End while
      close(CMD);
  }  ## End a File::Temp Block -- the tempfile should now no longer exist.
  my @out_array = split(//, $out_text);
  return(\@out_array);
}

1;
