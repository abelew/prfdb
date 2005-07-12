package PRFdb;
use strict;
use DBI;
use PRFConfig;
use File::Temp qw / tmpnam /;
use Fcntl ':flock'; # import LOCK_* constants

sub new {
  my ($class, %arg) = @_;
  my $me = bless {
                  dsn => $PRFConfig::config->{dsn},
                 }, $class;
  $me->{dbh} = DBI->connect($me->{dsn}, $PRFConfig::config->{user}, $PRFConfig::config->{pass});
  unless ($PRFConfig::config->{dboutput} eq 'dbi') {
	open(DBOUT, ">>$PRFConfig::config->{dboutput}");
  }

  return ($me);
}

sub Get_Sequence {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $table = 'genome_' . $species;
  my $statement = qq(SELECT sequence FROM $table WHERE accession = '$accession');
  my $info = $me->{dbh}->selectall_arrayref($statement);
  my $sequence = $info->[0]->[0];
  if ($sequence) {
	return($sequence);
  }
  else {
	return(undef);
  }
}

sub Get_RNAfolds {
  my $me = shift;
  my $db = shift;
  my $species = shift;
  my $accession = shift;
  my $return = {};
  my $table = $db . '_' . $species;
  my $statement = "SELECT count(id) FROM $table WHERE accession = '$accession'";
  my $dbh = $me->{dbh};
  my $info = $dbh->selectall_arrayref($statement);
  my $count = $info->[0]->[0];
  return($count);
}

sub Get_RNAmotif {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $return = {};
  my $table = "rnamotif_$species";
  my $statement = "SELECT total, start, permissable, filedata, output FROM $table WHERE accession = '$accession'";
  my $dbh = $me->{dbh};
  my $info = $dbh->selectall_arrayref($statement);
#  return(0) if (scalar(@{$info}) == 0);
  return(0) if (scalar(@{$info}) == 0);
  my @data = @{$info};
  foreach my $start (@data) {
	my $total = $start->[0];
	my $st = $start->[1];
	my $permissable = $start->[2];
	my $filedata = $start->[3];
	my $output = $start->[4];
	$return->{$st}{total} = $total;
	$return->{$st}{start} = $st;
	$return->{$st}{permissable} = $permissable;
	$return->{$st}{filedata} = $filedata;
	$return->{$st}{output} = $output;
  }
  return($return);
}

sub Motif_to_Fasta {
  my $me = shift;
  my $data = shift;
  my $fh = MakeTempfile();
#  print "TEST: $data\n";
  print $fh $data;
  return($fh->filename);
}

sub MakeTempfile {
  my $fh = new File::Temp(DIR => $PRFConfig::config->{tmpdir},
                          TEMPLATE => 'slip_XXXXX',
                          UNLINK => 0,
                          SUFFIX => '.fasta');
  open(RECORDER, ">>recorder.txt");
#  flock(RECORDER, LOCK_EX);
  my $seconds = time();
  my $filename = $fh->filename;
  print RECORDER "$filename\t$seconds\n";
#  flock(RECORDER, LOCK_UN);
  close RECORDER;
  return($fh);
}

sub Remove_Old {
  my @files = ();
  open(RECORD, "<recorder.txt");
  open(TMP, ">recorder.tmp.txt");
#  flock(RECORD, LOCK_EX);
#  flock(TMP, LOCK_EX);
  while(my $line = <RECORD>) {
	chomp $line;
	my ($filename, $file_time) = split(/\t/, $line);
	my $current_time = time();
	if (($current_time - $file_time) > 7200) {
	  unlink($filename);
	}
	else {
	  print TMP $filename;
	}
  }
  close(RECORD);
  close(TMP);
#  flock(RECORD, LOCK_UN);
#  flock(TMP, LOCK_UN);
  rename("recorder.tmp.txt", "recorder.txt");
}

sub Remove_Tempfile {
  my $filename = shift;
  open(RECORD, "<recorder.txt");
  open(TMP, ">recorder.tmp.txt");
#  flock(RECORD, LOCK_EX);
#  flock(TMP, LOCK_EX);
  while(my $line = <RECORD>) {
	print TMP $line unless ($line =~ /^$filename/);
  }
  unlink $filename;
  close(RECORD);
  close(TMP);
  flock(RECORD, LOCK_UN);
  flock(TMP, LOCK_UN);
  rename("recorder.tmp.txt", "recorder.txt");
}

sub Put_Nupack {
  my $me = shift;
  my $data = shift;
  my $table = 'nupack_' . $data->{species};
  my $statement = qq(INSERT INTO $table (id, accession, start, slipsite, seqlength, sequence, paren_output, parsed, mfe, knotp) VALUES ('', '$data->{accession}', '$data->{start}', '$data->{slippery}', '$data->{seqlength}', '$data->{sequence}', '$data->{paren_output}', '$data->{parsed}', '$data->{mfe}', '$data->{knotp}'));
#  print "NUPACK: $statement\n";
  if ($PRFConfig::config->{dboutput} eq 'dbi') {
	my $sth = $me->{dbh}->prepare($statement);
	$sth->execute()
  }
  else {
	print DBOUT "$statement\n";
  }
}

sub Put_Pknots {
  my $me = shift;
  my $data = shift;
  my $table = 'pknots_' . $data->{species};
  my $statement = qq(INSERT INTO $table (id, accession, start, slipsite, logodds, mfe, pairs, output, parsed) VALUES ('', '$data->{accession}', '$data->{start}', '$data->{slippery}', '$data->{logodds}', '$data->{mfe}', '$data->{pairs}', '$data->{pkout}', '$data->{parsed}'));
  if ($PRFConfig::config->{dboutput} eq 'dbi') {
	my $sth = $me->{dbh}->prepare($statement);
	$sth->execute()
  }
  else {
	print DBOUT "$statement\n";
  }
}

sub Put_RNAmotif {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $slipsites_data = shift;
  my $table = "rnamotif_" . $species;
  foreach my $start (keys %{$slipsites_data}) {
    my $total = $slipsites_data->{$start}{total};
    my $permissable = $slipsites_data->{$start}{permissable};
    my $filename = $slipsites_data->{$start}{filename};
    my $filedata = $slipsites_data->{$start}{filedata};
    my $output = $slipsites_data->{$start}{output};
    my $statement = qq(INSERT INTO $table (id, accession, start, total, permissable, filedata, output) VALUES ('', '$accession', '$start', '$total', '$permissable', '$filedata', '$output'));
#    print "RNAMOTIF: $statement\n";
	if ($PRFConfig::config->{dboutput} eq 'dbi') {
	  my $sth = $me->{dbh}->prepare($statement);
	  $sth->execute();
	}
	else {
	  print DBOUT "$statement\n";
	}
  }
}

sub Get_Slippery {
  my $me = shift;
  my $sequence = shift;
  my $start = shift;
  my @reg = split(//, $sequence);
  my $slippery = "$reg[$start]" . "$reg[$start+1]" . "$reg[$start+2]" . "$reg[$start+3]" . "$reg[$start+4]" . "$reg[$start+5]" . "$reg[$start+6]";
  return($slippery);
}

1;
