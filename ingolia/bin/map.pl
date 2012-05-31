#!/usr/bin/perl
use warnings;
use strict;
use autodie qw":all";
use JSON;

my $offset = 751 - 393;

my @positions = ();
for my $c (0 .. 1060) {
    $positions[$c] = 0;
}

open(IN, "<test_out");
while (my $line = <IN>) {
    chomp $line;
    my @datum = split(/\s+/, $line);
    my $start = $datum[3] - $offset + 15;  ## 15 for the A site
    next if ($start > 1059);
    $positions[$start]++;
}

my @json_positions = ();
for my $c (0 .. $#positions) {
    $json_positions[$c] = [$c, $positions[$c]];
}

open(OUT, ">ccr.json");
my @hits = (
    {label => "hits", data => \@json_positions }
    );
my $hits_json_text = to_json(\@hits, {utf8 => 1, pretty => 0});
print OUT $hits_json_text;
close OUT;






my $p1 = Count(0, 99);
my $p2 = Count(100, 199);
my $p3 = Count(200, 299);
my $p4 = Count(300, 399);
my $p5 = Count(400, 499);
my $p6 = Count(500, 599);
my $p7 = Count(600, 699);
my $p8 = Count(700, 799);
my $p9 = Count(800, 899);
my $p10 = Count(900, 999);
my $p11 = Count(1000, 1099);
#my $pre_1200 = Count(1000, 1199);

my $ten = Count(390, 410);
print "The few bases right in front of the -1 PRF signal: $ten->[0] $ten->[1] $ten->[2] $ten->[3]\n";
my $twe = Count(411, 430);
print "The few bases right after the -1 PRF signal: $twe->[0] $twe->[1] $twe->[2] $twe->[3]\n";
my $tw = Count(431, 450);
print "The few bases right after the -1 PRF signal: $tw->[0] $tw->[1] $tw->[2] $tw->[3]\n";

sub Count {
    my $start = shift;
    my $end = shift;
    my $ret = 0;
    my $zerof = 0;
    my $p1f = 0;
    my $m1f = 0;
    for my $c ($start .. $end) {
        if (($c % 3) == 0) {
            $zerof = $zerof + $positions[$c];
        } elsif ((($c + 1) % 3) == 0) {
            $p1f = $p1f + $positions[$c];
        } else {
            $m1f = $m1f + $positions[$c];
        }
        $ret = $ret + $positions[$c];
    }
    return([$ret, $zerof, $p1f, $m1f]);
}

format STDOUT =
@<<<<<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<
"Start po" "0" "100" "200" "300" "400" "500" "600" "700" "800" "900" "1000"
@<<<<<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<
"Total"    $p1->[0] $p2->[0] $p3->[0] $p4->[0] $p5->[0] $p6->[0] $p7->[0] $p8->[0] $p9->[0] $p10->[0] $p11->[0]
@<<<<<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<
"0 frame"   $p1->[1] $p2->[1] $p3->[1] $p4->[1] $p5->[1] $p6->[1] $p7->[1] $p8->[1] $p9->[1] $p10->[1] $p11->[1]
@<<<<<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<
"-1 frame"  $p1->[2] $p2->[2] $p3->[2] $p4->[2] $p5->[2] $p6->[2] $p7->[2] $p8->[2] $p9->[2] $p10->[2] $p11->[2]
@<<<<<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<  @<<<
"+1 frame"  $p1->[3] $p2->[3] $p3->[3] $p4->[3] $p5->[3] $p6->[3] $p7->[3] $p8->[3] $p9->[3] $p10->[3] $p11->[3]
.
write;

