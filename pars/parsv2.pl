#!/usr/bin/env perl
use strict;
use warnings;
use JSON;
use autodie qw(:all);

my $json = new JSON->allow_nonref;
my @files = ("sce_Score.tab");
my %pars_data = ();
foreach my $file (@files) {
    Pars_Read($file);
}
foreach my $orf (keys %pars_data) {
    open(JS, ">json/$orf.json");

    my @json_data = (
		     {label => "score", data => $pars_data{$orf}->{score}},

		     );
    my $json_text = to_json(\@json_data, {utf8 => 1, pretty => 0});
    print JS $json_text;
    close JS;
}

## score at i is:
## (/ (log  (/ (+ 1 (V1 of i+1))   (+ 1 (S1 of i+1))))
##    (log 2))
sub Pars_Score {
    my $v1 = shift;
    my $s1 = shift;
    my @scores = ();

    my @v_scores = @{$v1};
    my @s_scores = @{$s1};
    ## Drop the first values, since each score is of n+1 position
    ## This might want to be changed, lets see...
    shift @v_scores;
    shift @s_scores;
    my $c = 0;  ## The final array index, and position in the orf
    while (@v_scores) {
	my $s_list = shift @v_scores;
	my $v_list = shift @s_scores;
	my $s = $s_list->[1];
	my $v = $v_list->[1];
	my $long_score = (log((($v + 1) / ($s + 1))) / log(2));
	my $short_score = sprintf("%.3f", $long_score);
	$scores[$c] =  [$c , $short_score];
	$c++;
    }
    ## Add a 0 at the end to make sure the arrays all have the same size when graphing.
    $scores[$c] = [$c , 0];
    return(\@scores);
}


sub Pars_Read {
    my $file = shift;
    open(IN, "<$file");
    while (my $line = <IN>) {
	chomp $line;
	my ($orf, $len, $data) = split(/\s+/, $line);
	my @values = split(/\;/, $data);
	my $position = 0;
	my @points = ();
	foreach my $value (@values) {
	    $points[$position] = [$position, $value];
	    $position++;
	}
	$pars_data{$orf}->{score} = \@points;
    }
    close(IN);
}
