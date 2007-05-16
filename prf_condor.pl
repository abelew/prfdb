#!/usr/local/bin/perl -w
use strict;
use DBI;
use Time::HiRes;
use Getopt::Long;

use lib "$ENV{HOME}/usr/lib/perl5";
use lib 'lib';
use PRFConfig;
use PRFdb;
use RNAMotif_Search;
use RNAFolders;
use Bootlace;
use Overlap;
use MoreRandom;

my $config = $PRFConfig::config;
my $db = new PRFdb;
my %conf = ();
GetOptions(
           'nodaemon:i' => \$conf{nodaemon}, ## If this gets set, then the prf_daemon will exit before it gets to the queue
           'help|version' => \$conf{help}, ## Print some help information
           'accession|i:s' => \$conf{input_seq}, ## An accession to specifically fold.  If it is not already in the db
           ## Import it and then fold it.
           'copyfrom:s' => \$conf{copyfrom}, ## Another database from which to copy the genome table
           'input_file:s' => \$conf{input_file},  ## A file of accessions to import and queue
           'input_fasta:s' => \$conf{input_fasta}, ## A file of fasta data to import and queue
           'fasta_style:s' => \$conf{fasta_style}, ## The style of input fasta (sgd, ncbi, etc)
           ## By default this should be 0/1, but for some yeast genomes it may be 1000
           'fillqueue' => \$conf{fillqueue},  ## A boolean to see if the queue should be filled.
           'resetqueue' => \$conf{resetqueue}, ## A boolean to reset the queue
           'startpos:s' => \$conf{startpos},  ## A specific start position to fold a single sequence at, 
           ## also usable by inputfasta or inputfile
           'startmotif:s' => \$conf{startmotif}, ## A specific start motif to start folding at
           'length:i' => \$conf{max_struct_length},  ## i == integer
           'nupack:i' => \$conf{do_nupack},  ## If no type definition is given, it is boolean
           'pknots:i' => \$conf{do_pknots},  ## The question is, will these be set to 0 if not applied?
           'boot:i' => \$conf{do_boot},
           'workdir:s' => \$conf{workdir},
           'nupack_nopairs:i' => \$conf{nupack_nopairs_hack},
           'arch:i' => \$config{arch_specific_exe},
           'iterations:i' => \$conf{boot_iterations},
           'db|d:s' => \$conf{db},
           'host:s' => \$conf{host},
           'user:s' => \$conf{user},
           'pass:s' => \$conf{pass},
           'slip_site_1:s' => \$conf{slip_site_1},
           'slip_site_2:s' => \$conf{slip_site_2},
           'slip_site_3:s' => \$conf{slip_site_3},
           'slip_site_spacer_min:i' => \$conf{slip_site_spacer_min},
           'slip_site_spacer_max:i' => \$conf{slip_site_spacer_max},
           'stem1_min:i' => \$conf{stem1_min},
           'stem1_max:i' => \$conf{stem1_max},
           'stem1_bulge:i' => \$conf{stem1_bulge},
           'stem1_spacer_min:i' => \$conf{stem1_spacer_min},
           'stem1_spacer_max:i' => \$conf{stem1_spacer_max},
           'stem2_min:i' => \$conf{stem2_min},
           'stem2_max:i' => \$conf{stem2_max},
           'stem2_bulge:i' => \$conf{stem2_bulge},
           'stem2_loop_min:i' => \$conf{stem2_loop_min},
           'stem2_loop_max:i' => \$conf{stem2_loop_max},
           'stem2_spacer_max:i' => \$conf{stem2_spacer_min},
           'stem2_spacer_max:i' => \$conf{stem2_spacer_max},
           'num_daemons:i' => \$conf{num_daemons},
           'condor_memory:i' => \$conf{condor_memory},
           'condor_os:i' => \$conf{condor_os},
           'condor_arch:s' => \$conf{condor_arch},
           'condor_universe:s' => \$conf{condor_universe},
          );
foreach my $opt (keys %conf) {
  $config->{$opt} = $config{$opt} if (defined($conf{$opt}));
}

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
             rnamotif_information => undef,
             nupack_information => undef,
             pknots_information => undef,
             boot_information => undef,
             done_count => 0,
            };

### START DOING WORK NOW
chdir($config->{basedir});
Check_Environment();
Print_Config();
Check_Tables();

## Some Arguments should be checked before others...
## These first arguments are not exclusive and so are separate ifs
if (defined($config->{help})) {
  Print_Help();
}
if (defined($config->{fillqueue}))
  $db->FillQueue();
}
if (defined($config->{resetqueue})) {
  $db->Reset_Queue();
}
if (defined($config->{copyfrom})) {
  $db->Copy_Genome($config->{copyfrom});
}
if (defined($config->{input_file})) {
  if (defined($config->{startpos})) {
    Read_Accessions($config->{input_file}, $config->{startpos});
  }
  else {
    Read_Accessions($config->{input_file});
  }
}
if (defined($config->{accession})) {
  $db->Import_CDS($config->{accession});
  $state->{queue_id} = 0; ## Dumb hack lives on
  $state->{accession} = $config->{accession};
  $state->{genome_id} = $db->Get_GenomeId_From_Accession($config->{accession});
  if (defined($config->{startpos})) {
    Gather($state, $config->{startpos});
  }
  elsif (defined($config->{startmotif}) {
    Gather($state, $config->{startmotif});
  }
  else {
    Gather($state);
  }
  ## Once the prf_daemon finishes this accession it will start reading the queue...
}
if (defined($config->{input_fasta})) {
  if (defined($config->{startpos})) {
    $db->Import_Fasta($config->{input_fasta}, $config->{fasta_style}, $config->{startpos});
  }
  else {
    $db->Import_Fasta($config->{input_fasta}, $config->{fasta_style});
  }
}
#  else {
#    $state->{queue_id} = 0;  ## A dumb hack.  Why did I do this hack?  I think it
#    ## has to do with the import and searching of individual viral genomes
#    $state->{accession} = $ARGV[0];
#    $state->{genome_id} = $db->Get_GenomeId_From_Accession($ARGV[0]);
#    Gather($state);
#  }
#}
if ($config->{nodaemon} eq '1') {
  print "No daemon is set, existing before reading queue.\n";
  exit(0);
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
  my $ids = $db->Grab_Queue();
  $state->{queue_id} = $ids->{queue_id};
  $state->{genome_id} = $ids->{genome_id};
  if (defined($state->{genome_id})) {
    Gather($state);
  } ## End if have an entry in the queue
  else {
    sleep(60);
      $state->{done_count}++;
  }    ## no longer have $state->{genome_id}
}      ### End waiting for time to die

sub Print_Help {
  print "This is the help.\n";
  exit(0);
}

sub Read_Accessions {
  my $accession_file = shift;
  my $startpos = shift;
  open(AC, "<$accession_file") or die "Could not open the file of accessions $!";
  while (my $accession = <AC>) {
    chomp $accession;
    print "Importing Accession: $accession\n";
    if (defined($startpos)) {
      $db->Import_CDS($accession, $startpos);
    }
    else {
      $db->Import_CDS($accession);
    }
  }
}

## Start Gather
sub Gather {
  my $state = shift;
  my $ref = $db->Id_to_AccessionSpecies($state->{genome_id});
  $state->{accession} = $ref->{accession};
  $state->{species} = $ref->{species};
  print "\nWorking with: qid:$state->{queue_id} gid:$state->{genome_id} sp:$state->{species} acc:$state->{accession}\n";
  $state->{genome_information} = $db->Get_ORF($state->{accession});
  my $sequence = $state->{genome_information}->{sequence};
  my $orf_start = $state->{genome_information}->{orf_start};
  my $motifs = new RNAMotif_Search;
  my $rnamotif_information = $motifs->Search(
                                                   $state->{genome_information}->{sequence},
                                                   $state->{genome_information}->{orf_start});
  $state->{rnamotif_information} = $rnamotif_information;
  return(0) unless(defined($state->{rnamotif_information})); ## If rnamotif_information is null
  ## Now I should have 1 or more start sites
  STARTSITE: foreach my $slipsite_start (keys %{$rnamotif_information}) {
    my $nupack_mfe_id;
    my $pknots_mfe_id;
    my $seqlength;
    $state->{fasta_file} = $rnamotif_information->{$slipsite_start}{filename};
    $state->{sequence} = $rnamotif_information->{$slipsite_start}{sequence};
    if (!defined($state->{fasta_file} 
                 or $state->{fasta_file} eq '' 
                 or !-r $state->{fasta_file})) {
      print "The fasta file for: $state->{accession} $slipsite_start does not exist.\n";
      print "You may expect this script to die momentarily.\n";
    }
    my $check_seq = Check_Sequence_Length();
    if ($check_seq eq 'shorter than wanted') {
      print "The sequence is: $check_seq and will be skipped.\n";
      unlink($state->{fasta_file});
      next STARTSITE;
    }
    elsif ($check_seq eq 'null') {
	print "The sequence is null and will be skipped.\n";
	unlink($state->{fasta_file});
	next STARTSITE;
    }
    elsif ($check_seq eq 'polya') {
	print "The sequence is polya and will be skipped.\n";
	unlink($state->{fasta_file});  ## Get rid of each fasta file
	next STARTSITE;
    }

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
}
## End Gather

## Start Check_Environment
sub Check_Environment {
  die("No rnamotif descriptor file set.") unless(defined($config->{descriptor_file}));
  die("Workdir must be executable: $!") unless(-x $config->{workdir});
  die("Workdir must be writable: $!") unless(-w $config->{workdir});
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
## End Check_Environment

sub Check_Tables {
  my $test = $db->Tablep($config->{queue_table});
  unless($test) {
    $db->Create_Queue($config->{queue_table});
    $db->FillQueue();
  }
}

## Start Print_Config
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
## End Print_Config

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

## Start Check_Boot_Connectivity
sub Check_Boot_Connectivity {
    my $state = shift;
    my $slipsite_start = shift;
    my $genome_id = $state->{genome_id};
    my $check_statement = qq(SELECT mfe_id, mfe_method, id, genome_id FROM boot WHERE genome_id = ? and start = ?);
    my $answer = $db->MySelect($check_statement,[$genome_id,$slipsite_start]);
    my $num_fixed = 0;
    foreach my $boot (@{$answer}) {
      my $mfe_id = $boot->[0];
      my $mfe_method = $boot->[1];
      my $boot_id = $boot->[2];
      my $genome_id = $boot->[3];
      if (!defined($mfe_id) or $mfe_id == '0') {
        ## Then reconnect it using $mfe_method and $boot_id and $genome_id
        my $new_mfe_id_stmt = qq(SELECT id FROM mfe where genome_id = ? and start = ? and algorithm = ?);
        my $new_mfe_id_arrayref = $db->MySelect($new_mfe_id_stmt,[$genome_id,$slipsite_start,$mfe_method]);
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
        my $update_mfe_id_statement = qq(UPDATE boot SET mfe_id = ? WHERE id = ?);
        $db->Execute($update_mfe_id_statement,[$new_mfe_id,$boot_id]);
        $num_fixed++;
      } ### End if there is no mfe_id
    } ### End foreach boot in the list
    return($num_fixed);
}
## End Check_Boot_Connectivity

## Start Check_Nupack
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
}
## End Check_Nupack

## Start Check_Pknots
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
}
## End Check_Pknots

## Start Clean_Up
sub Clean_Up {
    $db->Done_Queue($state->{genome_id});
    foreach my $k (keys %{$state}) { $state->{$k} = undef unless ($k eq 'done_count'); }
}
## End Clean_Up

## Start Check_Sequence_Length
sub Check_Sequence_Length {
    my $filename = $state->{fasta_file};
    my $sequence = $state->{sequence};
    my @seqarray = split(//, $sequence);
    my $sequence_length = $#seqarray;
    my $wanted_sequence_length = $config->{max_struct_length};
    open(IN, "<$filename") or die ("Check_Sequence_Length: Couldn't open $filename $!");
    ## OPEN IN in Check_Sequence_Length
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
    ## CLOSE IN in Check_Sequence Length
    my $current_length = scalar(@out);
    if (!defined($sequence) or $sequence eq '') {
	return('null');
    }
    if ($sequence =~ /^a+$/) {
	return('polya');
    }
    elsif ($sequence =~ /aaaaaaa$/ and $sequence_length < $wanted_sequence_length) {
	return('polya');
    }
    elsif ($sequence_length > $wanted_sequence_length) {
	open(OUT, ">$filename") or die("Could not open $filename $!");
	## OPEN OUT in Check_Sequence_Length
	print OUT "$output\n";
	foreach my $char (0 .. $sequence_length) {
	    print OUT $out[$char];
	}
	print OUT "\n";
	close(OUT);
	## CLOSE OUT in Check_Sequence_Length
	return('longer than wanted');
    }
    elsif ($sequence_length == $wanted_sequence_length) {
	return('equal');
    }
    elsif ($sequence_length < $wanted_sequence_length) {
	return('shorter than wanted');
    }
    else {
	return('unknown');
    }
}
## End Check_Sequence_length

sub DESTROY {
  unlink($state->{fasta_file});
  $db->Disconnect();
}
