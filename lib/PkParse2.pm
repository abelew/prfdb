package PkParse2;

sub new {
  my ($class, %args) = @_;
  my $me = bless {
                  out_pattern => [],
                  stemid => 0,
                  debug => 0,
                  max_spaces => defined($args{max_spaces}) ? $args{max_spaces} : 6,
                  pseudoknot => 0,
                  positions_remaining => 0,
                 }, $class;
  if (defined($args{debug})) { $me->{debug} = $args{debug} };
  return($me);
}

sub Unzip {
  my $me = shift;
  my $in_pattern = shift;
  my @out_pattern = ();
  ## First pass, fill with .s and -1s
  for my $pos (0 .. $#$in_pattern) {
    if ($in_pattern->[$pos] eq '.') {
      $out_pattern[$pos] = '.';
    }
    else {
      $out_pattern[$pos] = -1; ### Placeholders
      $me->{positions_remaining}++;    ### Counter of how many places need to be filled.
    }
  }  ### Finished filling the state with initial values.
#  print "HERE: $me->{positions_remaining}\n";
  while ($me->{positions_remaining} > 0) {  ### As long as there are unfilled values.
    $me->UnWind($in_pattern, \@out_pattern);  ### Every time you fill a position, decrement positions_remaining
  }
  return(\@out_pattern);
}

sub UnWind {
  my $me = shift;
  my $in_pattern = shift; ## The pknots output
  my $out_pattern = shift;
  return($out_pattern) if ($me->{positions_remaining} == 0);
#  print "BLAH @{$in_pattern}\n @{$out_pattern}\n\n";
#  print <STDIN>;
  my $state = {
               st_length => 0, ## The length of the current stem
               last => 0, ## The last position visited
               current => 0, ## The current position visited
               next => 0,  ## The next position to visit
               front_pos => 0, ## How far from the font?
               back_pos => $#$in_pattern, ## How far from the back?
               placement => 'f', ## Front or Back
               spaces => 1000,  ## If this is greater than max_spaces then increment the stemid
               last_pos => -1000, ## ???
               positions_filled => 0, ## This should be a signal that it is time to restart
               times_in_stem => 0,
               };
  my $current;
  while ($state->{front_pos} < $state->{back_pos}) {
    $current = $state->{current};
#    print "$current $in_pattern->[$current] $out_pattern->[$current] $state->{placement}\n";
    if (!defined($in_pattern->[$current])) {
      $in_pattern->[$current] = '.'; }
    ### Imagine a 100 base structure, this will iterate f=0,b=99  f=1,b=98  f=2 b=97... until f=50,b=49
    if ($state->{placement} eq 'f') { ### At the 5' end
      $state->{placement} = 'b';

      if ($in_pattern->[$current] eq '.' and $state->{spaces} > $me->{max_spaces}) {
        ### The current position is a dot and one has surpassed the number of max_spaces
        ## Remember -- we are in the front
        $state->{next} = $state->{back_pos};  ## So move to the back
        $state->{front_pos}++;  ## The next time we jump to front, jump to next
        $state->{spaces}++;
        $state->{times_in_stem} = 0;
      }
      elsif ($in_pattern->[$current] eq '.' and $state->{spaces} <= $me->{max_spaces}) {
        $state->{next} = $state->{back_pos}; ## Jump to the back
        $state->{front_pos}++;
        $state->{spaces}++;
      }

      elsif ($in_pattern->[$current] ne '.' and $out_pattern->[$current] ne '.') {
        my $out_num = int($out_pattern->[$current]);
        my $in_num = int($in_pattern->[$current]);
        my $positions_filled = int($state->{positions_filled});
        my $times_in_stem = int($state->{times_in_stem});
#        if ($out_num > 0 and $state->{positions_filled} > 0 and $state->{times_in_stem} == 0) {
        if ($out_num > 0 and $positions_filled > 0 and $times_in_stem > 0) {
#        print "F In is num, positions filled == 0 times in stem == 0 -- returning state\n";
          ### If we hit an already used number and have already been in a stem
          return($state);
        }
        elsif ($out_num > 0) {  ## Then this is an already filled position
          ### If the current position is already filled out
          $state->{next} = $state->{back_pos}; ## Then jump to the back position
          $state->{front_pos}++; ## The next time we jump to front, jump to the next front
          $state->{spaces}++;    ## Treat it as if it were a . in all instances
          $state->{times_in_stem} = 0;
        }
        ### For the first time we will fill out a piece of out_pattern
        elsif ($times_in_stem == 0) {
          $me->{stemid}++;
          $state->{positions_filled}++;
          $state->{next} = $in_pattern->[$current];
          $state->{times_in_stem}++;
          $state->{spaces} = 0;
          $state->{front_pos}++;
          $out_pattern->[$current] = $me->{stemid}; ## YAY FILLED IT!
          $me->{positions_remaining}--;
        }
        elsif ($times_in_stem == 1) {
          $state->{positions_filled}++;
          $state->{next} = $state->{back_pos};
          $state->{times_in_stem}++;
          $state->{spaces} = 0;
          $state->{front_pos} = $current + 1;
          $out_pattern->[$current] = $me->{stemid}; ## YAY FILLED IT!
          $me->{positions_remaining}--;
        }
        elsif ($times_in_stem == 2) {
          $state->{positions_filled}++;
          $state->{next} = $in_pattern->[$current];
          $state->{times_in_stem}++;
          $state->{spaces} = 0;
          $state->{front_pos}++;
          $out_pattern->[$current] = $me->{stemid}; ## YAY
          $me->{positions_remaining}--;
        }
        elsif ($times_in_stem == 3) {
          $state->{positions_filled}++;
          $state->{next} = $state->{back_pos};
          $state->{times_in_stem}++;
          $state->{spaces} = 0;
          $state->{front_pos} = $current + 1; ## Different from PkParse
          $out_pattern->[$current] = $me->{stemid};
          $me->{positions_remaining}--;
        }
        elsif ($times_in_stem == 4) {
#          if ($in_pattern->[$current] < $state->{current}) { return('pseudo'); }
          if (abs($state->{last} - $in_pattern->[$current]) > 4) {
            $me->{stemid}++;
          }
          $state->{positions_filled}++;
          $state->{next} = $in_pattern->[$current];
          $state->{times_in_stem}--;
          $state->{spaces} = 0;
          $state->{front_pos}++;
          $out_pattern->[$current] = $me->{stemid};
          $me->{positions_remaining}--;
        }
      } ### A position not equal to '.'
      else {
        print "HIT ELSE\n";
      }
    } ### Back to the if facing forward
    elsif ($state->{placement} eq 'b') { ### At the 3' end
      $state->{placement} = 'f';
#      if ($pattern->[$current] =~ /\d/ and $me->{out_pattern}->[$current] != -1) {

      if ($in_pattern->[$current] eq '.' and $state->{spaces} > $me->{max_spaces}) {
        ### The current position is a dot and one has surpassed the number of max_spaces
        ## Remember -- we are in the back
        $state->{next} = $state->{front_pos};  ## So move to the back
        $state->{back_pos}--;  ## The next time we jump to front, jump to next
        $state->{spaces}++;
        $state->{times_in_stem} = 0;
      }
      elsif ($in_pattern->[$current] eq '.' and $state->{spaces} <= $me->{max_spaces}) {
        $state->{next} = $state->{front_pos}; ## Jump to the back
        $state->{back_pos}--;
        $state->{spaces}++;
      }

      elsif ($in_pattern->[$current] ne '.' and $out_pattern->[$current] ne '.') {
        my $out_num = int($out_pattern->[$current]);
        my $in_num = int($in_pattern->[$current]);
        my $positions_filled = int($state->{positions_filled});
        my $times_in_stem = int($state->{times_in_stem});
#        print "TESTME: $out_num $in_num $positions_filled $times_in_stem\n";
#        if ($out_num > 0 and $state->{positions_filled} > 0 and $state->{times_in_stem} == 0) {
        if ($out_num > 0 and $positions_filled > 0 and $times_in_stem > 0) {
#        print "B In is num, positions filled == 0 times in stem == 0 -- returning state\n";
          ## For when we hit a new stem after completing one -- drop out and restart the loop
          return($state);
        }
        elsif ($out_num > 0) { ### Then this is an already filled position
          ### If the current position is already filled out
          $state->{next} = $state->{front_pos}; ## Then jump to the back position
          $state->{back_pos}--; ## The next time we jump to front, jump to the next front
          $state->{spaces}++;    ## Treat it as if it were a . in all instances
          $state->{times_in_stem} = 0;
        }
        ### For the first time we will fill out a piece of out_pattern
        elsif ($times_in_stem == 0) {
          $me->{stemid}++;
          $state->{positions_filled}++;
          $state->{next} = $in_pattern->[$current];
          $state->{times_in_stem}++;
          $state->{spaces} = 0;
          $state->{back_pos}--;
          $out_pattern->[$current] = $me->{stemid}; ## YAY FILLED IT!
          $me->{positions_remaining}--;
        }
        elsif ($times_in_stem == 1) {
          $state->{positions_filled}++;
          $state->{next} = $state->{front_pos};
          $state->{times_in_stem}++;
          $state->{spaces} = 0;
          $state->{back_pos} = $current - 1;
          $out_pattern->[$current] = $me->{stemid}; ## YAY FILLED IT!
          $me->{positions_remaining}--;
        }
        elsif ($times_in_stem == 2) {
          $state->{positions_filled}++;
          $state->{next} = $in_pattern->[$current];
          $state->{times_in_stem}++;
          $state->{spaces} = 0;
          $state->{back_pos}--;
          $out_pattern->[$current] = $me->{stemid}; ## YAY
          $me->{positions_remaining}--;
        }
        elsif ($times_in_stem == 3) {
          $state->{positions_filled}++;
          $state->{next} = $state->{front_pos};
          $state->{times_in_stem}++;
          $state->{spaces} = 0;
          $state->{back_pos} = $current - 1; ## Different from PkParse
          $out_pattern->[$current] = $me->{stemid};
          $me->{positions_remaining}--;
        }
        elsif ($times_in_stem == 4) {
#          print "HERE!\n";
          if (abs($state->{last} - $in_pattern->[$current]) > 4) { $me->{stemid}++; }
          $state->{positions_filled}++;
          $state->{next} = $in_pattern->[$current];
          $state->{times_in_stem}--;
          $state->{spaces} = 0;
          $state->{back_pos}--;
          $out_pattern->[$current] = $me->{stemid};
          $me->{positions_remaining}--;
#          if ($in_pattern->[$current] < $state->{current}) { return('pseudo'); }
        }
        else {
          print "HIT ELSE\n";
        }
      } ### End of the non '.' positions of the in pattern
    } ## End if facing the back
    $state->{old} = $state->{last};
    $state->{last} = $state->{current};
    $state->{current} = $state->{next};
  }   ## End the while loop
  if ($out_pattern->[$current] =~ /\d/ and $out_pattern > -1) {
    $out_pattern->[$state->{last}] = -1;
#    $out_pattern->[$state->{current}] = -1;
#    $out_pattern->[$state->{next}] = -1;
    $out_pattern->[$state->{old}] = -1;
    $me->{stemid}--;
  }
  return($state);
}

1;
