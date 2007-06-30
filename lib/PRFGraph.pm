package PRFGraph;

use strict;
use DBI;
use PRFConfig qw / PRF_Error PRF_Out /;
use PRFdb;
use GD::Graph::mixed;

use Statistics::Basic::Mean;
use Statistics::Basic::Variance;
use Statistics::Basic::StdDev;
use Statistics::Distributions;
use Statistics::Basic::Correlation;

my $config = $PRFConfig::config;

sub new {
  my ( $class, $arg ) = @_;
  if ( defined( $arg->{config} ) ) {
    $config = $arg->{config};
  }
  my $me = bless {
    list_data => $arg->{list_data},
    accession  => $arg->{accession},
    real_mfe => $arg->{real_mfe},
    mfe_id => $arg->{mfe_id},
  }, $class;
  return ($me);
}

sub Make_Landscape {
  my $me        = shift;
  my $accession = $me->{accession};
  my $filename  = $me->Picture_Filename( { type => 'landscape', } );
  system("touch $filename");
  my $db         = new PRFdb;
  my $gene       = $db->MySelect("SELECT genename FROM genome WHERE accession='$accession'");
  my $data       = $db->MySelect("SELECT start, algorithm, pairs, mfe FROM landscape WHERE accession='$accession' ORDER BY start, algorithm");
  my $slipsites  = $db->MySelect("SELECT distinct(start) FROM mfe WHERE accession='$accession' ORDER BY start");
  my $start_stop = $db->MySelect("SELECT orf_start, orf_stop FROM genome WHERE accession = '$accession'");

  my $info        = {};
  my @points      = ();
  foreach my $datum ( @{$data} ) {
    my $place = $datum->[0];
    push( @points, $place );
    if ( $datum->[1] eq 'pknots' ) {
      $info->{$place}->{pknots} = $datum->[3];
    } elsif ( $datum->[1] eq 'nupack' ) {
      $info->{$place}->{nupack} = $datum->[3];
    }
  }    ## End foreach spot

  my ( @axis_x, @nupack_y, @pknots_y);
  my $end_spot = $points[$#points] + 105;
  my $current  = 0;
  while ( $current <= $end_spot ) {
    push( @axis_x, $current );
    if ( defined( $info->{$current} ) ) {
      push( @nupack_y, $info->{$current}->{nupack} );
      push( @pknots_y, $info->{$current}->{pknots} );
    }
    else {
      push( @nupack_y,    undef );
      push( @pknots_y,    undef );
    }
    $current++;
  }
  my @mfe_data = (\@axis_x, \@nupack_y, \@pknots_y,);
  my $width    = $end_spot;
  my $graph    = new GD::Graph::mixed( $width, 400 );
  $graph->set(
    x_label           => 'Distance on ORF',
    y_label           => 'kcal/mol',
    y_label_skip      => 2,
    y_number_format   => "%.2f",
    x_labels_vertical => 1,
    x_label_skip      => 100,
      line_width => 2,
      dclrs => [qw(blue red )],
    default_type      => 'lines',
      types => [qw(lines lines)],
  ) or die $graph->error;
  $graph->set_legend_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
  $graph->set_x_axis_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
  $graph->set_x_label_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
  $graph->set_y_axis_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
  $graph->set_y_label_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
  my $gd = $graph->plot( \@mfe_data ) or die( $graph->error );

  my $axes_coords = $graph->get_feature_coordinates('axes');
  my $top_x_coord = $axes_coords->[1];
  my $top_y_coord = $axes_coords->[2];
  my $bottom_x_coord = $axes_coords->[3];
  my $bottom_y_coord = $axes_coords->[4];
  my $green = $gd->colorAllocate(0,191,0);
  my $red = $gd->colorAllocate(191,0,0);
  my $black = $gd->colorAllocate(0,0,0);
  my $start_x_coord = $top_x_coord + $start_stop->[0]->[0];
  my $stop_x_coord = $top_x_coord + $start_stop->[0]->[1];
  my $orf_start = 0;
  my $orf_stop =
  ## Fill in the start site:
  $gd->filledRectangle($start_x_coord, $bottom_y_coord+1, $start_x_coord+1, $top_y_coord-1, $green);
  $gd->filledRectangle($stop_x_coord, $bottom_y_coord+1, $stop_x_coord+1, $top_y_coord-1, $red);
  foreach my $slipsite_x_coords (@{$slipsites}) {
      my $slipsite_x_coord = $slipsite_x_coords->[0];
      $gd->filledRectangle($slipsite_x_coord, $bottom_y_coord+1, $slipsite_x_coord+1, $top_y_coord-1, $black);
  }

  open( IMG, ">$filename" ) or die $!;
  binmode IMG;
  print IMG $gd->png;
  close IMG;
  return ($filename);
}

sub Make_Distribution{
    my $me = shift;
    my $graph_x_size = $config->{distribution_graph_x_size};
    my $graph_y_size = $config->{distribution_graph_y_size};
    
    #not yet implemented
    my $real_mfe = $me->{real_mfe};
    
    my @values = @{$me->{list_data}};
    my $acc_slip = $me->{acc_slip}; 
    
    
    my @sorted = sort {$a <=> $b} @values;
		
    my $min = sprintf("%+d",$sorted[0])-2;
    my $max = sprintf("%+d",$sorted[scalar(@sorted)-1])+2;
    
    my $total_range = sprintf("%d",($max - $min));
    
    my $num_bins = sprintf( "%d",2 * (scalar(@sorted) ** (2/5))); # bins = floor{ 2 * N^(2/5) }
    $num_bins++ if ($num_bins == 0);
    my $bin_range = sprintf( "%.1f", $total_range / $num_bins);
	
    my @yax = ( 0 );
    my @yax_sums = ( 0 );
    my @xax = ( sprintf("%.1f",$min) );
    
    for(my $i = 1; $i <= ($num_bins); $i++){
        $xax[$i] = sprintf( "%.1f",$bin_range * $i + $min);
        foreach my $val (@values) { 
	    if ($val < $xax[$i]) {
		$yax_sums[$i]++;
	    }
	}
    }
    #save the CDF
    my @CDF_yax = @yax_sums;
    
    # make a histogram and not a cumulative distribution function
    my $i = 0;
    for ($i = (@yax_sums-1); $i > 0; $i--) {
	my $subtraction = 0;
	my $y_axis_sum = 0;
	if (defined($yax_sums[$i])) {
	    $y_axis_sum = $yax_sums[$i];
	}
	if (defined($yax_sums[$i - 1])) {
	    $subtraction = $yax_sums[$i - 1];
	}
	$yax[$i] = ($y_axis_sum - $subtraction) / scalar(@values);
    }
    
    ###
    # Stats part
    my $xbar = sprintf("%.2f",Statistics::Basic::Mean->new(\@values)->query);
    my $xvar = sprintf("%.2f",Statistics::Basic::Variance->new(\@values)->query);
    my $xstddev = sprintf("%.2f",Statistics::Basic::StdDev->new(\@values)->query);
    
    
    # initially calculated as a CDF.
    my @dist_y = ();
    foreach my $x (@xax) {
        my $zscore; 
        if ($xstddev == 0) {
	 $zscore = 0;
	}
	else {
         $zscore = ($x - $xbar) / $xstddev;
        }
        my $prob = (1 - Statistics::Distributions::uprob($zscore));
        push(@dist_y,$prob);
    }
    #save the CDF
    my @CDF_dist = @dist_y;
    
    # make a pdf not a cdf.
    my $y_axis_maximum = 0;
    for(my $i = (@dist_y-1); $i > 0; $i--) {
	$dist_y[$i] = $dist_y[$i] - $dist_y[$i-1];
	if ($dist_y[$i] > $y_axis_maximum) {
	    $y_axis_maximum = $dist_y[$i];
	}
    }

    ## Make an array for the mfe value points
    
#    my @real_mfes;

    ## Assume 13 buckets
    ## The absolute y_axis maximum is 1.0
    ## $y_axis_maximum is one value >= 1.0
    ## I want to put $real_mfes[$c] between $y_axis_maximum and 0 so that earlier buckets get higher $y_axis_maximums
#    my $mfe_y_position = $y_axis_maximum;
#    my $mfe_y_decrement = ($y_axis_maximum / 10.0);
#    print "STARTING y max: $mfe_y_position DECEMENT: $mfe_y_decrement\n<br>";
#    for my $c (0 .. $#xax) {
#	$mfe_y_position -= $mfe_y_decrement;
#	print "TESTME $xax[$c] $mfe_y_position\n<br>";
#	if ($real_mfe < $xax[$c]) {
#	    print "$real_mfe is less than $xax[$c]\n<br>";
#	    $real_mfes[$c] = $y_axis_maximum/2;
#	    push(@real_mfes, undef);
#	    last;
#	}
#	else {
#	    push(@real_mfes, undef);
#	}
#    }

    # Chart part
    my @data = (\@xax, \@yax, \@dist_y, [0], );
    
    my $graph = GD::Graph::mixed->new($graph_x_size, $graph_y_size);
    $graph->set_legend( "Random MFEs", "Normal Distribution", "Actual MFE");
    $graph->set(
            types             => [ qw(bars lines lines) ],
            x_label           => 'kcal/mol',
            y_label           => 'p(x)',
            y_label_skip      => 2,
            y_number_format   => "%.2f",
            x_labels_vertical => 1,
            x_label_skip      => 1,
            line_width => 3,
            dclrs => [qw(blue red green)],
            borderclrs => [ qw(black ) ]
    ) or die $graph->error;

    $graph->set_legend_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_axis_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_label_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_axis_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_label_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});

    my $gd = $graph->plot(\@data) or die $graph->error;
 
    my $axes_coords = $graph->get_feature_coordinates('axes');

    my $top_x_coord = $axes_coords->[1];
    my $top_y_coord = $axes_coords->[2];
    my $bottom_x_coord = $axes_coords->[3];
    my $bottom_y_coord = $axes_coords->[4];

    my $x_interval = sprintf("%.1f", (($max-$min)/$num_bins) );

    # print "$x_interval\n";
    # my $bins_adjustment = $num_bins - 1;
    my $x_interval_pixels = ( $bottom_x_coord - $top_x_coord )/($num_bins + 2);
    # my $mfe_x_coord = (($real_mfe - $min)/($x_interval*$num_bins)) + $mfe_x_coord_buffer + $top_x_coord;
    my $mfe_x_coord = $top_x_coord + ($x_interval_pixels) + (($real_mfe - $min) * ($x_interval_pixels/$x_interval));
    # print "$max, $min, $real_mfe, $top_x_coord, $bottom_x_coord, $mfe_x_coord, $x_interval, $x_interval_pixels\n";
    # print "$axes_coords->[0], $top_x_coord, $top_y_coord, $bottom_x_coord, $bottom_x_coord, $mfe_x_coord"; 

    my $green = $gd->colorAllocate(0,191,0);
    $gd->filledRectangle($mfe_x_coord, $bottom_y_coord+1 , $mfe_x_coord+1, $top_y_coord-1, $green);

    my $filename = $me->Picture_Filename( { type => 'distribution', } );
    open(IMG, ">$filename") or die ("Unable to open $filename $!");
    binmode IMG;
    print IMG $gd->png;
    close IMG;
    return($filename);
}

sub Make_Feynman {
    my $me = shift;
    my $input_file = shift;
    my $acc_slip = $me->{acc_slip};
    my $filename = $me->Picture_Filename( { type => 'feynman', } );
    my $command = qq(DISPLAY=:6 ; /usr/bin/java -jar $config->{workdir}/jViz.jar -t -i $input_file -l $filename 2>$config->{workdir}/java.out 1>&2);
    my $output = system($command);
    system("rm $input_file");
}

sub Get_PPCC {
  my $me = shift;

  #probably should put some error checking here.. but... wtf!
  my @values = @{ $me->{list_data} };
  my @sorted = sort { $a <=> $b } @values;

  ###
  # Stats part
  my $n       = scalar(@values);
  my $xbar    = sprintf( "%.2f", Statistics::Basic::Mean->new( \@values )->query );
  my $xvar    = sprintf( "%.2f", Statistics::Basic::Variance->new( \@values )->query );
  my $xstddev = sprintf( "%.2f", Statistics::Basic::StdDev->new( \@values )->query );

  # get P(X) for each values
  my @PofX = ();
  foreach my $x (@sorted) {
    if ($xstddev == 0) {
      push( @PofX, 0 );
    }
    else { 
      push( @PofX, ( 1 - Statistics::Distributions::uprob( $x - $xbar ) / $xstddev ) );
    }
  }

  #get P(X) for the standard normal distribution
  my @PofY = ();
  for ( my $i = 1 ; $i < $n + 1 ; $i++ ) {
    push( @PofY, $i / ( $n + 1 ) );
  }

  my $corr = new Statistics::Basic::Correlation( \@PofY, \@PofX );

  return $corr->query;
}

sub Picture_Filename {
  my $me        = shift;
  my $args      = shift;
  my $type = $args->{type};
  my $url = $args->{url};

  my $accession = $me->{accession};
  my $mfe_id = $me->{mfe_id};

  my $directory = $me->Make_Directory( $type, $url );
  my $filename;
  if (defined($mfe_id)) {
      $filename = qq($directory/${accession}-${mfe_id}.png);
  }
  else {
      $filename  = qq($directory/$accession.png);
  }

  return ($filename);
}

sub Make_Directory {
  my $me        = shift;
  my $type      = shift;
  my $url       = shift;
  my $dir       = '';
  my $accession = $me->{accession};
  my $nums      = $accession;
  $nums =~ s/\W//g;
  $nums =~ s/[a-z]//g;
  $nums =~ s/[A-Z]//g;
  $nums =~ s/_//g;
  my @cheat  = split( //, $nums );
  my $first  = shift @cheat;
  my $second = shift @cheat;
  my $third  = shift @cheat;
  my $fourth = shift @cheat;
  my $fifth  = shift @cheat;
  my $sixth  = shift @cheat;

  if ( defined($url) ) {
    my $url = qq(images/$type/${first}${second}/${third}${fourth});
    return ($url);
  }
  my $directory = qq($config->{base}/images/$type/${first}${second}/${third}${fourth});
  
  my $command = qq(/bin/mkdir -p $directory);
  #system($command);
  #print "the command: $command <br>\n";
  my $output = '';
  if ( !-r $directory ) {
      open (CMD, "$command |") or die("Could not run $command
Make sure that user $< and/or group $( has write permissions: $!");
      while (my $line = <CMD>) {
	  $output .= $line;
     } 
  }
  return ($directory);
}
