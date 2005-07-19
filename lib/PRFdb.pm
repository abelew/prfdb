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
                  user => $PRFConfig::config->{user},
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

sub Get_Mfold {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $start = shift;
  my $return;
  my $table = "mfold_$species";
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

sub Put_Boot {
  my $me = shift;
  my $data = shift;
  my $table = 'boot_' . $data->{species};
  foreach my $mfe_method (keys%{$PRFConfig::config->{boot_mfe_algorithms}}) {
  #foreach my $mfe_method (keys %{$data}) {
      foreach my $rand_method (keys %{$PRFConfig::config->{boot_randomizers}}) {
      #foreach my $rand_method (keys %{$data->{$mfe_method}}) {
      my $num_iterations = $data->{$mfe_method}->{$rand_method}->{stats}->{num_iterations};
      my $mfe_mean = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_mean};
      my $mfe_sd = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_sd};
      my $mfe_se = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_se};
      my $pairs_mean = $data->{$mfe_method}->{$rand_method}->{stats}->{pairs_mean};
      my $pairs_sd = $data->{$mfe_method}->{$rand_method}->{stats}->{pairs_sd};
      my $pairs_se = $data->{$mfe_method}->{$rand_method}->{stats}->{pairs_se};
      my $statement = qq(INSERT INTO $table (id, accession, start, iterations, rand_method, mfe_method, mfe_mean, mfe_sd, mfe_se, pairs_mean, pairs_sd, pairs_se) VALUES ('', '$data->{accession}', '$data->{start}', '$num_iterations', '$rand_method', '$mfe_method', '$mfe_mean', '$mfe_sd', '$mfe_se', '$pairs_mean', '$pairs_sd', '$pairs_se'));
      print "STATEMENTS: $statement\n";
      if ($PRFConfig::config->{dboutput} eq 'dbi') {

        my $sth = $me->{dbh}->prepare($statement);
        $sth->execute()
      }
      else {
        print DBOUT "$statement\n";
      } ## End if dboutput test
    }  ### Foreach random method
  } ## Foreach mfe method
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

###
### Admin functions below!
###
sub Clean_Table {
  my $me = shift;
  my $type = shift;
  my $table = $type . '_' . $PRFConfig::config->{species};
  my $statement = "DELETE from $table";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute or Error("Could not execute statement: $statement in Create_Genome");
}

sub Drop_All {
  my $me = shift;
  my $genus_species = shift;
  my @tables = ('genome_', 'rnamotif_', 'pknots_', 'nupack_');
  foreach my $tab (@tables) {
	my $t_name = $tab . $genus_species;
	my $statement = "DROP table $t_name";
	my $sth = $me->{dbh}->prepare("$statement");
	$sth->execute or Error("Could not execute Statement: $statement in Drop_All");
  }
}

sub Drop_Table {
  my $me = shift;
  my $type = shift;
  my $table = $type . '_' . $PRFConfig::config->{species};
  my $statement = "DROP table $table";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute or Error("Could not execute statement: $statement in Create_Genome");
}

sub Create_Genome {
  my $me = shift;
  my $table = 'genome_' . $PRFConfig::config->{species};
  my $statement = "CREATE table $table  (accession varchar(10) not null, genename varchar(20), version int, comment blob not null, sequence blob not null, primary key (accession))";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute or die("Could not execute statement: $statement in Create_Genome");
}

sub Create_Boot {
  my $me = shift;
  my $table = 'boot_' . $PRFConfig::config->{species};
  my $statement = "CREATE table $table (id int not null auto_increment, accession varchar(10) not null, start int, iterations int, rand_method varchar(20), mfe_method varchar(20), mfe_mean float, mfe_sd float, mfe_se float, pairs_mean float, pairs_sd float, pairs_se float, primary key(id))";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute or die("Could not execute statement: $statement in Create_Genome");
}

sub Create_Pknots {
  my $me = shift;
  my $tablename = 'pknots_' . $PRFConfig::config->{species};
  my $statement = "CREATE table $tablename (id int not null auto_increment, process varchar(80), start int, length int, struct_start int, logodds float, mfe float, cor_mfe float, pairs int, pseudop tinyint, slipsite varchar(80), spacer varchar(80), sequence blob, structure blob, parsed blob, primary key (id))";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute;
}

sub Create_Nupack {
  my $me = shift;
  my $tablename = 'nupack_' . $PRFConfig::config->{species};
  my $statement = "CREATE table $tablename (id int not null auto_increment, accession varchar(80), start int, slipsite char(7), seqlength int, sequence char(200), paren_output char(200), parsed blob, mfe float, knotp bool, primary key(id))";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute;
}

sub Create_Rnamotif {
  my $me = shift;
  my $tablename = "rnamotif_" . $PRFConfig::config->{species};
  my $statement = "CREATE table $tablename (id int not null auto_increment, accession varchar(80), start int, total int, permissable int, filedata blob, output blob, primary key (id))";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute;
}

sub Create_Queue {
  my $me = shift;
  my $tablename = 'queue';
  my $statement = "CREATE table $tablename (id int not null auto_increment, public bool, species varchar(20), accession varchar(80), params blob, out bool, done bool, primary key (id))";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute;
}

sub FillQueue {
  my $me = shift;
  my $species = $PRFConfig::config->{species};
  my $collect_table = 'genome_' . $species;
  my $best_statement = "INSERT into queue (id, public, species, accession, params, out, done) SELECT '', 0, '$species', accession, '', 0, 0 from $collect_table";
#  my $collection = "SELECT 'homo_sapiens', accession from $collect_table";
  my $sth = $me->{dbh}->prepare($best_statement);
  $sth->execute;
}

sub Grab_Queue {
  my $me = shift;
  my $type = shift;  ## public or private
  $type = ($type eq 'public' ? 1 : 0);
  my $return;
  my $single_accession = qq(select species, accession from queue where public='$type' and  out='0' limit 1);
  my ($species, $accession) = $me->{dbh}->fetchrow_array($single_accession);
  return(undef) unless(defined($species));
  my $update = qq(UPDATE queue SET out='1' WHERE species='$species' and accession='$accession' and public='$type');
  print "UPDATE is: $update\n";
  my $st = $me->{dbh}->prepare($update);
  $st->execute();
  $return->{species} = $species;
  $return->{accession} = $accession;
  return($return);
}

sub Load_Genome_Table {
  my $me = shift;
  if ($PRFConfig::config->{input} =~ /gz$/) {
	open(IN, "$PRFConfig::config->{zcat} $PRFConfig::config->{input} |") or die "Could not open the fasta file\n $!\n";
  }
  else {
	open(IN, "<$PRFConfig::config->{input}") or die "Could not open the fasta file\n $!\n";
  }
  my %datum = (accession => undef, genename => undef, version => undef, comment => undef, sequence => undef);
  while(my $line = <IN>) {
	chomp $line;
	if ($line =~ /^\>ORFN/) {  ## If it is one of the kooky yeast genomes
	  if (defined($datum{accession})) {
		$me->Insert_Genome_Entry(\%datum);
	  }
	  my ($fake_accession, $comment) = split(/\,/, $line);
	  my ($accession, $genename) = split(/ /, $fake_accession);
	  $accession =~ s/^\>//g;
	  $datum{accession} = $accession;
	  $datum{genename} = $genename;
	  $datum{comment} = $comment;
	}  ## End if it is a kooky yeast genome.
	elsif ($line =~ /^\>/) {
		if (defined($datum{accession})) {
		  $me->Insert_Genome_Entry(\%datum);
		}
		my ($gi, $id, $gb, $accession_version, $comment) = split(/\|/, $line);
		my ($accession, $version) = split(/\./, $accession_version);
		$datum{accession} = $accession;
		$datum{version} = $version;
		$datum{comment} = $comment;
	  }  ## The mgc genomes
	else {
	  $datum{sequence} .= $line;
	}  ## Non accession line
  }  ## End every line
  $me->Insert_Genome_Entry(\%datum);  ## Get the last entry into the database.
}

sub Insert_Genome_Entry {
  my $me = shift;
  my $datum = shift;
  my $qa = $me->{dbh}->quote($datum->{accession});
  my $qn = $me->{dbh}->quote($datum->{genename});
  my $qv = $me->{dbh}->quote($datum->{version});
  my $qc = $me->{dbh}->quote($datum->{comment});
  my $qs = $me->{dbh}->quote($datum->{sequence});
  my $table = "genome_" . $PRFConfig::config->{species};
  my $statement = "INSERT INTO $table (accession, genename, version, comment, sequence) VALUES($qa, $qn, $qv, $qc, $qs)";
  $datum->{sequence} = undef;
#  print "TEST: $statement\n";
  my $sth = $me->{dbh}->prepare($statement);
  $sth->execute;
}

1;
