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
  my $inputfile = $me->{file};
  my $accession = $me->{accession};
  my $start = $me->{start};
  my $species = $me->{species};
  my $config = $PRFConfig::config;
  print "NUPACK: infile: $inputfile accession: $accession start: $start\n";
  open(SLIP, "<$inputfile");
  my ($slippery, $crap);
  while(my $line = <SLIP>) {
      chomp $line;
      if ($line =~ /^\>/) {
	  ($slippery, $crap) = split(/ /, $line);
	  $slippery =~ tr/actgTu/ACUGUU/;
	  $slippery =~ s/\>//g;
      }
      else {next;}
  }
  close(SLIP);
  my $return = {
      accession => $accession,
      start => $start,
      slippery => $slippery,
      species => $species,
      knotp => 0,
  };
  chdir($config->{tmpdir});
  my $command = qq(sh -c "time $config->{nupack} $inputfile" 2>nupack.err);
  open(NU, "$command |") or PRF_Error("Could not run nupack: $!", $species, $accession);
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
  my $pairs = 0;
  my @nupack_output = ();
  while(my $line = <PAIRS>) {
	chomp $line;
	$pairs++;
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
  my $inputfile = $me->{file};
  my $accession = $me->{accession};
  my $start = $me->{start};
  my $species = $me->{species};
  my $config = $PRFConfig::config;
  print "PKNOTS: infile: $inputfile accession: $accession start: $start\n";
  my $return = {
      accession => $accession,
      start => $start,
      slippery => '',
      species => $species,
      knotp => 0,
  };
  chdir($config->{tmpdir});
  my $command = qq(sh -c "time $config->{pknots} -k $inputfile" 2>pknots.err);
  print "PKNOTS: $command\n";
  open(PK, "$command |") or PRF_Error("Failed to run pknots: $!", $species, $accession);
  my $counter = 0;
  my ($line_to_read, $crap) = undef;
  my $string = '';
  my $uninteresting = undef;
  while (my $line = <PK>) {
	$counter++;
	chomp $line;
	### The NAM field prints out the name of the sequence
	### Which is set to the slippery site in RNAMotif
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
#	elsif ($line =~ /Log odds/) {
#	  ($crap, $return->{logodds}) = split(/score\:\s+/, $line);
#	}
	elsif ($line =~ /\/mol\)\:\s+/) {
	  ($crap, $return->{mfe}) = split(/\/mol\)\:\s+/, $line);
	}
	elsif ($line =~ /found\:\s+/) {
	  ($crap, $return->{pairs}) = split(/found\:\s+/, $line);
	}
  } ## For every line of pknots
  $string =~ s/\s+/ /g;
  $return->{pk_output} = $string;
  my $parser = new PkParse(debug => 0);
  my @struct_array = split(/ /, $string);
  my $out = $parser->Unzip(\@struct_array);
  my $parsed = '';
  foreach my $char (@{$out}) {
	$parsed .= $char . ' ';
  }
  $return->{parsed} = $parsed;
  if ($parser->{pseudoknot} == 0) {
      $return->{knotp} = 0;
  }
  else {
      $return->{knotp} = 1;
  }
  chdir($config->{basedir});
  return($return);
}


sub Mfold {
  my $me = shift;
  my $inputfile = $me->{file};
  my $config = $PRFConfig::config;
  $ENV{MFOLDLIB} = $config->{mfoldlib};

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
  my $command = qq(sh -c "time $config->{mfold} SEQ=$inputfile MAX=1" 2>mfold.err);
  open(MF, "$command 2>mfold.err |") or PRF_Error("Could not run mfold: $!", $species, $accession);
#  open(MF, "/bin/true |");
#  print "Running mfold\n";
#  sleep(2);
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
#  my @extra_files = ('ann', 'cmd', 'ct', 'det', 'h-num', 'log', 'out', 'plot', 'pnt', 'rnaml', 'sav', 'ss-count', 'gif');
#  for my $ext (@extra_files) {
#	my $stupido_filename = $me->{file} . '*.' . $ext;
#	unlink($stupido_filename);
#  }
#  my $command1 = "rm $me->{file}" . '_* 2>/dev/null';
#  my $command2 = "rm $me->{file}" . '.* 2>/dev/null';
#$command2
#";
#
#  system($command1);
#  system($command2);
#  return($return);
}

sub Pknots_Boot {
    ## The caller of this function is in Bootlace.pm and does not expect it to be
    ## In an OO fashion.
    my $inputfile = shift;
    my $species = shift;
    my $accession = shift;
    my $start = shift;
    my $config = $PRFConfig::config;
#    print "BOOT: infile: $inputfile accession: $accession start: $start\n";
    my $return = {
	accession => $accession,
	start => $start,
	species => $species,
    };

    chdir($config->{tmpdir});
    my $command = qq(sh -c "time $config->{pknots} $inputfile" 2>pknots_boot.err);
    open(PK, "$command |") or PRF_Error("Failed to run pknots: $!", $species, $accession);
    my $counter = 0;
    my ($line_to_read, $crap) = undef;
    my $string = '';
    my $uninteresting = undef;
    while (my $line = <PK>) {
	next if (defined($uninteresting));
	$counter++;
	chomp $line;
	if ($line =~ /^NAM/) {
	    my ($crap, $name) = split(/NAM\s+/, $line);
	}
	elsif ($line =~ /Log odds/) {
	    my ($crap, $logodds) = split(/score\:\s+/, $line);
	}
	elsif ($line =~ m/\/mol\)\:\s+/) {
	    ($crap, $return->{mfe}) = split(/\/mol\)\:\s+/, $line);
	}
	elsif ($line =~ /found\:\s+/) {
	    ($crap, $return->{pairs}) = split(/found\:\s+/, $line);
	    $uninteresting = 1;
	}
	elsif ($line =~ /^\s+\d+\s+[A-Z]+/) {
	    $line_to_read = $counter + 2;
	}
	elsif (defined($line_to_read) and $line_to_read == $counter) {
	    $line =~ s/^\s+//g;
	    $line =~ s/$/ /g;
	    $string .= $line;
	}
    } ## For every line of pknots
    $string =~ s/\s+/ /g;
    $return->{pkout} = $string;
    return($return);
}

sub Mfold_Boot {
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
  my $command = qq(sh -c "time $config->{mfold} SEQ=$inputfile MAX=1" 2>mfold_boot.err);
  open(MF, "$command |") or PRF_Error("Could not run mfold: $!", $species, $accession);
#  open(MF, "/bin/true |");
#  print "Running mfold $command\n";
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
#  my @extra_files = ('ann', 'cmd', 'ct', 'det', 'h-num', 'log', 'out', 'plot', 'pnt', 'rnaml', 'sav', 'ss-count', 'gif');
#  for my $ext (@extra_files) {
#	my $stupido_filename = $me->{file} . '*.' . $ext;
#	unlink($stupido_filename);
#  }
#  my $command1 = "rm $me->{file}" . '_* 2>/dev/null';
#  my $command2 = "rm $me->{file}" . '.* 2>/dev/null';
#  print "TESTME: $command1
#$command2
#";
#
#  system($command1);
#  system($command2);
#  chdir($config->{basedir});
#  return($return);
}

1;
