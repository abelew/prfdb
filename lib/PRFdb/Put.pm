package PRFdb::Put;
use strict;
our @ISA = qw(PRFdb);
our $AUTOLOAD;

sub Agree {
    my $me = shift;
    my %args = @_;
    my $agree = $args{agree};
    my $check = $me->MySelect(statement => "SELECT count(id) FROM agree WHERE accession = ? AND start = ? AND length = ?", vars => [$args{accession}, $args{start}, $args{length}], type => 'single');
    return(undef) if ($check >= 1);
    my $stmt = qq"INSERT DELAYED INTO agree (accession, start, length, all_agree, no_agree, n_alone, h_alone, p_alone, hplusn, nplusp, hplusp, hnp) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)";
    my $rows = $me->MyExecute(statement => $stmt,
			      vars => [$args{accession}, $args{start}, $args{length},
				       $agree->{all}, $agree->{none}, $agree->{n},
				       $agree->{h}, $agree->{p}, $agree->{hn},
				       $agree->{np}, $agree->{hp}, $agree->{hnp}],);
    return($rows);
}

sub Boot {
    my $me = shift;
    my $data = shift;
    my $config = $me->{config};
    my $id = $data->{genome_id};
    my @boot_ids = ();
    my $rows = 0;
    ## What fields are required?
    foreach my $mfe_method (keys %{$config->{boot_mfe_algorithms}}) {
	my $mfe_id = $data->{mfe_id};	
	foreach my $rand_method (keys %{$config->{boot_randomizers}}) {
	    my $iterations = $data->{$mfe_method}->{$rand_method}->{stats}->{iterations};
	    my $mfe_mean = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_mean};
	    my $mfe_sd = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_sd};
	    my $mfe_se = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_se};
	    my $pairs_mean = $data->{$mfe_method}->{$rand_method}->{stats}->{pairs_mean};
	    my $pairs_sd = $data->{$mfe_method}->{$rand_method}->{stats}->{pairs_sd};
	    my $pairs_se = $data->{$mfe_method}->{$rand_method}->{stats}->{pairs_se};
	    my $mfe_values = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_values};
	    my $species = $data->{$mfe_method}->{$rand_method}->{stats}->{species};
	    my $accession = $data->{$mfe_method}->{$rand_method}->{stats}->{accession};
	    $mfe_id = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_id};
	    my $start = $data->{$mfe_method}->{$rand_method}->{stats}->{start};
	    my $seqlength = $data->{$mfe_method}->{$rand_method}->{stats}->{seqlength};
	    my @boot = ('genome_id');
	    my $errorstring = Check_Insertion(\@boot, $data);
	    if (defined($errorstring)) {
		$errorstring = "Undefined value(s) in Put_Boot: $errorstring";
		$config->PRF_Error($errorstring, $species, $accession);
	    }
	    my $boot_table = ($species =~ /virus/ ? "boot_virus" : "boot_$species");
#	    my $statement = qq"INSERT INTO $boot_table
	    my $statement = qq"INSERT DELAYED INTO $boot_table
(genome_id, mfe_id, species, accession, start, seqlength, iterations, rand_method, mfe_method, mfe_mean, mfe_sd, mfe_se, pairs_mean, pairs_sd, pairs_se, mfe_values)
    VALUES
(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
            my $undefined_values = Check_Defined(genome_id => $data->{genome_id}, mfe_id => $mfe_id, species => $species, accession => $accession, start => $start, seqlength => $seqlength, iterations => $iterations, rand_method => $rand_method, mfe_method => $mfe_method, mfe_mean => $mfe_mean, mfe_sd => $mfe_sd, mfe_se => $mfe_se, pairs_mean => $pairs_mean, pairs_sd => $pairs_sd, pairs_se => $pairs_se, mfe_values => $mfe_values);
            if ($undefined_values) {
              $errorstring = "An error occurred in Put_Boot, undefined values: $undefined_values\n";
              $config->PRF_Error( $errorstring, $species, $accession );
              print "$errorstring, $species, $accession\n";
            }
            my $inserted_rows = $me->MyExecute(statement => $statement, vars => [ $data->{genome_id}, $mfe_id, $species, $accession, $start, $seqlength, $iterations, $rand_method, $mfe_method, $mfe_mean, $mfe_sd, $mfe_se, $pairs_mean, $pairs_sd, $pairs_se, $mfe_values ],);
            $rows = $rows + $inserted_rows;

#            my $boot_id = $me->MySelect(statement => 'SELECT LAST_INSERT_ID()', type => 'single');
#            push(@boot_ids, $boot_id);
          }    ### Foreach random method
    }    ## Foreach mfe method
#    return(\@boot_ids);
     return($rows);
}    ## End of Put_Boot

sub Hotknots {
    my $me = shift;
    my $data = shift;
    my $table = shift;
    my $mfe_id = shift;
    if (defined($table) and $table =~ /^landscape/) {
	$mfe_id = $me->Put_MFE_Landscape('hotknots', $data, $table);
    } elsif (defined($table)) {
	$mfe_id = $me->Put_MFE('hotknots', $data, $table);
    } else {
	$mfe_id = $me->Put_MFE('hotknots', $data);
    }
    return($mfe_id);
}

sub MFE {
    my $me = shift;
    my $algo = shift;
    my $data = shift;
    my $config = $me->{config};
    ## What fields do we want to fill in this MFE table?
    my @pknots = ('genome_id', 'accession', 'start', 'slipsite', 'seqlength', 'sequence', 'output', 'parsed', 'parens', 'mfe', 'pairs', 'knotp', 'barcode');
    my $errorstring = Check_Insertion(\@pknots, $data);
    if (defined($errorstring)) {
	$errorstring = "Undefined value(s) in Put_MFE: $errorstring";
	$config->PRF_Error($errorstring, $data->{species}, $data->{accession});
    }
    my $species = $data->{species};
    my $table = qq"mfe_$species";
    $data->{sequence} =~ tr/actgun/ACTGUN/;
    my $statement = qq(INSERT INTO $table (genome_id, algorithm, accession, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?));
    
    $me->MyExecute(statement => $statement, vars => [$data->{genome_id}, $data->{species}, $algo, $data->{accession}, $data->{start}, $data->{slipsite}, $data->{seqlength}, $data->{sequence}, $data->{output}, $data->{parsed}, $data->{parens}, $data->{mfe}, $data->{pairs}, $data->{knotp}, $data->{barcode}],);
    
    my $put_id = $me->MySelect(statement => 'SELECT LAST_INSERT_ID()', type => 'single');
    return ($put_id);
}    ## End of Put_MFE

sub MFE_Landscape {
    my $me = shift;
    my $algo = shift;
    my $data = shift;
    my $table = shift;
    my $config = $me->{config};
    ## What fields do we want to fill in this MFE table?
    $table = 'landscape_virus' if ($table =~ /virus/);
	
    my @filled;
    if ($algo eq 'vienna') {
	@filled = ('genome_id','species','accession','start','seqlength','sequence','parens','mfe');
    } else {
	@filled = ('genome_id', 'species', 'accession', 'start', 'seqlength', 'sequence', 'output', 'parsed', 'parens', 'mfe', 'pairs', 'knotp', 'barcode');
    }
    my $errorstring = Check_Insertion(\@filled, $data);
    if (defined($errorstring)) {
	$errorstring = "Undefined value(s) in Put_MFE_Landscape: $errorstring";
	$config->PRF_Error($errorstring, $data->{accession});
    }
    if (defined($data->{sequence})) {
	$data->{sequence} =~ tr/actgu/ACTGU/;
    } else {
	Callstack(message => qq"Sequence is not defined for Species:$data->{species}, Accession:$data->{accession}, Start:$data->{start}, Seqlength:$data->{seqlength}");
	return(undef);
    }
    my $statement = qq"INSERT DELAYED INTO $table (genome_id, species, algorithm, accession, start, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
    my $rows = $me->MyExecute(statement => $statement, vars => [$data->{genome_id}, $data->{species}, $algo, $data->{accession}, $data->{start}, $data->{seqlength}, $data->{sequence}, $data->{output}, $data->{parsed}, $data->{parens}, $data->{mfe}, $data->{pairs}, $data->{knotp}, $data->{barcode}],);
    return ($rows);
}    ## End put_mfe_landscape

sub Nupack {
    my $me = shift;
    my $data = shift;
    my $table = shift;
    my $mfe_id = shift;
    if (defined($table) and $table =~ /^landscape/) {
	$mfe_id = $me->Put_MFE_Landscape('nupack', $data, $table);
    } elsif (defined($table)) {
	$mfe_id = $me->Put_MFE('nupack', $data, $table);
    } else {
	$mfe_id = $me->Put_MFE('nupack', $data);
    }
    return($mfe_id);
}

sub Overlap {
    my $me = shift;
    my $data = shift;
    my $statement = qq(INSERT DELAYED INTO overlap
(genome_id, species, accession, start, plus_length, plus_orf, minus_length, minus_orf) VALUES
(?,?,?,?,?,?,?,?));
$me->MyExecute(statement => $statement, vars => [$data->{genome_id}, $data->{species}, $data->{accession}, $data->{start}, $data->{plus_length}, $data->{plus_orf}, $data->{minus_length}, $data->{minus_orf}],);
my $id = $data->{overlap_id};
return ($id);
}    ## End of Put_Overlap

sub Pknots {
    my $me = shift;
    my $data = shift;
    my $table = shift;
    my $mfe_id;
    if (defined($table) and $table =~ /^landscape/) {
	$mfe_id = $me->Put_MFE_Landscape('pknots', $data, $table);
    } elsif (defined($table)) {
	$mfe_id = $me->Put_MFE('pknots', $data, $table);
    } else {
	$mfe_id = $me->Put_MFE('pknots', $data);
    }
    return($mfe_id);
}



sub Single_Boot {
    my $me = shift;
    my $data = shift;
    my $mfe_method = shift;
    my $rand_method = shift;
    my $config = $me->{config};
    my $id = $data->{genome_id};
    my $mfe_id = $data->{mfe_id};
    my @boot_ids = ();
    my $iterations = $data->{$mfe_method}->{$rand_method}->{stats}->{iterations};
    my $mfe_mean = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_mean};
    my $mfe_sd = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_sd};
    my $mfe_se = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_se};
    my $pairs_mean = $data->{$mfe_method}->{$rand_method}->{stats}->{pairs_mean};
    my $pairs_sd = $data->{$mfe_method}->{$rand_method}->{stats}->{pairs_sd};
    my $pairs_se = $data->{$mfe_method}->{$rand_method}->{stats}->{pairs_se};
    my $mfe_values = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_values};
    my $species = $data->{$mfe_method}->{$rand_method}->{stats}->{species};
    my $accession = $data->{$mfe_method}->{$rand_method}->{stats}->{accession};
    $mfe_id = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_id};
    my $start = $data->{$mfe_method}->{$rand_method}->{stats}->{start};
    my $seqlength = $data->{$mfe_method}->{$rand_method}->{stats}->{seqlength};
    my @boot = ('genome_id');
    my $errorstring = Check_Insertion(\@boot, $data);
    
    if (defined($errorstring)) {
	$errorstring = "Undefined value(s) in Put_Boot: $errorstring";
	$config->PRF_Error($errorstring, $species, $accession);
    }
    my $table = ($species =~ /virus/ ? "boot_virus" : "boot_$species");
#    my $statement = qq"INSERT INTO $table
    my $statement = qq"INSERT DELAYED INTO $table
(genome_id, mfe_id, species, accession, start, seqlength, iterations, rand_method, mfe_method, mfe_mean, mfe_sd, mfe_se, pairs_mean, pairs_sd, pairs_se, mfe_values)
    VALUES
('$data->{genome_id}','$mfe_id','$species','$accession','$start','$seqlength','$iterations','$rand_method','$mfe_method','$mfe_mean','$mfe_sd','$mfe_sd','$pairs_mean','$pairs_sd','$pairs_se','$mfe_values')";

    my $undefined_values = Check_Defined(genome_id => $data->{genome_id}, mfe_id => $mfe_id, species => $species, accession => $accession, start => $start, seqlength => $seqlength, iterations => $iterations, rand_method => $rand_method, mfe_method => $mfe_method, mfe_mean => $mfe_mean, mfe_sd => $mfe_sd, mfe_se => $mfe_se, pairs_mean => $pairs_mean, pairs_sd => $pairs_sd, pairs_se => $pairs_se, mfe_values => $mfe_values);

    if ($undefined_values) {
        $errorstring = "An error occurred in Put_Boot, undefined values: $undefined_values\n";
        $config->PRF_Error($errorstring, $species, $accession);
        print "$errorstring, $species, $accession\n";
    }
    my $rows = $me->MyExecute(statement => $statement,);

#    my $boot_id = $me->MySelect(statement => 'SELECT LAST_INSERT_ID()', type => 'single');
#    print "Inserted $boot_id\n";
#    return($boot_id);
     return($rows);
}


sub Stats {
    my $me = shift;
    my $data = shift;
    my $finished = shift;
    my $inserted_rows = 0;
    $finished = [] if (!defined($finished));
    my $st_count = 0;
    my $st_total = scalar(@{$data->{species}});
    OUT: foreach my $species (@{$data->{species}}) {
	$st_count++;
	foreach my $sp (@{$finished}) {
	    next OUT if ($sp eq $species);
	}
	print "Starting Put_Stats for $species.  Number $st_count of $st_total.\n";
	my $table = ($species =~ /virus/ ? "boot_virus" : "boot_$species");
	$me->MyExecute(statement => qq"DELETE FROM stats WHERE species = '$species'");
	foreach my $seqlength (@{$data->{seqlength}}) {
	    foreach my $max_mfe (@{$data->{max_mfe}}) {
		foreach my $algorithm (@{$data->{algorithm}}) {
		    my $mfe_table = ($species =~ /virus/ ? "mfe_virus" : "mfe_$species");
		    #  0    1    2     3     4    5     6     7     8
		    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		    my $timestring = "$mon/$mday $hour:$min.$sec";
#		    print "$timestring  Now doing $species $seqlength $max_mfe $algorithm\n";
		    my $weedout_string = qq"WHERE algorithm = '$algorithm' AND seqlength = '$seqlength'";
 		    my $max_mfe = $me->MySelect(type => 'single', statement => "/* 1 of 19 */ SELECT max(mfe) FROM $mfe_table $weedout_string");
		    my $min_mfe = $me->MySelect(type => 'single', statement => "/* 2 of 19 */ SELECT min(mfe) FROM $mfe_table $weedout_string");
		    my $num_sequences = $me->MySelect(type => 'single', statement => "/* 3 of 19 */ SELECT count(id) FROM $mfe_table $weedout_string AND mfe <= '$max_mfe'");
		    my $avg_mfe = $me->MySelect(type => 'single', statement => "/* 4 of 19 */ SELECT avg(mfe) FROM $mfe_table $weedout_string AND mfe <= '$max_mfe'");
		    my $stdev_mfe = $me->MySelect(type => 'single', statement => "/* 5 of 19 */ SELECT stddev(mfe) FROM $mfe_table $weedout_string AND mfe <= '$max_mfe'");
		    my $avg_pairs = $me->MySelect(type => 'single', statement => "/* 6 of 19 */ SELECT avg(pairs) FROM $mfe_table $weedout_string AND mfe <= '$max_mfe'");
		    my $stdev_pairs = $me->MySelect(type => 'single', statement => "/* 7 of 19 */ SELECT stddev(pairs) FROM $mfe_table $weedout_string AND mfe <= '$max_mfe'");
		    my $num_sequences_noknot = $me->MySelect(type => 'single', statement => "/* 8 of 19 */ SELECT count(id) FROM $mfe_table $weedout_string AND knotp = '0' AND mfe <= '$max_mfe'");
		    my $avg_mfe_noknot = $me->MySelect(type => 'single', statement => "/* 9 of 19 */ SELECT avg(mfe) FROM $mfe_table $weedout_string AND knotp = '0' AND mfe <= '$max_mfe'");
		    my $stdev_mfe_noknot = $me->MySelect(type => 'single', statement => "/* 10 of 19 */ SELECT stddev(mfe) FROM $mfe_table $weedout_string AND knotp = '0' AND mfe <= '$max_mfe'");
		    my $avg_pairs_noknot = $me->MySelect(type => 'single', statement => "/* 11 of 19 */ SELECT avg(pairs) FROM $mfe_table $weedout_string AND knotp = '0' AND mfe <= '$max_mfe'");
		    my $stdev_pairs_noknot = $me->MySelect(type => 'single', statement => "/* 12 of 19 */ SELECT stddev(pairs) FROM $mfe_table $weedout_string AND knotp = '0' AND mfe <= '$max_mfe'");
		    my $num_sequences_knotted = $me->MySelect(type => 'single', statement => "/* 13 of 19 */ SELECT count(id) FROM $mfe_table $weedout_string AND knotp = '1' AND mfe <= '$max_mfe'");
		    my $avg_mfe_knotted = $me->MySelect(type => 'single', statement => "/* 14 of 19 */ SELECT avg(mfe) FROM $mfe_table $weedout_string AND knotp = '1' AND mfe <= '$max_mfe'");
		    my $stdev_mfe_knotted = $me->MySelect(type => 'single', statement => "/* 15 of 19 */ SELECT stddev(mfe) FROM $mfe_table $weedout_string AND knotp = '1' AND mfe <= '$max_mfe'");
		    my $avg_pairs_knotted = $me->MySelect(type => 'single', statement => "/* 16 of 19 */ SELECT avg(pairs) FROM $mfe_table $weedout_string AND knotp = '1' AND mfe <= '$max_mfe'");
		    my $stdev_pairs_knotted = $me->MySelect(type => 'single', statement => "/* 17 of 19 */ SELECT stddev(pairs) FROM $mfe_table $weedout_string AND knotp = '1' AND mfe <= '$max_mfe'");
		    my $avg_zscore = $me->MySelect(type => 'single', statement => "/* 18 of 19 */ SELECT avg(zscore) FROM $table WHERE mfe_method = '$algorithm' AND seqlength = '$seqlength'");
		    my $stdev_zscore = $me->MySelect(type => 'single', statement => "/* 19 of 19 */SELECT stddev(zscore) FROM $table WHERE mfe_method = '$algorithm' AND seqlength = '$seqlength'");
#		    print "species:$species  seqlength:$seqlength  max_mfe:$max_mfe  min_mfe:$min_mfe  algorithm:$algorithm  num_seq:$num_sequences  avg_mfe:$avg_mfe  stdev_mfe:$stdev_mfe  avg_pairs:$avg_pairs  stdev_pairs:$stdev_pairs  num_nokn:$num_sequences_noknot  avg_mfe_no:$avg_mfe_noknot  stdev_mfe_no:$stdev_mfe_noknot  avg_pairs_no:$avg_pairs_noknot  stdev_pairs_no:$stdev_pairs_noknot  num_knot:$num_sequences_knotted  avg_mfe_knot:$avg_mfe_knotted  stdev_mfe_knotted:$stdev_mfe_knotted  avg_pairs_knot:$avg_pairs_knotted  stdev_pairs:kno:$stdev_pairs_knotted  avg_z:$avg_zscore  stdev_zscore:$stdev_zscore\n";
		    my $statement = qq"INSERT DELAYED INTO stats
(species, seqlength, max_mfe, min_mfe, algorithm, num_sequences, avg_mfe, stddev_mfe, avg_pairs, stddev_pairs, num_sequences_noknot, avg_mfe_noknot, stddev_mfe_noknot, avg_pairs_noknot, stddev_pairs_noknot, num_sequences_knotted, avg_mfe_knotted, stddev_mfe_knotted, avg_pairs_knotted, stddev_pairs_knotted, avg_zscore, stddev_zscore)
    VALUES
('$species', '$seqlength', '$max_mfe', '$min_mfe', '$algorithm', '$num_sequences', '$avg_mfe', '$stdev_mfe', '$avg_pairs', '$stdev_pairs', '$num_sequences_noknot', '$avg_mfe_noknot', '$stdev_mfe_noknot', '$avg_pairs_noknot', '$stdev_pairs_noknot', '$num_sequences_knotted', '$avg_mfe_knotted', '$stdev_mfe_knotted', '$avg_pairs_knotted', '$stdev_pairs_knotted', '$avg_zscore', '$stdev_zscore')";
#                  print "STATEMENT: $statement\n";
                  my $rows = $me->MyExecute(statement => $statement,);
                  if (defined($me->{errors}->{errstr})) {
                    print "The statement: $me->{errors}->{statement} had an error:
$me->{errors}->{errstr}\n";
                  }
                  $inserted_rows = $inserted_rows + $rows;
                }
            }
        }
    }
  return($inserted_rows);
}

sub Vienna {
    my $me = shift;
    my $data = shift;
    my $table = shift;
    my $mfe_id = shift;
    if (defined($table) and $table =~ /^landscape/) {
	$mfe_id = $me->Put_MFE_Landscape('vienna', $data, $table);
    } elsif (defined($table)) {
	$mfe_id = $me->Put_MFE('vienna', $data, $table);
    } else {
	$mfe_id = $me->Put_MFE('vienna', $data);
    }
    return($mfe_id);
}

sub AUTOLOAD {
    my $me = shift;
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion
    if (@_) {
	return $me->{$name} = shift;
    } else {
	return $me->{$name};
    }
}

1;
