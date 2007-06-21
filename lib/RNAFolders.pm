package RNAFolders;
use strict;
use IO::Handle;
use lib 'lib';
use PkParse;
use PRFConfig qw / PRF_Error /;
my $config = $PRFConfig::config;

sub new {
  my ( $class, %arg ) = @_;
  my $me = bless {
    file      => $arg{file},
    genome_id => $arg{genome_id},
    species   => $arg{species},
    accession => $arg{accession},
    start     => $arg{start},
    slippery  => $arg{slippery},
  }, $class;
  return ($me);
}

sub Nupack {
  my $me        = shift;
  my $pseudo    = shift;
  my $inputfile = $me->{file};
  my $accession = $me->{accession};
  my $start     = $me->{start};
  my $slipsite = Get_Slipsite_From_Input($inputfile);
  my $return   = {
    start     => $start,
    slipsite  => $slipsite,
    knotp     => 0,
    genome_id => $me->{genome_id},
    species   => $me->{species},
    accession => $me->{accession},
  };
  chdir( $config->{workdir} );
  my $command;
  die("dataS_G.dna is missing.") unless ( -r "dataS_G.dna" );
  die("dataS_G.rna is missing.") unless ( -r "dataS_G.rna" );

  if ( defined($pseudo) and $pseudo eq 'nopseudo' ) {
    die("$config->{nupack_boot} is missing.") unless ( -r $config->{nupack_boot} );
    $command = qq($config->{nupack_boot} $inputfile 2>nupack.err);
  } else {
    die("$config->{nupack} is missing.") unless ( -r $config->{nupack} );
    $command = qq($config->{nupack} $inputfile 2>nupack.err);
  }
  print "NUPACK: infile: $inputfile accession: $accession start: $start
command: $command\n";
  my $nupack_pid = open( NU, "$command |" ) or PRF_Error( "RNAFolders::Nupack, Could not run nupack: $!", $accession );
  ## OPEN NU in Nupack
  my $count = 0;
  while ( my $line = <NU> ) {
    $count++;
    ## The first 15 lines of nupack output are worthless.
    next unless ( $count > 14 );
    chomp $line;
    if ( $count == 15 ) {
      my ( $crap, $len ) = split( /\ \=\ /, $line );
      $return->{seqlength} = $len;
    } elsif ( $count == 17 ) {    ## Line 17 returns the input sequence
      $return->{sequence} = $line;
    } elsif ( $count == 18 ) {    ## Line 18 returns paren output

      #	  $return->{output} = $line;
      $return->{parens} = $line;

      #	  $return->{parens} = $line;
    } elsif ( $count == 19 ) {    ## Get the MFE here
      my $tmp = $line;
      $tmp =~ s/^mfe\ \=\ //g;
      $tmp =~ s/\ kcal\/mol//g;
      $return->{mfe} = $tmp;
    } elsif ( $count == 20 ) {    ## Is it a pseudoknot?
      if ( $line eq 'pseudoknotted!' ) {
        $return->{knotp} = 1;
      } else {
        $return->{knotp} = 0;
      }
    }
  }    ## End of the line reading the nupack output.
  close(NU);
  ## CLOSE NU in Nupack
  my $nupack_return = $?;
  unless ( $nupack_return eq '0' or $nupack_return eq '256' ) {
    PRFConfig::PRF_Error( "Nupack Error: $!", $accession );
    die("Nupack Error! $!");
  }
  open( PAIRS, "<out.pair" ) or PRF_Error( "Could not open the nupack pairs file: $!", $accession );
  ## OPEN PAIRS in Nupack
  my $pairs         = 0;
  my @nupack_output = ();
  while ( my $line = <PAIRS> ) {
    chomp $line;
    $pairs++;
    my ( $fiveprime, $threeprime ) = split( /\s+/, $line );
    my $five  = $fiveprime - 1;
    my $three = $threeprime - 1;
    $nupack_output[$three] = $five;
    $nupack_output[$five]  = $three;
  }
  for my $c ( 0 .. $#nupack_output ) {
    $nupack_output[$c] = '.' unless ( defined $nupack_output[$c] );
  }
  close(PAIRS);
  ## CLOSE PAIRS in Nupack
  unlink("out.pair");
  my $nupack_output_string = '';
  foreach my $char (@nupack_output) { $nupack_output_string .= "$char "; }
  $return->{output} = $nupack_output_string;
  $return->{pairs}  = $pairs;
  my $parser;
  if ( defined( $config->{max_spaces} ) ) {
    my $max_spaces = $config->{max_spaces};
    $parser = new PkParse( debug => 0, max_spaces => $max_spaces );
  } else {
    $parser = new PkParse( debug => 0 );
  }
  my $out       = $parser->Unzip( \@nupack_output );
  my $new_struc = PkParse::ReBarcoder($out);
  my $barcode   = PkParse::Condense($new_struc);
  my $parsed    = '';
  foreach my $char ( @{$out} ) {
    $parsed .= $char . ' ';
  }
  $parsed            = PkParse::ReOrder_Stems($parsed);
  $return->{parsed}  = $parsed;
  $return->{barcode} = $barcode;
  chdir( $config->{basedir} );
  $return->{sequence} = Sequence_T_U( $return->{sequence} );
  return ($return);
}

sub Nupack_NOPAIRS {
  my $me        = shift;
  my $pseudo    = shift;
  my $inputfile = $me->{file};
  my $accession = $me->{accession};
  my $start     = $me->{start};
  my $slipsite = Get_Slipsite_From_Input($inputfile);
  my $return   = {
    start     => $start,
    slipsite  => $slipsite,
    knotp     => 0,
    genome_id => $me->{genome_id},
    species   => $me->{species},
    accession => $me->{accession},
  };
  chdir( $config->{workdir} );
  my $command;
  die("dataS_G.dna is missing.") unless ( -r "dataS_G.dna" );
  die("dataS_G.rna is missing.") unless ( -r "dataS_G.rna" );

  if ( defined($pseudo) and $pseudo eq 'nopseudo' ) {
    die("$config->{nupack_boot} is missing.") unless ( -r $config->{nupack_boot} );
    $command = qq($config->{nupack_boot} $inputfile 2>nupack.err);
  } else {
    warn("The nupack executable does not have 'nopairs' in its name") unless ( $config->{nupack} =~ /nopairs/ );
    die("$config->{nupack} is missing.") unless ( -r $config->{nupack} );
    $command = qq($config->{nupack} $inputfile 2>nupack.err);
  }
  print "NUPACK_NOPAIRS: infile: $inputfile accession: $accession start: $start
command: $command\n";
  my $nupack_pid = open( NU, "$command |" ) or PRF_Error( "RNAFolders::Nupack_NOPAIRS, Could not run nupack: $!", $accession );
  ## OPEN NU in Nupack_NOPAIRS
  my $count         = 0;
  my @nupack_output = ();
  my $pairs         = 0;
  while ( my $line = <NU> ) {
    if ( $line =~ /Error opening loop data file: dataS_G.rna/ ) {
      PRF_Error("RNAFolders::Nupack_NOPAIRS, Missing dataS_G.rna!");
    }
    $count++;
    ## The first 15 lines of nupack output are worthless.
    next unless ( $count > 14 );
    chomp $line;
    if ( $count == 15 ) {
      my ( $crap, $len ) = split( /\ \=\ /, $line );
      $return->{seqlength} = $len;
    } elsif ( $count == 17 ) {    ## Line 17 returns the input sequence
      $return->{sequence} = $line;
    } elsif ( $line =~ /^\d+\s\d+$/ ) {
      my ( $fiveprime, $threeprime ) = split( /\s+/, $line );
      my $five  = $fiveprime - 1;
      my $three = $threeprime - 1;
      $nupack_output[$three] = $five;
      $nupack_output[$five]  = $three;
      $pairs++;
      $count--;
    } elsif ( $count == 18 ) {    ## Line 18 returns paren output
      $return->{parens} = $line;
    } elsif ( $count == 19 ) {    ## Get the MFE here
      my $tmp = $line;
      $tmp =~ s/^mfe\ \=\ //g;
      $tmp =~ s/\ kcal\/mol//g;
      $return->{mfe} = $tmp;
    } elsif ( $count == 20 ) {    ## Is it a pseudoknot?
      if ( $line eq 'pseudoknotted!' ) {
        $return->{knotp} = 1;
      } else {
        $return->{knotp} = 0;
      }
    }
  }    ## End of the line reading the nupack output.
  close(NU);
  ## CLOSE NU in Nupack_NOPAIRS
  my $nupack_return = $?;
  unless ( $nupack_return eq '0' or $nupack_return eq '256' ) {
    PRFConfig::PRF_Error( "Nupack Error: $!", $accession );
    die("Nupack Error! $!");
  }
  for my $c ( 0 .. $#nupack_output ) {
    $nupack_output[$c] = '.' unless ( defined $nupack_output[$c] );
  }
  my $nupack_output_string = '';
  foreach my $char (@nupack_output) { $nupack_output_string .= "$char "; }
  $return->{output} = $nupack_output_string;
  $return->{pairs}  = $pairs;
  my $parser;
  if ( defined( $config->{max_spaces} ) ) {
    my $max_spaces = $config->{max_spaces};
    $parser = new PkParse( debug => 0, max_spaces => $max_spaces );
  } else {
    $parser = new PkParse( debug => 0 );
  }
  my $out       = $parser->Unzip( \@nupack_output );
  my $new_struc = PkParse::ReBarcoder($out);
  my $barcode   = PkParse::Condense($new_struc);
  my $parsed    = '';
  foreach my $char ( @{$out} ) {
    $parsed .= $char . ' ';
  }
  $parsed            = PkParse::ReOrder_Stems($parsed);
  $return->{parsed}  = $parsed;
  $return->{barcode} = $barcode;
  chdir( $config->{basedir} );
  $return->{sequence} = Sequence_T_U( $return->{sequence} );
  return ($return);
}

sub Pknots {
  my $me        = shift;
  my $pseudo    = shift;
  my $inputfile = $me->{file};
  my $accession = $me->{accession};
  my $start     = $me->{start};
  my $slipsite = Get_Slipsite_From_Input($inputfile);
  my $seq      = Get_Sequence_From_Input($inputfile);
  my $return   = {
    start     => $start,
    slipsite  => $slipsite,
    knotp     => 0,
    genome_id => $me->{genome_id},
    species   => $me->{species},
    accession => $me->{accession},
    sequence  => $seq,
    seqlength => length($seq),
  };
  chdir( $config->{workdir} );
  my $command;
  die("pknots is missing.") unless ( -r "$config->{pknots}" );

  if ( defined($pseudo) and $pseudo eq 'nopseudo' ) {
    $command = qq($config->{pknots} $inputfile 2>pknots.err);
  } else {
    $command = qq($config->{pknots} -k $inputfile 2>pknots.err);
  }
  print "PKNOTS: infile: $inputfile accession: $accession start: $start
command: $command\n";
  open( PK, "$command |" ) or PRF_Error( "RNAFolders::Pknots, Could not run pknots: $!", $accession );
  ## OPEN PK in Pknots
  my $counter = 0;
  my ( $line_to_read, $crap ) = undef;
  my $string        = '';
  my $uninteresting = undef;
  my $parser;
  while ( my $line = <PK> ) {
    $counter++;
    chomp $line;
    ### The NAM field prints out the name of the sequence
    ### Which is set to the slippery site in RNAMotif
    if ( $line =~ /^NAM/ ) {
      ( $crap, $return->{slipsite} ) = split( /NAM\s+/, $line );
      $return->{slipsite} =~ tr/actgTu/ACUGUU/;
    } elsif ( $line =~ /^\s+\d+\s+[A-Z]+/ ) {
      $line_to_read = $counter + 2;
    } elsif ( defined($line_to_read) and $line_to_read == $counter ) {
      $line =~ s/^\s+//g;
      $line =~ s/$/ /g;
      $string .= $line;
    } elsif ( $line =~ /\/mol\)\:\s+/ ) {
      ( $crap, $return->{mfe} ) = split( /\/mol\)\:\s+/, $line );
    } elsif ( $line =~ /found\:\s+/ ) {
      ( $crap, $return->{pairs} ) = split( /found\:\s+/, $line );
    }
  }    ## For every line of pknots
  close(PK);
  ## CLOSE PK in Pknots
  my $pknots_return = $?;
  unless ( $pknots_return eq '0' or $pknots_return eq '256' or $pknots_return eq '134' ) {
    PRFConfig::PRF_Error( "Pknots Error: $!", $accession );
    die("Pknots Error! $!");
  }
  $string =~ s/\s+/ /g;
  $return->{output} = $string;
  if ( defined( $config->{max_spaces} ) ) {
    my $max_spaces = $config->{max_spaces};
    $parser = new PkParse( debug => 0, max_spaces => $max_spaces );
  } else {
    $parser = new PkParse( debug => 0 );
  }
  my @struct_array = split( / /, $string );
  my $out          = $parser->Unzip( \@struct_array );
  my $new_struc    = PkParse::ReBarcoder($out);
  my $barcode      = PkParse::Condense($new_struc);
  my $parsed       = '';
  foreach my $char ( @{$out} ) {
    $parsed .= $char . ' ';
  }
  $parsed            = PkParse::ReOrder_Stems($parsed);
  $return->{parsed}  = $parsed;
  $return->{barcode} = $barcode;
  $return->{parens}  = PkParse::MAKEBRACKETS( \@struct_array );
  if ( $parser->{pseudoknot} == 0 ) {
    $return->{knotp} = 0;
  } else {
    $return->{knotp} = 1;
  }
  if ( $return->{parens} =~ /\{/ ) {
    $return->{knotp} = 1;
  }
  chdir( $config->{basedir} );
  $return->{sequence} = Sequence_T_U( $return->{sequence} );
  return ($return);
}

sub Get_Sequence_From_Input {
  my $inputfile = shift;
  open( SEQ, "<$inputfile" );
  ## OPEN SEQ in Get_Sequence_From_Input
  my $seq;
  while ( my $line = <SEQ> ) {
    chomp $line;
    if ( $line =~ /^\>/ ) {
      next;
    } else {
      $seq .= $line;
    }
  }
  close(SEQ);
  ## CLOSE SEQ in Get_Sequence_From_Input
  return ($seq);
}

sub Get_Slipsite_From_Input {
  my $inputfile = shift;
  open( SLIP, "<$inputfile" );
  ## OPEN SLIP in Get_Slipsite_From_Input
  my ( $slipsite, $crap );
  while ( my $line = <SLIP> ) {
    chomp $line;
    if ( $line =~ /^\>/ ) {
      ( $slipsite, $crap ) = split( / /, $line );
      $slipsite =~ tr/actgTu/ACUGUU/;
      $slipsite =~ s/\>//g;
    } else {
      next;
    }
  }
  close(SLIP);
  ## CLOSE SLIP in Get_Slipsite_From_Input
  return ($slipsite);
}

sub Pknots_Boot {
  ## The caller of this function is in Bootlace.pm and does not expect it to be
  ## In an OO fashion.
  my $inputfile = shift;
  my $accession = shift;
  my $start     = shift;
  ##  This expected for a bootlace include:
  ##  MFE, PAIRS
  my $return = {
    accession => $accession,
    start     => $start,
  };
  chdir( $config->{workdir} );
  die("pknots is missing.") unless ( -r "$config->{pknots}" );
  my $command = qq($config->{pknots} $inputfile 2>pknots_boot.err);
  open( PK, "$command |" ) or PRF_Error( "RNAFolders::Pknots_Boot, Failed to run pknots: $!", $accession );
  ## OPEN PK in Pknots_Boot
  my $counter = 0;
  my ( $line_to_read, $crap ) = undef;
  my $string        = '';
  my $uninteresting = undef;
  while ( my $line = <PK> ) {
    next if ( defined($uninteresting) );
    $counter++;
    chomp $line;
    if ( $line =~ /^NAM/ ) {
      my ( $crap, $name ) = split( /NAM\s+/, $line );
    } elsif ( $line =~ m/\/mol\)\:\s+/ ) {
      ( $crap, $return->{mfe} ) = split( /\/mol\)\:\s+/, $line );
    } elsif ( $line =~ /found\:\s+/ ) {
      ( $crap, $return->{pairs} ) = split( /found\:\s+/, $line );
      $uninteresting = 1;
    } elsif ( $line =~ /^\s+\d+\s+[A-Z]+/ ) {
      $line_to_read = $counter + 2;
    } elsif ( defined($line_to_read) and $line_to_read == $counter ) {
      $line =~ s/^\s+//g;
      $line =~ s/$/ /g;
      $string .= $line;
    }
  }    ## For every line of pknots
  close(PK);
  ## CLOSE PK in Pknots_Boot
  my $pknots_return = $?;
#  unless ( $pknots_return eq '0' or $pknots_return eq '256' or $pknots_return eq '134' ) {
#    PRFConfig::PRF_Error( "Pknots Error: $!", $accession );
#    die("Pknots Error! $!");
#  }
  return ($return);
}

sub Nupack_Boot {
  ## The caller of this function is in Bootlace.pm and does not expect it to be
  ## In an OO fashion.
  my $inputfile = shift;
  my $accession = shift;
  my $start     = shift;
  my $return    = {
    accession => $accession,
    start     => $start,
  };
  chdir( $config->{workdir} );
  die("dataS_G.dna is missing.")            unless ( -r "dataS_G.dna" );
  die("dataS_G.rna is missing.")            unless ( -r "dataS_G.rna" );
  die("$config->{nupack_boot} is missing.") unless ( -r $config->{nupack_boot} );
  my $command = qq($config->{nupack_boot} $inputfile 2>nupack_boot.err);
  open( NU, "$command |" ) or PRF_Error( "RNAFolders::Nupack_Boot, Failed to run nupack: $!", $accession );
  ## OPEN NU in Nupack_Boot
  my $count = 0;
  while ( my $line = <NU> ) {
    chomp $line;
    $count++;
    if ( $count == 19 ) {
      my $tmp = $line;
      $tmp =~ s/^mfe\ \=\ //g;
      $tmp =~ s/\ kcal\/mol//g;
      $return->{mfe} = $tmp;
    } else {
      next;
    }
  }    ## End of the output from nupack_boot
  close(NU);
  ## CLOSE NU in Nupack_Boot
  my $nupack_return = $?;
  unless ( $nupack_return eq '0' or $nupack_return eq '256' ) {
    PRFConfig::PRF_Error( "Nupack Error: $!", $accession );
    die("Nupack Error! $!");
  }

  open( PAIRS, "<out.pair" ) or PRF_Error( "Could not open the nupack pairs file: $!", $accession );
  ## OPEN PAIRS in Nupack_Boot
  my $pairs         = 0;
  my @nupack_output = ();
  while ( my $line = <PAIRS> ) {
    chomp $line;
    $pairs++;
  }    ## End of the pairs file
  close(PAIRS);
  ## CLOSE PAIRS in Nupack_Boot
  unlink("out.pair");
  $return->{pairs} = $pairs;
  return ($return);
}

sub Nupack_Boot_NOPAIRS {
  ## The caller of this function is in Bootlace.pm and does not expect it to be
  ## In an OO fashion.
  my $inputfile = shift;
  my $accession = shift;
  my $start     = shift;
  my $return    = {
    accession => $accession,
    start     => $start,
  };
  chdir( $config->{workdir} );
  die("dataS_G.dna is missing.")            unless ( -r "dataS_G.dna" );
  die("dataS_G.rna is missing.")            unless ( -r "dataS_G.rna" );
  die("$config->{nupack_boot} is missing.") unless ( -r $config->{nupack_boot} );
  warn("The nupack executable does not have 'nopairs' in its name") unless ( $config->{nupack} =~ /nopairs/ );
  my $command = qq($config->{nupack_boot} $inputfile 2>nupack_boot.err);
  my @nupack_output;
  open( NU, "$command |" ) or PRF_Error( "RNAFolders::Nupack_Boot_NOPAIRS, Failed to run nupack: $!", $accession );
  ## OPEN NU in Nupack_Boot_NOPAIRS
  my $counter = 0;
  my $pairs   = 0;
  while ( my $line = <NU> ) {
    chomp $line;
    $counter++;
    if ( $line =~ /^\d+\s\d+$/ ) {
      $pairs++;
      $counter--;
    } elsif ( $counter == 19 ) {
      my $tmp = $line;
      $tmp =~ s/^mfe\ \=\ //g;
      $tmp =~ s/\ kcal\/mol//g;
      $return->{mfe} = $tmp;
    } else {
      next;
    }
  }    ## End of the output from nupack_boot
  close(NU);
  ## CLOSE NU in Nupack_Boot_NOPAIRS
  my $nupack_return = $?;
  unless ( $nupack_return eq '0' or $nupack_return eq '256' ) {
    PRFConfig::PRF_Error( "Nupack Error: $!", $accession );
    die("Nupack Error! $!");
  }
  $return->{pairs} = $pairs;
  return ($return);
}

sub Sequence_T_U {
  my $sequence = shift;
  $sequence =~ tr/T/U/;
  return ($sequence);
}

1;
