package RNAFolders;
use strict;
use IO::Handle;
use lib 'lib';
use PkParse;
use PRFConfig qw / PRF_Error /;
my $config = $PRFConfig::config;

sub new {
  my ($class, %arg) = @_;
  my $me = bless {
                  file => $arg{file},
		  genome_id => $arg{genome_id},
		  species => $arg{species},
                  accession => $arg{accession},
                  start => $arg{start},
                  slippery => $arg{slippery},
                 }, $class;
  return ($me);
}

sub Nupack {
  my $me = shift;
  my $inputfile = $me->{file};
  my $accession = $me->{accession};
  my $start = $me->{start};
  print "NUPACK: infile: $inputfile accession: $accession start: $start\n";
  my $slipsite = Get_Slipsite_From_Input($inputfile);
  my $return = {
      start => $start,
      slipsite => $slipsite,
      knotp => 0,
      genome_id => $me->{genome_id},
      species => $me->{species},
      accession => $me->{accession},
  };
  chdir($config->{tmpdir});
  my $command = qq($config->{nupack} $inputfile 2>nupack.err);
  my $nupack_pid = open(NU, "$command |") or PRF_Error("Could not run nupack: $!", $accession);
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
      elsif ($count == 17) { ## Line 17 returns the input sequence
	  $return->{sequence} = $line;
      }
      elsif ($count == 18) { ## Line 18 returns paren output
	  $return->{output} = $line;
	  $return->{parens} = $line;
      }
      elsif ($count == 19) { ## Get the MFE here
	  my $tmp = $line;
	  $tmp =~ s/^mfe\ \=\ //g;
	  $tmp =~ s/\ kcal\/mol//g;
	  $return->{mfe} = $tmp;
      }
      elsif ($count == 20) { ## Is it a pseudoknot?
	  if ($line eq 'pseudoknotted!') {
	      $return->{knotp} = 1;
	  }
	  else {
	      $return->{knotp} = 0;
	  }
      }
  }  ## End of the line reading the nupack output.
  close(NU);
  my $nupack_return = $?;
  unless ($nupack_return eq '0' or $nupack_return eq '256') {
      PRFConfig::PRF_Error("Nupack Error: $!", $accession);
      die("Nupack Error! $!");
  }
  open(PAIRS, "<out.pair") or PRF_Error("Could not open the nupack pairs file: $!", $accession);
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
  my $parser;
  if (defined($config->{max_spaces})) {
      my $max_spaces = $config->{max_spaces};
      $parser = new PkParse(debug => 0, max_spaces => $max_spaces);
  }
  else {
      $parser = new PkParse(debug => 0);
  }
  my $out = $parser->Unzip(\@nupack_output);
  my $new_struc = PkParse::ReBarcoder($out);
  my $barcode = PkParse::Condense($new_struc);
  my $parsed = '';
  foreach my $char (@{$out}) {
      $parsed .= $char . ' ';
  }
  $return->{parsed} = $parsed;
  $return->{barcode} = $barcode;
  chdir($config->{basedir});
  return($return);
}

sub Nupack_NOPAIRS {
  my $me = shift;
  my $inputfile = $me->{file};
  my $accession = $me->{accession};
  my $start = $me->{start};
  print "NUPACK: infile: $inputfile accession: $accession start: $start\n";
  my $slipsite = Get_Slipsite_From_Input($inputfile);
  my $return = {
      start => $start,
      slipsite => $slipsite,
      knotp => 0,
      genome_id => $me->{genome_id},
      species => $me->{species},
      accession => $me->{accession},
  };
  chdir($config->{tmpdir});
  my $command = qq($config->{nupack} $inputfile 2>nupack.err);
  my $nupack_pid = open(NU, "$command |") or PRF_Error("Could not run nupack: $!", $accession);
  my $count = 0;
  my @nupack_output = ();
  my $pairs = 0;
  while (my $line = <NU>) {
      $count++;
      ## The first 15 lines of nupack output are worthless.
      next unless($count > 14);
      chomp $line;
      if ($count == 15) {
	  my ($crap, $len) = split(/\ \=\ /, $line);
	  $return->{seqlength} = $len;
      }
      elsif ($count == 17) { ## Line 17 returns the input sequence
	  $return->{sequence} = $line;
      }
      elsif ($line =~ /^\d+\s\d+$/) {
	  my ($fiveprime, $threeprime) = split(/\s+/, $line);
	  $nupack_output[$threeprime] = $fiveprime;
	  $nupack_output[$fiveprime] = $threeprime;
          $pairs++;
	  $count--;
      }
      elsif ($count == 18) { ## Line 18 returns paren output
	  $return->{output} = $line;
	  $return->{parens} = $line;
      }
      elsif ($count == 19) { ## Get the MFE here
	  my $tmp = $line;
	  $tmp =~ s/^mfe\ \=\ //g;
	  $tmp =~ s/\ kcal\/mol//g;
	  $return->{mfe} = $tmp;
      }
      elsif ($count == 20) { ## Is it a pseudoknot?
	  if ($line eq 'pseudoknotted!') {
	      $return->{knotp} = 1;
	  }
	  else {
	      $return->{knotp} = 0;
	  }
      }
  }  ## End of the line reading the nupack output.
  close(NU);
  my $nupack_return = $?;
  unless ($nupack_return eq '0' or $nupack_return eq '256') {
      PRFConfig::PRF_Error("Nupack Error: $!", $accession);
      die("Nupack Error! $!");
  }
  for my $c (0 .. $#nupack_output) {
      $nupack_output[$c] = '.' unless(defined $nupack_output[$c]);
  }
  $return->{pairs} = $pairs;
  my $parser;
  if (defined($config->{max_spaces})) {
      my $max_spaces = $config->{max_spaces};
      $parser = new PkParse(debug => 0, max_spaces => $max_spaces);
  }
  else {
      $parser = new PkParse(debug => 0);
  }
  my $out = $parser->Unzip(\@nupack_output);
  my $new_struc = PkParse::ReBarcoder($out);
  my $barcode = PkParse::Condense($new_struc);
  my $parsed = '';
  foreach my $char (@{$out}) {
      $parsed .= $char . ' ';
  }
  $return->{parsed} = $parsed;
  $return->{barcode} = $barcode;
  chdir($config->{basedir});
  return($return);
}

sub Pknots {
  my $me = shift;
  my $inputfile = $me->{file};
  my $accession = $me->{accession};
  my $start = $me->{start};
  print "PKNOTS: infile: $inputfile accession: $accession start: $start\n";
  my $slipsite = Get_Slipsite_From_Input($inputfile);
  my $seq = Get_Sequence_From_Input($inputfile);
  my $return = {
      start => $start,
      slipsite => $slipsite,
      knotp => 0,
      genome_id => $me->{genome_id},
      species => $me->{species},
      accession => $me->{accession},
      sequence => $seq,
      seqlength => length($seq),
  };
  chdir($config->{tmpdir});
  my $command = qq($config->{pknots} -k $inputfile 2>pknots.err);
  open(PK, "$command |") or PRF_Error("Could not run pknots: $!", $accession);
  my $counter = 0;
  my ($line_to_read, $crap) = undef;
  my $string = '';
  my $uninteresting = undef;
  my $parser;
  while (my $line = <PK>) {
	$counter++;
	chomp $line;
	### The NAM field prints out the name of the sequence
	### Which is set to the slippery site in RNAMotif
	if ($line =~ /^NAM/) {
	  ($crap, $return->{slipsite}) = split(/NAM\s+/, $line);
	  $return->{slipsite} =~ tr/actgTu/ACUGUU/;
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
  close(PK);
  my $pknots_return = $?;
  unless ($pknots_return eq '0' or $pknots_return eq '256') {
      PRFConfig::PRF_Error("Pknots Error: $!", $accession);
      die("Pknots Error! $!");
  }
  $string =~ s/\s+/ /g;
  $return->{output} = $string;
  if (defined($config->{max_spaces})) {
      my $max_spaces = $config->{max_spaces};
      $parser = new PkParse(debug => 0, max_spaces => $max_spaces);
  }
  else {
      $parser = new PkParse(debug => 0);
  }
  my @struct_array = split(/ /, $string);
  my $out = $parser->Unzip(\@struct_array);
  my $new_struc = PkParse::ReBarcoder($out);
  my $barcode = PkParse::Condense($new_struc);
  my $parsed = '';
  foreach my $char (@{$out}) {
	$parsed .= $char . ' ';
  }
  $return->{parsed} = $parsed;
  $return->{barcode} = $barcode;
  $return->{parens} = PkParse::MAKEBRACKETS(\@struct_array);
  if ($parser->{pseudoknot} == 0) {
      $return->{knotp} = 0;
  }
  else {
      $return->{knotp} = 1;
  }
  chdir($config->{basedir});
  return($return);
}

sub Get_Sequence_From_Input {
    my $inputfile = shift;
    open(SEQ, "<$inputfile");
    my $seq;
    while(my $line = <SEQ>) {
	chomp $line;
	if ($line =~ /^\>/) {
	    next;
	}
	else {
	    $seq .= $line;
	}
    }
    close(SEQ);
    return($seq);
}


sub Get_Slipsite_From_Input {
    my $inputfile = shift;
    open(SLIP, "<$inputfile");
    my ($slipsite, $crap);
    while(my $line = <SLIP>) {
	chomp $line;
	if ($line =~ /^\>/) {
	    ($slipsite, $crap) = split(/ /, $line);
	    $slipsite =~ tr/actgTu/ACUGUU/;
	    $slipsite =~ s/\>//g;
	}
	else {next;}
    }
    close(SLIP);
    return($slipsite);
}

sub Pknots_Boot {
    ## The caller of this function is in Bootlace.pm and does not expect it to be
    ## In an OO fashion.
    my $inputfile = shift;
    my $accession = shift;
    my $start = shift;
#    print "BOOT: infile: $inputfile accession: $accession start: $start\n";
##  This expected for a bootlace include:
##  MFE, PAIRS
    my $return = {
	accession => $accession,
	start => $start,
    };
    chdir($config->{tmpdir});
    my $command = qq($config->{pknots} $inputfile 2>pknots_boot.err);
    open(PK, "$command |") or PRF_Error("Failed to run pknots: $!", $accession);
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
    close(PK);
    my $pknots_return = $?;
    unless ($pknots_return eq '0' or $pknots_return eq '256') {
      PRFConfig::PRF_Error("Pknots Error: $!", $accession);
      die("Pknots Error! $!");
  }
    return($return);
}

sub Nupack_Boot {
  ## The caller of this function is in Bootlace.pm and does not expect it to be
  ## In an OO fashion.
  my $inputfile = shift;
  my $accession = shift;
  my $start = shift;
  #    print "Nupack_BOOT: infile: $inputfile accession: $accession start: $start\n";
  my $return = {
		accession => $accession,
		start => $start,
	       };
  chdir($config->{tmpdir});
  my $command = qq($config->{nupack_boot} $inputfile 2>nupack_boot.err);
  open(NU, "$command |") or PRF_Error("Failed to run nupack: $!", $accession);
  my $count = 0;
  while (my $line = <NU>) {
    chomp $line;
    $count++;
    if ($count == 19) {
      my $tmp = $line;
      $tmp =~ s/^mfe\ \=\ //g;
      $tmp =~ s/\ kcal\/mol//g;
      $return->{mfe} = $tmp;
    }
    else {
      next;
    }
  }  ## End of the output from nupack_boot
  close(NU);
  my $nupack_return = $?;
  unless ($nupack_return eq '0' or $nupack_return eq '256') {
    PRFConfig::PRF_Error("Nupack Error: $!", $accession);
    die("Nupack Error! $!");
  }

  open(PAIRS, "<out.pair") or PRF_Error("Could not open the nupack pairs file: $!", $accession);
  my $pairs = 0;
  my @nupack_output = ();
  while(my $line = <PAIRS>) {
    chomp $line;
    $pairs++;
    my ($fiveprime, $threeprime) = split(/\s+/, $line);
    $nupack_output[$threeprime] = $fiveprime;
    $nupack_output[$fiveprime] = $threeprime;
  }  ## End of the pairs file
  for my $c (0 .. $#nupack_output) {
    $nupack_output[$c] = '.' unless(defined $nupack_output[$c]);
  }
  close(PAIRS);
  unlink("out.pair");
  $return->{pairs} = $pairs;
  return($return);
}

sub Nupack_Boot_NOPAIRS {
    ## The caller of this function is in Bootlace.pm and does not expect it to be
    ## In an OO fashion.
    my $inputfile = shift;
    my $accession = shift;
    my $start = shift;
#    print "Nupack_BOOT: infile: $inputfile accession: $accession start: $start\n";
    my $return = {
	accession => $accession,
	start => $start,
    };
    chdir($config->{tmpdir});
    my $command = qq($config->{nupack_boot} $inputfile 2>nupack_boot.err);
    my @nupack_output;
    open(NU, "$command |") or PRF_Error("Failed to run nupack: $!", $accession);
    my $counter = 0;
    my $pairs = 0;
    while (my $line = <NU>) {
	chomp $line;
	$counter++;
	if ($line =~ /^\d+\s\d+$/) {
	    my ($fiveprime, $threeprime) = split(/\s+/, $line);
	    $nupack_output[$threeprime] = $fiveprime;
	    $nupack_output[$fiveprime] = $threeprime;
	    $pairs++;
	    $counter--;
#            print "GOT LINE: $line pairs: $pairs\n";
	}
	elsif ($counter == 19) {
	    my $tmp = $line;
	    $tmp =~ s/^mfe\ \=\ //g;
	    $tmp =~ s/\ kcal\/mol//g;
	    $return->{mfe} = $tmp;
	}
	else {
	    next;
	}
    }  ## End of the output from nupack_boot
    close(NU);
    my $nupack_return = $?;
    unless ($nupack_return eq '0' or $nupack_return eq '256') {
      PRFConfig::PRF_Error("Nupack Error: $!", $accession);
      die("Nupack Error! $!");
    }
    $return->{pairs} = $pairs;
    return($return);
}

1;
