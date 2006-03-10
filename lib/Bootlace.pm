package Bootlace;
use strict;
use RNAFolders;
use PRFdb;
use Randomize;
use Math::Stat;
use PRFConfig qw / PRF_Error PRF_Out /;

sub new {
  my ($class, %arg) = @_;
  my $me = bless {
                  genome_id => $arg{genome_id},
                  nupack_mfe_id => $arg{nupack_mfe_id},
                  pknots_mfe_id => $arg{pknots_mfe_id},
                  inputfile => $arg{inputfile},
                  ## Expect an array reference of sequence
                  iterations => $arg{iterations},  ## How many repetitions
                  ## Expect an int
                  boot_mfe_algorithms => $arg{boot_mfe_algorithms},  ## What to calculate mfe from
                  ## Expect a hash ref of algorithms
                  randomizers => $arg{randomizers},  ## What randomization algorithm to use
                  ## Expect a hash ref of randomizers
                  fasta_comment => undef,
                  species => $arg{species},
                  accession => $arg{accession},
                  start => $arg{start},
                  seqlength => $arg{seqlength},
                  fasta_comment => undef,
                  fasta_data => undef,
                  fasta_arrayref => [],
                 }, $class;
  my $inputfile = $me->{inputfile};
  open(IN, "<$inputfile") or PRFConfig::PRF_Error("Could not open the Bootlace input file.", $arg{species}, $arg{accession});
  ## OPEN IN in new
  while (my $line = <IN>) {
    chomp $line;
    if ($line =~ /^\>/) {
      $me->{fasta_comment} = $line;
    }
    else {
      $me->{fasta_data} .= $line;
    }
  }
  close(IN);
  ## CLOSE IN in new
  my @fasta_array = split(//, $me->{fasta_data});
  $me->{fasta_arrayref} = \@fasta_array;
  return($me);
}

sub Go {
  my $me = shift;
  my $return;  ## hash repetition, ref of algo name, random name, and output of mfe
  my $randomized_sequence;
  my $inputfile = $me->{inputfile};
  my $species = $me->{species};
  my $accession = $me->{accession};
  my $start = $me->{start};
  my $seqlength = $me->{seqlength};
  print "Boot: infile: $inputfile accession: $accession start: $start seqlength: $seqlength\n";
  ## randomizer should be a reference to a function which takes as input
  ## the array reference of the sequence window of interest.  Thus allowing us to
  ## change which function randomizes the sequence
  my @algos = keys(%{$me->{boot_mfe_algorithms}});
  foreach my $boot_mfe_algo_name (keys %{$me->{boot_mfe_algorithms}}) {
      my $mfe_id;
      if ($boot_mfe_algo_name eq 'nupack') {
	  $mfe_id = $me->{nupack_mfe_id},
      }
      elsif ($boot_mfe_algo_name eq 'pknots') {
	  $mfe_id = $me->{pknots_mfe_id},
      }
      my @randers = keys(%{$me->{randomizers}});
      foreach my $rand_name (keys %{$me->{randomizers}}) {
	  my $ret = {
	      mfe_id => $mfe_id,
	      accession => $accession,
	      species => $species,
	      start => $start,
	      seqlength => $seqlength,
	      iterations => 0,
	      mfe_mean => 0.0,
	      pairs_mean => 0.0,
	      mfe_sd => 0.0,
	      pairs_sd => 0.0,
	      mfe_se => 0.0,
	      pairs_se => 0.0,
	      mfe_conf => 0.0,
	      pairs_conf => 0.0,
	      total_pairs => 0,
	      total_mfe => 0.0,
	      total_mfe_deviation => 0.0,
	      total_pairs_deviation => 0.0,
	      total_mfe_error => 0.0,
	      total_pairs_error => 0.0,
	      mfe_values => '',
	  };
	  my @stats_mfe;
          my @stats_pairs;
	  my $iteration_count = 1;	  
          while ($iteration_count <= $me->{iterations}) {
	      $iteration_count++;
	      my $boot_mfe_algo = $me->{boot_mfe_algorithms}->{$boot_mfe_algo_name};
	      #my $rand_algo = $me->{randomizers}->{$rand_name}($inputfile, $species, $accession);
	      my $rand_algo = $me->{randomizers}->{$rand_name};
	      my $array_reference = $me->{fasta_arrayref};
	      my $randomized_sequence = &{$rand_algo}($array_reference);
	      $me->Overwrite_Inputfile($randomized_sequence);
#	      my $mfe = &{$boot_mfe_algo}($me->{inputfile}, $me->{species}, $me->{accession}, $me->{start});
	      my $mfe = &{$boot_mfe_algo}($me->{inputfile}, $me->{accession}, $me->{start});
	      foreach my $k (keys %{$mfe}) {
		  $return->{$boot_mfe_algo_name}->{$rand_name}->{$iteration_count}->{$k} = $mfe->{$k};
	      }

	      if (defined($mfe->{mfe})) {
		  push(@stats_mfe, $mfe->{mfe});
		  $ret->{iterations}++;
		  $ret->{mfe_values} .= "$mfe->{mfe} ";
	      }
	      push(@stats_pairs, $mfe->{pairs}) if (defined($mfe->{pairs}));
	
	  }  ## Foreach repetition
	  ## Now have collected every repetition, so we can calculate the means
	  my $mfe_stat = new Math::Stat(\@stats_mfe, {AutoClean => 1});
	  $ret->{mfe_mean} = sprintf("%.2f", $mfe_stat->average());
          $ret->{mfe_sd} = sprintf("%.2f", $mfe_stat->stddev());

          my $pairs_stat = new Math::Stat(\@stats_pairs, {AutoClean => 1});
          $ret->{pairs_mean} = sprintf("%.2f", $pairs_stat->average());
          $ret->{pairs_sd} = sprintf("%.2f", $pairs_stat->stddev());

          if (!defined($ret->{iterations}) or $ret->{iterations} eq '0') {
            $ret->{mfe_se} = undef;
            $ret->{pairs_se} = undef;
          }
          else {
            $ret->{mfe_se} = sprintf("%.2f", $ret->{mfe_sd} / sqrt($ret->{iterations}));
            $ret->{pairs_se} = sprintf("%.2f", $ret->{pairs_sd} / sqrt($ret->{iterations}));
	}

	  $return->{$boot_mfe_algo_name}->{$rand_name}->{stats} = $ret;
	  $return->{genome_id} = $me->{genome_id};
        }  ## Foreach randomization
    }  ## Foreach mfe calculator
  return($return);
}

sub Overwrite_Inputfile {
  my $me = shift;
  my $sequence = shift;
  my $string;
  foreach my $char (@{$sequence}) { $string .= $char; }
  open(OUT, ">$me->{inputfile}") or PRF_Error("Could not open output file in Bootlace.", $me->{species}, $me->{accession});
  ## OPEN OUT in Overwrite_Inputfile
  print OUT "$me->{fasta_comment}
$string
";
  close OUT;
  ## CLOSE OUT in Overwrite_Inputfile
}

1;
