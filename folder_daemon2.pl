#!/usr/local/bin/perl -w
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

my $config = $PRFConfig::config;
my $db = new PRFdb;
chdir($config->{basedir});
Check_Environment();

my $state = {
	     time_to_die => undef,
	     queue_id => undef,
	     genome_id => undef,
	     accession => undef,
	     species => undef,
	     fasta_file => undef,
	     genome_information => undef,
	     rnamotif_information => undef,
	     nupack_information => undef,
	     pknots_information => undef,
	     boot_information => undef,
	     done_count => 0,
	    };

Print_Config();
## Put some helper functions here
if (defined($ARGV[0])) {
  if ($ARGV[0] eq '-q') {
    $db->FillQueue();
  }
  elsif ($ARGV[0] eq '-r') {
    exit();
  }
exit();
}


until (defined($state->{time_to_die})) {
#  Time::HiRes::usleep(100);
  sleep(1);
  ### You can set a configuration variable 'master' so that it will not die
  if ($state->{done_count} > 60 and !defined($config->{master})) { $state->{time_to_die} = 1 };

  my $ids = $db->Grab_Queue('public');
  $state->{queue_id} = $ids->{queue_id};
  $state->{genome_id} = $ids->{genome_id};
  if (defined($state->{genome_id})) {
    Gather($state);
  }  ## End if have an entry in the public queue
  else {
    my $ids = $db->Grab_Queue('private');
    $state->{queue_id} = $ids->{queue_id};
    $state->{genome_id} = $ids->{genome_id};
    if (defined($state->{genome_id})) {
      Gather($state);
    }  ### End if have an entry in the private queue
    else {  ### Both queues are empty
      sleep(60);
      $state->{done_count}++;
    }  ### End Both queue
  }    ### End else public queue is empty
}      ### End waiting for time to die

sub Gather {
  my $state = shift;
  my $ref = $db->Id_to_AccessionSpecies($state->{genome_id});
  $state->{accession} = $ref->{accession};
  $state->{species} = $ref->{species};
  print "Working with: qid: $state->{queue_id} gid:$state->{genome_id} sp:$state->{species} acc:$state->{accession}\n";
  Gather_Rnamotif($state);
  return(0) unless(defined($state->{rnamotif_information})); ## If rnamotif_information is null
  my $rnamotif_information = $state->{rnamotif_information};
  ## Now I should have 1 or more start sites
  my $number_rnamotif_information = Get_Num($rnamotif_information);
  foreach my $slipsite_start (keys %{$rnamotif_information}) {
    $state->{fasta_file} = $rnamotif_information->{$slipsite_start}{filename};
    my $fold_search = new RNAFolders(
				     file => $state->{fasta_file},
				     genome_id => $state->{genome_id},
				     species => $state->{species},
				     accession => $state->{accession},
				     start => $slipsite_start,
				    );
    my $boot = new Bootlace(
			    genome_id => $state->{genome_id},
			    inputfile => $state->{fasta_file},
			    species => $state->{species},
			    accession => $state->{accession},
			    start => $slipsite_start,
			    iterations => $config->{boot_iterations},
			    boot_mfe_algorithms => $config->{boot_mfe_algorithms},
			    randomizers => $config->{boot_randomizers},
			   );
    if ($config->{do_nupack}) { ### Do we run a nupack fold?
      my $nupack_folds = $db->Get_Num_RNAfolds('nupack', $state->{genome_id});
      if ($nupack_folds >= $number_rnamotif_information) {
	print "$state->{genome_id} already has $number_rnamotif_information nupack_folds\n";
      }
      else { ### If there are no existing folds...
	my $nupack_info;
	if ($config->{nupack_nopairs_hack}) {
	  $nupack_info = $fold_search->Nupack_NOPAIRS();
	}
	else {
	  $nupack_info = $fold_search->Nupack();
	}
	$db->Put_Nupack($nupack_info);
      }  ### Done checking for nupack folds
    } ### End check if we should do a nupack fold

    if ($config->{do_pknots}) { ### Do we run a pknots fold?
      my $pknots_folds = $db->Get_Num_RNAfolds('pknots', $state->{genome_id});
      if ($pknots_folds >= $number_rnamotif_information) { ### If there are no existing folds...
	print "$state->{genome_id} already has pknots folds\n";
      }
      else {
	my $pknots_info = $fold_search->Pknots();
	$db->Put_Pknots($pknots_info);
      }  ### Done checking for pknots folds
    } ### End check if we should do a pknots fold

    if ($config->{do_boot}) {
      my $boot_folds = $db->Get_Num_RNAfolds('boot', $state->{genome_id}); ## CHECKME!
      my $number_boot_algos = Get_Num($config->{boot_mfe_algorithms});
      my $needed_boots = $number_boot_algos * $number_rnamotif_information;
      if ($boot_folds == $needed_boots) {
	print "Already have $boot_folds pieces of boot information for $state->{genome_id}\n";
      }
      elsif ($boot_folds < $needed_boots) {
	print "I have $boot_folds but need $needed_boots\n";
	my $bootlaces = $boot->Go();
	$db->Put_Boot($bootlaces);
      }
      else {
	print "WTF!\n";
      } ### End if there are no bootlaces
    }  ### End if we are to do a boot
    unlink($state->{fasta_file});  ## Get rid of each fasta file
  } ### End foreach slipsite_start
  foreach my $k (keys %{$state}) { $state->{$k} = undef unless ($k eq 'done_count'); }
  ## Clean out state
}  ## End Gather

sub Gather_Rnamotif {
  my $state = shift;
  my $id = $state->{genome_id};
  ### First, get the accession and species
  my $rnamotif_information = $db->Get_RNAmotif($id);
  if (defined($rnamotif_information)) {
    foreach my $start (keys %{$rnamotif_information}) {
      if ($start eq 'NONE') {
	print "$id has no slippery sites.\n";
	next;
      }
      else {
	$rnamotif_information->{$start}{filename} = $db->Motif_to_Fasta($rnamotif_information->{$start}{filedata});
	print "TESTME: $rnamotif_information->{$start}{filename} $start\n";
      }
      $state->{rnamotif_information} = $rnamotif_information;
    }
  }  ### End if rnamotif_information is defined
  else {
    $state->{genome_information} = $db->Get_ORF($state->{accession});
    my ($sequence, $orf_start, $orf_stop) = $state->{genome_information};
    my $motifs = new RNAMotif_Search;
    $state->{rnamotif_information} = $motifs->Search($sequence, $orf_start);
    $db->Put_RNAmotif($id, $state->{species}, $state->{accession}, $state->{rnamotif_information});
  }
}

sub Check_Environment {
  die("No rnamotif descriptor file set.") unless(defined($config->{descriptor_file}));
  die("Tmpdir must be executable: $!") unless(-x $config->{tmpdir});
  die("Tmpdir must be writable: $!") unless(-w $config->{tmpdir});
  die("Database not defined") unless($config->{db} ne 'prfconfigdefault_db');
  die("Database host not defined") unless($config->{host} ne 'prfconfigdefault_host');
  die("Database user not defined") unless($config->{user} ne 'prfconfigdefault_user');
  die("Database pass not defined") unless($config->{pass} ne 'prfconfigdefault_pass');

  unless(-r $config->{descriptor_file}) {
    RNAMotif_Search::Descriptor();
    die("Unable to read the rnamotif descriptor file: $!")
      unless(-r $config->{descriptor_file});
  }
}

sub signal_handler {
  $state->{time_to_die} = 1;
}

sub Print_Config {
  ### This is a little function designed to give the user a chance to abort
  if ($config->{do_nupack}) { print "I AM doing a nupack fold using the program: $config->{nupack}\n"; }
  else { print "I AM NOT doing a nupack fold\n"; }
  if ($config->{do_pknots}) { print "I AM doing a pknots fold using the program: $config->{pknots}\n"; }
  else { print "I AM NOT doing a pknots fold\n"; }
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
    print "nupack is using the following program for bootstrap:
$nu_boot and running: $config->{boot_iterations} times\n";
  }
  else { print "I AM NOT doing a boot.\n"; }
  if ($config->{arch_specific_exe}) { print "I AM USING ARCH SPECIFIC EXECUTABLES\n"; }
  else { print "I am not using arch specific executables\n"; }
  print "The default structure length in this run is: $config->{max_struct_length}\n";
  print "I am using the database: $config->{db} and user: $config->{user}\n";
  sleep(2);
}

sub Get_Num {
  my $data = shift;
  my $count = 0;
  foreach my $k (keys %{$data}) {
    $count++;
  }
  return($count);
}
