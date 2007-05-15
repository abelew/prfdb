#!/usr/local/bin/perl -w
use strict;
use POSIX;
use DBI;
use Time::HiRes;

use lib "$ENV{HOME}/usr/lib/perl5";
use lib 'lib';
use PRFConfig;
use PRFdb;
use RNAFolders;
use Bootlace;
use MoreRandom;

my $config = $PRFConfig::config;
my $db = new PRFdb;
my $state = {
             time_to_die => undef,
             queue_id => undef,
             pknots_mfe_id => undef,
             nupack_mfe_id => undef,
             genome_id => undef,
             accession => undef,
             species => undef,
             seqlength => undef,
             sequence => undef,
             fasta_file => undef,
             genome_information => undef,
             nupack_information => undef,
             pknots_information => undef,
             boot_information => undef,
             done_count => 0,
            };

### START DOING WORK NOW
chdir($config->{basedir});
Check_Environment();
## Put some helper functions here
if (defined($ARGV[0])) {
  if ($ARGV[0] eq '-q') {
    $db->FillQueue();
  }
  elsif ($ARGV[0] eq '-v') {
    print "This is version: 1.77 from cvs\n";
    exit();
  }
  elsif ($ARGV[0] eq '01' or $ARGV[0] eq 'reset') {
    $db->Reset_Queue();  ## For anything which sets checked_out = '1' and is not finished (done != '1'
  }
}

until (defined($state->{time_to_die})) {
  ### You can set a configuration variable 'master' so that it will not die
  if ($state->{done_count} > 60 and !defined($config->{master})) { $state->{time_to_die} = 1 };
  if (defined($config->{max_struct_length})) {
      $state->{seqlength} = $config->{max_struct_length} + 1;
  }
  else {
      $state->{seqlength} = 100;
  }
  my $ids = $db->Grab_Queue('landscape');
  $state->{queue_id} = $ids->{queue_id};
  $state->{genome_id} = $ids->{genome_id};
  if (defined($state->{genome_id})) {
    Gather($state);
  }  ## End if have an entry in the public queue
  else {
    print "Incrementing done_count: $state->{done_count}\n";
    sleep(5);
    $state->{done_count}++;
  }  ## No longer have $state->{genome_id}
}      ### End waiting for time to die

## Start Gather
sub Gather {
  my $state = shift;
  my $ref = $db->Id_to_AccessionSpecies($state->{genome_id});
  $state->{accession} = $ref->{accession};
  $state->{species} = $ref->{species};
  my $message = "qid:$state->{queue_id} gid:$state->{genome_id} sp:$state->{species} acc:$state->{accession}\n";
  print "\nWorking with: $message";
  ## Given a sequence, we want to perform a folding with both algorithms
  ## Every n bases where n is defined by the config variable window_space
  my $sequence = $db->Get_Sequence($state->{accession});
  my @seq_array = split(//, $sequence);
  my $sequence_length = scalar(@seq_array);
  my $start_point = 0;
  while ($start_point + $state->{seqlength} <= $sequence_length) {
      my $individual_sequence = ">$message";
      my $end_point = $start_point + $config->{max_struct_length};

      foreach my $character ($start_point .. $end_point) {
	  $individual_sequence = $individual_sequence . $seq_array[$character];
      }
      $individual_sequence = $individual_sequence . "\n";
      $state->{fasta_file} = $db->Sequence_to_Fasta($individual_sequence);
      my $fold_search = new RNAFolders(
				       file => $state->{fasta_file},
				       genome_id => $state->{genome_id},
				       species => $state->{species},
				       accession => $state->{accession},
				       start => $start_point,
				       );

      my $nupack_foldedp = Already_Folded($state->{genome_id}, $start_point, 'nupack');
      my $pknots_foldedp = Already_Folded($state->{genome_id}, $start_point, 'pknots');
      my $nupack_bootp = Already_Folded($state->{genome_id}, $start_point, 'nupack', 'boot');
      my $pknots_bootp = Already_Folded($state->{genome_id}, $start_point, 'pknots', 'boot');
      my ($nupack_info, $nupack_mfe_id, $pknots_info, $pknots_mfe_id);
      if (!defined($nupack_foldedp)) {
        if ($config->{nupack_nopairs_hack}) {
          print "Running NOPAIRS\n";
          $nupack_info = $fold_search->Nupack_NOPAIRS('nopseudo');
        }
        else {
          $nupack_info = $fold_search->Nupack('nopseudo');
        }
        $nupack_mfe_id = $db->Put_Nupack($nupack_info, 'landscape');
        $state->{nupack_mfe_id} = $nupack_mfe_id;
      }
      if (!defined($pknots_foldedp)) {
	  $pknots_info = $fold_search->Pknots('nopseudo');
	  $pknots_mfe_id = $db->Put_Pknots($pknots_info, 'landscape');
	  $state->{pknots_mfe_id} = $pknots_mfe_id;
      }

#      my $boot = new Bootlace(
#			      genome_id => $state->{genome_id},
#			      nupack_mfe_id => (defined($state->{nupack_mfe_id})) ? $state->{nupack_mfe_id} : $nupack_mfe_id,
#			      pknots_mfe_id => (defined($state->{pknots_mfe_id})) ? $state->{pknots_mfe_id} : $pknots_mfe_id,
#			      inputfile => $state->{fasta_file},
#			      species => $state->{species},
#			      accession => $state->{accession},
#			      start => $start_point,
#			      seqlength => $state->{seqlength},
#			      iterations => $config->{boot_iterations},
#			      boot_mfe_algorithms => $config->{boot_mfe_algorithms},
#			      randomizers => $config->{boot_randomizers},
#			      );
#      my $bootlaces = $boot->Go();
#      $db->Put_Boot($bootlaces);

      ## The functional portion of the while loop is over, just set the state now
      $start_point = $start_point + $config->{window_space};
      unlink($state->{fasta_file});  ## Get rid of each fasta file
  }
  Clean_Up('landscape');
}
## End Gather

## Start Check_Environment
sub Check_Environment {
  die("Workdir must be executable: $!") unless(-x $config->{workdir});
  die("Workdir must be writable: $!") unless(-w $config->{workdir});
  die("Database not defined") unless($config->{db} ne 'prfconfigdefault_db');
  die("Database host not defined") unless($config->{host} ne 'prfconfigdefault_host');
  die("Database user not defined") unless($config->{user} ne 'prfconfigdefault_user');
  die("Database pass not defined") unless($config->{pass} ne 'prfconfigdefault_pass');

}
## End Check_Environment

## Start Get_Num
sub Get_Num {
  my $data = shift;
  my $count = 0;
  foreach my $k (keys %{$data}) {
    $count++;
  }
  return($count);
}
## End Get_Num

sub Already_Folded {
    my $genome_id = shift;
    my $startpos = shift;
    my $type = shift;
    my $bootp = shift;
    if (!defined($bootp)) {
	my $num_folds = $db->Get_Num_RNAfolds($type, $genome_id, $startpos, 'landscape');
	if ($num_folds > 0) {
	    return($num_folds);
	}
	else {
	    return(undef);
	}
    }
    else { ## look for bootp
	my $num_folds = $db->Get_Num_Bootfolds($type, $genome_id, $startpos, 'landscape');
	if ($num_folds > 0) {
	    return($num_folds);
	}
	else {
	    return(undef);
	}
    }
}

## Start Clean_Up
sub Clean_Up {
    $db->Done_Queue($state->{genome_id}, 'landscape');
    foreach my $k (keys %{$state}) { $state->{$k} = undef unless ($k eq 'done_count'); }
}
## End Clean_Up
