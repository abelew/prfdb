package PkParse;
use PRFdb qw" Callstack ";
use vars qw($VERSION);
$VERSION='20111119';

sub new {
  my ($class, %args) = @_;
  my $me = bless {
      debug => 0,
      max_spaces => defined($args{max_spaces}) ? $args{max_spaces} : 12,
      pseudoknot => 0,
      positions_remaining => 0,
  }, $class;
  if (defined($args{debug})) {
      if ($args{debug} > 1) {
	  $me->{debug} = 1;
      }
  }
  return ($me);
}

### STATE INFORMATION
my $stemid = 0;
## The current stemid;
my $out_pattern = [];
my $parens_pattern = [];
## The output
my $three_back = 0;
my $two_back = 0;
my $last = 0;
## The last position visited
my $current = 0;
## The current position visited
my $next = 0;
## The next position to visit
my $front_pos = 0;
## How far from the font?
my $back_pos = 'initializeme';
## How far from the back?
my $placement = 'f';
## Front or Back
my $spaces = 1000;
## If this is greater than max_spaces then increment the stemid
my $last_pos = -1000;
## ??? Where was I last
my $positions_filled = 0;
## This should be a signal that it is time to restart
my $positions_remaining = 0;
## How many positions are left.
my $times_in_stem = 0;
## How many times Have I been in the current stem?
my $num_loops = 0;
## How many times has Unwind been called? if too many, error out

sub Unzip {
    my $me = shift;
    my $in_pattern = shift;
    ## First pass, fill with .s and -1s
    for my $pos (0 .. $#$in_pattern) {
	if ($in_pattern->[$pos] eq '.') {
	    $out_pattern->[$pos] = '.';
	    $parens_pattern->[$pos] = '.';
	} else {
	    $out_pattern->[$pos] = -1;    ### Placeholders
	    $positions_remaining++;       ### Counter of how many places need to be filled.
	}
    }    ### Finished filling the state with initial values.
    my $len = $#$in_pattern;
    $back_pos = $#$out_pattern;
    PkParse_Error($in_pattern, 'mismatch'), return (undef) unless ($len == $back_pos);
    
    while ($positions_remaining > 0) {    ### As long as there are unfilled values.
	$me->UnWind($in_pattern);             ### Every time you fill a position, decrement positions_remaining
    }
    $stemid = 0;
    $num_loops = 0;
    Clean_State();
    my $return = $out_pattern;
    $out_pattern = [];
    return ($return);
}

sub UnWind {
    my $me = shift;
    my $in_pattern = shift;                 ## The pknots output
    Clean_State();
    $num_loops++;
    PkParse_Error($in_pattern, 'loop'), $positions_remaining = 0 if ($num_loops > 100);
    return ($out_pattern) if ($positions_remaining == 0);
    if ($me->{debug}) {
	print "Start Unwind:
@{$in_pattern}
__________________________
@{$out_pattern}\n";
#	print <STDIN>;
    }
    while ($front_pos < $back_pos) {
	if ($me->{debug}) {
	    print "$current,$in_pattern->[$current],$out_pattern->[$current]\t";
	}
	if ($placement eq 'f') {
	    ### NOW AT THE 5' END
	    $placement = 'b';
	    
	    if ($in_pattern->[$current] eq '.') {
		if ($spaces > $me->{max_spaces}) {
		    ### The current position is a dot and one has surpassed the number of max_spaces
		    $next = $back_pos;    ## So move to the back
		    $front_pos++;         ## The next time we jump to front, jump to next
		    $spaces++;
		    $times_in_stem = 0;
		} elsif ($spaces <= $me->{max_spaces}) {
		## The current position is a dot and we have not passed max_spaces
		## this may be a bulge of an existing stem
		$next = $back_pos;    ## Jump to the back
		$front_pos++;
		$spaces++;
	    }
	}
	
	## This is a number AND the output has already been filled out for this position
	elsif ($out_pattern->[$current] > 0) {
	    $next = $back_pos;      ## Then jump to the back position
	    $front_pos++;           ## The next time we jump to front, jump to the next front
	    $spaces++;              ## Treat it as if it were a . in all instances
	    $times_in_stem = 0;
	}
	
	### For the first time we will fill out a piece of out_pattern
	elsif ($out_pattern->[$current] == -1) {
#	  print "\ttimes: $times_in_stem filled: $positions_filled\t";
	    if (($times_in_stem % 2) == 0) {
		if ($times_in_stem == 0) {
#		  print "Incrementing stemid 5' filled: $positions_filled\n";
		    $stemid++;
		    if ($positions_filled > 0) {
			return ($out_pattern);
		    }
		} elsif (abs($last - $in_pattern->[$current]) > $me->{max_spaces}) {
		    return ($out_pattern);
		}
		
		$positions_filled++;
		$next = $in_pattern->[$current];
		$times_in_stem++;
		$spaces = 0;
		$front_pos++;
		if ($me->{debug}) {
		    print "\t$current -> $stemid\t";
		}
		$out_pattern->[$current] = $stemid;    ## YAY FILLED IT!
		$positions_remaining--;
	    }    ## End elsif times_in_stem is even
	    
	    elsif (($times_in_stem % 2) == 1) {
		$positions_filled++;
		$next = $back_pos;
		$times_in_stem++;
		$spaces = 0;
		$front_pos = $current + 1;
		if ($me->{debug}) {
		    print "\t$current -> $stemid\t";
		}
		$out_pattern->[$current] = $stemid;    ## YAY FILLED IT!
		$positions_remaining--;
	    }
	}
	
	else {
	    Callstack(die => 1, message =>"WTF?");
	}
    }    ### Back to the if facing forward
    
    ### NOW ON THE 3' END
    elsif ($placement eq 'b') {
	$placement = 'f';
	
	if ($in_pattern->[$current] eq '.') {
	    if ($spaces > $me->{max_spaces}) {
		### The current position is a dot and one has surpassed the number of max_spaces
		$next = $front_pos;    ## So move to the front
		$back_pos--;           ## The next time we jump to front, jump to next
		$spaces++;
		$times_in_stem = 0;
	    } elsif ($spaces <= $me->{max_spaces}) {
		### The current position is a dot, but this may just be a bulge
		$next = $front_pos;    ## Jump to the back
		$back_pos--;
		$spaces++;
	    }
	}
	
	elsif ($out_pattern->[$current] > 0) {
	    ### Then this is an already filled position
	    $next = $front_pos;      ## Then jump to the back position
	    $back_pos--;             ## The next time we jump to front, jump to the next front
	    $spaces++;               ## Treat it as if it were a . in all instances
	    $times_in_stem = 0;
	}
	
	### For the first time we will fill out a piece of out_pattern
	elsif ($out_pattern->[$current] == -1) {
	    if (($times_in_stem % 2) == 0) {
		if ($times_in_stem == 0) {
#		print "Incrementing stemid, times_in_stem == 0 3'\n";
		    $stemid++;
		    if ($positions_filled > 0) {
			return ($out_pattern);
		    }
		} elsif (abs($last - $in_pattern->[$current]) > $me->{max_spaces}) {
		    if ($me->{debug}) {
			print "\tBHERE\t";
		    }
		    return ($out_pattern);
		}
		
		#          $stemid++ if ($times_in_stem == 0);
		#          $stemid++, $time_in_stem-- if (abs($last - $in_pattern->[$current]) > 4);
		$positions_filled++;
		$next = $in_pattern->[$current];
		$times_in_stem++;
		$spaces = 0;
		$back_pos--;
		if ($me->{debug}) {
		    print "\t$current -> $stemid\t3'";
		}
		$out_pattern->[$current] = $stemid;    ## YAY FILLED IT!
		$positions_remaining--;
	    }
	    
	    elsif (($times_in_stem % 2) == 1) {
		$positions_filled++;
		$next = $front_pos;
		$times_in_stem++;
		$spaces = 0;
		$back_pos = $current - 1;
		if ($me->{debug}) {
		    print "\t$current -> $stemid\t ODD times in stem";
		}
		$out_pattern->[$current] = $stemid;    ## YAY FILLED IT!
		$positions_remaining--;
	    }
	}
	
	else {
	    Callstack(die => 1, message => "WTF?");
	}
    }    ## End facing the back
    if ($me->{debug}) {
	print "$next,$in_pattern->[$next],$out_pattern->[$current]\n";
#	print <STDIN>;
    }
    $three_back = $two_back;
    $two_back   = $last;
    $last = $current;
    $current = $next;
}    ## End the while loop

return ($out_pattern);
}

sub Clean_State {
  $last = 0;
  $current = 0;
  $next = 0;
  $front_pos = 0;
  $back_pos = $#$out_pattern;
  $placement = 'f';
  $spaces = 1000;
  $last_pos = -1000;
  $positions_filled = 0;
  $times_in_stem = 0;
  $old = 0;
}

sub MyBrackets {
    my $pk_output = shift;
    my $barcode = shift;
    my @parens = @{$pk_output};

    my %stuff = ();
    for my $c (0 .. $#parens) {
	next if ($parens[$c] eq '.');
	next if ($parens[$c] eq ')');
	next if ($parens[$c] eq '(');
	if (!defined($stuff{$barcode->[$c]}{"fiveprime"})) {
	    my @fiveprime = ();
	    push(@fiveprime, $parens[$c]);
	    $stuff{$barcode->[$c]}{"fiveprime"} = \@fiveprime;
	}
	else {
	    my @fiveprime = @{$stuff{$barcode->[$c]}{"fiveprime"}};
	    push(@fiveprime, $parens[$c]);
	    $stuff{$barcode->[$c]}{"fiveprime"} = \@fiveprime;
	}
	
	if (!defined($stuff{$barcode->[$c]}{"threeprime"})) {
	    my @threeprime = ();
	    push(@threeprime, $parens[$parens[$c]]);
	    $stuff{$barcode->[$c]}{"threeprime"} = \@threeprime;
	}
	else {
	    my @threeprime = @{$stuff{$barcode->[$c]}{"threeprime"}};
	    push(@threeprime, $parens[$parens[$c]]);
	    $stuff{$barcode->[$c]}{"threeprime"} = \@threeprime;
	}
    }  ## End of each element in parens
#    print "Early TEST: @parens\n";
    
    my %stem_info = ();
    my $last_stem = 0;
    foreach my $stem (sort keys %stuff) {
	$last_stem = $stem if ($stem > $last_stem);
	my @temp = @{$stuff{$stem}{"threeprime"}};
	$stem_info{$stem}{"last_threeprime"} = $stuff{$stem}{"threeprime"}->[$#temp];
	$stem_info{$stem}{"first_threeprime"} = $stuff{$stem}{"threeprime"}->[0];
    }
    
  OUTER: foreach my $stem (sort keys %stem_info) {
    INNER: foreach my $second_stem (sort keys %stem_info) {
	next INNER if ($second_stem <= $stem);
	if ($stem_info{$stem}{"last_threeprime"} > $stem_info{$second_stem}{"first_threeprime"}) {
	    foreach my $position (@{$stuff{$second_stem}{"threeprime"}}) {
		$parens[$position] = '}';
	    }
	    foreach my $position (@{$stuff{$second_stem}{"fiveprime"}}) {
		$parens[$position] = '{';
	    }
	} else {
	    foreach my $position (@{$stuff{$second_stem}{"threeprime"}}) {
		$parens[$position] = ')';
	    }
	    foreach my $position (@{$stuff{$second_stem}{"fiveprime"}}) {
		$parens[$position] = '(';
	    }
	    
	}
    } ## END iNNER
      foreach my $position(@{$stuff{1}{"threeprime"}}) {
	  $parens[$position] = ')';
      }
      foreach my $position(@{$stuff{1}{"fiveprime"}}) {
	  $parens[$position] = '(';
      }
      
  } ## END OUTER
    return(\@parens);
}

sub MAKEBRACKETS {
    my ($strREF) = @_;
    my @helixLIST = ();
    push(@helixLIST, FINDHELIX($strREF));
    push(@helixLIST, FINDGAPS($strREF));
    my @brackets = ();
    while (my $helixREF = pop(@helixLIST)) {
    for (my $i = 0 ; $i < @$helixREF ; $i++) {
	unless ($$helixREF[$i] eq '-') {
	    $brackets[$i] = $$helixREF[$i];
	}
    }
    }
    return join("", @brackets);
}

sub FINDHELIX {
  my ($strREF) = @_;
  my $helixREF = "";
  my @helixLIST = ();
  my $last3 = 0;
  my $limit = @$strREF;

  for (my $i = 0; $i < @$strREF; $i++) {
      if (($$strREF[$i] =~ /\d+/) and ($i < $$strREF[$i])) {
	  SETDEFAULTBRACKETS();
	  if (($i < $last3) and ($limit < @$strREF)) {
	      SETALTERNATIVEBRACKETS();
	  }
	  ($i, $last3, $limit, $helixREF) = ZIPHELIX($strREF, $i, $limit);
	  # print @$helixREF,"\n";
	  push(@helixLIST, $helixREF);
      }
  }
  return @helixLIST;
}

sub FINDGAPS {
    my ($strREF) = @_;
    my @gaps = ();
    for (my $i = 0; $i < @$strREF; $i++) {
	if ($$strREF[$i] eq '.') {
	    $gaps[$i] = '.';
	} else {
	    #       next;
	    $gaps[$i] = '';
	}
    }
    return \@gaps;
}

sub ZIPHELIX {
  my ($strREF, $b5, $limit) = @_;
  my @helix = ();
  my $b3 = $$strREF[$b5];
  my $last5 = $b5;
  my $last3 = $b3;
  my $knot5 = "";
  my $knotted = 0;
  my $helixCrown = 0;
  my $nextLimit = @$strREF;

  for (my $i = 0; $i < $b5; $i++) {
      $helix[$i] = "-";
  }

  for (my $i = $b5; $i < $b3; $i++) {
    if (defined($helix[$i])) {
	if ($helix[$i] =~ /[\)\]]/) {
	    $helixCrown = 1;
	}
    }

    if (($$strREF[$i] =~ /\d+/) and ($i < $$strREF[$i]) and ($$strREF[$i] <= $b3)
	and ($i < $limit) and (not $knotted) and (not $helixCrown) and (not $helix[$i])) {
	$helix[$i] = $leftG;
	$helix[$$strREF[$i]] = $rightG;
	$last3 = $$strREF[$i];
	$last5 = $i;
    } elsif (($$strREF[$i] =~ /\d+/) and ($i < $$strREF[$i]) and ($$strREF[$i] > $b3) and (not $helix[$i])) {
	$helix[$i] = "-";
	$nextLimit = $i + 1;
	unless ($knotted) {
	    $knot5 = $i - 1;
	    $knotted = 1;
	}
    } elsif ($$strREF[$i] =~ /\./) {
	$helix[$i] = "-";
	$helix[$i] = "-";
    } elsif (not $helix[$i]) {
	$helix[$i] = "-";
    }
  }

  if ($knot5) {
      $last5 = $knot5;
  } else {
      $nextLimit = @$strREF;
  }
  return ($last5, $last3, $nextLimit, \@helix);
}

sub SETDEFAULTBRACKETS {
    $leftG = "(";
    $rightG = ")";
}

sub SETALTERNATIVEBRACKETS {
    $leftG = "{";
    $rightG = "}";
}

sub ReOrder_Stems {
  my $input = shift;
  my @arr = split( /\s+/, $input );
  my @return_array = @arr;
  my @tmp_array = @arr;
  my @shift_array = @arr;
  my $replace_char = 'a';
  while (my $char = shift(@shift_array)) {
      if ($char ne '.' and $char =~ /\d+/) {
	for my $t (0 .. $#shift_array) {
	  if ($shift_array[$t] eq $char) { $shift_array[$t] = '.'; }
      }
      
      for my $shift_num (0 .. $#tmp_array) {
	  if ( $tmp_array[$shift_num] ne '.' and $tmp_array[$shift_num] eq $char ) {
	    $tmp_array[$shift_num] = $replace_char;
	  }
      }
	$replace_char++;
      }
  }
  for my $c (0 .. $#tmp_array) {
      if ($tmp_array[$c] eq 'a') {
	  $return_array[$c] = '1';
      } elsif ($tmp_array[$c] eq 'b') {
	  $return_array[$c] = '2';
    } elsif ($tmp_array[$c] eq 'c') {
	$return_array[$c] = '3';
    } elsif ($tmp_array[$c] eq 'd') {
	$return_array[$c] = '4';
    } elsif ($tmp_array[$c] eq 'e') {
	$return_array[$c] = '5';
    } elsif ($tmp_array[$c] eq 'f') {
	$return_array[$c] = '6';
    } elsif ($tmp_array[$c] eq 'g') {
	$return_array[$c] = '7';
    } elsif ($tmp_array[$c] eq 'h') {
	$return_array[$c] = '8';
    } elsif ($tmp_array[$c] eq 'i') {
	$return_array[$c] = '9';
    } elsif ($tmp_array[$c] eq 'j') {
	$return_array[$c] = '10';
    } elsif ($tmp_array[$c] eq 'k') {
	$return_array[$c] = '11';
    } elsif ($tmp_array[$c] eq 'l') {
	$return_array[$c] = '12';
    } elsif ($tmp_array[$c] eq 'm') {
	$return_array[$c] = '13';
    } elsif ($tmp_array[$c] eq 'n') {
	$return_array[$c] = '14';
    } elsif ($tmp_array[$c] eq 'o') {
	$return_array[$c] = '15';
    } elsif ($tmp_array[$c] eq 'p') {
	$return_array[$c] = '16';
    } elsif ($tmp_array[$c] eq 'q') {
	$return_array[$c] = '17';
    } elsif ($tmp_array[$c] eq 'r') {
	$return_array[$c] = '18';
    } elsif ($tmp_array[$c] eq 's') {
	$return_array[$c] = '19';
    } elsif ($tmp_array[$c] eq 't') {
	$return_array[$c] = '20';
    } elsif ($tmp_array[$c] eq 'u') {
	$return_array[$c] = '21';
    } elsif ($tmp_array[$c] eq 'v') {
	$return_array[$c] = '22';
    } elsif ($tmp_array[$c] eq 'w') {
	$return_array[$c] = '23';
    } elsif ($tmp_array[$c] eq 'x') {
	$return_array[$c] = '24';
    } elsif ($tmp_array[$c] eq 'y') {
	$return_array[$c] = '25';
    } elsif ($tmp_array[$c] eq 'z') {
	$return_array[$c] = '26';
    }
  }    ## For each element of the tmp array.
  my $return = "@return_array";
  return ($return);
}

sub ReBarcoder {
  # Added by JLJ.
  my $strREF = shift;
  my $str = "";
  if (ref($strREF) eq "ARRAY") {
      $str = "@{$strREF}";
  } else {
      $str = $strREF;
  }

  my $x = "";
  my $max = 0;
  my $stems = "";
  my $order = "";

  while ($str =~ m/(\d)/g) {
      $x = $1;
      if ($x > $max) { $max = $x }
  }
  
  for (my $i = 1; $i <= $max; $i++) { $stems .= $i }

  while ($str =~ m/(\d)/g) {
      $x = $1;
      unless ($order =~ m/$x/) { $order .= $x; }
  }

  $_ = $str;
  eval "tr/$order/$stems/";    # or die $@;
  $str = $_;

  if (ref($strREF) eq "ARRAY") {
      my @duh = split(/ /, $str);
      return \@duh;
  } else {
      return $str;
  }
  Callstack(die => 1, messages => "WHAT THE HELLL!?!?!?!?!?!");
}

sub Condense {
  # Added JLJ.
    my $strREF = shift;
    my $str = "";
    if (ref($strREF) eq "ARRAY") {
	$str = "@{$strREF}";
    } else {
	$str = $strREF;
    }

    my $x = "";
    my $max = 0;
    while ($str =~ m/(\d)/g) {
	$x = $1;
	if ($x > $max) { $max = $x }
    }
    
    for (my $i = 1; $i <= $max; $i++ ) {
	$str =~ s/\s?($i)(?:\s[$i\.])*?\s?/$1/g;
	$str =~ s/\.|\s//g;
	$str =~ s/$i+/$i/g;
    }
    
    #print $str,"\n";
    
    my $count = 0;
    for (my $i = 1; $i <= $max; $i++) {
	$count++ while $str =~ m/$i/g;
	
	#print "$i $count\n";
	if ($count < 2) { $str =~ s/($i)/$1$1/; }
	$count = 0;
    }
    
    #print $str,"\n";
    
    return $str;
}

sub Knotp {
    my $me = shift;
    my $knotstring = shift;
    my @knot = split(//, $knotstring);
    my $knotref = \@knot;
    my $string = '';
    foreach my $c (@{$knotref}) { $string .= $c; }
    foreach my $char ('a' .. 'z') {
        $string =~ s/$char+/$char/g;
    }
    $string =~ s/\.//g;
    my @tmp = split(//, $string);
    my $orig_length;
  LOOP: while (scalar(@tmp) > 0) {
      $orig_length = scalar(@tmp);
      for my $pos (0 .. $#tmp) {
          next if (!defined($tmp[$pos + 1]));
          if ($tmp[$pos] eq $tmp[$pos + 1]) {
	      splice(@tmp, $pos, 2);
          }
      }
      my $fun = scalar(@tmp);
      if ($orig_length == scalar(@tmp)) {  ## If this is true there is a knot.
          my $return_string = '';
          foreach my $c (0 .. $#tmp) {
	      $return_string .= "$tmp[$c]";
          }
          return($return_string);
      }
  }
    return(0);
}

sub Parsed_to_Barcode {
  my $knotref = shift;
  my $string  = '';
  foreach my $char (@{$knotref} ) { $string = $string . $char if (defined($char)); }
  $string =~ tr/0-9//s;
  my @almost = split(//, $string);
  my $finished = '';
  if (Single_p($almost[0], \@almost)) {
      $finished = $almost[0] . $almost[0];
      shift(@almost);
  }
 LOOP: for my $c (0 .. $#almost) {
     my $char = $almost[$c];
     my $count = 0;
     ### If $char is in what is left of @almost 1 time...
     foreach my $test (@almost) {
      $count++ if ($test eq $char);
      if ($count > 1) {
#       print "Adding $char one time because it exists $count times\n";
        $finished = $finished . $char;
        $count = 0;
        next LOOP;
      }
    }
#    print "ADDING $char twice because it exists $count times\n";
    $finished = $finished . $char . $char;
  }
#  print "The reduced string is: $string\n";
  return ($finished);
}

sub Parsed_to_Barcode2 {
  my $knotref = shift;
  my $string  = '';
  foreach my $char (@{$knotref}) { $string = $string . $char if (defined($char)); }
  $string =~ tr/0-9//s;
#  print "TEST: $string\n";
  my @almost = split(//, $string);
  my $finished = '';
#  print "How many times does @almost have $almost[0]?\n";

  if (Single_p($almost[0], \@almost)) {
    $finished = $almost[0] . $almost[0];
    shift(@almost);
  }
LOOP: for my $c (0 .. $#almost) {
    my $char  = $almost[$c];
    my $count = 0;
    ### If $char is in what is left of @almost 1 time...
    foreach my $test (@almost) {
      $count++ if ($test eq $char);
      if ( $count > 1 ) {
#        print "Adding $char one time because it exists $count times\n";
        $finished = $finished . $char;
        $count    = 0;
        next LOOP;
      } elsif ( $count == 1 ) {
#        print "ADDING $char twice because it exists $count times\n";
        $finished = $finished . $char . $char;
        $count    = 0;
        next LOOP;
      }
    }
#    print "The reduced string is: $string\n";
    return ($finished);
  }
}

sub PkParse_Error {
  my $input = shift;
  my $string = shift;
  my $input_string = '';
  foreach my $c (@{$input}) { $input_string .= $c }
  open(ERROR, ">>pkparse_error.txt") or Callstack(die => 1, message => "Could not open the pkparse_error file.");
  ## OPEN ERROR in PkParse_Error
  if ($string eq 'loop') {
      print ERROR "Too many loops for $input_string\n";
  } elsif ($string eq 'mismatch') {
      print ERROR "There was a mismatch between the input and output sizes for $input_string\n";
  } else {
      print ERROR "There was an error for $input_string\n";
  }
  close(ERROR);
  ## CLOSE ERROR in PkParse_Error
}

1;

__END__

=head1 NAME

PkParse - A (hopefully) functional parser for the output from pknots.

=head1 SYNOPSIS

 use PkParse;
 my $parser = new PkParse();
 my $structure = $parser->Unzip(\@Pknots_structure);
 print "@{$structure}\n";

=head1 Unzip

 Unzip is the top level loop which handles some number of
 increasingly inner stem loops.   It completes only when there are no
 more unaccounted bound bases

=head1 UnWind

 UnWind does the real work, maintaining a small state machine and
 wandering the given structure from the outside in until the 'front
 pos' passes the 'back pos' which should occur either at the center
 of a sequence _or_ after completing an off center stem structure.

=head1 Handle_Front and Handle_Back

 These functions are essentially a long list of conditions which define when to increment the current stem id for a given position
 along the given sequence.  In each case the conditions between
 Handle_Front and Handle_Back are symmetric; so they could presumably
 be merged at a potential cost of clarity.
