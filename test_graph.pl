#!/usr/bin/perl -w
use strict;
use CGI qw/:standard :html3/;
use CGI::Carp qw(fatalsToBrowser carpout);

use GD::Graph::mixed;
use Statistics::Basic::Mean;
use Statistics::Basic::Variance;
use Statistics::Basic::StdDev;
use Statistics::Distributions;


my $cgi = new CGI;
print $cgi->header;
print $cgi->start_html("TEST CHART");

my $string_values = "-17.20  -31.80  -26.40  -33.40  -21.50  -20.40  -27.00  -24.90  -34.80  -26.00  -19.00  -24.00  -19.50  -24.20  -22.90  -23.10  -26.10  -26.20  -22.70  -21.00  -24.40  -26.70  -20.70  -26.20  -21.70  -23.20  -23.30  -22.30  -30.30  -19.10  -27.50  -26.60  -30.60  -24.10  -24.20  -28.00  -24.40  -25.60  -22.00  -23.00  -29.40  -21.80  -29.20  -21.60  -19.30  -20.10  -21.10  -24.00  -25.70  -34.10  -22.30  -19.30  -16.40  -20.60  -23.90  -32.20  -25.00  -21.50  -24.00  -22.90  -23.90  -25.70  -24.20  -28.20  -27.20  -21.00  -27.60  -24.70  -22.20  -24.90  -24.70  -24.40  -24.70  -22.40  -21.00  -18.80  -28.30  -24.00  -20.80  -24.80  -24.30  -18.20  -30.50  -22.00  -26.00  -23.20  -31.10  -23.60  -18.60  -28.80  -21.40  -23.80  -24.20  -24.30  -21.50  -20.20  -26.40  -18.50  -25.60  -18.90";
my @values = split(/\s+/, $string_values);

my $real_mfe = "-31.00";

print $cgi->img({
    src=>&RANDOMCHART( $real_mfe, @values ),
    align=>'LEFT'}
   );

print $cgi->end_html;

sub RANDOMCHART{
    my $real_mfe = shift;
    my @values = @_;
    my @sorted = sort {$a <=> $b} @values;

    my $min = sprintf("%+d",$sorted[0])-4;
    my $max = sprintf("%+d",$sorted[$#sorted])+4;
    my $total_range = sprintf("%d",($max - $min)/2);
    
    #my $num_bins = sprintf( "%d",(2 * (scalar(@values) ** (2/5)))); # bins = floor{ 2 * N^(2/5) }
    my $num_bins = $total_range;
    
    #my $bin_range = sprintf( "%.f", $total_range / $num_bins);
    my $bin_range = 1;
    my @yax = ( 0 );
    my @yax_sums = ( 0 );
    my @xax = ( $min );
    
    for(my $i = 1; $i <= ($num_bins); $i++){
        $xax[$i] = $bin_range * $i * 2 + $min;
        foreach my $val (@values){ $yax_sums[$i]++ if $val < $xax[$i] }
    }
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
            x_label_skip      => 2,
            line_width => 3,
            dclrs => [qw(lblue red)],
            borderclrs => [ qw(black ) ]
            ) or die $graph->error;

    my $gd = $graph->plot(\@data) or die $graph->error;
    
    # THIS NEEDS TO BE UNCOMMENTED
    #my $tempfile = 'temp/graph'.time().'.gif';
    
    # THIS NEEDS TO BE REMOVED.
    my $tempfile = 'temp/graph.gif';
    open(IMG, ">$tempfile") or die $!;
    binmode IMG;
    print IMG $gd->gif;

    return $tempfile;
}