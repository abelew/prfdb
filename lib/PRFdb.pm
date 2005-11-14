package PRFdb;
use strict;
use DBI;
use PRFConfig qw / PRF_Error PRF_Out /;
use SeqMisc;
use File::Temp qw / tmpnam /;
use Fcntl ':flock'; # import LOCK_* constants
use Bio::DB::Universal;
#use Bio::DB::GenBank;

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

sub Get_All_Sequences {
  my $me = shift;
  my $species = shift;
  my $table = 'genome_' . $species;
  my $statement = "SELECT accession, sequence from $table";
  my $sth = $me->{dbh}->prepare($statement);
  return($sth);
}

sub Keyword_Search {
  my $me = shift;
  my $species = shift;
  my $keyword = shift;
  my $table = 'genome_' . $species;
  my $statement = qq(SELECT accession, comment FROM $table WHERE comment like '%$keyword%' ORDER BY accession);
  my $dbh = $me->{dbh};
  my $info = $dbh->selectall_arrayref($statement);
  my $return = {};
  foreach my $accession (@{$info}) {
    my $accession_id = $accession->[0];
    my $accession_comment = $accession->[1];
    $return->{$accession_id} = $accession_comment;
  }
  return($return);
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

####
### Get and Set Nupack data
####
sub Get_Nupack {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $start  = shift;
  PRFConfig::PRF_Error("Undefined value in Get_Nupack", $species, $accession) unless (defined($species) and defined($accession));
  my $table = 'nupack_' . $species;
  my $statement;
  if (defined($start)) {
    $statement = qq(SELECT * FROM $table WHERE accession='$accession' AND start='$start' ORDER BY start);
  }
  else {
    $statement = qq(SELECT * from $table where accession='$accession' ORDER BY start);
  }
  my $dbh = $me->{dbh};
  my $info = $dbh->selectall_hashref($statement, 1);
  return($info);
}

sub Put_Nupack {
  my $me = shift;
  my $data = shift;
  my $table = 'nupack_' . $data->{species};
  PRFConfig::PRF_Error("Undefined value in Put_Nupack", $data->{species}, $data->{accession}) unless(defined($data->{start}) and defined($data->{slippery}) and defined($data->{seqlength}) and defined($data->{sequence}) and defined($data->{paren_output}) and defined($data->{parsed}) and defined($data->{mfe}) and defined($data->{knotp}));
  my $statement = qq(INSERT INTO $table (id, accession, start, slipsite, seqlength, sequence, paren_output, parsed, mfe, knotp) VALUES ('', '$data->{accession}', '$data->{start}', '$data->{slippery}', '$data->{seqlength}', '$data->{sequence}', '$data->{paren_output}', '$data->{parsed}', '$data->{mfe}', '$data->{knotp}'));
#  print "NUPACK: $statement\n";
  if ($PRFConfig::config->{dboutput} eq 'dbi') {
	my $sth = $me->{dbh}->prepare($statement);
	$sth->execute();
  }
  else {
	print DBOUT "$statement\n";
  }
}

####
### Get and Set Pknots data
####
sub Get_Pknots {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $table = 'pknots_' . $species;
  my $statement = qq(SELECT * from $table where accession='$accession');
  my $dbh = $me->{dbh};
  my $info = $dbh->selectall_hashref($statement, 'id');
  return($info);
}

sub Put_Pknots {
  my $me = shift;
  my $data = shift;
  my $table = 'pknots_' . $data->{species};
#  PRFConfig::PRF_Error("Undefined value in Put_Pknots", $data->{species} $data->{accession}) unless(defined($data->{start}) and defined($data->{slippery}) and defined($data->{pk_output}) and defined($data->{parsed}) and defined($data->{mfe}) and defined($data->{pairs}) and defined($data->{knotp}));
  my $statement = qq(INSERT INTO $table (id, accession, start, slipsite, pk_output, parsed, mfe, pairs, knotp) VALUES ('', '$data->{accession}', '$data->{start}', '$data->{slippery}', '$data->{pk_output}', '$data->{parsed}', '$data->{mfe}', '$data->{pairs}', '$data->{knotp}'));

#  my $statement = qq(INSERT INTO $table (id, accession, start, slipsite, logodds, mfe, pairs, output, parsed) VALUES ('', '$data->{accession}', '$data->{start}', '$data->{slippery}', '$data->{logodds}', '$data->{mfe}', '$data->{pairs}', '$data->{pkout}', '$data->{parsed}'));
  if ($PRFConfig::config->{dboutput} eq 'dbi') {
      my $sth = $me->{dbh}->prepare($statement);
      $sth->execute();
  }
  else {
	print DBOUT "$statement\n";
  }
}

####
### Get and Set Bootstrap data
####
sub Get_Boot {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $start = shift;
  PRFConfig::PRF_Error("Undefined value in Get_Boot", $species, $accession) unless (defined($species) and defined($accession));
  my $table = 'boot_' . $species;
  my $statement;
  if (defined($start)) {
    $statement = qq(SELECT * FROM $table WHERE accession='$accession' AND start='$start' ORDER BY start);
  }
  else {
    $statement = qq(SELECT * from $table where accession='$accession' ORDER BY start);
  }
  my $dbh = $me->{dbh};
  my $info = $dbh->selectall_hashref($statement, 1);
  return($info);
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
      my $mfe_values = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_values};

      my $statement = qq(INSERT INTO $table (id, accession, start, iterations, rand_method, mfe_method, mfe_mean, mfe_sd, mfe_se, pairs_mean, pairs_sd, pairs_se, mfe_values) VALUES ('', '$data->{accession}', '$data->{start}', '$num_iterations', '$rand_method', '$mfe_method', '$mfe_mean', '$mfe_sd', '$mfe_se', '$pairs_mean', '$pairs_sd', '$pairs_se', '$mfe_values'));
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

####
### Get and Set motif data
####
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

sub Put_RNAmotif {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $slipsites_data = shift;
  my $table = "rnamotif_" . $species;
  if (scalar %{$slipsites_data} eq '0') {
    my $statement = qq(INSERT INTO $table (id, accession, start, total, permissable, filedata, output) VALUES ('', '$accession', '', '', '', '', ''));
    if ($PRFConfig::config->{dboutput} eq 'dbi') {
      my $sth = $me->{dbh}->prepare($statement);
      $sth->execute();
    }
    else { print DBOUT "$statement\n"; }
  }
  else {  ## There are some keys to play with
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
      else { print DBOUT "$statement\n"; } ## End checking on the type of db connection
    } ## End looking at every slipsite for a locus
  }  ## End checking for a null set
}  ## End Put_RNAMotif

sub Get_Slippery_From_Sequence {
  my $me = shift;
  my $sequence = shift;
  my $start = shift;
  my @reg = split(//, $sequence);
  my $slippery = "$reg[$start]" . "$reg[$start+1]" . "$reg[$start+2]" . "$reg[$start+3]" . "$reg[$start+4]" . "$reg[$start+5]" . "$reg[$start+6]";
  return($slippery);
}

sub Error_Db {
  my $me = shift;
  my $message = shift;
  my $species = shift;
  my $accession = shift;
  $species = '' if (!defined($species));
  $accession = '' if (!defined($accession));
  my $statement = qq(INSERT into errors VALUES('', now(), '$message', '$species', '$accession'));
  my $sth = $me->{dbh}->prepare($statement);
  $sth->execute();
}

sub Get_Pubqueue {
  my $me = shift;
  my $return;
  my $statement = qq(SELECT accession FROM queue WHERE public='1' and  out='0');
  my $accessions = $me->{dbh}->selectall_arrayref($statement);
  return($accessions);
}

sub Set_Pubqueue {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $params = shift;
  my $statement = qq(INSERT INTO queue (id, public, species, accession, params, out, done) VALUES ('', '0', '$species', '$accession', '', 0, 0));
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute or PRFConfig::PRF_Error("Could not execute \"$statement\" in Set_Pubqueue");
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
  $sth->execute or PRFConfig::PRF_Error("Could not execute statement: $statement in Create_Genome");
}

sub Drop_All {
  my $me = shift;
  my $genus_species = shift;
  my @tables = ('genome_', 'rnamotif_', 'pknots_', 'nupack_');
  foreach my $tab (@tables) {
	my $t_name = $tab . $genus_species;
	my $statement = "DROP table $t_name";
	my $sth = $me->{dbh}->prepare("$statement");
	$sth->execute or PRFConfig::PRF_Error("Could not execute \"$statement\" in Drop_All");
  }
}

sub Drop_Table {
  my $me = shift;
  my $type = shift;
  my $table = $type . '_' . $PRFConfig::config->{species};
  my $statement = "DROP table $table";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute or PRFConfig::PRF_Error("Could not execute statement: $statement in Create_Genome");
}

sub Create_Genome {
  my $me = shift;
  my $table = 'genome_' . $PRFConfig::config->{species};
  my $statement = "CREATE table $table  (accession varchar(16) not null, genename varchar(20), version int, comment blob not null, sequence blob not null, primary key (accession))";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute or die("Could not execute statement: $statement in Create_Genome");
}

sub Create_Boot {
  my $me = shift;
  my $table = 'boot_' . $PRFConfig::config->{species};
  my $statement = "CREATE table $table (id int not null auto_increment, accession varchar(10) not null, start int, iterations int, rand_method varchar(20), mfe_method varchar(20), mfe_mean float, mfe_sd float, mfe_se float, pairs_mean float, pairs_sd float, pairs_se float, mfe_values blob, primary key(id))";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute or die("Could not execute statement: $statement in Create_Genome");
}

sub Create_Pknots {
  my $me = shift;
  my $tablename = 'pknots_' . $PRFConfig::config->{species};
  my $statement = "CREATE table $tablename (id int not null auto_increment, accession varchar(80), start int, slipsite char(7), pk_output blob, parsed blob, mfe float, pairs int, knotp bool, primary key(id))";
#  my $statement = "CREATE table $tablename (id int not null auto_increment, process varchar(80), start int, length int, struct_start int, logodds float, mfe float, cor_mfe float, pairs int, pseudop tinyint, slipsite varchar(80), spacer varchar(80), sequence blob, structure blob, parsed blob, primary key (id))";
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
  my $statement = "CREATE table $tablename (id int not null auto_increment, public bool, species varchar(40), accession varchar(80), params blob, out bool, done bool, primary key (id))";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute;
}

sub Create_Errordb {
  my $me = shift;
  my $tablename = 'errors';
  my $statement = "CREATE table $tablename (id int not null auto_increment, time timestamp, message blob, species varchar(80), accession varchar(80), primary key(id))";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute;
}

sub FillQueue {
  my $me = shift;
  my $species = $PRFConfig::config->{species};
  my $best_statement = "INSERT into queue (id, public, species, accession, params, out, done) SELECT '', 0, species, accession, '', 0, 0 from genome";
#  my $collection = "SELECT 'homo_sapiens', accession from $collect_table";
  my $sth = $me->{dbh}->prepare($best_statement);
  $sth->execute;
}

sub Grab_Queue {
  my $me = shift;
  my $type = shift;  ## public or private
  $type = ($type eq 'public' ? 1 : 0);
  my $return;
  my $single_accession = qq(select species, accession from queue where public='$type' and  out='0' ORDER BY rand() LIMIT 1);
#  my $single_accession = qq(select species, accession from queue where species='homo_sapiens' and accession='BC064626' ORDER BY rand() LIMIT 1);
  my ($species, $accession) = $me->{dbh}->selectrow_array($single_accession);
  return(undef) unless(defined($species));
  my $update = qq(UPDATE queue SET out='1' WHERE species='$species' and accession='$accession' and public='$type');
  my $st = $me->{dbh}->prepare($update);
  $st->execute();
  $return->{species} = $species;
  $return->{accession} = $accession;
  return($return);
}

sub Load_Genome_Table {
  my $me = shift;
  if ($PRFConfig::config->{input} =~ /gz$/ or $PRFConfig::config->{input} =~ /Z$/) {
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
      my ($accession, $version);
      if ($accession_version =~ m/\./) {
	  ($accession, $version) = split(/\./, $accession_version);
      }
      else {
	  $accession = $accession_version;
	  $version = '0';
      }
      $datum{accession} = $accession;
      $datum{version} = $version;
      $datum{comment} = $comment;
    }  ## The mgc genomes
    else {
	$datum{sequence} .= $line;
    }   ## Non accession line
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

################################################3
### Everything below here is for the 05 tables
################################################

## ORF data by definition starts at position 1 and ends at the end of the sequence
sub Load_ORF_Data {
  my $me = shift;
  my $species = shift;
  my $misc = new SeqMisc;
  if ($PRFConfig::config->{input} =~ /gz$/ or $PRFConfig::config->{input} =~ /Z$/) {
	open(IN, "$PRFConfig::config->{zcat} $PRFConfig::config->{input} |") or die "Could not open the fasta file\n $!\n";
  }
  else {
	open(IN, "<$PRFConfig::config->{input}") or die "Could not open the fasta file\n $!\n";
  }
  my %datum = (
               accession => undef,
               species => undef,
               genename => undef,
               version => undef,
               comment => undef,
               mrna_seq => undef,
               protein_seq => undef,
               orf_start => undef,
               orf_stop => undef,
               );
  while(my $line = <IN>) {
    chomp $line;
    ### A comment line from the SGD
    ### >ORFN:YAL001C TFC3 SGDID:S0000001, Chr I from 147595-147664,147755-151167, reverse complement
    if ($line =~ /^\>ORFN/) {  ## If it is one of the kooky yeast genomes
      if (defined($datum{accession})) {
        $datum{protein_seq} = $misc->Translate($datum{mrna_seq});
        $datum{orf_start} = 1;
        $datum{orf_stop} = length($datum{mrna_seq});
        print "Submitting $datum{accession}\n";
        if (!defined($me->Get_Sequence05($datum{species}, $datum{accession}))) {
          $me->Insert_Genome05_Entry(\%datum);
          %datum = (
                    accession => undef,
                    species => undef,
                    genename => undef,
                    version => undef,
                    comment => undef,
                    mrna_seq => undef,
                    protein_seq => undef,
                    orf_start => undef,
                    orf_stop => undef,
               );
        }
      }
      if (!defined($species)) { $species = 'saccharomyces_cerevisiae'; }
      my @information = split(/\,/, $line);
      my $identifier = shift @information;
      my ($orfname, $genename, $accession) = split(/\s+/, $identifier);
      $orfname =~ s/\>ORFN\://g;
      $genename = join(" ", $orfname, $genename);
      my $comment = join(",", @information);
      $datum{accession} = $accession;
      $datum{genename} = $genename;
      $datum{comment} = $comment;
      $datum{species} = $species;
    }  ## End if it is a kooky yeast genome.
#    elsif ($line =~ /^\>/) {
#      if (defined($datum{accession})) {
#        $me->Insert_Genome_Entry(\%datum);
#      }
#      my ($gi, $id, $gb, $accession_version, $comment) = split(/\|/, $line);
#      my ($accession, $version);
#      if ($accession_version =~ m/\./) {
#	  ($accession, $version) = split(/\./, $accession_version);
#      }
#      else {
#	  $accession = $accession_version;
#	  $version = '0';
#      }
#      $datum{accession} = $accession;
#      $datum{version} = $version;
#      $datum{comment} = $comment;
#    }  ## The mgc genomes
      else {
        $datum{mrna_seq} .= $line;
    }   ## Non accession line
  }  ## End every line
    $datum{protein_seq} = $misc->Translate($datum{mrna_seq});
  print "Submitting $datum{accession}\n";
    $me->Insert_Genome05_Entry(\%datum);  ## Get the last entry into the database.
}

sub Import_CDS {
  my $me = shift;
  my $accession = shift;
  my $uni = new Bio::DB::Universal;
  my $seq = $uni->get_Seq_by_id($accession);

#  my @features = $seq->all_SeqFeatures();
  my @cds      = grep { $_->primary_tag eq 'CDS' } $seq->get_SeqFeatures();
  my ($protein_sequence, $orf_start, $orf_stop);
  my $counter = 0;
  foreach my $feature (@cds) {
    if ($counter > 1) {
      die("HOLY SHIT MORE THAN 1 CDS!");
    }
    $counter++;
    my $primary_tag = $feature->primary_tag();
    $protein_sequence =  $feature->seq->translate->seq();
    $orf_start = $feature->start();
    ### Don't change me, this is provided by genbank
    $orf_stop = $feature->end();
  }
  my $binomial_species = $seq->species->binomial();
  my ($genus, $species) = split(/ /, $binomial_species);
  my $full_species = qq(${genus}_${species});
  $full_species =~ tr/[A-Z]/[a-z]/;
  $PRFConfig::config->{species} = $full_species;
  my $full_comment = $seq->desc();
  my ($genename, $desc) = split(/\,/, $full_comment);
  my $mrna_sequence = $seq->seq();

  my %datum = (
               accession => $accession,
               mrna_seq => $mrna_sequence,
               protein_seq => $protein_sequence,
               orf_start => $orf_start,
               orf_stop => $orf_stop,
               species => $full_species,
               genename => $genename,
               version => $seq->{_seq_version},
               comment => $full_comment,
              );
#  foreach my $k (keys %datum) {
#    print "TEST: $k and $datum{$k}\n";
#  }
  $me->Insert_Genome05_Entry(\%datum);
}

sub mRNA_subsequence {
  my $me = shift;
  my $sequence = shift;
  my $start = shift;
  my $stop = shift;
  $start--;
  $stop--;
  my @t = split(//, $sequence);
  my $orf_sequence;
  foreach my $c ($start .. $stop) {
    $orf_sequence .= $t[$c];
  }
  return($orf_sequence);
}

sub Import_Accession {
  my $me = shift;
  my $accession = shift;
  my $uni = new Bio::DB::Universal;
  my $seq = $uni->get_Seq_by_id($accession);
  my $binomial_species = $seq->species->binomial();
  my ($genus, $species) = split(/ /, $binomial_species);
  my $full_species = qq(${genus}_${species});
  $full_species =~ tr/[A-Z]/[a-z]/;
  $PRFConfig::config->{species} = $full_species;
  my $full_comment = $seq->desc();
  my ($genename, $desc) = split(/\,/, $full_comment);

  my %datum = (
               accession => $accession,
               sequence => $seq->seq(),
               species => $full_species,
               genename => $genename,
               version => $seq->{_seq_version},
               comment => $full_comment,
              );
  if (! $me->Check_Genome_Table($full_species)) {
    $me->Create_Genome($full_species);
  }
  $me->Insert_Genome_Entry(\%datum);
}

sub Check_Genome_Table {
  my $me = shift;
  my $species = shift;
  my $table = 'genome_' . $species;
  my $statement = "SHOW TABLES like '$table'";
  my $dbh = $me->{dbh};
  my $info = $dbh->selectall_arrayref($statement);
  if (scalar(@{$info}) == 0) {
    return(0);
  }
  else {
    return(1);
  }
}

#################################################
### Get RNAMotif Nupack Pknots Boot Sequence
#################################################
sub Get_Sequence05 {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $statement = qq(SELECT mrna_seq FROM genome WHERE accession = '$accession' and species = '$species');
  my $info = $me->{dbh}->selectall_arrayref($statement);
  my $sequence = $info->[0]->[0];
  if ($sequence) {
	return($sequence);
  }
  else {
	return(undef);
  }
}

sub Get_RNAfolds05 {
  my $me = shift;
  my $table = shift;
  my $species = shift;
  my $accession = shift;
  my $return = {};
  my $statement = "SELECT count(id) FROM $table WHERE accession = '$accession' and species='$species'";
  my $dbh = $me->{dbh};
  my $info = $dbh->selectall_arrayref($statement);
  my $count = $info->[0]->[0];
  return($count);
}

sub Get_RNAmotif05 {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $return = {};
  my $statement = "SELECT total, start, permissable, filedata, output FROM rnamotif WHERE accession = '$accession' and species='$species'";
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

sub Get_mRNA05 {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $statement = qq(SELECT mrna_seq, orf_start, orf_stop FROM genome WHERE species='$species' and accession='$accession');
#  my $info = $me->{dbh}->selectall_arrayref($statement);
  my $info = $me->{dbh}->selectrow_hashref($statement);
#  my $sequence = $info->[0]->[0];
  my $mrna_seq = $info->{mrna_seq};
  if ($mrna_seq) {
	return($mrna_seq);
  }
  else {
	return(undef);
  }
}

sub Get_ORF05 {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $statement = qq(SELECT mrna_seq, orf_start, orf_stop FROM genome WHERE species='$species' and accession='$accession');
#  my $info = $me->{dbh}->selectall_arrayref($statement);
  my $info = $me->{dbh}->selectrow_hashref($statement);
#  my $sequence = $info->[0]->[0];
  my $mrna_seq = $info->{mrna_seq};
  ### A PIECE OF CODE TO HANDLE PULLING SUBSEQUENCES FROM CDS
  my $start = $info->{orf_start} - 1;
  my $stop = $info->{orf_stop} - 1;
  my $offset = $stop - $start;
  my $sequence = substr($mrna_seq, $start, $offset);
  ### DONT SCAN THE ENTIRE MRNA, ONLY THE ORF
  if ($sequence) {
	return($sequence, $start);
  }
  else {
	return(undef);
  }
}

sub Get_Slippery_From_RNAMotif {
  my $me = shift;
  my $filename = shift;
  open(IN, "<$filename");
  while(my $line = <IN>) {
      chomp $line;
      if ($line =~ /^\>/) {
	  my ($slippery, $crap) = split(/ /, $line);
	  $slippery =~ s/\>//g;
	  return($slippery);
      }
  }
  return(undef);
}


#################################################
### Put RNAMotif, Nupack, Pknots, Boot, Genome
#################################################
sub Insert_Genome05_Entry {
  my $me = shift;
  my $datum = shift;
  my $qa = $me->{dbh}->quote($datum->{accession});
  my $qsp = $me->{dbh}->quote($datum->{species});
  my $qn = $me->{dbh}->quote($datum->{genename});
  my $qv = $me->{dbh}->quote($datum->{version});
  my $qc = $me->{dbh}->quote($datum->{comment});
  my $qs = $me->{dbh}->quote($datum->{mrna_seq});
  my $qp = $me->{dbh}->quote($datum->{protein_seq});
  my $qos = $me->{dbh}->quote($datum->{orf_start});
  my $qoe = $me->{dbh}->quote($datum->{orf_stop});
  my $statement = "INSERT INTO genome (id, accession, species, genename, version, comment, mrna_seq, protein_seq, orf_start, orf_stop) VALUES('', $qa, $qsp, $qn, $qv, $qc, $qs, $qp, $qos, $qoe)";
  $datum->{sequence} = undef;
#  print "TEST: $statement\n";
  my $sth = $me->{dbh}->prepare($statement);
  $sth->execute;
}

sub Put_RNAmotif05 {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $slipsites_data = shift;
  if (scalar %{$slipsites_data} eq '0') {
    my $statement = qq(INSERT INTO rnamotif (id, species, accession, start, total, permissable, filedata, output) VALUES ('', '$species', '$accession', '', '', '', '', ''));
    if ($PRFConfig::config->{dboutput} eq 'dbi') {
      my $sth = $me->{dbh}->prepare($statement);
      $sth->execute();
    }
    else { print DBOUT "$statement\n"; }
  }
  else {  ## There are some keys to play with
    foreach my $start (keys %{$slipsites_data}) {
      my $total = $slipsites_data->{$start}{total};
      my $permissable = $slipsites_data->{$start}{permissable};
      my $filename = $slipsites_data->{$start}{filename};
      my $filedata = $slipsites_data->{$start}{filedata};
      my $output = $slipsites_data->{$start}{output};
      my $statement = qq(INSERT INTO rnamotif (id, species, accession, start, total, permissable, filedata, output) VALUES ('', '$species', '$accession', '$start', '$total', '$permissable', '$filedata', '$output'));
      #    print "RNAMOTIF: $statement\n";
      if ($PRFConfig::config->{dboutput} eq 'dbi') {
        my $sth = $me->{dbh}->prepare($statement);
        $sth->execute();
      }
      else { print DBOUT "$statement\n"; } ## End checking on the type of db connection
    } ## End looking at every slipsite for a locus
  }  ## End checking for a null set
}  ## End Put_RNAMotif05

sub Put_Nupack05 {
  my $me = shift;
  my $data = shift;
  PRFConfig::PRF_Error("Undefined value in Put_Nupack05", $data->{species}, $data->{accession}) unless(defined($data->{start}) and defined($data->{slippery}) and defined($data->{seqlength}) and defined($data->{sequence}) and defined($data->{paren_output}) and defined($data->{parsed}) and defined($data->{mfe}) and defined($data->{knotp}));
  my $statement = qq(INSERT INTO nupack (id, species, accession, start, slipsite, seqlength, sequence, paren_output, parsed, mfe, pairs, knotp) VALUES ('', '$data->{species}', '$data->{accession}', '$data->{start}', '$data->{slippery}', '$data->{seqlength}', '$data->{sequence}', '$data->{paren_output}', '$data->{parsed}', '$data->{mfe}', '$data->{pairs}', '$data->{knotp}'));
#  print "NUPACK: $statement\n";
  if ($PRFConfig::config->{dboutput} eq 'dbi') {
	my $sth = $me->{dbh}->prepare($statement);
	$sth->execute();
  }
  else {
	print DBOUT "$statement\n";
  }
}  ## End of Put_Nupack05

sub Put_Pknots05 {
  my $me = shift;
  my $data = shift;
  my $statement = qq(INSERT INTO pknots (id, species, accession, start, slipsite, pk_output, parsed, mfe, pairs, knotp) VALUES ('', '$data->{species}', '$data->{accession}', '$data->{start}', '$data->{slippery}', '$data->{pk_output}', '$data->{parsed}', '$data->{mfe}', '$data->{pairs}', '$data->{knotp}'));
  if ($PRFConfig::config->{dboutput} eq 'dbi') {
      my $sth = $me->{dbh}->prepare($statement);
      $sth->execute();
  }
  else {
	print DBOUT "$statement\n";
  }
}

sub Put_Boot05 {
  my $me = shift;
  my $data = shift;
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
      my $mfe_values = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_values};

      my $statement = qq(INSERT INTO boot (id, species, accession, start, iterations, rand_method, mfe_method, mfe_mean, mfe_sd, mfe_se, pairs_mean, pairs_sd, pairs_se, mfe_values) VALUES ('', '$data->{species}', '$data->{accession}', '$data->{start}', '$num_iterations', '$rand_method', '$mfe_method', '$mfe_mean', '$mfe_sd', '$mfe_se', '$pairs_mean', '$pairs_sd', '$pairs_se', '$mfe_values'));
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

#################################################
### Functions used to create the prfdb05 tables
#################################################
sub Create_Genome05 {
  my $me = shift;
  my $table = 'genome';
  my $statement = "CREATE table $table (
id $PRFConfig::config->{mysql_id},
accession $PRFConfig::config->{mysql_accession},
species $PRFConfig::config->{mysql_species},
genename $PRFConfig::config->{mysql_genename},
version int,
comment $PRFConfig::config->{mysql_comment},
mrna_seq text not null,
protein_seq text,
orf_start int,
orf_stop int,
primary key (id),
UNIQUE(accession),
INDEX(genename))";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute or die("Could not execute statement: $statement in Create_Genome");
}

sub Create_Rnamotif05 {
  my $me = shift;
  print "TESTTHIS: $PRFConfig::config->{mysql_index}\n";
  sleep(5);
  my $statement = "CREATE table rnamotif (
id $PRFConfig::config->{mysql_index},
species $PRFConfig::config->{mysql_species},
accession $PRFConfig::config->{mysql_accession},
start int,
total int,
permissable int,
filedata blob,
output blob,
lastupdate $PRFConfig::config->{mysql_timestamp},
primary key (id))";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute;
}

sub Create_Queue05 {
  my $me = shift;
  my $tablename = 'queue';
  my $statement = "CREATE table $tablename (
id $PRFConfig::config->{mysql_index},
public bool,
species $PRFConfig::config->{mysql_species},
accession $PRFConfig::config->{mysql_accession},
params blob,
out bool,
done bool,
primary key (id))";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute;
}

sub Create_Nupack05 {
  my $me = shift;
  my $statement = "CREATE TABLE nupack (
id $PRFConfig::config->{mysql_index},
species $PRFConfig::config->{mysql_species},
accession $PRFConfig::config->{mysql_accession},
start int,
slipsite char(7),
seqlength int,
sequence char(200),
paren_output char(200),
parsed blob,
mfe float,
pairs int,
knotp bool,
lastupdate $PRFConfig::config->{mysql_timestamp},
primary key(id))";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute;
}

sub Create_Pknots05 {
  my $me = shift;
  my $statement = "CREATE TABLE pknots (
id $PRFConfig::config->{mysql_index},
species $PRFConfig::config->{mysql_species},
accession $PRFConfig::config->{mysql_accession},
start int,
slipsite char(7),
pk_output blob,
parsed blob,
mfe float,
pairs int,
knotp bool,
lastupdate $PRFConfig::config->{mysql_timestamp},
primary key(id))";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute;
}

sub Create_Boot05 {
  my $me = shift;
  my $statement = "CREATE TABLE boot (
id $PRFConfig::config->{mysql_index},
species $PRFConfig::config->{mysql_species},
accession $PRFConfig::config->{mysql_accession},
start int,
iterations int,
rand_method varchar(20),
mfe_method varchar(20),
mfe_mean float,
mfe_sd float,
mfe_se float,
pairs_mean float,
pairs_sd float,
pairs_se float,
mfe_values blob,
lastupdate $PRFConfig::config->{mysql_timestamp},
primary key(id))";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute or die("Could not execute statement: $statement in Create_Genome");
}

1;
