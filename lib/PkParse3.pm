package PkParse3;

sub new {
  my ( $class, %args ) = @_;
  my $me = bless {
    debug         => 0,
    max_spaces    => defined( $args{max_spaces} ) ? $args{max_spaces} : 3,
    initial_state => {
      out_pattern         => [],
      stemid              => 0,
      positions_remaining => 0,
      st_length           => 0,        ## The length of the current stem
      last                => 0,        ## The last position visited
      current             => 0,        ## The current position visited
      next                => 0,        ## The next position to visit
      front_pos           => 0,        ## How far from the font?
      back_pos            => 0,        ## How far from the back?
      placement           => 'f',      ## Front or Back
      spaces              => 1000,     ## If this is greater than max_spaces then increment the stemid
      last_pos            => -1000,    ## ???
      positions_filled    => 0,        ## This should be a signal that it is time to restart
      times_in_stem       => 0,
      pseudoknot          => 0,
    },
  }, $class;
  if ( defined( $args{debug} ) ) { $me->{debug} = $args{debug} }
  return ($me);
}

my $state = { stemid => 0, };

sub Unzip {
  my $me             = shift;
  my $in_pattern     = shift;
  my $new_in_pattern = [];
  my $this_stemid    = $state->{stemid};
  foreach my $k ( keys %{ $me->{initial_state} } ) { $state->{$k} = $me->{initial_state}->{$k}; }
  $state->{stemid} = $this_stemid;
  ## First pass, fill with .s and -1s
  my $c = 0;
  for my $pos ( @{$in_pattern} ) {
    next if ( !defined($pos) );
    next if ( $pos =~ /\s+/ );

    #      next if ($pos =~ /\W|\.+/);
    if ( $pos eq '.' ) {
      $state->{out_pattern}->[$c] = '.';
      $new_in_pattern->[$c] = '.';
      $c++;
    } else {
      $state->{out_pattern}->[$c] = -1;
      $new_in_pattern->[$c] = $pos;
      $state->{positions_remaining}++;
      $c++;
    }
  }
  $in_pattern = $new_in_pattern;
  my @in_pat = @{$in_pattern};
  my @o_pat  = @{ $state->{out_pattern} };
  print "HERE: $state->{positions_remaining}
@in_pat
@o_pat\n";
  while ( $state->{positions_remaining} > 0 ) {    ### As long as there are unfilled values.
    $state->{front_pos} = 0;
    $state->{back_pos}  = $#$in_pattern;
    $me->UnWind($in_pattern);                      ### Every time you fill a position, decrement positions_remaining
  }
  my $return = $state->{out_pattern};
  foreach my $k ( keys %{ $me->{initial_state} } ) { $state->{$k} = $me->{initial_state}->{$k}; }
  return ($return);
}

sub UnWind {
  my $me         = shift;
  my $in_pattern = shift;
  print "BLAH @{$in_pattern}\n @{$state->{out_pattern}}\n\n";
  print <STDIN>;
  while ( $state->{front_pos} < $state->{back_pos} ) {
    last if ( $state->{positions_remaining} == 0 );
    print "$state->{current} $in_pattern->[$state->{current}] $state->{out_pattern}->[$state->{current}] $state->{placement}\t\t";
    if ( !defined( $in_pattern->[ $state->{current} ] ) ) {
      $in_pattern->[ $state->{current} ] = '.';
    }
    ### Imagine a 100 base structure, this will iterate f=0,b=99  f=1,b=98  f=2 b=97... until f=50,b=49
    if ( $state->{placement} eq 'f' ) {    ### At the 5' end
      $state->{placement} = 'b';

      if ( $in_pattern->[ $state->{current} ] eq '.' and $state->{spaces} > $me->{max_spaces} ) {
        $state->{next} = $state->{back_pos};    ## So move to the back
        $state->{front_pos}++;                  ## The next time we jump to front, jump to next
        $state->{spaces}++;
        $state->{times_in_stem} = 0;            ## TIMES IN STEM IS A KEY TO INCREMENT
      } elsif ( $in_pattern->[ $state->{current} ] eq '.' and $state->{spaces} <= $me->{max_spaces} ) {
        $state->{next} = $state->{back_pos};    ## Jump to the back
        $state->{front_pos}++;
        $state->{spaces}++;
      }

      elsif ( $in_pattern->[ $state->{current} ] ne '.' ) {
        if (  $state->{out_pattern}->[ $state->{current} ] > 0
          and $state->{positions_filled} > 0
          and $state->{times_in_stem} > 0 )
        {
          return ($me);
        } elsif ( $state->{out_pattern}->[ $state->{current} ] >= 0 ) {
          ## Then this is an already filled position
          $state->{next} = $state->{back_pos};    ## Then jump to the back position
          $state->{front_pos}++;                  ## The next time we jump to front, jump to the next front
          $state->{spaces}++;                     ## Treat it as if it were a . in all instances
          $state->{times_in_stem} = 0;
        }
        ## The current position must be -1
        elsif ( ( $state->{times_in_stem} % 2 ) == 0 ) {
          if ( abs( $state->{last} - $in_pattern->[ $state->{current} ] ) > 4 ) {
            ## If the stem is binding far away from what it is currently bound to
            $state->{stemid}++;
            $state->{times_in_stem}--;
          }
          Fill_Space();
          $state->{stemid}++ if ( $state->{times_in_stem} == 0 );
          $state->{next} = $in_pattern->[ $state->{current} ];
          $state->{front_pos}++;
          print "TESTMEF: $state->{next}\n";
          $state->{out_pattern}->[ $state->{current} ] = $state->{stemid};    ## YAY FILLED IT!
        } elsif ( ( $state->{times_in_stem} % 2 ) == 1 ) {
          Fill_Space();
          $state->{next}                               = $state->{back_pos};
          $state->{front_pos}                          = $state->{current} + 1;
          $state->{out_pattern}->[ $state->{current} ] = $state->{stemid};        ## YAY FILLED IT!
        }
      }    ### A position not equal to '.'
      else {
        print "HIT ELSE\n";
      }
    }    ### Back to the if facing forward
    elsif ( $state->{placement} eq 'b' ) {    ### At the 3' end
      $state->{placement} = 'f';
      if ( $in_pattern->[ $state->{current} ] eq '.' and $state->{spaces} > $me->{max_spaces} ) {
        $state->{next} = $state->{front_pos};    ## So move to the back
        $state->{back_pos}--;                    ## The next time we jump to front, jump to next
        $state->{spaces}++;
        $state->{times_in_stem} = 0;
      } elsif ( $in_pattern->[ $state->{current} ] eq '.'
        and $state->{spaces} <= $me->{max_spaces} )
      {
        $state->{next} = $state->{front_pos};    ## Jump to the back
        $state->{back_pos}--;
        $state->{spaces}++;
      } elsif ( $in_pattern->[ $state->{current} ] ne '.' ) {
        if (  $state->{out_pattern}->[ $state->{current} ] > 0
          and $state->{positions_filled} > 0
          and $state->{times_in_stem} > 0 )
        {
          return ($me);
        } elsif ( $state->{out_pattern}->[ $state->{current} ] >= 0 ) {
          ### Then this is an already filled position
          $state->{next} = $state->{front_pos};    ## Then jump to the back position
          $state->{back_pos}--;                    ## The next time we jump to front, jump to the next front
          $state->{spaces}++;                      ## Treat it as if it were a . in all instances
          $state->{times_in_stem} = 0;
        }
        ## The current position must be -1
        elsif ( ( $state->{times_in_stem} % 2 ) == 0 ) {
          if ( abs( $state->{last} - $in_pattern->[ $state->{current} ] ) > 4 ) {
            $state->{stemid}++;
            $state->{times_in_stem}--;
          }
          Fill_Space();
          $state->{stemid}++ if ( $state->{times_in_stem} == 0 );
          $state->{next} = $in_pattern->[ $state->{current} ];
          $state->{back_pos}--;
          $state->{out_pattern}->[ $state->{current} ] = $state->{stemid};    ## YAY FILLED IT!

          #		  print "TESTT: $state->{out_pattern}->[96] $state->{out_pattern}->[97] $state->{out_pattern}->[98]\n";
        } elsif ( ( $state->{times_in_stem} % 2 ) == 1 ) {
          Fill_Space();
          $state->{next}                               = $state->{front_pos};
          $state->{back_pos}                           = $state->{current} - 1;
          $state->{out_pattern}->[ $state->{current} ] = $state->{stemid};        ## YAY FILLED IT!
        } else {
          print "HIT ELSE\n";
        }
      }    ### End of the non '.' positions of the in pattern
    }    ## End if facing the back
    print "$state->{current} $in_pattern->[$state->{current}] $state->{out_pattern}->[$state->{current}] $state->{placement}\t\t";
    $state->{old}     = $state->{last};
    $state->{last}    = $state->{current};
    $state->{current} = $state->{next};
    print "$state->{last} $state->{out_pattern}->[$state->{last}] $state->{current} $state->{positions_remaining}\n";
    print <STDIN>;
    return ( $state->{out_pattern} ) if ( $state->{positions_remaining} == 0 );
  }    ## End the while loop
  if (  $state->{out_pattern}->[ $state->{current} ] =~ /\d/
    and $state->{out_pattern}->[ $state->{current} ] > -1 )
  {
    $state->{out_pattern}->[ $state->{last} ] = -1;
    $state->{out_pattern}->[ $state->{old} ]  = -1;
    $state->{stemid}--;
  }
  return ($me);
}

sub Fill_Space {
  $state->{positions_filled}++;
  $state->{times_in_stem}++;
  $state->{spaces} = 0;
  $state->{positions_remaining}--;
}

1;
