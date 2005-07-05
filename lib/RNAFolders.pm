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
  my $tmp_dir = `pwd`;
  chomp $tmp_dir;
  $tmp_dir .= '/work';
  chdir $tmp_dir;
  
  if (fork) {  ## Parental code goes in here.
      return(undef);
  }  ## End the parent's code
  else {  ## The child's code goes in here
      setsid();
      my $command = "$tmp_dir/Fold.out $input";
      open (WRITER, ">$input.out") or die "Could not open the nupack output file.<br>\n";
      open(NU, "$command 2>&1 |") or die "Nupack failed. $!\n";
      while (my $line = <NU>) {
	  chomp $line;
	  print WRITER "$line\n";
      }
  }  ## End the children's code
  print "The children's code has ended. So this should come in a timely fashion.<br>\n";
#  my $command = "$tmp_dir/Nupack $input";
#  my $command = "/home/trey/dinman/code/browser/work/Nupack $input";
#  open(NU, "./Fold.out $input |") or die "Nupack failed $!.";
#  while (my $line = <NU>) {
#	chomp $line;
#	print WRITER "$line<br>\n";
#  }
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
