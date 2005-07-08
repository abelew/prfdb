package RNAFolders;
use strict;
use IO::Handle;
use POSIX 'setsid';
use lib 'lib';
use PRFConfig qw(Error);

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
  my $return = { accession => $accession,
				 start => $start,
				 slippery => $slippery,
				 species => $species,
               };
  chdir($config->{tmpdir});
  my $command = "$config->{nupack} $input";
  open(NU, "$command $input 2>nupack.err |") or Error("Could not run nupack: $!");
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
  open(PAIRS, "<out.pair") or Error("Could not open the nupack pairs file: $!");
  my $pairs = '';
  while(my $line = <PAIRS>) {
	chomp $line;
	$pairs .= $line . ',';
  }
  close(PAIRS);
  unlink("out.pair");
  $return->{pairs} = $pairs;
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
  open(PK, "$command $input 2>pknots.err |") or Error("Failed to run pknots: $!");
}

1;
