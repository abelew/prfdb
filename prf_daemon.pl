#!/usr/bin/env perl
use strict;
use warnings;
use lib "$ENV{PRFDB_HOME}/lib";
use local::lib "$ENV{PRFDB_HOME}/usr/perl";
use vars qw"$db $config";
die("Could not load PRFConfig.\n$@\n") unless (eval "use PRFConfig; 1");
$config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
die("Could not load PRFdb.\n$@\n") unless (eval "use PRFdb qw'AddOpen RemoveFile Callstack Cleanup'; 1");
$db = new PRFdb(config => $config);
die("Could not load RNAMotif.\n$@\n") unless (eval "use RNAMotif; 1");
die("Could not load RNAFolders.\n$@\n") unless (eval "use RNAFolders; 1");
die("Could not load Bootlace.\n$@\n") unless (eval "use Bootlace; 1");
die("Could not load Overlap.\n$@\n") unless (eval "use Overlap; 1");
die("Could not load SeqMisc.\n$@\n") unless (eval "use SeqMisc; 1");
die("Could not load PRFBlast.\n$@\n") unless (eval "use PRFBlast; 1");
die("Could not load Agree.\n$@\n") unless (eval "use Agree; 1");
die("Could not load MyGenbank.\n$@\n") unless (eval "use MyGenbank; 1");
my $load_return = eval("use PRFGraph; 1");
warn("Could not load PRFGraph, disabling graphing routines.\n$@\n") unless($load_return);
$SIG{INT} = \&PRFdb::Cleanup;
$SIG{BUS} = \&PRFdb::Cleanup;
$SIG{SEGV} = \&PRFdb::Cleanup;
$SIG{PIPE} = \&PRFdb::Cleanup;
$SIG{ABRT} = \&PRFdb::Cleanup;
$SIG{QUIT} = \&PRFdb::Cleanup;
setpriority(0,0,$config->{niceness});

our $state = { time_to_die => undef,
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
	       done_count => 0, };

### START DOING WORK NOW
chdir($ENV{PRFDB_HOME});
if ($config->{checks}) {
    Check_Environment();
    Check_Blast();
}
## Some Arguments should be checked before others...
if (defined($config->{make_jobs})) {
    Make_Queue_Jobs();
    exit(0);
}    
if (defined($config->{dbexec})) {
    $db->MyExecute(statement => "$config->{dbexec}");
    exit(0);
}
if (defined($config->{dbselect})) {
    my $answer = $db->MySelect($config->{dbselect});
    foreach my $row (@{$answer}) {
	my @r = @{$row};
	print @r;
    }
    exit(0);
}
if (defined($config->{import_genbank_accession})) {
    Import_Genbank_Accession($config->{import_genbank_accession});
}
if (defined($config->{import_genbank_flatfile})) {
    Import_Genbank_Flatfile($config->{import_genbank_flatfile});
}
if (defined($config->{makeblast})) {
    Make_Blast();
    exit(0);
}
if (defined($config->{resync})) {
    $db->ReSync();
    exit(0);
}
if (defined($config->{revcomp})) {
    die("Need a sequence.") if (!$config->{revcomp});
    my $tmp = new SeqMisc(sequence => $config->{revcomp});
    print "$tmp->{revcomp}\n";
    exit(0);
}
if (defined($config->{reverse})) {
    die("Need a sequence.") if (!$config->{reverse});
    my $tmp = new SeqMisc(sequence => $config->{reverse});
    print "$tmp->{reverse}\n";
    exit(0);
}
if (defined($config->{zscore})) {
    Zscore();
    exit(0);
}
if (defined($config->{clear_queue})) {
    $db->Reset_Queue(complete => 1);
    exit(0);
}
if (defined($config->{make_landscape})) {
    Make_Landscape_Tables();
    exit(0);
}
if (defined($config->{maintain})) {
    print "Performing maintenance of the PRFdb.\n";
    Maintenance();
    exit(0);
}
if (defined($config->{do_stats})) {
    my $data = {
	species => $config->{index_species},
	seqlength => $config->{seqlength},
	max_mfe => [$config->{max_mfe}],
	mfe_methods => $config->{mfe_methods},
    };
    $db->Put_All_Stats($data);
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
    my $num = $db->MySelect(statement => "SELECT count(id) from $config->{queue_table}", type => 'single');
    print "The queue now has $num entries\n";
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
    } else {
	Read_Accessions($config->{input_file});
    }
}
if (defined($config->{accession})) {
    $state->{queue_id} = 0;
    $config->{debug} = 1;
    ## Dumb hack lives on
    $state->{accession} = $config->{accession};
    $state->{genome_id} = $db->Get_GenomeId_From_Accession($config->{accession});
    if (defined($config->{startpos})) {
	Gather($state, $config->{startpos});
    } else {
	Gather($state);
    }
    exit(0);
}
if (defined($config->{input_fasta})) {
    my $queue_ids;
    if (defined($config->{startpos})) {
	$queue_ids = $db->Import_Fasta($config->{input_fasta}, $config->{fasta_style}, $config->{startpos});
    } else {
	$queue_ids = $db->Import_Fasta($config->{input_fasta}, $config->{fasta_style});
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

MAINLOOP: until (defined($state->{time_to_die})) {
    my $wait = $db->MySelect(statement => "SELECT wait from wait", type => 'single');
    if ($wait == 2) {
	exit(0);
    }
    while ($wait == 1) {
	sleep(300);
	next MAINLOOP;
    }
    ### You can set a configuration variable 'master' so that it will not die
    if ($state->{done_count} > 60 and !defined($config->{master})) {$state->{time_to_die} = 1}
    if (defined($config->{seqlength})) {
	$state->{seqlength} = $config->{seqlength};
    } else {
	$state->{seqlength} = 100;
    }
    if (defined($config->{process_import_queue})) {
	my $import_accession = $db->Get_Import_Queue();
	if (defined($import_accession)) {
	    my $import = $db->Import_CDS($import_accession);
	    if (defined($import) and $import !~ m/Error/) {
		if ($import == 0) {
		    print "Did not import $import_accession, it has no coding sequence defined.\n";
		} else {
		    print "Imported $import_accession added $import bases.\n";
		}
	    }
	}
    }
    my $ids = $db->Grab_Queue();
    $state->{queue_table} = $ids->{queue_table};
    $state->{queue_id} = $ids->{queue_id};
    $state->{genome_id} = $ids->{genome_id};
    if (defined($state->{genome_id})) {
	Gather($state);
	## End if have an entry in the queue
    } else {
	sleep(60);
	$state->{done_count}++;
    } ## no longer have $state->{genome_id}
} ### End waiting for time to die

sub Read_Accessions {
    my $accession_file = shift;
    my $startpos = shift;
    my $retries = 10;
    ## Rewrite the list of things to do removing the ones which are done
    system("touch ${accession_file}.done");
    open(D, "<${accession_file}.done") or Callstack(die => 1, message => "Could not open the done file.");
    my @done_list = ();
    while (my $line = <D>) {
	chomp $line;
	push(@done_list, $line);
    }
    close(D);
    open(A, ">${accession_file}.new") or Callstack(die => 1, message => "Could not open the accession file.");
    open(AA, "<$accession_file") or Callstack(die => 1, message => "Could niot open the accession file.");
  AA: while (my $line = <AA>) {
      chomp $line;
      my $num_left = scalar(@done_list);
      foreach my $test (@done_list) {
	  if ($test eq $line) {
	      next AA;
	  }
      }
      print A "$line\n";
    }
    close(A);
    close(AA);
    system("rm $accession_file.done");
    system("mv ${accession_file}.new $accession_file");
    open(DONE, ">${accession_file}.done") or Callstack(die => 1, message => "Could not open the done file.");
    open(AC, "<$accession_file") or Callstack(die => 1, message => "Could not open the file of accessions");
    OUTER: while (my $accession = <AC>) {
	sleep(2);
	my $attempts = 0;
	while ($attempts < $retries) {
	    if ($attempts >= $retries) {
		Callstack(die => 1, message => "Unable to acquire sequence for $accession after $retries attempts.");
	    }
	    chomp $accession;
	    print "Importing Accession: $accession\n";
	    my $seq;
	    if (defined($startpos)) {
		$seq = $db->Import_CDS($accession, $startpos);
	    } else {
		$seq = $db->Import_CDS($accession);
	    }
	    if ($seq =~ /^Error/) {
		sleep(30);
		$attempts++;
	    } else {
		print DONE "$accession\n";
		next OUTER;
	    }
	}
    }
    close(DONE);
    close(AC);
}

## Start Gather
sub Gather {
    my $state = shift;
    my $startpos = shift;
    my $ref = $db->Id_to_AccessionSpecies($state->{genome_id});
    $state->{accession} = $ref->{accession};
    $state->{species} = $ref->{species};
    $db->Create_Landscape("landscape_$state->{species}") unless($db->Tablep("landscape_$state->{species}"));
    $db->Create_Boot("boot_$state->{species}") unless($db->Tablep("boot_$state->{species}")); 
    unless ($state->{species} =~ /^virus/) {
	$db->Create_MFE("mfe_$state->{species}") unless($db->Tablep("mfe_$state->{species}"));
    }
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
    my $message = "${hour}:${min}.${sec} $mon/$mday id:$state->{queue_id} gid:$state->{genome_id} sp:$state->{species} acc:$state->{accession}\n";
    print $message;
    
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
    my $noslipsite = $db->MySelect(statement =>"SELECT num_slipsite FROM numslipsite WHERE accession = ?", type => 'row', vars => [$state->{accession}],);
    return(undef) if (defined($noslipsite->[0]) and $noslipsite->[0] == 0);
    $state->{genome_information} = $db->Get_ORF($state->{accession});
    my $sequence = $state->{genome_information}->{sequence};
    my $orf_start = $state->{genome_information}->{orf_start};
    my $motifs = new RNAMotif(config => $config);
    my $rnamotif_information;
    my $num_slipsites = 0;
    my $sp = 'UNDEF';
    my $ac = 'UNDEF';
    if (!defined($orf_start)) {
	print STDERR "ORF START for $ac is not defined, setting it to 0.";
	$orf_start = 0;
    }
    $sp = $state->{species} if (defined($state->{species}));
    $ac = $state->{accession} if (defined($state->{accession}));
    my $current = "sp:$sp acc:$ac st:$orf_start l:$len";
    print "PRF_Gather: about to run $current\n" if (defined($config->{debug}));
    if (defined($startpos)) {
#      $startpos = $startpos - $orf_start;
	my $inf = PRFdb::MakeFasta($state->{genome_information}->{sequence},
				   $startpos, 
#				   $startpos + $config->{seqlength});
				   $startpos + $len);
	$rnamotif_information->{$startpos}{filename} = $inf->{filename};
	$rnamotif_information->{$startpos}{sequence} = $inf->{string};
	$state->{rnamotif_information} = $rnamotif_information;
    } else {
	$rnamotif_information = $motifs->Search($state->{genome_information}->{sequence},
						$state->{genome_information}->{orf_start},
						$len);
	$state->{rnamotif_information} = $rnamotif_information;
	if (!defined($state->{rnamotif_information})) {
	    $db->Insert_NumSlipsite($state->{accession}, 0);
	}
    } ## End else, so all start sites should be collected.
    return(0) if (!defined($rnamotif_information));
  STARTSITE: foreach my $slipsite_start (keys %{$rnamotif_information}) {
      print "PRF_Gatherer: $current $slipsite_start\n" if (defined($config->{debug}));
      $num_slipsites++;
      $state->{species} = 'virus' if ($state->{species} =~ /virus/);
      my $mt = "mfe_$state->{species}";
      if ($config->{do_utr} == 0) {
	  my $end_of_orf = $db->MySelect(statement => "SELECT orf_stop FROM genome WHERE accession = ?", vars => [$state->{accession}], type =>'row',);
	  if ($end_of_orf->[0] < $slipsite_start) {
	      PRFdb::RemoveFile($rnamotif_information->{$slipsite_start}{filename});
	      next STARTSITE;
	  }
      }  ## End of if do_utr
      
      my ($nupack_mfe_id, $pknots_mfe_id, $hotknots_mfe_id);
      $state->{fasta_file} = $rnamotif_information->{$slipsite_start}{filename};
      $state->{sequence} = $rnamotif_information->{$slipsite_start}{sequence};
      
      if (!defined($state->{fasta_file} or $state->{fasta_file} eq '' or !-r $state->{fasta_file})) {
	  print "The fasta file for: $state->{accession} $slipsite_start does not exist.\n";
	  print "You may expect this script to die momentarily.\n";
      }
      
      my $check_seq = Check_Sequence_Length();
      if ($check_seq eq 'shorter than wanted') {
	  print "The sequence is: $check_seq and will be skipped.\n" if (defined($config->{debug}));
	  PRFdb::RemoveFile($state->{fasta_file});
	  next STARTSITE;
      } elsif ($check_seq eq 'null') {
	  print "The sequence is null and will be skipped.\n"  if (defined($config->{debug}));
	  PRFdb::RemoveFile($state->{fasta_file});
	  next STARTSITE;
      } elsif ($check_seq eq 'polya') {
	  print "The sequence is polya and will be skipped.\n"  if (defined($config->{debug}));
	  PRFdb::RemoveFile($state->{fasta_file});
	  next STARTSITE;
      }
      
      my $fold_search = new RNAFolders(file => $state->{fasta_file},
				       genome_id => $state->{genome_id},
				       species => $state->{species},
				       accession => $state->{accession},
				       config => $config,
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
	  my $nupack_mfe_info = $fold_search->Nupack_NOPAIRS('nopseudo');
	  my $vienna_mfe_info = $fold_search->Vienna();
	  my $pk = $pknots_mfe_info->{mfe};
	  my $nu = $nupack_mfe_info->{mfe};
	  my $vi = $vienna_mfe_info->{mfe};
          print "Pknots was undefined in do_comparison\n" if (!defined($pk));
          print "Nupack was undefined in do_comparison\n" if (!defined($pk));
          print "Vienna was undefined in do_comparison\n" if (!defined($pk));
	  my $comparison_string = "$pk,$nu,$vi";
	  $comparison_string =~ s/\s+//g;
	  my $update_string = qq"UPDATE $mt SET compare_mfes = '$comparison_string' WHERE accession = '$state->{accession}' AND seqlength = '$state->{seqlength}' AND start = '$slipsite_start'";
	  $db->MyExecute($update_string);
      }
      if ($config->{do_agree}) {
	  my $stmt = qq"(SELECT sequence, slipsite, parsed, output, mfe_method FROM $mt WHERE id = ?)
UNION
(SELECT sequence, slipsite, parsed, output, mfe_method FROM $mt WHERE id = ?)
UNION
(SELECT sequence, slipsite, parsed, output, mfe_method FROM $mt WHERE id = ?)";
	  my $info = $db->MySelect(statement => $stmt, vars => [$pknots_mfe_id, $nupack_mfe_id, $hotknots_mfe_id],);
	  my $agree = new Agree();
	  my $agree_datum = $agree->Do(info => $info);
	  $db->Put_Agree(accession => $state->{accession}, start => $slipsite_start, length => $state->{seqlength}, agree => $agree_datum);
	  undef $agree;
      }
      if ($config->{do_boot}) {
          my $tmp_nupack_mfe_id = $db->MySelect(statement => qq"SELECT id FROM $mt WHERE accession = ? AND start = ? AND seqlength = ? AND mfe_method = 'nupack'", type => 'single', vars => [$state->{accession}, $slipsite_start, $state->{seqlength}],);
          my $tmp_pknots_mfe_id = $db->MySelect(statement => qq"SELECT id FROM $mt WHERE accession = ? AND start = ? AND seqlength = ? AND mfe_method = 'pknots'", type => 'single', vars => [$state->{accession}, $slipsite_start, $state->{seqlength}],);
          my $tmp_hotknots_mfe_id = $db->MySelect(statement => qq"SELECT id FROM $mt WHERE accession = ? AND start = ? AND seqlength = ? AND mfe_method = 'hotknots'", type => 'single', vars => [$state->{accession}, $slipsite_start, $state->{seqlength}],);
	  my $boot = new Bootlace(genome_id => $state->{genome_id},
				  nupack_mfe_id => (defined($state->{nupack_mfe_id})) ?
				  $state->{nupack_mfe_id} : $nupack_mfe_id,
				  pknots_mfe_id => (defined($state->{pknots_mfe_id})) ?
				  $state->{pknots_mfe_id} : $pknots_mfe_id,
				  hotknots_mfe_id => (defined($state->{hotknots_mfe_id})) ?
				  $state->{hotknots_mfe_id} : $hotknots_mfe_id,
				  inputfile => $state->{fasta_file},
				  species => $state->{species},
				  accession => $state->{accession},
				  start => $slipsite_start,
				  seqlength => $state->{seqlength},
				  iterations => $config->{boot_iterations},
				  boot_mfe_methods => $config->{boot_mfe_methods},
				  randomizers => $config->{boot_randomizers},
				  config => $config,
				  );
          my @methods = keys(%{$config->{boot_mfe_methods}});
          my $boot_folds;
          foreach my $method (@methods) {
              $boot_folds = $db->Get_Num_Bootfolds(species => $state->{species},
						   genome_id =>$state->{genome_id},
						   start => $slipsite_start,
						   seqlength => $state->{seqlength},
						   method => $method,);
              print "$current has $boot_folds randomizations for method: $method\n" if (defined($config->{debug}));
              if (!defined($boot_folds) or $boot_folds == 0) {
                  my $bootlaces = $boot->Go($method);
                  my $rows = $db->Put_Boot($bootlaces);
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
	print "Landscape Gatherer, position $start_point\n" if (defined($config->{debug}));
	my $individual_sequence = ">$message";
	my $end_point = $start_point + ($config->{landscape_seqlength} - 1);
	my $sequence_string = '';
	foreach my $character ($start_point .. $end_point) {
	    if (defined($seq_array[$character])) {
		$sequence_string .= $seq_array[$character];
	    }
	}
	$individual_sequence = qq"$individual_sequence
$sequence_string
";
	$state->{fasta_file} = $db->Sequence_to_Fasta($individual_sequence);
	if (!defined($state->{accession})) {
	    Callstack(die => 1, message => "The accession is no longer defined. This cannot be allowed.");
	}
	my $landscape_table = qq/landscape_$state->{species}/;
	my $fold_search = new RNAFolders(file => $state->{fasta_file}, genome_id => $state->{genome_id}, config => $config,
					 species => $state->{species}, accession => $state->{accession},
					 start => $start_point,
					 sequence => $sequence_string,);
	my $nupack_foldedp = $db->Get_Num_RNAfolds('nupack', $state->{genome_id}, $start_point,
						   $config->{landscape_seqlength}, $landscape_table);
	my $pknots_foldedp = $db->Get_Num_RNAfolds('pknots', $state->{genome_id}, $start_point,
						   $config->{landscape_seqlength}, $landscape_table);
	my $vienna_foldedp = $db->Get_Num_RNAfolds('vienna', $state->{genome_id}, $start_point,
						   $config->{landscape_seqlength}, $landscape_table);
	my ($nupack_info, $nupack_mfe_id, $pknots_info, $pknots_mfe_id, $vienna_info, $vienna_mfe_id);
	if ($nupack_foldedp == 0) {
	    $nupack_info = $fold_search->Nupack_NOPAIRS('nopseudo');
	    $nupack_mfe_id = $db->Put_Nupack($nupack_info, $landscape_table);
	    ## Try to stop these random seeming errors with nupack
	    if (!defined($nupack_mfe_id)) {
		sleep(5);
		print STDERR "Trying again for nupack landscape fold.\n";
		$nupack_info = $fold_search->Nupack_NOPAIRS('nopseudo');
		$nupack_mfe_id = $db->Put_Nupack($nupack_info, $landscape_table);
	    }
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
    die("No rnamotif template file set.") unless (defined($config->{exe_rnamotif_template}));
    die("No rnamotif descriptor file set.") unless (defined($config->{exe_rnamotif_descriptor}));
    die("Workdir must be executable: $config->{workdir} $!") unless (-x $config->{workdir});
    die("Workdir must be writable: $!") unless (-w $config->{workdir});
    die("Database not defined") if ($config->{database_name} eq 'prfconfigdefault_db');
    die("Database host not defined") if ($config->{database_host} eq 'prfconfigdefault_host');
    die("Database user not defined") if ($config->{database_user} eq 'prfconfigdefault_user');
    die("Database pass not defined") if ($config->{database_pass} eq 'prfconfigdefault_pass');
    
    unless (-r $config->{exe_rnamotif_descriptor}) {
	RNAMotif::Descriptor(config=>$config);
	  unless (-r $config->{exe_rnamotif_descriptor}) {
	      die("Unable to read the rnamotif descriptor file: $!");
	  }
      }
    unless (-r "$ENV{PRFDB_HOME}/.htaccess") {
	my $copy_command;
	if ($config->{has_modperl}) {
	    $copy_command = qq(cp $ENV{PRFDB_HOME}/html/htaccess.modperl $ENV{PRFDB_HOME}/.htaccess);
	} else {
	    $copy_command = qq(cp $ENV{PRFDB_HOME}/html/htaccess.cgi $ENV{PRFDB_HOME}/.htaccess);
	}
	system($copy_command);
    }
## End Check_Environment
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
    } else {
	print "I AM NOT using a hacked version of nupack!\n";
    }
    if ($config->{do_nupack}) {
	print "I AM doing a nupack fold using the program: $config->{exe_nupack}\n";
    } else {
	print "I AM NOT doing a nupack fold\n"; 
    }
    if ($config->{do_pknots}) {
	print "I AM doing a pknots fold using the program: $config->{exe_pknots}\n";
    } else {
	print "I AM NOT doing a pknots fold\n";
    }
    if ($config->{do_boot}) {
	print "PLEASE CHECK THE prfdb.conf to see if you are using NOPAIRS\n";
	my $randomizers = $config->{boot_randomizers};
	my $mfes = $config->{boot_mfe_methods};
	my $nu_boot = $config->{exe_nupack_boot};
	print "I AM doing a boot using the following randomizers\n";
	foreach my $k (keys %{$randomizers}) {
	    print "$k\n";
	}
	print "and the following mfe methods:\n";
	foreach my $k (keys %{$mfes}) {
	    print "$k\n";
	}
	print "nupack is using the following program for bootstrap:
$nu_boot and running: $config->{boot_iterations} times\n";
    } else {
	print "I AM NOT doing a boot.\n";
    }
    if ($config->{arch_specific_exe}) {
	print "I AM USING ARCH SPECIFIC EXECUTABLES\n";
    } else {
	print "I am not using arch specific executables\n"; 
    }
    if (ref($config->{seqlength}) eq 'ARRAY') {
	my @fun = @{$config->{seqlength}};
    print "The default structure length in this run is: @fun\n";
    }
    print "I am using the database: $config->{database_name} and user: $config->{database_user}\n\n\n";
    sleep(5);
}
## End Print_Config

## Start Check_Boot_Connectivity
sub Check_Boot_Connectivity {
    my $state = shift;
    my $slipsite_start = shift;
    my $genome_id = $state->{genome_id};
    my $species = $state->{species};
    my $mt = "mfe_$species";
    my $boot_table = ($species =~ /virus/ ? "boot_virus" : "boot_$species");
    my $check_statement = qq"SELECT mfe_id, mfe_method, id, genome_id FROM $boot_table WHERE genome_id = ? and start = ?";
    my $answer = $db->MySelect(statement => $check_statement, vars =>[$genome_id, $slipsite_start],);
    my $num_fixed = 0;
    foreach my $boot (@{$answer}) {
	my $mfe_id = $boot->[0];
	my $mfe_method = $boot->[1];
	my $boot_id = $boot->[2];
	my $genome_id = $boot->[3];
	if (!defined($mfe_id) or $mfe_id == '0') {
	    ## Then reconnect it using $mfe_method and $boot_id and $genome_id
	    my $new_mfe_id_stmt = qq"SELECT id FROM $mt where genome_id = ? and start = ? and mfe_method = ?";
	    my $new_mfe_id_arrayref = $db->MySelect(statement => $new_mfe_id_stmt, vars => [$genome_id, $slipsite_start, $mfe_method],);
	    my $new_mfe_id = $new_mfe_id_arrayref->[0]->[0];
	    if ((!defined($new_mfe_id) or $new_mfe_id == '0' or $new_mfe_id eq '') and $mfe_method eq 'nupack') {
		### Then there is no nupack information :(
		#print "No Nupack information!\n";
		if (!defined($state->{accession})) {
		    Callstack(die => 1, message => "The accession is no longer defined. This cannot be allowed.");
		}
		my $fold_search = new RNAFolders(file => $state->{fasta_file}, genome_id => $state->{genome_id}, config => $config, species => $state->{species}, accession => $state->{accession}, start => $slipsite_start,);
		$new_mfe_id = Check_Nupack($fold_search, $slipsite_start);
	    } elsif ((!defined($new_mfe_id) or $new_mfe_id == '0' or $new_mfe_id eq '') and $mfe_method eq 'pknots') {
		### Then there is no pknots information :(
		if (!defined($state->{accession})) {
		    Callstack(die => 1, message => "The accession is no longer defined. This cannot be allowed.");
		}
		my $fold_search = new RNAFolders(file => $state->{fasta_file}, genome_id => $state->{genome_id}, config => $config, species => $state->{species}, accession => $state->{accession}, start => $slipsite_start,);
		$new_mfe_id = Check_Pknots($fold_search, $slipsite_start);
	    } ### End if there is no mfe_id and pknots was the method
	    my $update_mfe_id_statement = qq(UPDATE $boot_table SET mfe_id = ? WHERE id = ?);
	    $db->MyExecute(statement => $update_mfe_id_statement, vars =>[$new_mfe_id, $boot_id],);
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
    my $mfe_varname = qq"${type}_mfe_id";
    my $folds = $db->Get_Num_RNAfolds($type, $state->{genome_id}, $slipsite_start, $state->{seqlength});
    if ($folds > 0) { ### If there ARE existing folds...
	print "$state->{genome_id} has $folds > 0 pknots_folds at position $slipsite_start\n" if (defined($config->{debug}));
	$state->{$mfe_varname} = $db->Get_MFE_ID($state->{genome_id}, $slipsite_start,
						 $state->{seqlength}, $type);
	$mfe_id = $state->{$mfe_varname};
	print "Check_Folds $type - already done: state: $mfe_id\n" if (defined($config->{debug}));
    } else { ### If there are NO existing folds...
	print "$state->{genome_id} has only $folds <= 0 $type at position $slipsite_start\n" if (defined($config->{debug}));
	my ($info, $mfe_id);
	if ($type eq 'pknots') {
	    $info = $fold_search->Pknots();
	    $mfe_id = $db->Put_Pknots($info);
	    $state->{$mfe_varname} = $mfe_id;
	    print "Performed Put_Pknots and returned $mfe_id\n" if (defined($config->{debug}));
	} elsif ($type eq 'nupack') {
	    $info = $fold_search->Nupack_NOPAIRS();
	    $mfe_id = $db->Put_Nupack($info);
	    $state->{$mfe_varname} = $mfe_id;
	    print "Performed Put_Nupack and returned $mfe_id\n" if (defined($config->{debug}));
	} elsif ($type eq 'hotknots') {
	    $info = $fold_search->Hotknots();
	    $mfe_id = $db->Put_Hotknots($info);
	    $state->{$mfe_varname} = $mfe_id;
	    print "Performed Put_Hotknots and returned $mfe_id\n" if (defined($config->{debug}));
	} else {
	    Callstack(die => 1, message => "Non existing type in Check_Folds");
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
    open(IN, "<$filename") or Callstack(die => 1, message => "Check_Sequence_Length: Couldn't open $filename");
    ## OPEN IN in Check_Sequence_Length
    my $output = '';
    my @out = ();
    while (my $line = <IN>) {
	chomp $line;
	if ($line =~ /^\>/) {
	    $output .= $line;
	} else {
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
    } elsif ($sequence_length > $wanted_sequence_length) {
	return ('longer than wanted');
    } elsif ($sequence_length == $wanted_sequence_length) {
	return ('equal');
    } elsif ($sequence_length < $wanted_sequence_length) {
	return ('shorter than wanted');
    } else {
	return ('unknown');
    }
}
## End Check_Sequence_length

sub Make_Blast {
    my @sp = @{$config->{index_species}};
    my $outputfile = 'blast_prfdb.fasta.gz';
    system("rm $ENV{PRFDB_HOME}/blast/$outputfile");
    system("touch $ENV{PRFDB_HOME}/blast/$outputfile");
    foreach my $s (@sp) {
	next if ($s =~ /virus/);
	print "Getting $s\n";
	$db->Genome_to_Fasta($outputfile, $s);
    }
    my $blast = new PRFBlast;
    print "Formatting Database\n";
    $blast->Format_Db($ENV{PRFDB_HOME}, $outputfile);
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

sub Zscore {
    my $tables = $db->MySelect("show tables");
    my $mt;
    foreach my $t (@{$tables}) {
	my $table = $t->[0];
	next unless ($table =~ /^boot_/);
	my $species = $table;
	$species =~ s/^boot_//g;
	my $all_boot_stmt = qq"SELECT id, mfe_id, mfe_mean, mfe_sd, FROM $table WHERE zscore is NULL";
	$mt = qq"mfe_$species";
	my $all_boot = $db->MySelect($all_boot_stmt);
	foreach my $boot (@{$all_boot}) {
	    my $id = $boot->[0];
	    my $mfe_id = $boot->[1];
	    my $mfe_mean = $boot->[2];
	    my $mfe_sd = $boot->[3];
	    my $species = $boot->[4];
	    my $mfe_stmt = qq"SELECT mfe FROM $mt WHERE id = '$mfe_id'";
	    my $mfe = $db->MySelect(statement => $mfe_stmt, type =>'single');
	    $mfe_sd = 1 if (!defined($mfe_sd) or $mfe_sd == 0);
	    $mfe = 0 if (!defined($mfe));
	    $mfe_mean = 0 if (!defined($mfe_mean));
	    my $zscore = sprintf("%.3f", ($mfe - $mfe_mean) / $mfe_sd);
	    my $update_stmt = qq(UPDATE $table SET zscore = '$zscore' WHERE id = '$id');
	    $db->MyExecute($update_stmt);
	}
    }
    my $cleaning = qq"DELETE FROM $mt WHERE mfe > '10'";
    $db->MyExecute($cleaning);
}

sub Optimize {
    my $tables = $db->MySelect("show tables");
    unless ($config->{maintenance_skip_optimize}) {
	foreach my $t (@{$tables}) {
            print "Performing OPTIMIZE TABLE $t->[0]\n";
	    $db->MyExecute("OPTIMIZE TABLE $t->[0]");
            print "Performing ANALYZE TABLE $t->[0]\n";
	    $db->MyExecute("ANALYZE TABLE $t->[0]");
	}
    }
}

sub Maintenance {
    my $finished_species = $db->MySelect(statement => "SELECT species FROM finished", type => 'flat');
    $finished_species = [] if (!defined($finished_species));
#    $db->MyExecute("UPDATE wait SET wait = '1'");
    unless ($config->{maintenance_skip_sleep}) {
	sleep(10);
    }
    ## Optimize the tables
    Optimize();
    my $tables = $db->MySelect("show tables");
    unless ($config->{maintenance_skip_optimize}) {
	foreach my $t (@{$tables}) {
            print "Performing OPTIMIZE TABLE $t->[0]\n";
	    $db->MyExecute("OPTIMIZE TABLE $t->[0]");
            print "Performing ANALYZE TABLE $t->[0]\n";
	    $db->MyExecute("ANALYZE TABLE $t->[0]");
	}
    }
    ## Fill in missing zscores
    unless ($config->{maintenance_skip_zscore}) {
        print "Calculating Z scores\n";
	Zscore();
    }
    ## The stats table
    unless ($config->{maintenance_skip_stats}) {
	my $data = {
	    species => $config->{index_species},
	    seqlength => $config->{seqlength},
	    max_mfe => [$config->{max_mfe}],
	    mfe_method => ['pknots','nupack','hotknots'],
	};
        print "Recreating the Stats table\n";
	$db->Put_Stats($data, $finished_species);
    }
    ## End the stats table

    ## The index stats table
    unless ($config->{maintenance_skip_index}) {
	my $test = $db->Tablep('index_stats');
	$db->Create_Index_Stats() unless($test);
	my ($num_genome, $num_mfe_entries, $num_mfe_knotted, $mt);
      OUT: foreach my $species (@{$config->{index_species}}) {
	  foreach my $sp (@{$finished_species}) {
	      next OUT if ($sp eq $species);
	  }
	  print "Filling index_stats for $species\n";
	  next if ($species =~ /^virus-/);
	  $mt = "mfe_$species";
	  $num_genome = $db->MySelect(statement=>qq"SELECT COUNT(id) FROM genome WHERE species = ?", type=>'single', vars =>[$species,]);
	  $num_mfe_entries = $db->MySelect(statement=>qq"SELECT COUNT(id) FROM $mt WHERE species = ?",type=>'single', vars => [$species,]);
	  $num_mfe_knotted = $db->MySelect(statement=>qq"SELECT COUNT(DISTINCT(accession)) FROM $mt WHERE knotp = '1' and species = ?",type=>'single', vars => [$species],);
	  my $rc = $db->MyExecute(statement => qq"DELETE FROM index_stats WHERE species = ?", vars => [$species],);
	  $rc = $db->MyExecute(statement => qq"INSERT INTO index_stats VALUES('',?,?,?,?)", vars => [$species, $num_genome, $num_mfe_entries, $num_mfe_knotted],);
      }  ## End foreach species...
	my $rc = $db->MyExecute(statement => qq"DELETE FROM index_stats WHERE species = 'virus'");
	$num_genome = $db->MySelect(statement=>qq"SELECT COUNT(id) FROM genome WHERE species like 'virus-%'", type=>'single');
	$num_mfe_entries = $db->MySelect(statement=>qq"SELECT COUNT(id) FROM mfe_virus",type=>'single');
	$num_mfe_knotted = $db->MySelect(statement=>qq"SELECT COUNT(DISTINCT(accession)) FROM mfe_virus WHERE knotp = '1'",type=>'single');
	$rc = $db->MyExecute(statement => qq"INSERT INTO index_stats VALUES('', 'virus',?,?,?)", vars => [$num_genome, $num_mfe_entries, $num_mfe_knotted],);
	## End index_stats
    }
    unless ($config->{maintenance_skip_clouds}) {
	## Generate all clouds
	my @slipsites = ('AAAUUUA', 'UUUAAAU', 'AAAAAAA', 'UUUAAAA', 'UUUUUUA', 'AAAUUUU', 'UUUUUUU', 'UUUAAAC', 'AAAAAAU', 'AAAUUUC', 'AAAAAAC', 'GGGUUUA', 'UUUUUUC', 'GGGAAAA', 'CCCUUUA', 'CCCAAAC', 'CCCAAAA', 'GGGAAAU', 'GGGUUUU', 'GGGAAAC', 'CCCUUUC', 'CCCUUUU', 'GGGAAAG', 'GGGUUUC', 'all');
	my @pknot = ('yes','no');
	foreach my $seqlength (@{$config->{seqlength}}) {
	    foreach my $pk (@pknot) {
	      SP: foreach my $species (@{$config->{index_species}}) {
		  foreach my $sp (@{$finished_species}) {
		      next SP if ($sp eq $species);
		  }
		  foreach my $slip (@slipsites) {
		      ## First check if we were able to load PRFGraph
		      if ($load_return) {
			  print "Generating picture for $species slipsite: $slip knotted: $pk seqlength: $seqlength\n";
			  my $cloud = new PRFGraph(config => $config);
			  my $pknots_only = undef;
			  my $boot_table = "boot_$species";
			  my $suffix = undef;
			  if ($pk eq 'yes') {
			      $suffix .= "-pknot";
			      $pknots_only = 1;
			  }
			  if ($slip eq 'all') {
			      $suffix .= "-all";
			  } else {
			      $suffix .= "-${slip}";
			  }
			  $suffix .= "-${seqlength}";
			  my $mt = "mfe_$species";
			  my $cloud_output_filename = $cloud->Picture_Filename(type => 'cloud',
									       species => $species,
									       suffix => $suffix,);
			  my $cloud_url = $cloud->Picture_Filename(type => 'cloud',
								   species => $species,
								   url => 'url',
								   suffix => $suffix,);
			  $cloud_url = $ENV{PRFDB_HOME} . '/' . $cloud_url;
			  my ($points_stmt, $averages_stmt, $points, $averages);
			  if (!-f $cloud_output_filename) {
			      $points_stmt = qq"SELECT SQL_BUFFER_RESULT $mt.mfe, $boot_table.zscore, $mt.accession, $mt.knotp, $mt.slipsite, $mt.start, genome.genename FROM $mt, $boot_table, genome WHERE $boot_table.zscore IS NOT NULL AND $mt.mfe > -80 AND $mt.mfe < 5 AND $boot_table.zscore > -10 AND $boot_table.zscore < 10 AND $mt.species = ? AND $mt.seqlength = $seqlength AND $mt.id = $boot_table.mfe_id AND ";
			      $averages_stmt = qq"SELECT SQL_BUFFER_RESULT avg($mt.mfe), avg($boot_table.zscore), stddev($mt.mfe), stddev($boot_table.zscore) FROM $mt, $boot_table WHERE $boot_table.zscore IS NOT NULL AND $mt.mfe > -80 AND $mt.mfe < 5 AND $boot_table.zscore > -10 AND $boot_table.zscore < 10 AND $mt.seqlength = $seqlength AND $mt.id = $boot_table.mfe_id AND ";
			      
			      if ($pk eq 'yes') {
				  $points_stmt .= "$mt.knotp = '1' AND ";
				  $averages_stmt .= "$mt.knotp = '1' AND ";
			      }
			      $points_stmt .= " $mt.genome_id = genome.id";
			      $averages_stmt =~ s/AND $//g;
			      $points = $db->MySelect(statement => $points_stmt, vars => [$species]);
			      $averages = $db->MySelect(statement => $averages_stmt, vars => [$species], type => 'row',);
			      my $cloud_data;
			      my %args;
			      if ($pk eq 'yes') {
				  %args = (
				      seqlength => $seqlength,
				      species => $species,
				      points => $points,
				      averages => $averages,
				      filename => $cloud_output_filename,
				      url => $ENV{PRFDB_HOME},
				      pknot => 1,
				      slipsites => $slip,
				      );
			      } else {
				  %args = (
				      seqlength => $seqlength,
				      species => $species,
				      points => $points,
				      averages => $averages,
				      filename => $cloud_output_filename,
				      url => $ENV{PRFDB_HOME},
				      slipsites => $slip,
				      );
			      }
			      $cloud_data = $cloud->Make_Cloud(%args);
			  }
			  
			  my $map_file = $cloud_output_filename . '.map';
			  my $extension_percent_filename = $cloud->Picture_Filename(type => 'extension_percent',
										    species => $species,);
			  my $extension_codons_filename = $cloud->Picture_Filename(type=> 'extension_codons',
										   species => $species,);
			  my $percent_map_file = $extension_percent_filename . '.map';
			  my $codons_map_file = $extension_codons_filename . '.map';
			  
			  if (!-f $extension_codons_filename) {
			      $cloud->Make_Extension($species, $extension_codons_filename, 'codons', $ENV{PRFDB_HOME});
			  }
			  if (!-f $extension_percent_filename) {
			      $cloud->Make_Extension($species, $extension_percent_filename, 'percent', $ENV{PRFDB_HOME});
			  }
		      }
		  } ## Foreach slipsite
	      } ## foreach species
	    }  ## if pknotted
	}
    } ## seqlengths
    ## End generating all clouds
#    $db->MyExecute("UPDATE wait set wait = '0'");
}

sub Import_Genbank_Accession {
    my $acc = shift;
    my $import = $db->Import_CDS($acc);
    exit(0);
}

sub Import_Genbank_Flatfile {
    my $import_genbank = shift;
    my $accession = shift;
    my $genome = shift;
    die("Could not load Bio::DB::Universal.\n $@\n") unless (eval "use Bio::DB::Universal; 1");
    die("Could not load Bio::Index::GenBank.\n $@\n") unless (eval "use Bio::Index::GenBank; 1");
    
    my $uni = new Bio::DB::Universal();
    my $in  = Bio::SeqIO->new(-file => $import_genbank,
			      -format => 'genbank');
    while (my $seq = $in->next_seq()) {
	#my $seq = $uni->get_Seq_by_id($accession);
	my @cds = grep {$_->primary_tag eq 'CDS'} $seq->get_SeqFeatures();
	if (!defined($accession)) {
	    $accession = $seq->accession_number();
	}
	print "About to import: $accession.\n";
	my ($protein_sequence, $orf_start, $orf_stop);
	my $binomial_species = $seq->species->binomial();
	my ($genus, $species) = split(/ /, $binomial_species);
	my $full_species = qq(${genus}_${species});
	$full_species =~ tr/[A-Z]/[a-z]/;
	$config->{species} = $full_species;
	unless ($full_species =~ /virus/) {
	    $db->Create_Landscape(qq"landscape_$full_species");
	    $db->Create_Boot(qq"boot_$full_species");
	    $db->Create_MFE(qq"mfe_$full_species");
	}
	my $full_comment = $seq->desc();
	my $defline = "lcl||gb|$accession|species|$full_comment\n";
	my ($genename, $desc) = split(/\,/, $full_comment);
	my $mrna_sequence = $seq->seq();
	my @mrna_seq = split(//, $mrna_sequence);
	my $counter = 0;
	my $num_cds = scalar(@cds);
	
	my %datum_orig = (
			  accession => $accession,
			  species => $full_species,
			  defline => $defline,
			  );
	foreach my $feature (@cds) {
	    $counter++;
	    my $primary_tag = $feature->primary_tag();
	    $protein_sequence = $feature->seq->translate->seq();
	    $orf_start = $feature->start();
	    $orf_stop = $feature->end();
	    my ($direction, $start, $stop);
	    if (!defined($feature->{_location}{_strand})) {
		$direction = 'undefined';
		$start = $orf_start;
		$stop = $orf_stop;
	    } elsif ($feature->{_location}{_strand} == 1) {
		$direction = 'forward';
		$start = $orf_start;
		$stop = $orf_stop;
	    } elsif ($feature->{_location}{_strand} == -1) {
		$direction = 'reverse';
		$start = $orf_stop;
		$stop = $orf_start;
	    }
	    my $padding = 300;
	    my $tmp_mrna_sequence = '';
	    my $mrna_seqlength = $orf_stop - $orf_start;
	    my $orf_start_pad = $orf_start - $padding;
	    my $orf_stop_pad = $orf_stop + $padding;
	    foreach my $c (($orf_start_pad - 1) .. ($orf_stop_pad - 1)) {
		next if (!defined($mrna_seq[$c]));
		$tmp_mrna_sequence .= $mrna_seq[$c];
	    }
	    if ($direction eq 'reverse') {
		$tmp_mrna_sequence =~ tr/ATGCatgcuU/TACGtacgaA/;
		$tmp_mrna_sequence = reverse($tmp_mrna_sequence);
	    }
	    #	print "The sequences for this guy is $tmp_mrna_sequence\n";
	    ### Don't change me, this is provided by genbank
	    ### FINAL TEST IF $startpos is DEFINED THEN OVERRIDE WHATEVER YOU FOUND
	    my $genename = '';
	    if (defined($feature->{_gsf_tag_hash}->{gene}->[0])) {
		$genename .= $feature->{_gsf_tag_hash}->{gene}->[0];
	    }
	    if (defined($feature->{_gsf_tag_hash}->{product}->[0])) {
		$genename .= ", $feature->{_gsf_tag_hash}->{product}->[0]";
	    }
	    my $db_xrefs = "";
	    my $omim_id = "";
	    my $hgnc_id = "";
	    if (defined($feature->{_gsf_tag_hash}->{db_xref}->[0])) {
		my @features = @{$feature->{_gsf_tag_hash}->{db_xref}};
		foreach my $db (@features) {
		    $db_xrefs .= "$db ";
		    if ($db =~ /^MIM\:/) {
			$db =~ s/^MIM\://g;
			$omim_id .= "$db ";
		    }    ## Is it in omim?
		    if ($db =~ /^HGNC\:/) {
			$db =~ s/^HGNC\://g;
			$hgnc_id .= "$db ";
		    }
		} ## Foreach $db
	    }
	    if ($config->{genome}) {  ## Check to see if this is a viral or bacterial genome file
		## In which case there is a single accession for many ORFs
		$accession = qq"${accession}-${orf_start}";
	    }
	    my %datum = (### FIXME
			 accession => $accession,
			 mrna_seq => $tmp_mrna_sequence,
			 protein_seq => $protein_sequence,
			 orf_start => 301,
			 orf_stop => (301 + $mrna_seqlength),
			 direction => $direction,
			 species => $full_species,
			 genename => $genename,
			 version => $seq->{_seq_version},
			 comment => $feature->{_gsf_tag_hash}->{note}->[0],
			 db_xrefs => $db_xrefs,
			 omim_id => $omim_id,
			 defline => qq"$defline, $feature->{_gsf_tag_hash}->{gene}->[0], $feature->{_gsf_tag_hash}->{product}->[0]",
		);
	    $db->Insert_Genome_Entry(\%datum);
	    $accession = undef;
	    }
      }
}

sub Make_Queue_Jobs {
    ## copying out of the perl script make_jobs.pl
    die("Could not load Template.\n$@\n") unless (eval "use Template; 1");
    my $template_config;
    foreach my $k (keys %{$config}) {
	$template_config->{$k} = $config->{$k};
    }
    $template_config->{PRE_PROCESS} = 0;
    $template_config->{EVAL_PERL} = 0;
    $template_config->{INTERPOLATE} = 0;
    $template_config->{POST_CHOMP} = 0;
    $template_config->{ABSOLUTE} = 1;
    my $template = new Template($template_config);
    my $input_file = "$ENV{PRFDB_HOME}/descr/job_template";
    my @arches = split(/ /, $config->{pbs_arches});
    foreach my $arch (@arches) {
	system("mkdir -p jobs/$arch") unless (-d "jobs/$arch");
	my $archchar = substr($arch,0,3);
	foreach my $daemon ("01" .. $template_config->{pbs_num_daemons}) {
	    my $output_file = "jobs/$arch/$daemon";
	    ## First delete the existing job file in case a change has been made to the
	    ## configuration file
	    unlink($output_file);
	    my $name = $template_config->{pbs_partialname};
	    my $pbs_fullname = "${name}_${archchar}_${daemon}";
	    my $incdir = "$ENV{PRFDB_HOME}/usr/perl.${arch}/lib";
	    my $vars = {
		pbs_shell => $template_config->{pbs_shell},
		pbs_memory => $template_config->{pbs_memory},
		pbs_cpu => $template_config->{pbs_cpu},
		pbs_arch => $arch,
		pbs_name => $pbs_fullname,
		pbs_cputime => $template_config->{pbs_cputime},
		pbs_nodes => 1,
		perl => $template_config->{exe_perl},
		incdir => $incdir,
		daemon_name => $template_config->{daemon_name},
		job_num => $daemon,
	    };
	    $template->process($input_file, $vars, $output_file) or Callstack(die => 1, message => $template->error());
#	    system("/usr/local/bin/qsub $output_file");
#	    print "Going to run /usr/local/bin/qsub $output_file\n";
	}
    }
}

BEGIN {
    unless (defined($ENV{PRFDB_HOME})) {
        print "These scripts depend widely on the environment variable: PRFDB_HOME.
It is currently not set.  Setting it to .
";
        $ENV{PRFDB_HOME} = $ENV{PWD};
    }
    $ENV{LD_LIBRARY_PATH} .= ":$config->{ENV_LIBRARY_PATH}" if(defined($config->{ENV_LIBRARY_PATH}));
}

END {
    $db->Disconnect() if (defined($db));
    PRFdb::RemoveFile('all') if (defined($config->{remove_end}));
}
