#!/usr/bin/perl -w
use strict;
use lib '.';
use SubstMatrix;
#use AppConfig;
use Getopt::Long;
use Carp;

my $aa = new SubstMatrix();
my $aa_matrix = $aa->Read_Matrix();
my $config = Get_Configuration();
my $inputs = Read_Inputs();
my $matrix = Dynamic($inputs, $aa_matrix);
my $alignment = NW_TraceBack($matrix, $inputs);
Print_Html_Matrix($matrix,$inputs, $alignment);
Print_Matrix($matrix);

sub NW_TraceBack {
  my $matrix = shift;
  my $inputs = shift;

  my @horiz = @{$inputs->{horiz_array}};
  my @vert = @{$inputs->{vert_array}};

  my %pos = ( 'x' => scalar(@horiz), 'y' => scalar(@vert) );
  my ($top_line, $middle_line, $bottom_line) = '';
#  print "The max score is: $start_pos->[0]->{score}, Held by:\n";
  my @traces = ();
  my @trace = ();
#	print "$pos{'x'},$pos{'y'}\n";
  my $current_x = $pos{'x'};
  my $current_y = $pos{'y'};
  while ($current_x > 0 and $current_y > 0) {
	my $best = $matrix->[$current_x]->[$current_y]->{direction};
#	print "TESTING: $best for $current_x and $current_y\n";
	my $direction = '';
	if ($best eq 'col') { $current_y--; $direction = 'col'; }
	elsif ($best eq 'row') { $current_x--; $direction = 'row'; }
	elsif ($best eq 'diag') { $current_x--; $current_y--; $direction = 'diag'; }
	elsif ($best eq 'all') {$current_x--; $current_y--; $direction = 'diag';}
	elsif ($best eq 'diag+row') {$current_x--;$current_y--;$direction='diag';}
	elsif ($best eq 'diag+col') {$current_x--;$current_y--;$direction='diag';}
	elsif($best eq 'row+col') {$current_x--;$direction='row';}
	elsif ($best eq 'null') {$current_x--; $current_y--; $direction='diag'; }
	push(@trace, { direction => $direction , 'horiz' => $current_x , 'vert' => $current_y });
  }  ## End of while
  my $trace = Interpret_Trace(\@trace, $inputs);
}

sub Interpret_Trace {
  my $trace = shift;
  my $inputs = shift;
  my $horiz_string;
  my $mid_string;
  my $vert_string;
  foreach my $move (@{$trace}) {
	if ($move->{direction} eq 'diag') {
	  $horiz_string = $horiz_string . "$inputs->{horiz_array}->[$move->{horiz}]";
	  $mid_string = $mid_string . "|";
	  $vert_string = $vert_string . "$inputs->{vert_array}->[$move->{vert}]";
	}
	elsif ($move->{direction} eq 'row') {
	  $horiz_string = $horiz_string . "$inputs->{horiz_array}->[$move->{horiz}]";
	  $mid_string = $mid_string . " ";
	  $vert_string = $vert_string . "_";
	}
	elsif ($move->{direction} eq 'col') {
	  $horiz_string = $horiz_string . "_";
	  $mid_string = $mid_string . " ";
	  $vert_string = $vert_string . "$inputs->{vert_array}->[$move->{vert}]";
	}
  }
  $horiz_string = reverse $horiz_string;
  $mid_string = reverse $mid_string;
  $vert_string = reverse $vert_string;
  return[$horiz_string, $mid_string, $vert_string];
}

sub Max_End {
  my $matrix = shift;
  my @max = ( { score => 0, 'x' => 0, 'y' => 0 },);

  my @ho = @{$matrix};
  for my $h (0 .. $#ho) {
	my @ve = @{$ho[$h]};
	for my $v (0 .. $#ve) {
	  next unless ($v == $#ve or $h == $#ho);
	  if ($matrix->[$h]->[$v]->{best} == $max[0]->{score}) {
		my %tmp = ( 'x' => $h, 'y' => $v );
		push(@max, \%tmp);
	  }
	  elsif ($matrix->[$h]->[$v]->{best} > $max[0]->{score}) {
		@max = ();
		my %tmp = ( score => $matrix->[$h]->[$v]->{best}, 'x' => $h, 'y' => $v);
		push(@max, \%tmp);
	  }
	}
  }
  return(\@max);
}

sub Read_Inputs {
  my $inputs = {
				horiz => undef,
				vert => undef,
			   };

  if (defined($config->{first_input})) { $inputs->{horiz} = $config->{first_input}; }
  elsif (defined($config->{first_input_file})) {	$inputs->{horiz} = Read_File($config->{first_input_file}); }
  else { croak("This script requires a first input."); }

  if (defined($config->{second_input})) { $inputs->{vert} = $config->{second_input}; }
  elsif (defined($config->{second_input_file})) { $inputs->{vert} = Read_File($config->{second_input_file}); }
  else { croak("This script requires a second input."); }

  $inputs->{vert} =~ tr/a-z/A-Z/;
  $inputs->{horiz} =~ tr/a-z/A-Z/;
  my @vert_tmp = split(//, $inputs->{vert});
  my @horiz_tmp = split(//, $inputs->{horiz});
  $inputs->{vert_array} = \@vert_tmp;
  $inputs->{horiz_array} = \@horiz_tmp;
#  print "TESTING: $inputs->{horiz_array}->[4]\n";
  return($inputs);
}

sub Read_File {
  my $filename = shift;
  my $sequence = '';
  croak("The file: $filename is not readable: $!") unless (-r $filename);
  open(IN, "<$filename") or croak ("Could not open $filename: $!");
  while(my $line = <IN>) {
	next if ($line =~ /^\>/);
	chomp $line;
	$line =~ s/\s//g;
	$line =~ tr/a-z/A-Z/;
	$sequence = $sequence . $line;
  }
  my $length = length($sequence);
  croak("The sequence is too short: $length bases") if ($length < 3);
  return($sequence);
}

sub Get_Configuration {
  my %config = (
				first_input => undef,
				first_input_file => 'first.fasta',
				second_input => undef,
				second_input_file => 'second.fasta',
				matrix_file => undef,
				gap_penalty => '8.0',
				algorithm => 'Needleman Wunsch',
				matrix => 'blosum62',
			   );
  my %data = ();
  foreach my $k (keys %data) {
	$config{$k} = $data{$k};
  }
  GetOptions(
			 'in1|1:s' => \$config{first_input},
			 'infile1|f1:s' => \$config{first_input_file},
			 'in2|2:s' => \$config{second_input},
			 'infile2|f2:s' => \$config{second_input_file},
			 'gap|g:f' => \$config{gap_penalty},
			 'matrixfile|f:s' => \$config{matrix_file},
			 'matrix|m:s' => \$config{matrix},
			 'algorithm|a:s' => \$config{algorithm},
			 'verbose' => \$config{verbose},
	 		 'quiet'   => sub { $config{verbose} = 0 });
  if ($config{algorithm} =~ /^[s|S]/) {
	print "Smith Waterman!\n";
	$config{algorithm} = 'Smith Waterman';
  }

 return(\%config);
}

sub Go_Away {
}

sub Print_Matrix {
  my $matrix = shift;
  my @ho = @{$matrix};
  for my $h (0 .. $#ho) {
	my @ve = @{$ho[$h]};
	for my $v (0 .. $#ve) {
	  my %datum = %{$ve[$v]};
	  print " $datum{best},";
	}
	print "\n";
  }
}

sub Print_Html_Matrix {
  my $matrix = shift;
  my $inputs = shift;
  my $traceback = shift;
  my @hor_seq = @{$inputs->{horiz_array}};
  my @ver_seq = @{$inputs->{vert_array}};
#  print "TEST: @hor_seq\n";
  open(OUT, ">dynamic.html");
  print OUT "<html>
  <table>
";
  print OUT "    <tr>
      <td></td>\n";
  foreach my $ve_char (@ver_seq) {
	print OUT "      <td align=center width=20>$ve_char</td>\n";
  }
  print OUT "      <td></td>
    </tr>\n";
  my @ve = @{$matrix};
  my $horizontal_counter = -1;

  for my $v (0 .. $#ve) {
	print OUT "    <tr>\n";
	my @ho = @{$ve[$v]};
	for my $h (0 .. $#ho) {
	  my %datum = %{$ho[$h]};

	  if ($datum{direction} eq 'null') {
	  print OUT "      <td width=45>
       <table width=45 align=center>
        <tr>
          <td width=20><!--- row - 1, column - 1>$datum{minusxy}</td>
          <td width=20><!-- column -1>$datum{minusx}</td>
        </tr>
        <tr>
         <td width=20><!-- row -1>$datum{minusy}</td>
         <td width=20><!-- best>$datum{best}</td>
        </tr>
       </table>
      </td>\n";
	}
	  elsif ($datum{direction} eq 'all') {
	  print OUT "      <td width=45>
       <table width=45 align=center>
        <tr>
          <td width=20 bgcolor='gray'><!--- row - 1, column - 1>$datum{minusxy}</td>
          <td width=20 bgcolor='gray'><!-- column -1>$datum{minusx}</td>
        </tr>
        <tr>
         <td width=20 bgcolor='gray'><!-- row -1>$datum{minusy}</td>
         <td width=20 bgcolor='gray'><!-- best>$datum{best}</td>
        </tr>
       </table>
      </td>\n";
	}
	  elsif ($datum{direction} eq 'diag+row') {
	  print OUT "      <td width=45>
       <table width=45 align=center>
        <tr>
          <td width=20 bgcolor='yellow'><!--- row - 1, column - 1>$datum{minusxy}</td>
          <td width=20 bgcolor='yellow'><!-- column -1>$datum{minusx}</td>
        </tr>
        <tr>
         <td width=20><!-- row -1>$datum{minusy}</td>
         <td width=20 bgcolor='yellow'><!-- best>$datum{best}</td>
        </tr>
       </table>
      </td>\n";
	}
	  elsif ($datum{direction} eq 'diag+col') {
	  print OUT "      <td width=45>
       <table width=45 align=center>
        <tr>
          <td width=20 bgcolor='blue'><!--- row - 1, column - 1>$datum{minusxy}</td>
          <td width=20><!-- column -1>$datum{minusx}</td>
        </tr>
        <tr>
         <td width=20 bgcolor='blue'><!-- row -1>$datum{minusy}</td>
         <td width=20 bgcolor='blue'><!-- best>$datum{best}</td>
        </tr>
       </table>
      </td>\n";
	}
	  elsif ($datum{direction} eq 'row+col') {
	  print OUT "      <td width=45>
       <table width=45 align=center>
        <tr>
          <td width=20><!--- row - 1, column - 1>$datum{minusxy}</td>
          <td width=20 bgcolor='orange'><!-- column -1>$datum{minusx}</td>
        </tr>
        <tr>
         <td width=20 bgcolor='orange'><!-- row -1>$datum{minusy}</td>
         <td width=20 bgcolor='orange'><!-- best>$datum{best}</td>
        </tr>
       </table>
      </td>\n";
	}
	  elsif ($datum{direction} eq 'diag') {
	  print OUT "      <td width=45>
       <table width=45 align=center>
        <tr>
          <td width=20 bgcolor='green'><!--- row - 1, column - 1>$datum{minusxy}</td>
          <td width=20><!-- column -1>$datum{minusx}</td>
        </tr>
        <tr>
         <td width=20><!-- row -1>$datum{minusy}</td>
         <td width=20 bgcolor='green'><!-- best>$datum{best}</td>
        </tr>
       </table>
      </td>\n";
	}
	  elsif ($datum{direction} eq 'row') {
		print OUT "      <td width=45>
       <table width=45 align=center>
        <tr>
          <td width=20><!--- row - 1, column - 1>$datum{minusxy}</td>
          <td width=20 bgcolor='red'><!-- column -1>$datum{minusx}</td>
        </tr>
        <tr>
          <td width=20><!-- row -1>$datum{minusy}</td>
          <td width=20 bgcolor='red'><!-- best>$datum{best}</td>
        </tr>
       </table>
      </td>\n";
	}
	  elsif ($datum{direction} eq 'col') {
		print OUT "      <td width=45>
       <table width=45 align=center>
        <tr>
          <td width=20><!--- row - 1, column - 1>$datum{minusxy}</td>
          <td width=20><!-- column -1>$datum{minusx}</td>
        </tr>
        <tr>
          <td width=20 bgcolor='cyan'><!-- row -1>$datum{minusy}</td>
          <td width=20 bgcolor='cyan'><!-- best>$datum{best}</td>
        </tr>
       </table>
      </td>\n";
	  }

	  if ($h == $#ho) {
		if ($horizontal_counter == -1) {
		  print OUT "    <td width=20></td>\n";
		}
		else {
		  print OUT "    <td width=20>$hor_seq[$horizontal_counter]</td>\n";
		}
		$horizontal_counter++;
	  }

	}
	print OUT "    </tr>\n\n";
  }
print OUT "  </table>
<p>
<center>
<pre>
$traceback->[0]
$traceback->[1]
$traceback->[2]
</pre>
</center>
</p>
</html>\n";
  close(OUT);
}

sub Dynamic {
  my $inputs = shift;
  my $aa_matrix = shift;
  my $matrix = [];

  $inputs->{horiz} = '0' . $inputs->{horiz};
  my @horiz = split(//, $inputs->{horiz});
  $inputs->{vert} = '0' . $inputs->{vert};
  my @vert = split(//, $inputs->{vert});
  ## Start at the 2nd position of the arrays so that the first can be null
  for my $h (0 .. $#horiz) {
	$matrix->[$h] = [];
	for my $v (0 .. $#vert) {
	  my $ho = $horiz[$h];
	  my $ve = $vert[$v];
	  my ($mxy, $mx, $my, $best);
	  if ($v == 0 and $h == 0) {
		$mxy = $mx = $my = 0;
	  }
	  elsif ($h == 0) {
		$mxy = $mx = $my = $matrix->[$h]->[$v-1]->{best} - $config->{gap_penalty};
	  }
	  elsif ($v == 0) {
		$mxy = $mx = $my = $matrix->[$h-1]->[$v]->{best} - $config->{gap_penalty};
	  }
	  else {
#		print "TEST MXY: $aa_matrix->{$ho}{$ve}\n";
		$mxy = $aa_matrix->{$ho}{$ve} + $matrix->[$h-1]->[$v-1]->{best};
		$mx = $matrix->[$h-1]->[$v]->{best} - $config->{gap_penalty};
		$my = $matrix->[$h]->[$v-1]->{best} - $config->{gap_penalty};
	  }
	  $matrix->[$h]->[$v]->{minusxy} = $mxy;
	  $matrix->[$h]->[$v]->{minusx} = $mx;
	  $matrix->[$h]->[$v]->{minusy} = $my;
#	  print "TEST: $mxy, $mx, $my\n";
	  my $tm = Highest($mxy, $mx, $my);
	  $matrix->[$h]->[$v]->{best} = $tm->[0];
	  $matrix->[$h]->[$v]->{direction} = $tm->[1];
	} ## for every entry of the vertical sequence
  }       ## for every entry of the horizontal sequence
  return($matrix);
}

sub Highest {
  my $diag = shift;
  my $row = shift;
  my $col = shift;
#  print "Running highest of $diag, $row, $col\n";
  my $answer = [];
  if ($diag == $row and $diag == $col) {
	$answer = [$diag, 'all'];
  }
  elsif ($diag == $row and $diag > $col) {
	$answer = [$diag, 'diag+row'];
  }
  elsif ($diag == $col and $diag > $row) {
	$answer = [$diag, 'diag+col'];
  }
  elsif ($col == $row and $col > $diag) {
	$answer = [$col, 'row+col'];
  }
  elsif ($diag > $col and $diag > $row) {
	$answer = [$diag, 'diag'];
  }
  elsif ($col > $diag and $col > $row) {
	$answer = [$col, 'col'];
  }
  elsif ($row > $diag and $row > $col) {
	$answer = [$row, 'row'];
  }
  else {
	$answer = [undef, 'error'];
  }

  if ($config->{algorithm} eq 'Smith Waterman') {
	if ($answer->[0] < 0) {
	  $answer = [0, 'null'];
	}
  }
  return($answer);
}






