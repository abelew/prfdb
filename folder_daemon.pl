#! /usr/bin/perl -w
use strict;
use POSIX;
use DBI;

use lib 'lib';
use PRFdb;
use RNAMotif_Search;
use RNAFolders;

my $config = {
			db => 'atbprfdb',
			host => 'localhost',
			user => 'trey',
			pass => 'Iactilm2',
			};

$ENV{EFNDATA} = "/usr/local/bin/efndata";

my $directory = '/home/trey/browser';
my $time_to_die = 0;
chroot($directory) or die "Could not change directory into $directory: $!\n";

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
  if (defined($datum->{species})) {
	print "Line 47\n";
	my $existsp = Check_Db($datum);
	print "Line 49\n";
  }
  else {
	sleep(2);
  }
}

sub Check_Queue {
  my $return = {};
  open (FH, "+<queue") or die "can't update queue: $!";
  my $addr= undef;
  while ( my $line = <FH> ) {
	if (eof(FH)) {
	  my ($species, $accession) = split(/\t/, $line);
	  print "TEST: $species\n";
	  $return->{species} = $species;
	  $return->{accession} = $accession;
	  truncate(FH, $addr) if (defined($addr));
	}
	else {
	  $addr = tell(FH);
	}
  }
  print "Line 68\n";
  return($return);
}

sub Check_Db {
  my $datum = shift;
  print "Line 78\n";
  my $db = new PRFdb;
  print "Line 80\n";
  my $motifs = new RNAMotif_Search;
  ## First see that there is rna motif information
  print "Line 81\n";
  my $info = $db->Get_RNAmotif($datum->{species}, $datum->{accession});
  if ($info) {  ## If the motif information _does_ exist, check the folding information
	foreach my $start (keys %{$info}) {
	  my $folding = $db->Get_RNAfolds($datum->{species}, $datum->{accession}, $start);
	  if ($folding) {  ## Both have motif and folding
		return(1);
	  }
	  else {  ## Do have a motif for the sequence, do not have folding information
		return(0);
	  }
	} ## End recursing over the starts in a given sequence
  }  ## End if there is a motif for this sequence
  else {  ## Do not have motif nor folding
	my $sequence = $db->Get_Sequence($datum->{species}, $datum->{accession});
	my $slipsites = $motifs->Search($datum->{sequence});
	$db->Put_RNAmotif($datum->{species}, $datum->{accession}, $slipsites);
  }
}
sub signal_handler {
  $time_to_die = 1;
}

