package PkParse;

sub new {
  my ($class, %args) = @_;
  my $me = bless {
				  recursion_count => 0,
				  out_pattern => [],
				  stemid => 0,
				  debug => 0,
				  max_spaces => 3,
				  pseudoknot => 0,
				 }, $class;
  if (defined($args{debug})) { $me->{debug} = $args{debug} };
  return($me);
}

sub Unzip {
  my $me = shift;
  my $pattern = shift;
  for my $pos (0 .. $#$pattern) {
	if ($pattern->[$pos] eq '.') {
	  $me->{out_pattern}->[$pos] = '.';
	}
	else {
	  $me->{out_pattern}->[$pos] = -1;
	  $me->{positions_remaining}++;
	}
  }

  while ($me->{positions_remaining} > 0) {
	if ($me->{debug}) {
	  print "STARTING THE WIND LOOP with:
@{$me->{out_pattern}}!\n\n";
	}
	$me->UnWind($pattern);
	$me->{positions_remaining} = $me->Missing_p();
  }

  $me->{recursion_count} = 0;
  $me->{stemid} = 0;
  my $return = $me->{out_pattern};
  $me->{out_pattern} = [];
  return($return);
}

sub Missing_p {
  my $me = shift;
  foreach my $pos (@{$me->{out_pattern}}) {
	return(1) if ($pos eq '-1');
  }
return(0);
}

sub UnWind {
  my $me = shift;
  my $pattern = shift;
  my $state = {st_length => 0,
			   last => 0,
			   current => 0,
			   next => 0,
			   front_pos => 0,
			   back_pos => $#$pattern,
			   placement => 'front',
			   spaces => 1000,
			   last_pos => -1000,
			   times_in_layer => 0,
			   };
#  WIND: while ($me->Finished_Stem_p(\%state) == 0) {
 WIND: while ($me->Finished_Test_p($state) == 0) {
	my $last = $state->{last};
	my $current = $state->{current};
	my $next = $state->{next};
	my $pat = $pattern->[$next];
	my $out = $me->{out_pattern}->[$current];
	if ($me->{debug}) {
	  print "PRE-if: last:$last current:$current next:$next pattern:$pat placement:$state->{placement} out:$out lay:$state->{times_in_layer} spaces:$state->{spaces}\n";
	}
	if ($state->{placement} eq 'front') {
	  $state = $me->Handle_Front($state, $pattern);
	}
	elsif ($state->{placement} eq 'back') {
	  $state = $me->Handle_Back($state, $pattern);
	}

	if ($state eq 'pseudo') {
	  $me->{pseudoknot}++;
	  last WIND;
	}

	if ($me->{debug}) {
	  print "POST-if: true:$state->{true} last: $last cur:$current next:$state->{next} pat:$pat placemnt:$state->{placement} out:$me->{out_pattern}->[$state->{last}] layer:$state->{times_in_layer} spaces:$state->{spaces} fp:$state->{front_pos} bp:$state->{back_pos}\n\n";
	  print <STDIN>;
	}
  }  ## End while
}

sub Handle_Front {
  my $me = shift;
  my $state = shift;
  my $pattern = shift;
  my $last = $state->{last};
  my $current = $state->{current};
  my $next = $state->{next};

  my $pat = $pattern->[$current];
  $state->{placement} = 'back';

  ## Already examined
  if ($pat =~ /\d/  and $me->{out_pattern}->[$current] != -1) {
	$state->{true} = 'bf';
	$state->{next} = $state->{back_pos};
	$state->{front_pos}++;
	$state->{spaces}++;
	$state->{times_in_layer} = 0;	
  }
  elsif ($pat eq '.' and $state->{spaces} > $me->{max_spaces}) {
	$state->{true} = '1f';
	$state->{next} = $state->{back_pos};
	$state->{front_pos}++;
	$state->{spaces}++;
	$state->{times_in_layer} = 0;
  }
  elsif ($pat eq '.' and $state->{spaces} <= $me->{max_spaces}) {
	$state->{true} = 'af';
	$state->{next} = $state->{back_pos};
	$state->{front_pos}++;
	$state->{spaces}++;
  }
  elsif ($pat =~ /\d/ and $state->{times_in_layer} == 0) {
	$state->{true} = '2f';
	$me->{stemid}++;
	$me->{out_pattern}->[$current] = $me->{stemid};
	$state->{next} = $pat;
	$state->{times_in_layer}++;
	$state->{spaces} = 0;
	$state->{front_pos}++;
  }
  elsif ($pat =~ /\d/ and $state->{times_in_layer} == 1) {
	$state->{true} = '3f';
	$me->{out_pattern}->[$current] = $me->{stemid};
	$state->{next} = $state->{back_pos};
	$state->{times_in_layer}++;
	$state->{spaces} = 0;
	$state->{front_pos} = $current + 1;
  }
  elsif ($pat =~ /\d/ and $state->{times_in_layer} == 2) {
	$state->{true} = '4f';
	$me->{out_pattern}->[$current] = $me->{stemid};
	$state->{next} = $pat;
	$state->{times_in_layer}++;
	$state->{spaces} = 0;
	$state->{front_pos}++;
  }
  elsif ($pat =~ /\d/ and $state->{times_in_layer} == 3) {
	$state->{true} = '5f';
	$state->{times_in_layer}++;
	$me->{out_pattern}->[$current] = $me->{stemid};
	$state->{next} = $state->{back_pos};
	$state->{spaces} = 0;
	$state->{front_pos} = $state->{current} + 1;
  }
  elsif ($pat =~ /\d/ and $state->{times_in_layer} == 4) {
	$state->{true} = '6f';
##	last WIND if ($pat < $state->{current});  ## TEST FOR PSEUDOKNOTS
	if ($pat < $state->{current}) {
	  return('pseudo');
	}
	## Test switching from one loop to another
	if (abs($last - $pat) > 4) {
	  $me->{stemid}++;
	}
	$me->{out_pattern}->[$current] = $me->{stemid};
	$state->{next} = $pat;
	$state->{times_in_layer}--;
	$state->{spaces} = 0;
	$state->{front_pos}++;
  }
  else {
	$state->{true} = '0f';
  }
  $state->{last} = $state->{current};
  $state->{current} = $state->{next};
  return($state);
}

sub Handle_Back {
  my $me = shift;
  my $state = shift;
  my $pattern = shift;
  my $last = $state->{last};
  my $current = $state->{current};
  my $next = $state->{next};

  my $pat = $pattern->[$current];
  $state->{placement} = 'front';

  ## Already examined
  if ($pat =~ /\d/  and $me->{out_pattern}->[$current] ne '-1') {
	$state->{true} = 'bb';
	$state->{next} = $state->{front_pos};
	$state->{back_pos}--;
	$state->{spaces}++;
	$state->{times_in_layer} = 0;	
  }
  elsif ($pat eq '.' and $state->{spaces} > $me->{max_spaces}) {
	$state->{true} = '1b';
	$state->{next} = $state->{front_pos};
	$state->{back_pos}--;
	$state->{spaces}++;
	$state->{times_in_layer} = 0;
  }
  elsif ($pat eq '.' and $state->{spaces} <= $me->{max_spaces}) {
	$state->{true} = 'ab';
	$state->{next} = $state->{front_pos};
	$state->{back_pos}--;
	$state->{spaces}++;
  }
  elsif ($pat =~ /\d/ and $state->{times_in_layer} == 0) {
	$state->{true} = '2b';
	$me->{stemid}++;
	$me->{out_pattern}->[$current] = $me->{stemid};
	$state->{next} = $pat;
	$state->{times_in_layer}++;
	$state->{spaces} = 0;
	$state->{back_pos}--;
  }
  elsif ($pat =~ /\d/ and $state->{times_in_layer} == 1) {
	$state->{true} = '3b';
	$me->{out_pattern}->[$current] = $me->{stemid};
	$state->{next} = $state->{front_pos};
	$state->{times_in_layer}++;
	$state->{spaces} = 0;
	$state->{back_pos} = $current - 1;
  }
  elsif ($pat =~ /\d/ and $state->{times_in_layer} == 2) {
	$state->{true} = '4b';
	$me->{out_pattern}->[$current] = $me->{stemid};
	$state->{next} = $pat;
	$state->{times_in_layer}++;
	$state->{spaces} = 0;
	$state->{back_pos}--;
  }
  elsif ($pat =~ /\d/ and $state->{times_in_layer} == 3) {
	$state->{true} = '5b';
	$state->{times_in_layer}++;
	$me->{out_pattern}->[$current] = $me->{stemid};
	$state->{next} = $state->{front_pos};
	$state->{spaces} = 0;
	$state->{back_pos} = $state->{current} - 1;
  }
  elsif ($pat =~ /\d/ and $state->{times_in_layer} == 4) {
	$state->{true} = '6b';
#	last WIND if ($pat > $state->{current});  ## TEST FOR PSEUDOKNOTS
	if ($pat > $state->{current}) {
	  return('pseudo');
	}
	if (abs($last - $pat) > 4) {
	  $me->{stemid}++;
	}
	$me->{out_pattern}->[$current] = $me->{stemid};
	$state->{next} = $pat;
	$state->{times_in_layer}--;
	$state->{spaces} = 0;
	$state->{back_pos}--;
  }
  else {
	$state->{true} = '0b';
  }
  $state->{last} = $state->{current};
  $state->{current} = $state->{next};
  return($state);
}

sub Finished_Test_p {
  my $me = shift;
  my $state = shift;
  if ($state->{front_pos} > $state->{back_pos}) {
	return(1);
  }
  else {
	return(0);
  }
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

 These functions are essentially a long list of conditions which
 define when to increment the current stem id for a given position
 along the given sequence.  In each case the conditions between
 Handle_Front and Handle_Back are symmetric; so they could presumably
 be merged at a potential cost of clarity.
