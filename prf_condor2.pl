#! /usr/bin/perl -w
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
use MoreRandom;

my $config = $PRFConfig::config;
my $db     = new PRFdb;
my %conf   = ();
GetOptions(
  'nodaemon:i' => \$conf{nodaemon},    ## If this gets set, then the prf_daemon
  ##  will exit before it gets to the queue
  'help|version'  => \$conf{help},         ## Print some help information
  'accession|i:s' => \$conf{input_seq},    ## An accession to specifically fold.  If it is not already in the db
  ## Import it and then fold it.
  'copyfrom:s'    => \$conf{copyfrom},       ## Another database from which to copy the genome table
  'input_file:s'  => \$conf{input_file},     ## A file of accessions to import and queue
  'input_fasta:s' => \$conf{input_fasta},    ## A file of fasta data to import and queue
  'fasta_style:s' => \$conf{fasta_style},    ## The style of input fasta (sgd, ncbi, etc)
  ## By default this should be 0/1, but for some yeast genomes it may be 1000
  'fillqueue'  => \$conf{fillqueue},         ## A boolean to see if the queue should be filled.
  'resetqueue' => \$conf{resetqueue},        ## A boolean to reset the queue
  'startpos:s' => \$conf{startpos},          ## A specific start position to fold a single sequence at,
  ## also usable by inputfasta or inputfile
  'startmotif:s'           => \$conf{startmotif},             ## A specific start motif to start folding at
  'length:i'               => \$conf{max_struct_length},      ## i == integer
  'nupack:i'               => \$conf{do_nupack},              ## If no type definition is given, it is boolean
  'pknots:i'               => \$conf{do_pknots},              ## The question is, will these be set to 0 if not applied?
  'boot:i'                 => \$conf{do_boot},
  'workdir:s'              => \$conf{workdir},
  'nupack_nopairs:i'       => \$conf{nupack_nopairs_hack},
  'arch:i'                 => \$conf{arch_specific_exe},
  'iterations:i'           => \$conf{boot_iterations},
  'db|d:s'                 => \$conf{db},
  'host:s'                 => \$conf{host},
  'user:s'                 => \$conf{user},
  'pass:s'                 => \$conf{pass},
  'slip_site_1:s'          => \$conf{slip_site_1},
  'slip_site_2:s'          => \$conf{slip_site_2},
  'slip_site_3:s'          => \$conf{slip_site_3},
  'slip_site_spacer_min:i' => \$conf{slip_site_spacer_min},
  'slip_site_spacer_max:i' => \$conf{slip_site_spacer_max},
  'stem1_min:i'            => \$conf{stem1_min},
  'stem1_max:i'            => \$conf{stem1_max},
  'stem1_bulge:i'          => \$conf{stem1_bulge},
  'stem1_spacer_min:i'     => \$conf{stem1_spacer_min},
  'stem1_spacer_max:i'     => \$conf{stem1_spacer_max},
  'stem2_min:i'            => \$conf{stem2_min},
  'stem2_max:i'            => \$conf{stem2_max},
  'stem2_bulge:i'          => \$conf{stem2_bulge},
  'stem2_loop_min:i'       => \$conf{stem2_loop_min},
  'stem2_loop_max:i'       => \$conf{stem2_loop_max},
  'stem2_spacer_max:i'     => \$conf{stem2_spacer_min},
  'stem2_spacer_max:i'     => \$conf{stem2_spacer_max},
  'num_daemons:i'          => \$conf{num_daemons},
  'condor_memory:i'        => \$conf{condor_memory},
  'condor_os:i'            => \$conf{condor_os},
  'condor_arch:s'          => \$conf{condor_arch},
  'condor_universe:s'      => \$conf{condor_universe},
);
foreach my $opt ( keys %conf ) {
  $config->{$opt} = $conf{$opt} if ( defined( $conf{$opt} ) );
}

my $state = {};

### START DOING WORK NOW
chdir( $config->{basedir} );
Check_Environment();
Print_Config();
Check_Tables();

## Some Arguments should be checked before others...
## These first arguments are not exclusive and so are separate ifs
if ( defined( $config->{help} ) ) {
  Print_Help();
}
if ( defined( $config->{fillqueue} ) ) {
  $db->FillQueue();
}
if ( defined( $config->{resetqueue} ) ) {
  $db->Reset_Queue();
}
if ( defined( $config->{copyfrom} ) ) {
  $db->Copy_Genome( $config->{copyfrom} );
}
if ( defined( $config->{input_file} ) ) {
  if ( defined( $config->{startpos} ) ) {
    Read_Accessions( $config->{input_file}, $config->{startpos} );
  } else {
    Read_Accessions( $config->{input_file} );
  }
}
if ( defined( $config->{accession} ) ) {
  $config->{num_daemons} = 1;    ## Only run 1 daemon
  $db->Import_CDS( $config->{accession} );
  $state->{0}->{queue_id}  = 0;                                                          ## Dumb hack lives on
  $state->{0}->{accession} = $config->{accession};
  $state->{0}->{genome_id} = $db->Get_GenomeId_From_Accession( $config->{accession} );
  if ( defined( $config->{startpos} ) ) {
    Gather( $state, $config->{startpos} );
  } elsif ( defined( $config->{startmotif} ) ) {
    Gather( $state, $config->{startmotif} );
  } else {
    Gather($state);
  }
  ## Once the prf_daemon finishes this accession it will start reading the queue...
}
if ( defined( $config->{input_fasta} ) ) {
  if ( defined( $config->{startpos} ) ) {
    $db->Import_Fasta( $config->{input_fasta}, $config->{fasta_style}, $config->{startpos} );
  } else {
    $db->Import_Fasta( $config->{input_fasta}, $config->{fasta_style} );
  }
}

if ( $config->{nodaemon} eq '1' ) {
  print "No daemon is set, existing before reading queue.\n";
  exit(0);
}

my $finished = 0;
until ( $finished > 0 ) {
  for my $slot ( 0 .. $config->{num_daemons} ) {
    if ( !defined( $state->{$slot} or Check_Slot($slot) eq 'done' ) ) {
      $state->{$slot} = Setup_State($slot);
    } else {
      sleep(1);
    }
  }
}

sub Check_Slot {
  my $slot = shift;
  $state->{$slot} = $db->Get_Input();
  print "Slot: $slot Qid: $state->{$slot}->{queue_id} Gid: $state->{$slot}->{genome_id} Sp:$state->{$slot}->{species} Acc:$state->{$slot}->{accession}\n";
  my $motifs = new RNAMotif_Search;
  $state->{$slot}->{rnamotif_information} = $motifs->Search( $state->{$slot}->{mrna_seq}, $state->{$slot}->{orf_start} );
  $state->{$slot}->{done} = 1 unless ( defined( $state->{$slot}->{rnamotif_information} ) );
STARTSITE: foreach my $slipsite_start ( sort keys %{ $state->{$slot}->{rnamotif_information} } ) {
    if ( !defined( $state->{$slot}->{fasta_file} or $state->{$slot}->{fasta_file} eq '' or !-r $state->{$slot}->{fasta_file} ) ) {
      print "The fasta file for $state->{$slot}->{accession} $slipsite_start does not exist.
Bad things are going to happen soon.\n";
    }
    my $check_seq = Check_Sequence_Length($slot);
    unless ( $check_seq eq 'good' ) {
      unlink( $state->{$slot}->{fasta_file} );
      next STARTSITE;
    }
    my $fold_search = new RNAFolders(
      file      => $state->{$slot}->{fasta_file},
      genome_id => $state->{$slot}->{genome_id},
      species   => $state->{$slot}->{species},
      accession => $state->{$slot}->{accession},
      start     => $slipsite_start,
    );
    if ( $config->{do_nupack} ) {
      my $nupack_mfe_id = Check_Folds( 'nupack', $fold_search, $slipsite_start, $slot );
      my $seqlength = $db->Get_Seqlength($nupack_mfe_id);
    }    ### End check if we should do a nupack fold

    if ( $config->{do_pknots} ) {    ### Do we run a pknots fold?
      my $pknots_mfe_id = Check_Folds( 'pknots', $fold_search, $slipsite_start, $slot );
      my $seqlength = $db->Get_Seqlength($pknots_mfe_id);
    }
    unlink( $state->{$slot}->{fasta_file} );
    Clean_Up( $state->{$slot} );
  }
}

sub Check_Folds {
  my $name           = shift;
  my $fold_search    = shift;
  my $slipsite_start = shift;
  my $slot           = shift;
  my $folds          = $db->Get_Num_RNAfolds( $name, $state->{$slot}->{genome_id}, $slipsite_start );
  my $id;
  if ( $folds > 0 ) {    ## Then there are folds in the db
    ## I could grab the mfe id now to check the boot table...
    print "Check $name - already done: state: $state->{$slot}->{pknots_mfe_id}\n";
  } else {               ## There are no existing folds
    if ( $name eq 'pknots' ) {
      my $pknots_info = $fold_search->Pknots_Condor();
      $id = $db->Put_Pknots($pknots_info);
      $state->{pknots_mfe_id} = $id;
    } elsif ( $name eq 'nupack' ) {
      my $nupack_info = $fold_search->Nupack_Condor();
      $id = $db->Put_Nupack($nupack_info);
      $state->{nupack_mfe_id} = $id;
    }
  }
  return ($id);
}

## Start Check_Sequence_Length
sub Check_Sequence_Length {
  my $slot                   = shift;
  my $filename               = $state->{$slot}->{fasta_file};
  my $sequence               = $state->{$slot}->{sequence};
  my @seqarray               = split( //, $sequence );
  my $sequence_length        = $#seqarray;
  my $wanted_sequence_length = $config->{seqlength};
  open( IN, "<$filename" ) or die("Check_Sequence_Length: Couldn't open $filename $!");
  ## OPEN IN in Check_Sequence_Length
  my $output = '';
  my @out    = ();
  while ( my $line = <IN> ) {
    chomp $line;
    if ( $line =~ /^\>/ ) {
      $output .= $line;
    } else {
      my @tmp = split( //, $line );
      push( @out, @tmp );
    }
  }
  close(IN);
  ## CLOSE IN in Check_Sequence Length
  my $current_length = scalar(@out);
  if ( !defined($sequence) or $sequence eq '' ) {
    return ('null');
  }
  if ( $sequence =~ /^a+$/ ) {
    return ('polya');
  } elsif ( $sequence =~ /aaaaaaaaaa$/ and $sequence_length < $wanted_sequence_length ) {
    return ('polya');
  } elsif ( $sequence_length > $wanted_sequence_length ) {
    open( OUT, ">$filename" ) or die("Could not open $filename $!");
    ## OPEN OUT in Check_Sequence_Length
    print OUT "$output\n";
    foreach my $char ( 0 .. $sequence_length ) {
      print OUT $out[$char];
    }
    print OUT "\n";
    close(OUT);
    ## CLOSE OUT in Check_Sequence_Length
    return ('longer than wanted');
  } elsif ( $sequence_length == $wanted_sequence_length ) {
    return ('good');
  } elsif ( $sequence_length < $wanted_sequence_length ) {
    return ('shorter than wanted');
  } else {
    return ('unknown');
  }
}
## End Check_Sequence_length
