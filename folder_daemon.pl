#! /usr/bin/perl -w
use strict;
use POSIX;
use DBI;

use lib 'lib';
use PRFdb;
use RNAMotif_Search;
use RNAFolders;
use Input;

my $config = {
			db => 'atbprfdb',
			host => 'localhost',
			user => 'trey',
			pass => 'Iactilm2',
			};

$ENV{EFNDATA} = "/usr/local/bin/efndata";

my $directory = '/home/trey/browser';
my $time_to_die = 0;
#chroot($directory) or die "Could not change directory into $directory: $!\n";

my $pid = fork;
exit if $pid;
die "Could not fork: $!\n" unless defined($pid);

POSIX::setsid() or die "Could not start a new process group: $!\n";

$SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signal_handler;

until ($time_to_die) {
  sleep(2);
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
  my $datum = Check_Queue();
  print "About to check $datum->{species}, $datum->{accession}\n";
  sleep(2);

  if (defined($datum->{species})) {
	my $existsp = Check_Db($datum);
  }
  else {
	sleep(2);
  }
}

sub Check_Queue {
  my $return = {};
  open (FH, "+<queue") or die "can't update queue: $!";
  my $addr= undef;
  my $line_bak;
  while (my $line = <FH> ) {
	$addr = tell(FH) unless eof(FH);
	$line_bak = $line;
  }
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
  my $info = $db->Get_RNAmotif($datum->{species}, $datum->{accession});
  if ($info) {  ## If the motif information _does_ exist, check the folding information
	foreach my $start (keys %{$info}) {
	  my $folding = $db->Get_RNAfolds($datum->{species}, $datum->{accession}, $start);
	  if ($folding) {  ## Both have motif and folding
		print "HAVE FOLDING AND MOTIF!\n";
		sleep(1);
		return(1);
	  }
	  else {  ## Do have a motif for the sequence, do not have folding information
		print "HAVE MOTIF, NO FOLDING\n";
		sleep(1);
		return(0);
	  }
	} ## End recursing over the starts in a given sequence
  }  ## End if there is a motif for this sequence
  else {  ## Do not have motif nor folding
	print "NO MOTIF, NO FOLDING\n";
	my $sequence = $db->Get_Sequence($datum->{species}, $datum->{accession});
	my $slipsites = $motifs->Search($sequence);
	$db->Put_RNAmotif($datum->{species}, $datum->{accession}, $slipsites);
	foreach my $start (keys %{$slipsites}) {
	  my $fold_search = new RNAFolders(file => $slipsites->{$start}{filename},
									   accession => $datum->{accession},
									   start => $slipsites->{$start}{start},
									   species => $datum->{species},);
	  print "About to start nupack with $slipsites->{$start}{filename}\n";
	  my $nupack_info = $fold_search->Nupack();
	  foreach my $k (keys %{$nupack_info}) {
		print "key: $k value: $nupack_info->{$k}\n";
	  }
	  $db->Put_Nupack($nupack_info);
	  unlink($slipsites->{$start}{filename});
	}  ## End of the foreach slipsite of a given locus
  }
}

sub signal_handler {
  $time_to_die = 1;
}
