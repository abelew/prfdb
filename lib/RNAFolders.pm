package RNAFolders;
use strict;
use IO::Handle;
use POSIX 'setsid';

sub new {
  my ($class, %arg) = @_;
  my $me = bless {
				  file => $arg{file},
				 }, $class;
  return ($me);
}

sub Nupack {
  my $me = shift;
  my $input = $me->{file};
  my $return = {};
  my $child_pid;
  open (WRITER, ">nupack.out") or die "Could not open the nupack output file.<br>\n";
  if (!defined($child_pid)) {
	die "Could not fork a child process for nupack. $!<br>\n";
  }
  else {
	## The child process does its work here.
	my $tmp_dir = `pwd` . '/work';
	chdir $tmp_dir;
	my $command = "./Nupack $input";
	open(NU, "$command |") or die "Nupack failed.";
	while (my $line = <NU>) {
	  chomp $line;
	  print WRITER "$line<br>\n";
	}
  }
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
