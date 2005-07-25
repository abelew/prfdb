package RNAFolders;
use strict;
use IO::Handle;
use lib 'lib';
use PkParse;
use PRFConfig qw / PRF_Error /;

sub new {
  my ($class, %arg) = @_;
  my $me = bless {
                  file => $arg{file},
                  accession => $arg{accession},
                  start => $arg{start},
                  slippery => $arg{slippery},
                  species => $arg{species},
                 }, $class;
  return ($me);
}

sub Nupack {
  my $me = shift;
  my $input = $me->{file};
  my $accession = $me->{accession};
  my $start = $me->{start};
  my $species = $me->{species};
  my $slippery = $me->{slippery};
  my $config = $PRFConfig::config;
  my $return = {
                accession => $accession,
                start => $start,
                slippery => $slippery,
                species => $species,
                knotp => 0,
               };
  chdir($config->{tmpdir});
  my $command = "$config->{nupack} $input";
#  open(NU, "$command $input 2>nupack.err |") or PRF_Error("Could not run nupack: $!", $species, $accession);
  open(NU, "/bin/true |");
  print "Running Nupack: $command\n";
  sleep(2);
  my $count = 0;
  while (my $line = <NU>) {
	$count++;
	## The first 15 lines of nupack output are worthless.
	next unless($count > 14);
	chomp $line;
	if ($count == 15) {
	  my ($crap, $len) = split(/\ \=\ /, $line);
	  $return->{seqlength} = $len;
	}
	elsif ($count == 17) {
	  $return->{sequence} = $line;
	}
	elsif ($count == 18) {
	  $return->{paren_output} = $line;
	}
	elsif ($count == 19) {
	  my $tmp = $line;
	  $tmp =~ s/^mfe\ \=\ //g;
	  $tmp =~ s/\ kcal\/mol//g;
	  $return->{mfe} = $tmp;
	}
	elsif ($count == 20) {
	  if ($line eq 'pseudoknotted!') {
		$return->{knotp} = 1;
	  }
	  else {
		$return->{knotp} = 0;
	  }
	}
  }  ## End of the line reading the nupack output.
  open(PAIRS, "<out.pair") or PRF_Error("Could not open the nupack pairs file: $!", $species, $accession);
  my $pairs = '';
  my @nupack_output = ();
  while(my $line = <PAIRS>) {
	chomp $line;
	my ($fiveprime, $threeprime) = split(/\s+/, $line);
	$nupack_output[$threeprime] = $fiveprime;
	$nupack_output[$fiveprime] = $threeprime;
  }
  for my $c (0 .. $#nupack_output) {
	$nupack_output[$c] = '.' unless(defined $nupack_output[$c]);
  }
  close(PAIRS);
  unlink("out.pair");
  $return->{pairs} = $pairs;
  my $parser = new PkParse(debug => 0);
  my $out = $parser->Unzip(\@nupack_output);
  my $parsed = '';
  foreach my $char (@{$out}) {
	$parsed .= $char . ' ';
  }
  $return->{parsed} = $parsed;
  chdir($config->{basedir});
  return($return);
}

sub Pknots {
  my $me = shift;
  my $input = $me->{file};
  my $accession = $me->{accession};
  my $start = $me->{start};
  my $species = $me->{species};
  my $slippery = $me->{slippery};
  my $config = $PRFConfig::config;
  my $return = { accession => $accession,
                 start => $start,
                 slippery => $slippery,
                 species => $species,
               };
  chdir($config->{tmpdir});
  my $command = "$config->{pknots} -k $input";
#  open(PK, "$command $input 2>pknots.err |") or PRF_Error("Failed to run pknots: $!", $species, $accession);
  open(PK, "/bin/true |");
  print "Running pknots: $command\n";
  sleep(1);
  my $counter = 0;
  my ($line_to_read, $crap) = undef;
  my $string = '';
  my $uninteresting = undef;
  while (my $line = <PK>) {
	next if (defined($uninteresting));
	$counter++;
	chomp $line;
	if ($line =~ /^NAM/) {
	  ($crap, $return->{slippery}) = split(/NAM\s+/, $line);
	}
	elsif ($line =~ /^\s+\d+\s+[A-Z]+/) {
	   $line_to_read = $counter + 2;
	 }
	elsif (defined($line_to_read) and $line_to_read == $counter) {
#	  print "TEST: $line\n";
	  $line =~ s/^\s+//g;
	  $line =~ s/$/ /g;
	  $string .= $line;
	}
	elsif ($line =~ /Log odds/) {
	  ($crap, $return->{logodds}) = split(/score\:\s+/, $line);
	}
	elsif ($line =~ /\/mol\)\:\s+/) {
	  ($crap, $return->{mfe}) = split(/\/mol\)\:\s+/, $line);
	}
	elsif ($line =~ /found\:\s+/) {
	  ($crap, $return->{pairs}) = split(/found\:\s+/, $line);
	  $uninteresting = 1;
	}
  } ## For every line of pknots
  $string =~ s/\s+/ /g;
  $return->{pkout} = $string;
  my $parser = new PkParse(debug => 0);
  my @struct_array = split(/ /, $string);
  my $out = $parser->Unzip(\@struct_array);
  my $parsed = '';
  foreach my $char (@{$out}) {
	$parsed .= $char . ' ';
  }
  $return->{parsed} = $parsed;
  return($return);
}


sub Mfold {
  my $me = shift;
  my $input = $me->{file};
  my $config = $PRFConfig::config;
  $ENV{MFOLDLIB} = $config->{tmpdir} . '/dat';

  my $accession = $me->{accession};
  my $start = $me->{start};
  my $species = $me->{species};
  my $slippery = $me->{slippery};

  my $return = {
                accession => $accession,
                start => $start,
                slippery => $slippery,
                species => $species,
               };
  chdir($config->{tmpdir});

  my $command = "$config->{mfold} SEQ=$input MAX=1";
#  open(MF, "$command 2>mfold.err |") or PRF_Error("Could not run mfold: $!", $species, $accession);
  open(MF, "/bin/true |");
  print "Running mfold\n";
  sleep(2);
  my $count = 0;
  while (my $line = <MF>) {
	$count++;
	next unless ($count > 11);
	chomp $line;
	my @crap = ();
	if ($line =~ /^Minimum folding energy/) {
	  @crap = split(/\s+/, $line);
	  $return->{mfe} = $crap[4];
	}
  }
  my @extra_files = ('ann', 'cmd', 'ct', 'det', 'h-num', 'log', 'out', 'plot', 'pnt', 'rnaml', 'sav', 'ss-count', 'gif');
  for my $ext (@extra_files) {
	my $stupido_filename = $me->{file} . '*.' . $ext;
	unlink($stupido_filename);
  }
  my $command1 = "rm $me->{file}" . '_* 2>/dev/null';
  my $command2 = "rm $me->{file}" . '.* 2>/dev/null';

  system($command1);
  system($command2);
  return($return);
}

sub Mfold_MFE {
  my $inputfile = shift;
  my $species = shift;
  my $accession = shift;
  my $start = shift;
  my $config = $PRFConfig::config;
#  $ENV{MFOLDLIB} = $config->{tmpdir} . '/dat';
  $ENV{MFOLDLIB} = '/home/trey/browser/work/dat';
  my $return;
#  my $return = {
 #               accession => $accession,
 #               start => $start,
 #               species => $species,
 #              };
  chdir($config->{tmpdir});

  $inputfile = `basename $inputfile`;
  chomp $inputfile;
#  my $command = "$config->{mfold} SEQ=$inputfile MAX=1 2>mfold.err";
  my $command = "$config->{mfold} SEQ=$inputfile MAX=1 2>/dev/null";
#  open(MF, "$command |") or PRF_Error("Could not run mfold: $!", $species, $accession);
  open(MF, "/bin/true |");
  print "Running mfold $command\n";
  my $count = 0;
  while (my $line = <MF>) {
    $count++;
    next unless ($count > 11);
    chomp $line;
    my @crap = ();
    if ($line =~ /^Minimum folding energy/) {
      @crap = split(/\s+/, $line);
      $return->{mfe} = $crap[4];
#      $return = $crap[4];
    }
  }
  ## Now get the number of pairs
  my $detfile = $inputfile . '.det';
  my $det = 1;
  open(DET, "<$detfile") or $det = 0, PRF_Error("Could not open the detfile $detfile: $!", $species, $accession);
  if ($det) {
    my $pairs = 0;
    while (my $line = <DET>) {
      chomp $line;
      if ($line =~ /^Helix/) {
        my ($helix, $ddg, $eq, $dumb_num, $num) = split(/\s+/, $line);
        $pairs += $num;
      }
    }
    $return->{pairs} = $pairs;
  }  ## End checking for the detfile
  else {
    $return->{pairs} = 0;
  }
  my @extra_files = ('ann', 'cmd', 'ct', 'det', 'h-num', 'log', 'out', 'plot', 'pnt', 'rnaml', 'sav', 'ss-count', 'gif');
  for my $ext (@extra_files) {
    my $stupido_filename = $inputfile . '.' . $ext;
    unlink($stupido_filename);
  }
  chdir($config->{basedir});
  return($return);
}

1;
