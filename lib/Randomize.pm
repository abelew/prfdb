package Randomize;
use strict;

sub new {
  my ($class, %arg) = @_;
  my $me = bless {
				 }, $class;
  return($me);
}


## Expect an array reference, return same reference, but array changed.
## Just do a pseudo random number randomization of each incoming nucleotide
## Code shamelessly taken from Jonathan Jacobs' <jlj email> work from 2003.
sub Coin_Random {
  my $me = shift;
  my $sequence = shift;
  my @nucleotides = ('a', 'u', 'g', 'c');
  for my $c ($#$sequence) {
	$sequence->[$c] = $nucleotides[int(rand(4))];
  }
  return($sequence);
}


## Expect an array reference
## Perform a shuffle by substitution
## Code shamelessly taken from Jonathan Jacobs' <jlj email> work from 2003.
sub Nucleotide_Montecarlo {
  my $start_sequence = shift;
  my @st = @{$start_sequence};
  my $new_sequence = [];
  my $new_seq_count = 0;
  while (@st) {
	my $position = rand(@st);
	$new_sequence->[$new_seq_count] = $position;
	$new_seq_count++;
	splice(@st, $position, 1);
  }
  return($new_sequence);
}

## Expect an array reference
## Perform a shuffle keeping the same dinucleotide frequencies as original sequence.
## Code shamelessly taken from Jonathan Jacobs' <jlj email> work from 2003.
## I don't know why, but I love the way Jonathan wrote this.
sub Dinucletode {
  my $start_sequence = shift;
  my @st = @{$start_sequence};
  my @new_sequence = ();
#  my @startA = my @startT = my @startG = my @startC = ();
#  ## Create 4 arrays containing
  ## Create an array containing all the dinucleotides
  my @doublets = ();
  push(@doublets, $start_sequence =~ /(?=(\w\w))/g);
  while (scalar(@{$start_sequence}) > scalar(@new_sequence)) {
	my $chosen_doublet = int(rand(@doublets));
	my ($base1, $base2) = split(//, $doublets[$chosen_doublet]);
	push(@new_sequence, $base1, $base2);
  }
  return(\@new_sequence);
}

## Expect an array reference
## Perform a shuffle keeping the same triplet frequencies as original sequence.
## Code shamelessly taken from Jonathan Jacobs' <jlj email> work from 2003.
sub Codon_montecarlo {
  my $start_sequence = shift;
  my @new_sequence = ();
  my $new_seq_count = 0;
  my @codons = $$start_sequence =~ /(\w\w\w)/g;
  while (@codons) {
    my $position = rand(@codons);
    my @nts = split(//, $codons[$position]);
    push(@new_sequence, @nts);
	splice(@codons, $position, 1);
  }
  return(\@new_sequence);
}

## Expect an array reference
## Perform a shuffle keeping the same triplet frequencies as original sequence.
## Code shamelessly taken from Jonathan Jacobs' <jlj email> work from 2003.
sub Related_Codon {
  my $start_sequence = shift;
  my @codons = $start_sequence =~ /(\w\w\w)/g;
  for my $c (0 .. $#codons) {
	my @potential = split(/\s/, $Randomize::amino_acids{$codons[$c]});
	$codons[$c] = $potential[rand(@potential)];
  }
  return(\@codons);
}


my %amino_acids = (
				   '*' => 'TAA TAG TGA', TAA => '*', TAG => '*', TAA => '*',
				   A => 'GCA GCT GCC GCG', GCA => 'A', GCT => 'A', GCC => 'A', GCG => 'A', GCA => 'A',
				   C => 'TGC TGT', TGC => 'C', TGT => 'C',
				   D => 'GAC GAT', GAC => 'D', GAT => 'D',
				   E => 'GAA GAG', GAA => 'E', GAG => 'E',
				   F => 'TTC TTT', TTC => 'F', TTT => 'F',
				   G => 'GGA GGC GGT GGC', GGA => 'G', GGC => 'G', GGT => 'G', GGA => 'G',
				   H => 'CAC CAT', CAC => 'H', CAT => 'H',
				   I => 'ATA ATC ATT', ATA => 'I', ATC => 'I', ATT => 'I',
				   K => 'AAA AAG', AAA => 'K', AAG => 'K',
				   L => 'TTA TTG CTA CTT CTG CTC', TTA => 'L', TTG => 'L', CTA => 'L', CTT => 'L', CTG => 'L', CTC => 'L', TTA => 'L',
				   M => 'ATG', ATG => 'M',
				   N => 'AAC AAT', AAC => 'N', AAT => 'N',
				   P => 'CCA CCT CCG CCC', CCA => 'P', CCT => 'P', CCG => 'P', CCC => 'P', CCA => 'P',
				   Q => 'CAA CAG', CAA => 'Q', CAG => 'Q',
				   R => 'CGA CGT CGG CGC AGA AGG', CGA => 'R', CGT => 'R', CGG => 'R', CGC => 'R', AGA => 'R', CGA => 'R',
				   S => 'TCA TCT TCG TCG AGC AGT', TCA => 'S', TCT => 'S', TCG => 'S', AGC => 'S', AGT => 'S', TCA => 'S',
				   T => 'ACA ACC ACG ACT', ACA => 'T', ACC => 'T', ACG => 'T', ACT => 'T',
				   V => 'GTA GTC GTG GTT', GTA => 'V', GTC => 'V', GTG => 'V', GTT => 'V', GTA => 'V',
				   W => 'TGG', TGG => 'W',
				   Y => 'TAC TAT', TAC => 'Y', TAT => 'Y', TAC => 'Y',
				  );

1;
