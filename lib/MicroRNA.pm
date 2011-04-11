package MicroRNA;
use strict;
use autodie qw":all";
use PRFdb;
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
    }, $class;
    return($me);
}

sub Miranda_PRF {
    my $me = shift;
    my $accession = shift;
    my $position = shift;
    my $seq = $me->{db}->MySelect(type => 'single', statement => "SELECT sequence FROM mfe_homo_sapiens WHERE accession = ? AND start = ?", vars => [$accession, $position]);
    my $data = ">tmp\n$seq\n";
    my $filename = $me->{db}->Sequence_to_Fasta($data);
    my $command = qq(miranda $filename "$ENV{PRFDB_HOME}/work/homo_sapiens_microrna.fasta" -sc 100 -en -15);
    open(MIR, "$command |");
    my $line_num = 0;
    my $miranda_data = {};
    my $skip_lines = 34;
    my $alignment_line_num = 1;
    my $last_line = '';
    while (my $line = <MIR>) {
	chomp $line;
	$line_num++;
	if ($skip_lines > 0) {
	    $skip_lines--;
	    next;
	}
	if ($line =~ /^Performing/) {
	    my ($performing, $scan, $library_entry, $scanned_name) = split(/ /, $line);
	    $skip_lines = 2;
	}
	if ($line =~ /^\s+Forward\:) {
	    my ($forward, $sc, $score, $q, $to, $num, $r, $to, $r2, $align, $len, $len_num, $per1, $per2) = split(/\s+/, $line);
	    $skip_lines = 1;
	}
	if ($line =~ /^\s+Query/
	    my ($qu, $threep, $top_align_seq, $fivep) = split(/\s+/, $line);
	    $alignment_line_num = $line_num + 1;
	}
	if ($alignment_line_num == $line_num) {
	    my $align = $line;
	    $align =~ s/\s{15}//g;
	}
	if ($line =~ /^\s+Ref/) {
	    my ($ref, $fivep, $bottom_align_seq, $threep) = split(/\s+/, $line);
	    $skip_lines = 1;
	}
	if ($line =~ /^\s+Energy/) {
	    my ($ene, $energy_value, $kcal) = split(/\s+/, $line);
	    $skip_lines = 2;
	}
	if ($line =~ /^Scores for this hit/) {
	    $last_line = 'Scores for this hit';
	} elsif ($last_line eq 'Scores for this hit') {
	    my ($fasta_comment, $lib_hit, $hit_score, $hit_energy, $num1, $num2, $num3, $num4, $num5, $per1, $per2) = split(/\s+/, $line);
	}
	if ($line =~ /^Score for this Scan/) {
	    $last_line = 'Scores for this scan';
	} elsif ($last_line eq 'Scores for this scan') {
	    my ($fasta_comment, $lib_hit, $hit_score, $hit_energy, $num1, $num2, $num3, $num4, $num5, $per1, $per2) = split(/\s+/, $line);
	}
    }
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
	next unless ($species eq $micro_species);
	if (defined($mature)) {
	    print OUT ">$micro_name $hairpin_accession $mature_accession
$mature\n";
	}
	if (defined($star_seq)) {
	    print OUT ">$micro_name $hairpin_accession $star_accession
$star_seq\n";
	}
	if (defined($fivep_seq)) {
	    print OUT ">$micro_name $hairpin_accession $fivep_accession
$fivep_seq\n";
	}   
	if (defined($threep_seq)) {
	    print OUT ">$micro_name $hairpin_accession $threep_accession
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
