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

#  $dbh = DBI->connect_cached($me->{dsn}, $config->{user}, $config->{pass});
  $dbh->{mysql_auto_reconnect} = 1;
  $dbh->{InactiveDestroy} = 1;
  if ($config->{checks}) {
    my $answer = $me->Tablep('genome');
    $me->Create_Genome() unless($me->Tablep('genome'));
    $me->Create_Queue() unless($me->Tablep($config->{queue_table}));
    $me->Create_Boot() unless($me->Tablep('boot'));
    $me->Create_MFE() unless($me->Tablep('mfe'));
    $me->Create_Landscape() unless($me->Tablep('landscape'));
#  $me->Create_Analysis() unless($me->Tablep('analysis'));
    $me->Create_Errors() unless($me->Tablep('errors'));
    $me->Create_NoSlipsite() unless($me->Tablep('noslipsite'));
  }
  return ($me);
}

sub Disconnect {
  $dbh->disconnect();
}

sub MySelect {
    my $me = shift;
    my $statement = shift;
    my $vars = shift;
    my $type = shift;
    my $descriptor = shift;
    my $return = undef;
    if (!defined($statement)) {
	die("WTF, no statement in MySelect");
    }
    my $dbh = $me->MyConnect($statement);
    my $selecttype;
    my $sth = $dbh->prepare($statement);
    my $rv = $sth->execute(@{$vars});
    ## If $type AND $descriptor are defined, do selectall_hashref
    if (defined($type) and defined($descriptor)) {
        $return = $sth->fetchall_hashref($descriptor);
	$selecttype = 'selectall_hashref';
    }

    ## If $type is defined, AND if you ask for a row, do a selectrow_arrayref
    elsif (defined($type) and $type eq 'row') {
      $return = $sth->fetchrow_arrayref();
      $selecttype = 'selectrow_arrayref';
    }

    ## A flat select is one in which the returned elements are returned as a single flat arrayref
    ## If you ask for multiple columns, then it will return a 2d array ref with the first d being the cols
    elsif (defined($type) and $type eq 'flat') {
      my $selecttype = 'flat';
      my @ret = ();
      my $data = $sth->fetchall_arrayref();
      if (!defined($data->[0])) {
	return(undef);
      }
      if (scalar(@{$data->[0]}) == 1) {
        foreach my $c (0 .. $#$data) {
          push(@ret, $data->[$c]->[0]);
        }
      }
      else {
        foreach my $c (0 .. $#$data) {
	  my @elems = @{$data->[$c]};
          foreach my $d (0 .. $#elems) {
            $ret[$d][$c] = $data->[$c]->[$d];
          }
        }
      }
      $return = \@ret;
    } ## Endif flat

    ## If only $type is defined, do a selectrow_hashref
    elsif (defined($type)) {  ## Usually defined as 'hash'
      $return = $sth->fetchrow_hashref();
      $selecttype = 'selectrow_hashref';
    }

    ## The default is to do a selectall_arrayref
    else {
      $return = $sth->fetchall_arrayref();
      $selecttype = 'selectall_arrayref';
    }

    if (!defined($return) or $return eq 'null') {
	Write_SQL($statement);
	my $errorstring = "DBH: <$dbh> $selecttype return is undefined in MySelect: $statement, ";
	if (defined($DBI::errstr)) {
	    $errorstring .= $DBI::errstr;
	}
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
    $dbh->{mysql_auto_reconnect} = 1;
    $dbh->{InactiveDestroy} = 1;
    if (!defined($dbh)) {
	if (defined($statement)) {
	    Write_SQL($statement);
	}
	my $error = "Could not open cached connection: $me->{dsn}, " . $DBI::err . ", " . $DBI::errstr;
	die("$error");
    }
    return($dbh);
}

sub Get_GenomeId_From_Accession {
  my $me = shift;
  my $accession = shift;
  my $info = $me->MySelect(qq(SELECT id FROM genome WHERE accession = ?),
                           [$accession], 'row');
  return($info->[0]);
}

sub Get_GenomeId_From_QueueId {
    my $me = shift;
    my $queue_id = shift;
    my $info = $me->MySelect(qq(SELECT genome_id FROM $config->{queue_table} WHERE id = ?), [$queue_id], 'row');
    return($info->[0]);
}

sub Get_All_Sequences {
  my $me = shift;
  my $statement = "SELECT accession, mrna_seq FROM genome";
  $me->MyConnect($statement);
  my $sth = $dbh->prepare($statement);
  return($sth);
}

sub Keyword_Search {
  my $me = shift;
  my $species = shift;
  my $keyword = shift;
  my $statement = qq(SELECT accession, comment FROM genome WHERE comment like ? ORDER BY accession);
  my $info = $me->MySelect($statement,['%$keyword%']);
  my $return = {};
  foreach my $accession (@{$info}) {
    my $accession_id = $accession->[0];
    my $accession_comment = $accession->[1];
    $return->{$accession_id} = $accession_comment;
  }
  return($return);
}

sub Genome_to_Fasta {
  my $me = shift;
  my $output = shift;
  my $species = shift;
  my $statement = qq(SELECT DISTINCT accession, species, comment,  mrna_seq FROM genome);
  my $info;
  open(OUTPUT, ">blast/$output") or die("Could not open the fasta output file. $!");
  if (defined($species)) {
    $statement .= ' WHERE species = ?';
    $info = $me->MySelect($statement, [$species]);
  }
  else {
    $info = $me->MySelect($statement);
  }
  my $count = 0;
  foreach my $datum (@{$info}) {
    $count++;
    my $id = $count;
    my $accession = $datum->[0];
    my $species = $datum->[1];
    my $comment = $datum->[2];
    my $sequence = $datum->[3];
    print OUTPUT ">gi|$id|gb|$accession $species $comment
$sequence
";
  }
  close(OUTPUT);
}

sub Sequence_to_Fasta {
  my $me = shift;
  my $data = shift;
  my $fh = PRFdb::MakeTempfile();
  print $fh $data;
  my $filename = $fh->filename;
  close($fh);
  return($filename);
}

sub MakeTempfile {
  $File::Temp::KEEP_ALL = 1;
  my $fh = new File::Temp(DIR => $config->{workdir},
                          TEMPLATE => 'slip_XXXXX',
                          UNLINK => 0,
                          SUFFIX => '.fasta');
  return($fh);
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
    $statement = qq(SELECT * FROM boot WHERE accession = ? AND start = ? ORDER BY start);
  }
  else {
    $statement = qq(SELECT * from boot where accession = ? ORDER BY start);
  }
  my $info = $me->MySelect($statement, [$accession,$start], 'hash', 1);
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
  my $statement = qq(SELECT accession, species from genome where id = ?);
  my $data = $me->MySelect($statement, [$id]);
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
  my $statement = qq(INSERT into errors (message, accession) VALUES(?,?));
  ## Don't call Execute here or you may run into circular crazyness
  $me->MyConnect($statement,);
  my $sth = $dbh->prepare($statement);
  $sth->execute($message,$accession);
}

sub Get_Entire_Queue {
  my $me = shift;
  my $table = 'queue';
  if (defined($config->{queue_table})) {
    $table = $config->{queue_table};
  }
  my $return;
  my $statement = qq(SELECT id FROM $table WHERE checked_out='0');
  my $ids = $me->MySelect($statement);
  return($ids);
}

sub Set_Queue {
  my $me = shift;
  my $id = shift;
  my $table = 'queue';
  if (defined($config->{queue_table})) {
    $table = $config->{queue_table};
  }
  my $statement = qq(INSERT INTO $table (genome_id, checked_out, done) VALUES (?, 0, 0));
  $me->MyConnect($statement);
  my $sth = $dbh->prepare("$statement");
  $sth->execute($id) or PRF_Error("Could not execute \"$statement\" in Set_Queue");
  my $last_id = $me->Get_Last_Id();
  return($last_id);
}

sub Clean_Table {
  my $me = shift;
  my $type = shift;
  my $table = $type . '_' . $config->{species};
  my $statement = "DELETE from $table";
  $me->MyConnect($statement);
  my $sth = $dbh->prepare("$statement");
  my ($cp,$cf,$cl) = caller();
  $me->Execute($statement,[$cp,$cf,$cl]);
}

sub Drop_Table {
  my $me = shift;
  my $table = shift;
  my $statement = "DROP table $table";
  $me->MyConnect($statement);
  my $sth = $dbh->prepare("$statement");
  my ($cp,$cf,$cl) = caller();
  $me->Execute($statement,[$cp,$cf,$cl]);
}

sub FillQueue {
  my $me = shift;
  my $table = 'queue';
  if (defined($config->{queue_table})) {
    $table = $config->{queue_table};
  }
  $me->Create_Queue() unless($me->Tablep($table));
  my $best_statement = "INSERT into $table (genome_id, checked_out, done) SELECT id, 0, 0 from genome";
  $me->MyConnect($best_statement);
  my ($cp,$cf,$cl) = caller();
  $me->Execute($best_statement,[],[$cp,$cf,$cl]);
}

sub Copy_Genome {
  my $me = shift;
  my $old_db = shift;
  my $new_db = $config->{db};
  my $statement = qq/INSERT INTO ${new_db}.genome
(accession,species,genename,locus,ontology_function,ontology_component,ontology_process,version,comment,mrna_seq,protein_seq,orf_start,orf_stop,direction,omim_id)
SELECT accession,species,genename,locus,ontology_function,ontology_component,ontology_process,version,comment,mrna_seq,protein_seq,orf_start,orf_stop,direction,omim_id from ${old_db}.genome/;
  my ($cp,$cf,$cl) = caller();
  $me->Execute($statement,[],[$cp,$cf,$cl]);
}

sub Reset_Queue {
    my $me = shift;
    my $table = shift;
    my $complete = shift;
    if (!defined($table)) {
      if (defined($config->{queue_table})) {
        $table = $config->{queue_table};
      }
      else {
        $table = 'queue';
      }
    }

    my $statement = '';
    if (defined($complete)) {
      $statement = "UPDATE $table SET checked_out = '0', done = '0'";
    }
    else {
      $statement = "UPDATE $table SET checked_out = '0' where done = '0' and checked_out = '1'";
    }
    $me->MyConnect($statement);
    my ($cp,$cf,$cl) = caller();
    $me->Execute($statement,[],[$cp,$cf,$cl]);
}

sub Get_Input {
  my $me = shift;
  my $queue_table = $config->{queue_table};
  my $genome_table = $config->{genome_table};
  my $query = qq(SELECT ${queue_table}.id, ${queue_table}.genome_id, ${genome_table}.accession,
${genome_table}.species, ${genome_table}.mrna_seq, ${genome_table}.orf_start,
${genome_table}.direction FROM ${queue_table}, ${genome_table} WHERE ${queue_table}.checked_out = '0'
AND ${queue_table}.done = '0' AND ${queue_table}.genome_id = ${genome_table}.id LIMIT 1);
  my $ids = $me->MySelect($query, [], 'row');
  my $id = $ids->[0];
  my $genome_id = $ids->[1];
  my $accession = $ids->[2];
  my $species = $ids->[3];
  my $mrna_seq = $ids->[4];
  my $orf_start = $ids->[5];
  my $direction = $ids->[6];
  if (!defined($id) or $id eq ''
      or !defined($genome_id) or $genome_id eq '') {
    return(undef);
  }
  my $update = qq(UPDATE $queue_table SET checked_out='1', checked_out_time=current_timestamp() WHERE id=?);
  my ($cp, $cf, $cl) = caller();
  $me->Execute($update, [$id],[$cp, $cf, $cl]);
  my $return = {
                queue_id => $id,
                genome_id => $genome_id,
                accession => $accession,
                species => $species,
                mrna_seq => $mrna_seq,
                orf_start => $orf_start,
                direction => $direction,
               };
  return($return);
}

sub Grab_Queue {
  my $me = shift;
  my $queue = undef;
  if ($config->{check_webqueue} == 1) {
    ### Then first see if anything is in the webqueue
    $queue = $me->Get_Queue('webqueue');
    if (defined($queue)) {
      return($queue);
    }
    else {
      $queue = $me->Get_Queue();
      return($queue);
    }
  }
  else {
    $queue = $me->Get_Queue();
      return($queue);
  }
}

sub Get_Queue {
  my $me = shift;
  my $queue_name = shift;
  my $table = 'queue';
  if (defined($queue_name)) {
    $table = $queue_name;
  }
  elsif (defined($config->{queue_table})) {
    $table = $config->{queue_table};
  }
  unless ($me->Tablep($table)) {
    $me->Create_Queue($table);
#    $me->Copy_Queue($old_table, $table);
    $me->Reset_Queue($table, 'complete');
  }

  ## This id is the same id which uniquely identifies a sequence in the genome database
  my $single_id = qq(SELECT id, genome_id FROM $table WHERE checked_out = '0' LIMIT 1);
  my $ids = $me->MySelect($single_id, [], 'row');
  my $id = $ids->[0];
  my $genome_id = $ids->[1];
  if (!defined($id) or $id eq ''
      or !defined($genome_id) or $genome_id eq '') {
      ## This should mean there are no more entries to fold in the queue
      ## Lets check this for truth -- first see if any are not done
      my $done_id = qq(SELECT id, genome_id FROM $table WHERE done = '0' LIMIT 1);
      my $ids = $me->MySelect($done_id, [], 'row');
      $id = $ids->[0];
      $genome_id = $ids->[1];
      if (!defined($id) or $id eq '' or
	  !defined($genome_id) or $genome_id eq '') {
	  print "There are no more entries in the queue to test.\n";
	  return(undef);
      }
  }
  my $update = qq(UPDATE $table SET checked_out='1', checked_out_time=current_timestamp() WHERE id=?);
  my ($cp, $cf, $cl) = caller();
  $me->Execute($update, [$id],[$cp, $cf, $cl]);
  my $return = {
                queue_id => $id,
                genome_id => $genome_id,
               };
  return($return);
}

sub Copy_Queue {
  my $me = shift;
  my $old_table = shift;
  my $new_table = shift;
  my $statement = "INSERT INTO $new_table SELECT * FROM $old_table";
  my ($cp, $cf, $cl) = caller();
  $me->Execute($statement, [], [$cp, $cf, $cl]);
}

sub Done_Queue {
  my $me = shift;
  my $id = shift;
  my $table = 'queue';
  if (defined($config->{queue_table})) {
      $table = $config->{queue_table};
  }

  my $update = qq(UPDATE $table SET done='1', done_time=current_timestamp() WHERE genome_id=?);
  my ($cp, $cf, $cl) = caller();
  $me->Execute($update,[$id], [$cp, $cf, $cl]);
}

sub Import_Fasta {
  my $me = shift;
  my $file = shift;
  my $style = shift;
  my $startpos = shift;
  my @return_array;
  print "Starting Import_Fasta\n";
  open(IN, "<$file") or die "Could not open the input file. $!";
  my %datum = (accession => undef, genename => undef, version => undef, comment => undef, mrna_seq => undef);
  my $linenum = 0;
  while (my $line = <IN>) {
      $linenum++;
      chomp $line;
      if ($line =~ /^\>/) {

	  ## Do the actual insertion here, regardless of style
	  if ($linenum > 1) {
	      $datum{orf_start} = 1;
	      $datum{orf_stop} = length($datum{mrna_seq});
	      my $genome_id = $me->Insert_Genome_Entry(\%datum);
	      my $queue_id = $me->Set_Queue($genome_id, \%datum);
	      print "Added $queue_id\n";
	      push(@return_array, $queue_id);
	  }

	  if (defined($style)) {
	      if ($style eq 'sgd') {
		  %datum = (accession => undef, 
			    genename => undef,
			    version => undef,
			    comment => undef,
			    mrna_seq => undef);
		  my ($fake_accession, $comment) = split(/\,/, $line);
		  my ($accession, $genename) = split(/ /, $fake_accession);
		  $accession =~ s/^\>//g;
		  $datum{accession} = $accession;
		  $datum{genename} = $genename;
		  $datum{comment} = $comment;
		  $datum{genename} = $genename;
		  $datum{protein_seq} = '';
		  $datum{direction} = 'forward';
		  $datum{defline} = $line;
	      } ## End if the style is sgd

	      elsif ($style eq 'mgc') {
		  %datum = (accession => undef,
			    genename => undef,
			    version => undef,
			    comment => undef,
			    mrna_seq => undef
		      );
		  my ($gi_trash, $gi_id, $gb_trash, $accession_version, $comment) =
		      split(/\|/, $line);
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
		  $datum{protein_seq} = '';
		  $datum{direction} = 'forward';
		  $datum{defline} = $line;
	      }
	      else {
		  print "No style.\n";
	      }
	  } ## End if the style is defined.
	  else {
	      print "Style is not defined.\n";
	  }

      }  ## End if you are on a > line

      else {
	  $line =~ s/\s//g;
	  $line =~ s/\d//g;
	  $datum{mrna_seq} .= $line;
	  ## The line after every Import_CDS had better clear datum{mrna_seq} or the sequence
	  ## will grow with every new sequence.
      } ## Not an accession line
  } ## End looking at every line.
  close(IN);
  $datum{orf_start} = 0;
  $datum{orf_stop} = length($datum{mrna_seq});
  my $genome_id = $me->Insert_Genome_Entry(\%datum);
  my $queue_id = $me->Set_Queue($genome_id, \%datum);
  print "Added $queue_id\n";
  push(@return_array, $queue_id);
  print "Last test: @return_array\n";
  return(\@return_array);
}

sub Import_RawSeq {
    my $me = shift;
    my $datum = shift;
    my $startpos = shift;
    my $accession = $datum->{accession};
    my $comment = $datum->{comment};
    my $species = $datum->{species};
    my $genename = $datum->{genename};
    my $mrna_seq = $datum->{mrna_seq};
    my $orf_start = (defined($startpos) ? $startpos : 0);
    my $orf_stop = length($mrna_seq);    
}

sub Import_CDS {
  my $me = shift;
  my $accession = shift;
  my $startpos = shift;
  my $return = '';
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
  my $defline = "lcl||gb|$accession|species|$full_comment\n";
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
#    print "START: $orf_start STOP: $orf_stop $feature->{_location}{_strand}\n";
    ### $feature->{_location}{_strand} == -1 or 1 depending on the strand.
    my $direction;
    if(!defined($feature->{_location}{_strand})) {
	$direction = 'forward';
    }
    elsif ($feature->{_location}{_strand} == 1) {
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
      print PRF_Error("WTF: Direction is not forward or reverse");
      $direction = 'forward';
    }
    ### Don't change me, this is provided by genbank
    ### FINAL TEST IF $startpos is DEFINED THEN OVERRIDE WHATEVER YOU FOUND
    if (defined($startpos)) {
      $orf_start = $startpos;
    }
    my $mrna_seqlength = length($tmp_mrna_sequence);
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
                 defline => $defline,
                );
    my $genome_id = $me->Insert_Genome_Entry(\%datum);
    if (defined($genome_id)) {
      $return .= "Inserting $mrna_seqlength bases into the genome table with id: $genome_id\n";
       $me->Set_Queue($genome_id, \%datum);
    }
    else {
      $return .= "Did not insert anything into the genome table.\n";
    }
    print $return;
  }
  return($return);
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

sub Get_OMIM {
  my $me = shift;
  my $id = shift;;
  my $statement = qq(SELECT omim_id FROM genome where id=?);
  my $info = $me->MySelect($statement,[$id]);
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
    $statement = qq(UPDATE genome SET omim_id = ? WHERE id = ?);
    my ($cp, $cf, $cl) = caller();
    $me->Execute($statement,[$omim_id,$id],[$cp,$cf,$cl]);
    return($omim_id);
  }
}

sub Get_Sequence {
  my $me = shift;
  my $accession = shift;
  my $statement = qq(SELECT mrna_seq FROM genome WHERE accession = ?);
  my $info = $me->MySelect($statement,[$accession]);
  my $sequence = $info->[0]->[0];
  if ($sequence) {
	return($sequence);
  }
  else {
	return(undef);
  }
}

sub Get_Seqlength {
  my $me = shift;
  my $mfe_id = shift;
  my $statement = qq(SELECT seqlength FROM mfe WHERE id = ?);
  my $info = $me->MySelect($statement,[$mfe_id]);
  my $seqlength = $info->[0]->[0];
  if ($seqlength) {
	return($seqlength);
  }
  else {
	return(undef);
  }
}

sub Get_Sequence_from_id {
    my $me = shift;
    my $id = shift;
    my $statement = qq(SELECT mrna_seq FROM genome WHERE id = ?);
    my $info = $me->MySelect($statement,[$id]);
    my $sequence = $info->[0]->[0];
    if ($sequence) {
	return($sequence);
    }
    else {
	return(undef);
    }
}

sub Get_Sequence_From_Fasta {
    my $filename = shift;
    my $return = '';
    open(IN, "<$filename") or print "Could not open $filename in Get_Sequence_From_Fasta $!\n";
    while (my $line = <IN>) {
	next if ($line =~ /^\>/);
	$return .= $line;
    }
    close(IN);
    return($return);
}

sub Get_MFE_ID {
    my $me = shift;
    my $genome_id = shift;
    my $start = shift;
    my $seqlength = shift;
    my $algorithm = shift;
    my $statement = qq(SELECT id FROM mfe WHERE genome_id = ? AND start = ? AND seqlength = ? AND algorithm = ? LIMIT 1);
    my $info = $me->MySelect($statement,[$genome_id,$start,$seqlength,$algorithm]);
    my $mfe = $info->[0]->[0];
    return($mfe);
}

sub Get_Num_RNAfolds {
  my $me = shift;
  my $algo = shift;
  my $genome_id = shift;
  my $slipsite_start = shift;
  my $table = shift;
  $table = 'mfe' unless (defined($table));
  my $return = {};
  my $sequence_length = $config->{seqlength} + 1;
  my $statement = qq(SELECT count(id) FROM $table WHERE genome_id = ? AND algorithm = ? AND start = ? AND seqlength = ?);
  my $info = $me->MySelect($statement,[$genome_id,$algo,$slipsite_start,$sequence_length]);
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
  my $sequence_length = $config->{seqlength} + 1;
  my $statement = qq(SELECT count(id) FROM boot WHERE genome_id = ? and start = ? and seqlength = ?);
  my $info = $me->MySelect($statement,[$genome_id,$start,$sequence_length]);
  my $count = $info->[0]->[0];
  return($count);
}

sub Get_mRNA {
  my $me = shift;
  my $accession = shift;
  my $statement = qq(SELECT mrna_seq, orf_start, orf_stop FROM genome WHERE accession = ?);
  my $info = $me->MySelect($statement, [$accession], 'hash');
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
  my $statement = qq(SELECT mrna_seq, orf_start, orf_stop FROM genome WHERE accession = ?);
  my $info = $me->MySelect($statement,[$accession], 'hash');
  my $mrna_seq = $info->{mrna_seq};
  ### A PIECE OF CODE TO HANDLE PULLING SUBSEQUENCES FROM CDS
  my $start = $info->{orf_start} - 1;
  my $stop = $info->{orf_stop} - 1;
  my $offset = $stop - $start;
  #  my $sequence = substr($mrna_seq, $start, $offset);  ## If I remove the substring
  ## Then it should return from the start codon to the end of the mRNA which is good
  ## For searching over viral sequence!
  my $sequence = substr($mrna_seq, $start);
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
  ## OPEN IN in Get_Slippery_From_RNAMotif
  while(my $line = <IN>) {
      chomp $line;
      if ($line =~ /^\>/) {
	  my ($slippery, $crap) = split(/ /, $line);
	  $slippery =~ s/\>//g;
	  return($slippery);
      }
  }
  close(IN);
  ## CLOSE IN in Get_Slippery_From_RNAMotif
  return(undef);
}

sub Insert_Genome_Entry {
  my $me = shift;
  my $datum = shift;
  ## Check to see if the accession is already there
  my $check = qq(SELECT id FROM genome where accession=?);
  my $info = $me->MySelect($check,[$datum->{accession}]);
  my $already_id = $info->[0]->[0];
  if (defined($already_id)) {
      print "The accession $datum->{accession} is already in the database with id: $already_id\n";
      return(undef);
  }
  my $statement = qq(INSERT INTO genome
(accession, species, genename, version, comment, mrna_seq, protein_seq, orf_start, orf_stop, direction)
VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?));
  my ($cp, $cf, $cl) = caller();
  $me->Execute($statement,
  [$datum->{accession},$datum->{species},$datum->{genename},$datum->{version},$datum->{comment},$datum->{mrna_seq},$datum->{protein_seq},$datum->{orf_start},$datum->{orf_stop},$datum->{direction}],
  [$cp,$cf,$cl]);
    ## The following line is very important to ensure that multiple 
    ##calls to this don't end up with
    ## Increasingly long sequences
  foreach my $k (keys %{$datum}) { $datum->{$k} = undef; }
  my $last_id = $me->Get_Last_Id();
  return($last_id);
}

sub Insert_Noslipsite {
    my $me = shift;
    my $accession = shift;
    my $statement = "INSERT INTO noslipsite
(accession)
VALUES($accession)";
  my ($cp, $cf, $cl) = caller();
  $me->Execute($statement,[$cp,$cf,$cl]);
  my $last_id = $me->Get_Last_Id();
  return($last_id);
}

sub Get_Pknots {
  my $me = shift;
  my $identifier = shift;  ## { genome_id => #, species => #, accession => #, start => # }
  my $statement = '';
  my $info;
  if (defined($identifier->{genome_id})) {
    $statement = qq(SELECT id, genome_id, species, accession, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode FROM mfe where genome_id = ?);
    $info = $me->MySelect($statement, [$identifier->{genome_id}], [qq(id genome_id species accession start slipsite seqlength sequence output parsed parens mfe pairs knotp barcode)]);
  }
  elsif (defined($identifier->{accession} and defined($identifier->{start}))) {
    $statement = qq(SELECT id, genome_id, species, accession, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode FROM mfe where accession = ? and start = ?);
    $info = $me->MySelect($statement, [$identifier->{accession}, $identifier->{start}], [qq(id genome_id species accession start slipsite seqlength sequence output parsed parens mfe pairs knotp barcode)]);
  }
  return($info);
}

sub Put_Nupack {
    my $me = shift;
    my $data = shift;
    my $table = shift;
    if (defined($table) and $table eq 'landscape') {
      $me->Put_MFE_Landscape('nupack', $data);
    }
    elsif (defined($table)) {
      $me->Put_MFE('nupack', $data, $table);
    }
    else {
      $me->Put_MFE('nupack', $data);
    }
}

sub Put_Pknots {
  my $me = shift;
  my $data = shift;
  my $table = shift;
  if (defined($table) and $table eq 'landscape') {
    $me->Put_MFE_Landscape('pknots', $data);
  }
  elsif (defined($table)) {
    $me->Put_MFE('pknots', $data, $table);
  }
  else {
    $me->Put_MFE('pknots', $data);
  }
}

sub Put_MFE {
  my $me = shift;
  my $algo = shift;
  my $data = shift;
  my $table = shift;
  $table = 'mfe' unless(defined($table));
  ## What fields do we want to fill in this MFE table?
  my @pknots = ('genome_id','species','accession','start','slipsite','seqlength','sequence','output','parsed','parens','mfe','pairs','knotp','barcode');
  my $errorstring = Check_Insertion(\@pknots, $data);
  if (defined($errorstring)) {
    $errorstring = "Undefined value(s) in Put_MFE: $errorstring";
    PRF_Error($errorstring, $data->{species}, $data->{accession});
  }
  my $statement = qq(INSERT INTO $table (genome_id, species, algorithm, accession, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?));
  my ($cp, $cf, $cl) = caller();
  $me->Execute($statement,
  [$data->{genome_id},$data->{species},$algo,$data->{accession},$data->{start},$data->{slipsite},$data->{seqlength},$data->{sequence},$data->{output},$data->{parsed},$data->{parens},$data->{mfe},$data->{pairs},$data->{knotp},$data->{barcode}],
  [$cp,$cf,$cl],
  $data->{genome_id});
  my $dbh = DBI->connect($me->{dsn}, $config->{user}, $config->{pass});
  my $get_inserted_id = qq(SELECT LAST_INSERT_ID());
  my $id = $me->MySelect($get_inserted_id,[]);
  return($id->[0]->[0]);
}  ## End of Put_MFE

sub Put_MFE_Landscape {
  my $me = shift;
  my $algo = shift;
  my $data = shift;
  ## What fields do we want to fill in this MFE table?
  my @pknots = ('genome_id','species','accession','start','seqlength','sequence','output','parsed','parens','mfe','pairs','knotp','barcode');
  my $errorstring = Check_Insertion(\@pknots, $data);
  if (defined($errorstring)) {
    $errorstring = "Undefined value(s) in Put_MFE_Landscape: $errorstring";
    Sec_Error($errorstring, $data->{species}, $data->{accession});
  }
  my $statement = qq(INSERT INTO landscape (genome_id, species, algorithm, accession, start, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?));
  my ($cp, $cf, $cl) = caller();
  $me->Execute($statement,
  [$data->{genome_id},$data->{species},$algo,$data->{accession},$data->{start},$data->{seqlength},$data->{sequence},$data->{output},$data->{parsed},$data->{parens},$data->{mfe},$data->{pairs},$data->{knotp},$data->{barcode}],
  [$cp,$cf,$cl],
  $data->{genome_id});
  my $dbh = DBI->connect($me->{dsn}, $config->{user}, $config->{pass});
  my $get_inserted_id = qq(SELECT LAST_INSERT_ID());
  my $id = $me->MySelect($get_inserted_id);
  return($id->[0]->[0]);
}  ## End put_mfe_landscape

sub Put_Stats {
  my $me = shift;
  my $data= shift;
  foreach my $species (@{$data->{species}}) {
    foreach my $seqlength (@{$data->{seqlength}}) {
      foreach my $max_mfe (@{$data->{max_mfe}}) {
        foreach my $algorithm (@{$data->{algorithm}}) {
          my $statement = qq/INSERT INTO stats
(species, seqlength, max_mfe, algorithm, num_sequences, avg_mfe, stddev_mfe, avg_pairs, stddev_pairs, num_sequences_noknot, avg_mfe_noknot, stddev_mfe_noknot, avg_pairs_noknot, stddev_pairs_noknot, num_sequences_knotted, avg_mfe_knotted, stddev_mfe_knotted, avg_pairs_knotted, stddev_pairs_knotted)
VALUES
('$species', '$seqlength', '$max_mfe', '$algorithm',
(SELECT count(id) FROM mfe WHERE algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength' AND mfe <= '$max_mfe'),
(SELECT avg(mfe) FROM mfe WHERE algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength' AND mfe <= '$max_mfe'),
(SELECT stddev(mfe) FROM mfe WHERE algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength' AND mfe <= '$max_mfe'),
(SELECT avg(pairs) FROM mfe WHERE algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength' AND mfe <= '$max_mfe'),
(SELECT stddev(pairs) FROM mfe WHERE algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength' AND mfe <= '$max_mfe'),
(SELECT count(id) FROM mfe WHERE knotp = '0' AND algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength' AND mfe <= '$max_mfe'),
(SELECT avg(mfe) FROM mfe WHERE knotp = '0' AND algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength' AND mfe <= '$max_mfe'),
(SELECT stddev(mfe) FROM mfe WHERE knotp = '0' AND algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength' AND mfe <= '$max_mfe'),
(SELECT avg(pairs) FROM mfe WHERE knotp = '0' AND algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength' AND mfe <= '$max_mfe'),
(SELECT stddev(pairs) FROM mfe WHERE knotp = '0' AND algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength' AND mfe <= '$max_mfe'),
(SELECT count(id) FROM mfe WHERE knotp = '1' AND algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength' AND mfe <= '$max_mfe'),
(SELECT avg(mfe) FROM mfe WHERE knotp = '1' AND algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength' AND mfe <= '$max_mfe'),
(SELECT stddev(mfe) FROM mfe WHERE knotp = '1' AND algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength' AND mfe <= '$max_mfe'),
(SELECT avg(pairs) FROM mfe WHERE knotp = '1' AND algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength' AND mfe <= '$max_mfe'),
(SELECT stddev(pairs) FROM mfe WHERE knotp = '1' AND algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength' AND mfe <= '$max_mfe'))/;
          my ($cp, $cf, $cl) = caller();
          $me->Execute($statement, [], [$cp,$cf,$cl]);
        }
      }
    }
  }
}

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
      $mfe_id = $data->{$mfe_method}->{$rand_method}->{stats}->{mfe_id};
      my $start = $data->{$mfe_method}->{$rand_method}->{stats}->{start};
      my $seqlength = $data->{$mfe_method}->{$rand_method}->{stats}->{seqlength};
      my @boot = ('genome_id');
      my $errorstring = Check_Insertion(\@boot, $data);
      if (defined($errorstring)) {
        $errorstring = "Undefined value(s) in Put_Boot: $errorstring";
        PRF_Error($errorstring, $species, $accession);
      }
      my $statement = qq(INSERT INTO boot 
(genome_id, mfe_id, species, accession, start, seqlength, iterations, rand_method, mfe_method, mfe_mean, mfe_sd, mfe_se, pairs_mean, pairs_sd, pairs_se, mfe_values)
VALUES
(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?));
      my $undefined_values = Check_Defined({genome_id=>$data->{genome_id}, mfe_id => $mfe_id, species => $species, accession => $accession, start => $start, seqlength => $seqlength, iterations => $iterations, rand_method => $rand_method, mfe_method => $mfe_method, mfe_mean => $mfe_mean, mfe_sd => $mfe_sd, mfe_se => $mfe_se, pairs_mean => $pairs_mean, pairs_sd => $pairs_sd, pairs_se => $pairs_se, mfe_values => $mfe_values});
      if ($undefined_values) {
        $errorstring = "An error occurred in Put_Boot, undefined values: $undefined_values\n";
        PRF_Error($errorstring, $species, $accession);
        print "$errorstring, $species, $accession\n";
      }
      my ($cp, $cf, $cl) = caller();
      $me->Execute($statement,
[$data->{genome_id},$mfe_id,$species,$accession,$start,$seqlength,$iterations,$rand_method,$mfe_method,$mfe_mean,$mfe_sd,$mfe_se,$pairs_mean,$pairs_sd,$pairs_se,$mfe_values],
[$cp,$cf,$cl]);
   }  ### Foreach random method
  } ## Foreach mfe method
}  ## End of Put_Boot

sub Put_Overlap {
    my $me = shift;
    my $data = shift;
    my $statement = qq(INSERT INTO overlap
(genome_id, species, accession, start, plus_length, plus_orf, minus_length, minus_orf) VALUES
(?,?,?,?,?,?,?,?));
    my ($cp, $cf, $cl) = caller();
    $me->Execute($statement,
[$data->{genome_id},$data->{species},$data->{accession},$data->{start},$data->{plus_length},$data->{plus_orf},$data->{minus_length},$data->{minus_orf}],
[$cp,$cf,$cl]);
    my $id = $data->{overlap_id};
    return($id);
}  ## End of Put_Overlap

sub Fill_Globals {
  my $me = shift;
  ## First fill out the means mfe for every sequence in the db
#  my $statement = qq(SELECT average(SELECT mfe FROM mfe
}

#################################################
### Functions used to create the prfdb tables
#################################################

sub Write_SQL {
    my $statement = shift;
    my $genome_id = shift;
    open(SQL, ">>failed_sql_statements.txt");
    ## OPEN SQL in Write_SQL
    my $string = "$statement" . ";\n";
    print SQL "$string";

    if (defined($genome_id)) {
	my $second_statement = "UPDATE queue set done='0', checked_out='0' where genome_id = '$genome_id';\n";
	print SQL "$second_statement";
    }
    close(SQL);
    ## CLOSE SQL in Write_SQL
}

sub Get_Last_Id {
    my $me = shift;
    my $statement = 'select last_insert_id()';
    my $id = $me->MySelect($statement);
    return($id->[0]->[0]);
}

sub Check_Genome_Table {
  my $me = shift;
  my $species = shift;
  my $table = 'genome_' . $species;
  my $statement = "SHOW TABLES like '$table'";  
  my $info = $me->MySelect($statement,[]);
  if (scalar(@{$info}) == 0) {
    return(0);
  }
  else {
    return(1);
  }
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

sub Check_Defined {
    my $args = shift;
    my $return = '';
    foreach my $k (keys %{$args}) {
	if (!defined($args->{$k})) {
		$return .= "$k,";
	}
    }
    return($return);
}

sub Tablep {
    my $me = shift;
    my $table = shift;
    my $statement = qq(SHOW TABLES LIKE ?);
    my $info = $me->MySelect($statement, [$table]);
    my $answer = scalar(@{$info});
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

sub Execute {
    my $me = shift;
    my $statement = shift;
    my $vars = shift;
    my $caller = shift;
    my $genome_id = shift;
    $me->MyConnect($statement);
    my $errorstr;
    my $retry_count = 0;
    my $success = 0;
    my $sth = $dbh->prepare($statement) or
	$errorstr = "Error at: line $caller->[2] of $caller->[0]: Could not prepare: $statement " . $dbh->errstr , Write_SQL($statement, $genome_id),  PRF_Error($errorstr);
    my $rc = $sth->execute(@{$vars});
    if (!$rc) {
      if ($dbh->errstr =~ /(?:lost connection|mysql server has gone away)/i) {
        while ($retry_count < 5 and $success == 0) {
          $retry_count++;
          sleep 120;
          $me->MyConnect($statement);
          $sth = $dbh->prepare($statement);
          $rc = $sth->execute(@{$vars});
          if ($rc) {
            $success = 1;
          }  ## End checking for success in the 5 try while loop
        }    ## End the 5 try while loop
      }      ## End the if checking for a lost connection
      elsif ($dbh->errstr =~ /(?:called with)/i) {
	  $errorstr = "Error at: line $caller->[2] of $caller->[0]: Could not execute: $statement\n";
	  print $errorstr;
      }
      elsif ($dbh->errstr =~ /(?:You have an error)/i) {
	  $errorstr = "Error at: line $caller->[2] of $caller->[0]: Could not execute: $statement\n";
	  print $errorstr;
      }
    }        ## End the top level check for success.

    if ($success == 0 and $retry_count >= 5) {
      $errorstr = "Tried to connect 5 times: " . $dbh->errstr , Write_SQL($statement, $genome_id), PRF_Error($errorstr);
      die("Could not connect after 5 tries.");
    }
    return($rc);
}

sub Create_Genome {
  my $me = shift;
  my $statement = qq/CREATE table genome (
id $config->{sql_id},
accession $config->{sql_accession},
species $config->{sql_species},
genename $config->{sql_genename},
locus text,
ontology_function text,
ontology_component text,
ontology_process text,
version int,
comment $config->{sql_comment},
defline blob not null,
mrna_seq longblob not null,
protein_seq text,
orf_start int,
orf_stop int,
direction char(7) DEFAULT 'forward',
omim_id varchar(30),
lastupdate $config->{sql_timestamp},
INDEX(accession),
INDEX(genename),
PRIMARY KEY (id))/;
  my ($cp, $cf, $cl) = caller();
  $me->Execute($statement,[],[$cp,$cf,$cl]);
}

sub Create_NoSlipsite {
    my $me = shift;
    my $statement = qq/CREATE table noslipsite (
id $config->{sql_id},
accession $config->{sql_accession},
lastupdate $config->{sql_timestamp},
PRIMARY KEY (id))/;
    my ($cp, $cf, $cl) = caller();
    $me->Execute($statement, [], [$cp,$cf,$cl]);
}


sub Create_Evaluate {
  my $me = shift;
  my $statement = qq(CREATE table evaluate (
id $config->{sql_id},
species $config->{sql_species},
accession $config->{sql_accession},
start int,
length int,
pseudoknot bool,
min_mfe float,
PRIMARY KEY (id)));
  my ($cp, $cf, $cl) = caller();
  $me->Execute($statement,[],[$cp,$cf,$cl]);
}

sub Create_Globals {
  my $me = shift;
  my $statement = "CREATE TABLE globals (
id $config->{sql_id},
seqlength text,
species text,
mean_mfe float,
primary key(id))";
  $me->Execute($statement);
}

sub Create_Stats {
  my $me = shift;
  my $statement = qq(CREATE table stats (
id $config->{sql_id},
species $config->{sql_species},
seqlength int,
max_mfe float,
algorithm varchar(10),
num_sequences int,
avg_mfe float,
stddev_mfe float,
avg_pairs float,
stddev_pairs float,
num_sequences_noknot int,
avg_mfe_noknot float,
stddev_mfe_noknot float,
avg_pairs_noknot float,
stddev_pairs_noknot float,
num_sequences_knotted int,
avg_mfe_knotted float,
stddev_mfe_knotted float,
avg_pairs_knotted float,
stddev_pairs_knotted float,
PRIMARY KEY (id)));
  my ($cp, $cf, $cl) = caller();
  $me->Execute($statement,[],[$cp,$cf,$cl]);
}

sub Create_Overlap {
    my $me = shift;
    my $statement = qq(CREATE table overlap (
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
PRIMARY KEY (id)));
    my ($cp, $cf, $cl) = caller();
    $me->Execute($statement,[],[$cp,$cf,$cl]);
}

### prfdb05 queue should be recreated.
sub Create_Queue {
    my $me = shift;
    my $table = shift;
    if (!defined($table)) {
      if (defined($config->{queue_table})) {
        $table = $config->{queue_table};
      }
      else {
        $table = 'queue';
      }
    }
    my $statement = qq\CREATE TABLE $table (
id $config->{sql_id},
genome_id int,
checked_out bool,
checked_out_time timestamp default 0,
done bool,
done_time timestamp default 0,
PRIMARY KEY (id))\;
    my ($cp, $cf, $cl) = caller();
    $me->Execute($statement,[],[$cp, $cf, $cl]);
}

sub Create_MFE {
  my $me = shift;
  my $statement = qq\CREATE TABLE mfe (
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
INDEX(genome_id),
INDEX(accession),
PRIMARY KEY(id))\;
  my ($cp, $cf, $cl) = caller();
  $me->Execute($statement,[],[$cp,$cf,$cl]);
}

sub Create_Landscape {
  my $me = shift;
  my $statement = qq\CREATE TABLE landscape (
id $config->{sql_id},
genome_id int,
species $config->{sql_species},
accession $config->{sql_accession},
algorithm char(10),
start int,
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
INDEX(genome_id),
INDEX(accession),
PRIMARY KEY(id))\;
  my ($cp, $cf, $cl) = caller();
  $me->Execute($statement,[],[$cp,$cf,$cl]);
}

sub Create_Boot {
  my $me = shift;
  my $statement = qq\CREATE TABLE boot (
id $config->{sql_id},
genome_id int,
mfe_id int,
species $config->{sql_species},
accession $config->{sql_accession},
start int,
seqlength int,
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
INDEX(genome_id),
INDEX(mfe_id),
INDEX(accession),
PRIMARY KEY(id))\;
  my ($cp, $cf, $cl) = caller();
  $me->Execute($statement,[],[$cp,$cf,$cl]);
}

sub Create_Analysis {
    my $me = shift;
    my $statement = qq\CREATE TABLE analysis (
id $config->{sql_id},
genome_id int,
mfe_source varchar(20),
mfe_id int,
boot_id int,
accession $config->{sql_accession},
image blob,
z_score float,
lastupdate $config->{sql_timestamp},
PRIMARY KEY(id))\;
    my ($cp, $cf, $cl) = caller();
    $me->Execute($statement,[],[$cp,$cf,$cl]);
}

sub Create_Errors {
  my $me = shift;
  my $statement = qq\CREATE table errors (
id $config->{sql_id},
time $config->{sql_timestamp},
message blob,
accession $config->{sql_accession},
PRIMARY KEY(id))\;
  my ($cp, $cf, $cl) = caller();
  $me->Execute($statement,[],[$cp,$cf,$cl]);
}

sub Create_TermCount {
  my $me = shift;
  my $statement = qq\CREATE table termcount (
id $config->{sql_id},
term text,
count int,
PRIMARY KEY(id))\;
  my ($cp, $cf, $cl) = caller();
  $me->Execute($statement,[],[$cp,$cl,$cl]);
}

1;
