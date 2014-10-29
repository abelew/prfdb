package PRFGraph;
use strict;
use constant PI => scalar(4 * atan2 1, 1);
use DBI;
use PRFConfig qw / PRF_Error PRF_Out /;
use PRFdb qw / Callstack /;
use GD::Graph::mixed;
use GD::Graph::lines;
use GD::Graph::bars;
use GD::Graph::hbars;
use GD::SVG;
use Statistics::Basic qw(:all);
use Statistics::Distributions;
use SVG::TT::Graph::Line;
use SVG::TT::Graph::Pie;
use JSON;
use vars qw ($VERSION);
use File::Temp;
use File::Basename;
use Switch;
$VERSION='20111119';

my $config;

sub new {
    my $class = shift;
    my %arg = @_;
    if (defined($arg{config})) {
	$config = $arg{config};
    }
    my $me = bless {}, $class;
    foreach my $key (%arg) {
	$me->{$key} = $arg{$key} if (defined($arg{$key}));
    }
    $me->{graph_font_size} = 14;
    return ($me);
}

sub deg2rad {PI * $_[0] / 180}

sub Graph_Agreement {
    my $me = shift;
    my $db = new PRFdb(config => $config);
    my $data = $db->MySelect(statement => qq"SELECT all_agree,no_agree,n_alone,h_alone,p_alone,hplusn,nplusp,hplusp,hnp FROM agree WHERE length = '100'");
    my (@all_agree, @no_agree, @n_alone, @h_alone, @p_alone, @hplusn, @nplusp, @hplusp, @hnp_arr);
    my @axis = ();
    foreach my $n (0 .. 100) {
	push(@axis, $n);
    }
    foreach my $datum (@{$data}) {
	my ($all, $no, $n, $h, $p, $hn, $np, $hp, $hnp) = @{$datum};
	foreach my $num (0 .. 100) {
	    switch ($num) {
		case { $num == $all } {
		    ($all_agree[$num]) ? $all_agree[$num] = $all_agree[$num]++ : $all_agree[$num] = 1;
		}
		case { $num == $no } {
		    ($no_agree[$num]) ? $no_agree[$num] = $no_agree[$num]++ : $no_agree[$num] = 1;
		}
		case { $num == $n } {
		    ($n_alone[$num]) ? $n_alone[$num] = $n_alone[$num]++ : $n_alone[$num] = 1;
		}
		case { $num == $p } {
		    ($p_alone[$num]) ? $p_alone[$num] = $p_alone[$num]++ : $p_alone[$num] = 1;
		}
		case { $num == $h } {
		    ($h_alone[$num]) ? $h_alone[$num] = $h_alone[$num]++ : $h_alone[$num] = 1;
		}
		case { $num == $hn } {
		    ($hplusn[$num]) ? $hplusn[$num] = $hplusn[$num]++ : $hplusn[$num] = 1;
		}
		case { $np == $num } {
		    ($nplusp[$num]) ? $nplusp[$num] = $nplusp[$num]++ : $nplusp[$num] = 1;
		}
		case { $hp == $num } {
		    ($hplusp[$num]) ? $hplusp[$num] = $hplusp[$num]++ : $hplusp[$num] = 1;
		}
		case { $hnp == $num } {
		    ($hnp_arr[$num]) ? $hnp_arr[$num] = $hnp_arr[$num]++ : $hnp_arr[$num] = 1;
		}
	    } ## End switch

#	    if ($all == $num) {
#		($all_agree[$num]) ? $all_agree[$num] = $all_agree[$num]++ : $all_agree[$num] = 1;
#	    }
#	    elsif ($no == $num) {
#		($no_agree[$num]) ? $no_agree[$num] = $no_agree[$num]++ : $no_agree[$num] = 1;
#	    }
#	    elsif ($n == $num) {
#		($n_alone[$num]) ? $n_alone[$num] = $n_alone[$num]++ : $n_alone[$num] = 1;
#	    }
#	    elsif ($p == $num) {
#		($p_alone[$num]) ? $p_alone[$num] = $p_alone[$num]++ : $p_alone[$num] = 1;
#	    }
#	    elsif ($h == $num) {
#		($h_alone[$num]) ? $h_alone[$num] = $h_alone[$num]++ : $h_alone[$num] = 1;
#	    }
#	    elsif ($hn == $num) {
#		($hplusn[$num]) ? $hplusn[$num] = $hplusn[$num]++ : $hplusn[$num] = 1;
#	    }
#	    elsif ($np == $num) {
#		($nplusp[$num]) ? $nplusp[$num] = $nplusp[$num]++ : $nplusp[$num] = 1;
#	    }
#	    elsif ($hp == $num) {
#		($hplusp[$num]) ? $hplusp[$num] = $hplusp[$num]++ : $hplusp[$num] = 1;
#	    }
#	    elsif ($hnp == $num) {
#		($hnp_arr[$num]) ? $hnp_arr[$num] = $hnp_arr[$num]++ : $hnp_arr[$num] = 1;
#	    }
	}
    }
    print "
ALL: @all_agree
NO: @no_agree
N: @n_alone
H: @h_alone
P: @p_alone
HN: @hplusn
HP: @hplusp
NP: @nplusp
";
    my $g = new GD::Graph::mixed('400','400');
    $g->set(bgclr => 'white', y_label => 'Accessions Agreed', x_label_skip => 5, x_label => 'Number Agreed', default_type => 'lines',) or Callstack(die => 0, message => $g->error);
    my $ext_g = $g->plot(\@axis, \@all_agree, \@n_alone, \@h_alone, \@p_alone, \@hplusn, \@hplusp, \@hnp_arr) or Callstack(die => 1, message => $g->error);
    open(IMG, ">/tmp/test.png");
    binmode IMG;
    print IMG $ext_g->png;
    close IMG;
}

sub Make_Extension {
    my $me = shift;
    my $species = shift;
    my $filename = shift;
    my $type = shift;
    my $url_base = shift;
    $species = 'saccharomyces_cerevisiae' unless (defined($species));
    my $db = new PRFdb(config => $config);
    ## UNDEF VALUES this statement is pulling up undefined values...
    my $averages = qq"SELECT avg_mfe, avg_zscore, stddev_mfe, stddev_zscore FROM stats WHERE species = '$species' AND seqlength = '100' AND mfe_method = 'nupack'";
    my $averages_fun = $db->MySelect(statement => $averages, type => 'row');
    if (!defined($averages_fun->[0])) {
	my $data = {
	    species => [ $species ,],
	    seqlength => $config->{seqlength},
	    max_mfe => [ $config->{max_mfe} ],
	    mfe_method => $config->{mfe_methods},
	};
	$db->Put_Stats($data);
	$averages_fun = $db->MySelect(statement => $averages, type => 'row');
    }
    my $avg_mfe = $averages_fun->[0];
    my $avg_zscore = $averages_fun->[1];
    my $mfe_minus_stdev = $avg_mfe - $averages_fun->[2];
    my $zscore_minus_stdev = $avg_zscore - $averages_fun->[3];
    if (!defined($avg_mfe)) {
	
    }
    my $radius = 4;
    my $graph = new GD::Graph::points('800','800');
    $graph->set(bgclr => 'white');
    if ($type eq 'percent') {
	$graph->set(y_max_value => 150);
	$graph->set(y_label => '-1 frame extension in percent');
    }
    elsif ($type eq 'codons') {
	$graph->set(y_max_value => 200);
	$graph->set(y_label => '-1 frame extension in codons');
    }
    else {
	$graph->set(y_max_value => 200);
	$graph->set(y_label => 'testme');
    }
    $graph->set(x_label => 'Percentage ORF');
    $graph->set(y_min_value => 0);
    $graph->set(y_ticks => 1);
    $graph->set(y_tick_number => 10);
    $graph->set(y_tick_offset => 2);
    $graph->set(y_label_skip => 2);
    $graph->set(x_min_value => 0);
    $graph->set(x_max_value => 100);
    $graph->set(x_ticks => 1);
    $graph->set(x_tick_number => 25);
    $graph->set(x_label_skip => 2);
    $graph->set(x_tick_offset => 2);
    $graph->set(markers => [7,7]);
    $graph->set(marker_size => 0);
    $graph->set(bgclr => 'white');
    $graph->set(dclrs => [qw(black black)]);
    $graph->set_legend_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $me->{graph_font_size});
    $graph->set_x_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $me->{graph_font_size});
    $graph->set_x_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $me->{graph_font_size});
    $graph->set_y_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $me->{graph_font_size});
    $graph->set_y_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $me->{graph_font_size});
#    my $fun = [[0,0,0,[0,0,0]];
    my $fun = [[0,0,0],[0,100,0]];
    my $gd = $graph->plot($fun) or Callstack(die => 0, message => "Line 149" , $graph->error);
    my $black = $gd->colorResolve(0,0,0);
    my $red = $gd->colorResolve(191,0,0);
    my $green = $gd->colorResolve(0,191,0);
    my $blue = $gd->colorResolve(0,0,191);
    my $gb = $gd->colorResolve(0,97,97);
    my $darkslategray = $gd->colorResolve(165,165,165);
    my $axes_coords = $graph->get_feature_coordinates('axes');
    # print "@{$axes_coords}\n";
    my $left_x_coord = $axes_coords->[1];
    my $top_y_coord = $axes_coords->[2];
    my $right_x_coord = $axes_coords->[3];
    my $bottom_y_coord = $axes_coords->[4];
    my $x_range = ($right_x_coord - $left_x_coord);
    my $y_range = $top_y_coord - $bottom_y_coord;
    my $mt = "mfe_$species";
    my $stmt = qq"SELECT DISTINCT ${mt}.id, ${mt}.accession, ${mt}.start, genome.orf_start, genome.orf_stop, genome.mrna_seq, ${mt}.bp_mstop, ${mt}.mfe FROM genome,$mt WHERE genome.id = ${mt}.genome_id AND ${mt}.seqlength='100' AND ${mt}.mfe_method = 'nupack'";
    my $stuff = $db->MySelect(statement => $stmt,);
    
    open(MAP, ">${filename}.map") or Callstack(message => qq"Unable to open the map file ${filename}.map");
    my $map_string = '';
    if ($type eq 'percent') {
	$map_string = qq/<map name="percent_extension" id="percent_extension">\n/;
    }
    elsif ($type eq 'codons') {
	$map_string = qq/<map name="codons_extension" id="codons_extension">\n/;
    }
    else {
	$map_string = "uhh what?\n";
    }
    print MAP $map_string;
    ## $extension_distribution is intended to hold a distribution of how many -1 frame extensions
    ## reach to x codons
    ## $orf_distribution counts how many are found at each x percent down the orf from 0 to 100
    my $extension_distribution = [];
    my $orf_distribution = [];
    my $long_orf_distribution = [];

    foreach my $datum (@{$stuff}) {
	my $mfeid = $datum->[0];
	my $accession = $datum->[1];
	my $start = $datum->[2];
	my $orf_start = $datum->[3];
	my $orf_stop = $datum->[4];
	my $mrna_sequence = $datum->[5];
	my $bp_minus_stop = $datum->[6];
	my $mfe = $datum->[7];
	my $zscore_stmt = qq"SELECT zscore from boot_$species where mfe_id = '$mfeid'";
	my $zscore = $db->MySelect(statement => $zscore_stmt, type => 'single');
	next if (!defined($zscore));
	my $minus_string = '';
	$mrna_sequence =~ tr/Tt/Uu/;
	my @seq = split(//, $mrna_sequence);
	my $stop_count = 0;
	if (($orf_start % 3) == 0) {
	    $stop_count = 1;
	}
	elsif (($orf_start % 3) == 1) {
	    $stop_count = 2;
	}
	elsif (($orf_start % 3) == 2) {
	    $stop_count = 0;
	}
	else {
	    Callstack(message => "WTF?", die => 1);
	}
	my $minus_start = $start + 4;
	my $codon = '';
#	print "Working on $accession: orf start: $orf_start prf_start: $start at $minus_start\n";	
        LOOP: for my $c ($minus_start .. $#seq) {
	    next if ($c == 3);  ## Hack to make it work
	    if (($c % 3) == $stop_count) {
		if ($codon eq 'UAG' or $codon eq 'UAA' or $codon eq 'UGA' or
		    $codon eq 'uag' or $codon eq 'uaa' or $codon eq 'uga') {
		    $minus_string .= $codon;
		    last LOOP;
		}
		else {
		    $minus_string .= $codon;
		}
		$codon = $seq[$c];
		## if on a third base of the -1 frame
	    }
	    else {
		$codon .= $seq[$c];
	    }
	} ## Foreach character of the sequence
	my $x_percentage = sprintf("%.2f", 100.0 * ($start - $orf_start) / ($orf_stop - $orf_start));

	## start is mfe.start orf_start is genome.orf_start
#	print "x_percentage:$x_percentage $accession 100 * ($start - $orf_start) / ($orf_stop - $orf_start))<br>\n";
	my $x_coord = sprintf("%.2f", ((($x_range / 100) * $x_percentage) + $left_x_coord));

	my $extension_length = length($minus_string);
	my $minus_codons = ($extension_length / 3);

	## Fill out $orf_distribution here
	my $x_percent_int = int($x_percentage);
	if ($minus_codons > 30) {
	    if ($long_orf_distribution->[$x_percent_int]) {
		my $tmp = $long_orf_distribution->[$x_percent_int];
		$tmp++;
		$long_orf_distribution->[$x_percent_int] = $tmp;
	    }
	    else {
		$long_orf_distribution->[$x_percent_int] = 1;
	    }
	}

	if ($orf_distribution->[$x_percent_int]) {
	    my $tmp = $orf_distribution->[$x_percent_int];
	    $tmp++;
	    $orf_distribution->[$x_percent_int] = $tmp;
	}
	else {
	    $orf_distribution->[$x_percent_int] = 1;
	}
	## Make a graph of the distribution of these extensions right quick...
	my $minus_modified = $minus_codons / 5;
	$minus_modified = int($minus_codons);
	if ($extension_distribution->[$minus_modified]) {
	    my $tmp = $extension_distribution->[$minus_modified];
	    $tmp++;
	    $extension_distribution->[$minus_modified] = $tmp;
	}
	else {
	    $extension_distribution->[$minus_modified] = 1;
	}
	## That fills out the $extension_distribution array

	my $minus_codons_pixels = $minus_codons * 4;
	my $codons_y_coord = sprintf("%.2f", ($y_range - $minus_codons_pixels) + $bottom_y_coord);
	my $y_percentage = sprintf("%.2f", 100.0 * (($extension_length + $start) - $orf_start) / ($orf_stop - $orf_start));
	$y_percentage = 150 if ($y_percentage > 150);
	my $percent_y_coord = sprintf("%.2f", ((($y_range / 150) * (150 - $y_percentage)) + $bottom_y_coord));
	my $map_percent_y_coord = sprintf("%.2f", ((($y_range / 150) * (150 - $y_percentage)) + $bottom_y_coord));
#y_codons: minus_codons:$minus_codons  codons_coord:$codons_y_coord<br>
#y_percent: y_percentage:$y_percentage percent_y_coord:$percent_y_coord<br>\n";

	if (!defined($bp_minus_stop)) {
	    my $stmt = qq"UPDATE mfe_$species SET bp_mstop = '$extension_length' WHERE id = '$mfeid'";
	    $db->MyExecute($stmt);
	}
	my $color;
	## UNDEF VALUES HERE
#	sleep 1;
	if (($mfe < $avg_mfe) and ($zscore > $avg_zscore)) {
	    ## Red
	    $color = $gd->colorResolve(191,0,0); 
	}
	elsif ($mfe < $avg_mfe) {
	    ## Green, I think
	    $color = $gd->colorResolve(0,191,0);
	}
	elsif ($zscore > $avg_zscore) {
	    ## Blue?
	    $color = $gd->colorResolve(0,0,191);
	}
	else {
	    ## Gray?
	    $color = $gd->colorResolve(165,165,165);
	}
	my $url = qq"/search.html?short=1&accession=$accession";

	
	if ($type eq 'percent') {
#	    if (!defined($zscore)) {
#		sleep 10;
#	    }
	    $map_string = qq/<area shape="circle" coords="${x_coord},${percent_y_coord},$radius" href="${url}" title="$accession, mfe:$mfe z:$zscore xpercent:$x_percentage ypercent:$y_percentage">\n/;
	    $gd->filledArc($x_coord, $percent_y_coord, 4,4,0,360,$color,4);
	}
	elsif ($type eq 'codons') {
	    $minus_codons = sprintf("%.1f", $minus_codons);
	    $map_string = qq/<area shape="circle" coords="${x_coord},${codons_y_coord},$radius" href="${url}" title="$accession mfe:$mfe z:$zscore xpercent:$x_percentage ycodons:$minus_codons">\n/;
#	    print "Percent: xcoord: $x_coord xcoord: $codons_y_coord<br>\n";
	    $gd->filledArc($x_coord, $codons_y_coord, 4,4,0,360,$color,4);
	}
	else {
	    Callstack(message => "Type is not specified", die => 1);
	}
	print MAP $map_string;
    }  ## End foreach datum in stuff

    my ($max_exts, $max_orfs) = 0;
    if ($type eq 'codons') {
	my @ext_axis = ();
	my @ext_vals = ();
	foreach my $c (0 .. $#$extension_distribution) {
	    last if ($c == 100);
	    if ($extension_distribution->[$c]) {
		$max_exts = $extension_distribution->[$c] if ($max_exts < $extension_distribution->[$c]);
		$ext_vals[$c] = $extension_distribution->[$c];
	    }
	    else {
		$ext_vals[$c] = 1;
	    }
	    push(@ext_axis, $c);
	}
	$max_exts = 100 if ($max_exts < 100);
	my @e_data = (\@ext_axis, \@ext_vals);
	my $egraph = new GD::Graph::mixed('400','400');
	$egraph->set_legend_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", 14);
	$egraph->set_x_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", 14);
	$egraph->set_x_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}",14);
	$egraph->set_y_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", 14);
	$egraph->set_y_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}",14);
	my $max_exts_y_value = $max_exts + 10;
	while (($max_exts_y_value % 20) != 0) {
	    $max_exts_y_value++;
	}
	$egraph->set(bgclr => 'white',
		     y_max_value => $max_exts_y_value,
		     y_label => 'Number extensions',
		     x_label_skip => 25,
		     x_label => 'Length',
                     line_width => 3,
		     default_type => 'lines',
		     types => [qw(lines)],) or Callstack(die => 0, message => $egraph->error);
	my $ext_gd = $egraph->plot(\@e_data) or Callstack(die => 1, message => $egraph->error);
	my $codons_y_thirty_coord = sprintf("%.2f", ($y_range - (30 * 4)) + $bottom_y_coord);
	$ext_gd->filledRectangle($left_x_coord, $codons_y_thirty_coord, $right_x_coord, ($codons_y_thirty_coord + 1), $red);
	my $extension_filename = $filename;
	$extension_filename =~ s/\.png/_extension\.png/g;
	open(EXTIMG, ">$extension_filename") or Callstack(message => qq"error opening file to write extension distribution.", die => 0);
	binmode EXTIMG;
	print EXTIMG $ext_gd->png;
	close EXTIMG;
    }
    else {
	my @orf_axis = ();
	my @orf_vals = ();
	my @long_orf_percent = ();
	foreach my $c (0 .. $#$orf_distribution) {
	    if ($orf_distribution->[$c]) {
		$max_orfs = $orf_distribution->[$c] if ($max_orfs < $orf_distribution->[$c]);
		$orf_vals[$c] = $orf_distribution->[$c];
		$long_orf_percent[$c] = (($long_orf_distribution->[$c] / $orf_distribution->[$c]) * 100.0);
	    }
	    else {
		$orf_vals[$c] = 1;
		$long_orf_percent[$c] = 0;
	    }
	    push(@orf_axis, $c);
	    $max_orfs = 100 if ($max_orfs < 100);
	}
	my @o_data = (\@orf_axis, \@orf_vals, \@long_orf_percent);
	my @o_num_data = (\@orf_axis, \@orf_vals);
	my $y_max_value = $max_orfs + 10;
	while (($y_max_value % 20) != 0) {
	    $y_max_value++;
	}
	my $o_num_graph = new GD::Graph::mixed('400','400');
	$o_num_graph->set_legend_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", 14);
	$o_num_graph->set_x_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", 14);
	$o_num_graph->set_x_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}",14);
	$o_num_graph->set_y_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", 14);
	$o_num_graph->set_y_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}",14);
	$o_num_graph->set(dclrs => [qw(blue)]);
	$o_num_graph->set(bgclr => 'white',
		     y_label => 'Number Extensions',
		     x_label_skip => 20,
		     x_label => 'Percent ORF',
		     line_width => 3,
		     default_type => 'lines',
		     types => [qw(lines lines)],
		     y_max_value => $y_max_value,
		     ) or Callstack(die => 1, message => $o_num_graph->error);
	my $orf_num_gd = $o_num_graph->plot(\@o_num_data) or Callstack(die => 1, message => $o_num_graph->error);
	my $orf_num_filename = $filename;
	$orf_num_filename =~ s/\.png/_orf_num\.png/g;
	open(ORFNUMIMG, ">$orf_num_filename") or Callstack(message => qq"error opening file to write orf distribution.", die => 0);
	binmode ORFNUMIMG;
	print ORFNUMIMG $orf_num_gd->png;
	close ORFNUMIMG;

	my @o_pct_data =(\@orf_axis, \@long_orf_percent);
	my $o_pct_graph = new GD::Graph::mixed('400','400');
	$o_pct_graph->set_legend_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", 14);
	$o_pct_graph->set_x_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", 14);
	$o_pct_graph->set_x_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}",14);
	$o_pct_graph->set_y_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", 14);
	$o_pct_graph->set_y_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}",14);
	$o_pct_graph->set(dclrs => [qw(black)]);
	$o_pct_graph->set(bgclr => 'white',
		     y_label => 'Percent Long Extensions',
		     x_label_skip => 20,
		     x_label => 'Percent ORF',
		     line_width => 3,
		     default_type => 'lines',
		     types => [qw(lines lines)],
		     y_max_value => 80,
		     ) or Callstack(die => 1, message => $o_pct_graph->error);
	my $orf_pct_gd = $o_pct_graph->plot(\@o_pct_data) or Callstack(die => 1, message => $o_pct_graph->error);
	my $orf_pct_filename = $filename;
	$orf_pct_filename =~ s/\.png/_orf_pct\.png/g;
	open(ORFPCTIMG, ">$orf_pct_filename") or Callstack(message => qq"error opening file to write orf distribution.", die => 0);
	binmode ORFPCTIMG;
	print ORFPCTIMG $orf_pct_gd->png;
	close ORFPCTIMG;


	my $ograph = new GD::Graph::mixed('400','400');
#	$ograph->set_legend([qw"Num ORFs, Pct long"]);
	$ograph->set(bgclr => 'white',
		     y1_label => 'Number Extensions',
		     y2_label => 'Percent Long Extensions',
		     x_label_skip => 5,
		     two_axes => 1,
		     x_label => 'Percent ORF',
		     y2_min_value => 0,
		     line_width => 3,
		     y2_max_value => 100,  ## I got a weird error 'Maximum for y2 too small'  this is the only place I can guess for it.
		     default_type => 'lines',
		     types => [qw(lines lines)],
		     y1_min_value => 0,
		     y1_max_value => ($max_orfs + 10),
		     ) or Callstack(die => 1, message => $ograph->error);
	my $orf_gd = $ograph->plot(\@o_data) or Callstack(die => 1, message => $ograph->error);
	my $extension_filename = $filename;
	$extension_filename =~ s/\.png/_orf\.png/g;
	open(ORFIMG, ">$extension_filename") or Callstack(message => qq"error opening file to write orf distribution.", die => 0);
	binmode ORFIMG;
	print ORFIMG $orf_gd->png;
	close ORFIMG;
    }

    open(IMG, ">$filename") or Callstack(message => qq"error opening file to write image", die => 1);
    binmode IMG;
    print IMG $gd->png;
    close IMG;
    print MAP "</map>\n";
    close MAP;
    system("/usr/bin/uniq ${filename}.map > ${filename}.tmp  ;  /bin/mv ${filename}.tmp ${filename}.map");
}

sub Make_Summary_Pie {
    my $me = shift;
    my $filename = shift;
    my $width = shift;
    my $height = shift;
    my $species = shift;
    my $slipsite = shift;
    my $seqlength = shift;
    my $mfe_method = shift;
    my $info_stmt = '';
    my $db = new PRFdb(config=>$config);
#    if ($slipsite eq 'all') {
    $info_stmt = qq"SELECT * FROM stats WHERE species = '$species' AND seqlength = '$seqlength' AND mfe_method = '$mfe_method'";
    my $info = $db->MySelect(type => 'list_of_hashes', statement => $info_stmt);
    foreach my $datum (@{$info}) {
	my %inf = %{$datum};
	my @fields = ('No match', 'Insignificant', 'Significant');
	my $no_match = $inf{total_genes} - $inf{genes_hits};
	my $insignificant = $inf{total_genes} - $inf{genes_1both_knotted};
	my $significant = $inf{genes_1both_knotted};
	my @data = ($no_match, $insignificant, $significant);
	my $graph = SVG::TT::Graph::Pie->new({
           height => '800',
           width  => '800',
           fields => \@fields,
	   tidy => 1,
	   show_shadow => 1,
	   shadow_size => 10,
	   shadow_offset => 15,
	   show_data_labels => 1,
	   show_actual_values => 1,
	   show_percent => 1,
	   rollover_values => 1,
	   # data on key:
	   show_key_data_labels => 1,
	   show_key_actual_values => 1,
	   show_key_percent => 1,
	   expanded => 0,
	   expand_smallest => 1,
	   key => 1,
	   key_placement => 'R',
       });
	$graph->compress(0);
	$graph->add_data({
           'data'  => \@data,
           'title' => 'Significant hits',
       });
	open(OUT, ">$filename");
#	print OUT "Content-type: image/svg+xml\n\n";
	print OUT $graph->burn();
	close OUT;
    }
}

sub Make_Cloud {
    my $me = shift;
    my %args = @_;
    my $species = $args{species};
    my $data = $args{points};
    my $averages = $args{averages};
    my $filename = $args{filename};
    my $url = $args{url};
    my $args_slipsites = $args{slipsites};
    my $args_mfe_methods = $args{mfe_methods};
    my $seqlength;
    if (defined($args{seqlength})) {
	$seqlength = $args{seqlength};
    } else {
	$seqlength = 100;
    }
    my $pknot = undef;
    if (defined($args{pknot}) and $args{pknot} == 1) {
	$pknot = 1;
    }
    my $mt = "mfe_$species";
    my $graph = new GD::Graph::points('800','800');
    my $db = new PRFdb(config => $config);
    my ($mfe_min_value, $mfe_max_value);
    my $min_stmt = qq"SELECT min(mfe) FROM $mt ";
    my $max_stmt = qq"SELECT max(mfe) FROM $mt ";
    if ($args_mfe_methods ne 'all') {
	if ($args_mfe_methods eq 'nupack+hotknots') {
	    $min_stmt .= " WHERE mfe_method = 'nupack' OR mfe_method = 'hotknots'";
	    $max_stmt .= " WHERE mfe_method = 'nupack' OR mfe_method = 'hotknots'";
	}
	elsif ($args_mfe_methods eq 'nupack') {
	    $min_stmt .= " WHERE mfe_method = 'nupack'";
	    $max_stmt .= " WHERE mfe_method = 'nupack'";
	}
	elsif ($args_mfe_methods eq 'hotknots') {
	    $min_stmt .= " WHERE mfe_method = 'hotknots'";
	    $max_stmt .= " WHERE mfe_method = 'hotknots'";
	}
	elsif ($args_mfe_methods eq 'pknots') {
	    $min_stmt .= " WHERE mfe_method = 'pknots'";
	    $max_stmt .= " WHERE mfe_method = 'pknots'";
	}
    }
    $mfe_min_value = $db->MySelect(statement => $min_stmt, type => 'single');
    $mfe_max_value = $db->MySelect(statement => $max_stmt, type => 'single');
    unless ($mfe_min_value) {
	$mfe_min_value = -47.0;
    }
    unless ($mfe_max_value) {
	$mfe_max_value = 2.0;
    }
    $mfe_min_value -= 3.0;
    $mfe_max_value += 3.0;
    my $z_min_value = -10.0;
    my $z_max_value = 5.0;
    $graph->set(bgclr => 'white',
		x_min_value => $mfe_min_value,
		x_max_value => $mfe_max_value,
		x_ticks => 1,
		x_label => 'MFE',
		x_labels_vertical => 1,
		x_label_skip => 0,
		x_number_format => "%.1f",
		x_tick_number => 20,
		x_all_ticks => 1,
		y_min_value => $z_min_value,
		y_max_value => $z_max_value,
		y_label => 'Zscore',
		y_label_skip => 0,
		y_number_format => "%.2f",
		y_tick_number => 20,
		dclrs => [qw(black black)],
		marker_size => 0,) or Callstack(die => 0, message =>  $graph->error . " Line 518");
#    $graph->set_y_ticks(1);
#    $graph->set_y_all_ticks(1);
    $graph->set_legend_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    my $fun = [[-100,-100,-100],[0,0,0]];
#    my $gd = $graph->plot($fun,) or Callstack(die => 1, message => $graph->error);
    my $gd = $graph->plot($fun,) or Callstack(die => 0, message => $graph->error . " Line 526");
    my $black = $gd->colorResolve(0,0,0);
    my $green = $gd->colorResolve(0,191,0);
    my $blue = $gd->colorResolve(0,0,191);
    my $gb = $gd->colorResolve(0,97,97);
    my $darkslategray = $gd->colorResolve(165,165,165);
    my $axes_coords = $graph->get_feature_coordinates('axes');
    # print "@{$axes_coords}\n";
    my $left_x_coord = $axes_coords->[1];
    my $top_y_coord = $axes_coords->[2];
    my $right_x_coord = $axes_coords->[3];
    my $bottom_y_coord = $axes_coords->[4];
    my $x_range = $right_x_coord - $left_x_coord;
    my $y_range = $top_y_coord - $bottom_y_coord;
    my $mfe_range = $mfe_max_value - $mfe_min_value;
    my $z_range = $z_max_value - $z_min_value;
    
    my $average_mfe_coord = sprintf("%.1f",((($x_range/$mfe_range)*($averages->[0] - $mfe_min_value)) + $left_x_coord));
    my $average_z_coord = sprintf("%.1f",((($y_range/$z_range)*($z_max_value - $averages->[1])) + $bottom_y_coord));
    my $mfe_significant = $averages->[0] - $averages->[2];
    my $z_significant = $averages->[1] - $averages->[3];
    my $mfe_significant_coord = sprintf("%.1f", ((($x_range/$mfe_range)*($mfe_significant - $mfe_min_value)) + $left_x_coord));
    my $z_significant_coord = sprintf("%.1f",((($y_range/$z_range)*($z_max_value - $z_significant)) + $bottom_y_coord));
    
    my $mfe_2stds_significant = $averages->[0] - ($averages->[2] * 2);
    my $mfe_2stds_significant_coord = sprintf("%.1f", ((($x_range/$mfe_range)*($mfe_2stds_significant - $mfe_min_value)) + $left_x_coord));
    my $z_2stds_significant = $averages->[1] - ($averages->[3] * 2);
    my $z_2stds_significant_coord = sprintf("%.1f",((($y_range/$z_range)*($z_max_value - $z_2stds_significant)) + $bottom_y_coord));
    
    my $points = {};
    my $max_counter = 1;

    my (%mfe_distribution, %z_distribution) = ();
    #Callstack(message => qq"Go to 560?");  ## This one is ok...
    my $cloud_csv_filename = $filename;
    $cloud_csv_filename =~ s/\.png/\.csv/g;
    open(CLOUD_CSV, ">$cloud_csv_filename") or Callstack(die => 0, message => qq"Could not open $cloud_csv_filename. $!");
    ##                                   0   1    2          3          4     5
    ## Structure of each row of @data:  mfe, z, accession, knotp, slipsite, start, genename
##                        0            1         2           3   4       5
    print CLOUD_CSV qq|"accession", "start", "slipsite", "MFE", "Z", "knotted"\n|;
    foreach my $point (@{$data}) {
##                             0            1              2            3              4          5            
	print CLOUD_CSV qq|"$point->[2]","$point->[5]","$point->[4]","$point->[0]","$point->[1]","$point->[3]"\n|;
	my $x_point = sprintf("%.1f",$point->[0]);
	my $y_point = sprintf("%.2f",$point->[1]);
	my $slipsite = $point->[4];
	my $knotted = $point->[3];
	if (defined($z_distribution{$y_point})) {
	    my $t = $z_distribution{$y_point}{total};
	    $t++;
	    $z_distribution{$y_point}{total} = $t;
	    if (defined($z_distribution{$y_point})) {
		my $s = $z_distribution{$y_point}{$slipsite};
		$s++;
		$z_distribution{$y_point}{$slipsite} = $s;
	    }
	    else {
		$z_distribution{$y_point}{$slipsite} = 1;
	    }
	}
	else {
	    $z_distribution{$y_point}{total} = 1;
	    $z_distribution{$y_point}{$slipsite} = 1;
	}


	if (defined($mfe_distribution{$x_point})) {
	    my $t = $mfe_distribution{$x_point}{total};
	    $t++;
	    $mfe_distribution{$x_point}{total} = $t;
	    if (defined($mfe_distribution{$x_point})) {
		my $kn = $mfe_distribution{$x_point}{kno};
		$kn++ if ($knotted == 1);
		$mfe_distribution{$x_point}{kno} = $kn;
	    }
	    else {
		$mfe_distribution{$x_point}{kno} = 1 if ($knotted == 1);
	    }
	}
	else {
	    $mfe_distribution{$x_point}{total} = 1;
	    $mfe_distribution{$x_point}{kno} = 1 if ($knotted == 1);
	}

	#print "MFE_value: $x_point Zscore: $y_point<br>\n";
	if (defined($points->{$x_point}->{$y_point})) {
	    $points->{$x_point}->{$y_point}->{count}++;
	    $points->{$x_point}->{$y_point}->{accessions} .= " $point->[2]";
	    $points->{$x_point}->{$y_point}->{genenames} .= " ; $point->[6]";
	    $points->{$x_point}->{$y_point}->{knotted} += $point->[3];
	    if ($max_counter < $points->{$x_point}->{$y_point}->{count}) {
		$max_counter = $points->{$x_point}->{$y_point}->{count};
	    }
	}
	else {
	    $points->{$x_point}->{$y_point}->{count} = 1;
	    $points->{$x_point}->{$y_point}->{accessions} = $point->[2];
	    $points->{$x_point}->{$y_point}->{genenames} = $point->[6];
	    $points->{$x_point}->{$y_point}->{knotted} = $point->[3];
	    $points->{$x_point}->{$y_point}->{start} = $point->[5];
	}
    }  ## End foreach point in @data
    close(CLOUD_CSV);

    ## Created %z_distribution and %mfe_distribution above, now to make them a graph...
    ## The Z graph should be tall and thin (200x800 perhaps)
    ## MFE graph should be the opposite (800x200)
    my $z_filename = $filename;
    my $mfe_filename = $filename;
    $z_filename =~ s/\.png/\-z_dist\.png/g;
    $mfe_filename =~ s/\.png/\-mfe_dist\.png/g;

    my (@z_keys, @z_values, @mfe_keys, @mfe_values_total, @z_subset, @mfe_subset);
    my (@z_aaa, @z_uuu, @z_ccc, @z_ggg);
    my (@mfe_unk, @mfe_kno);
    
    my $current_z = $z_max_value;
    my $next_z;
    #Callstack(message => qq"Go to 625?");
    while ($current_z >= $z_min_value) {
	$next_z = $current_z - 0.1;
	push(@z_keys, sprintf("%.1f", $current_z));
	my $val = 0;
	my $aaa_val = 0;
	my $uuu_val = 0;
	my $ccc_val = 0;
	my $ggg_val = 0;
	foreach my $k (keys %z_distribution) {
	    if ($k >= $next_z and $k < $current_z) {
		$val = $val + $z_distribution{$k};
		foreach my $slips (keys %{$z_distribution{$k}}) {
		    if ($slips =~ /^AAA/) {
			$aaa_val += $z_distribution{$k}{$slips};
		    }
		    elsif ($slips =~ /^UUU/) {
			$uuu_val += $z_distribution{$k}{$slips};
		    }
		    elsif ($slips =~ /^CCC/) {
			$ccc_val += $z_distribution{$k}{$slips};
		    }
		    elsif ($slips =~ /^GGG/) {
			$ggg_val += $z_distribution{$k}{$slips};
		    }
		} ## End foreach slips
	    }
	}
	push(@z_aaa, $aaa_val);
	push(@z_uuu, $uuu_val);
	push(@z_ccc, $ccc_val);
	push(@z_ggg, $ggg_val);
	push(@z_values, $val);
	$current_z = $next_z;
    } ## End while

    #Callstack(message => qq"Go to 657?");
    my $current_mfe = $mfe_min_value;
    my $next_mfe;
    while ($current_mfe <= $mfe_max_value) {
	$next_mfe = $current_mfe + 0.3;
	push(@mfe_keys, sprintf("%.1f", $current_mfe));
	my $val = 0;
	my $unk = 0;
	my $kno = 0;
	foreach my $k (keys %mfe_distribution) {
	    if ($k <= $next_mfe and $k > $current_mfe) {
		$val += $mfe_distribution{$k}{total};
		$kno += $mfe_distribution{$k}{kno};
	    }
	}
	push(@mfe_kno, $kno);
	push(@mfe_unk, ($val - $kno));
	push(@mfe_values_total, $val);
	$current_mfe = $next_mfe;
    }
    
    my @z_dist = (\@z_keys, \@z_values, \@z_aaa, \@z_uuu, \@z_ggg, \@z_ccc);
    my @mfe_dist = (\@mfe_keys, \@mfe_values_total, \@mfe_unk, \@mfe_kno);
    
    my $json = JSON->new->allow_nonref;
    my @mfe_json = ();
    my (@z_json_aaa, @z_json_uuu, @z_json_ggg, @z_json_ccc) = ();

    for my $c (0 .. $#z_keys) {
	push(@z_json_aaa, [$z_aaa[$c], $z_keys[$c]]);
	push(@z_json_uuu, [$z_uuu[$c], $z_keys[$c]]);
	push(@z_json_ccc, [$z_ccc[$c], $z_keys[$c]]);
	push(@z_json_ggg, [$z_ggg[$c], $z_keys[$c]]);
    }

    my @full_z_json = ({label => "AAA", data => \@z_json_aaa},
		       {label => "UUU", data => \@z_json_uuu},
		       {label => "CCC", data => \@z_json_ccc},
		       {label => "GGG", data => \@z_json_ggg},
		       );
    my $z_json_text = to_json(\@full_z_json, {utf8 => 1, pretty => 0});

    my (@mfe_json_unk, @mfe_json_kno) = ();
    for my $c (0 .. $#mfe_keys) {
	push(@mfe_json_kno, [$mfe_keys[$c], $mfe_kno[$c]]);
	push(@mfe_json_unk, [$mfe_keys[$c], $mfe_unk[$c]]);
    }
    my @full_mfe_json = ({label => "Knotted", data => \@mfe_json_kno},
			 {label => "Unknotted", data => \@mfe_json_unk},
			 );
    my $mfe_json_text = to_json(\@full_mfe_json, {utf8 => 1, pretty => 0});

    my $mfe_json_filename = $mfe_filename;
    $mfe_json_filename =~ s/\.png/\.json/g;
    my $z_json_filename = $z_filename;
    $z_json_filename =~ s/\.png/\.json/g;
    open(MFE_JSON, ">$mfe_json_filename") or Callstack(die=> 0, message => qq"error opening $mfe_json_filename. $!");
    open(Z_JSON, ">$z_json_filename") or Callstack(die => 0, message => qq"error opening $z_json_filename. $!");
    print MFE_JSON $mfe_json_text;
    print Z_JSON $z_json_text;
    close MFE_JSON;
    close Z_JSON;

    my $tmp_filename = $filename;
    
    foreach my $x_point (keys %{$points}) {
	my $x_coord = sprintf("%.1f",((($x_range/$mfe_range)*($x_point - $mfe_min_value)) + $left_x_coord));
	foreach my $y_point (keys %{$points->{$x_point}}) {
	    my $accessions = $points->{$x_point}->{$y_point}->{accessions};
	    my $genenames = $points->{$x_point}->{$y_point}->{genenames};
	    if (!defined($genenames)) {
		$genenames = $accessions;
	    }
	    my $y_coord = sprintf("%.2f",((($y_range/$z_range)*($z_max_value - $y_point)) + $bottom_y_coord));
	    my $counter = $points->{$x_point}->{$y_point}->{count};
	    ## Quadrant Color Code
	    my $color_value = 220 - (220*($counter/$max_counter));
	    my $color = undef;
	    #print "X: $x_coord Y: $y_coord AVGX: $average_mfe_coord AVGY: $average_z_coord CV: $color_value";
	    if (($x_coord < $average_mfe_coord) and ($y_coord > $average_z_coord)) {
		$color = $gd->colorResolve($color_value,0,0);
		# print " C: red<br>\n";
	    }
	    elsif ($x_coord < $average_mfe_coord) {
		$color = $gd->colorResolve(0,$color_value,0);
		# print " C: green<br>\n";
	    }
	    elsif ($y_coord > $average_z_coord) {
		$color = $gd->colorResolve(0,0,$color_value);
		# print " C: blue<br>\n";
	    }
	    elsif (($x_coord > $average_mfe_coord) and ($y_coord < $average_z_coord)) {
		$color = $gd->colorResolve($color_value,$color_value,$color_value);
		# print " C: grey<br>\n";
	    }
	    else {
		$color = $gd->colorResolve(254,191,191);
		# print " C: pink<br>\n";
	    }
	    # $gd->filledRectangle($x_coord-1, $y_coord-1, $x_coord+1, $y_coord+1, $color);
	    $gd->filledArc($x_coord, $y_coord, 4, 4, 0, 360, $color, 4);
	    $x_coord = sprintf('%.0f', $x_coord);
	    $y_coord = sprintf('%.0f', $y_coord);
	    my $image_map_string;
	} ## Foreach y point
    } ## Foreach x point
    my $radius = 1;
    my @all_slipsites = ('AAAAAAA','AAAAAAU','AAAAAAC','AAAUUUA','AAAUUUU','AAAUUUC',
			 'UUUUUUA','UUUUUUU','UUUUUUC','UUUAAAA','UUUAAAU','UUUAAAC',
			 'GGGAAAA','GGGAAAU','GGGAAAC','GGGUUUA','GGGUUUU','GGGUUUC',
			 'CCCAAAA','CCCAAAU','CCCAAAC','AAAUUUA','CCCUUUU','CCCUUUC',
			 ## Theoretically non-allowed slipsites here
#			 'AAAAAAG','UUUUUUG','AAAUUUG','UUUAAAG','GGGAAAG','GGGUUUG',
#			 'CCCAAAG','CCCUUUG'
			 );
    my %slipsites_numbers = ();
    foreach my $s (@all_slipsites) { $slipsites_numbers{$s}{num} = 0; }
    my %slips_significant = ();
    foreach my $s (@all_slipsites) { $slips_significant{$s}{num} = 0; }
    open(MAP, ">${tmp_filename}.map") or Callstack(message => qq"Unable to open the map file ${tmp_filename}.map");
    print MAP "<map name=\"map\" id=\"map\">\n";
    my $image_map_string;
    if ($args_slipsites eq 'all') {
	foreach my $x_point (keys %{$points}) {
	    my $x_coord = sprintf("%.1f",((($x_range/$mfe_range)*($x_point - $mfe_min_value)) + $left_x_coord));
	    foreach my $y_point (keys %{$points->{$x_point}}) {
		my $accessions = $points->{$x_point}->{$y_point}->{accessions};
		my $genenames = $points->{$x_point}->{$y_point}->{genenames};
		if (!defined($genenames)) {
		    $genenames = $accessions;
		}
		my $start = $points->{$x_point}->{$y_point}->{start};
		my $y_coord = sprintf("%.1f",((($y_range/$z_range)*($z_max_value - $y_point)) + $bottom_y_coord));
		$x_coord = sprintf('%.0f', $x_coord);
		$y_coord = sprintf('%.0f', $y_coord);
		if ($points->{$x_point}->{$y_point}->{count} == 1) {
		    $image_map_string = qq(<area shape="circle" coords="${x_coord},${y_coord},$radius" href="/detail.html?short=1&accession=$accessions&slipstart=$start" title="$genenames">\n);
		}
		else {
		    if (defined($pknot)) {
			$image_map_string = qq(<area shape="circle" coords="${x_coord},${y_coord},$radius" href="/cloud_mfe_z.html?pknot=1&seqlength=${seqlength}&species=${species}&mfe=${x_point}&z=${y_point}" title="$genenames">\n);
		    }
		    else {
			$image_map_string = qq(<area shape="circle" coords="${x_coord},${y_coord},$radius" href="/cloud_mfe_z.html?seqlength=${seqlength}&species=${species}&mfe=${x_point}&z=${y_point}" title="$genenames">\n);
		    }
		}
		print MAP $image_map_string;
	    }
	}
    } 
    else {
	foreach my $point (@{$data}) {
	    my $x_point = sprintf("%.1f",$point->[0]);
	    my $y_point = sprintf("%.1f",$point->[1]);
	    my $x_coord = sprintf("%.1f",((($x_range/$mfe_range)*($x_point - $mfe_min_value)) + $left_x_coord));
	    my $y_coord = sprintf("%.1f",((($y_range/$z_range)*($z_max_value - $y_point)) + $bottom_y_coord));
	    my $slipsite = $point->[4];
	    my $accessions = $point->[2];
	    my $genenames = $point->[6];
	    my $start = $point->[5];
	    
	    if ($x_coord <= $mfe_significant_coord and $y_coord <= $z_significant_coord) {
		if (!defined($slips_significant{$slipsite})) {
		    $slips_significant{$slipsite}{num} = 1;
		}
		else {
		    $slips_significant{$slipsite}{num}++;
		}
		if ($slipsite =~ /^AAA....$/) {
		    $slips_significant{$slipsite}{color} = 'red';
		}
		elsif ($slipsite =~ /^UUU....$/) {
		    $slips_significant{$slipsite}{color} = 'green';
		}
		elsif ($slipsite =~ /^GGG....$/) {
		    $slips_significant{$slipsite}{color} = 'blue';
		}
		elsif ($slipsite =~ /^CCC....$/) {
		    $slips_significant{$slipsite}{color} = 'black';
		}
		else {
		    #$slips_significant{$slipsite}{color} = 'yellow';
		    #warn("This sucks. $slipsite doesn't match");
		    next;
		}
	    }
	    if (!defined($slipsites_numbers{$slipsite})) {
		$slipsites_numbers{$slipsite}{num} = 1;
	    }
	    else {
		$slipsites_numbers{$slipsite}{num}++;
	    }

	    if ($slipsite =~ /^AAA....$/) {
		$slipsites_numbers{$slipsite}{color} = 'red';
	    }
	    elsif ($slipsite =~ /^UUU....$/) {
		$slipsites_numbers{$slipsite}{color} = 'green';
	    }
	    elsif ($slipsite =~ /^GGG....$/) {
		$slipsites_numbers{$slipsite}{color} = 'blue';
	    }
	    elsif ($slipsite =~ /^CCC....$/) {
		$slipsites_numbers{$slipsite}{color} = 'black';
	    }
	    else {
		#warn("This sucks. $slipsite doesn't match the expected");
		next;
	    }
	    
	    if ($args_slipsites eq $slipsite) {
		my $x_coord = sprintf("%.1f",((($x_range/$mfe_range)*($x_point - $mfe_min_value)) + $left_x_coord));
		my $y_coord = sprintf("%.1f",((($y_range/$z_range)*($z_max_value - $y_point)) + $bottom_y_coord));
		$x_coord = sprintf('%.0f', $x_coord);
		$y_coord = sprintf('%.0f', $y_coord);
		# $gd->filledRectangle($x_coord-1, $y_coord-1, $x_coord+1, $y_coord+1, $black);
		$gd->filledArc($x_coord, $y_coord, 4, 4, 0, 360, $black, 4);
		
		if ($slipsites_numbers{$slipsite}{num} > 1) {
		    $image_map_string = qq(<area shape="circle" coords="${x_coord},${y_coord},$radius" href="/detail.html?short=1&accession=$accessions&slipstart=$start" title="$genenames">\n);
		}
		else {
		    if (defined($pknot)) {
			$image_map_string = qq(<area shape="circle" coords="${x_coord},${y_coord},$radius" href="/cloud_mfe_z.html?seqlength=${seqlength}&slipsite=$args_slipsites&pknot=1&species=${species}&mfe=${x_point}&z=${y_point}" title="$genenames">\n;);
		    }
		    else {
			$image_map_string = qq(<area shape="circle" coords="${x_coord},${y_coord},$radius" href="/cloud_mfe_z.html?seqlength=${seqlength}&slipsite=$args_slipsites&seqlength=${seqlength}&species=${species}&mfe=${x_point}&z=${y_point}" title="$genenames">\n);
		    } ## Foreach x point
		}
		print MAP $image_map_string;
	    }
	}
    }
    print MAP "</map>\n";
    close MAP;
    
    $gd->filledRectangle($average_mfe_coord, $bottom_y_coord+1, $average_mfe_coord+1, $top_y_coord-1, $black);
    $gd->filledRectangle($left_x_coord+1, $average_z_coord, $right_x_coord-1, $average_z_coord+1, $black);
    $gd->filledRectangle($mfe_significant_coord, $z_significant_coord, $mfe_significant_coord,
			 $top_y_coord, $darkslategray);
    $gd->filledRectangle($left_x_coord, $z_significant_coord, $mfe_significant_coord,
			 $z_significant_coord, $darkslategray);
    $gd->filledRectangle($mfe_2stds_significant_coord, $z_2stds_significant_coord,
			 $mfe_2stds_significant_coord, $top_y_coord, $darkslategray);
    $gd->filledRectangle($left_x_coord, $z_2stds_significant_coord, $mfe_2stds_significant_coord,
			 $z_2stds_significant_coord, $darkslategray);
    
    ### FIXME:  The 'top_y_coord' is actually the bottom.
    
    my ($bar_filename, $bar_sig_filename, $percent_sig_filename);
    $bar_filename = $filename;
    $bar_filename =~ s/\-[A-Z]+.*$//g;
    $bar_filename .= '-bar.png';
    $bar_sig_filename = $bar_filename;
    $bar_sig_filename =~ s/\.png$/-sig\.png/g;
    $percent_sig_filename = $bar_filename;
    $percent_sig_filename =~ s/\.png$/-percentsig\.png/g;
    my %percent_sig;
    foreach my $slip (keys %slipsites_numbers) {
	## UNDEF VALUES HERE, DIVISION BY ZERO
	if (!defined($slipsites_numbers{$slip}{num})) {
	    #$percent_sig{$slip}{num} = 0;
	    #$percent_sig{$slip}{color} = 'yellow';
	    #$slipsites_numbers{$slip}{num} = 0;
	    #$slipsites_numbers{$slip}{color} = 'yellow';
	}
	else {
	    if ($slipsites_numbers{$slip}{num} == 0) {
		$percent_sig{$slip}{num} = 0;
	    }
	    else {
		$percent_sig{$slip}{num} = (($slips_significant{$slip}{num} / $slipsites_numbers{$slip}{num}) * 100.0);
		$percent_sig{$slip}{num} = sprintf("%.1f", $percent_sig{$slip}{num});
	    }
	    $percent_sig{$slip}{color} = $slips_significant{$slip}{color};
	}
    }
    if (defined($args_slipsites) and $args_slipsites ne 'all') {
	Make_SlipBars(\%slipsites_numbers, $bar_filename);
	Make_SlipBars(\%slips_significant, $bar_sig_filename);
	Make_SlipBars(\%percent_sig, $percent_sig_filename);
    }
    open (IMG, ">$filename") or Callstack(die => 0, message => qq"error opening $filename to write image.");
    binmode IMG;
    print IMG $gd->png;
    close IMG;
    return($points);
}

sub Make_Overlay {
    my $me = shift;
    my %args = @_;
    my $species = $args{species};
    my $data = $args{points};
    my $filename = $args{filename};
    my $map_filename = $args{map};
    my $url = $args{url};
    my $accession = $args{accession};
    my $inputstring = $args{inputstring};
    my $graph = new GD::Graph::points('800','800');
    my $db = new PRFdb(config => $config);
    my $mt = "mfe_$species";
    my $mfe_min_value = $db->MySelect(statement => qq"SELECT min(mfe) FROM $mt", type => 'single');
    my $mfe_max_value = $db->MySelect(statement => qq"SELECT max(mfe) FROM $mt", type => 'single');
    $mfe_min_value -= 3.0;
    $mfe_max_value += 3.0;
    my $z_min_value = -10;
    my $z_max_value = 5;
    $graph->set(transparent => 1,
		x_min_value => $mfe_min_value,
		x_max_value => $mfe_max_value,
		x_ticks => 1,
		x_label => 'MFE',
		x_labels_vertical => 1,
		x_label_skip => 0,
		x_number_format => "%.1f",
		x_tick_number => 20,
		x_all_ticks => 1,
		y_min_value => $z_min_value,
		y_max_value => $z_max_value,
		y_ticks => 1,
		y_label => 'Zscore',
		y_label_skip => 0,
		y_number_format => "%.2f",
		y_tick_number => 20,
		y_all_ticks => 1,
		dclrs => ['black','black'],
		marker_size => 0,);
    $graph->set_legend_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    my $fun = [[-100,-100,-100],[0,0,0]];
    my $gd = $graph->plot($fun,) or Callstack(die => 1, message => $graph->error);
    my $black = $gd->colorResolve(0,0,0);
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

    open(MAP, ">$map_filename") or Callstack(message => qq"Unable to open the map file $map_filename.");
    print MAP "<map name=\"overlaymap\" id=\"overlaymap\">\n";

    my $radius = 6;
    foreach my $point (@{$data}) {
	my $x_point = sprintf("%.1f",$point->[0]);
	my $y_point = sprintf("%.1f",$point->[1]);
	my $slipstart = $point->[2];
	my $mfe_method = $point->[3];
	my $x_coord = sprintf("%.1f",((($x_range/$mfe_range)*($x_point - $mfe_min_value)) + $left_x_coord));
	my $y_coord = sprintf("%.1f",((($y_range/$z_range)*($z_max_value - $y_point)) + $bottom_y_coord));
	$x_coord = sprintf('%.0f', $x_coord);
	$y_coord = sprintf('%.0f', $y_coord);
	$gd->filledArc($x_coord, $y_coord, $radius, $radius, 0, 360, $black, 4);
	my $map_string = qq(<area shape="circle" coords="${x_coord},${y_coord},$radius" href="/detail.html?short=1&accession=$accession&slipstart=$slipstart" title="Position $slipstart of $accession ($inputstring) using $mfe_method">\n);
        print MAP $map_string;
    }
    print MAP "</map>\n";
    open (IMG, ">$filename") or Callstack(message => qq"error opening filename:<$filename> to write image.");
    binmode IMG;
    print IMG $gd->png;
    close IMG;
    close MAP;
    return(0);
}

sub Make_SlipBars {
    my $numbers = shift;
    my $filename = shift;
    my (@keys, @values);
    my @colors;
    my $color_string = '';
    ## UNDEF VALUES HERE
    my $nums;
    foreach my $k (keys %{$numbers}) {
#	print "WTF: $numbers->{$k}{color}\n";
	$nums->{$k} = $numbers->{$k} if (defined($numbers->{$k}{num}));
    }
    $numbers = $nums;
    foreach my $k (sort { $numbers->{$b}{num} <=> $numbers->{$a}{num} } keys %{$numbers}) {
#    foreach my $k (sort  keys %{$numbers}) {
#	$color_string .= "$numbers->{$k}{color} ";
	push (@colors, $numbers->{$k}{color});
	push (@keys, $k);
	push (@values, $numbers->{$k}{num});
    }
    my @data = (\@keys, \@values);
    my $bargraph = new GD::Graph::bars(700,400);
    my $y_label = 'number';
    my $title = 'How many of each slipsite';
    if ($filename =~ /percent/) {
	$y_label = 'percent';
	$title = 'Percent significant of each slipsite';
    }
    $bargraph->set(x_label => 'slipsite',
		   y_label => $y_label,
		   title => $title,
		   dclrs => [ qw"blue black red green" ],
		   cycle_clrs => 1,
		   dclrs => \@colors,
		   show_values => 1,
		   values_vertical => 1,
		   x_labels_vertical => 1,
		   y_max_value => $values[0],);
    #dclrs => [ qw"blue black red green" ],
    #dclrs => [ qw($color_string) ],
    $bargraph->set_legend_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $bargraph->set_x_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $bargraph->set_x_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $bargraph->set_y_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $bargraph->set_y_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    my $image = $bargraph->plot(\@data);
    open(IMG, ">$filename");
    print IMG $image->png if (defined($image));
    close IMG;
}

sub Make_Landscape_TT {
    my $me = shift;
    my $species = shift;
    my $accession = $me->{accession};
    my $filename = $me->Picture_Filename(type => 'landscape',);
    my $table = "landscape_$species";
    $filename =~ s/\.png/\.svg/g;
    my $db = new PRFdb(config => $config);
    my $mt = "mfe_$species";
    my $data =  $db->MySelect("SELECT start, mfe_method, pairs, mfe FROM $table WHERE accession='$accession' ORDER BY start, mfe_method");
    return(undef) if (!defined($data));
    my $slipsites = $db->MySelect("SELECT distinct(start) FROM $mt WHERE accession='$accession' ORDER BY start");
    my $start_stop = $db->MySelect("SELECT orf_start, orf_stop FROM genome WHERE accession = '$accession'");
    my $info = {};
    my @x_axis = ();
    my ($mean_nupack, $mean_pknots, $mean_vienna) = 0;
    my $position_counter = 0;
    
    
    foreach my $datum (@{$data}) {
	$position_counter++;
	my $place = $datum->[0];
	push(@x_axis, $place);
	$info->{$place}->{$datum->[1]} = $datum->[3];
    }   
    ## End foreach spot
    if ($position_counter == 0) {  ## There is no data!?
	return(undef);
	Callstack(message => "There is no data.");
    }
    $position_counter = $position_counter / 3;
    $mean_pknots = $mean_pknots / $position_counter;
    $mean_nupack = $mean_nupack / $position_counter;
    $mean_vienna = $mean_vienna / $position_counter;
    my (@axis_x, @nupack_y, @pknots_y, @vienna_y, @m_nupack, @m_pknots, @m_vienna);
#    my $end_spot = $points[$#points] + 105;
    my $current  = 0;
    my $height = 200;
    my $width = 600;
    my $svg_graph = new SVG::TT::Graph::Line({
	height => $height,
	width => $width + 400,
	fields => \@x_axis,
	show_data_points => 1,
	show_data_values => 0,
	show_x_labels => 0,
	show_y_labels => 1,
	show_x_title => 1,
	x_title => 'Position',
	show_y_title => 1,
	y_title => 'MFE',
	show_graph_title => 0,
	key => 1,
	key_position => 'right',
	tidy => 1,
    });
    $svg_graph->compress(0);
    $svg_graph->style_sheet("/graph.css");
    
    ## Fill the id list with everything if it is null
    ## When adding data to the graph it is sent as a
    ## 2d array, by program then position (I think)
    my @lines = ('pknots','nupack','vienna');
    #	$info->{$place}->{$datum->[1]} = $datum->[3];
    ##  We have a hash keyed by position, then mfe_method, leading to MFE
    ##  Our goal is to do an add_data(\@all_points_for_one_mfe_method, $name_of_mfe_method);
    my @line_datum = ();
    my @mean_line_datum = ();
    foreach my $line (@lines) {
#	foreach my $pos (sort $a<=>$b keys %{$info}) {
	foreach my $pos (sort keys %{$info}) {
	    push(@line_datum, $info->{$pos}->{$line});
	    my $var_name = "mean_$line";
	    push(@mean_line_datum, $$var_name);
	}
	$svg_graph->add_data({data => \@line_datum, title => $line});
	$svg_graph->add_data({data => \@mean_line_datum, title => "$line mean"});
    }
    open(OUT, ">$filename");
    print OUT $svg_graph->burn();
    close OUT;
}

sub Make_Landscape {
    my $me = shift;
    my $species = shift;
    my $accession = $me->{accession};
    my $filename = $me->Picture_Filename(type => 'landscape',);
    my $table = "landscape_$species";
    system("touch $filename");
    my $db = new PRFdb(config=>$config);
    my $mt = "mfe_$species";
    my $data = $db->MySelect("SELECT start, mfe_method, pairs, mfe FROM $table WHERE accession='$accession' ORDER BY start, mfe_method");
    return(undef) if (!defined($data));
    my $slipsites = $db->MySelect("SELECT distinct(start) FROM $mt WHERE accession='$accession' ORDER BY start");
    my $start_stop = $db->MySelect("SELECT orf_start, orf_stop FROM genome WHERE accession = '$accession'");
    my $info = {};
    my @points = ();
    my ($mean_nupack, $mean_pknots, $mean_vienna) = 0;
    my $position_counter = 0;
    foreach my $datum (@{$data}) {
	$position_counter++;
	my $place = $datum->[0];
	push(@points, $place);
	
	if ($datum->[1] eq 'pknots') {
	    $info->{$place}->{pknots} = $datum->[3];
	    $mean_pknots = $mean_pknots + $datum->[3];
	}
	elsif ($datum->[1] eq 'nupack') {
	    $info->{$place}->{nupack} = $datum->[3];
	    $mean_nupack = $mean_nupack + $datum->[3];
	}
	elsif ($datum->[1] eq 'vienna') {
	    $info->{$place}->{vienna} = $datum->[3];
	    $mean_vienna = $mean_vienna + $datum->[3];
	}
    }    ## End foreach spot
    if ($position_counter == 0) {  ## There is no data!?
	return(undef);
	Callstack(message => "There is no data.");
    }
    $position_counter = $position_counter / 3;
    $mean_pknots = $mean_pknots / $position_counter;
    $mean_nupack = $mean_nupack / $position_counter;
    $mean_vienna = $mean_vienna / $position_counter;
    my (@axis_x, @nupack_y, @pknots_y, @vienna_y, @m_nupack, @m_pknots, @m_vienna);
    my $end_spot = $points[$#points] + 105;
    my $current  = 0;
    while ($current <= $end_spot) {
	push(@axis_x, $current);
	push(@m_nupack, $mean_nupack);
	push(@m_pknots, $mean_pknots);
	push(@m_vienna, $mean_vienna);
	if (defined($info->{$current})) {
	    push(@nupack_y, $info->{$current}->{nupack});
	    push(@pknots_y, $info->{$current}->{pknots});
	    push(@vienna_y, $info->{$current}->{vienna});
	}
	else {
	    push(@nupack_y,undef);
	    push(@pknots_y,undef);
	    push(@vienna_y,undef);
	}
	$current++;
    }
    my @mfe_data = (\@axis_x, \@nupack_y, \@pknots_y, \@vienna_y, \@m_nupack, \@m_pknots, \@m_vienna);
    my $width = $end_spot;
    my $height = 400;
    my $graph = new GD::Graph::mixed($width,$height);
    $graph->set(bgclr => 'white',
		x_label => 'Distance on ORF',
		y_label => 'kcal/mol',
		y_label_skip => 2,
		y_number_format => "%.2f",
		x_labels_vertical => 1,
		x_label_skip => 100,
		line_width => 2,
		dclrs => [qw(blue red green blue red green)],
		default_type => 'lines',
		types => [qw(lines lines lines lines lines lines)],) or Callstack(die => 1, message => $graph->error);
    $graph->set_legend_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    my $gd = $graph->plot(\@mfe_data) or Callstack(die => 1, message => $graph->error);
    
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

    open(IMG, ">$filename") or Callstack(die => 1);
    binmode IMG;
    print IMG $gd->png;
    close IMG;
    my $ret = {
	filename => $filename,
	mean_pknots => $mean_pknots,
	mean_nupack => $mean_nupack,
	mean_vienna => $mean_vienna,
	height => $height,
	width => $width,
    };
    return ($ret);
}

sub Make_Distribution {
    my $me = shift;
    my $graph_x_size = $config->{graph_distribution_x_size};
    my $graph_y_size = $config->{graph_distribution_y_size};
    #not yet implemented
    my $real_mfe = $me->{real_mfe};
    my @values = @{$me->{list_data}};
    for my $c (0 .. $#values) {
	if (!defined($values[$c])) {
	    $values[$c] = 0;
	}
    }
    my $acc_slip = $me->{acc_slip}; 
    my @sorted = sort {$a <=> $b} @values;
    my $min = sprintf("%+d",$sorted[0]);
    ## An attempt to make sure that the green bar containing the MFE of the
    ## nupack/pknots folded sequence window actually falls on the bar.
    if ($min > $real_mfe) {
	$min = sprintf("%+d", $real_mfe);
    }
    my $max = sprintf("%+d", $sorted[scalar(@sorted) - 1]);
    my $total_range = sprintf("%d", ($max - $min));
    my $num_bins = sprintf("%d",2 * (scalar(@sorted) ** (2 / 5))); # bins = floor{ 2 * N^(2/5) }
    $num_bins++ if ($num_bins == 0);
    my $bin_range = sprintf("%.1f", $total_range / $num_bins);
    my @yax = (0);
    my @yax_sums = (0);
    my @xax = ( sprintf("%.1f", $min) );
    for(my $i = 1; $i <= ($num_bins); $i++){
	$xax[$i] = sprintf( "%.1f", $bin_range * $i + $min);
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
    my $xbar = mean(\@values);
    my $xvar = variance(\@values);
    my $xstddev = stddev(\@values);
    $xbar = sprintf("%.2f",$xbar->query);
    $xvar = sprintf("%.2f",$xvar->query);
    $xstddev = sprintf("%.2f",$xstddev->query);
    
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
    my @data = (\@xax, \@yax, \@dist_y, [0], [0],);
    
    my $graph = GD::Graph::mixed->new($graph_x_size, $graph_y_size);
    $graph->set_legend("Rand. MFEs", "Normal Dist.", "Actual MFE", "Mean MFE");
    $graph->set(bgclr => 'white', types => [qw(bars lines lines lines)], x_label => 'kcal/mol',
		y_label => 'p(x)', y_label_skip => 2, y_number_format => "%.2f",
		x_labels_vertical => 1, x_label_skip => 1, line_width => 3,
		dclrs => [qw(blue red green black)], borderclrs => [qw(black)]) or Callstack(message => $graph->error, die => 1);
    
    $graph->set_legend_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_axis_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_label_font("$ENV{PRFDB_HOME}/fonts/$config->{graph_font}", $config->{graph_font_size});
    
    my $gd = $graph->plot(\@data) or Callstack(die => 1, message => $graph->error);
    
    my $axes_coords = $graph->get_feature_coordinates('axes');
    
    my $top_x_coord = $axes_coords->[1];
    my $top_y_coord = $axes_coords->[2];
    my $bottom_x_coord = $axes_coords->[3];
    my $bottom_y_coord = $axes_coords->[4];
    my $x_interval = sprintf("%.1f", (($max-$min)/$num_bins) );
    my $x_interval_pixels = ($bottom_x_coord - $top_x_coord)/($num_bins + 2);

    my $mfe_x_coord;
    my $mfe_xbar_coord;
    if (!$x_interval or $x_interval == 0) {
	$mfe_x_coord = $top_x_coord + $x_interval_pixels + (($real_mfe - $min) * $x_interval_pixels);
	$mfe_xbar_coord = $top_x_coord + $x_interval_pixels + (($xbar - $min) * $x_interval_pixels);
    } else {
	$mfe_x_coord = $top_x_coord + $x_interval_pixels + (($real_mfe - $min) * ($x_interval_pixels/$x_interval));
	$mfe_xbar_coord = $top_x_coord + $x_interval_pixels + (($xbar - $min) * ($x_interval_pixels/$x_interval));
    }
    my $green = $gd->colorAllocate(0,191,0);
    $gd->filledRectangle($mfe_x_coord, $bottom_y_coord+1 , $mfe_x_coord+1, $top_y_coord-1, $green);
    my $bl = $gd->colorAllocate(0,0,0);
    $gd->filledRectangle($mfe_xbar_coord, $bottom_y_coord+1 , $mfe_xbar_coord+1, $top_y_coord-1, $bl);
    my $filename = $me->Picture_Filename(type => 'distribution');
    open(IMG, ">$filename") or Callstack(message => "Unable to open $filename.");
    binmode IMG;
    print IMG $gd->png;
    close IMG;
    return($filename);
}

sub Make_Feynman {
    my $me = shift;
    my $out_filename = shift;
    my $include_slipsite = shift;
    my ($id, $sequence, $parsed, $pkout, $slipsite);
    $include_slipsite = 1 if (!defined($slipsite) and !defined($include_slipsite));
    if (defined($me->{sequence})) {
	$sequence = $me->{sequence};
	$parsed = $me->{parsed};
	$pkout = $me->{output};
    }
    else {
	$id = $me->{mfe_id};
	my $db = new PRFdb(config=>$config);
	my $species = $db->MySelect(statement => "SELECT species FROM gene_info WHERE accession = ?", type => 'single', vars => [$me->{accession}]);
	my $mt = qq"mfe_$species";
	$mt = 'mfe_virus' if ($mt =~ /virus/);
	my $stmt = qq"SELECT sequence, slipsite, parsed, output FROM $mt WHERE id = '$id'";
	my $info = $db->MySelect(statement => $stmt, type => 'row');
	$sequence = $info->[0];
	$slipsite = $info->[1];
	$parsed = $info->[2];
	$pkout = $info->[3];
    }
    my $seqlength = length($sequence);
    my $character_size = 10;
    my $height_per_nt = 3.5;
    
    ## x_pad takes into account the size of the blank space on the left
    my $x_pad = 10;
    ## Width takes into account the size of each character, the number of character, the padding between them, and
    ## The size of the padding
    my $slipsite_padding = 0;
    if ($include_slipsite == 1) {
	$slipsite_padding = 56;
    }
    my $width = ($seqlength * ($character_size - 2)) + ($x_pad * 2) + $slipsite_padding;
    
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
    my $white = $fey->colorAllocate(255,255,255);
    my $black = $fey->colorAllocate(0,0,0);
    my $blue = $fey->colorAllocate(0,0,191);
    my $red = $fey->colorAllocate(248,0,0);
    my $green = $fey->colorAllocate(0,191,0);
    my $purple = $fey->colorAllocate(192,60,192);
    my $orange = $fey->colorAllocate(255,165,0);
    my $brown = $fey->colorAllocate(192,148,68);
    my $darkslategray = $fey->colorAllocate(165,165,165);
    my $gray = $fey->colorAllocate(127,127,127);
    my $aqua = $fey->colorAllocate(127,255,212);
    my $yellow = $fey->colorAllocate(255,255,0);
    my $gb = $fey->colorAllocate(0,97,97);
    
    $fey->transparent($white);
#1    $fey->filledRectangle(0,0,$width,$height,$white);
    
    my @colors = ($black, $blue, $red, $green, $purple, $orange, $brown, $darkslategray,
		  $black, $blue, $red, $green, $purple, $orange, $brown, $darkslategray,
		  $black, $blue, $red, $green, $purple, $orange, $brown, $darkslategray,
		  );
    
    my $start_x = $x_pad;
    my $start_y = $height - 10;
    
    my $distance_per_char = $character_size - 2;
    my $string_x_distance = $character_size * length($sequence);
    
    my @stems = split(/\s+/, $parsed);
    my @paired = split(/\s+/, $pkout);
    my @seq = split(//, $sequence);
    my $last_stem = $me->Get_Last(\@stems);
    my $bp_per_stem = $me->Get_Stems(\@stems);
    
    my $character_x = $start_x;
    my $character_y = $start_y - 10;
    
    ## Print out the slipsite
    my @slipsite = split(//, $slipsite);
    for my $c (0 .. $#slipsite) {
	$fey->char(gdMediumBoldFont, $character_x, $character_y, $slipsite[$c], $black);
	$character_x = $character_x + 8;
    }
    
    for my $c (0 .. $#seq) {
	my $count = $c+1;
	next if (!defined($paired[$c]));
	if ($paired[$c] eq '.') {
	    if ($stems[$c] =~ /\d+/) {
		$fey->char(gdMediumBoldFont, $character_x, $character_y, $seq[$c], $colors[$stems[$c]]);
	    }
	    elsif ($stems[$c] eq '.') {
		$fey->char(gdMediumBoldFont, $character_x, $character_y, $seq[$c], $black);
	    }
	}
	elsif ($paired[$c] =~ /\d+/) {
	    my $current_stem = $stems[$c];
	    my $bases_in_stem = $bp_per_stem->{$current_stem};
	    my $center_characters = ($paired[$c] - $c) / 2;
	    my $center_position = $center_characters * $distance_per_char;
	    ## Note the random +56 here (8 pixels for each character of the slipsite and 7 characters)
	    my $center_x = $center_position + ($c * $distance_per_char) + $slipsite_padding;
	    my $center_y = $height;
	    my $dist_x = $center_characters * $distance_per_char * 2;
	    my $dist_nt = $paired[$c] - $c;
	    my $dist_y = $dist_nt * $height_per_nt;
	    $center_x = $center_x + $x_pad + ($distance_per_char / 2);
	    $center_y = $center_y - 20;
	    $fey->setThickness(2);
	    $fey->arc($center_x, $center_y, $dist_x, $dist_y, 180, 0, $colors[$stems[$c]]);
	    $paired[$paired[$c]] = '.';
	    $fey->char(gdMediumBoldFont, $character_x, $character_y, $seq[$c], $colors[$stems[$c]]);
	}
	else {
### Why are there spaces?
#	    print "Crap in a hat the character is $paired[$c]\n";
	    $fey->char(gdMediumBoldFont, $character_x, $character_y, $seq[$c], $black);
	}
	$character_x = $character_x + 8;
    }
    my $output;
    if(defined($out_filename)) {
	$output = $out_filename;
    }
    else {
	$output = $me->Picture_Filename(type => 'feynman');
    }
    open(OUT, ">$output");
    binmode OUT;
    print OUT $fey->svg;
    close OUT;
    my $command = qq(sed 's/font=\"Helvetica\"/font-family="Courier New"/g' ${output} > ${output}.tmp);
    system($command);
    $command = qq(mv ${output}.tmp ${output});
    system($command);
    
    my $ret = {
	width => $width + 1 + $slipsite_padding,
	height => $height + 1,
    };
    return($ret);
}

sub Char_Position {
    my $char_num = shift;
    my $num_characters = shift;
    my $width = shift;
    my $height = shift;
    my $degrees = (360 / $num_characters) * $char_num;
    my $rads = deg2rad($degrees);
    my $position_x = (($width / 2) - 20) * cos($rads) + ($width / 2);
    my $position_y = (($height / 2) - 20) * sin($rads) + ($height / 2);
    my @ret = ($position_x, $position_y, $degrees, $rads);
    return(\@ret);
}

sub Make_OFeynman {
    my $me = shift;
    my $out_filename = shift;
    my $include_slipsite = shift;
    my $slipsite = undef;
    $include_slipsite = 1 if (!defined($slipsite) and !defined($include_slipsite));
    my $mt = "mfe_$me->{species}";
    my $ids = $me->{ids};
    my $db = new PRFdb(config=>$config);
    my $stmt = qq"SELECT sequence, slipsite, parsed, output, mfe_method FROM $mt WHERE id = ? or id = ? or id = ?";
    my $info = $db->MySelect(statement => $stmt, vars => [$ids->[0], $ids->[1], $ids->[2]],);
    my $sequence = $info->[0]->[0];
    $slipsite = $info->[0]->[1];
    my (@parsed, @pkout, @mfe_method);
    my @seq = split(//, $sequence);
    foreach my $datum (@{$info}) {
	push(@parsed, $datum->[2]);
	push(@pkout, $datum->[3]);
	push(@mfe_method, $datum->[4]);
    }
    my $seqlength = length($sequence);
    my $character_size = 10;
    my $height_per_nt = 3.5;
    
    ## x_pad takes into account the size of the blank space on the left
    my $x_pad = 10;
    ## Width takes into account the size of each character, the number of character, the padding between them, and
    ## The size of the padding
    my $slipsite_padding = 0;
    if ($include_slipsite == 1) {
	$slipsite_padding = 56;
    }
    my $width = ($seqlength * ($character_size - 2)) + ($x_pad * 2) + $slipsite_padding;
    my $height = 400;
    ## originally (($height_per_nt * $max_dist) / 2) + ($character_size * 4);
    my $fey = new GD::SVG::Image($width,$height);
    my $white = $fey->colorAllocate(255,255,255);
    my $black = $fey->colorAllocate(0,0,0);
#    my $blue = $fey->colorAllocate(0,0,191);
# new blue
    my $blue = $fey->colorAllocate(83,144,255);
    my $red = $fey->colorAllocate(248,0,0);
    my $green = $fey->colorAllocate(0,191,0);
    my $purple = $fey->colorAllocate(192,60,192);
    my $orange = $fey->colorAllocate(255,165,0);
    my $brown = $fey->colorAllocate(192,148,68);
    my $darkslategray = $fey->colorAllocate(165,165,165);
    my $gray = $fey->colorAllocate(127,127,127);
    my $aqua = $fey->colorAllocate(127,255,212);
    my $yellow = $fey->colorAllocate(255,255,0);
    my $gb = $fey->colorAllocate(0,97,97);
    $fey->transparent($gray);

    my $struct;
    LOOP: for my $c (0 .. 120) {  ## Grossly overshoot the number of basepairs
	for my $d (0 .. $#pkout) {   ## The 3 or so mfe_methods available
	    my @pktmp = split(/\s+/, $pkout[$d]);
	    my @patmp = split(/\s+/, $parsed[$d]);
	    next LOOP if (!defined($pktmp[$c]));
	    $struct->{$c}->{$mfe_method[$d]}->{partner} = $pktmp[$c];
	    $patmp[$c] = '.' if (!defined($patmp[$c]));
	    $struct->{$c}->{$mfe_method[$d]}->{stemnum} = $patmp[$c];
	}
    }
    
    my $comp = {};
    my $agree = {
	all => 0,
	none => 0,
	n => 0,
	h => 0,
	p => 0,
	hn => 0,
	np => 0,
	hp => 0,
	hnp => 0,
    };
    my $c = -1;
    while ($c < 200) {
	$c++;
	next if (!defined($struct->{$c}));
	my $n = $struct->{$c}->{nupack}->{partner};
	my $h = $struct->{$c}->{hotknots}->{partner};
	my $p = $struct->{$c}->{pknots}->{partner};
	if (!defined($n)) {
	    print "n not defined\n";
	    next;
	}
	elsif (!defined($h)) {
	    print "h not defined\n";
	    next;
	}
	elsif (!defined($p)) {
	    print "$p not defined\n";
	    next;
	}

#	sleep(1);
	if ($struct->{$c}->{hotknots}->{partner} eq '.' and $struct->{$c}->{pknots}->{partner} eq '.' and $struct->{$c}->{nupack}->{partner} eq '.') {
	    $agree->{none}++;
	    $comp->{$c}->{partner} = ['.'];
	    $comp->{$c}->{color} = [0];
	    ## Nothing is 0
	}
	elsif (($n eq $h) and ($n eq $p)) {
	    $agree->{all}++;
	    $comp->{$c}->{partner} = [$n];
	    $comp->{$c}->{color} = [1];
	    ## All 3 same is 1
	}
	elsif (($n ne $h) and ($n ne $p)) {
	    $agree->{hnp}++;
	    $comp->{$c}->{partner} = [$n,$h,$p];
	    $comp->{$c}->{color} = [2,3,4];
	    ## nupack is 2
	    ## hotknots is 3
	    ## pknots is 4
	}
	elsif ($n eq '.' and $h eq '.') {
	    $agree->{p}++;
	    $comp->{$c}->{partner} = [$p];
	    $comp->{$c}->{color} = [4];
	}
	elsif ($n eq '.' and $p eq '.') {
	    $agree->{h}++;
	    $comp->{$c}->{partner} = [$h];
	    $comp->{$c}->{color} = [3];
	}
	elsif ($h eq '.' and $p eq '.') {
	    $agree->{n}++;
	    $comp->{$c}->{partner} = [$n];
	    $comp->{$c}->{color} = [2];
	}
	elsif ($n eq '.') {
	    $agree->{hp}++;
	    if ($h eq $p) {
		$comp->{$c}->{partner} = [$h];
		$comp->{$c}->{color} = [5];
		## hotknots+pknots is 5
	    }
	    else {
		$comp->{$c}->{partner} = [$h,$p];
		$comp->{$c}->{color} = [3,4];
	    }
	}
	elsif ($h eq '.') {
	    $agree->{np}++;
	    if ($n eq $p) {
		$comp->{$c}->{partner} = [$n];
		$comp->{$c}->{color} = [6];
		## nupack+pknots is 6
	    }
	    else {
		$comp->{$c}->{partner} = [$n,$p];
		$comp->{$c}->{color} = [2,4];
	    }
	}
	elsif ($p eq '.') {
	    $agree->{hn}++;
	    if ($h eq $n) {
		$comp->{$c}->{partner} = [$h];
		$comp->{$c}->{color} = [7];
		## hotknots+nupack is 7
	    }
	    else {
		$comp->{$c}->{partner} = [$h,$n];
		$comp->{$c}->{color} = [2,3];
	    }
	}
	elsif ($n eq $p) {
	    $agree->{hnp}++;
#	    $comp->{$c}->{partner} = [$n,$h];
#	    $comp->{$c}->{color} = [6,3];
	    $comp->{$c}->{partner} = [$h,$n];
	    $comp->{$c}->{color} = [3,6];
	}
	elsif ($n eq $h) {
	    $agree->{hnp}++;
#	    $comp->{$c}->{partner} = [$n,$p];
#	    $comp->{$c}->{color} = [7,4];
	    $comp->{$c}->{partner} = [$p,$n];
	    $comp->{$c}->{color} = [4,7];
	}
	elsif ($p eq $h) {
	    $agree->{hnp}++;
#	    $comp->{$c}->{partner} = [$p,$n];
#	    $comp->{$c}->{color} = [5,2];
	    $comp->{$c}->{partner} = [$n,$p];
	    $comp->{$c}->{color} = [2,5];
	}
    }
    ##             0            1       2        3       4      5       6        7   8 9 10 are catchalls
    ##             nothing      all    nupack   hot    pknot   h+p    n+p       h+n
#    my @colornames = ('white','black','orange','aqua','yellow','green','red','blue','darkslategray','darkslategray','darkslategray');
    my @color_list = ($white, $black, $yellow, $red, $blue, $purple, $green, $orange, $darkslategray, $darkslategray, $darkslategray);
    my $start_x = $x_pad;
    my $start_y = $height - 10;
    my $distance_per_char = $character_size - 2;
    my $string_x_distance = $character_size * length($sequence);
    my $character_x = $start_x;
    my $character_y = $start_y - 10;
    
    $c = -1;
    while ($c < 200) {
	$c++;
	next if (!defined($seq[$c]));
	## Draw the base
	$fey->char(gdMediumBoldFont, $character_x, $character_y, $seq[$c], $black);
	$character_x += 8;
	## Draw the curves
	if (!defined($comp->{$c}->{partner})) {
	    $comp->{$c}->{partner} = ['.'];
	    $comp->{$c}->{color} = [$darkslategray];
	}
	my @curves = @{$comp->{$c}->{partner}};
	my @colors = @{$comp->{$c}->{color}};
	for my $a (0 .. $#curves) {
	    next if ($curves[$a] eq '.');
	    ## Current character is $seq[$c], position is $c
	    ## Paired character's position is $curves[$a],
	    ## Resulting color is $color_list[$colors[$a]]
	    ## color name: $colornames[$a]
	    my $center_characters = ($curves[$a] - $c) / 2;
	    my $center_position = $center_characters * $distance_per_char;
	    my $center_x = $center_position + ($c * $distance_per_char);  ## + $slipsite_padding
	    my $center_y = $height;
	    my $dist_x = $center_characters * $distance_per_char * 2;
	    my $dist_nt = $curves[$a] - $c;
	    my $dist_y = $dist_nt * $height_per_nt;
	    $center_x = $center_x + $x_pad + ($distance_per_char / 2);
	    $center_y = $center_y - 20;
	    $fey->setThickness(2);
	    $fey->arc($center_x, $center_y, $dist_x, $dist_y, 180, 0, $color_list[$colors[$a]]);
	}
    }

    my $output;
    if(defined($out_filename)) {
	$output = $out_filename;
    }
    else {
	$output = $me->Picture_Filename(type => 'ofeynman');
    }
    open(OUT, ">$output");
    binmode OUT;
    print OUT $fey->svg;
    close OUT;
    my $command = qq(sed 's/font=\"Helvetica\"/font-family="Courier New"/g' ${output} > ${output}.tmp);
    system($command);
    $command = qq(mv ${output}.tmp ${output});
    system($command);
    
    my $ret = {
	width => $width + 1 + $slipsite_padding,
	height => $height + 1,
	agree => $agree,
    };
    return($ret);
}

sub Make_Classical {
    my $me = shift;
    my $id = $me->{mfe_id};
    my $db = new PRFdb(config => $config);
    my $mt = qq"mfe_$me->{species}";
    my $stmt = qq"SELECT sequence, parsed, output FROM $mt WHERE id = ?";
    my $info = $db->MySelect(statement => $stmt, vars => [$id], type => 'row');
    my $sequence = $info->[0];
    my $parsed = $info->[1];
    my $pkout = $info->[2];
    my $seqlength = length($sequence);
    my $character_size = 10;
    my $height_per_nt = 3.5;
    
    my $x_pad = 10;
    my $width = 800;
    my $height = 800;
    
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
    my $gray = $fey->colorAllocate(127,127,127);
    my $aqua = $fey->colorAllocate(127,255,212);
    my $yellow = $fey->colorAllocate(255,255,0);
    my $gb = $fey->colorAllocate(0, 97, 97);
    
    $fey->transparent($white);
#1    $fey->filledRectangle(0,0,$width,$height,$white);
    
    my @colors = ($black, $blue, $red, $green, $purple, $orange, $brown, $darkslategray,
		  $black, $blue, $red, $green, $purple, $orange, $brown, $darkslategray,
		  $black, $blue, $red, $green, $purple, $orange, $brown, $darkslategray,
		  );
    
    my $center_x = $width / 2;
    my $center_y = $height / 2;
    
    my $distance_per_char = $character_size - 2;
    my $string_x_distance = $character_size * length($sequence);
    
    my @stems = split(/\s+/, $parsed);
    my @paired = split(/\s+/, $pkout);
    my @seq = split(//, $sequence);
    my $last_stem = $me->Get_Last(\@stems);
    my $bp_per_tsem = $me->Get_Stems(\@stems);
    
    my %return_position = ();
    my $num_characters = scalar(@seq) + 5;
    my $struct = {};
    for my $c (0 .. $#seq) {
	my $position_info = Char_Position($c, $num_characters, $width, $height);
	my $degrees = $position_info->[2];
	my $rads = $position_info->[3];
	my $position_x = $position_info->[0];
	my $position_y = $position_info->[1];
	$struct->{$c}->{x} = $position_x;
	$struct->{$c}->{y} = $position_y;
	$struct->{$c}->{char} = $seq[$c];
	$struct->{$c}->{stem} = $stems[$c];
	$struct->{$c}->{paired} = $paired[$c];
    }

    my $max_iter = 10;
    for my $iter (0 .. $max_iter) {
	for my $bp (0 .. $num_characters) {
	    if ($struct->{$bp}->{stem} =~ /\d+/) {
		print "rawr\n";
	    }
	}
    }

    for my $c (0 .. $#seq) {
        my $position_info = Char_Position($c, $num_characters, $width, $height);
        my $degrees = $position_info->[2];
        my $rads = $position_info->[3];
        my $position_x = $position_info->[0];
        my $position_y = $position_info->[1];
        $return_position{$c}->{x} = $position_x;
        $return_position{$c}->{y} = $position_y;
        $return_position{$c}->{char} = $seq[$c];
        $return_position{$c}->{stem} = $stems[$c];
        $return_position{$c}->{paired} = $paired[$c];
	my $count = $c+1;
	if ($paired[$c] eq '.') {
	    if ($stems[$c] =~ /\d+/) {
#		$fey->stringRotate(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $colors[$stems[$c]], $degrees);
#		$fey->stringFT($black, gdMediumBoldFont, 4, $degrees, $position_x, $position_y, $seq[$c]);
		$fey->char(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black);
	    }
	    elsif ($stems[$c] eq '.') {
#		$fey->stringRotate(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black, $degrees);
#		$fey->stringFT($black, gdMediumBoldFont, 4, $degrees, $position_x, $position_y, $seq[$c]);
		$fey->char(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black);
	    }
	}
	elsif ($paired[$c] =~ /\d+/) {
	    my $old_position = Char_Position($paired[$c], $num_characters, $width, $height);
	    my $old_degrees = $old_position->[2];
	    my $old_x = $old_position->[0];
	    my $old_y = $old_position->[1];
	    
	    my $c_x = abs($position_x - $old_x) / 2;
	    my $c_y = abs($position_y - $old_y) / 2;
	    
	    $fey->setThickness(2);
	    $fey->line($old_x+5, $old_y+5, $position_x+5, $position_y+5, $colors[$stems[$c]]);
	    $paired[$paired[$c]] = '.';
#	    $fey->stringRotate(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $colors[$stems[$c]], $degrees);
#	    $fey->stringFT($black, gdMediumBoldFont, 4, $degrees, $position_x, $position_y, $seq[$c]);
	    $fey->char(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black);
	}
	else { ### Why are there spaces?
#	    $fey->stringRotate(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black, $degrees);
#	    $fey->stringFT($black, gdMediumBoldFont, 4, $degrees, $position_x, $position_y, $seq[$c]);
	    $fey->char(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black);
	}
    }
    my $output = $me->Picture_Filename(type => 'cfeynman');
    open(OUT, ">$output");
    binmode OUT;
    print OUT $fey->svg;
    close OUT;
    my $command = qq(sed 's/font=\"Helvetica\"/font-family="Courier New"/g' ${output} > ${output}.tmp);
    system($command);
    $command = qq(mv ${output}.tmp ${output});
    system($command);   
    return(\%return_position);
}

sub Make_CFeynman {
    my $me = shift;
    my $id = $me->{mfe_id};
    my $db = new PRFdb(config => $config);
    my $species = $me->{species};
    my $mt = qq"mfe_${species}";
    my $stmt = qq"SELECT sequence, parsed, output FROM $mt WHERE id = ?";
    my $info = $db->MySelect(statement => $stmt, vars => [$id], type => 'row');
    my $sequence = $info->[0];
    my $parsed = $info->[1];
    my $pkout = $info->[2];
    my $seqlength = length($sequence);
    my $character_size = 10;
    my $height_per_nt = 3.5;
    
    my $x_pad = 10;
    my $width = 800;
    my $height = 800;
    
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
    my $gray = $fey->colorAllocate(127,127,127);
    my $aqua = $fey->colorAllocate(127,255,212);
    my $yellow = $fey->colorAllocate(255,255,0);
    my $gb = $fey->colorAllocate(0, 97, 97);
    
    $fey->transparent($white);
#1    $fey->filledRectangle(0,0,$width,$height,$white);
    
    my @colors = ($black, $blue, $red, $green, $purple, $orange, $brown, $darkslategray,
		  $black, $blue, $red, $green, $purple, $orange, $brown, $darkslategray,
		  $black, $blue, $red, $green, $purple, $orange, $brown, $darkslategray,
		  );
    
    my $center_x = $width / 2;
    my $center_y = $height / 2;
    
    my $distance_per_char = $character_size - 2;
    my $string_x_distance = $character_size * length($sequence);
    
    my @stems = split(/\s+/, $parsed);
    my @paired = split(/\s+/, $pkout);
    my @seq = split(//, $sequence);
    my $last_stem = $me->Get_Last(\@stems);
    my $bp_per_tsem = $me->Get_Stems(\@stems);
    
    my %return_position = ();
    my $num_characters = scalar(@seq) + 5;
    for my $c (0 .. $#seq) {
	my $position_info = Char_Position($c, $num_characters, $width, $height);
	my $degrees = $position_info->[2];
	my $rads = $position_info->[3];
	my $position_x = $position_info->[0];
	my $position_y = $position_info->[1];
	$return_position{$c}->{x} = $position_x;
	$return_position{$c}->{y} = $position_y;
	$return_position{$c}->{char} = $seq[$c];
	$return_position{$c}->{stem} = $stems[$c];
	$return_position{$c}->{paired} = $paired[$c];
	my $count = $c+1;
	if ($paired[$c] eq '.') {
	    if ($stems[$c] =~ /\d+/) {
#		$fey->stringRotate(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $colors[$stems[$c]], $degrees);
#		$fey->stringFT($black, gdMediumBoldFont, 4, $degrees, $position_x, $position_y, $seq[$c]);
		$fey->char(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black);
	    }
	    elsif ($stems[$c] eq '.') {
#		$fey->stringRotate(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black, $degrees);
#		$fey->stringFT($black, gdMediumBoldFont, 4, $degrees, $position_x, $position_y, $seq[$c]);
		$fey->char(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black);
	    }
	}
	elsif ($paired[$c] =~ /\d+/) {
	    my $old_position = Char_Position($paired[$c], $num_characters, $width, $height);
	    my $old_degrees = $old_position->[2];
	    my $old_x = $old_position->[0];
	    my $old_y = $old_position->[1];
	    
	    my $c_x = abs($position_x - $old_x) / 2;
	    my $c_y = abs($position_y - $old_y) / 2;
	    
	    $fey->setThickness(2);
	    $fey->line($old_x+5, $old_y+5, $position_x+5, $position_y+5, $colors[$stems[$c]]);
	    $paired[$paired[$c]] = '.';
#	    $fey->stringRotate(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $colors[$stems[$c]], $degrees);
#	    $fey->stringFT($black, gdMediumBoldFont, 4, $degrees, $position_x, $position_y, $seq[$c]);
	    $fey->char(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black);
	}
	else { ### Why are there spaces?
#	    $fey->stringRotate(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black, $degrees);
#	    $fey->stringFT($black, gdMediumBoldFont, 4, $degrees, $position_x, $position_y, $seq[$c]);
	    $fey->char(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black);
	}
    }
    my $output = $me->Picture_Filename(type => 'cfeynman');
    open(OUT, ">$output");
    binmode OUT;
    print OUT $fey->svg;
    close OUT;
    my $command = qq(sed 's/font=\"Helvetica\"/font-family="Courier New"/g' ${output} > ${output}.tmp);
    system($command);
    $command = qq(mv ${output}.tmp ${output});
    system($command);
    
    return(\%return_position);
}

sub Make_Struct {
    my $initial = shift;
    my $new = {};
    foreach my $k (keys %$initial) {
	foreach my $l (keys %{$initial->{$k}}) {
	    $new->{$k}->{$l} = $initial->{$k}->{$l};
	}
    }
    foreach my $k (keys %{$new}) {
	next if (!defined($new->{$k}->{paired}));
	my $other = $new->{$k}->{paired};
	my $half_way_x = ($new->{$k}->{x} + $new->{$other}->{x}) / 2;
	my $half_way_y = ($new->{$k}->{x} + $new->{$other}->{y}) / 2;
    }
    
    return($new);
}

sub Get_PPCC {
    my $me = shift;
    my @values = @{$me->{list_data}};
    for my $c (0 .. $#values) {
	if (!defined($values[$c])) {
	    $values[$c] = 0;
	}
    }
    my @sorted = sort {$a <=> $b} @values;
    my $n = scalar(@values);
    my $xbar = mean(\@values);
    my $xvar = variance(\@values);
    my $xstddev = stddev(\@values);
    $xbar = sprintf("%.2f",$xbar->query);
    $xvar = sprintf("%.2f",$xvar->query);
    $xstddev = sprintf("%.2f",$xstddev->query);
    # get P(X) for each values
    my @PofX = ();
    foreach my $x (@sorted) {
	next if (!defined($x));
	if ($xstddev == 0) {
	    push(@PofX, 0);
	}
	else { 
	    push(@PofX, (1 - Statistics::Distributions::uprob($x - $xbar) / $xstddev));
	}
    }
    
    #get P(X) for the standard normal distribution
    my @PofY = ();
    for (my $i = 1 ; $i < $n + 1 ; $i++) {
	my $new_value = $i / ($n + 1);
	push(@PofY, $new_value);
    }
    my $corr = new Statistics::Basic::Correlation(\@PofY, \@PofX);
    return($corr->query);
}

## Reimplement picture_filename so it isn't so stupid
sub Get_Filename {
    my $me = shift;

}

sub Picture_Filename {
    my $me = shift;
    my %args = @_;
    my $type = $args{type};
    my $url = $args{url};
    my $species = $args{species};
    my $suffix = $args{suffix};
    my $extension;
    my $mfe_methods = $args{mfe_methods};
    my $accession = $me->{accession};
    my $mfe_id = $me->{mfe_id};

    $mfe_methods = 'all' unless ($mfe_methods);

    if ($type =~ /\:/) {
	Callstack(die => 1, message => "Illegal name.");
    }
    if ($species and $species =~ /\:/) {
	Callstack(die => 1, message => "Illegal name.");
    }

    if ($type eq 'extension_percent') {
	return(qq"images/cloud/$species/extension-percent.png");
    }
    elsif ($type eq 'extension_codons') {
	return(qq"images/cloud/$species/extension-codons.png");
    } 
    
    if ($type =~ /feynman/) {
	$extension = '.svg'; 
    }
    else {
	$extension = '.png';
    }
    
    if (defined($species)) {
	my $tmpdir = qq"$ENV{PRFDB_HOME}/images/$type/$species";
	my $command = qq"/bin/mkdir -p $tmpdir";
	my $output = '';
	if (!-d $tmpdir) {
	    open (CMD, "$command |") or Callstack(message => qq"Could not run $command
Make sure that user $< and/or group $( has write permissions.", die => 1);
	    while (my $line = <CMD>) {
		$output .= $line;
	    }  ## End while mkdir
	    close(CMD);
	}  ## End if the directory does not exist.
	if (defined($url)) {
	    if (defined($suffix)) {
		return(qq"images/$type/$species/cloud$suffix$extension");
	    }
	    else {
		return(qq"images/$type/$species/cloud$extension");
	    }
	} else {
	    if (defined($suffix)) {
		return(qq"$ENV{PRFDB_HOME}/images/${type}/${species}/cloud${suffix}$extension");
	    }
	    else {
		return(qq"$ENV{PRFDB_HOME}/images/${type}/${species}/cloud$extension");
	    }
	}
    } ## End if defined $species

    my $directory = $me->Make_Directory($type, $url);
    my $filename;
    if (defined($mfe_id)) {
	if (defined($suffix)) {
	    $filename = qq"$directory/${accession}-${mfe_id}${suffix}$extension";
	}
	else {
	    $filename = qq"$directory/${accession}-${mfe_id}$extension";
	}
    }
    else {
	if (defined($suffix)) {
	    $filename = qq"$directory/$accession${suffix}$extension";
	}
	else {
	    $filename = qq"$directory/$accession$extension";
	}
    }
    return($filename);
}

sub jViz {
    my $me = shift;
    my %args = @_;
    my $jviz_type = $args{jviz_type};  ## classic, dotplot, feynman, cfeynman, dual_graph
    ## I think to make it easier, prefix all of these with jviz...
    my $input_filename = $args{input_file};
    my $output_filename;
    my $output =  {};

    my $pids = $me->Check_Process(process => "java");
    my $num_pids = scalar(@{$pids});
    ## sleep(5) while(scalar(@{$me->Check_Process(process => "java")}) > 0);
    while ($num_pids > 0) {
	$pids = $me->Check_Process(process => "java");
	$num_pids = scalar(@{$pids});
	sleep(5);
    }

    if ($args{output_file}) {
	$output_filename = $args{output_file};
    }
    else {
	$output_filename = $me->Picture_Filename(type => $args{jviz_type}, accession => $me->{accession});
    }

    print STDERR "The output filename is: $output_filename\n" if ($args{debug});
    unless (-r $output_filename) {
	my $db = new PRFdb(config => $config);
	my $species = $me->{species};
	my $input_name;
	if ($me->{mfe_id}) {
	    my $mfe_id = $me->{mfe_id};
	    $input_name = $db->Mfeid_to_Seq(type => 'ct', species => $species, mfeid => $mfe_id);
	} else {
	    $input_name = $input_filename;
	}
	my $basename = basename($input_name);
	my $xvfb_xauth = qq"$ENV{PRFDB_HOME}/folds/${basename}-auth";
	my $type_flag = '';
	my $suffix = $jviz_type;
	$suffix =~ s/jviz_//g;
	## classic, dotplot, feynman, cfeynman, dual_graph
	if ($jviz_type eq 'jviz_classic_structure') {
	    $type_flag = '-C';
	}
	elsif ($jviz_type eq 'jviz_dot_plot') {
	    $type_flag = '-d';
	}
	elsif ($jviz_type eq 'jviz_linked_graph') {
	    $type_flag = '-l';
	}
	elsif ($jviz_type eq 'jviz_circle_graph') {
	    $type_flag = '-c';
	}
	elsif ($jviz_type eq 'jviz_dual_graph') {
	    $type_flag = '-g';
	}
	else {
	    $type_flag = '-C';
	    $suffix = 'classic_structure';
	}

	my $jviz_command = qq"cd $ENV{PRFDB_HOME}/folds && $ENV{PRFDB_HOME}/bin/xvfb-run -f ${basename}-auth -a /usr/bin/java -jar $ENV{PRFDB_HOME}/bin/jViz.jar -t $type_flag -f png ${basename} 2>${basename}.out 1>&2";
	print STDERR "DEBUG: Running $jviz_command\n" if ($args{debug});
	system($jviz_command);
	my $move_command = qq"cd $ENV{PRFDB_HOME}/folds && /bin/mv ${basename}-${suffix}.png $output_filename";
	print STDERR "MOVE: $move_command\n" if ($args{debug});
	system($move_command);
	$output_filename = qq"${basename}-${suffix}.png";
	my $remove = qq"/bin/rm $ENV{PRFDB_HOME}/folds/${basename}-auth";
	system($remove);

    } ## End unless the file already exists

    $output->{path} = $output_filename;
    $output->{filename} = basename($output_filename);
    return($output);
}


sub Check_Process {
    my ($me, %args) = @_;
    my $process = $args{process};
    my $command = qq"/bin/ps -C $process -o pid=";
    open(TEST, "$command |") or Callstack("Could not run $command $!");
    my @pids = ();
    while (my $line = <TEST>) {
	chomp $line;
	push(@pids, $line);
    }
    return(\@pids);
}




sub Make_Directory {
    my $me = shift;
    my $type = shift;
    my $url = shift;
    my $species = shift;
    my $dir = '';
    my $accession = $me->{accession};
    my $nums = $accession;
    if ($nums =~ /^NC_/) {  ## Then it is a genome and we should be looking at the numbers following the accession
	my ($before, $after) = split(/\-/, $nums);
	$nums = $after;
    }
    $nums =~ s/\W//g;
    $nums =~ s/[a-z]//g;
    $nums =~ s/[A-Z]//g;
    $nums =~ s/_//g;
    my @cheat = split(//, $nums);

    if (defined($url)) {
	my $ret_url = "images/$type/";
#	while (my $num = shift(@cheat)) {
#	    $ret_url .= "$num/";
#	}
	foreach my $n (@cheat) {
	    $ret_url .= "$n/";
	}
	$ret_url =~ s/\/$//g;
	return($ret_url);
    }
    
    my $directory;
    if (defined($species)) {
	$directory = qq($ENV{PRFDB_HOME}/images/$type/$species);
    }
    else {
	$directory = qq"$ENV{PRFDB_HOME}/images/$type/";
	my @cheat_again = split(//, $nums);
	foreach my $n (@cheat_again) {
	    $directory .= "$n/";
	}
	$directory =~ s/\/$//g;
    	my $command = qq(/bin/mkdir -p $directory);
	my $output = '';
	if (!-r $directory) {
	    open (CMD, "$command |") or Callstack(message => qq"Could not run $command
Make sure that user $< and/or group $( has write permissions.");
	    while (my $line = <CMD>) {
		$output .= $line;
	    }  ## End while mkdir
	    close(CMD);
	}  ## End if the directory does not exist.
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

sub Get_Feynman_ImageSize {
    my $me = shift;
    my $filename = shift;
    open(IN, "<$filename");
    my($svg, $height, $width, $stuff);
    while(my $line = <IN>) {
	next unless ($line =~ /^\<svg/);
	($svg, $height, $width, $stuff) = split(/\s+/, $line);
	$height =~ s/height="(\d+).*/$1/g;
        $width =~ s/width="(\d+).*/$1/g;
	last;
    }
    close(IN);
    my $ret = {};
    $ret->{height} = $height + 1; ### To correct for truncated decimal points in the svg file
    $ret->{width} = $width + 1;   ## Because we hate those god damn scroll bars so very much
    return($ret);
}

1;
