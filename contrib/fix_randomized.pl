#!/usr/local/bin/perl -w
use strict;
use DBI;
use lib '../lib';
use PRFConfig;
use PRFdb;
use Bootlace;
use MoreRandom;

my $config = $PRFConfig::config;
my $db     = new PRFdb;

#$SIG{INT} = 'CLEANUP';
#$SIG{BUS} = 'CLEANUP';
#$SIG{SEGV} = 'CLEANUP';
#$SIG{PIPE} = 'CLEANUP';
#$SIG{ABRT} = 'CLEANUP';
#$SIG{QUIT} = 'CLEANUP';
Main();

sub Main {
    my $mfe_ids = $db->MySelect("SELECT id FROM mfe");
    foreach my $mfe_id_ref (@{$mfe_ids}) {
	my $mfe_id = $mfe_id_ref->[0];
	my $mfe_data = $db->MySelect({type => 'hash',
				      statement => "SELECT * from mfe WHERE id = '$mfe_id'",
				      descriptor => 1});
	my $boot_data = $db->MySelect({type => 'hash',
				       statement => "SELECT * from boot WHERE mfe_id = '$mfe_id'",
				       descriptor => 1});

	my %mfe_datum = %{$mfe_data->{$mfe_id}};
	my $has_dinuc_pknots = 0;
	my $has_dinuc_nupack = 0;
	my $has_array_pknots = 0;
	my $has_array_nupack = 0;
	print "Starting MFE ID: $mfe_id\n";
	foreach my $boot_id (keys %{$boot_data}) {
	    my %boot_datum = %{$boot_data->{$boot_id}};
	    if ($boot_datum{rand_method} eq 'array' and $boot_datum{mfe_method} eq 'pknots') {
		$has_array_pknots++;
	    }
	    elsif ($boot_datum{rand_method} eq 'array' and $boot_datum{mfe_method} eq 'nupack') {
		$has_array_nupack++;
	    }
	    elsif ($boot_datum{rand_method} eq 'dinuc' and $boot_datum{mfe_method} eq 'pknots') {
		$has_dinuc_pknots++;
	    }
	    elsif ($boot_datum{rand_method} eq 'dinuc' and $boot_datum{mfe_method} eq 'nupack') {
		$has_dinuc_nupack++;
	    }
	}

	## Now fill in the boot for the missing fields
	if ($mfe_datum{algorithm} eq 'pknots') {
	    ## Then check the two pknots possibilities
	    if ($has_dinuc_pknots == 0) {
		Boot_Fill('pknots','dinuc', $mfe_id, \%mfe_datum);
	    }
	    if ($has_array_pknots == 0) {
		Boot_Fill('pknots','array', $mfe_id, \%mfe_datum);
	    }
	}
	elsif ($mfe_datum{algorithm} eq 'nupack') {
	    if ($has_dinuc_nupack == 0) {
		Boot_Fill('nupack','dinuc', $mfe_id, \%mfe_datum);
	    }
	    if ($has_array_nupack == 0) {
		Boot_Fill('nupack','array', $mfe_id, \%mfe_datum);
	    }
	}
    }
}

sub Boot_Fill {
    my $alg = shift;
    my $ran = shift;
    my $mfe_id = shift;
    my $mfe_datum = shift;
    print "Running a boot with $alg and $ran\n";
    my $inputfile = PRFdb::MakeFasta($mfe_datum->{sequence}, 0, $mfe_datum->{seqlength});
    my $boot_mfe_algorithms = '';
    my $boot_randomizers = '';
    if ($alg eq 'pknots') {
	$boot_mfe_algorithms = {pknots => \&RNAFolders::Pknots_Boot};
    }
    elsif ($alg eq 'nupack') {
	$boot_mfe_algorithms = {nupack => \&RNAFolders::Nupack_Boot_NOPAIRS};
    }
    else {
	print "Returning undef, algorithm = $alg\n";
	return(undef);
    }

    if ($ran eq 'dinuc') {
	$boot_randomizers = {dinuc => \&MoreRandom::Squid_Dinuc};
    }
    elsif ($ran eq 'array') {
	$boot_randomizers = {array => \&MoreRandom::ArrayShuffle};
    }
    else {
	return(undef);
    }

    my $boot = new Bootlace(genome_id => $mfe_datum->{genome_id},
			    mfe_id => $mfe_id,
			    inputfile => $inputfile->{filename},
			    species => $mfe_datum->{species},
			    accession => $mfe_datum->{accession},
			    start => $mfe_datum->{start},
			    seqlength => $mfe_datum->{seqlength},
			    iterations => 100,
			    boot_mfe_algorithms => $boot_mfe_algorithms,
			    randomizers => $boot_randomizers,
			    );
    
    my $bootlaces = $boot->Go();
    my $inserted_ids = $db->Put_Single_Boot($bootlaces, $alg, $ran);
    CLEANUP();
}


sub CLEANUP {
    $db->Disconnect();
    PRFdb::RemoveFile('all');
}

END {
    $db->Disconnect();
    PRFdb::RemoveFile('all');
}
