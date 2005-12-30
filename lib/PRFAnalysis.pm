package PRFAnalysis;

# my $charturl = $chart->GET_CHART_URL();

use strict;
use GD::Graph::mixed;
use Statistics::Basic::Mean;
use Statistics::Basic::Variance;
use Statistics::Basic::StdDev;
use Statistics::Distributions;
use Statistics::Basic::Correlation;
use File::Temp;

sub new {
    my ($class, $args) = @_;
    #my %args = @_;  ## Pass { _list_data => 'list' }
    
    my $obj = bless {
        list_data => $args->{list_data},
        #realmfe => $args->{realmfe},
        tempfh => ""
    }, $class;
    
    #unless( $obj->{list_data} ){
    #    my @tmp = qw(-17.20  -31.80  -26.40  -33.40  -21.50  -20.40  -27.00  -24.90  -34.80  -26.00  -19.00  -24.00  -19.50  -24.20  -22.90  -23.10  -26.10  -26.20  -22.70  -21.00  -24.40  -26.70  -20.70  -26.20  -21.70  -23.20  -23.30  -22.30  -30.30  -19.10  -27.50  -26.60  -30.60  -24.10  -24.20  -28.00  -24.40  -25.60  -22.00  -23.00  -29.40  -21.80  -29.20  -21.60  -19.30  -20.10  -21.10  -24.00  -25.70  -34.10  -22.30  -19.30  -16.40  -20.60  -23.90  -32.20  -25.00  -21.50  -24.00  -22.90  -23.90  -25.70  -24.20  -28.20  -27.20  -21.00  -27.60  -24.70  -22.20  -24.90  -24.70  -24.40  -24.70  -22.40  -21.00  -18.80  -28.30  -24.00  -20.80  -24.80  -24.30  -18.20  -30.50  -22.00  -26.00  -23.20  -31.10  -23.60  -18.60  -28.80  -21.40  -23.80  -24.20  -24.30  -21.50  -20.20  -26.40  -18.50  -25.60  -18.90);
    #    $obj->{list_data} = \@tmp;
    #}
    
    #unless( $obj->{realmfe} ){ $obj->{realmfe} = "-31.00"; }    
    
    return $obj;
}

# PPCC is Probability Plot Correlation Coefficient; basically, how good does the randomized data fit a normal distribution?
# see Jacobs & Dinman, NAR 2004 or Filliben 1974 for more info.
sub GET_PPCC{
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

sub GET_CHART_URL{
    my $me = shift;
    
    #not yet implemented
    #my $real_mfe = $me->{realmfe};
    
    my @values = @{$me->{list_data}};
    
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
    my $fh = new File::Temp(
        TEMPLATE => "chartXXXXXX",
        DIR => "temp",
        SUFFIX => ".gif",
        UNLINK => 0
    );
    
    my $tempfile = $fh->filename();
    print $fh $gd->gif;

    return $tempfile;
}

1;

