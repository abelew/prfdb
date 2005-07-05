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
  my $tmp_dir = `pwd`;
  chomp $tmp_dir;
  $tmp_dir .= '/work';
  chdir $tmp_dir;
#  my $command = "$tmp_dir/Nupack $input";
  chdir("/home/trey/dinman/code/browser/work");
  my $command = "/home/trey/dinman/code/browser/work/Nupack $input";
  open(NU, "./Fold.out $input |") or die "Nupack failed $!.";
  while (my $line = <NU>) {
	chomp $line;
	print WRITER "$line<br>\n";
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
