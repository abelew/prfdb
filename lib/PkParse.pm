package PkParse;

sub new {
  my ($class, %args) = @_;
  my $me = bless {
                  recursion_count => 0,
                  out_pattern => [],
                  stemid => 0,
                  debug => 0,
                  max_spaces => defined($args{max_spaces}) ? $args{max_spaces} : 3,
                  pseudoknot => 0,
                  positions_remaining => 0,
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
  my $state = {
      ##  st_length is not currently used, intended to keep the length of each stem
      st_length => 0,
      ##  last is set to current at the end of each loop
      last => 0,
      ##  current is the current position in the putative structure
      current => 0,
      ##  next is set to either: 1 base 5' if you are currently in a 3' loop
      ##  1 base 3' if in a 5' loop, or the same
      next => 0,
      ##  The number of bases from the first 5' base
      front_pos => 0,
      ##  The number of bases from the end
      back_pos => $#$pattern,
      ##  front switches to back after each iteration
      placement => 'front',
      ##  spaces is compared to max_spaces to see if the current stem
      ##  should be incremented.  Thus on the first stem it will increment to 1
      spaces => 1000,
      ##  last_pos similarly should start in crazy land so it gets popped
      ##  to the last position in the structure
      last_pos => -1000,
      ##  when this gets to 4 we can check for a pseudoknot 1212
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

sub MAKEBRACKETS {
    my($strREF) = @_;
    my @helixLIST = ();
    push(@helixLIST, FINDHELIX($strREF) );
    push(@helixLIST, FINDGAPS($strREF) );
    my @brackets = ();
    while( my $helixREF = pop(@helixLIST) ){
	for(my $i=0; $i < @$helixREF; $i++){
	    unless($$helixREF[$i] eq '-'){
		$brackets[$i] = $$helixREF[$i];
	    }
	}
    }
    return join("",@brackets);
}

sub FINDHELIX {
    my( $strREF ) = @_;
    my $helixREF = "";
    my @helixLIST = ();
    my $last3 = 0;
    my $limit = @$strREF;

    for(my $i = 0; $i < @$strREF; $i++ ){
	if(( $$strREF[$i] =~ /\d+/) and
	   ( $i < $$strREF[$i] )) {
	    SETDEFAULTBRACKETS();
	    if(($i < $last3 ) and
	       ($limit < @$strREF)) {
		SETALTERNATIVEBRACKETS();
	    }
	    ( $i, $last3, $limit, $helixREF) = ZIPHELIX( $strREF, $i, $limit );
	    # print @$helixREF,"\n";
	    push( @helixLIST, $helixREF );
	}
    }
    return @helixLIST;
}

sub FINDGAPS{
  my($strREF) = @_;
  my @gaps = ();
  for(my $i = 0; $i < @$strREF; $i++){
    if($$strREF[$i] eq '.'){
      $gaps[$i] = '.';
    } else {
#       next;
       $gaps[$i] = '';
    }
  }
  return \@gaps;
}

sub ZIPHELIX{
    my( $strREF, $b5, $limit ) = @_;
    my @helix = ();

    my $b3 = $$strREF[ $b5 ];
    my $last5 = $b5;
    my $last3 = $b3;
    my $knot5 = "";
    my $knotted = 0;
    my $helixCrown = 0;
    my $nextLimit = @$strREF;

    for(my $i = 0; $i < $b5; $i++){
	$helix[$i] = "-";
    }

    for(my $i = $b5; $i < $b3; $i++ ){
	if( defined($helix[$i]) ){
	    if( $helix[$i] =~ /[\)\]]/ ){
		$helixCrown = 1;
	    }
	}

	if(( $$strREF[$i] =~ /\d+/ ) and
	   ( $i < $$strREF[$i] ) and
	   ( $$strREF[$i] <= $b3 ) and
	   ( $i < $limit ) and
	   ( not $knotted ) and
	   ( not $helixCrown ) and
	   ( not $helix[$i] )) {
	    $helix[$i] = $leftG;
	    $helix[ $$strREF[$i] ] = $rightG;
	    $last3 = $$strREF[$i];
	    $last5 = $i;
	}
	elsif (( $$strREF[$i] =~ /\d+/ ) and
	       ( $i < $$strREF[$i] ) and
	       ( $$strREF[$i] > $b3 ) and
	       ( not $helix[$i] )) {
	    $helix[$i] = "-";
	    $nextLimit = $i+1;
	    unless( $knotted ) {
		$knot5 = $i-1;
		$knotted = 1;
	    }
	} elsif( $$strREF[$i] =~ /\./  ) {
	    $helix[$i] = "-";
	    $helix[$i] = "-";
	} elsif( not $helix[$i] ) {
	    $helix[$i] = "-";
	}
    }

    if( $knot5 ){
	$last5 = $knot5;
    }else{
	$nextLimit = @$strREF;
    }
    return ($last5, $last3, $nextLimit, \@helix);
}

sub SETDEFAULTBRACKETS{
    $leftG = "(";
    $rightG = ")";
}

sub SETALTERNATIVEBRACKETS{
    $leftG = "{";
    $rightG = "}";
}

sub ReBarcoder{
    # Added by JLJ.
    my $strREF = shift;
    my $str = "";
    if (ref($strREF) eq "ARRAY") {
        $str = "@{$strREF}";
    } 
    else {
        $str = $strREF;
    }
    
    my $x = "";
    my $max = 0;
    my $stems = "";
    my $order = "";
    
    while ($str =~ m/(\d)/g) {
        $x = $1;
        if($x > $max) { $max = $x }
    }
    
    for(my $i=1; $i <= $max; $i++) { $stems .= $i }
    
    while ($str =~ m/(\d)/g) {
        $x = $1;
        unless($order =~ m/$x/) { $order .= $x; }
    }
    
    $_ = $str;
    eval "tr/$order/$stems/"; # or die $@;
    $str = $_;
        
    if(ref($strREF) eq "ARRAY") {
        my @duh = split(/ /,$str);
        return \@duh;
    } else {
        return $str;
    }
    die "WHAT THE HELLL!?!?!?!?!?!\n";
}

sub Condense{
    # Added JLJ.
    my $strREF = shift;
    my $str = "";
    if( ref($strREF) eq "ARRAY" ){
        $str = "@{$strREF}";
    }else{
        $str = $strREF;
    }
    
    my $x = "";
    my $max = 0;    
    while($str =~ m/(\d)/g){
        $x = $1;
        if( $x > $max ){ $max = $x }
    }
    
    for(my $i = 1; $i <= $max; $i++){
        $str =~ s/\s?($i)(?:\s[$i\.])*?\s?/$1/g;
        $str =~ s/\.|\s//g;
        $str =~ s/$i+/$i/g;
    }
    #print $str,"\n";
    
    my $count = 0;
    for(my $i = 1; $i <= $max; $i++){
       $count++ while $str =~ m/$i/g;
       #print "$i $count\n";
       if($count < 2){ $str =~ s/($i)/$1$1/; }
       $count = 0;
    }
    #print $str,"\n";
 
    
    return $str;  
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
