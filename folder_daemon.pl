#!/usr/bin/perl -w
use strict;
use POSIX;
use DBI;
use Time::HiRes;

use lib 'lib';
use PRFConfig;
use PRFdb;
use RNAMotif_Search;
use RNAFolders;
use Bootlace;

my $config = $PRFConfig::config;
chdir($config->{basedir});

if (defined($ARGV[0])) {
  if ($ARGV[0] eq 'split') {
	Split_Queue($ARGV[1]);
	exit(0);
  }
  elsif ($ARGV[0] eq 'privqueue') {
	$PRFConfig::config->{privqueue} = $ARGV[1];
  }
}

Check_Environment();

my $time_to_die = 0;
my $pid = fork;
exit if $pid;
die "Could not fork: $!\n" unless defined($pid);

POSIX::setsid() or die "Could not start a new process group: $!\n";
$SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signal_handler;

until ($time_to_die) {
  Time::HiRes::usleep(100);
  ## Code goes here.
  ## Process:
  # 1.  Open queue file, read last line; gather species, accession, start
  # 1a. Sleep if empty
  # 2.  Rewrite queue file without last line
  # 3.  Query db for existing information on species, accession, start
  # 4.  Next if exists.
  # 4a. Fold via algorithms
  # 5. Fill db

  ## Check queue file.
  my $public_datum = Check_Queue('public');
  if (defined($public_datum)) {  ## The public queue is not empty
    my $existsp = Check_Db($public_datum);
  }
  else {  ## The public queue is empty
    my $private_datum = Check_Queue('private');
    if (defined($private_datum)) {  # The queue is not empty
      my $existsp = Check_Db($private_datum);
    }
    else {  ## Both queues are empty
      sleep(10);
    }
  }  ## End the public queue is empty
}    ## End until it is time to die


sub Check_Queue {
  my $type = shift;
  my $qfile = $type . '_queue';
  my $return = {};
  open (FH, "+<$qfile") or die "can't update queue: $qfile: $!";
  my $addr = undef;
  my $line_bak;
  while (my $line = <FH> ) {
	$addr = tell(FH) unless eof(FH);
	$line_bak = $line;
  }
  return(undef) unless defined($line_bak);
  chomp $line_bak;
  my ($species, $accession) = split(/\t/, $line_bak);
  $return->{species} = $species;
  $return->{accession} = $accession;
  truncate(FH, $addr);
  return($return);
}

sub Check_Db {
  my $datum = shift;
  my $db = new PRFdb;
  my $motifs = new RNAMotif_Search;
  ## First see that there is rna motif information
  my $motif_info;
  if ($PRFConfig::config->{dbinput} ne 'dbi') { $motif_info = 0; }
  else { $motif_info = $db->Get_RNAmotif($datum->{species}, $datum->{accession}); }
  if ($motif_info) {  ## If the motif information _does_ exist, check the folding information
    foreach my $start (keys %{$motif_info}) {  ## For every start site in the sequence
      my $folding;
      my $fdata = $motif_info->{$start}{filedata};
      if ($PRFConfig::config->{dbinput} ne 'dbi') { $folding = 0; } ##Yeah yeah, bad style.  Except logically it is simpler
      ## to just drop out if we are not in a dbi environment.
      else { ## Therefore this is in a DBI environment
        my $nupack_folding = undef;
        my $pknots_folding = undef;
        my $mfold_folding = undef;

        if ($PRFConfig::config->{do_nupack}) {  ## Check the configuration file for nupack
          $nupack_folding = $db->Get_RNAfolds('nupack', $datum->{species}, $datum->{accession}, $start);
          if ($nupack_folding ne '0') {  ## Both have motif and folding
            Out("HAVE NUPACK FOLDING AND MOTIF for $datum->{species} $datum->{accession}");
            return(1);
          }
          else { ## Want nupack, have motif, no folding, so need to make a tmp file for nupack.
            my $filename = $db->Motif_to_Fasta($motif_info->{$start}{filedata});
            my $slippery = $db->Get_Slippery($db->Get_Sequence($datum->{species}, $datum->{accession}), $start);
            my $fold_search = new RNAFolders(
                                             file => $filename,
                                             accession => $datum->{accession},
                                             start => $start,
                                             slippery => $slippery,
                                             species => $datum->{species},);
            my $nupack_info = $fold_search->Nupack();
            $db->Put_Nupack($nupack_info);
          }  ## Else checking for folding and motif information
        }  ## End do_nupack
        if ($PRFConfig::config->{do_pknots}) {  ## Check to see if pknots should be run
          $pknots_folding = $db->Get_RNAfolds('pknots', $datum->{species}, $datum->{accession}, $start);
          if ($pknots_folding ne '0') {  ## Both have motif and folding
            Out("HAVE PKNOTS FOLDING AND MOTIF for $datum->{species} $datum->{accession}");
            return(1);
          }
          else {  ## Want pknots, have motif, no folding, so make a tempfile
            my $filename = $db->Motif_to_Fasta($motif_info->{$start}{filedata});
            my $slippery = $db->Get_Slippery($db->Get_Sequence($datum->{species}, $datum->{accession}), $start);
            my $fold_search = new RNAFolders(file => $filename,
                                             accession => $datum->{accession},
                                             start => $start,
                                             slippery => $slippery,
                                             species => $datum->{species},);
            my $pknots_info = $fold_search->Pknots();
            $db->Put_Pknots($pknots_info);
          }  ## End checking for folding and motif information
        } ## End check for do_pknots

        ## At this point pknot and nupack should both have output for the case in which there there is not folding/motif info
        ## Now we wish to see if there is bootstrap informaiton for mfold
        ## FIXME: This will need to be reworked to deal with different randomization schemes and may need to store different data
        if ($PRFConfig::config->{do_bootlace}) {
          my $boot = new Bootlace(
                                  inputfile => $filename,
                                  repetitions => $PRFConfig::config->{boot_repetitions},
                                  mfe_algorithms => { mfold => \&RNAFolders::Mfold_MFE, },
                                  randomizers => { coin => \&Randomize::Coin_Random, },
                                  );
          $boot->Go();
        }
 #       if ($PRFConfig::config->{do_mfold}) {
 #         my $mfold_test = $db->Get_Mfold($datum->{species}, $datum->{accession}, $start);
 #         if ($mfold_test ne '0') {  ## Do not have mfold mfe data for this species and accession
 #           Out("HAVE MFOLD data and RNAMotif for $datum->{species} $datum->{accession}");
 #           return(1);
 #         }  ## End having mfold data
 #         else {
 #           my $filename = $db->Motif_to_Fasta($motif_info->{$start}{filedata});
 #           my $slippery = $db->Get_Slippery($db->Get_Sequence($datum->{species}, $datum->{accession}), $start);
 #           my $fold_search = new RNAFolders(
 #                                            file => $filename,
 #                                            accession => $datum->{accession},
 #                                            start => $start,
 #                                            slippery => $slippery,
 #                                            species => $datum->{species},);
 #           my $mfold_info = $fold_search->Mfold();
 #           $db->Put_Mfold($mfold_info);
 #         }  ## End checking for mfold data
        }  ## End checking if we are using mfold
      }  ## End if we are in a dbi environment
    }  ## End foreach piece of $motif_info
  }  ## End if there is motif information
  else { ## No folding information
    my $sequence = $db->Get_Sequence($datum->{species}, $datum->{accession});
    my $slipsites = $motifs->Search($sequence);
    $db->Put_RNAmotif($datum->{species}, $datum->{accession}, $slipsites);
    Out("NO MOTIF, NO FOLDING for $datum->{species} $datum->{accession}");
    my $success = scalar(%{$slipsites});
    if ($success eq '0') { Out("$datum->{species} $datum->{accession} has no slippery sites."); }
    foreach my $start (keys %{$slipsites}) {
      Out("STARTING FOLD FOR $start in $datum->{accession}");
      my $slippery = $db->Get_Slippery($sequence, $start); 
      my $fold_search = new RNAFolders(file => $slipsites->{$start}{filename},
                                       accession => $datum->{accession},
                                       start => $start,
                                       slippery => $slippery,
                                       species => $datum->{species},);
      my ($nupack_info, $pknots_info);
      if ($PRFConfig::config->{do_nupack}) {
        $nupack_info = $fold_search->Nupack();
        $db->Put_Nupack($nupack_info);
      }

      if ($PRFConfig::config->{do_pknots}) {
        $pknots_info = $fold_search->Pknots();
        $db->Put_Pknots($pknots_info);
      }

      ## At this point pknot and nupack should both have output for the case in which there there is not folding/motif info
      ## Now we wish to see if there is bootstrap informaiton for mfold
      ## FIXME: This will need to be reworked to deal with different randomization schemes and may need to store different data
      if ($PRFConfig::config->{do_mfold}) {
        $mfold_info = $fold_search->Mfold();
        $db->Put_Mfold($mfold_info);
      }

    unlink($slipsites->{$start}{filename});
    } ##End checking slipsites for a locus when have not motif nor folding information
  } ## End no motif nor folding information.
}

sub Split_Queue {
  my $num = shift;
  my $count = 0;
  no strict 'refs';
  for my $c ($count .. $num) {
	my $priv_handle = "private_$c";
	open($priv_handle, ">$priv_handle");
  }

  open(PRIV_IN, "<private_queue");
  $count = 0;
  while (my $line = <PRIV_IN>) {
    $count++;
    my $serial = $count % $num;
    my $handle = "private_" . $serial;
    Out("Printing $line to $handle");
    print $handle $line;
  }
}

sub Check_Environment {
  die("No rnamotif descriptor file set.") unless(defined($PRFConfig::config->{descriptor_file}));
  die("Missing rnamotif: $!") unless(-x $PRFConfig::config->{rnamotif});
  die("Missing pknots: $!") unless(-x $PRFConfig::config->{pknots});
  die("Missing nupack: $!") unless(-x $PRFConfig::config->{nupack});
  die("Missing rmprune: $!") unless(-x $PRFConfig::config->{rmprune});
  die("Missing mfold: $!") unless(-x $PRFConfig::config->{mfold});
  die("Tmpdir must be executable: $!") unless(-x $PRFConfig::config->{tmpdir});
  die("Tmpdir must be writable: $!") unless(-w $PRFConfig::config->{tmpdir});
  die("Privqueue must be writable: $!") unless(-w $PRFConfig::config->{privqueue});
  die("Pubqueue must be writable: $!") unless(-w $PRFConfig::config->{pubqueue});
  die("Database not defined") unless(defined($PRFConfig::config->{db}));
  die("Database host not defined") unless(defined($PRFConfig::config->{host}));
  die("Database user not defined") unless(defined($PRFConfig::config->{user}));
  die("Database pass not defined") unless(defined($PRFConfig::config->{pass}));
  unless(-r $PRFConfig::config->{descriptor_file}) {
	RNAMotif_Search::Descriptor();
	die("Unable to read the rnamotif descriptor file: $!") unless(-r $PRFConfig::config->{descriptor_file});
  }
}

sub signal_handler {
  $time_to_die = 1;
}

