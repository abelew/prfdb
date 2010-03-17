package PRFGraph;
use strict;
use constant PI => scalar(4 * atan2 1, 1);
use DBI;
use PRFConfig qw / PRF_Error PRF_Out /;
use PRFdb;
use GD::Graph::mixed;
use GD::SVG;
use Statistics::Basic qw(:all);
use Statistics::Distributions;
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
    return ($me);
}

sub deg2rad {PI * $_[0] / 180}

sub Make_Extension {
    my $me = shift;
    my $species = shift;
    my $filename = shift;
    my $type = shift;
    my $url_base = shift;
    $species = 'saccharomyces_cerevisiae' unless (defined($species));
    my $db = new PRFdb(config => $config);
    ## UNDEF VALUES this statement is pulling up undefined values...
    my $averages = qq"SELECT avg_mfe, avg_zscore, stddev_mfe, stddev_zscore FROM stats WHERE species = '$species' AND seqlength = '100' AND algorithm = 'nupack'";
    my $averages_fun = $db->MySelect($averages);
    my $avg_mfe = $averages_fun->[0]->[0];
    my $avg_zscore = $averages_fun->[0]->[1];
    my $mfe_minus_stdev = $avg_mfe - $averages_fun->[0]->[2];
    my $zscore_minus_stdev = $avg_zscore - $averages_fun->[0]->[3];
    my $radius = 4;
    my $graph = new GD::Graph::points('800','800');
    $graph->set(bgclr => 'white');
    if ($type eq 'percent') {
	$graph->set(y_max_value=>150);
	$graph->set(y_label=>'-1 frame extension in percent');
    } elsif ($type eq 'codons') {
	$graph->set(y_max_value=>150);
	$graph->set(y_label=> '-1 frame extension in codons');
    } else {
	$graph->set(y_max_value=>200);
	$graph->set(y_label=>'testme');
    }
    $graph->set(x_label=>'Percentage ORF');
    $graph->set(y_min_value=>0);
    $graph->set(y_ticks=>1);
    $graph->set(y_tick_number=>10);
    $graph->set(y_tick_offset=>2);
    $graph->set(y_label_skip=>2);
    $graph->set(x_min_value=>0);
    $graph->set(x_max_value=>100);
    $graph->set(x_ticks=>1);
    $graph->set(x_tick_number=>10);
    $graph->set(x_label_skip=>2);
    $graph->set(x_tick_offset=>2);
    $graph->set(markers=> [7,7]);
    $graph->set(marker_size=> 0);
    $graph->set(bgclr => 'white');
    $graph->set(dclrs => [qw(black black)]);
    $graph->set_legend_font("$config->{base}/fonts/$config->{graph_font}", 12);
    $graph->set_x_axis_font("$config->{base}/fonts/$config->{graph_font}", 12);
    $graph->set_x_label_font("$config->{base}/fonts/$config->{graph_font}",12);
    $graph->set_y_axis_font("$config->{base}/fonts/$config->{graph_font}", 12);
    $graph->set_y_label_font("$config->{base}/fonts/$config->{graph_font}",12);
#    my $fun = [[0,0,0,[0,0,0]];
    my $fun = [[0,0,0],[0,100,0]];
    my $gd = $graph->plot($fun) or die ($graph->error);
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
    my $stmt = qq"SELECT DISTINCT mfe.id, mfe.accession, mfe.start, gene_info.orf_start, gene_info.orf_stop, gene_seq.mrna_seq, mfe.bp_mstop, mfe.mfe FROM gene_info,gene_seq,mfe WHERE gene_info.id = gene_seq.id AND mfe.genome_id = gene_info.id AND mfe.seqlength='100' AND mfe.algorithm = 'nupack' AND mfe.species = '$species'";
    my $stuff = $db->MySelect({statement => $stmt,});
    
    open(MAP, ">${filename}.map") or die("Unable to open the map file ${filename}.map");
    my $map_string = '';
    if ($type eq 'percent') {
	$map_string = qq/<map name="percent_extension" id="percent_extension">\n/;
    } elsif ($type eq 'codons') {
	$map_string = qq/<map name="codons_extension" id="codons_extension">\n/;
    } else {
	$map_string = "uhh what?\n";
    }
    print MAP $map_string;
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
	my $minus_string = '';
	$mrna_sequence =~ tr/Tt/Uu/;
	my @seq = split(//, $mrna_sequence);
	my $stop_count = 0;
	if (($orf_start % 3) == 0) {
	    $stop_count = 1;
	} elsif (($orf_start % 3) == 1) {
	    $stop_count = 2;
	} elsif (($orf_start % 3) == 2) {
	    $stop_count = 0;
	} else {
	    die "WTF?";
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
	      } else {
		  $minus_string .= $codon;
	      }
	      $codon = $seq[$c];
	      ## if on a third base of the -1 frame
	  } else {
	      $codon .= $seq[$c];
	  }
      } ## End foreach character of the sequence
	my $extension_length = length($minus_string);
	$extension_length = $extension_length - 5;
	my $minus_codons = ($extension_length / 3) * 5;
	if (!defined($bp_minus_stop)) {
	    my $stmt = qq"UPDATE mfe SET bp_mstop = '$extension_length' WHERE id = '$mfeid'";
	    $db->MyExecute($stmt);
	}
	my $x_percentage = sprintf("%.2f", 100.0 *($start - $orf_start) / ($orf_stop - $orf_start));
	my $y_percentage = sprintf("%.2f", 100.0 * (($extension_length + $start) - $orf_start) / ($orf_stop - $orf_start));
	my $color;
	## UNDEF VALUES HERE
	print "TESTME BIG TEST: zscore: $zscore avgz: $avg_zscore mfe: $mfe avgm: $avg_mfe<br>\n";
	if (($zscore < $avg_zscore) and ($mfe < $avg_mfe)) {
	    $color = $gd->colorResolve(191,0,0);  ## Red
	} elsif (($zscore >= $avg_zscore) and ($mfe < $avg_mfe)) {
	    $color = $gd->colorResolve(0,191,0);  ## Green, I think
	} elsif (($zscore < $avg_zscore) and ($mfe >= $avg_mfe)) {
	    $color = $gd->colorResolve(0,0,191);
	} else {
	    $color = $gd->colorResolve(165,165,165);
	}
	my $x_coord = sprintf("%.2f", (($x_range / 100) * $x_percentage + $left_x_coord));
	my $percent_y_coord = sprintf("%.2f", ((($y_range / 130) * (130 - $y_percentage)) + $bottom_y_coord));
	my $codons_y_coord = sprintf("%.2f", ($y_range - $minus_codons) + $bottom_y_coord);
	my $url = qq"/browse.html?short=1&accession=$accession";
	if ($type eq 'percent') {
	    $map_string = qq/<area shape="circle" coords="${x_coord},${percent_y_coord},$radius" href="${url}" title="$accession, mfe: $avg_mfe z: $avg_zscore">\n/;
	    $gd->filledArc($x_coord, $percent_y_coord, 4,4,0,360,$color,4);
	} elsif ($type eq 'codons') {
	    $map_string = qq/<area shape="circle" coords="${x_coord},${codons_y_coord},$radius" href="${url}" title="$accession">\n/;
	    $gd->filledArc($x_coord, $codons_y_coord, 4,4,0,360,$color,4);
	} else {
	    die("Type is non-specified");
	}
	print MAP $map_string;
    }  ## End foreach stuff
    open(IMG, ">$filename") or die "error opening file to write image: $!";
    binmode IMG;
    print IMG $gd->png;
    close IMG;
    print MAP "</map>\n";
    close MAP;
    system("/usr/bin/uniq ${filename}.map > e");
    system("/bin/mv e ${filename}.map");
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
    
    my $graph = new GD::Graph::points('800','800');
    my $db = new PRFdb(config => $config);
    my ($mfe_min_value, $mfe_max_value);
    if ($species eq 'all') {
	$mfe_min_value = $db->MySelect(statement => qq/SELECT min(mfe) FROM mfe/, type => 'single');
	$mfe_max_value = $db->MySelect(statement => qq/SELECT max(mfe) FROM mfe/, type => 'single');
    } else {
	$mfe_min_value = $db->MySelect(statement => qq/SELECT min(mfe) FROM mfe WHERE species = '$species'/, type => 'single');
	$mfe_max_value = $db->MySelect(statement => qq/SELECT max(mfe) FROM mfe WHERE species = '$species'/, type => 'single');
    }
    $mfe_min_value -= 3.0;
    $mfe_max_value += 3.0;
    my $z_min_value = -10;
    my $z_max_value = 5;
    $graph->set(bgclr => 'white', x_min_value => $mfe_min_value, x_max_value => $mfe_max_value,
		x_ticks => 1, x_label => 'MFE', x_labels_vertical => 1,
		x_label_skip => 0, x_number_format => "%.1f", x_tick_number => 20,
		x_all_ticks => 1, y_min_value => $z_min_value, y_max_value => $z_max_value,
		y_ticks => 1, y_label => 'Zscore', y_label_skip => 0,
		y_number_format => "%.2f", y_tick_number => 20, y_all_ticks => 1,
		dclrs => ['black','black'], marker_size => 0,);
    $graph->set_legend_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_axis_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_label_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_axis_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_label_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    my $fun = [[-100,-100,-100],[0,0,0]];
    my $gd = $graph->plot($fun,) or die ($graph->error);
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
    
    foreach my $point (@{$data}) {
	my $x_point = sprintf("%.1f",$point->[0]);
	my $y_point = sprintf("%.2f",$point->[1]);
	#print "MFE_value: $x_point Zscore: $y_point<br>\n";
	if (defined($points->{$x_point}->{$y_point})) {
	    $points->{$x_point}->{$y_point}->{count}++;
	    $points->{$x_point}->{$y_point}->{accessions} .= " $point->[2]";
	    $points->{$x_point}->{$y_point}->{genenames} .= " ; $point->[6]";
	    $points->{$x_point}->{$y_point}->{knotted} += $point->[3];
	    if ($max_counter < $points->{$x_point}->{$y_point}->{count}) {
		$max_counter = $points->{$x_point}->{$y_point}->{count};
	    }
	} else {
	    $points->{$x_point}->{$y_point}->{count} = 1;
	    $points->{$x_point}->{$y_point}->{accessions} = $point->[2];
	    $points->{$x_point}->{$y_point}->{genenames} = $point->[6];
	    $points->{$x_point}->{$y_point}->{knotted} = $point->[3];
	    $points->{$x_point}->{$y_point}->{start} = $point->[5];
	}
    }
    
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
	    } elsif ($x_coord < $average_mfe_coord) {
		$color = $gd->colorResolve(0,$color_value,0);
		# print " C: green<br>\n";
	    } elsif ($y_coord > $average_z_coord) {
		$color = $gd->colorResolve(0,0,$color_value);
		# print " C: blue<br>\n";
	    } elsif (($x_coord > $average_mfe_coord) and ($y_coord < $average_z_coord)) {
		$color = $gd->colorResolve($color_value,$color_value,$color_value);
		# print " C: grey<br>\n";
	    } else {
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
    my %slipsites_numbers = ();
    my %slips_significant = ();
    open(MAP, ">${tmp_filename}.map") or die("Unable to open the map file ${tmp_filename}.map");
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
		} else {
		    if (defined($pknot)) {
			$image_map_string = qq(<area shape="circle" coords="${x_coord},${y_coord},$radius" href="/cloud_mfe_z.html?pknot=1&seqlength=${seqlength}&species=${species}&mfe=${x_point}&z=${y_point}" title="$genenames">\n);
		    } else {
			$image_map_string = qq(<area shape="circle" coords="${x_coord},${y_coord},$radius" href="/cloud_mfe_z.html?seqlength=${seqlength}&species=${species}&mfe=${x_point}&z=${y_point}" title="$genenames">\n);
		    }
		}
		print MAP $image_map_string;
	    }
	}
    } else {
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
		    if ($slipsite =~ /^AAA....$/) {
			$slips_significant{$slipsite}{color} = 'red';
		    } elsif ($slipsite =~ /^UUU....$/) {
			$slips_significant{$slipsite}{color} = 'green';
		    } elsif ($slipsite =~ /^GGG....$/) {
			$slips_significant{$slipsite}{color} = 'blue';
		    } elsif ($slipsite =~ /^CCC....$/) {
			$slips_significant{$slipsite}{color} = 'black';
		    } else {
			#warn("This sucks. $slipsite doesn't match");
			next;
		    }
		} else {
		    $slips_significant{$slipsite}{num}++;
		}
	    }
	    
	    if (!defined($slipsites_numbers{$slipsite})) {
		$slipsites_numbers{$slipsite}{num} = 1;
		if ($slipsite =~ /^AAA....$/) {
		    $slipsites_numbers{$slipsite}{color} = 'red';
		} elsif ($slipsite =~ /^UUU....$/) {
		    $slipsites_numbers{$slipsite}{color} = 'green';
		} elsif ($slipsite =~ /^GGG....$/) {
		    $slipsites_numbers{$slipsite}{color} = 'blue';
		} elsif ($slipsite =~ /^CCC....$/) {
		    $slipsites_numbers{$slipsite}{color} = 'black';
		} else {
		    #warn("This sucks. $slipsite doesn't match the expected");
		    next;
		}
	    } else {
		$slipsites_numbers{$slipsite}{num}++;
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
		} else {
		    if (defined($pknot)) {
			$image_map_string = qq(<area shape="circle" coords="${x_coord},${y_coord},$radius" href="/cloud_mfe_z.html?seqlength=${seqlength}&slipsite=$args_slipsites&pknot=1&species=${species}&mfe=${x_point}&z=${y_point}" title="$genenames">\n;);
		    } else {
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
    $gd->filledRectangle($mfe_significant_coord, $z_significant_coord, $mfe_significant_coord, $top_y_coord, $darkslategray);
    $gd->filledRectangle($left_x_coord, $z_significant_coord, $mfe_significant_coord, $z_significant_coord, $darkslategray);
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
	    $percent_sig{$slip}{num} = 0;
	}
	$percent_sig{$slip}{num} = (($slips_significant{$slip}{num} / $slipsites_numbers{$slip}{num}) * 100.0);
	$percent_sig{$slip}{num} = sprintf("%.1f", $percent_sig{$slip}{num});
	$percent_sig{$slip}{color} = $slips_significant{$slip}{color};
    }
    if (defined($args_slipsites) and $args_slipsites ne 'all') {
	Make_SlipBars(\%slipsites_numbers, $bar_filename);
	Make_SlipBars(\%slips_significant, $bar_sig_filename);
	Make_SlipBars(\%percent_sig, $percent_sig_filename);
    }
    open (IMG, ">$filename") or die "error opening $filename to write image: $!";
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
    my $mfe_min_value = $db->MySelect({statement => qq/SELECT min(mfe) FROM mfe WHERE species = '$species'/, type => 'single'});
    my $mfe_max_value = $db->MySelect({statement => qq/SELECT max(mfe) FROM mfe WHERE species = '$species'/, type => 'single'});
    $mfe_min_value -= 3.0;
    $mfe_max_value += 3.0;
    my $z_min_value = -10;
    my $z_max_value = 5;
    $graph->set(transparent => 1,x_min_value => $mfe_min_value, x_max_value => $mfe_max_value,
		x_ticks => 1, x_label => 'MFE', x_labels_vertical => 1,
		x_label_skip => 0, x_number_format => "%.1f", x_tick_number => 20,
		x_all_ticks => 1, y_min_value => $z_min_value, y_max_value => $z_max_value,
		y_ticks => 1, y_label => 'Zscore', y_label_skip => 0,
		y_number_format => "%.2f", y_tick_number => 20, y_all_ticks => 1,
		dclrs => ['black','black'], marker_size => 0,);
    $graph->set_legend_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_axis_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_label_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_axis_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_label_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    my $fun = [[-100,-100,-100],[0,0,0]];
    my $gd = $graph->plot($fun,) or die ($graph->error);
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

    open(MAP, ">$map_filename") or die("Unable to open the map file $map_filename: $!");
    print MAP "<map name=\"overlaymap\" id=\"overlaymap\">\n";

    my $radius = 6;
    foreach my $point (@{$data}) {
	my $x_point = sprintf("%.1f",$point->[0]);
	my $y_point = sprintf("%.1f",$point->[1]);
	my $slipstart = $point->[2];
	my $algorithm = $point->[3];
	my $x_coord = sprintf("%.1f",((($x_range/$mfe_range)*($x_point - $mfe_min_value)) + $left_x_coord));
	my $y_coord = sprintf("%.1f",((($y_range/$z_range)*($z_max_value - $y_point)) + $bottom_y_coord));
	$x_coord = sprintf('%.0f', $x_coord);
	$y_coord = sprintf('%.0f', $y_coord);
	$gd->filledArc($x_coord, $y_coord, $radius, $radius, 0, 360, $black, 4);
	my $map_string = qq(<area shape="circle" coords="${x_coord},${y_coord},$radius" href="/detail.html?short=1&accession=$accession&slipstart=$slipstart" title="Position $slipstart of $accession ($inputstring) using $algorithm">\n);
        print MAP $map_string;
    }
    print MAP "</map>\n";
    open (IMG, ">$filename") or die "error opening $filename to write image: $!";
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
    foreach my $k (sort { $numbers->{$b}{num} <=> $numbers->{$a}{num} } keys %{$numbers}) {
#    foreach my $k (sort  keys %{$numbers}) {
	$color_string .= "$numbers->{$k}{color} ";
	push (@colors, $numbers->{$k}{color});
	push (@keys, $k);
	push (@values, $numbers->{$k}{num});
    }
    my @data = (\@keys, \@values);
    my $bargraph = new GD::Graph::bars(700,400);
    $bargraph->set(x_label => 'slipsite', y_label => 'number', title => 'How many of each slipsite',
		   dclrs => [ qw(blue black red green) ], cycle_clrs => 1, dclrs => \@colors,
		   show_values => 1, values_vertical => 1, x_labels_vertical => 1,
		   y_max_value => $values[0],);
    #	dclrs => [ qw($color_string) ],
    $bargraph->set_legend_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $bargraph->set_x_axis_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $bargraph->set_x_label_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $bargraph->set_y_axis_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $bargraph->set_y_label_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    my $image = $bargraph->plot(\@data);
    open(IMG, ">$filename");
    print IMG $image->png if (defined($image));
    close IMG;
}

sub Make_Landscape {
    my $me = shift;
    my $species = shift;
    my $accession = $me->{accession};
    my $filename = $me->Picture_Filename(type => 'landscape',);
    my $table = "landscape_$species";
    system("touch $filename");
    my $db = new PRFdb(config=>$config);
    my $data = $db->MySelect("SELECT start, algorithm, pairs, mfe FROM $table WHERE accession='$accession' ORDER BY start, algorithm");
    return(undef) if (!defined($data));
    my $slipsites = $db->MySelect("SELECT distinct(start) FROM mfe WHERE accession='$accession' ORDER BY start");
    my $start_stop = $db->MySelect("SELECT orf_start, orf_stop FROM gene_info WHERE accession = '$accession'");
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
	} elsif ($datum->[1] eq 'nupack') {
	    $info->{$place}->{nupack} = $datum->[3];
	    $mean_nupack = $mean_nupack + $datum->[3];
	} elsif ($datum->[1] eq 'vienna') {
	    $info->{$place}->{vienna} = $datum->[3];
	    $mean_vienna = $mean_vienna + $datum->[3];
	}
    }    ## End foreach spot
    if ($position_counter == 0) {  ## There is no data!?
	return(undef);
	print STDERR "There is no data\n";
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
	} else {
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
    $graph->set(bgclr => 'white', x_label => 'Distance on ORF', y_label => 'kcal/mol',
		y_label_skip => 2, y_number_format => "%.2f", x_labels_vertical => 1,
		x_label_skip => 100, line_width => 2, dclrs => [qw(blue red green blue red green)],
		default_type => 'lines', types => [qw(lines lines lines lines lines lines)],) or die $graph->error;
    $graph->set_legend_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_axis_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_label_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_axis_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_label_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    my $gd = $graph->plot(\@mfe_data) or die($graph->error);
    
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

    open(IMG, ">$filename") or die $!;
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
	} else {
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
		dclrs => [qw(blue red green black)], borderclrs => [qw(black)]) or die $graph->error;
    
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
    my $x_interval_pixels = ($bottom_x_coord - $top_x_coord)/($num_bins + 2);
    my $mfe_x_coord = $top_x_coord + ($x_interval_pixels) + (($real_mfe - $min) * ($x_interval_pixels/$x_interval));
    my $mfe_xbar_coord = $top_x_coord + ($x_interval_pixels) + (($xbar - $min) * ($x_interval_pixels/$x_interval));
    my $green = $gd->colorAllocate(0,191,0);
    $gd->filledRectangle($mfe_x_coord, $bottom_y_coord+1 , $mfe_x_coord+1, $top_y_coord-1, $green);
    my $bl = $gd->colorAllocate(0,0,0);
    $gd->filledRectangle($mfe_xbar_coord, $bottom_y_coord+1 , $mfe_xbar_coord+1, $top_y_coord-1, $bl);
    my $filename = $me->Picture_Filename(type => 'distribution');
    open(IMG, ">$filename") or die ("Unable to open $filename $!");
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
    } else {
	$id = $me->{mfe_id};
	my $db = new PRFdb(config=>$config);
	my $stmt = qq(SELECT sequence, slipsite, parsed, output FROM mfe WHERE id = ?);
	my $info = $db->MySelect({statement => $stmt, vars => [$id], type => 'row' });
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
	    } elsif ($stems[$c] eq '.') {
		$fey->char(gdMediumBoldFont, $character_x, $character_y, $seq[$c], $black);
	    }
	} elsif ($paired[$c] =~ /\d+/) {
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
	} else {
### Why are there spaces?
#	    print "Crap in a hat the character is $paired[$c]\n";
	    $fey->char(gdMediumBoldFont, $character_x, $character_y, $seq[$c], $black);
	}
	$character_x = $character_x + 8;
    }
    my $output;
    if(defined($out_filename)) {
	$output = $out_filename;
    } else {
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
    my $ids = $me->{ids};
    my $db = new PRFdb(config=>$config);
    my $stmt = qq"SELECT sequence, slipsite, parsed, output, algorithm FROM mfe WHERE id = ? or id = ? or id = ?";
    my $info = $db->MySelect(statement => $stmt, vars => [$ids->[0], $ids->[1], $ids->[2]],);
    my $sequence = $info->[0]->[0];
    $slipsite = $info->[0]->[1];
    my (@parsed, @pkout, @algorithm);
    my @seq = split(//, $sequence);
    foreach my $datum (@{$info}) {
	push(@parsed, $datum->[2]);
	push(@pkout, $datum->[3]);
	push(@algorithm, $datum->[4]);
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
	for my $d (0 .. $#pkout) {   ## The 3 or so algorithms available
	    my @pktmp = split(/\s+/, $pkout[$d]);
	    my @patmp = split(/\s+/, $parsed[$d]);
	    next LOOP if (!defined($pktmp[$c]));
	    $struct->{$c}->{$algorithm[$d]}->{partner} = $pktmp[$c];
	    $patmp[$c] = '.' if (!defined($patmp[$c]));
	    $struct->{$c}->{$algorithm[$d]}->{stemnum} = $patmp[$c];
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
	} elsif (!defined($h)) {
	    print "h not defined\n";
	    next;
	} elsif (!defined($p)) {
	    print "$p not defined\n";
	    next;
	}

#	sleep(1);
	if ($struct->{$c}->{hotknots}->{partner} eq '.' and $struct->{$c}->{pknots}->{partner} eq '.' and $struct->{$c}->{nupack}->{partner} eq '.') {
	    $agree->{none}++;
	    $comp->{$c}->{partner} = ['.'];
	    $comp->{$c}->{color} = [0];
	    ## Nothing is 0
	} elsif (($n eq $h) and ($n eq $p)) {
	    $agree->{all}++;
	    $comp->{$c}->{partner} = [$n];
	    $comp->{$c}->{color} = [1];
	    ## All 3 same is 1
	} elsif (($n ne $h) and ($n ne $p)) {
	    $agree->{hnp}++;
	    $comp->{$c}->{partner} = [$n,$h,$p];
	    $comp->{$c}->{color} = [2,3,4];
	    ## nupack is 2
	    ## hotknots is 3
	    ## pknots is 4
	} elsif ($n eq '.' and $h eq '.') {
	    $agree->{p}++;
	    $comp->{$c}->{partner} = [$p];
	    $comp->{$c}->{color} = [4];
	} elsif ($n eq '.' and $p eq '.') {
	    $agree->{h}++;
	    $comp->{$c}->{partner} = [$h];
	    $comp->{$c}->{color} = [3];
	} elsif ($h eq '.' and $p eq '.') {
	    $agree->{n}++;
	    $comp->{$c}->{partner} = [$n];
	    $comp->{$c}->{color} = [2];
	} elsif ($n eq '.') {
	    $agree->{hp}++;
	    if ($h eq $p) {
		$comp->{$c}->{partner} = [$h];
		$comp->{$c}->{color} = [5];
		## hotknots+pknots is 5
	    } else {
		$comp->{$c}->{partner} = [$h,$p];
		$comp->{$c}->{color} = [3,4];
	    }
	} elsif ($h eq '.') {
	    $agree->{np}++;
	    if ($n eq $p) {
		$comp->{$c}->{partner} = [$n];
		$comp->{$c}->{color} = [6];
		## nupack+pknots is 6
	    } else {
		$comp->{$c}->{partner} = [$n,$p];
		$comp->{$c}->{color} = [2,4];
	    }
	} elsif ($p eq '.') {
	    $agree->{hn}++;
	    if ($h eq $n) {
		$comp->{$c}->{partner} = [$h];
		$comp->{$c}->{color} = [7];
		## hotknots+nupack is 7
	    } else {
		$comp->{$c}->{partner} = [$h,$n];
		$comp->{$c}->{color} = [2,3];
	    }
	} elsif ($n eq $p) {
	    $agree->{hnp}++;
#	    $comp->{$c}->{partner} = [$n,$h];
#	    $comp->{$c}->{color} = [6,3];
	    $comp->{$c}->{partner} = [$h,$n];
	    $comp->{$c}->{color} = [3,6];
	} elsif ($n eq $h) {
	    $agree->{hnp}++;
#	    $comp->{$c}->{partner} = [$n,$p];
#	    $comp->{$c}->{color} = [7,4];
	    $comp->{$c}->{partner} = [$p,$n];
	    $comp->{$c}->{color} = [4,7];
	} elsif ($p eq $h) {
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
    } else {
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
    my $stmt = qq"SELECT sequence, parsed, output FROM mfe WHERE id = ?";
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
	    } elsif ($stems[$c] eq '.') {
#		$fey->stringRotate(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black, $degrees);
#		$fey->stringFT($black, gdMediumBoldFont, 4, $degrees, $position_x, $position_y, $seq[$c]);
		$fey->char(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black);
	    }
	} elsif ($paired[$c] =~ /\d+/) {
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
	} else { ### Why are there spaces?
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
    my $stmt = qq"SELECT sequence, parsed, output FROM mfe WHERE id = ?";
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
	    } elsif ($stems[$c] eq '.') {
#		$fey->stringRotate(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black, $degrees);
#		$fey->stringFT($black, gdMediumBoldFont, 4, $degrees, $position_x, $position_y, $seq[$c]);
		$fey->char(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black);
	    }
	} elsif ($paired[$c] =~ /\d+/) {
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
	} else { ### Why are there spaces?
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
	} else { 
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
    return ($corr->query);
}

sub Picture_Filename {
    my $me = shift;
    my %args = @_;
    my $type = $args{type};
    my $url = $args{url};
    my $species = $args{species};
    my $suffix = $args{suffix};
    my $extension;    
    my $accession = $me->{accession};
    my $mfe_id = $me->{mfe_id};

    if ($type eq 'extension_percent') {
	return(qq"images/cloud/$species/extension-percent.png");
    } elsif ($type eq 'extension_codons') {
	return(qq"images/cloud/$species/extension-codons.png");
    } 
    
    if ($type =~ /feynman/) {
	$extension = '.svg'; 
    }
    else {
	$extension = '.png';
    }
    
    if (defined($species)) {
	my $tmpdir = qq"$config->{base}/images/$type/$species";
	my $command = qq"/bin/mkdir -p $tmpdir";
	my $output = '';
	if (!-d $tmpdir) {
	    open (CMD, "$command |") or die("Could not run $command
Make sure that user $< and/or group $( has write permissions: $!");
	    while (my $line = <CMD>) {
		$output .= $line;
	    }  ## End while mkdir
	    close(CMD);
	}  ## End if the directory does not exist.
	if (defined($url)) {
	    if (defined($suffix)) {
		return(qq"images/$type/$species/cloud$suffix$extension");
	    } else {
		return(qq"images/$type/$species/cloud$extension");
	    }
	} else {
	    if (defined($suffix)) {
		return(qq"$config->{base}/images/${type}/${species}/cloud${suffix}$extension");
	    } else {
		return(qq"$config->{base}/images/${type}/${species}/cloud$extension");
	    }
	}
    } ## End if defined $species
    my $directory = $me->Make_Directory($type, $url);
    my $filename;
    if (defined($mfe_id)) {
	if (defined($suffix)) {
	    $filename = qq"$directory/${accession}-${mfe_id}${suffix}$extension";
	} else {
	    $filename = qq"$directory/${accession}-${mfe_id}$extension";
	}
    } else {
	if (defined($suffix)) {
	    $filename = qq"$directory/$accession${suffix}$extension";
	} else {
	    $filename = qq"$directory/$accession$extension";
	}
    }
    return ($filename);
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
	while (my $num = shift(@cheat)) {
	    $ret_url .= "$num/";
	}
	$ret_url =~ s/\/$//g;
#	print "TESTME URL Make_Directory: $ret_url<br>\n";
	return($ret_url);
    }
    
    my $directory;
    if (defined($species)) {
	$directory = qq($config->{base}/images/$type/$species);
    } else {
	$directory = qq"$config->{base}/images/$type/";
	my @cheat_again = split(//, $nums);
	while (my $num = shift(@cheat_again)) {
	    $directory .= "$num/";
	}
	$directory =~ s/\/$//g;
    	my $command = qq(/bin/mkdir -p $directory);
	my $output = '';
	if (!-r $directory) {
	    open (CMD, "$command |") or die("Could not run $command
Make sure that user $< and/or group $( has write permissions: $!");
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
	} else {
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
