package PRFGraph;

use strict;
use DBI;
use PRFConfig qw / PRF_Error PRF_Out /;
use PRFdb;
use GD::Graph::mixed;
use GD::SVG;
use Statistics::Basic::Mean;
use Statistics::Basic::Variance;
use Statistics::Basic::StdDev;
use Statistics::Distributions;
use Statistics::Basic::Correlation;

# GD::Image->trueColor(1);
my $config = $PRFConfig::config;

sub new {
  my ( $class, $arg ) = @_;
  if ( defined( $arg->{config} ) ) {
    $config = $arg->{config};
  }
  my $me = bless {}, $class;
  foreach my $key (%{$arg}) {
      $me->{$key} = $arg->{$key};
  }
  return ($me);
}

sub Make_Cloud {
    my $me = shift;
    my $species = shift;
    my $data = shift;
    my $averages = shift;
    my $filename = shift;
    my $url = shift;
    my $graph = new GD::Graph::points('800','800');

    my $mfe_min_value = -80;
    my $mfe_max_value = 5;
    my $z_min_value = -10;
    my $z_max_value = 10;
    $graph->set(
		bgclr => 'white',

		x_min_value => $mfe_min_value,
		x_max_value => $mfe_max_value,
		x_ticks => 1,
		x_label           => 'MFE',
		x_labels_vertical => 1,
		x_label_skip      => 0,
		x_number_format   => "%.1f",
		x_tick_number => 20,
		x_all_ticks => 1,

		y_min_value => $z_min_value,
		y_max_value => $z_max_value,
		y_ticks => 1,
		y_label           => 'Zscore',
		y_label_skip      => 0,
		y_number_format   => "%.2f",
		y_tick_number => 20,
		y_all_ticks => 1,

		dclrs => ['black','black'],
		marker_size => 0,

		);
    $graph->set_legend_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_axis_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_label_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_axis_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_label_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    my $fun = [[-100,-100,-100],[0,0,0]];
    my $gd = $graph->plot($fun,) or die ($graph->error);
    #$gd = GD::Image->TrueColor(1);
    my $black = $gd->colorResolve(0,0,0);
    my $green = $gd->colorResolve(0,191,0);
    my $blue = $gd->colorResolve(0,0,191);
    my $gb = $gd->colorResolve(0,97,97);
    my $axes_coords = $graph->get_feature_coordinates('axes');
    my $left_x_coord = $axes_coords->[1];
    my $top_y_coord = $axes_coords->[2];
    my $right_x_coord = $axes_coords->[3];
    my $bottom_y_coord = $axes_coords->[4];
    my $x_range = $right_x_coord - $left_x_coord;
    my $y_range = $top_y_coord - $bottom_y_coord;
    my $mfe_range = $mfe_max_value - $mfe_min_value;
    my $z_range = $z_max_value - $z_min_value;

    my $points = {};
    my $max_counter = 1;
    foreach my $point (@{$data}) {
	my $x_point = sprintf("%.1f",$point->[0]);
	my $y_point = sprintf("%.1f",$point->[1]);
	#print "MFE_value: $x_point Zscore: $y_point<br>\n";
	if ( defined($points->{$x_point}->{$y_point})) {
	    $points->{$x_point}->{$y_point}->{count}++;
	    if ( $max_counter < $points->{$x_point}->{$y_point}->{count} ) {
		$max_counter = $points->{$x_point}->{$y_point}->{count};
	    }
	}
	else {
	    $points->{$x_point}->{$y_point}->{count} = 1;
	    $points->{$x_point}->{$y_point}->{accession} = $point->[2];
	}
    }

    my $average_mfe_coord = sprintf("%.1f",((($x_range/$mfe_range)*($averages->[0] - $mfe_min_value)) + $left_x_coord));
    my $average_z_coord = sprintf("%.1f",((($y_range/$z_range)*($z_max_value - $averages->[1])) + $bottom_y_coord));
    my $tmp_filename = $filename;
    open(MAP, ">${tmp_filename}.map");
    foreach my $x_point (keys %{$points}) {
	my $x_coord = sprintf("%.1f",((($x_range/$mfe_range)*($x_point - $mfe_min_value)) + $left_x_coord));
	foreach my $y_point (keys %{$points->{$x_point}}) {
	    my $accession = $points->{$x_point}->{$y_point}->{accession};
	    my $y_coord = sprintf("%.1f",((($y_range/$z_range)*($z_max_value - $y_point)) + $bottom_y_coord));
	    my $counter = $points->{$x_point}->{$y_point}->{count};
	    
	    ## Quadrant Color Code
	    my $color_value = 220 - (220*($counter/$max_counter));
	    my $color = undef;
	    # print "X: $x_coord Y: $y_coord AVGX: $average_mfe_coord AVGY: $average_z_coord CV: $color_value";
	    if ( ($x_coord < $average_mfe_coord) and ($y_coord > $average_z_coord) ) {
		$color = $gd->colorResolve($color_value,0,0);
		# print " C: red<br>\n";
	    } elsif ( $x_coord < $average_mfe_coord ) {
		$color = $gd->colorResolve(0,$color_value,0);
		# print " C: green<br>\n";
	    } elsif ( $y_coord > $average_z_coord ) {
		$color = $gd->colorResolve(0,0,$color_value);
		# print " C: blue<br>\n";
	    } elsif ( ($x_coord > $average_mfe_coord) and ($y_coord < $average_z_coord) ) {
		$color = $gd->colorResolve($color_value,$color_value,$color_value);
		# print " C: grey<br>\n";
	    } else {
		$color = $gd->colorResolve(254,191,191);
		# print " C: pink<br>\n";
	    }
	    $gd->filledArc($x_coord, $y_coord, 4, 4, 0, 360, $color, 4);
	    $x_coord = sprintf('%.0f', $x_coord);
	    $y_coord = sprintf('%.0f', $y_coord);
	    my $string = qq(point ${url}/mfe_z?species=${species}&mfe=${x_point}&z=${y_point} ${x_coord},${y_coord}\n);
	    print MAP $string;
	}
    }
    close MAP;
    $gd->filledRectangle($average_mfe_coord, $bottom_y_coord+1, $average_mfe_coord+1, $top_y_coord-1, $black);
    $gd->filledRectangle($left_x_coord+1, $average_z_coord, $right_x_coord-1, $average_z_coord+1, $black);
    $gd->filledRectangle($average_mfe_coord, $bottom_y_coord+1, $average_mfe_coord+1, $top_y_coord-1, $black);
    open (IMG, ">$filename") or die "error opening $filename to write image: $!";
    binmode IMG;
    print IMG $gd->png;
    close IMG;
    return($points);
}

sub Make_Landscape {
  my $me        = shift;
  my $accession = $me->{accession};
  my $filename  = $me->Picture_Filename( { type => 'landscape', } );
  system("touch $filename");
  my $db         = new PRFdb;
#  my $gene       = $db->MySelect({
#	  statement => "SELECT genename FROM genome WHERE accession='$accession'",
#	  type => 'single'
#				 });
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
	      bgclr   => 'white',
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
  $graph->set_x_label_font("$config->{base}/fonts/$config->o{graph_font}", $config->{graph_font_size});
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
  my $orf_stop = $end_spot;
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

    # Chart part
    my @data = (\@xax, \@yax, \@dist_y, [0], );
    
    my $graph = GD::Graph::mixed->new($graph_x_size, $graph_y_size);
    $graph->set_legend( "Random MFEs", "Normal Distribution", "Actual MFE");
    $graph->set(
		bgclr => 'white',
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
    my $x_interval_pixels = ( $bottom_x_coord - $top_x_coord )/($num_bins + 2);
    my $mfe_x_coord = $top_x_coord + ($x_interval_pixels) + (($real_mfe - $min) * ($x_interval_pixels/$x_interval));

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
    my $id = $me->{mfe_id};
    my $db         = new PRFdb;
    my $stmt = qq(SELECT sequence, parsed, output FROM mfe WHERE id = ?);
    my $info = $db->MySelect({statement => $stmt, vars => [$id], type => 'row' });
    my $sequence = $info->[0];
    my $parsed = $info->[1];
    my $pkout = $info->[2];
    my $seqlength = length($sequence);
    my $character_size = 10;
    my $height_per_nt = 3.5;

    my $x_pad = 10;
    my $width = ($seqlength * ($character_size - 2)) + ($x_pad * 2);

    my $pkt = $pkout;
    my @pktmp = split(/\s+/, $pkt);
    my $max_dist = 0;
    for my $c (0 .. $#pktmp) {
	my $count = $c + 1;
	next if ($pktmp[$c] eq '.');
	my $dist = $pktmp[$c] - $c;
	$max_dist = $dist if ($dist > $max_dist);
	$pktmp[$pktmp[$c]] = '.';
    }
    my $height = (($height_per_nt * $max_dist) /2) + ($character_size * 4);
   
    my $fey = new GD::SVG::Image($width,$height);
    my $white = $fey->colorAllocate(255, 255, 255);
    my $black = $fey->colorAllocate(0, 0, 0);
    my $blue = $fey->colorAllocate(0, 0, 191);
    my $red = $fey->colorAllocate(248,0,0);
    my $green = $fey->colorAllocate(0, 191, 0);
    my $purple = $fey->colorAllocate(192,60,192);
    my $orange = $fey->colorAllocate(255,165,0);
    my $brown = $fey->colorAllocate(192,148,68);
    my $darkslategray = $fey->colorAllocate(165,165,165);
    my $gray   = $fey->colorAllocate(127,127,127);
    my $aqua   = $fey->colorAllocate(127,255,212);
    my $yellow = $fey->colorAllocate(255,255,0);
    my $gb = $fey->colorAllocate(0, 97, 97);

    $fey->transparent($white);
#1    $fey->filledRectangle(0,0,$width,$height,$white);

    my @colors = ($black, $blue, $red, $green, $purple, $orange, $brown, $darkslategray,
		  $black, $blue, $red, $green, $purple, $orange, $brown, $darkslategray,
		  $black, $blue, $red, $green, $purple, $orange, $brown, $darkslategray,
	);

    my $start_x = $x_pad;
    my $start_y = $height - 10;

    my $bounds = $fey->string(gdMediumBoldFont, $start_x, $start_y-10, $sequence, $black);

    my $distance_per_char = $character_size - 2;
    my $string_x_distance = $character_size * length($sequence);

    my @stems = split(/\s+/, $parsed);
    my @paired = split(/\s+/, $pkout);
    my @seq = split(//, $sequence);
    my $last_stem = $me->Get_Last(\@stems);
    my $bp_per_stem = $me->Get_Stems(\@stems);

    for my $c (0 .. $#seq) {
	my $count = $c+1;
	next if ($paired[$c] eq '.');
	if ($paired[$c] =~ /\d+/) {
	    my $current_stem = $stems[$c];
	    my $bases_in_stem = $bp_per_stem->{$current_stem};
	    my $center_characters = ($paired[$c] - $c) / 2;
	    my $center_position = $center_characters * $distance_per_char;
	    my $center_x = $center_position + ($c * $distance_per_char);
	    my $center_y = $height;
	    my $dist_x = $center_characters * $distance_per_char * 2;
	    my $dist_nt = $paired[$c] - $c;
	    my $dist_y = $dist_nt * $height_per_nt;
	    $center_x = $center_x + $x_pad + ($distance_per_char / 2);
	    $center_y = $center_y - 20;
	    $fey->setThickness(2);
	    $fey->arc($center_x, $center_y, $dist_x, $dist_y, 180, 0, $colors[$stems[$c]]);
	    $paired[$paired[$c]] = '.';
	}
    }
    my $output = $me->Picture_Filename( {type => 'feynman',});
    $output =~ s/\.png/\.svg/g;
    open(OUT, ">$output");
    binmode OUT;
    print OUT $fey->svg;
    close OUT;
    my $command = qq(sed 's/font="Helvetica"/font-family="Courier New"/g' $output > ${output}.tmp);
    system($command);
    my $command2 = qq(mv ${output}.tmp $output);
    system($command2);
    my $ret = {
	width => $width,
	height =>$height,
    };
    return($ret);
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
  my $species = $args->{species};

  my $accession = $me->{accession};
  my $mfe_id = $me->{mfe_id};

  if (defined($species)) {
      if (defined($url)) {
	  return(qq(images/${type}/${species}.png));
      }
      else {
	  return(qq($config->{base}/images/${type}/${species}.png));
      }
  }

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

sub Get_Last {
    my $me = shift;
    my $list = shift;
    my $last = 0;
    foreach my $char (@{$list}) {
	next if ($char eq '.');
	$last = $char if ($char > $last);
    }
    return($last);
}

sub Get_Stems {
    my $me = shift;
    my $list = shift;
    my $dat = {};
    foreach my $char (@{$list}) {
	next if ($char eq '.');
	if (!defined($dat->{$char})) {
	    $dat->{$char} = 0.5;
	}
	else {
	    $dat->{$char} = $dat->{$char} + 0.5;
	}
    }
    return($dat);
}

