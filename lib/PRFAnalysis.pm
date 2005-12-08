package PRFAnalysis;
use strict;
use GD::Graph::bars;
use POSIX;

sub new {
}

my $string_values = "-17.20  -31.80  -26.40  -33.40  -21.50  -20.40  -27.00  -24.90  -34.80  -26.00  -19.00  -24.00  -19.50  -24.20  -22.90  -23.10  -26.10  -26.20  -22.70  -21.00  -24.40  -26.70  -20.70  -26.20  -21.70  -23.20  -23.30  -22.30  -30.30  -19.10  -27.50  -26.60  -30.60  -24.10  -24.20  -28.00  -24.40  -25.60  -22.00  -23.00  -29.40  -21.80  -29.20  -21.60  -19.30  -20.10  -21.10  -24.00  -25.70  -34.10  -22.30  -19.30  -16.40  -20.60  -23.90  -32.20  -25.00  -21.50  -24.00  -22.90  -23.90  -25.70  -24.20  -28.20  -27.20  -21.00  -27.60  -24.70  -22.20  -24.90  -24.70  -24.40  -24.70  -22.40  -21.00  -18.80  -28.30  -24.00  -20.80  -24.80  -24.30  -18.20  -30.50  -22.00  -26.00  -23.20  -31.10  -23.60  -18.60  -28.80  -21.40  -23.80  -24.20  -24.30  -21.50  -20.20  -26.40  -18.50  -25.60  -18.90";


my @values = split(/\s+/, $string_values);

#@data = (
#	 ["1st","2nd","3rd","4th","5th","6th","7th", "8th", "9th"],
#	 [    1,    2,    5,    6,    3,  1.5,    1,     3,     4],
#	 [ sort { $a <=> $b } (1, 2, 5, 6, 3, 1.5, 1, 3, 4) ]
#	 );
#my $a;
#my $b;
my @sorted = sort {$a cmp $b} @values;
my $smallest = $sorted[0];
my $largest = $sorted[$#sorted];
my $total_range = $largest - $smallest;
my $num_bins = 20;
my $bin_range = $total_range / $num_bins;
#my $bin_range = $largest / $num_bins;
print "TESTME: range: $smallest - $largest  $bin_range\n";
my @num_per_bin = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
my @x_axis =      (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
my $current_bin = $smallest;
my $next_bin = $smallest + $bin_range;
my $count = 1.0;
for my $c (0 .. $#num_per_bin) {
    $x_axis[$c] = $current_bin;
    foreach my $datum (@sorted) {
	if ($datum gt $current_bin and $datum le $next_bin) {
	    $num_per_bin[$c] = $num_per_bin[$c] + 1;
	}
    }
    $current_bin = $next_bin;
    $next_bin = $current_bin + $bin_range;
}
print "@num_per_bin\n";
my @num_per_bin_sorted = sort {$a <=> $b} @num_per_bin;
my $max_y = $num_per_bin_sorted[$#num_per_bin_sorted];
$max_y = POSIX::ceil($max_y * 1.1);
my $max_x = POSIX::ceil(abs($largest));
my $min_x = POSIX::floor(abs($smallest));
print "TESTME: $min_x $max_x\n";


my @data = (
	    \@x_axis,
	    \@num_per_bin,
	    );
my $graph = GD::Graph::bars->new(600, 600);
$graph->set(
	    x_number_format   => \&x_format,
	    x_label           => 'MFE (Kcal/mol)',
	    y_label           => 'Number of replicates/bin',
	    title             => 'Randomization of yeast SIS1 (S0004952)',
	    y_max_value       => $max_y,
	    y_tick_number     => $max_y,
	    y_label_skip      => 0,
	    x_labels_vertical => 1,
	    ) or die $graph->error;
my $gd = $graph->plot(\@data) or die $graph->error;
open(IMG, '>file.gif') or die $!;
binmode IMG;
print IMG $gd->gif;

	    
sub x_format {
    my $value = shift;
    return (sprintf("%.3f", abs($value)));
}

1;
