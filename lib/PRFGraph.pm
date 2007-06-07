package PRFGraph;

use strict;
use DBI;
use PRFConfig qw / PRF_Error PRF_Out /;
use PRFdb;
use GD::Graph::mixed;
# use GD::SVG;
use Statistics::Basic::Mean;
use Statistics::Basic::Variance;
use Statistics::Basic::StdDev;
use Statistics::Distributions;
use Statistics::Basic::Correlation;

my $config = $PRFConfig::config;
my $db = new PRFdb;

sub new {
  my ($class, $arg) = @_;
  if (defined($arg->{config})) {
    $config = $arg->{config};
  }
  my $me = bless {
    list_data => $arg->{list_data},
    acc_slip => $arg->{acc_slip},
  }, $class;
  return($me);
}

sub Make_Landscape {
  my $me = shift;
  my $accession = shift;
  my $filename = $me->Picture_Filename('landscape', $accession);
  system("touch $filename");
  # my $img = GD::SVG::Image->new();
  my $gene = $db->MySelect("SELECT genename FROM genome WHERE accession='$accession'");
  my $data = $db->MySelect("SELECT start, algorithm, pairs, mfe FROM landscape WHERE accession='$accession' ORDER BY start, algorithm");
  my $slipsites = $db->MySelect("SELECT distinct(start) FROM mfe WHERE accession='$accession' ORDER BY start");
  my $start_stop = $db->MySelect("SELECT orf_start, orf_stop FROM genome WHERE accession = '$accession'");

  my $info = {};
  my @points = ();
  my $avg_counter = 0;
  my $avg_sum = 0;
  foreach my $datum (@{$data}) {
    $avg_counter = $avg_counter + 2;
    my $place = $datum->[0];
    push(@points, $place);
    if ($datum->[1] eq 'pknots') {
      $info->{$place}->{pknots} = $datum->[3];
      $avg_sum = $avg_sum + $datum->[3];
    }
    elsif ($datum->[1] eq 'nupack') {
      $info->{$place}->{nupack} = $datum->[3];
      $avg_sum = $avg_sum + $datum->[3];
    }
  }  ## End foreach spot
  my $average = $avg_sum / $avg_counter;
  my $site_info = {};
  foreach my $site (@{$slipsites}) {
    $site_info->{$site->[0]} = 'slipsite';
  }
  $site_info->{$start_stop->[0]->[0]} = 'start';
  $site_info->{$start_stop->[0]->[1]} = 'stop';
#  print "TESTME START: $start_stop->[0]->[0] STOP: $start_stop->[0]->[1]<br>\n";

  my (@axis_x, @slipsites_y, @nupack_y, @pknots_y, @start_y, @stop_y);
  my $end_spot = $points[$#points] + 105;
  my $current = 0;
  while ($current <= $end_spot) {
    push(@axis_x, $current);
    if (defined($info->{$current})) {
      push(@nupack_y, $info->{$current}->{nupack});
      push(@pknots_y, $info->{$current}->{pknots});
      if (defined($site_info->{$current})) {
	if ($site_info->{$current} eq 'start') {
	  push(@start_y, $average);
	  push(@slipsites_y, undef);
	  push(@stop_y, undef);
	}
	elsif ($site_info->{$current} eq 'stop') {
	  push(@start_y, undef);
	  push(@slipsites_y, undef);
	  push(@stop_y, $average);
	}
	elsif ($site_info->{$current} eq 'slipsite') {
	  push(@start_y, undef);
	  push(@slipsites_y, $average);
	  push(@stop_y, undef);
	}
      }
      else {
	  push(@start_y, undef);
	  push(@slipsites_y, undef);
	  push(@stop_y, undef);
      }
    }


    elsif (defined($site_info->{$current})) {
      if ($site_info->{$current} eq 'start') {
	push(@start_y, $average);
	push(@slipsites_y, undef);
	push(@stop_y, undef);
      }
      elsif ($site_info->{$current} eq 'stop') {
	push(@start_y, undef);
	push(@slipsites_y, undef);
	push(@stop_y, $average);
      }
      elsif ($site_info->{$current} eq 'slipsite') {
	push(@start_y, undef);
	push(@slipsites_y, $average);
	push(@stop_y, undef);
      }
      else {
	push(@start_y, undef);
	push(@slipsites_y, undef);
	push(@stop_y, undef);
      }
    }


    else {
      push(@slipsites_y, undef);
      push(@nupack_y, undef);
      push(@pknots_y, undef);
      push(@start_y, undef);
      push(@stop_y, undef);
    }
    $current++;
  }

  my @mfe_data = (\@axis_x, \@nupack_y, \@pknots_y, \@slipsites_y, \@start_y, \@stop_y);
  my $width = $end_spot;
  my $graph = new GD::Graph::mixed($width, 400);
  $graph->set(
	      x_label => 'Distance on ORF',
	      y_label => 'kcal/mol',
	      y_label_skip => 2,
	      y_number_format => "%.2f",
	      x_labels_vertical => 1,
	      x_label_skip => 100,
	      dclrs => [qw(blue red black green red)],
	      default_type => 'lines',
	      types => [qw(lines lines points points points)],
	      markers => [10],
	      marker_size => 160,
	     ) or die $graph->error;

  my $gd = $graph->plot(\@mfe_data) or die($graph->error);

  open(IMG, ">$filename") or die $!;
  binmode IMG;
  print IMG $gd->png;
  close IMG;
  return($filename);
}

sub Make_Distribution{
    my $me = shift;
    
    #not yet implemented
    #my $real_mfe = $me->{realmfe};
    
    my @values = @{$me->{list_data}};
    my $acc_slip = $me->{acc_slip}; 
    
    my $filename = $me->Picture_Filename('distribution', $acc_slip);
    
    my @sorted = sort {$a <=> $b} @values;
		
    my $min = sprintf("%+d",$sorted[0])-2;
    my $max = sprintf("%+d",$sorted[scalar(@sorted)-1])+2;
    
    my $total_range = sprintf("%d",($max - $min));
    
    my $num_bins = sprintf( "%d",2 * (scalar(@sorted) ** (2/5))); # bins = floor{ 2 * N^(2/5) }
    
    my $bin_range = sprintf( "%.1f", $total_range / $num_bins);
	
	my @yax = ( 0 );
    my @yax_sums = ( 0 );
    my @xax = ( sprintf("%.1f",$min) );
    
    for(my $i = 1; $i <= ($num_bins); $i++){
        $xax[$i] = sprintf( "%.1f",$bin_range * $i + $min);
        foreach my $val (@values){ $yax_sums[$i]++ if $val < $xax[$i] }
    }
    #save the CDF
    my @CDF_yax = @yax_sums;
    
    # make a histogram and not a cumulative distribution function
    for(my $i = (@yax_sums-1); $i > 0; $i--){ $yax[$i] = ($yax_sums[$i]-$yax_sums[$i-1]) / scalar(@values); }
    
    ###
    # Stats part
    my $xbar = sprintf("%.2f",Statistics::Basic::Mean->new(\@values)->query);
    my $xvar = sprintf("%.2f",Statistics::Basic::Variance->new(\@values)->query);
    my $xstddev = sprintf("%.2f",Statistics::Basic::StdDev->new(\@values)->query);
    
    
    # initially calculated as a CDF.
    my @dist_y = ();
    foreach my $x (@xax){
        my $zscore = ($x - $xbar) / $xstddev;
        my $prob = (1 - Statistics::Distributions::uprob($zscore));
        push(@dist_y,$prob);
    }
    #save the CDF
    my @CDF_dist = @dist_y;
    
    # make a pdf not a cdf.
    for(my $i = (@dist_y-1); $i > 0; $i--){ $dist_y[$i] = $dist_y[$i] - $dist_y[$i-1]; }
    
    ###
    # Chart part
    my @data = (\@xax, \@yax, \@dist_y );
    
    my $graph = GD::Graph::mixed->new(200,150);
    $graph->set_legend( "Random MFE", "Normal Distribution");
    $graph->set(
            types             => [ qw(bars lines) ],
            x_label           => 'kcal/mol',
            y_label           => 'p(x)',
            y_label_skip      => 2,
            y_number_format   => "%.2f",
            x_labels_vertical => 1,
            x_label_skip      => 1,
            line_width => 3,
            dclrs => [qw(lblue red)],
            borderclrs => [ qw(black ) ]
    ) or die $graph->error;

    my $gd = $graph->plot(\@data) or die $graph->error;
    
    # THIS NEEDS TO BE UNCOMMENTED
    #my $tempfile = 'temp/graph'.time().'.gif';
	open(IMG, ">$filename") or die $!;
 	binmode IMG;
    print IMG $gd->png;
    close IMG;
    return($filename);
}

sub Get_PPCC{
    my $me = shift;

    #probably should put some error checking here.. but... wtf!
    my @values = @{$me->{list_data}};
    my @sorted = sort {$a <=> $b} @values;
		
    ###
    # Stats part
    my $n = scalar(@values);
    my $xbar = sprintf("%.2f",Statistics::Basic::Mean->new(\@values)->query);
    my $xvar = sprintf("%.2f",Statistics::Basic::Variance->new(\@values)->query);
    my $xstddev = sprintf("%.2f",Statistics::Basic::StdDev->new(\@values)->query);
    
    # get P(X) for each values
    my @PofX = ();
    foreach my $x (@sorted){
    	push(@PofX, (1 - Statistics::Distributions::uprob($x - $xbar) / $xstddev));
    }
    
    #get P(X) for the standard normal distribution
    my @PofY = ();
    for(my $i = 1; $i < $n+1; $i++){
    	push(@PofY,$i/($n+1));
   	}
   	
	my $corr = new Statistics::Basic::Correlation( \@PofY, \@PofX );
	
	return $corr->query;
}

sub Picture_Filename {
    my $me = shift;
    my $type = shift;
    my $accession = shift;
    my $url = shift;
    my $directory = $me->Make_Directory($type, $accession, $url);
    my $filename = qq($directory/$accession.png);
#    print "Picture_Filename: $filename\n";
    return($filename);
}

sub Make_Directory {
  my $me = shift;
  my $type = shift;
  my $accession = shift;
  my $url = shift;
  my $dir = '';
  my $nums = $accession;
  $nums =~ s/\W//g;
  $nums =~ s/[a-z]//g;
  $nums =~ s/[A-Z]//g;
#  print "TESTME $nums\n";
  my @cheat = split(//, $nums);
  my $first = shift @cheat;
  my $second = shift @cheat;
  my $third = shift @cheat;
  my $fourth = shift @cheat;
  my $fifth = shift @cheat;
  my $sixth = shift @cheat;
  if (defined($url)) {
      my $url = qq($type/${first}${second}/${third}${fourth});
      return($url);
  }
  my $directory = qq($config->{base}/$type/${first}${second}/${third}${fourth});
#  print "<br>$directory\n<br>\n";
  if (!-x $directory) {
      system("mkdir -p $directory");
  }
  return($directory);
}
