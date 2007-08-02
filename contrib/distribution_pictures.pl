#!/usr/bin/perl -w
use strict;
use lib '../lib';
use PRFdb;
use PRFConfig;
use PRFGraph;

our $config = $PRFConfig::config;
our $db = new PRFdb;
our $graph = new PRFGraph;
my $nomatches = 0;
my $num_looked = 0;
my $hunk = $db->MySelect({
    statement => 'SELECT * FROM boot',
    type => 'hash',
    descriptor => 1});
foreach my $boot_id (keys %{$hunk}) { 
    $num_looked++;
    ## Columns:
    # id, genome_id, mfe_id, species, accession, start, seqlength, iterations, rand_method,
    # mfe_method, mfe_mean, mfe_sd, mfe_se, pairs_sd, pairs_se, mfe_values, zscores
    my @boot_values_check = ('id','genome_id','mfe_id','species','accession','start','seqlength','iterations','rand_method','mfe_method','mfe_mean','mfe_sd','mfe_se','pairs_sd','pairs_se','mfe_values','zscore');
    my @undefined_boot_values = ();
    foreach my $col (@boot_values_check) {
	if (!defined($hunk->{$boot_id}->{$col}) or $hunk->{$boot_id}->{$col} eq '') {
	    push(@undefined_boot_values, $col);
	}
    }
    ## First check to see if mfe_id is there
    my $mfe_check = $db->MySelect({statement => qq(SELECT * FROM mfe WHERE id = '$hunk->{$boot_id}->{mfe_id}'), type => 'hash', descriptor => 1});
    my $mfe_count = 0;
    foreach my $mfe_id (keys %{$mfe_check}) {
	$mfe_count++;
	die("More than 1 mfe_id matches $boot_id\n") if ($mfe_count > 1);
	my $num_undefined = scalar(@undefined_boot_values);
	if ($num_undefined > 0) {
	    foreach my $undefined_value (@undefined_boot_values) {
		if ($undefined_value eq 'accession') {
		    my $accession = $mfe_check->{$mfe_id}->{accession};
		    my $update_stmt = qq(UPDATE boot SET accession = '$accession' WHERE id = '$boot_id');
		    print "$update_stmt\n";
		    $db->Execute($update_stmt);
		    $num_undefined--;
		}
		elsif ($undefined_value eq 'seqlength') {
		    my $seqlength = $mfe_check->{$mfe_id}->{seqlength};
		    my $update_stmt = qq(UPDATE boot SET seqlength = '$seqlength' WHERE id = '$boot_id');
		    print "$update_stmt \n";
		    $db->Execute($update_stmt);
		    $num_undefined--;
		}
		elsif ($undefined_value eq 'species') {
		    my $species = $mfe_check->{$mfe_id}->{species};
		    my $update_stmt = qq(UPDATE boot SET species = '$species' WHERE id = '$boot_id');
		    print "$update_stmt\n";
		    $db->Execute($update_stmt);
		    $num_undefined--;
		}
		elsif ($undefined_value eq 'zscore') {
		    my $zscore = sprintf("%.3f", ($mfe_check->{$mfe_id}->{mfe} - $hunk->{$boot_id}->{mfe_mean}) / $hunk->{$boot_id}->{mfe_sd});
		    my $update_stmt = qq(UPDATE boot SET zscore = '$zscore' WHERE id = '$boot_id');
		    print "$update_stmt \n";
		    $db->Execute($update_stmt);
		    $num_undefined--;
#		    print "Imported $undefined_value: $zscore\n";
		} ## End if the undefined value is zscore

	    } ## End foreach undefined value
	    print "There is still an undefined value: @undefined_boot_values\n\n";
	}
	Check_Distribution($hunk->{$boot_id}, $mfe_check->{$mfe_id}, $mfe_id);
    }  ## End foreach mfe_id  -- THERE SHOULD ONLY BE 1
    if ($mfe_count == 0) {
	if (!defined($hunk->{$boot_id}->{accession}) or $hunk->{$boot_id}->{accession} eq '') {
	    my $get_accession = qq(SELECT accession FROM genome WHERE id = '$hunk->{$boot_id}->{genome_id}');
	    my $accession_name = $db->MySelect({statement => $get_accession, type => 'single'});
	    print "The accession was not defined, but it has been found to be $accession_name\n";
	    my $update_stmt = qq(UPDATE boot SET accession = '$accession_name' WHERE id = '$boot_id');
	    $db->Execute($update_stmt);
	    $hunk->{$boot_id}->{accession} = $accession_name;
	}
	if (!defined($hunk->{$boot_id}->{species}) or $hunk->{$boot_id}->{species} eq '') {
	    my $get_species = qq(SELECT species FROM genome WHERE id = '$hunk->{$boot_id}->{genome_id}');
	    my $species_name = $db->MySelect({statement => $get_species, type => 'single'});
	    print "The species was not defined, but it has been found to be $species_name\n";
	    my $update_stmt = qq(UPDATE boot SET species = '$species_name' WHERE id = '$boot_id');
	    $db->Execute($update_stmt);
	    $hunk->{$boot_id}->{species} = $species_name;
	}
	if (!defined($hunk->{$boot_id}->{seqlength}) or $hunk->{$boot_id}->{seqlength} eq '') {
	    my $get_seqlength = qq(SELECT seqlength FROM mfe WHERE id = '$hunk->{$boot_id}->{mfe_id}');
	    my $seqlength_name = $db->MySelect({statement => $get_seqlength, type => 'single'});
	    if (defined($seqlength_name)) {
		print "The seqlength was not defined, but it has been found to be $seqlength_name\n";
		my $update_stmt = qq(UPDATE boot SET seqlength = '$seqlength_name' WHERE id = '$boot_id');
		$db->Execute($update_stmt);
		$hunk->{$boot_id}->{seqlength} = $seqlength_name;	    
	    }
	}
	my $test_stmt = qq(SELECT id, mfe FROM mfe WHERE accession = '$hunk->{$boot_id}->{accession}' AND algorithm = '$hunk->{$boot_id}->{mfe_method}');
	print "TESTME: $test_stmt\n";
	my $possible_mfe_ids = $db->MySelect($test_stmt);
	print "This boot id $boot_id has a MFE_mean of $hunk->{$boot_id}->{mfe_mean} and z: $hunk->{$boot_id}->{zscore} and SD: $hunk->{$boot_id}->{mfe_sd}\n";
	my $putative_mfe = sprintf("%.1f", (($hunk->{$boot_id}->{mfe_sd} * $hunk->{$boot_id}->{zscore}) + $hunk->{$boot_id}->{mfe_mean}));
	print "The putative mfe is: $putative_mfe\n";
	my $matches = 0;
	foreach my $possible (@{$possible_mfe_ids}) {
	    if ($putative_mfe == $possible->[1]) {
		$matches++;
		my $putative_update_stmt = qq(UPDATE boot SET mfe_id = '$possible->[0]' WHERE id = '$boot_id');
		print "Found match with mfe: $possible->[0]: $putative_update_stmt\n";
		$db->Execute($putative_update_stmt);
	    }
	}
	if ($matches == 0) {
#	    foreach my $possible (@{$possible_mfe_ids}) {
#		print "ID: $possible->[0] has MFE: $possible->[1]\n";
#	    }
#	    print "Choose ID:";
#	    my $chosen_id = <STDIN>;
#	    chomp $chosen_id;
#	    print "You chose $chosen_id, correct?\n";
#	    my $response = <STDIN>;
#	    my $update_stmt = qq(UPDATE boot SET mfe_id = '$chosen_id' WHERE id = '$boot_id');
#	    $db->Execute($update_stmt);
#	    print "\n";
            $nomatches++;
	    print("$boot_id has no matching mfe ids: $nomatches of $num_looked.\n");
            my $del = qq/DELETE FROM boot WHERE id = '$boot_id'/;
            $db->Execute($del);
	}
    }
}
print "There were $nomatches without MFE ids.\n";


sub Check_Distribution {
    my $boot_info = shift;
    my $mfe_info = shift;
    my $mfe_id = shift;
    my $mfe_values = $boot_info->{mfe_values};
    my $boot_algo = $boot_info->{mfe_method};
    my $boot_rand = $boot_info->{rand_method};
    my $acc_slip = qq/$boot_info->{accession}-$mfe_info->{start}-$boot_algo-$boot_rand/;
    my @mfe_values_array = split(/\s+/, $mfe_values);
    my $mfe_value = $mfe_info->{mfe};
#    print "Values into constructor: MFE: $mfe_value
#mfe values: $mfe_values
#accession: $acc_slip
#id: $mfe_id
#";
    my $chart = new PRFGraph(
	{
	    real_mfe => $mfe_value,
	    list_data => \@mfe_values_array,
	    accession => $acc_slip,
	    mfe_id => $mfe_id,
	});
		
    my $filename = $chart->Picture_Filename({type => 'distribution',});
    if (!-r $filename) {
	print "I could not find: $filename\n";
	$chart = $chart->Make_Distribution();
    }
}
