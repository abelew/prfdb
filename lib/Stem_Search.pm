package Stem_Search;
use strict;

my @slippery_sites = (
  'A AAA AAA',
  'A AAA AAC',

  #					  'A AAA AAG',
  'A AAA AAT',

  #					  'A AAC CCA', 'A AAC CCC', 'A AAC CCG', 'A AAC CCT', 'A AAG GGA', 'A AAG GGC', 'A AAG GGG', 'A AAG GGT',
  'A AAT TTA',
  'A AAT TTC',

  #					  'A AAT TTG',
  'A AAT TTT',
  'C CCA AAA',
  'C CCA AAC',

  #					  'C CCA AAG',
  'C CCA AAT',

  #					  'C CCC CCA', 'C CCC CCC', 'C CCC CCG', 'C CCC CCT', 'C CCG GGA', 'CCC GGG C', 'C CCG GGG', 'C CCG GGT',
  'C CCT TTA',
  'C CCT TTC',

  #					  'C CCT TTG',
  'C CCT TTT',
  'G GGA AAA',
  'G GGA AAC',
  'G GGA AAG',
  'G GGA AAT',

  #					  'G GGC CCA', 'G GGC CCC', 'G GGC CCG', 'G GGC CCT', 'G GGG GGA', 'G GGG GGC', 'G GGG GGG', 'G GGG GGT',
  'G GGT TTA',
  'G GGT TTC',

  #					  'G GGT TTG',
  'G GGT TTT',
  'T TTA AAA',
  'T TTA AAC',

  #					  'T TTA AAG',
  'T TTA AAT',

  #					  'T TTC CCA', 'T TTC CCC', 'T TTC CCG', 'T TTC CCT', 'T TTG GGA', 'T TTG GGC', 'T TTG GGG', 'T TTG GGT',
  'T TTT TTA',
  'T TTT TTC',

  #					  'T TTT TTG',
  'T TTT TTT',
);

sub new {
  my ( $class, %arg ) = @_;
  my $me = bless {}, $class;
  $me->{max_stem_length}    = 150;
  $me->{stem_length}        = 6;
  $me->{max_dist_from_slip} = 15;
  return ($me);
}

## Search: Given a cDNA sequence, put all slippery sites into @slipsites
## Put all of those which are followed by a stem into @slipsite_stems
sub Search {
  my $me       = shift;
  my $sequence = shift;
  my $length   = shift;
  $sequence =~ s/A+$//g;
  my @information    = split( //, $sequence );
  my $end_trim       = 30;
  my @slipsites      = ();
  my @slipsite_stems = ();

  for my $c ( 0 .. ( $#information - $end_trim ) ) {    ## Don't bother with the last $end_trim nucleotides
    if ( ( ( $c + 1 ) % 3 ) == 0 ) {
      my $next_seven = "$information[$c] " . $information[ $c + 1 ] . $information[ $c + 2 ] . "$information[$c + 3] " . $information[ $c + 4 ] . $information[ $c + 5 ] . $information[ $c + 6 ];
      ## Check for a slippery site from this position
      if ( Slip_p($next_seven) ) {
        push( @slipsites, $c );
        my $end_of_region = $c + $me->{max_stem_length};
        if ( defined( $me->Five_Prime_Stem_p( $c, \@information, $end_of_region ) ) ) {
          push( @slipsite_stems, $c );
        }
      }
    }
  }
  return ( \@slipsites, \@slipsite_stems );
}

sub Five_Prime_Stem_p {
  my $me            = shift;
  my $pos           = shift;
  my $sequence      = shift;
  my $end_of_region = shift;

  my @return = undef;

  my $end         = $pos + $me->{max_stem_distance};
  my $stem_length = $me->{stem_length};
  my $from_slip   = $me->{max_dist_from_slip};

  ## Get the search template: From the end of the slippery site until max_stem_length
  my @search_template = ();
  for my $char ( ( $pos + 7 + $from_slip ) .. $end_of_region ) {
    push( @search_template, $sequence->[$char] );
  }

  ## Pick out the search region: eg the x nucleotides after the slippery site
  ## which must be recursed over in order to find stems
  my $search_region = '';
  for my $c ( ( $pos + 6 ) .. ( $pos + 6 + $from_slip ) ) {
    $search_region .= $sequence->[$c];
  }
  my @search_reg = split( //, $search_region );
  while ( scalar( @search_reg >= $me->{stem_length} ) ) {
    my $mini_search = '';
    for my $nuc_num ( 0 .. ( $me->{stem_length} - 1 ) ) {
      $mini_search = join( '', $mini_search, $search_reg[$nuc_num] );
    }
    shift @search_reg;    ## hehe don't forget me
    print "searching for region: $mini_search<br>\n";
    if ( defined( $me->Search_Reverse( $mini_search, \@search_template ) ) ) {
      print "GOT A STEM AT $pos\n";
      return (1);
    }
  }
  print "<br><br>IMP: @return<br><br>\n";
  return ( \@return );
}

sub Search_Reverse {
  my $me              = shift;
  my $search_string   = shift;
  my $search_template = shift;

  my $new_string = reverse($search_string);
  $new_string =~ tr/agcutAGCUT/TCGAATCGAA/;
  print "$search_string and $new_string in @{$search_template}<br>\n";

  ## Worry about this later -- it will be the basis of handling GU base pairs
  my %expansions = ( T => [ 'T', 'G' ], );

  my @template = @{$search_template};
  my $count    = 0;
  while ( scalar(@template) >= $me->{stem_length} ) {
    $count++;
    my $seek = '';
    for my $char ( 0 .. ( $me->{stem_length} - 1 ) ) {
      $seek = join( '', $seek, $template[$char] );
    }
    if ( $seek eq $new_string ) {
      return (1);
      print "GOT ONE: $new_string, $seek at position: $count<br>\n";
    }
    shift @template;
  }
  return (undef);
}

## Given a sequence array and position, search the n nucleotides downstream from
## it for a region which will make a perfect nmer stem (4 nucleotides in this case)
#sub Five_Prime_Stem_p {
#  my $pos = shift;
#  my $sequence = shift;
#  my $subsequence = SubSeq(($pos + 7), 10, 'forward', $sequence);
#  print "TEST: $subsequence\n";
#}

#sub SubSeq {
#  my $pos = shift;
#  my $bases = shift;
#  my $direction = shift;
#  my $sequence = shift;
#  my @seq = @{$sequence};
#  my $return = '';
#  my $count = 1;
#  while ($bases >= $count) {
#	if ($direction eq 'forward') {
#	  $return .= $seq[$pos];
#	  $pos++;
#	}
#	elsif ($direction eq 'reverse') {
#	  $return .= $seq[$pos];
#	  $pos--;
#	}
#	$count++;
#  }
#  return($return);
#}

sub Slip_p {
  my $septet = shift;
  foreach my $slip (@slippery_sites) {
    return (1) if ( $slip eq $septet );
  }
  return (0);
}

1;
