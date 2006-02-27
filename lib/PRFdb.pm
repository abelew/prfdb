package PRFdb;
use strict;
use DBI;
use PRFConfig qw / PRF_Error PRF_Out /;
use SeqMisc;
use File::Temp qw / tmpnam /;
use Fcntl ':flock'; # import LOCK_* constants
use Bio::DB::Universal;

### Holy crap global variables!
my $config = $PRFConfig::config;
my $dbh;
###

sub new {
  my ($class, %arg) = @_;
  if (defined($arg{config})) {
    $config = $arg{config};
  }
  my $me = bless {
      dsn => $config->{dsn},
      user => $config->{user},
  }, $class;

  $dbh = DBI->connect($me->{dsn}, $config->{user}, $config->{pass});
  $me->{dbh}->{mysql_auto_reconnect} = 1;
  $me->{dbh}->{Inactive_Destroy} = 1;
  $me->Create_Genome() unless($me->Tablep('genome'));
  $me->Create_Queue() unless($me->Tablep('queue'));
  $me->Create_Rnamotif() unless($me->Tablep('rnamotif'));
  $me->Create_Boot() unless($me->Tablep('boot'));
  $me->Create_MFE() unless($me->Tablep('mfe'));
#  $me->Create_Analysis() unless($me->Tablep('analysis'));
  $me->Create_Errors() unless($me->Tablep('errors'));
  return ($me);
}

sub MySelect {
    my $me = shift;
    my $statement = shift;
    my $type = shift;  
    my $descriptor = shift;
    my $return = undef;
    if (!defined($statement)) {
	die("WTF, no statement in MySelect");
    }
    $me->MyConnect($statement);
    my $selecttype;

    ## If $type AND $descriptor are defined, do selectall_hashref
    if (defined($type) and defined($descriptor)) {
	$return = $dbh->selectall_hashref($statement, $descriptor);
	$selecttype = 'selectall_hashref';
    }

    ## If $type is defined, AND if you ask for a row, do a selectrow_arrayref
    elsif (defined($type) and $type eq 'row') {
	$return = $dbh->selectrow_arrayref($statement);
#	print "TESTME: $return\n";
	$selecttype = 'selectrow_arrayref';
    }

    ## If only $type is defined, do a selectrow_hashref
    elsif (defined($type)) {
	$return = $dbh->selectrow_hashref($statement);
	$selecttype = 'selectrow_hashref';
    }

    ## The default is to do a selectall_arrayref
    else {
	$return = $dbh->selectall_arrayref($statement);
	$selecttype = 'selectall_arrayref';
    }

    if (!defined($return) or $return eq 'null') {
	Write_SQL($statement);
	my $errorstring = "DBH: <$dbh> $selecttype return is undefined in MySelect: $statement, " . $DBI::errstr;
	die($errorstring);
    }
    return($return);
}

sub MyConnect {
    my $me = shift;
    my $statement = shift;
    if (!defined($statement) or $statement eq '') {
	die("Statement is not defined in MyConnect!");
    }
    $dbh = DBI->connect_cached($me->{dsn}, $config->{user}, $config->{pass});
    if (!defined($dbh)) {
	if (defined($statement)) {
	    Write_SQL($statement);
	}
	my $error = "Could not open cached connection: $me->{dsn}, " . $DBI::err . ", " . $DBI::errstr;
	die("$error");
    }
    return($dbh);
}

sub Get_All_Sequences {
  my $me = shift;
  my $statement = "SELECT accession, mrna_seq from genome";
  $me->MyConnect($statement);
  my $sth = $dbh->prepare($statement);
  return($sth);
}

sub Keyword_Search {
  my $me = shift;
  my $species = shift;
  my $keyword = shift;
  my $statement = qq(SELECT accession, comment FROM genome WHERE comment like '%$keyword%' ORDER BY accession);
  my $info = $me->MySelect($statement);
  my $return = {};
  foreach my $accession (@{$info}) {
    my $accession_id = $accession->[0];
    my $accession_comment = $accession->[1];
    $return->{$accession_id} = $accession_comment;
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
### Get and Set Bootstrap data
####
sub Get_Boot {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $start = shift;
  PRF_Error("Undefined value in Get_Boot", $species, $accession) unless (defined($species) and defined($accession));
  my $statement;
  if (defined($start)) {
    $statement = qq(SELECT * FROM boot WHERE accession='$accession' AND start='$start' ORDER BY start);
  }
  else {
    $statement = qq(SELECT * from boot where accession='$accession' ORDER BY start);
  }
  my $info = $me->MySelect($statement, 'hash', 1);
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
  my $data = $me->MySelect($statement);
  my $accession = $data->[0]->[0];
  my $species = $data->[0]->[1];
  my $return = {accession => $accession, species => $species,};
  return($return);
}

sub Error_Db {
  my $me = shift;
  my $message = shift;
  my $species = shift;
  my $accession = shift;
  $species = '' if (!defined($species));
  $accession = '' if (!defined($accession));
  print "Error: '$message'\n";
  my $statement = qq(INSERT into errors (message, accession) VALUES('$message', '$accession'));
  ## Don't call Execute here or you may run into circular crazyness
  $me->MyConnect($statement);
  my $sth = $dbh->prepare($statement);
  $sth->execute();
}

sub Get_Entire_Pubqueue {
  my $me = shift;
  my $return;
  my $statement = qq(SELECT id FROM queue WHERE public='1' and  out='0');
  my $ids = $me->MySelect($statement);
  return($ids);
}

sub Set_Pubqueue {
  my $me = shift;
  my $id = shift;
  my $params = shift;
  my $statement;
  $statement = qq(INSERT INTO queue (id, public, params, out, done) VALUES ('$id', '1', '', 0, 0));
  $me->MyConnect($statement);
  my $sth = $dbh->prepare("$statement");
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
  $me->MyConnect($statement);
  my $sth = $dbh->prepare("$statement");
  $sth->execute or PRF_Error("Could not execute statement: $statement in Create_Genome");
}

sub Drop_Table {
  my $me = shift;
  my $table = shift;
  my $statement = "DROP table $table";
  $me->MyConnect($statement);
  my $sth = $dbh->prepare("$statement");
  $sth->execute or PRF_Error("Could not execute statement: $statement in Create_Genome");
}

sub FillQueue {
  my $me = shift;
  my $best_statement = "INSERT into queue (genome_id, public, params, out, done) SELECT id, 0, '', 0, 0 from genome";
  $me->MyConnect($best_statement);
  my $sth = $dbh->prepare($best_statement);
  $sth->execute;
}

sub Reset_Queue {
    my $me = shift;
    my $statement = "UPDATE queue set out = '0' where done = '0' and out = '1'";
    $me->MyConnect($statement);
    my $sth = $dbh->prepare($statement);
    $sth->execute;
}

sub Grab_Queue {
  my $me = shift;
  my $type = shift;  ## public or private
  $type = ($type eq 'public' ? 1 : 0);
  ## This id is the same id which uniquely identifies a sequence in the genome database
#  my $single_id = qq(select id, genome_id from queue where public='$type' and out='0' ORDER BY rand() LIMIT 1);
#  my $single_id = qq(select id, genome_id from queue where genome_id='207');
  my $single_id = qq(select id, genome_id from queue where public='$type' and out='0' LIMIT 1);
  my $ids = $me->MySelect($single_id, 'row');
  my $id = $ids->[0];
  my $genome_id = $ids->[1];
  if (!defined($id) or $id eq ''
      or !defined($genome_id) or $genome_id eq '') {
    return(undef);
  }
  my $update = qq(UPDATE queue SET out='1', outtime=current_timestamp() WHERE id='$id' and public='$type');
  $me->Execute($update);
  my $return = { queue_id => $id,
		 genome_id => $genome_id,
		 };
  return($return);
}

sub Grab_Overlap_Queue {
    my $me = shift;
    ## This id is the same id which uniquely identifies a sequence in the genome database
    my $single_id = qq(select id, genome_id from overlap_queue where out='0' LIMIT 1);
    my $ids = $me->{dbh}->selectrow_arrayref($single_id);
    my $id = $ids->[0];
    my $genome_id = $ids->[1];
    if (!defined($id) or $id eq ''
	or !defined($genome_id) or $genome_id eq '') {
        return(undef);
    }
    my $update = qq(UPDATE overlap_queue SET out='1', outtime=current_timestamp() WHERE id='$id');
    $me->Execute($update);
    my $return = {
	queue_id => $id,
	genome_id => $genome_id,
    };
    return($return);
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
    my $tmp_mrna_sequence = $mrna_sequence;
    $counter++;
    my $primary_tag = $feature->primary_tag();
    $protein_sequence =  $feature->seq->translate->seq();
    $orf_start = $feature->start();
    $orf_stop = $feature->end();
    ### $feature->{_location}{_strand} == -1 or 1 depending on the strand.
    my $direction;
    if ($feature->{_location}{_strand} == 1) {
      $direction = 'forward';
    }
    elsif ($feature->{_location}{_strand} == -1) {
      $direction = 'reverse';
      my $tmp_start = $orf_start;
      $orf_start = $orf_stop - 1;
      $orf_stop = $tmp_start - 2;
      my $fake_orf_stop = 0;
      undef $tmp_start;
      my @tmp_sequence = split(//, $tmp_mrna_sequence);
      my $tmp_length = scalar(@tmp_sequence);
      my $sub_sequence = '';
      while ($orf_start > $fake_orf_stop) {
	$sub_sequence .= $tmp_sequence[$orf_start];
	$orf_start--;
      }
      $sub_sequence =~ tr/ATGCatgcuU/TACGtacgaA/;
      $tmp_mrna_sequence = $sub_sequence;
    }
    else {
      print PRF_Error("WTF: Direction is not forward or reverse\n");
    }
    ### Don't change me, this is provided by genbank
#    print "TESTME: $orf_start $orf_stop\n\n";
    my %datum = (
                 ### FIXME
                 accession => $accession,
                 mrna_seq => $tmp_mrna_sequence,
                 protein_seq => $protein_sequence,
                 orf_start => $orf_start,
                 orf_stop => $orf_stop,
                 direction => $direction,
                 species => $full_species,
                 genename => $genename,
                 version => $seq->{_seq_version},
                 comment => $full_comment,
                );
    my $genome_id = $me->Insert_Genome_Entry(\%datum);
    $me->Set_Privqueue($genome_id, \%datum);
  }
}
#363-581
#ctagacgt ggaaaacgag cggcggtaga aacgtaggaa taggtgtacc gtcgtaccct
#ctggacgacc taggtctgtc tatgtattct atctcctccg gtagacgtag aaaaacgaat
#actcggtcta tcctcgggca gacatagacg cgtccacctc cgaatctaaa cagacgggta
#tacgataaat ctacgtcgtc ggagacccga cgaacgacca t

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

sub Get_OMIM {
  my $me = shift;
  my $id = shift;;
  my $statement = qq(SELECT omim_id FROM genome where id='$id');
  my $info = $me->MySelect($statement);
  my $omim = $info->[0]->[0];
  if (!defined($omim) or $omim eq 'none') {
    return(undef);
  }
  elsif ($omim =~ /\d+/) {
    return($omim);
  }
  else {
    my $uni = new Bio::DB::Universal;
    my $seq = $uni->get_Seq_by_id($id);
    my @cds = grep { $_->primary_tag eq 'CDS' } $seq->get_SeqFeatures();
    my $omim_id = '';
    foreach my $feature (@cds) {
      my $db_xref_list = $feature->{_gsf_tag_hash}->{db_xref};
      foreach my $db (@{$db_xref_list}) {
        if ($db =~ /^MIM\:/) {
          $db =~ s/^MIM\://g;
          $omim_id .= "$db ";
        } ## Is it in omim?
      }   ## Possible databases
    }     ## CDS features
    my $statement = "UPDATE genome SET omim_id='$omim_id' WHERE id='$id'";
    $me->Execute($statement);
    return($omim_id);
  }
}

sub Check_Genome_Table {
  my $me = shift;
  my $species = shift;
  my $table = 'genome_' . $species;
  my $statement = "SHOW TABLES like '$table'";  
  my $info = $me->MySelect($statement);
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
  my $info = $me->MySelect($statement);
  my $sequence = $info->[0]->[0];
  if ($sequence) {
	return($sequence);
  }
  else {
	return(undef);
  }
}

sub Get_Sequence_from_id {
    my $me = shift;
    my $id = shift;
    my $statement = qq(SELECT mrna_seq FROM genome WHERE id = '$id');
    my $info = $me->{dbh}->selectall_arrayref($statement);
    my $sequence = $info->[0]->[0];
    if ($sequence) {
	return($sequence);
    }
    else {
	return(undef);
    }
}

sub Get_MFE_ID {
    my $me = shift;
    my $genome_id = shift;
    my $start = shift;
    my $seqlength = shift;
    my $algorithm = shift;
    my $statement = qq(SELECT id FROM mfe WHERE genome_id = '$genome_id' AND start = '$start' AND seqlength = '$seqlength' AND algorithm = '$algorithm');
#    print "TESTMEL $statement\n";
    my $info = $me->MySelect($statement);
    my $mfe = $info->[0]->[0];
    return($mfe);
}

sub Get_Num_RNAfolds {
  my $me = shift;
  my $algo = shift;
  my $genome_id = shift;
  my $return = {};
  my $sequence_length = $PRFConfig::config->{max_struct_length} + 1;
  my $statement = "SELECT count(id) FROM mfe WHERE seqlength = '$sequence_length' and genome_id = '$genome_id' and algorithm = '$algo'";
#  print "TESTING: $statement\n";
  my $info = $me->MySelect($statement);
  my $count = $info->[0]->[0];
  if (!defined($count) or $count eq '') {
      $count = 0;
  }
  return($count);
}

sub Get_Num_Bootfolds {
  my $me = shift;
  my $genome_id = shift;
  my $start = shift;
  my $return = {};
  my $sequence_length = $PRFConfig::config->{max_struct_length} + 1;
  my $statement = "SELECT count(id) FROM boot WHERE genome_id = '$genome_id' and start = '$start'";
  print "TEST: $statement\n";
  my $info = $me->MySelect($statement);
  my $count = $info->[0]->[0];
  return($count);
}

sub Get_RNAmotif {
  my $me = shift;
  my $genome_id = shift;
  my $return = {};
  my $statement = "SELECT start, total, permissable, filedata, output FROM rnamotif WHERE genome_id = '$genome_id'";
  my $info = $me->MySelect($statement);
  my @data = @{$info};
  my $records = scalar(@data);
  return(undef) if (scalar(@data) <= 0);
  foreach my $start (@data) {
    my @tmp = @{$start};
    if (!defined($start->[0])) {
      $return->{NONE} = undef;
    }
    else {
      my $st = $start->[0];
      $return->{$st}{start} = $st;
      $return->{$st}{total} = $start->[1];
      $return->{$st}{permissable} = $start->[2];
      $return->{$st}{filedata} = $start->[3];
      $return->{$st}{output} = $start->[4];
    }
  }
  return($return);
}

sub Get_mRNA {
  my $me = shift;
  my $accession = shift;
  my $statement = qq(SELECT mrna_seq, orf_start, orf_stop FROM genome WHERE accession='$accession');
  my $info = $me->MySelect($statement, 'hash');
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
  my $info = $me->MySelect($statement, 'hash');
  my $mrna_seq = $info->{mrna_seq};
  ### A PIECE OF CODE TO HANDLE PULLING SUBSEQUENCES FROM CDS
  my $start = $info->{orf_start} - 1;
  my $stop = $info->{orf_stop} - 1;
  my $offset = $stop - $start;
#  my $sequence = substr($mrna_seq, $start, $offset);  ## If I remove the substring
  ## Then it should return from the start codon to the end of the mRNA which is good
  ## For searching over viral sequence!
  my $sequence = substr($mrna_seq, $start);
#	print "PRFDB TEST: $sequence\n";
  ### DONT SCAN THE ENTIRE MRNA, ONLY THE ORF
  if ($sequence) {
	my $return = {
          sequence => "$sequence",
          orf_start => $start,
          orf_stop => $stop,
        };
	return($return);
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
  my $dbh = DBI->connect($me->{dsn}, $config->{user}, $config->{pass});
  my $accession = $dbh->quote($datum->{accession});
  my $species = $dbh->quote($datum->{species});
  my $genename = $dbh->quote($datum->{genename});
  my $version = $dbh->quote($datum->{version});
  my $comment = $dbh->quote($datum->{comment});
  my $mrna_seq = $dbh->quote($datum->{mrna_seq});
  my $prot_seq = $dbh->quote($datum->{protein_seq});
  my $orf_start = $dbh->quote($datum->{orf_start});
  my $orf_stop = $dbh->quote($datum->{orf_stop});
  my $orf_direction = '';
  if (defined($datum->{direction})) {
    $orf_direction = $dbh->quote($datum->{direction});
  }
  my $statement = "INSERT INTO genome
(accession, species, genename, version, comment, mrna_seq, protein_seq, orf_start, orf_stop, direction)
VALUES($accession, $species, $genename, $version, $comment, $mrna_seq, $prot_seq, $orf_start, $orf_stop, $orf_direction)";
  ## The following line is very important to ensure that multiple calls to this don't end up with
  ## Increasingly long sequences
  foreach my $k (keys %{$datum}) { $datum->{$k} = undef; }
  $dbh->disconnect();
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

sub Get_Pknots {
  my $me = shift;
  my $identifier = shift;  ## { genome_id => #, species => #, accession => #, start => # }
  my $statement = '';
  if (defined($identifier->{genome_id})) {
    $statement = "SELECT id, genome_id, species, accession, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode FROM mfe where genome_id = '$identifier->{genome_id}'";
  }
  elsif (defined($identifier->{accession} and defined($identifier->{start}))) {
    $statement = "SELECT id, genome_id, species, accession, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode FROM mfe where accession = '$identifier->{accession}' and start = '$identifier->{start}'";
  }
  my $info = $me->MySelect($statement, [qq(id genome_id species accession start slipsite seqlength sequence output parsed parens mfe pairs knotp barcode)]);
  return($info);
}

sub Put_Pknots {
    my $me = shift;
    my $data = shift;
    $me->Put_MFE('pknots', $data);
}

sub Put_MFE {
  my $me = shift;
  my $algo = shift;
  my $data = shift;
  ## What fields do we want to fill in this MFE table?
  my @pknots = ('genome_id','species','accession','start','slipsite','seqlength','sequence','output','parsed','parens','mfe','pairs','knotp','barcode');
  my $errorstring = Check_Insertion(\@pknots, $data);
  if (defined($errorstring)) {
      $errorstring = "Undefined value(s) in Put_MFE: $errorstring";
      PRF_Error($errorstring, $data->{species}, $data->{accession});
    }
    my $statement = qq(INSERT INTO mfe (genome_id, species, algorithm, accession, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode) VALUES ('$data->{genome_id}', '$data->{species}', '$algo', '$data->{accession}', '$data->{start}', '$data->{slipsite}', '$data->{seqlength}', '$data->{sequence}', '$data->{output}', '$data->{parsed}', '$data->{parens}', '$data->{mfe}', '$data->{pairs}', '$data->{knotp}', '$data->{barcode}'));
  #  print "MFE: $statement\n";
  $me->Execute($statement, $data->{genome_id});
  my $dbh = DBI->connect($me->{dsn}, $config->{user}, $config->{pass});
  my $get_inserted_id = qq(SELECT LAST_INSERT_ID());
  my $id = $me->MySelect($get_inserted_id);
  return($id->[0]->[0]);
}  ## End of Put_MFE

sub Put_Boot {
  my $me = shift;
  my $data = shift;
  my $id = $data->{genome_id};
  ## What fields are required?
  foreach my $mfe_method (keys%{$config->{boot_mfe_algorithms}}) {
      my $mfe_id = $data->{mfe_id};
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
	  my $species = $data->{$mfe_method}->{$rand_method}->{stats}->{species};
	  my $accession = $data->{$mfe_method}->{$rand_method}->{stats}->{accession};
	  my $mfe_id = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_id};
#	  print "LAST HERE: $mfe_id\n";
	  my $start = $data->{$mfe_method}->{$rand_method}->{stats}->{start};
	  my @boot = ('genome_id');
	  my $errorstring = Check_Insertion(\@boot, $data);
	  if (defined($errorstring)) {
	      $errorstring = "Undefined value(s) in Put_Boot: $errorstring";
	      PRF_Error($errorstring, $species, $accession);
	  }

	  my $statement = qq(INSERT INTO boot (genome_id, mfe_id, species, accession, start, iterations, rand_method, mfe_method, mfe_mean, mfe_sd, mfe_se, pairs_mean, pairs_sd, pairs_se, mfe_values) VALUES ('$data->{genome_id}', '$mfe_id', '$species', '$accession', '$start', '$iterations', '$rand_method', '$mfe_method', '$mfe_mean', '$mfe_sd', '$mfe_se', '$pairs_mean', '$pairs_sd', '$pairs_se', '$mfe_values'));
#	print "TEST: $statement\n";
	  $me->Execute($statement);
      }  ### Foreach random method
  } ## Foreach mfe method
}  ## End of Put_Boot

sub Put_Overlap {
    my $me = shift;
    my $data = shift;
    my $statement = qq(INSERT INTO overlap (genome_id, species, accession, start, plus_length, plus_orf, minus_length, minus_orf) VALUES ('$data->{genome_id}', '$data->{species}', '$data->{accession}', '$data->{start}', '$data->{plus_length}', '$data->{plus_orf}', '$data->{minus_length}', '$data->{minus_orf}'));
    $me->Execute($statement);
    my $id = $data->{overlap_id};
    return($id);
}  ## End of Put_Overlap

#################################################
### Functions used to create the prfdb tables
#################################################

### FIXME The prfdb05 does not have the direction field and omim_id
sub Create_Genome {
  my $me = shift;
  my $statement = "CREATE table genome (
id $config->{sql_id},
accession $config->{sql_accession},
species $config->{sql_species},
genename $config->{sql_genename},
version int,
comment $config->{sql_comment},
mrna_seq longblob not null,
protein_seq text,
orf_start int,
orf_stop int,
direction char(7) DEFAULT 'forward',                  /* forward or reverse */
omim_id varchar(30),
lastupdate $config->{sql_timestamp},
primary key (id),
UNIQUE(accession),
INDEX(genename))";
  $me->Execute($statement);
}

sub Create_Overlap {
    my $me = shift;
    my $statement = "CREATE table overlap (
id $config->{sql_id},
genome_id int,
species $config->{sql_species},
accession $config->{sql_accession},
start int,
plus_length int,
plus_orf text,
minus_length int,
minus_orf text,
lastupdate $config->{sql_timestamp},
primary key (id))";
    $me->Execute($statement);
}

### FIXME Recreate rnamotif table for prfdb05
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

### prfdb05 queue should be recreated.
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

sub Create_Overlap_Queue {
    my $me = shift;
    my $statement = "CREATE table overlap_queue (
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
    my $best_statement = "INSERT into overlap_queue (genome_id, public, params, out, done) SELECT id, 0, '', 0, 0 from genome where species = 'homo_sapiens'";
    my $sth = $me->{dbh}->prepare($best_statement);
    $sth->execute;
}

### FIXME The Prfdb05 has different columns from nupack 
### (- genome_id, s/paren_output/output/, - parens, - barcode
### FIXME pknots table: s/seqLength/seqlength/, +pk_output
sub Create_MFE {
  my $me = shift;
  my $name = shift;
  my $statement = "CREATE TABLE $name (
id $config->{sql_id},
genome_id int,
species $config->{sql_species},
accession $config->{sql_accession},
algorithm char(10),
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

### FIXME Jonathan has changed genome_id to structureID in prfdb05
sub Create_Boot {
  my $me = shift;
  my $statement = "CREATE TABLE boot (
id $config->{sql_id},
genome_id int,
mfe_id int,
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
genome_id int,
mfe_source varchar(20),
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
    my $info = $me->MySelect($statement);
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
    my $genome_id = shift;
    $me->MyConnect($statement);
    my $errorstr;

    my $sth = $dbh->prepare($statement) or
	$errorstr = "Could not prepare: $statement " . $dbh->errstr , Write_SQL($statement, $genome_id),  PRF_Error($errorstr);
    $sth->execute() or
	$errorstr = "Could not execute: $statement " . $dbh->errstr , Write_SQL($statement, $genome_id), PRF_Error($errorstr);
}

sub Write_SQL {
    my $statement = shift;
    my $genome_id = shift;
    open(SQL, ">>failed_sql_statements.txt");
    my $string = "$statement" . ";\n";
    print SQL "$string";

    if (defined($genome_id)) {
	my $second_statement = "UPDATE queue set done='0', out='0' where genome_id = '$genome_id';\n";
	print SQL "$second_statement";
    }
    close(SQL);
}

sub Get_Last_Id {
    my $me = shift;
    my $statement = 'select last_insert_id()';
    my $id = $me->MySelect($statement);
    return($id->[0]->[0]);
}

1;
