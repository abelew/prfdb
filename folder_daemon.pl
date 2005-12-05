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

$^W=1;

my $config = $PRFConfig::config;
chdir($config->{basedir});
Check_Environment();

my $time_to_die = 0;

until ($time_to_die) {
  Time::HiRes::usleep(100);
  my $db = new PRFdb;
  my $public_id = $db->Grab_Queue('public');
  if (defined($public_id)) {  ## The public queue is not empty
    my $existsp = Check_Db($public_id);
  }
  else {  ## The public queue is empty
    my $private_id = $db->Grab_Queue('private');
    if (defined($private_id)) {  # The queue is not empty
      my $existsp = Check_Db($private_id);
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
  my $accession, $species;
  [$accession, $species] = $db->Id_to_AccessionSpecies($id);
  ## First see that there is rna motif information
  my $bootlaces = undef;
  my $motif_info = $db->Get_RNAmotif($accession);
  if ($motif_info) {  ## If the motif information _does_ exist, check the folding information
      ## For every slippery start site in the sequence
    foreach my $start (keys %{$motif_info}) {
      print "Doing locus: $accession start: $start\n";
      my $fdata = $motif_info->{$start}{filedata};
      my $folding = undef;
      my $nupack_folding = undef;
      my $pknots_folding = undef;
      my $mfold_folding = undef;
      my $filename = undef;

      if ($PRFConfig::config->{do_nupack}) {  ## Check the configuration file for nupack
        $nupack_folding = $db->Get_Num_RNAfolds('nupack', $accession, $start);
        if ($nupack_folding ne '0') {  ## Both have motif and folding
          PRF_Out("HAVE NUPACK FOLDING AND MOTIF for $accession");
          return(1);
        }
        else { ## Want nupack, have motif, no folding, so need to make a tmp file for nupack.
	    ## First thing: create a fasta file with the sequence from rnamotif
	    ## The rnamotif table has the motif start position with respect to the
	    ## first base pair in the sequence
	    $filename = $db->Motif_to_Fasta($motif_info->{$start}{filedata});
	    my $fold_search = new RNAFolders(
					     file => $filename,
					     accession => $accession,
					     start => $start,
					     species => $datum->{species},);
	    my $nupack_info = $fold_search->Nupack();
	    $db->Put_Nupack($nupack_info);
        }  ## Else checking for folding and motif information
      }  ## End do_nupack

      if ($PRFConfig::config->{do_pknots}) {  ## Check to see if pknots should be run
        $pknots_folding = $db->Get_Num_RNAfolds('pknots', $datum->{accession}, $start);
        if ($pknots_folding ne '0') {  ## Both have motif and folding
          PRF_Out("HAVE PKNOTS FOLDING AND MOTIF for $datum->{species} $datum->{accession}");
          return(1);
        }
        else {  ## Want pknots, have motif, no folding, so make a tempfile
          $filename = $db->Motif_to_Fasta($motif_info->{$start}{filedata});
          my $orf_sequence = $db->Get_ORF($datum->{accession});
	  print "Want pknots, have notif, no folding\n";
          my $fold_search = new RNAFolders(
                                           file => $filename,
                                           accession => $datum->{accession},
                                           start => $start,
                                           species => $datum->{species},);
          my $pknots_info = $fold_search->Pknots();
          $db->Put_Pknots($pknots_info);
        }  ## End checking for folding and motif information
      } ## End check for do_pknots
      ### At this point pknot and nupack should both have output for the case
      ### in which case there there is no folding/motif info
      ### Now we wish to see if there is bootstrap informaiton for mfold
      ### FIXME: This will need to be reworked to deal with different
      ### randomization schemes and may need to store different data
      if ($PRFConfig::config->{do_boot}) {
        my $species = $datum->{species};
        my $accession = $datum->{accession};
        my $boot = new Bootlace(
                                inputfile => $filename,
                                species => $species,
                                accession => $accession,
                                start => $start,
                                iterations => $PRFConfig::config->{boot_iterations},
                                boot_mfe_algorithms => $PRFConfig::config->{boot_mfe_algorithms},
                                randomizers => $PRFConfig::config->{boot_randomizers},
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
    my ($sequence, $orf_start) = $db->Get_ORF($datum->{accession});
    ## Get_ORF should return a piece of sequence starting with the ATG
    ## End ending with the stop codon as well as the start position
    my $slipsites = $motifs->Search($sequence, $orf_start);
    $db->Put_RNAmotif($datum->{species}, $datum->{accession}, $slipsites);
    PRF_Out("NO MOTIF, NO FOLDING for $datum->{species} $datum->{accession}");
    my $success = scalar(%{$slipsites});
    if ($success eq '0') {
      PRF_Out("$datum->{species} $datum->{accession} has no slippery sites.");
    }
    foreach my $start (keys %{$slipsites}) {
      my $filename = $slipsites->{$start}{filename};
      my $accession = $datum->{accession};
      my $species = $datum->{species};
      PRF_Out("STARTING FOLD FOR $start in $datum->{accession}");
      ### We are now reading the orf sequence, thus we need to look from
      ### the start position of the slippery site.
      my $fold_search = new RNAFolders(file => $filename,
                                       accession => $accession,
                                       start => $start,
                                       species => $species,);

      ### Perform fold predictions here.
      my ($nupack_info, $pknots_info);
      if ($PRFConfig::config->{do_nupack}) {
	  $nupack_info = $fold_search->Nupack();
	  $db->Put_Nupack($nupack_info);
      }
      if ($PRFConfig::config->{do_pknots}) {
        $pknots_info = $fold_search->Pknots();
        $db->Put_Pknots($pknots_info);
      }
      ### At this point pknot and nupack should both have output for the case
      ### in which case there there is no folding/motif info
      ### Now we wish to see if there is bootstrap informaiton for mfold

      if ($PRFConfig::config->{do_boot}) {
        my $boot = new Bootlace(
				inputfile => $filename,
				species => $species,
                                accession => $accession,
                                start => $start,
                                iterations => $PRFConfig::config->{boot_iterations},
				boot_mfe_algorithms => $PRFConfig::config->{boot_mfe_algorithms},
				randomizers => $PRFConfig::config->{boot_randomizers},
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
  die("No rnamotif descriptor file set.") unless(defined($PRFConfig::config->{descriptor_file}));
  die("Tmpdir must be executable: $!") unless(-x $PRFConfig::config->{tmpdir});
  die("Tmpdir must be writable: $!") unless(-w $PRFConfig::config->{tmpdir});
  die("Database not defined") unless(defined($PRFConfig::config->{db}));
  die("Database host not defined") unless(defined($PRFConfig::config->{host}));
  die("Database user not defined") unless(defined($PRFConfig::config->{user}));
  die("Database pass not defined") unless(defined($PRFConfig::config->{pass}));
  ## Now we should be able to connect to the database, so check that all the tables exist.
  Create_Genome() unless(PRFdb::Tablep('genome'));
  Create_Rnamotif() unless(PRFdb::Tablep('rnamotif'));
  Create_Pknots() unless(PRFdb::Tablep('pknots'));
  Create_Nupack() unless(PRFdb::Tablep('nupack'));
  Create_Boot() unless(PRFdb::Tablep('boot'));
#  Create_Derived() unless(PRFdb::Tablep('derived'));

  unless(-r $PRFConfig::config->{descriptor_file}) {
	RNAMotif_Search::Descriptor();
	die("Unable to read the rnamotif descriptor file: $!") unless(-r $PRFConfig::config->{descriptor_file});
  }
}

sub signal_handler {
  $time_to_die = 1;
}

