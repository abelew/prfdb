package Input;
use strict;

sub new {
  my ($class, %arg) = @_;
  $arg{filename} = 'STDIN' if (!defined($arg{filename}));
  $arg{format} = 'fasta' if (!defined($arg{format}));
  my $me = bless {
				  filename => $arg{filename},
				  format => $arg{format},
				  sequences => {},
				 }, $class;
  if ($arg{format} eq 'fasta') {
	$me->{sequences} = Read_Fasta($arg{filename}, $arg{format});
  }
  return($me);
}

sub Read_Fasta {
  my $filename = shift;
  my $format = shift;
  my $return =  {};
  open(INPUT, "<$filename");
  my $line_count = 0;
  my $seq_count = 1;
  my $sequence = '';
  while(my $line = <INPUT>) {
	chomp $line;
	if ($line =~ /^\>/ and $line_count == 0) {
	  $return->{$seq_count}->{comment} = $line;
	  $line_count++;
	}
	elsif ($line =~ /^\>/) {
	  $return->{$seq_count}->{sequence} = $sequence;
	  $sequence = '';
	  $seq_count++;
	  $return->{$seq_count}->{comment} = $line;
	}
	else {
	  $sequence .= $line;
	}
  }  ## End of the input file.
  $return->{$seq_count}->{sequence} = $sequence;
#  print "TEST: $seq_count $sequence\n";
  return($return);
}

1;
