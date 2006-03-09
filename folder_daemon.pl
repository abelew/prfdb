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
use Overlap;
use MoreRandom;

my $arg = $ARGV[0];
my $config = $PRFConfig::config;
my $db = new PRFdb;
chdir($config->{basedir});
Check_Environment();
if (defined($arg)) {
  if ($arg eq '01') {
    $db->Reset_Queue();  ## For anything which sets out = '1' and is not finished (done != '1'
  }
}

my $state = {
	     time_to_die => undef,
	     queue_id => undef,
	     pknots_mfe_id => undef,
             nupack_mfe_id => undef,
	     genome_id => undef,
	     accession => undef,
	     species => undef,
	     seqlength => $config->{max_struct_length} + 1,
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
  elsif ($ARGV[0] eq '-v') {
    print "This is version: 1.77 from cvs\n";
    exit();
  }
exit();
}


until (defined($state->{time_to_die})) {
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
  print "\nWorking with: qid:$state->{queue_id} gid:$state->{genome_id} sp:$state->{species} acc:$state->{accession}\n";
  Gather_Rnamotif($state);
  return(0) unless(defined($state->{rnamotif_information})); ## If rnamotif_information is null
  my $rnamotif_information = $state->{rnamotif_information};
  ## Now I should have 1 or more start sites
  foreach my $slipsite_start (keys %{$rnamotif_information}) {
    my $nupack_mfe_id;
    my $pknots_mfe_id;
    my $seqlength;
    $state->{fasta_file} = $rnamotif_information->{$slipsite_start}{filename};
    if (!defined($state->{fasta_file} or $state->{fasta_file} eq '')) {
	print "The fasta file for: $state->{accession} $slipsite_start does not exist.\n";
	print "You may expect this script to die momentarily.\n";
    }
    Check_Sequence_Length($state->{fasta_file});
    my $fold_search = new RNAFolders(
				     file => $state->{fasta_file},
				     genome_id => $state->{genome_id},
				     species => $state->{species},
				     accession => $state->{accession},
				     start => $slipsite_start,
				    );

    if ($config->{do_nupack}) { ### Do we run a nupack fold?
      $nupack_mfe_id = Check_Nupack($fold_search, $slipsite_start);
      $seqlength = $db->Get_Seqlength($nupack_mfe_id);
    } ### End check if we should do a nupack fold

    if ($config->{do_pknots}) { ### Do we run a pknots fold?
      $pknots_mfe_id = Check_Pknots($fold_search, $slipsite_start);
      $seqlength = $db->Get_Seqlength($pknots_mfe_id);
    }

    if ($config->{do_boot}) {
	my $boot = new Bootlace(
                            genome_id => $state->{genome_id},
                            nupack_mfe_id => (defined($state->{nupack_mfe_id})) ? $state->{nupack_mfe_id} : $nupack_mfe_id,
                            pknots_mfe_id => (defined($state->{pknots_mfe_id})) ? $state->{pknots_mfe_id} : $pknots_mfe_id,
                            inputfile => $state->{fasta_file},
                            species => $state->{species},
                            accession => $state->{accession},
                            start => $slipsite_start,
                            seqlength => $seqlength,
                            iterations => $config->{boot_iterations},
                            boot_mfe_algorithms => $config->{boot_mfe_algorithms},
                            randomizers => $config->{boot_randomizers},
                           );

	my $boot_folds = $db->Get_Num_Bootfolds($state->{genome_id}, $slipsite_start);
	my $number_boot_algos = Get_Num($config->{boot_mfe_algorithms});
	## CHECKME!  I do not think this next line is appropriate
	#my $needed_boots = $number_boot_algos * $number_rnamotif_information;
	my $needed_boots = $number_boot_algos;
      if ($boot_folds == $needed_boots) {
        print "Already have $boot_folds pieces of boot information for $state->{genome_id} and start:$slipsite_start\n";
	Check_Boot_Connectivity($state, $slipsite_start);
      }
      elsif ($boot_folds < $needed_boots) {
        print "I have $boot_folds but need $needed_boots\n";
	my $bootlaces = $boot->Go();
	$db->Put_Boot($bootlaces);
      }
      else {
	  print "Already have $boot_folds pieces of boot information for $state->{genome_id} and start:$slipsite_start -- only needed $needed_boots\n";
	  Check_Boot_Connectivity($state, $slipsite_start);
      } ### End if there are no bootlaces
    }  ### End if we are to do a boot

    if ($config->{do_overlap}) {
	my $sequence_information = $db->Get_Sequence_from_id($state->{genome_id});
	my $overlap = new Overlap(
				  genome_id => $state->{genome_id},
				  species => $state->{species},
				  accession => $state->{accession},
				  sequence => $sequence_information,
				  );
	my $overlap_info = $overlap->Alts($slipsite_start);
	$db->Put_Overlap($overlap_info);
    } ## End check to do an overlap

    ## Clean up after yourself!
    unlink($state->{fasta_file});  ## Get rid of each fasta file
  } ### End foreach slipsite_start
  Clean_Up();
  ## Clean out state
}  ## End Gather

sub Gather_Rnamotif {
  my $state = shift;
  ### First, get the accession and species
  my $rnamotif_information = $db->Get_RNAmotif($state->{genome_id}, $state->{seqlength});
  if (defined($rnamotif_information)) {
    foreach my $start (keys %{$rnamotif_information}) {
      if ($start eq 'NONE') {
	print "$state->{genome_id} has no slippery sites.\n";
	Clean_Up();
	next;
      }
      else {
	$rnamotif_information->{$start}{filename} = $db->Motif_to_Fasta($rnamotif_information->{$start}{filedata});
      }
      $state->{rnamotif_information} = $rnamotif_information;
    }
  }  ### End if rnamotif_information is defined
  else {
    $state->{genome_information} = $db->Get_ORF($state->{accession});
     my $return = $state->{genome_information};
     my $sequence = $return->{sequence};
     my $orf_start = $return->{orf_start};
     my $orf_stop = $return->{orf_stop};
    my $motifs = new RNAMotif_Search;
    $state->{rnamotif_information} = $motifs->Search($sequence, $orf_start);
    $db->Put_RNAmotif($state->{genome_id}, $state->{species}, $state->{accession}, $state->{rnamotif_information}, $state->{seqlength});
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
  if ($config->{nupack_nopairs_hack}) { print "I AM using a hacked version of nupack!\n"; }
  else { print "I AM NOT using a hacked version of nupack!\n"; }
  if ($config->{do_nupack}) { print "I AM doing a nupack fold using the program: $config->{nupack}\n"; }
  else { print "I AM NOT doing a nupack fold\n"; }
  if ($config->{do_pknots}) { print "I AM doing a pknots fold using the program: $config->{pknots}\n"; }
  else { print "I AM NOT doing a pknots fold\n"; }
  if ($config->{do_boot}) {
    print "PLEASE CHECK THE prfdb.conf to see if you are using NOPAIRS\n";
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
  print "I am using the database: $config->{db} and user: $config->{user}\n\n\n";
  sleep(1);
}

sub Get_Num {
  my $data = shift;
  my $count = 0;
  foreach my $k (keys %{$data}) {
    $count++;
  }
  return($count);
}

sub Check_Boot_Connectivity {
    my $state = shift;
    my $slipsite_start = shift;
    my $genome_id = $state->{genome_id};
    my $check_statement = qq(SELECT mfe_id, mfe_method, id, genome_id FROM boot WHERE genome_id = '$genome_id' and start = '$slipsite_start');
    my $answer = $db->MySelect($check_statement);
    my $num_fixed = 0;
    foreach my $boot (@{$answer}) {
      my $mfe_id = $boot->[0];
      my $mfe_method = $boot->[1];
      my $boot_id = $boot->[2];
      my $genome_id = $boot->[3];
      if (!defined($mfe_id) or $mfe_id == '0') {
        ## Then reconnect it using $mfe_method and $boot_id and $genome_id
        my $new_mfe_id_stmt = qq(SELECT id FROM mfe where genome_id = '$genome_id' and start = '$slipsite_start' and algorithm = '$mfe_method');
        my $new_mfe_id_arrayref = $db->MySelect($new_mfe_id_stmt);
        my $new_mfe_id = $new_mfe_id_arrayref->[0]->[0];
        if ((!defined($new_mfe_id)
             or $new_mfe_id == '0'
             or $new_mfe_id eq '')
            and $mfe_method eq 'nupack') {
          ### Then there is no nupack information :(
          #print "No Nupack information!\n";
          my $fold_search = new RNAFolders(
                                           file => $state->{fasta_file},
                                           genome_id => $state->{genome_id},
                                           species => $state->{species},
                                           accession => $state->{accession},
                                           start => $slipsite_start,
                                          );
          $new_mfe_id = Check_Nupack($fold_search, $slipsite_start);
        }
        elsif ((!defined($new_mfe_id)
                or $new_mfe_id == '0'
                or $new_mfe_id eq '')
               and $mfe_method eq 'pknots') {
          ### Then there is no pknots information :(
          my $fold_search = new RNAFolders(
                                           file => $state->{fasta_file},
                                           genome_id => $state->{genome_id},
                                           species => $state->{species},
                                           accession => $state->{accession},
                                           start => $slipsite_start,
                                          );
          $new_mfe_id = Check_Pknots($fold_search, $slipsite_start);
        } ### End if there is no mfe_id and pknots was the algorithm
        my $update_mfe_id_statement = qq(UPDATE boot SET mfe_id = '$new_mfe_id' WHERE id = '$boot_id');
        $db->Execute($update_mfe_id_statement);
        $num_fixed++;
      } ### End if there is no mfe_id
    } ### End foreach boot in the list
    return($num_fixed);
}

sub Check_Nupack {
    my $fold_search = shift;
    my $slipsite_start = shift;
    my $nupack_mfe_id;
    my $nupack_folds = $db->Get_Num_RNAfolds('nupack', $state->{genome_id}, $slipsite_start);
    if ($nupack_folds > 0) {
      print "$state->{genome_id} has $nupack_folds > 0 nupack_folds\n";
      my $seqlen = $config->{max_struct_length} + 1;
      print "TEST seqlen: $seqlen genome_id:$state->{genome_id} slipsite_start:$slipsite_start seqlen:$seqlen\n";
      $state->{nupack_mfe_id} = $db->Get_MFE_ID($state->{genome_id}, $slipsite_start, $seqlen, 'nupack');
      $nupack_mfe_id = $state->{nupack_mfe_id};
      print "Check_nupack - already done: state: $state->{nupack_mfe_id} var: $nupack_mfe_id\n";
    }
    else { ### If there are no existing folds...
      print "$state->{genome_id} has only $nupack_folds <= nupack_folds\n";
      my $nupack_info;
      if ($config->{nupack_nopairs_hack}) {
        $nupack_info = $fold_search->Nupack_NOPAIRS();
      }
      else {
        $nupack_info = $fold_search->Nupack();
      }
      $nupack_mfe_id = $db->Put_Nupack($nupack_info);
      $state->{nupack_mfe_id} = $nupack_mfe_id;
    }  ### End if there are no existing folds
    print "Check_Nupack Test: state:$state->{nupack_mfe_id} var: $nupack_mfe_id\n";
    return($nupack_mfe_id);
}  ## End Check_Nupack

sub Check_Pknots {
    my $fold_search = shift;
    my $slipsite_start = shift;
    my $pknots_mfe_id;
    my $pknots_folds = $db->Get_Num_RNAfolds('pknots', $state->{genome_id}, $slipsite_start);
    if ($pknots_folds > 0) {### If there ARE existing folds...
      print "$state->{genome_id} has $pknots_folds > 0 pknots_folds\n";
      my $seqlen = $config->{max_struct_length} + 1;
      print "TEST seqlen: $seqlen genome_id:$state->{genome_id} slipsite_start:$slipsite_start seqlen:$seqlen\n";
      $state->{pknots_mfe_id} = $db->Get_MFE_ID($state->{genome_id}, $slipsite_start, $seqlen, 'pknots');
      $pknots_mfe_id = $state->{pknots_mfe_id};
      print "Check_pknots - already done: state: $state->{pknots_mfe_id}\n";
    }
    else { ### If there are NO existing folds...
      print "$state->{genome_id} has only $pknots_folds <= 0 pknots_folds\n";
      my $pknots_info = $fold_search->Pknots();
      $pknots_mfe_id = $db->Put_Pknots($pknots_info);
      $state->{pknots_mfe_id} = $pknots_mfe_id;
    }  ### Done checking for pknots folds
    print "Check_Pknots Test: state:$state->{pknots_mfe_id} var: $pknots_mfe_id\n";
    return($pknots_mfe_id);
} ## End Check_Pknots


sub Clean_Up {
    $db->Done_Queue($state->{genome_id});
    foreach my $k (keys %{$state}) { $state->{$k} = undef unless ($k eq 'done_count'); }
}

sub Check_Sequence_Length {
    my $filename = shift;
    my $sequence_length = $config->{max_struct_length};
    open(IN, "<$filename") or die ("Check_Sequence_Length: Couldn't open $filename $!");
    my $output = '';
    my @out = ();
    while (my $line = <IN>) {
	chomp $line;
	if ($line =~ /^\>/) {
	    $output .= $line;
	}
	else {
	    my @tmp = split(//, $line);
	    push(@out, @tmp);
	}
    }
    close(IN);
    my $current_length = scalar(@out);
    if ($current_length <= $sequence_length) { return(undef); }
    open(OUT, ">$filename") or die("Could not open $filename $!");
    print OUT "$output\n";
    foreach my $char (0 .. $sequence_length) {
	print OUT $out[$char];
    }
    print OUT "\n";
    close(OUT);
}
