package MicroRNA;
use strict;
use autodie qw":all";
use PRFdb;
use vars qw($VERSION);
$VERSION='20111119';
our $AUTOLOAD;

sub new {
    my ($class, %arg) = @_;
    my $config;
    if (defined($arg{config})) {
	$config = $arg{config};
    }
    my $me = bless {
	config => $config,
	db => new PRFdb(config => $config),
	energy_cutoff => $arg{energy_cutoff},
	max_internal_loop => $arg{max_internal_loop},
	max_bulge_loop => $arg{max_bulge_loop},
    }, $class;
    $me->{energy_cutoff} = -22.0 unless ($me->{energy_cutoff});
    $me->{max_internal_loop} = 3 unless ($me->{max_internal_loop});
    $me->{max_bulge_loop} = 3 unless ($me->{max_bulge_loop});
    return($me);
}


sub RNAHybrid {
    my $me = shift;
    my $accession = shift;
    my $position = shift;
    my $output = {};
    my $max_bulge = $me->{max_bulge_loop};
    my $max_internal = $me->{max_internal_loop};
    my $max_mfe = $me->{energy_cutoff};
    my $seq = $me->{db}->MySelect(type => 'single', statement => "SELECT sequence FROM mfe_homo_sapiens WHERE accession = ? AND start = ?", vars => [$accession, $position]);
    my $data = ">tmp\n$seq\n";
    my $filename = $me->{db}->Sequence_to_Fasta($data);
#    my $command = qq"$ENV{PRFDB_HOME}/work/RNAhybrid -u $max_bulge -v $max_internal -e $max_mfe -d -s 3utr_human -q $ENV{PRFDB_HOME}/data/homo_sapiens_microrna.fasta -t $filename";
    my $command = qq"$ENV{PRFDB_HOME}/bin/RNAhybrid -u $max_bulge -v $max_internal -d -s 3utr_human -q $ENV{PRFDB_HOME}/data/homo_sapiens_microrna.fasta -t $filename";
    ## rnahybrid setfaults mysteriously if you attempt to impose an MFE constraint
#    print STDERR "TESTME Running $command\n";
    open(MIR, "$command |") or print STDERR "Could not run $command $!";
    my ($key, $junk, $inner_hash, $miRNA, $mfe, $target_mismatch, $target_match, $miRNA_mismatch, $miRNA_match);
##  Each result from rnahybrid is 11 lines of text with some blanks.
##  If I put a next in front of every line starting with 'target:' or blank, or  then 
##  there remain... 7 lines of interest
##  I can count the rest of the lines and do a mod 7 of them
##  The 1st: miRNA name, 2nd: mfe, 3rd: position, 4th: target_mis, 5th: target_match, 6th: miRNA_match, 7th miRNA_mis
    my $count = 0;
    while (my $line = <MIR>) {
	chomp $line;
	next if ($line =~ /^\s*$/);
	next if ($line =~ /^target:/);
	next if ($line =~ /^length/);
	if ($line =~ /^p-value/) {
#	    print STDERR "TESTME: $line\n";
	    next;
	}
	$line =~ s/^mfe:\s+//g;
	$line =~ s/^miRNA ://g;
	$line =~ s/^position //g;
	$line =~ s/^target //g;
	$line =~ s/^\s+//g;
	$line =~ s/^miRNA //g;
	$count++;
	$count = 1 if ($count == 8);
	if ($count == 1) {
	    $miRNA = $line;
	} elsif ($count == 2) {
	    $mfe = $line;
	    $mfe =~ s/\"//g;
	    $mfe =~ s/ kcal\/mol//g;
	} elsif ($count == 3) {
	    $position = $line;
	} elsif ($count == 4) {
	    $target_mismatch = $line;
	} elsif ($count == 5) {
	    $target_match = $line;
	} elsif ($count == 6) {
	    $miRNA_match = $line;
	} else {
	    $miRNA_mismatch = $line;
	}
	$output->{$miRNA}->{$position}->{mfe} = $mfe;
	$output->{$miRNA}->{$position}->{target_mismatch} = $target_mismatch;
	$output->{$miRNA}->{$position}->{target_match} = $target_match;
	$output->{$miRNA}->{$position}->{miRNA_match} = $miRNA_match;
	$output->{$miRNA}->{$position}->{miRNA_mismatch} = $miRNA_mismatch;
	$output->{$miRNA}->{$position}->{target} = $accession;
	$output->{$miRNA}->{$position}->{target_position} = $position;
    }
#    close(MIR);
    return($output);
}


sub Miranda {
    my $me = shift;
    my $accession = shift;
    my $position = shift;
    my $output = {};
    my $max_bulge = $me->{max_bulge_loop};
    my $max_internal = $me->{max_internal_loop};
    my $max_mfe = $me->{energy_cutoff};
    my $seq = $me->{db}->MySelect(type => 'single', statement => "SELECT sequence FROM mfe_homo_sapiens WHERE accession = ? AND start = ?", vars => [$accession, $position]);
    my $data = ">tmp\n$seq\n";
    my $filename = $me->{db}->Sequence_to_Fasta($data);
    my $command = qq"$ENV{PRFDB_HOME}/bin/miranda \"$ENV{PRFDB_HOME}/data/homo_sapiens_microrna.fasta\" $filename -en $me->{energy_cutoff} -sc 100 -quiet";
    print "<pre>\n";
#    print "TESTME: $command<br>\n";
    open(MIR, "$command |") or print STDERR "Could not run $command $!";
    my $line_num = 0;
    my $miranda_data = {};
    my $skip_lines = 34;
    my $alignment_line_num = 1;
    my $last_line = '';
    my $miRNA;
    my $position = 0;
    my $alignment = 0;
    my $mRNA_match = '';
    my $miRNA_match = '';
    my $align_string = '';
    my $energy_string = 0;
    while (my $line = <MIR>) {
	next if ($line =~ /^\s*$/);
	chomp $line;
	$line_num++;
	$alignment--;

	## Skip the header at the top of the miranda output.
	if ($skip_lines > 0) {
	    $skip_lines--;
	    next;
	}

	## Each line which is 'Forward:' provides the following:
#    Forward:Score: 109.000000  Q:2 to 22  R:26 to 48 Align Len (20) (60.00%) (80.00%)
	## The miranda score
        ## Q: The region of the miRNA
	## R: The region of the mRNA
	## Alignment length and identity %
	## Sadly, the name of the miRNA doesn't come for another 4 lines...
	if ($line =~ /^\s+Forward\:/) {
#	    print "FORWARD: $line\n";
	    my ($forward, $sc, $score, $q, $to, $num, $r, $to_two, $r2, $align, $len, $len_num, $per1, $per2) = split(/\s+/, $line);
	    $position = $r;
	    $position =~ s/R\://g;
	}
	## The line which starts with 'Query' and the two following it provide the alignment.
	## So as soon as I see a Query, I will set the 'alignment flag to '2' and use it to pull the next two lines.
	if ($line =~ /^\s+Query/) {
#	    print "QUERY: $line\n";
	    $alignment = 3;
	    my ($spaces, $qu, $threep, $top_align_seq, $fivep) = split(/\s+/, $line);
	    $miRNA_match = $top_align_seq;
	}
	## The next two stanzas decrement thanks to the alignment-- above.
	if ($alignment == 2) {  ## Get the alignment string, strip annoying leading spaces
	    $align_string = $line;
	    $align_string =~ s/^\s{16}//g;
#	    print "TESTME: $align_string<br>\n";
	}
	if ($alignment == 1) {  ## Grab the bottom match string
	    my ($more_spaces, $ref, $fivep, $bottom_align_seq, $threep) = split(/\s+/, $line);
	    $mRNA_match = $bottom_align_seq;
	}

	## Now get the kcal/mol predicted, we still don't have the name of the miRNA
	if ($line =~ /^\s+Energy/) {
#	    print "ENERGY: $line\n";
	    my ($ene, $energy_value, $kcal) = split(/\s+/, $line);
	    $energy_string = $energy_value; ## The score line has a version of this which has been sprintf()'d
	    ## so use that instead.
	}

	## The line following 'scores for this hit' is the one with the name etc.
	if ($line =~ /^Scores for this hit/) {
#	    print "SCORES: $line\n";
	    $last_line = 'Scores for this hit';
	} elsif ($last_line eq 'Scores for this hit') {
	    ## In this line we can start filling out $output
	    my ($miRNA, $lib_hit, $hit_score, $hit_energy, $num1, $num2, $num3, $num4, $num5, $per1, $per2) = split(/\s+/, $line);
	    $last_line = 'spelled out the score.';
	    $output->{$miRNA}->{$position}->{mfe} = $hit_energy;
	    $output->{$miRNA}->{$position}->{target_match} = $mRNA_match;
	    $output->{$miRNA}->{$position}->{miRNA_match} = $miRNA_match;
	    $output->{$miRNA}->{$position}->{target} = $accession;
	    $output->{$miRNA}->{$position}->{align_string} = $align_string;
	    $output->{$miRNA}->{$position}->{target_position} = $position;
	}
    }
    close(MIR);
    return($output);
}

sub Micro_Fasta {
    my $me = shift;
    my $species = shift;
    my $output = shift;
    my $data = $me->{db}->MySelect("SELECT * FROM microrna WHERE species = '$species'");
    open(OUT,">$output");
    foreach my $datum (@{$data}) {
	my ($id, $micro_species, $micro_name, $hairpin_accession, $hairpin_seq, 
	    $mature_accession, $mature, $star_accession, $star_seq, $fivep_accession,
	    $fivep_seq, $threep_accession, $threep_seq) = @{$datum};
	$hairpin_accession = "undefined" if (!$hairpin_accession);
	next unless ($species eq $micro_species);
	if (defined($mature)) {
	    print OUT ">${micro_name}-mature $hairpin_accession $mature_accession
$mature\n";
	}
	if (defined($star_seq)) {
	    print OUT ">${micro_name}-star $hairpin_accession $star_accession
$star_seq\n";
	}
	if (defined($fivep_seq)) {
	    print OUT ">${micro_name}-5p $hairpin_accession $fivep_accession
$fivep_seq\n";
	}   
	if (defined($threep_seq)) {
	    print OUT ">${micro_name}-3p $hairpin_accession $threep_accession
$threep_seq\n";
	}    
    } ## End of all data
    close(OUT);
}

sub Micro_Import_Fasta {
    my %data = ();
    my $comment = 0;
    my $saved_mi_name;
    my $sequence;
    open(HA,"<hairpin.fa");
    while (my $line = <HA>) {
	chomp $line;
	$line = lc($line);
	if ($line =~ /^\>/) {
	    $sequence = '';
	    $comment = 1;
	} else {
	    $comment = 0;
	}

	if ($comment == 1) {
	    my ($mi_name, $mi_accession, $genus, $species, $name, $type) = split(/\s+/, $line);
	    $mi_name =~ s/\>//g;
	    $mi_name = lc($mi_name);
	    if ($mi_name =~ /\w+\-\w+\-\w+\-.*/) {
		 $mi_name =~ s/\-\d+$//g;
		print "Found one: $mi_name\n";
	    }
	    $data{$mi_name} = {} if (!defined($data{$mi_accession}));
	    $data{$mi_name}{mi_name} = $mi_name;
	    $data{$mi_name}{mi_accession} = $mi_accession;
	    $data{$mi_name}{species} = lc(qq"${genus}_${species}");
	    $data{$mi_name}{hairpin_name} = $name;
	    $data{$mi_name}{hairpin_accession} = $mi_accession;
	    $saved_mi_name = $mi_name;
	} else {
	    if (!$data{$saved_mi_name}{hairpin_sequence}) {
		$data{$saved_mi_name}{hairpin_sequence} = $line;
	    } else {
		$data{$saved_mi_name}{hairpin_sequence} .= $line;
	    }
	}
    }
    close(HA);

    my $mature_type = '';
    open(MA,"<mature.fa");
    while (my $line = <MA>) {
	chomp $line;
	$line = lc($line);
	if ($line =~ /^\>/) {
	    $sequence = ''; 
	    $comment = 1;
	} else {
	    $comment = 0;
	}

	if ($comment == 1) {
	    my ($mature_name, $mi_accession, $genus, $species, $name) = split(/\s+/, $line);
	    $mature_name =~ s/\>//g;
	    $mature_name = lc($mature_name);
	    $saved_mi_name = $mature_name;
	    $data{$saved_mi_name}{mi_accession} = $mi_accession;
	    $data{$saved_mi_name}{species} = lc(qq"${genus}_${species}");
	    if (!defined($data{$saved_mi_name}{species})) {
		if ($saved_mi_name =~ /hsa/) {
		    $data{$saved_mi_name}{species} = 'homo_sapiens';
		}
	    }

	    if ($mature_name =~ /\*/) {
		$mature_type = 'star';
		$saved_mi_name =~ s/\*//g;
		$data{$saved_mi_name}{star_accession} = $mi_accession;
	    } elsif ($mature_name =~ /\-5p/) {
		$mature_type = '5p';
		$saved_mi_name =~ s/\-5p//g;
		$data{$saved_mi_name}{fivep_accession} = $mi_accession;
	    } elsif ($mature_name =~ /\-3p/) {
		$mature_type = '3p';
		$saved_mi_name =~ s/\-3p//g;
		$data{$saved_mi_name}{threep_accession} = $mi_accession;
	    } else {
		$mature_type = 'normal';
		$data{$saved_mi_name}{mature_accession} = $mi_accession;
	    }
	} else { ## else comment = 0
	    if ($mature_type eq 'star') {
		$data{$saved_mi_name}{mature_star} = $line;
	    } elsif ($mature_type eq '5p') {
		$data{$saved_mi_name}{mature_5p} = $line;
	    } elsif ($mature_type eq '3p') {
		$data{$saved_mi_name}{mature_3p} = $line;
	    } else {
		$data{$saved_mi_name}{mature} = $line;
	    }
	}
    }
    close(MA);

    foreach my $entry (keys %data) {
	my %tmp = %{$data{$entry}};
	my $stmt = qq"INSERT INTO microrna (species, micro_name, hairpin_accession, hairpin, mature_accession, mature, star_accession, mature_star, fivep_accession, mature_5p, threep_accession, mature_3p) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)";
	my $db = new PRFdb(config => new PRFConfig);
	$db->MyExecute(statement => $stmt, vars => [$data{$entry}{species}, $entry, $data{$entry}{hairpin_accession}, $data{$entry}{hairpin_sequence}, $data{$entry}{mature_accession}, $data{$entry}{mature}, $data{$entry}{star_accession}, $data{$entry}{mature_star}, $data{$entry}{fivep_accession}, $data{$entry}{mature_5p}, $data{$entry}{threep_accession}, $data{$entry}{mature_3p}]);
#	foreach my $column (keys %tmp) {
#	    print "TESTME: $column VAL: $tmp{$column}\n";
#	}
#	print "\n\n";
    }
}

sub DESTROY {
}

sub AUTOLOAD {
    my $me = shift;
    my $name = $AUTOLOAD;
    print "Unable to find the function: $name in MicroRNA\n";
    $name =~ s/.*://;   # strip fully-qualified portion
    if (@_) {
	return $me->{$name} = shift;
    } else {
	return $me->{$name};
    }
}

1;
