package Bootlace;
use strict;
use RNAFolders;
use PRFdb;
use Randomize;

sub new {
  my ($class, %arg) = @_;
  my $me = bless {
                  inputfile => $arg{inputfile},
                  ## Expect an array reference of sequence
                  repetitions => $arg{repetitions},  ## How many repetitions
                  ## Expect an int
                  mfe_algorithms => $arg{mfe_algorithms},  ## What to calculate mfe from
                  ## Expect a hash ref of algorithms
                  randomizers => $arg{randomizers},  ## What randomization algorithm to use
                  ## Expect a hash ref of randomizers
                  fasta_comment => undef,
                  species => undef,
                  accession => undef,
                  start => undef,
                  fasta_comment => undef,
                  fasta_data => undef,
                 }, $class;
  open(IN, "<$me->{inputfile}") or Error("Could not open the Bootlace input file.");
  while (my $line = <IN>) {
    chomp $line;
    if ($line = /^\>/) {
      $me->{fasta_data} = $line;
    }
    else {
      $me->{fasta_data} .= $line;
    }
  }
  close(IN);
  return($me);
}

sub Go {
  my $me = shift;
  my $return;  ## hash repetition, ref of algo name, random name, and output of mfe
  my $randomized_sequence;
  my $count = 1;
  my $inputfile = $me->{inputfile};
  my $species = $me->{species};
  my $accession = $me->{accession};
  my $start = $me->{start};
  while ($count < $me->{repetitions}) {
    $count++;
    ## randomizer should be a reference to a function which takes as input
    ## the array reference of the sequence window of interest.  Thus allowing us to
    ## change which function randomizes the sequence.
    foreach my $mfe_algo_name (keys %{$me->{mfe_algorithms}}) {
      foreach my $rand_name (keys %{$me->{randomizers}}) {
        my $mfe_algo = $me->{mfe_algorithms}->{$mfe_algo_name};
        my $rand_algo = $me->{randomizers}->{$rand_name}($inputfile, $species, $accession);
        my $input_sequence = &{$rand_algo}($me->{input});
        print "TEST: About to overwrite $inputfile with $input_sequence\n";
        $me->Overwrite_Inputfile($input_sequence);
        my $mfe = &{$mfe_algo}($input_sequence);
        $return->{$count}->{$mfe_algo_name}->{$rand_name}->{sequence} = $input_sequence;
        $return->{$count}->{$mfe_algo_name}->{$rand_name}->{mfe} = $mfe;
      } ## End recursing over randomizations
    }   ## End recursing over mfe algorithms
  }     ## End foreach repetition
  return($return);
}

sub Overwrite_Inputfile {
  my $me = shift;
  my $sequence = shift;
  open(OUT, ">$me->{inputfile}") or Error("Could not open output file in Bootlace.");
  print OUT "$me->{fasta_comment}
$sequence
";
  close OUT;
}


1;
