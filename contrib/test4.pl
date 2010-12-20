#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use lib "$ENV{PRFDB_HOME}/usr/lib/perl5";
use lib "$ENV{PRFDB_HOME}/lib";
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile Callstack Cleanup";
use GD::Graph::histogram;

$config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
$SIG{INT} = \&PRFdb::Cleanup;

my @knot = ('0','1');
my @species = ('saccharomyces_cerevisiae','homo_sapiens','haloarcula_marismortui');
my @algos = ('hotknots','nupack','pknots');
my @graph_types = ('percentage','number');
my @slipsites = ('AAAAAAA','AAAAAAC','AAAAAAT','AAATTTA','AAATTTC','AAATTTT',
		 'CCCAAAA','CCCAAAC','CCCAAAT','CCCTTTA','CCCTTTC','CCCTTTT',
		 'GGGAAAA','GGGAAAC','GGGAAAT','GGGTTTA','GGGTTTC','GGGTTTT',
		 'TTTAAAA','TTTAAAC','TTTAAAT','TTTTTTA','TTTTTTC','TTTTTTT',
		 );
my @types = ('mfe','boot');
foreach my $type (@types) {
    foreach my $spec (@species) {
	foreach my $algo (@algos) {
	    foreach my $site (@slipsites) {
		foreach my $kn (@knot) {
		    foreach my $gt (@graph_types) {
			Make_Graph($spec,$algo,$site,$kn,$type,$gt);
		    }
		}
	    }
	}
    }
}

sub Make_Graph {
    my $spec = shift;
    my $algo = shift;
    my $site = shift;
    my $knot = shift;
    my $type = shift;
    my $gtyp = shift;
    my $color;
    if ($knot eq '1') {
	$color = 'green';
    } else {
	$color = 'red';
    }

    my $y_max = 10.0;
    if ($gtyp ne 'percentage') {
	$y_max = 2000;
    }
    my $output_file = qq"hist-${spec}-${algo}-${site}-${knot}-${type}-${gtyp}.png";
    my $table = "${type}_${spec}";
    my $stmt = qq"SELECT accession,start,mfe FROM $table WHERE algorithm = '$algo' AND seqlength = '100' AND knotp = '$knot'";
    my $mfe_values = $db->MySelect($stmt);
    my $num_mfe = $#$mfe_values;
    my %score;
    my %score_list;
    my @mfe_hist;
    my @z_hist;
    for my $c (0 .. $num_mfe) {
	my $accession = $mfe_values->[$c]->[0];
	my $start = $mfe_values->[$c]->[1];
	my $mfe = $mfe_values->[$c]->[2];
	my $short_mfe = int($mfe);
	push(@mfe_hist, $mfe);
	$score{$accession}{$start}{mfe} = $mfe;
	$score{$accession}{$start}{mfe_score} = ($c / $num_mfe);
	my @tmp;
	my $string = qq"${accession}_${start}";
	if (defined($score_list{$short_mfe})) {
	    @tmp = @{$score_list{$short_mfe}};
	    push(@tmp, $string);
	    $score_list{mfe}{$short_mfe} = \@tmp;
	} else {
	    $score_list{mfe}{$short_mfe} = [ $string , ];
	}    
    }
    my $graph = new GD::Graph::histogram(1600,800);
    $graph->set(
		title => 'A Simple Count Histogram Chart',
		histogram_type => $gtyp,
		histogram_bins => '50',
		x_label => 'X Label',
		x_labels_vertical => 1,
		bar_spacing => 0,
		shadow_depth => 0,
		transparent => 0,
		y_label => 'MFE Count',
		y_max_value => $y_max,
		dclrs => [ $color, ],
		) or warn $graph->error;
    my $gd = $graph->plot(\@mfe_hist) or die $graph->error;
    open(IMG, ">histograms/$output_file") or die $!;
    binmode IMG;
    print IMG $gd->png;
}
