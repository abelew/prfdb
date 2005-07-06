package RNAFolders;
use strict;
use IO::Handle;
use POSIX 'setsid';

sub new {
  my ($class, %arg) = @_;
  my $me = bless {
				  file => $arg{file},
				  accession => $arg{accession},
				  start => $arg{start},
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
  my $return = { accession => $accession,
				 start => $start,
				 species => $species,
			   };
  my $child_pid;
  chdir("/home/trey/dinman/code/browser/work");
  my $command = "/home/trey/dinman/code/browser/work/Fold.out $input";
  open(NU, "$command $input |") or die "Nupack failed $!.";
  my $count = 0;
  while (my $line = <NU>) {
	$count++;
	## The first 15 lines of nupack output are worthless.
	next unless($count > 14);
	chomp $line;
	if ($count == 15) {
	  print "TEST: $line\n";
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
  open(PAIRS, "<out.pair") or die "Could not open the pairs file: $!";
  my $pairs = '';
  while(my $line = <PAIRS>) {
	chomp $line;
	$pairs .= $line . ',';
  }
  close(PAIRS);
  unlink("out.pair");
  $return->{pairs} = $pairs;
  chdir("/home/trey/dinman/code/browser");
  return($return);
}

sub Pknots {
  my $me = shift;
  my $input = $me->{file};
  my $return = {};
  my $command = "pknots $input";
  open(PK, "$command |");
  while (my $line = <PK>) {
	chomp $line;
	print "$line<br>\n";
  }
}




1;
