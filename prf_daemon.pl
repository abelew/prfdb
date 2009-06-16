#!/usr/bin/perl -w
use strict;
use DBI;
use Getopt::Long;
use lib "$ENV{HOME}/usr/lib/perl5";
use lib 'lib';
use PRFConfig;
use PRFdb;
use RNAMotif_Search;
use RNAFolders;
use Bootlace;
use Overlap;
use SeqMisc;
use PRFBlast;
$SIG{INT} = 'CLEANUP';
$SIG{BUS} = 'CLEANUP';
$SIG{SEGV} = 'CLEANUP';
$SIG{PIPE} = 'CLEANUP';
$SIG{ABRT} = 'CLEANUP';
$SIG{QUIT} = 'CLEANUP';
our $config = $PRFConfig::config;
setpriority(0,0,$config->{niceness});
our $db = new PRFdb;
our %conf = ();
$ENV{LD_LIBRARY_PATH} .= ":$config->{ENV_LIBRARY_PATH}";
GetOptions(## If this gets set, then the prf_daemon will exit before it gets to the queue
	   'nodaemon:i' => \$conf{nodaemon},  
	   'debug:i' => \$conf{debug},
	   ## Print some help information
	   'help|version' => \$conf{help},      
	   ## An accession to specifically fold.  If it is not already in the db  
	   ## Import it and then fold it.
	   'accession|i:s' => \$conf{accession},
	   'blast:s' => \$conf{blast},
	   'makeblast' => \$conf{makeblast},
           ## Create a local blast database from the genome
	   'optimize:s' => \$conf{optimize},
	   ## Use mysql to optimize a table
	   'species:s' => \$conf{species},
	   'copyfrom:s' => \$conf{copyfrom},
	   ## Another database from which to copy the genome table
	   'import:s' => \$conf{import_accession},
	   ## A single accession to import
	   'input_file:s' => \$conf{input_file},
	   ## A file of accessions to import and queue
	   'input_fasta:s' => \$conf{input_fasta},
	   ## A file of fasta data to import and queue
	   'fasta_style:s' => \$conf{fasta_style},
	   ## The style of input fasta (sgd, ncbi, etc)
	   ## By default this should be 0/1, but for some yeast genomes it may be 1000
	   'fillqueue' => \$conf{fillqueue},
	   ## A boolean to see if the queue should be filled.
	   'resetqueue' => \$conf{resetqueue},
	   ## A boolean to reset the queue
	   'stats' => \$conf{stats},
	   ## Generate stats
	   'startpos:s' => \$conf{startpos},
	   ## A specific start position to fold a single sequence at,
	   ## also usable by inputfasta or inputfile
	   'startmotif:s' => \$conf{startmotif},
	   ## A specific start motif to start folding at
	   'length:i' => \$conf{seqlength},
	   ## i == integer
	   'landscape_length:i' => \$conf{landscape_seqlength},
	   'nupack:i' => \$conf{do_nupack},
	   ## If no type definition is given, it is boolean
	   'pknots:i' => \$conf{do_pknots},
	   ## The question is, will these be set to 0 if not applied?
	   'hotknots:i' => \$conf{do_hotknots},
	   ## The question is, will these be set to 0 if not applied?
	   'boot:i' => \$conf{do_boot},
	   'utr:i' => \$conf{do_utr},
	   'workdir:s' => \$conf{workdir},
	   'nupack_nopairs:i' => \$conf{nupack_nopairs_hack},
	   'arch:i' => \$conf{arch_specific_exe},
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
	   'stem2_spacer_min:i' => \$conf{stem2_spacer_min},
	   'stem2_spacer_max:i' => \$conf{stem2_spacer_max},
	   'checks:i' => \$conf{checks},
	   'make_jobs' => \$conf{make_jobs},
	   'make_landscape' => \$conf{make_landscape},);
foreach my $opt (keys %conf) {
    if (defined($conf{$opt})) {
	$config->{$opt} = $conf{$opt};
    }
}

our $state = {time_to_die => undef,
	      queue_table => undef,
	      queue_id => undef,
	      pknots_mfe_id => undef,
	      nupack_mfe_id => undef,
	      vienna_mfe_id => undef,
	      hotknots_mfe_id => undef,
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
	      done_count => 0,};

### START DOING WORK NOW
chdir($config->{base});
if ($config->{checks}) {
    Check_Environment();
    Check_Tables();
    Check_Blast();
}
## Some Arguments should be checked before others...
## These first arguments are not exclusive and so are separate ifs
if (defined($config->{help})) {
    Print_Help();
}
if (defined($config->{makeblast})) {
    Make_Blast();
    exit(0);
}
if (defined($config->{make_landscape})) {
    Make_Landscape_Tables();
    exit(0);
}
if (defined($config->{stats})) {
    Generate_Stats();
    exit(0);
}
if (defined($config->{optimize})) {
    Optimize($config->{optimize});
    exit(0);
}
if (defined($config->{blast})) {
    my $blast = new PRFBlast;
    $blast->Search($config->{blast}, 'local');
    print "\n\n\n\n\n\n\n";
    $blast->Search($config->{blast}, 'remote');
    exit(0);
}
if (defined($config->{fillqueue})) {
    $db->FillQueue();
    my $num = $db->MySelect("SELECT count(id) from $config->{queue_table}");
    print "The queue now has $num->[0] entries\n";
    exit(0);
}
if (defined($config->{resetqueue})) {
    $db->Reset_Queue();
    exit(0);
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
if (defined($config->{make_jobs})) {
    Make_Jobs();  ## USED FOR PBS SYSTEMS
}
if (defined($config->{accession})) {
    $state->{queue_id} = 0;
    ## Dumb hack lives on
    $state->{accession} = $config->{accession};
    $state->{genome_id} = $db->Get_GenomeId_From_Accession($config->{accession});
    if (defined($config->{startpos})) {
	Gather($state, $config->{startpos});
    }
    else {
	Gather($state);
    }
    exit(0);
}
if (defined($config->{import_accession})) {
    my $accession = $config->{import_accession};
    print "Importing Accession: $accession\n";
    $db->Import_CDS($accession);
    $state->{queue_id} = 0;
    ## Dumb hack lives on
    $state->{accession} = $accession;
    $state->{genome_id} = $db->Get_GenomeId_From_Accession($accession);
    if (defined($config->{startpos})) {
	Gather($state, $config->{startpos});
    }
    elsif (defined($config->{startmotif})) {
	Gather($state, $config->{startmotif});
    }
    else {
	Gather($state);
    }
    ## Once the prf_daemon finishes this accession it will start reading the queue...
}  ## Endif used the import_accession arg
if (defined($config->{input_fasta})) {
    my $queue_ids;
    if (defined( $config->{startpos})) {
	$queue_ids = $db->Import_Fasta($config->{input_fasta}, $config->{fasta_style}, $config->{startpos});
    } 
    else {
	$queue_ids = $db->Import_Fasta($config->{input_fasta}, $config->{fasta_style});
    }
    
    foreach my $queue_id (@{$queue_ids}) {
	$state->{genome_id} = $db->Get_GenomeId_From_QueueId($queue_id);
	$state->{queue_id}  = $queue_id;
	print "Performing gather for genome_id $state->{genome_id}";
	Gather($state);
    }
    exit(0);
}
if (defined($config->{nodaemon})) {
    print "No daemon is set, existing before reading queue.\n";
    exit(0);
}
if ($config->{checks}) {
    Print_Config();
}

until (defined($state->{time_to_die})) {
    ### You can set a configuration variable 'master' so that it will not die
    if ($state->{done_count} > 60 and !defined($config->{master})) {$state->{time_to_die} = 1}
    if (defined($config->{seqlength})) {
	$state->{seqlength} = $config->{seqlength};
    } 
    else {
	$state->{seqlength} = 100;
    }
    my $ids = $db->Grab_Queue();
    $state->{queue_table} = $ids->{queue_table};
    $state->{queue_id}  = $ids->{queue_id};
    $state->{genome_id} = $ids->{genome_id};
    
    if (defined($state->{genome_id})) {
	Gather($state);
    } ## End if have an entry in the queue
    else {
	sleep(60);
	$state->{done_count}++;
    } ## no longer have $state->{genome_id}
} ### End waiting for time to die

sub Print_Help {
    print "The prf_daemon script takes many possible options including:
accession      fold a particular accession
blast          provide it an accession and it will blast it to the rest of the prfdb
makeblast      create a local blast database from all the sequences in the genome table
optimize       perform a mysql specific optimization of the tables in the db
species        specify a species to work with
copyfrom       copy the genome table from one database to another
import         provide a single accession to import into the prfdb
input_file     provide the filename containing one accession per line
input_fasta    provide the filename containing fasta input (keep in mind the NCBI format)
fasta_style    see input_fasta -- currently can handle sgd and ncbi styles
fillqueue      fill up the queue with everything from the genome table
resetqueue     set all entries in the queue to unexamined
startpos       explicitly set the start position for a folding -- for use with --accession
startmotif     start at a particular subsequence (I don't think this is completed)
length         set the window size
landscape_length set the landscape window size
nupack         explicitly turn on/off nupack
pknots         explicitly turn on/off pknots
hotknots       explicitly turn on/off hotknots
boot           turn on/off randomization
utr            turn on/off the folding in the 3' utr
checks         perform a series of checks to see if the database is ready for use
make_jobs      create job files for PBS

";
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
    my $startpos = shift;
    my $ref = $db->Id_to_AccessionSpecies($state->{genome_id});
    $state->{accession} = $ref->{accession};
    $state->{species} = $ref->{species};
    my $message = "qid:$state->{queue_id} gid:$state->{genome_id} sp:$state->{species} acc:$state->{accession}\n";
    print "Working with: $message";
    
    my %pre_landscape_state = %{$state};
    my $landscape_state = \%pre_landscape_state;
    if ($config->{do_landscape}) {
	Landscape_Gatherer($landscape_state, $message);
    }

    foreach my $len (@{$config->{seqlength}}) {
        $state->{seqlength} = $len;
        PRF_Gatherer($state, $len, $startpos);
    }
}
## End Gather

## Start PRF_Gatherer
sub PRF_Gatherer {
    my $state = shift;
    my $len = shift;
    my $startpos = shift;
    ## Check for existence in the noslipsite table
    my $noslipsite = $db->MySelect({
	statement =>"SELECT num_slipsite FROM numslipsite WHERE accession = '$state->{accession}'",
	type => 'row'});
    return(undef) if (defined($noslipsite->[0]) and $noslipsite->[0] == 0);
    $state->{genome_information} = $db->Get_ORF($state->{accession});
    my $sequence = $state->{genome_information}->{sequence};
    my $orf_start = $state->{genome_information}->{orf_start};
    my $motifs = new RNAMotif_Search();
    my $rnamotif_information;
    my $sp = 'UNDEF';
    my $ac = 'UNDEF';
    $sp = $state->{species} if (defined($state->{species}));
    $ac = $state->{accession} if (defined($state->{accession}));
    my $current = "sp:$sp acc:$ac st:$orf_start l:$len";
    if (defined($startpos)) {
#      $startpos = $startpos - $orf_start;
	my $inf = PRFdb::MakeFasta($state->{genome_information}->{sequence},
				   $startpos, 
				   $startpos + $config->{seqlength});
	$rnamotif_information->{$startpos}{filename} = $inf->{filename};
	$rnamotif_information->{$startpos}{sequence} = $inf->{string};
	$state->{rnamotif_information} = $rnamotif_information;
    }
    else {
	$rnamotif_information = $motifs->Search($state->{genome_information}->{sequence},
						$state->{genome_information}->{orf_start});
	$state->{rnamotif_information} = $rnamotif_information;
	if (!defined($state->{rnamotif_information})) {
	    $db->Insert_NumSlipsite($state->{accession}, 0);
	}
    } ## End else, so all start sites should be collected.
    
    if (!defined($rnamotif_information)) {
	return(0);
    }
    my $num_slipsites = 0;
  STARTSITE: foreach my $slipsite_start (keys %{$rnamotif_information}) {
      $num_slipsites++;
      if ($config->{do_utr} == 0) {
	  my $end_of_orf = $db->MySelect({
	      statement => "SELECT orf_stop FROM genome WHERE accession = ?",
	      vars => [$state->{accession}], 
	      type =>'row',});
	  if ($end_of_orf->[0] < $slipsite_start) {
	      PRFdb::RemoveFile($rnamotif_information->{$slipsite_start}{filename});
		next STARTSITE;
	    }
      }  ## End of if do_utr
      
      my ($nupack_mfe_id, $pknots_mfe_id, $hotknots_mfe_id);
      $state->{fasta_file} = $rnamotif_information->{$slipsite_start}{filename};
      $state->{sequence} = $rnamotif_information->{$slipsite_start}{sequence};
      
      if (!defined($state->{fasta_file} or
		   $state->{fasta_file} eq ''
		   or !-r $state->{fasta_file})) {
	  print "The fasta file for: $state->{accession} $slipsite_start does not exist.\n";
	  print "You may expect this script to die momentarily.\n";
      }
      
      my $check_seq = Check_Sequence_Length();
      if ($check_seq eq 'shorter than wanted') {
	  print "The sequence is: $check_seq and will be skipped.\n" if (defined($config->{debug}));
	  PRFdb::RemoveFile($state->{fasta_file});
	  next STARTSITE;
      } 
      elsif ($check_seq eq 'null') {
	  print "The sequence is null and will be skipped.\n"  if (defined($config->{debug}));
	  PRFdb::RemoveFile($state->{fasta_file});
	  next STARTSITE;
      } 
      elsif ($check_seq eq 'polya') {
	  print "The sequence is polya and will be skipped.\n"  if (defined($config->{debug}));
	  PRFdb::RemoveFile($state->{fasta_file});
	  next STARTSITE;
      }
      
      my $fold_search = new RNAFolders(file => $state->{fasta_file},
				       genome_id => $state->{genome_id},
				       species => $state->{species},
				       accession => $state->{accession},
				       start => $slipsite_start,);
      
      if ($config->{do_nupack}) { ### Do we run a nupack fold?
	  $nupack_mfe_id = Check_Folds('nupack', $fold_search, $slipsite_start);
      }
      if ($config->{do_pknots}) { ### Do we run a pknots fold?
	  $pknots_mfe_id = Check_Folds('pknots', $fold_search, $slipsite_start);
      }
      if ($config->{do_hotknots}) {
	  $hotknots_mfe_id = Check_Folds('hotknots', $fold_search, $slipsite_start);
      }
      if ($config->{do_comparison}) {
	  my $pknots_mfe_info = $fold_search->Pknots('nopseudo');
	  my $nupack_mfe_info = $fold_search->Nupack('nopseudo');
	  my $vienna_mfe_info = $fold_search->Vienna();
	  my $pk = $pknots_mfe_info->{mfe};
	  my $nu = $nupack_mfe_info->{mfe};
	  my $vi = $vienna_mfe_info->{mfe};
	  my $comparison_string = "$pk,$nu,$vi";
	  $comparison_string =~ s/\s+//g;
	  my $update_string = qq(UPDATE MFE set compare_mfes = '$comparison_string' WHERE accession = '$state->{accession}' AND seqlength = '$state->{seqlength}' AND start = '$slipsite_start');
	  print "Did $update_string\n";
	  $db->MyExecute($update_string);
      }
      if ($config->{do_boot}) {
          my $tmp_nupack_mfe_id = $db->MySelect({
              statement => qq/SELECT id FROM mfe WHERE accession = '$state->{accession}' AND start = '$slipsite_start'
 AND seqlength = '$state->{seqlength}' AND algorithm = 'nupack'/,
              type => 'single'});
          my $tmp_pknots_mfe_id = $db->MySelect({
              statement => qq/SELECT id FROM mfe WHERE accession = '$state->{accession}' AND start = '$slipsite_start'
 AND seqlength = '$state->{seqlength}' AND algorithm = 'pknots'/,
              type => 'single'});
          my $tmp_hotknots_mfe_id = $db->MySelect({
              statement => qq/SELECT id FROM mfe WHERE accession = '$state->{accession}' AND start = '$slipsite_start'
 AND seqlength = '$state->{seqlength}' AND algorithm = 'hotknots'/,
              type => 'single'});

	  my $boot = new Bootlace(genome_id => $state->{genome_id},
				  nupack_mfe_id => (defined($state->{nupack_mfe_id})) ?
				  $state->{nupack_mfe_id} : $nupack_mfe_id,
				  pknots_mfe_id => (defined($state->{pknots_mfe_id})) ?
				  $state->{pknots_mfe_id} : $pknots_mfe_id,
				  inputfile => $state->{fasta_file},
				  species => $state->{species},
				  accession => $state->{accession},
				  start => $slipsite_start,
				  seqlength => $state->{seqlength},
				  iterations => $config->{boot_iterations},
				  boot_mfe_algorithms => $config->{boot_mfe_algorithms},
				  randomizers => $config->{boot_randomizers},
				  );
          my @algos = keys(%{$config->{boot_mfe_algorithms}});
          my $boot_folds;
          foreach my $method (@algos) {
              $boot_folds = $db->Get_Num_Bootfolds(
                  $state->{genome_id},
                  $slipsite_start,
                  $state->{seqlength},
                  $method);
              print "$current has $boot_folds randomizations for method: $method\n";
              if (!defined($boot_folds) or $boot_folds == 0) {
                  my $bootlaces = $boot->Go($method);
                  my $inserted_ids = $db->Put_Boot($bootlaces);
                  my @fun = @{$inserted_ids};
              }
          }
          Check_Boot_Connectivity($state, $slipsite_start);
      } ### End if we are to do a boot

      if ($config->{do_overlap}) {
	  my $sequence_information = $db->Get_Sequence_from_id($state->{genome_id});
	  my $overlap = new Overlap(genome_id => $state->{genome_id},
				    species => $state->{species},
				    accession => $state->{accession},
				    sequence  => $sequence_information,);
	  my $overlap_info = $overlap->Alts($slipsite_start);
	  $db->Put_Overlap($overlap_info);
      } ## End check to do an overlap
      ## Clean up after yourself!
      PRFdb::RemoveFile($state->{fasta_file});
  }    ### End foreach slipsite_start
    $db->Insert_Numslipsite($state->{accession}, $num_slipsites) if (!defined($noslipsite->[0]));
    Clean_Up();
    ## Clean out state
}
## End PRF_Gatherer

## Start Landscape_Gatherer
sub Landscape_Gatherer {
    my $state = shift;
    my $message = shift;
    my $sequence = $db->Get_Sequence($state->{accession});
    my @seq_array = split(//, $sequence);
    my $sequence_length = scalar(@seq_array);
    my $start_point = 0;
    while ($start_point + $config->{landscape_seqlength} <= $sequence_length) {
	my $individual_sequence = ">$message";
	my $end_point = $start_point + $config->{landscape_seqlength};
	foreach my $character ($start_point .. $end_point) {
	    if (defined($seq_array[$character])) {
		$individual_sequence = $individual_sequence . $seq_array[$character];
	    }
	}
	$individual_sequence = $individual_sequence . "\n";
	$state->{fasta_file} = $db->Sequence_to_Fasta($individual_sequence);
	if (!defined($state->{accession})) {die("The accession is no longer defined. This cannot be allowed.")};
	my $landscape_table = qq/landscape_$state->{species}/;
	my $fold_search = new RNAFolders(file => $state->{fasta_file}, genome_id => $state->{genome_id},
					 species => $state->{species}, accession => $state->{accession},
					 start => $start_point,);
	my $nupack_foldedp = $db->Get_Num_RNAfolds('nupack', $state->{genome_id}, $start_point,
						   $config->{landscape_seqlength}, 'landscape');
	my $pknots_foldedp = $db->Get_Num_RNAfolds('pknots', $state->{genome_id}, $start_point,
						   $config->{landscape_seqlength}, 'landscape');
	my $vienna_foldedp = $db->Get_Num_RNAfolds('vienna', $state->{genome_id}, $start_point,
						   $config->{landscape_seqlength}, 'landscape');
	my ($nupack_info, $nupack_mfe_id, $pknots_info, $pknots_mfe_id, $vienna_info, $vienna_mfe_id);
	if ($nupack_foldedp == 0) {
	    if ($config->{nupack_nopairs_hack}) {
		$nupack_info = $fold_search->Nupack_NOPAIRS('nopseudo');
	    } 
	    else {
		$nupack_info = $fold_search->Nupack('nopseudo');
	    }
	    $nupack_mfe_id = $db->Put_Nupack($nupack_info, $landscape_table);
	    $state->{nupack_mfe_id} = $nupack_mfe_id;
	}
	if ($pknots_foldedp == 0) {
	    $pknots_info = $fold_search->Pknots('nopseudo');
	    $pknots_mfe_id = $db->Put_Pknots($pknots_info, $landscape_table);
	    $state->{pknots_mfe_id} = $pknots_mfe_id;
	}
	if ($vienna_foldedp == 0) {
	    $vienna_info = $fold_search->Vienna();
	    $vienna_mfe_id = $db->Put_Vienna($vienna_info, $landscape_table);
	    $state->{vienna_mfe_id} = $vienna_mfe_id;
	}
	## The functional portion of the while loop is over, just set the state now
	$start_point = $start_point + $config->{window_space};
	PRFdb::RemoveFile($state->{fasta_file});
    }
    Clean_Up('landscape');
}
## End Landscape_Gatherer

## Start Check_Environment
sub Check_Environment {
    die("No rnamotif template file set.") unless (defined($config->{rnamotif_template}));
    die("No rnamotif descriptor file set.") unless (defined($config->{rnamotif_descriptor}));
    die("Workdir must be executable: $config->{workdir} $!") unless (-x $config->{workdir});
    die("Workdir must be writable: $!") unless (-w $config->{workdir});
    die("Database not defined") if ($config->{db} eq 'prfconfigdefault_db');
    die("Database host not defined") if ($config->{host} eq 'prfconfigdefault_host');
    die("Database user not defined") if ($config->{user} eq 'prfconfigdefault_user');
    die("Database pass not defined") if ($config->{pass} eq 'prfconfigdefault_pass');
    
    unless (-r $config->{rnamotif_descriptor}) {
	RNAMotif_Search::Descriptor();
	  unless (-r $config->{rnamotif_descriptor}) {
	      die("Unable to read the rnamotif descriptor file: $!");
	  }
      }
    unless (-r "$config->{base}/.htaccess") {
	my $copy_command;
	if ($config->{has_modperl}) {
	    $copy_command = qq(cp $config->{base}/html/htaccess.modperl $config->{base}/.htaccess);
	}
	else {
	    $copy_command = qq(cp $config->{base}/html/htaccess.cgi $config->{base}/.htaccess);
	}
	system($copy_command);
    }
## End Check_Environment
}

sub Check_Tables {
    my $test = $db->Tablep($config->{queue_table});
    unless ($test) {
	$db->Create_Queue($config->{queue_table});
	$db->FillQueue();
    }
}

sub Check_Blast {
    my $testfile = qq($config->{blastdir}/nr.nni);
    unless (-r $testfile) {
        print "Running Make_Blast, this may take a while.\n";
	Make_Blast();
        print "Finished Make_Blast.\n";
    }
}

## Start Print_Config
sub Print_Config {
    ### This is a little function designed to give the user a chance to abort
    if   ($config->{nupack_nopairs_hack}) {
	print "I AM using a hacked version of nupack!\n"; 
    }
    else {
	print "I AM NOT using a hacked version of nupack!\n";
    }
    if ($config->{do_nupack}) {
	print "I AM doing a nupack fold using the program: $config->{nupack}\n";
    }
    else {
	print "I AM NOT doing a nupack fold\n"; 
    }
    if ($config->{do_pknots}) {
	print "I AM doing a pknots fold using the program: $config->{pknots}\n";
    }
    else {
	print "I AM NOT doing a pknots fold\n";
    }
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
    else {
	print "I AM NOT doing a boot.\n";
    }
    if ($config->{arch_specific_exe}) {
	print "I AM USING ARCH SPECIFIC EXECUTABLES\n"; }
    else {
	print "I am not using arch specific executables\n"; 
    }
    print "The default structure length in this run is: $config->{seqlength}\n";
    print "I am using the database: $config->{db} and user: $config->{user}\n\n\n";
    sleep(1);
}
## End Print_Config

## Start Check_Boot_Connectivity
sub Check_Boot_Connectivity {
    my $state = shift;
    my $slipsite_start = shift;
    my $genome_id = $state->{genome_id};
    my $check_statement = qq(SELECT mfe_id, mfe_method, id, genome_id FROM boot WHERE genome_id = ? and start = ?);
    my $answer = $db->MySelect({
	statement => $check_statement,
	vars =>[$genome_id, $slipsite_start],});
    my $num_fixed = 0;
    foreach my $boot (@{$answer}) {
	my $mfe_id = $boot->[0];
	my $mfe_method = $boot->[1];
	my $boot_id = $boot->[2];
	my $genome_id = $boot->[3];
	if (!defined($mfe_id) or $mfe_id == '0') {
	    ## Then reconnect it using $mfe_method and $boot_id and $genome_id
	    my $new_mfe_id_stmt = qq(SELECT id FROM mfe where genome_id = ? and start = ? and algorithm = ?);
	    my $new_mfe_id_arrayref = $db->MySelect({
		statement => $new_mfe_id_stmt,
		vars => [$genome_id, $slipsite_start, $mfe_method],});
	    my $new_mfe_id = $new_mfe_id_arrayref->[0]->[0];
	    if ((!defined($new_mfe_id) or $new_mfe_id == '0' or $new_mfe_id eq '') and $mfe_method eq 'nupack') {
		### Then there is no nupack information :(
		#print "No Nupack information!\n";
		if (!defined($state->{accession})) {
		    die("The accession is no longer defined. This cannot be allowed.")
		    };
		my $fold_search = new RNAFolders(file => $state->{fasta_file}, genome_id => $state->{genome_id},
						 species => $state->{species}, accession => $state->{accession},
						 start => $slipsite_start,);
		$new_mfe_id = Check_Nupack($fold_search, $slipsite_start);
	    }
	    elsif ((!defined($new_mfe_id) or $new_mfe_id == '0' or $new_mfe_id eq '') and $mfe_method eq 'pknots') {
		### Then there is no pknots information :(
		if (!defined($state->{accession})) {
		    die("The accession is no longer defined. This cannot be allowed.")
		    };
		my $fold_search = new RNAFolders(file => $state->{fasta_file}, genome_id => $state->{genome_id},
						 species => $state->{species}, accession => $state->{accession},
						 start => $slipsite_start,);
		$new_mfe_id = Check_Pknots($fold_search, $slipsite_start);
	    } ### End if there is no mfe_id and pknots was the algorithm
	    my $update_mfe_id_statement = qq(UPDATE boot SET mfe_id = ? WHERE id = ?);
	    my ($cp,$cf, $cl) = caller(0);
	    $db->MyExecute({statement => $update_mfe_id_statement,
			    vars =>[$new_mfe_id, $boot_id],
			    caller =>"$cp $cf $cl",});
	    $num_fixed++;
	}    ### End if there is no mfe_id
    }    ### End foreach boot in the list
    return ($num_fixed);
}
## End Check_Boot_Connectivity

sub Check_Folds {
    my $type = shift;
    my $fold_search = shift;
    my $slipsite_start = shift;
    my $mfe_id;
    my $mfe_varname = qq(${type}_mfe_id);
    my $folds = $db->Get_Num_RNAfolds($type, $state->{genome_id}, $slipsite_start, $state->{seqlength});
    if ($folds > 0) { ### If there ARE existing folds...
	print "$state->{genome_id} has $folds > 0 pknots_folds at position $slipsite_start\n";
	$state->{$mfe_varname} = $db->Get_MFE_ID($state->{genome_id}, $slipsite_start,
						 $state->{seqlength}, $type);
	$mfe_id = $state->{$mfe_varname};
	print "Check_Folds $type - already done: state: $mfe_id\n";
    }
    else { ### If there are NO existing folds...
	print "$state->{genome_id} has only $folds <= 0 $type at position $slipsite_start\n";
	my ($info, $mfe_id);
	if ($type eq 'pknots') {
	    $info = $fold_search->Pknots();
	    $mfe_id = $db->Put_Pknots($info);
	    $state->{$mfe_varname} = $mfe_id;
	    print "Performed Put_Pknots and returned $mfe_id\n";
	}
	elsif ($type eq 'nupack') {
	    $info = $fold_search->Nupack_NOPAIRS();
	    $mfe_id = $db->Put_Nupack($info);
	    $state->{$mfe_varname} = $mfe_id;
	    print "Performed Put_Nupack and returned $mfe_id\n";
	}
	elsif ($type eq 'hotknots') {
	    $info = $fold_search->Hotknots();
	    $mfe_id = $db->Put_Hotknots($info);
	    $state->{$mfe_varname} = $mfe_id;
	    print "Performed Put_Hotknots and returned $mfe_id\n";
	}
	else {
	    die("Non existing type in Check_Folds");
	}
    }    ### Done checking for pknots folds
    return ($mfe_id);
}
## End Check_Folds

## Start Clean_Up
sub Clean_Up {
    $db->Done_Queue($state->{queue_table}, $state->{genome_id});
    foreach my $k (keys %{$state}) { $state->{$k} = undef unless ($k eq 'done_count' or $k); }
}
## End Clean_Up

## Start Check_Sequence_Length
sub Check_Sequence_Length {
    my $filename = $state->{fasta_file};
    my $sequence = $state->{sequence};
    my @seqarray = split(//, $sequence);
    my $sequence_length = $#seqarray + 1;
    my $wanted_sequence_length = $state->{seqlength};
    open(IN, "<$filename") or die("Check_Sequence_Length: Couldn't open $filename $!");
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
    $sequence = uc($sequence);
    if (!defined($sequence) or $sequence eq '') {
	return ('null');
    }
    if ($sequence =~ /^A+$/) {
	return ('polya');
    }
    elsif ($sequence =~ /^A+C+UCG+$/) {
	return('polya');
    }
    elsif ($sequence =~ /^A+U+$/) {
	return('polya');
    }
    elsif ($sequence =~ /^A+C+UGAG$/) {
	return('polya');
    }
    elsif ($sequence =~ /^A+U+A+$/) {
	return('polya');
    }
    elsif ($sequence =~ /^A+C{3,}G+$/) {
	return('polya');
    }
    elsif ($sequence =~ /^A+CCCUCG+$/) {
	return('polya');
    }
    elsif ($sequence =~ /AAAAAAAA$/ and $sequence_length < $wanted_sequence_length) {
	return ('polya');
    }
    elsif ($sequence_length > $wanted_sequence_length) {
#    open( OUT, ">$filename" ) or die("Could not open $filename $!");
#    ## OPEN OUT in Check_Sequence_Length
#    print OUT "$output\n";
#    foreach my $char ( 0 .. $sequence_length ) {
#      print OUT $out[$char];
#    }
#    print OUT "\n";
#    close(OUT);
#    ## CLOSE OUT in Check_Sequence_Length
	return ('longer than wanted');
    }
    elsif ($sequence_length == $wanted_sequence_length) {
	return ('equal');
    }
    elsif ($sequence_length < $wanted_sequence_length) {
	return ('shorter than wanted');
    }
    else {
	return ('unknown');
    }
}
## End Check_Sequence_length

sub Make_Blast {
    my $outputfile = 'blast_prfdb.fasta';
    $db->Genome_to_Fasta($outputfile);
    my $blast = new PRFBlast;
    print "Formatting Database\n";
    $blast->Format_Db($outputfile);
}

sub Make_Landscape_Tables {
    my $tables = $db->MySelect("SELECT distinct(species) from genome");
    my @spec = @{$tables};
    foreach my $s (@spec) {
	my $sp = $s->[0];
	$sp =~ s/\-/_/g;
	$db->Create_Landscape($sp);
    }
    exit(0);
}

sub Make_Jobs {
    use lib "$ENV{HOME}/usr/perl.irix/lib";
    use Template;
    use PRFConfig;
    my $template_config = $config;
    $template_config->{PRE_PROCESS} = undef;
    $template_config->{EVAL_PERL} = 0;
    $template_config->{INTERPOLATE} = 0;
    $template_config->{POST_CHOMP} = 0;
    my $template = new Template($template_config);
    
    my $base = $template_config->{base};
    my $prefix = $template_config->{prefix};
    my $input_file = "$prefix/descr/job_template";
    my @arches = split(/ /, $config->{pbs_arches});
    foreach my $arch (@arches) {
	system("mkdir jobs/$arch") unless (-d "jobs/$arch");
	foreach my $daemon ("01" .. $config->{num_daemons}) {
	    my $output_file = "jobs/$arch/$daemon";
	    my $name = $template_config->{pbs_partialname};
	    my $pbs_fullname = "${name}${daemon}_${arch}";
	    my $incdir = "${base}/usr/perl.${arch}/lib";
	    my $vars = {
		pbs_shell => $template_config->{pbs_shell},
		pbs_memory => $template_config->{pbs_memory},
		pbs_cpu => $template_config->{pbs_cpu},
		pbs_arch => $arch,
		pbs_name => $pbs_fullname,
		pbs_cput => $template_config->{pbs_cput},
		prefix => $prefix,
		perl => $template_config->{perl},
		incdir => $incdir,
		daemon_name => $template_config->{daemon_name},
		job_num => $daemon,
	    };
	    $template->process($input_file, $vars, $output_file) or die $template->error();
	}
    }
}


sub Generate_Stats {
    my $fun = $db->MyExecute("DELETE FROM stats");
    my $data = {
	species => $config->{index_species},
	seqlength => $config->{seqlength},
	max_mfe => [$config->{max_mfe}],
	algorithm => ['pknots','nupack','hotknots'],
    };
    $db->Put_Stats($data);
}

sub Optimize {
    my $table = shift;
    my $stmt = qq(OPTiMIZE TABLE $table);
    $db->MyExecute({statement => $stmt});
}

sub CLEANUP {
    $db->Disconnect();
    PRFdb::RemoveFile('all');
    print "\n\nCaught Fatal signal.\n\n";
    exit(0);
}

END {
    $db->Disconnect();
    PRFdb::RemoveFile('all');
}
