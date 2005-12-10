package PRFdb;
use strict;
use DBI;
use PRFConfig qw / PRF_Error PRF_Out /;
use SeqMisc;
use File::Temp qw / tmpnam /;
use Fcntl ':flock'; # import LOCK_* constants
use Bio::DB::Universal;
#use Bio::DB::GenBank;

my $config = $PRFConfig::config;

sub new {
  my ($class, %arg) = @_;
  my $me = bless {
      dsn => $config->{dsn},
      user => $config->{user},
  }, $class;
  $me->{dbh} = DBI->connect($me->{dsn}, $config->{user}, $config->{pass});
  $me->Create_Genome() unless($me->Tablep('genome'));
  $me->Create_Queue() unless($me->Tablep('queue'));
  $me->Create_Rnamotif() unless($me->Tablep('rnamotif'));
  $me->Create_Pknots() unless($me->Tablep('pknots'));
  $me->Create_Nupack() unless($me->Tablep('nupack'));
  $me->Create_Boot() unless($me->Tablep('boot'));
  $me->Create_Analysis() unless($me->Tablep('analysis'));
  $me->Create_Errors() unless($me->Tablep('errors'));
  return ($me);
}

sub Get_All_Sequences {
  my $me = shift;
  my $statement = "SELECT accession, mrna_seq from genome";
  my $sth = $me->{dbh}->prepare($statement);
  return($sth);
}

sub Keyword_Search {
  my $me = shift;
  my $species = shift;
  my $keyword = shift;
  my $statement = qq(SELECT accession, comment FROM genome WHERE comment like '%$keyword%' ORDER BY accession);
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

sub Get_Mfold {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $start = shift;
  my $return;
  my $statement = "SELECT total, start, permissable, filedata, output FROM mfold WHERE accession = '$accession'";
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
  my $fh = new File::Temp(DIR => $config->{tmpdir},
                          TEMPLATE => 'slip_XXXXX',
                          UNLINK => 0,
                          SUFFIX => '.fasta');
}

####
### Get and Set Nupack data
####
sub Get_Nupack {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $start  = shift;
  PRF_Error("Undefined value in Get_Nupack", $species, $accession) unless (defined($species) and defined($accession));
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

####
### Get and Set Bootstrap data
####
sub Get_Boot {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $start = shift;
  PRF_Error("Undefined value in Get_Boot", $species, $accession) unless (defined($species) and defined($accession));
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

sub Get_Slippery_From_Sequence {
  my $me = shift;
  my $sequence = shift;
  my $start = shift;
  my @reg = split(//, $sequence);
  my $slippery = "$reg[$start]" . "$reg[$start+1]" . "$reg[$start+2]" . "$reg[$start+3]" . "$reg[$start+4]" . "$reg[$start+5]" . "$reg[$start+6]";
  return($slippery);
}

sub Id_to_AccessionSpecies {
  my $me = shift;
  my $id = shift;
  my $start  = shift;
  PRF_Error("Undefined value in Id_to_AccessionSpecies", $id) unless (defined($id));
  my $statement = qq(SELECT accession, species from genome where id='$id');
  my $dbh = $me->{dbh};
  my ($accession, $species) = $dbh->selectrow_array($statement);
  return([$accession, $species]);
}

sub Error_Db {
  my $me = shift;
  my $message = shift;
  my $species = shift;
  my $accession = shift;
  $species = '' if (!defined($species));
  $accession = '' if (!defined($accession));
  print "Error: '$message'\n";
  my $statement = qq(INSERT into errors VALUES('', now(), '$message', '$species', '$accession'));
  ## Don't call Execute here or you may run into circular crazyness
  my $sth = $me->{dbh}->prepare($statement);
  $sth->execute();
}

sub Get_Entire_Pubqueue {
  my $me = shift;
  my $return;
  my $statement = qq(SELECT id FROM queue WHERE public='1' and  out='0');
  my $ids = $me->{dbh}->selectall_arrayref($statement);
  return($ids);
}

sub Set_Pubqueue {
  my $me = shift;
  my $id = shift;
  my $params = shift;
  my $statement;
  $statement = qq(INSERT INTO queue (id, public, params, out, done) VALUES ('$id', '1', '', 0, 0));
  print "ST: $statement\n";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute or PRF_Error("Could not execute \"$statement\" in Set_Pubqueue");
}

sub Set_Privqueue {
  my $me = shift;
  my $id = shift;
  my $statement = qq(INSERT INTO queue (id, genome_id, public, params, out, done) VALUES ('', '$id', '0', '', 0, 0));
  $me->Execute($statement);
}

###
### Admin functions below!
###
sub Clean_Table {
  my $me = shift;
  my $type = shift;
  my $table = $type . '_' . $config->{species};
  my $statement = "DELETE from $table";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute or PRF_Error("Could not execute statement: $statement in Create_Genome");
}

sub Drop_All {
  my $me = shift;
  my $genus_species = shift;
  my @tables = ('genome_', 'rnamotif_', 'pknots_', 'nupack_');
  foreach my $tab (@tables) {
	my $t_name = $tab . $genus_species;
	my $statement = "DROP table $t_name";
	my $sth = $me->{dbh}->prepare("$statement");
	$sth->execute or PRF_Error("Could not execute \"$statement\" in Drop_All");
  }
}

sub Drop_Table {
  my $me = shift;
  my $type = shift;
  my $table = $type . '_' . $config->{species};
  my $statement = "DROP table $table";
  my $sth = $me->{dbh}->prepare("$statement");
  $sth->execute or PRF_Error("Could not execute statement: $statement in Create_Genome");
}

sub FillQueue {
  my $me = shift;
  my $best_statement = "INSERT into queue (id, public, params, out, done) SELECT id, 0, '', 0, 0 from genome";
  my $sth = $me->{dbh}->prepare($best_statement);
  $sth->execute;
}

sub Grab_Queue {
  my $me = shift;
  my $type = shift;  ## public or private
  $type = ($type eq 'public' ? 1 : 0);
  my $return;
  ## This id is the same id which uniquely identifies a sequence in the genome database
  my $single_id = qq(select id from queue where public='$type' and out='0' ORDER BY rand() LIMIT 1);
  my @id = $me->{dbh}->selectrow_array($single_id);
  my $return_id = $id[0];
  if (!defined($return_id) or $return_id eq '') {
      return(undef);
  }
  my $update = qq(UPDATE queue SET out='1', outtime=current_timestamp() WHERE id='$return_id' and public='$type');
  $me->Execute($update);
  return($return_id);
}

sub Done_Queue {
  my $me = shift;
  my $id = shift;
  my $update = qq(update queue set done='1', donetime=current_timestamp() where id='$id');
  $me->Execute($update);
}

sub Load_Genome_Table {
  my $me = shift;
  if ($config->{input} =~ /gz$/ or $config->{input} =~ /Z$/) {
	open(IN, "$config->{zcat} $config->{input} |") or die "Could not open the fasta file\n $!\n";
  }
  else {
	open(IN, "<$config->{input}") or die "Could not open the fasta file\n $!\n";
  }
  my %datum = (accession => undef, genename => undef, version => undef, comment => undef, mrna_seq => undef);
  while(my $line = <IN>) {
    chomp $line;
    if ($line =~ /^\>ORFN/) {  ## If it is one of the kooky yeast genomes
      if (defined($datum{accession})) {
	  #$me->Insert_Genome_Entry(\%datum);
	  $me->Import_CDS($datum{accession});
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
	  #$me->Insert_Genome_Entry(\%datum);
	  $me->Import_CDS($datum{accession});
      }
      my ($gi_trash, $gi_id, $gb_trash, $accession_version, $comment) = split(/\|/, $line);
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
      my ($space_trash, $genus, $species) = split(/ /, $comment);
      $datum{species} = $genus . '_' . $species;
      my ($genename, $clone, $type) = split(/\,/, $comment);
      $datum{genename} = $genename;
    }  ## The mgc genomes
    else {
	$datum{mrna_seq} .= $line;
    }   ## Non accession line
  }  ## End every line
#  $me->Insert_Genome_Entry(\%datum);  ## Get the last entry into the database.
  $me->Import_CDS($datum{accession});
}

################################################3
### Everything below here is for the 05 tables
################################################

## ORF data by definition starts at position 1 and ends at the end of the sequence
sub Load_ORF_Data {
  my $me = shift;
  my $species = shift;
  my $misc = new SeqMisc;
  if ($config->{input} =~ /gz$/ or $config->{input} =~ /Z$/) {
	open(IN, "$config->{zcat} $config->{input} |") or die "Could not open the fasta file\n $!\n";
  }
  else {
	open(IN, "<$config->{input}") or die "Could not open the fasta file\n $!\n";
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
        if (!defined($me->Get_Sequence($datum{species}, $datum{accession}))) {
          $me->Insert_Genome_Entry(\%datum);
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
    elsif ($line =~ /^\>/) {  ### This is a CDS entry from the MGC
## >gi|13435938|gb|BC004809.1| Mus musculus PDZ and LIM domain 1 (elfin), mRNA (cDNA clone MGC:5634 IMAGE:3588132), complete cds
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
    }  ## END OF A MGC CDS ENTRY
    else {
      $datum{mrna_seq} .= $line;
    }   ## Non accession line
  }  ## End every line
  $datum{protein_seq} = $misc->Translate($datum{mrna_seq});
  print "Submitting $datum{accession}\n";
  $me->Insert_Genome_Entry(\%datum);  ## Get the last entry into the database.
}

sub Import_CDS {
  my $me = shift;
  my $accession = shift;
  my $uni = new Bio::DB::Universal;
  my $seq = $uni->get_Seq_by_id($accession);
  my @cds = grep { $_->primary_tag eq 'CDS' } $seq->get_SeqFeatures();
  my ($protein_sequence, $orf_start, $orf_stop);
  my $binomial_species = $seq->species->binomial();
  my ($genus, $species) = split(/ /, $binomial_species);
  my $full_species = qq(${genus}_${species});
  $full_species =~ tr/[A-Z]/[a-z]/;
  $config->{species} = $full_species;
  my $full_comment = $seq->desc();
  my ($genename, $desc) = split(/\,/, $full_comment);
  my $mrna_sequence = $seq->seq();
  my $counter = 0;
  my $num_cds = scalar(@cds);
  foreach my $feature (@cds) {
    $counter++;
    ### This is a short term solution FIXME FIXME
    ### The real solution is to remove the uniqueness of accession
    ### In the genome table and introduce an int index
    my $tmp_accession;
    if ($num_cds > 1) {
      $tmp_accession = "$accession.$counter";
    }
    else {
      $tmp_accession = $accession;
    }
    my $primary_tag = $feature->primary_tag();
    $protein_sequence =  $feature->seq->translate->seq();
    $orf_start = $feature->start();
    ### Don't change me, this is provided by genbank
    $orf_stop = $feature->end();
    my %datum = (
                 ### FIXME
                 accession => $tmp_accession,
                 mrna_seq => $mrna_sequence,
		 protein_seq => $protein_sequence,
                 orf_start => $orf_start,
                 orf_stop => $orf_stop,
                 species => $full_species,
                 genename => $genename,
                 version => $seq->{_seq_version},
                 comment => $full_comment,
                );
    my $genome_id = $me->Insert_Genome_Entry(\%datum);
    $me->Set_Privqueue($genome_id, \%datum);
  }
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
  $config->{species} = $full_species;
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
sub Get_Sequence {
  my $me = shift;
  my $accession = shift;
  my $statement = qq(SELECT mrna_seq FROM genome WHERE accession = '$accession');
  my $info = $me->{dbh}->selectall_arrayref($statement);
  my $sequence = $info->[0]->[0];
  if ($sequence) {
	return($sequence);
  }
  else {
	return(undef);
  }
}

sub Get_Num_RNAfolds {
  my $me = shift;
  my $table = shift;
  my $genome_id = shift;
  my $return = {};
  my $statement = "SELECT count(id) FROM $table WHERE genome_id = '$genome_id'";
  my $dbh = $me->{dbh};
  my $info = $dbh->selectall_arrayref($statement);
  my $count = $info->[0]->[0];
  return($count);
}

sub Get_RNAmotif {
  my $me = shift;
  my $genome_id = shift;
  my $return = {};
  my $statement = "SELECT total, start, permissable, filedata, output FROM rnamotif WHERE genome_id = '$genome_id'";
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

sub Get_mRNA {
  my $me = shift;
  my $accession = shift;
  my $statement = qq(SELECT mrna_seq, orf_start, orf_stop FROM genome WHERE accession='$accession');
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

sub Get_ORF {
  my $me = shift;
  my $accession = shift;
  my $statement = qq(SELECT mrna_seq, orf_start, orf_stop FROM genome WHERE accession='$accession');
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
sub Insert_Genome_Entry {
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
  ## The following line is very important to ensure that multiple calls to this don't end up with
  ## Increasingly long sequences
  foreach my $k (keys %{$datum}) { $datum->{$k} = undef; }
  $me->Execute($statement);
  my $last_id = $me->Get_Last_Id();
  return($last_id);
}

sub Put_RNAmotif {
  my $me = shift;
  my $id = shift;
  my $species = shift;
  my $accession = shift;
  my $slipsites_data = shift;
  ## RNAMotif table
  ## id, genome_id, species, accession, start, total, permissable, filedata, output, lastupdate
  if (scalar %{$slipsites_data} eq '0') {
      my $statement = qq(INSERT INTO rnamotif (genome_id, species, accession) VALUES ('$id', '$species', '$accession'));
      $me->Execute($statement);
  }
  else {  ## There are some keys to play with
      foreach my $start (keys %{$slipsites_data}) {
	  my $total = $slipsites_data->{$start}{total};
	  my $permissable = $slipsites_data->{$start}{permissable};
	  my $filename = $slipsites_data->{$start}{filename};
	  my $filedata = $slipsites_data->{$start}{filedata};
	  my $output = $slipsites_data->{$start}{output};
	  my $statement = qq(INSERT INTO rnamotif (genome_id, species, accession, start, total, permissable, filedata, output) VALUES ('$id', '$species', '$accession', '$start', '$total', '$permissable', '$filedata', '$output'));
      #    print "RNAMOTIF: $statement\n";
	  $me->Execute($statement);
      } ## End looking at every slipsite for a locus
  }  ## End checking for a null set
}  ## End Put_RNAMotif

sub Put_Nupack {
    my $me = shift;
    my $data = shift;
    $me->Put_MFE('nupack', $data);
}

sub Put_Pknots {
    my $me = shift;
    my $data = shift;
    $me->Put_MFE('pknots', $data);
}

sub Put_MFE {
  my $me = shift;
  my $table = shift;
  my $data = shift;
  ## What fields do we want to fill in this MFE table?
  my @pknots = ('genome_id','species','accession','start','slipsite','seqlength','sequence','output','parsed','parens','mfe','pairs','knotp','barcode');
  my $errorstring = Check_Insertion(\@pknots, $data);
  if (defined($errorstring)) {
      $errorstring = "Undefined value(s) in Put_MFE $table: $errorstring";
      PRF_Error($errorstring, $data->{species}, $data->{accession});
    }
    my $statement = qq(INSERT INTO $table (genome_id, species, accession, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode) VALUES ('$data->{genome_id}', '$data->{species}', '$data->{accession}', '$data->{start}', '$data->{slipsite}', '$data->{seqlength}', '$data->{sequence}', '$data->{output}', '$data->{parsed}', '$data->{parens}', '$data->{mfe}', '$data->{pairs}', '$data->{knotp}', '$data->{barcode}'));
  #  print "MFE: $statement\n";
  $me->Execute($statement);
}  ## End of Put_MFE

sub Put_Boot {
  my $me = shift;
  my $data = shift;
  my $id = $data->{genome_id};
  ## What fields are required?
  foreach my $mfe_method (keys%{$config->{boot_mfe_algorithms}}) {
      #foreach my $mfe_method (keys %{$data}) {
      foreach my $rand_method (keys %{$config->{boot_randomizers}}) {
	  #foreach my $rand_method (keys %{$data->{$mfe_method}}) {
	  my $iterations = $data->{$mfe_method}->{$rand_method}->{stats}->{iterations};
	  my $mfe_mean = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_mean};
	  my $mfe_sd = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_sd};
	  my $mfe_se = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_se};
	  my $pairs_mean = $data->{$mfe_method}->{$rand_method}->{stats}->{pairs_mean};
	  my $pairs_sd = $data->{$mfe_method}->{$rand_method}->{stats}->{pairs_sd};
	  my $pairs_se = $data->{$mfe_method}->{$rand_method}->{stats}->{pairs_se};
	  my $mfe_values = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_values};

	  my @boot = ('genome_id','species','accession','start');
	  my $errorstring = Check_Insertion(\@boot, $data);
	  if (defined($errorstring)) {
	      $errorstring = "Undefined value(s) in Put_Boot: $errorstring";
	      PRF_Error($errorstring, $data->{species}, $data->{accession});
	  }

	  my $statement = qq(INSERT INTO boot (genome_id, species, accession, start, iterations, rand_method, mfe_method, mfe_mean, mfe_sd, mfe_se, pairs_mean, pairs_sd, pairs_se, mfe_values) VALUES ('$data->{genome_id}', '$data->{species}', '$data->{accession}', '$data->{start}', '$iterations', '$rand_method', '$mfe_method', '$mfe_mean', '$mfe_sd', '$mfe_se', '$pairs_mean', '$pairs_sd', '$pairs_se', '$mfe_values'));
	  $me->Execute($statement);
      }  ### Foreach random method
  } ## Foreach mfe method
}  ## End of Put_Boot

#################################################
### Functions used to create the prfdb tables
#################################################
sub Create_Genome {
  my $me = shift;
  my $statement = "CREATE table genome (
id $config->{sql_id},
accession $config->{sql_accession},
species $config->{sql_species},
genename $config->{sql_genename},
version int,
comment $config->{sql_comment},
mrna_seq text not null,
protein_seq text,
orf_start int,
orf_stop int,
lastupdate $config->{sql_timestamp},
primary key (id),
UNIQUE(accession),
INDEX(genename))";
  $me->Execute($statement);
}

sub Create_Rnamotif {
  my $me = shift;
  my $statement = "CREATE table rnamotif (
id $config->{sql_id},
genome_id int,
species $config->{sql_species},
accession $config->{sql_accession},
start int,
total int,
permissable int,
filedata blob,
output blob,
lastupdate $config->{sql_timestamp},
primary key (id))";
  $me->Execute($statement);
}

sub Create_Queue {
  my $me = shift;
  my $statement = "CREATE table queue (
id $config->{sql_id},
genome_id int,
public bool,
params blob,
out bool,
outtime timestamp default '',
done bool,
donetime timestamp default '',
primary key (id))";
  $me->Execute($statement);
}

sub Create_Pknots {
  my $me = shift;
  $me->Create_MFE('pknots');
}

sub Create_Nupack {
  my $me = shift;
  $me->Create_MFE('nupack');
}

sub Create_MFE {
  my $me = shift;
  my $name = shift;
  my $statement = "CREATE TABLE $name (
id $config->{sql_id},
genome_id int,
species $config->{sql_species},
accession $config->{sql_accession},
start int,
slipsite char(7),
seqlength int,
sequence text,
output text,
parsed text,
parens text,
mfe float,
pairs int,
knotp bool,
barcode text,
lastupdate $config->{sql_timestamp},
primary key(id))";
  $me->Execute($statement);
}

sub Create_Boot {
  my $me = shift;
  my $statement = "CREATE TABLE boot (
id $config->{sql_id},
genome_id int,
species $config->{sql_species},
accession $config->{sql_accession},
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
mfe_values text,
lastupdate $config->{sql_timestamp},
primary key(id))";
  $me->Execute($statement);
}

sub Create_Analysis {
    my $me = shift;
    my $statement = "CREATE TABLE analysis (
id $config->{sql_id},
mfe_source varchar(20) not null,
mfe_id int,
boot_id int,
accession $config->{sql_accession},
image blob,
z_score float,
lastupdate $config->{sql_timestamp},
primary key(id))";
    $me->Execute($statement);
}

sub Create_Errors {
  my $me = shift;
  my $statement = "CREATE table errors (
id $config->{sql_id},
time $config->{sql_timestamp},
message blob,
accession $config->{sql_accession},
primary key(id))";
  $me->Execute($statement);
}

sub Tablep {
    my $me = shift;
    my $table = shift;
    my $statement = qq(SHOW TABLES LIKE '$table');
    my $dbh = DBI_Connect();
    my $info = $dbh->selectall_arrayref($statement);
    return(scalar(@{$info}));
}

sub DBI_Connect {
    my ($datasource,$username, $password,$attr) = @_;
    my $dbh;
    my $conn_error;
    if (!defined($datasource)) {
      $datasource = "dbi:mysql:" . $config->{db} . ":hostname=" . $config->{host};
      $username = $config->{user};
      $password = $config->{pass};
      $attr = {RaiseError => 1, AutoCommit => 1 };
    }
	
    # Try connecting to the database, as usual.  If that fails, print
    # an error message and exit.
    unless ($dbh = DBI->connect($datasource, $username, $password, $attr)) {
	$conn_error = DBI->errstr();
	die("Failed to connect to $datasource: $conn_error");
    }	
    return $dbh;
}

sub DBI_doSQL {
    my $dbh = shift;
    my $statement = shift;
    my $sth;
    my $returncode;
    my $prep_error;
    my $data_error;
    my @resultSet = ();
    my @record = ();
    
    unless( $sth = $dbh->prepare($statement) ){
	$prep_error = $dbh->errstr;
	print "SQL syntax error!\n\n$prep_error\n\n
			Your statement was \n\n$statement\n\n
			Exiting...\n";
	exit();
    }
    
    if( $returncode = $sth -> execute() ) {
	while(@record = $sth -> fetchrow_array() ){
	    push(@resultSet, [@record] );
	}
	$sth -> finish();
    } else {
	$data_error = $dbh->errstr;
	print "SQL execution error!\n\n$data_error\n\n
			Your statement was \n\n$statement\n\n";
	exit();
    }
    return \@resultSet;
}

sub Check_Insertion {
    my $list = shift;
    my $data = shift;
    my $errorstring = undef;
    foreach my $column (@{$list}) {
	$errorstring .= "$column " unless(defined($data->{$column}));
    }
    return($errorstring);
}

sub Execute {
    my $me = shift;
    my $statement = shift;
    my $dbh = $me->{dbh};
    my $errorstr;
    my $sth = $dbh->prepare($statement) or
	$errorstr = "Could not prepare: $statement " . $dbh->errstr , PRF_Error($errorstr);
    $sth->execute() or
	$errorstr = "Could not execute: $statement " . $dbh->errstr , PRF_Error($errorstr);
}

sub Get_Last_Id {
    my $me = shift;
    my $id = $me->{dbh}->selectall_arrayref('select last_insert_id()');
    return($id->[0]->[0]);
}

1;
