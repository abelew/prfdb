#!/usr/local/bin/perl
use strict;
use POSIX;
use DBI;
use Time::HiRes;

use lib "$ENV{HOME}/usr/lib/perl5";
use lib 'lib';
use PRFConfig;
use PRFdb;
use RNAMotif_Search;
use RNAFolders;
use Bootlace;
use MoreRandom;
use Data::Dumper;

$^W=1;
my $config = $PRFConfig::config;
my $db = new PRFdb;
chdir($config->{basedir});
Check_Environment();
Print_Config();
sleep(10);
my $time_to_die = 0;

until ($time_to_die) {
  Time::HiRes::usleep(100);
  my $ids = $db->Grab_Queue('public');
  if (defined($ids)) {  ## The public queue is not empty
    my $existsp = Check_Db($ids->[1]);
    $db->Done_Queue($ids->[0]);
  }
  else {  ## The public queue is empty
    my $ids = $db->Grab_Queue('private');
    if (defined($ids)) {  # The queue is not empty
      my $existsp = Check_Db($ids->[1]);
      $db->Done_Queue($ids->[0]);
    }
    else {  ## Both queues are empty
      sleep(10);
    }
  }  ## End the public queue is empty
}    ## End until it is time to die

## Check_Db does all the work
## It consists of a large if statement:
## if (have rnamotif for the accession) {
##    foreach startsite in rnamotif information {
##      if (do_nupack) { Do Nupack }
##      if (do_pknots) { Do Pknots }
##      if (do_boot)   { Do Boot   }
##      unlink the fasta file
##    }
##  } else { ## Do not have rnamotif for the accession
##    perform rnamotif search
##    foreach startsite in rnamotif information {
##      if (do_nupack) { Do Nupack }
##      if (do_pknots) { Do Pknots }
##      if (do_boot)   { Do Boot   }
##      unlink the fasta file
##    }
##  }
sub Check_Db {
    my $id = shift;
    my $db = new PRFdb;
    my $motifs = new RNAMotif_Search;
    my $accession_species_ref = $db->Id_to_AccessionSpecies($id);
    my $accession = $accession_species_ref->[0];
    my $species = $accession_species_ref->[1];
    if (!defined($accession) or !($accession)) {
      PRF_Error("No accession for $id", $id);
      next;
    }
    ## First see that there is rna motif information
    my $bootlaces = undef;
    my $motif_info = $db->Get_RNAmotif($id);
    if ($motif_info) {  ## If the motif information _does_ exist, check the folding information
	## For every slippery start site in the sequence
	foreach my $start (keys %{$motif_info}) {
	    print "Doing Genomeid: $id locus: $accession start: $start\n";
	    my $fdata = $motif_info->{$start}{filedata};
	    my $folding = undef;
	    my $nupack_folding = undef;
	    my $pknots_folding = undef;
	    my $mfold_folding = undef;
	    my $filename = undef;
	    
	    if ($config->{do_nupack}) {  ## Check the configuration file for nupack
		$nupack_folding = $db->Get_Num_RNAfolds('nupack', $id);
		if ($nupack_folding ne '0') {  ## Both have motif and folding
		    PRF_Out("HAVE NUPACK FOLDING AND MOTIF for $accession");
		    return(1);
		}
		else { ## Want nupack, have motif, no folding, so need to make a tmp
		    ## file for nupack.  First thing: create a fasta file with the
		    ## sequence from rnamotif  The rnamotif table has the motif start
		    ## position with respect to the first base pair in the sequence
		    $filename = $db->Motif_to_Fasta($motif_info->{$start}{filedata});
		    ### Some of these parameters are not used by
		    ### The various folders, but the information
		    ### will be saved into $nupack_info and thus
		    ### find its way into the database
		    ### Alternately we could make these arguments for Put_Nupack
		    my $fold_search = new RNAFolders(
						     file => $filename,
						     genome_id => $id,
						     species => $species,
						     accession => $accession,
						     start => $start,
						     );
		    my $nupack_info;
		    if ($config->{nupack_nopairs_hack}) {
			$nupack_info = $fold_search->Nupack_NOPAIRS();
		    }
		    else {
			$nupack_info = $fold_search->Nupack();
		    }
		    $db->Put_Nupack($nupack_info);
        }  ## Else checking for folding and motif information
      }  ## End do_nupack

      if ($config->{do_pknots}) {  ## Check to see if pknots should be run
	  $pknots_folding = $db->Get_Num_RNAfolds('pknots', $id);
        if ($pknots_folding ne '0') {  ## Both have motif and folding
          PRF_Out("HAVE PKNOTS FOLDING AND MOTIF for $species $accession");
          return(1);
        }
        else {  ## Want pknots, have motif, no folding, so make a tempfile
          $filename = $db->Motif_to_Fasta($motif_info->{$start}{filedata});
          my $orf_sequence = $db->Get_ORF($accession);
	  print "Want pknots, have notif, no folding\n";
          my $fold_search = new RNAFolders(
					   file => $filename,
					   genome_id => $id,
					   species => $species,
					   accession => $accession,
					   start => $start,
					   );
          my $pknots_info = $fold_search->Pknots();
          $db->Put_Pknots($pknots_info);
        }  ## End checking for folding and motif information
      } ## End check for do_pknots
      ### At this point pknot and nupack should both have output for the case
      ### in which case there there is no folding/motif info
      ### Now we wish to see if there is bootstrap informaiton for mfold
      ### FIXME: This will need to be reworked to deal with different
      ### randomization schemes and may need to store different data
      if ($config->{do_boot}) {
        my $boot = new Bootlace(
				genome_id => $id,
                                inputfile => $filename,
                                species => $species,
                                accession => $accession,
                                start => $start,
                                iterations => $config->{boot_iterations},
                                boot_mfe_algorithms => $config->{boot_mfe_algorithms},
                                randomizers => $config->{boot_randomizers},
                               );
        $bootlaces = $boot->Go();
        $bootlaces->{species} = $species;
        $bootlaces->{accession} = $accession;
        $bootlaces->{start} = $start;
        #          $bootlaces->{num_iterations} = $num_iterations;
        ## bootlaces should be organized:
        ## bootlaces->{mfe_algorithm}->{random_algorithm}->{num_iterations} = 100;
        ## bootlaces->{mfe_algorithm}->{random_algorithm}->{total_mfe} = -250.0;
        ## bootlaces->{mfe_algorithm}->{random_algorithm}->{total_pairs} = 40;
        ## bootlaces->{mfe_algorithm}->{random_algorithm}->{mfe_mean} = -25.0;
        ## bootlaces->{mfe_algorithm}->{random_algorithm}->{pairs_mean} = 8.0;
        ## bootlaces->{mfe_algorithm}->{random_algorithm}->{mfe_st_dev} = 10.0;
        ## bootlaces->{mfe_algorithm}->{random_algorithm}->{pairs_st_dev} = 1.0;
        ## bootlaces->{mfe_algorithm}->{random_algorithm}->{mfe_st_err} = 0.5;
        ## bootlaces->{mfe_algorithm}->{random_algorithm}->{pairs_st_err} = 0.2;
        ## bootlaces->{mfe_algorithm}->{random_algorithm}->{1}->{mfe} = -10;
        ## etc etc
        $db->Put_Boot($bootlaces);
      }  ## End if do_bootlace
      unlink($filename);
    }  ## End foreach $start in %motif_info
  }  ## End checking if there is %motif_info

  else { ## No rnamotif information
    ### FIXME!!!
    my ($sequence, $orf_start, $orf_stop) = $db->Get_ORF($accession);
    if (!defined($sequence) or !($sequence)) {
      PRF_Error("No sequence for $accession!", $accession);
    }
    elsif (!defined($orf_start) or !($orf_start)) {
      PRF_Error("No orf_start for $accession!", $accession);
    }
    elsif (!defined($orf_stop) or !($orf_stop)) {
      PRF_Error("No orf_stop for $accession!", $accession);
    }
    ## Get_ORF should return a piece of sequence starting with the ATG
    ## End ending with the stop codon as well as the start position
    my $slipsites = $motifs->Search($sequence, $orf_start);
    $db->Put_RNAmotif($id, $species, $accession, $slipsites);
    PRF_Out("NO MOTIF, NO FOLDING for $species $accession");
    my $success = scalar(%{$slipsites});
    if ($success eq '0') {
      PRF_Out("$species $accession has no slippery sites.");
    }
    foreach my $start (keys %{$slipsites}) {
	next if ($orf_stop <= $start);  ## If the slippery site is after the STOP codon
	### Then move on to the next
	my $filename = $slipsites->{$start}{filename};
	PRF_Out("STARTING FOLD FOR $start in $accession");
	### We are now reading the orf sequence, thus we need to look from
	### the start position of the slippery site.
	my $fold_search = new RNAFolders(
					 file => $filename,
					 genome_id => $id,
					 species => $species,
					 accession => $accession,
					 start => $start,
					 );
	### Perform fold predictions here.
	my ($nupack_info, $pknots_info);
	if ($config->{do_nupack}) {
	    if ($config->{nupack_nopairs_hack}) {
		$nupack_info = $fold_search->Nupack_NOPAIRS();
	    }
	    else {
		$nupack_info = $fold_search->Nupack();
	    }
	    $db->Put_Nupack($nupack_info);
	}
	if ($config->{do_pknots}) {
	    $pknots_info = $fold_search->Pknots();
	    $db->Put_Pknots($pknots_info);
	}
	### At this point pknot and nupack should both have output for the case
	### in which case there there is no folding/motif info
	### Now we wish to see if there is bootstrap informaiton for mfold

	if ($config->{do_boot}) {
	    my $boot = new Bootlace(
				    genome_id => $id,
				    inputfile => $filename,
				    species => $species,
				    accession => $accession,
				    start => $start,
				    iterations => $config->{boot_iterations},
				    boot_mfe_algorithms => $config->{boot_mfe_algorithms},
				    randomizers => $config->{boot_randomizers},
				    );
	    $bootlaces = $boot->Go();
	    $bootlaces->{species} = $species;
	    $bootlaces->{accession} = $accession;
	    $bootlaces->{start} = $start;
	    $db->Put_Boot($bootlaces);
	}  # End if do_bootlace
	## Remove the fasta file used for nupack/pknots
	unlink($slipsites->{$start}{filename});
    } ##End checking slipsites for a locus when have not motif nor folding information
  } ## End no motif nor folding information.
}

sub Check_Environment {
  die("No rnamotif descriptor file set.") unless(defined($config->{descriptor_file}));
  die("Tmpdir must be executable: $!") unless(-x $config->{tmpdir});
  die("Tmpdir must be writable: $!") unless(-w $config->{tmpdir});
  die("Database not defined") unless($config->{db} ne 'prfconfigdefault_db');
  die("Database host not defined") unless($config->{host} ne 'prfconfigdefault_host');
  die("Database user not defined") unless($config->{user} ne 'prfconfigdefault_user');
  die("Database pass not defined") unless($config->{pass} ne 'prfconfigdefault_pass');
  ## Now we should be able to connect to the database, so check that all the tables exist.
  $db->Create_Genome() unless($db->Tablep('genome'));
  $db->Create_Rnamotif() unless($db->Tablep('rnamotif'));
  $db->Create_Pknots() unless($db->Tablep('pknots'));
  $db->Create_Nupack() unless($db->Tablep('nupack'));
  $db->Create_Boot() unless($db->Tablep('boot'));
#  Create_Derived() unless(PRFdb::Tablep('derived'));

  unless(-r $config->{descriptor_file}) {
      RNAMotif_Search::Descriptor();
	die("Unable to read the rnamotif descriptor file: $!")
	    unless(-r $config->{descriptor_file});
  }
}

sub Print_Config {
    ### This is a little function designed to give the user a chance to abort
    if ($config->{do_nupack}) {
	my $nupack = $config->{nupack};
	print "I AM doing a nupack fold using the program: $nupack\n";
    }
    else {
	print "I AM NOT doing a nupack fold\n";
    }

    if ($config->{do_pknots}) {
	my $pknots = $config->{pknots};
	print "I AM doing a pknots fold using the program: $pknots\n";
    }
    else {
	print "I AM NOT doing a pknots fold\n";
    }
$Data::Dumper::Purity = 1;
    if ($config->{do_boot}) {
	my $randomizers = $config->{boot_randomizers};
	my $mfes = $config->{boot_mfe_algorithms};
	my $nu_boot = $config->{nupack_boot};
	print "I AM doing a boot using the following randomizers\n";
	foreach my $k (keys %{$randomizers}) {
		 print "$k\n";
	 }
	print "and the following mfe algorithms:\n";
	foreach my $k (keys %{$mfes}) { print "$k\n"; }
        $Data::Dumper::Purity=1;
	$Data::Dumper::Deepcopy=1;
        print Dumper($config->{boot_mfe_algorithms});
	print "nupack is using the following program for bootstrap:
$nu_boot
and running: $config->{boot_iterations} times\n";
    }
    else {
	print "I AM NOT doing a boot.\n";
    }

    if ($config->{arch_specific_exe}) {
	print "I AM USING ARCH SPECIFIC EXECUTABLES\n";
    }
    else {
	print "I am not using arch specific executables\n";
    }

    print "The default structure length in this run is: $config->{max_struct_length}\n";
    print "I am using the database: $config->{db} and user: $config->{user}\n";
}

sub signal_handler {
  $time_to_die = 1;
}
