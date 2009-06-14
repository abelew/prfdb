package PRFdb;
use strict;
use DBI;
use PRFConfig qw / PRF_Error PRF_Out /;
use SeqMisc;
use File::Temp qw / tmpnam /;
use Fcntl ':flock';    # import LOCK_* constants
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
    dsn  => $config->{dsn},
    user => $config->{user},
    num_retries => 60,
    retry_time => 15,
  }, $class;

  if ($config->{checks}) {
    $me->Create_Genome() unless ($me->Tablep('genome'));
    $me->Create_Queue() unless ($me->Tablep($config->{queue_table}));
    $me->Create_Boot() unless ($me->Tablep('boot'));
    $me->Create_MFE() unless ($me->Tablep('mfe'));
#    $me->Create_Landscape() unless ($me->Tablep('landscape'));
    $me->Create_Errors() unless ($me->Tablep('errors'));
    $me->Create_NoSlipsite() unless ($me->Tablep('noslipsite'));
  }
  $me->{errors} = undef;
  return ($me);
}

sub Disconnect {
  $dbh->disconnect() if (defined($dbh));
}

sub MySelect {
  my $me = shift;
  my $input = shift;
  my $input_type = ref($input);
  my ($statement, $vars, $type, $descriptor);
  if (!defined($input_type) or $input_type eq '' or $input_type eq 'SCALAR') {
      $statement = $input;
  }
  else {
      $statement = $input->{statement};
      $vars = $input->{vars};
      $type = $input->{type};
      $descriptor = $input->{descriptor};
  }

  my $return = undef;
  if (!defined($statement)) {
    die("No statement in MySelect");
  }

  my $dbh = $me->MyConnect($statement);
  my $selecttype;
  my $sth = $dbh->prepare($statement);
  my $rv;
  if (defined($vars)) {
      $rv = $sth->execute(@{$vars});
  }
  else {
      $rv = $sth->execute();
  }

  if (!defined($rv)) {
      print STDERR "Execute failed for: $statement
from: $input->{caller}
with: error $DBI::errstr\n";
      $me->{errors}->{statement} = $statement;
      $me->{errors}->{errstr} = $DBI::errstr;
      if (defined($input->{caller})) {
	  $me->{errors}->{caller} = $input->{caller};
      }
      return(undef);
  }

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
  elsif (defined($type) and $type eq 'single') {
      my $tmp = $sth->fetchrow_arrayref();
      $return = $tmp->[0];
  }
  elsif (defined($type) and $type eq 'flat') {
      my $selecttype = 'flat';
      my @ret = ();
      my $data = $sth->fetchall_arrayref();
      if (!defined($data->[0])) {
	  return (undef);
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
  }    ## Endif flat
  elsif (defined($type) and $type eq 'list_of_hashes') { 
      $return = $sth->fetchall_arrayref({});
      $selecttype = 'selectall_arrayref({})';     
  }
  ## If only $type is defined, do a selectrow_hashref
  elsif (defined($type)) {    ## Usually defined as 'hash'
      $return = $sth->fetchrow_hashref();
      $selecttype = 'selectrow_hashref';
  }
  ## The default is to do a selectall_arrayref
  else {
      $return = $sth->fetchall_arrayref();
      $selecttype = 'selectall_arrayref';
  }

  if (defined($DBI::errstr)) {
      print STDERR "Error for: $statement
from: $input->{caller}
with: error $DBI::errstr\n";
      $me->{errors}->{statement} = $statement;
      $me->{errors}->{errstr} = $DBI::errstr;
      if (defined($vars->{caller})) {
	  $me->{errors}->{caller} = $vars->{caller};
      }
      Write_SQL($statement);
  }
  return ($return);
}

sub MyExecute {
  my $me = shift;
  my $input = shift;
  my $input_type = ref($input);
  my $statement;
  if (!defined($input_type) or $input_type eq '' or $input_type eq 'SCALAR') {
      $statement = $input;
      $input = undef;
  }
  else {
      $statement = $input->{statement};
  }
  
  my $dbh = $me->MyConnect($statement);
  my $sth = $dbh->prepare($statement);
  my $rv;
  if (defined($input->{vars})) {
      $rv = $sth->execute( @{$input->{vars}});
  }
  else {
      $rv = $sth->execute();
  }
  
  my $rows = 0;
  if (!defined($rv)) {
      print STDERR "Execute failed for: $statement
from: $input->{caller}
with: error $DBI::errstr\n";
      $me->{errors}->{statement} = $statement;
      $me->{errors}->{errstr} = $DBI::errstr;
      if (defined($input->{caller})) {
	  $me->{errors}->{caller} = $input->{caller};
      }
      return(undef);
  }
  else {
      $rows = $dbh->rows();
  }
  return($rows);
}

sub MyGet {
    my $me = shift;
    my $vars = shift;
    my $final_statement = qq(SELECT);
    my $tables = $vars->{table};
    delete($vars->{table});
    my $order = $vars->{order};
    delete($vars->{order});
    my @select_columns = ();
    my $select_count = 0;
    foreach my $criterion (keys %{$vars}) {
	if (!defined($vars->{$criterion})) {
	    $select_count++;
	    push(@select_columns, $criterion);
	    $final_statement .= "$criterion, "
	}
    }
    if ($select_count == 0) {
	$final_statement .= "* ";
    }
    $final_statement =~ s/, $/ /g;
    $final_statement .= "FROM $tables WHERE ";
    my $criteria_count = 0;
    foreach my $criterion (keys %{$vars}) {
	if (defined($vars->{$criterion})) {
	    $criteria_count++;
	    if ($vars->{$criterion} =~ /\s+/) {
		$final_statement .= "$criterion $vars->{$criterion} AND ";
	    }
	    else {
		$final_statement .= "$criterion = '$vars->{$criterion}' AND ";
	    }
	}
    }
    if ($criteria_count == 0) {
	$final_statement =~ s/ WHERE $//g;
    }
    $final_statement =~ s/ AND $//g;
    if (defined($order)) {
	$final_statement .= " ORDER BY $order";
    }

    my $dbh = $me->MyConnect($final_statement);
    my $stuff = $me->MySelect({ statement => $final_statement,});

    print "Column order: @select_columns\n";
    my $c = 1;
    foreach my $datum (@{$stuff}) {
	print "$c\n";
	$c++;
	foreach my $c (0 .. $#select_columns) {
	    print "  ${select_columns[$c]}: $datum->[$c]\n";
	}
    }
    return($final_statement);
}

sub MyConnect {
  my $me = shift;
  my $statement = shift;
  $dbh = DBI->connect_cached($me->{dsn}, $config->{user}, $config->{pass}, { AutoCommit => 1},);
  my $retry_count = 0;
  if (!defined($dbh) or
       (defined($DBI::errstr) and
		$DBI::errstr =~ m/(?:lost connection|Unknown MySQL server host|mysql server has gone away)/ix)) {
      my $success = 0;
      while ($retry_count < $me->{num_retries} and $success == 0) {
	  $retry_count++;
	  sleep $me->{retry_time};
	  $dbh = DBI->connect_cached($me->{dsn}, $config->{user}, $config->{pass});
	  if (defined($dbh) and
	      (!defined($dbh->errstr) or $dbh->errstr eq '')) {
	      $success++;
	  }
      }
  }

  if (!defined($dbh)) {
      $me->{errors}->{statement} = $statement, Write_SQL($statement) if (defined($statement));
      $me->{errors}->{errstr} = $DBI::errstr;
      my $time = localtime();

      my $error = qq($time: Could not open cached connection: $me->{dsn}, $DBI::err.
$DBI::errstr);
      die($error);
  }
  $dbh->{mysql_auto_reconnect} = 1;
  $dbh->{InactiveDestroy} = 1;
  return ($dbh);
}

sub Get_GenomeId_From_Accession {
  my $me = shift;
  my $accession = shift;
  my $info = $me->MySelect({
      statement => qq(SELECT id FROM genome WHERE accession = ?),
      vars => [$accession],
      type => 'single'});
  return ($info);
}

sub Get_GenomeId_From_QueueId {
  my $me = shift;
  my $queue_id = shift;
  my $info = $me->MySelect({
      statement => qq(SELECT genome_id FROM $config->{queue_table} WHERE id = ?),
      vars => [$queue_id],
      type => 'single'});
  return ($info);
}

sub Get_All_Sequences {
  my $me = shift;
  my $statement = "SELECT accession, mrna_seq FROM genome";
  my $crap = $me->MySelect({
      statement => $statement});
  return ($crap);
}

sub Keyword_Search {
  my $me = shift;
  my $species = shift;
  my $keyword = shift;
  my $statement = qq(SELECT accession, comment FROM genome WHERE comment like ? ORDER BY accession);
  my $info = $me->MySelect({
      statement => $statement,
      vars => ['%$keyword%']});
  my $return = {};
  foreach my $accession (@{$info}) {
    my $accession_id = $accession->[0];
    my $accession_comment = $accession->[1];
    $return->{$accession_id} = $accession_comment;
  }
  return ($return);
}

sub Mfeid_to_Bpseq {
    my $me = shift;
    my $mfeid = shift;
    my $outputfile = shift;
    my $add_slipsite = shift;
    my ($fh, $filename);
    if (!defined($outputfile)) {
     $fh = PRFdb::MakeTempfile({SUFFIX => '.bpseq'});
     $filename = $fh->filename;
    }
    elsif (ref($outputfile) eq 'GLOB') {
	$fh = $outputfile;
    }
    else {
     $fh = \*OUT;
     open($fh, ">$outputfile");
     $filename = $outputfile;
    }

    my $input_stmt = qq(SELECT sequence, output, slipsite FROM mfe WHERE id = ?);
    my $input = $me->MySelect({
	statement => $input_stmt,
	vars => [$mfeid],
	type => 'row'});
    my $seq = $input->[0];
    my $in = $input->[1];
    my $slipsite = $input->[2];
    my $output = '';
    $seq =~ s/^\s+//g;
    $seq =~ tr/augct/AUGCT/;
    $in =~ s/^\s+//g;
    my @seq_array = split(//, $seq);
    my @in_array = split(/\s+/, $in);
    if (defined($add_slipsite)) {
	$slipsite = reverse($slipsite);
	my @slipsite_array = split(//, $slipsite);
	foreach my $slipsite_char (@slipsite_array) {
	    unshift(@seq_array, $slipsite_char);
	    unshift(@in_array, '.');
	}
    }
    my $seq_length = scalar(@seq_array);
    my $input_length = scalar(@in_array);

    foreach my $c (0 .. $#seq_array) {
	if (!defined($in_array[$c])) {
	    $output .= "$c $seq_array[$c] 0\n";
	}
	elsif ($in_array[$c] eq '.') {
	    my $position = $c + 1;
	    $output .= "$position $seq_array[$c] 0\n";
	}
	else {
	    my $position = $c + 1;
	    my $bound_position = $in_array[$c] + 1;
	    $output .= "$position $seq_array[$c] $bound_position\n";
	}
    }
    print $fh $output;
    return($filename);
}

sub Genome_to_Fasta {
    my $me = shift;
    my $output = shift;
    my $species = shift;
    my $statement = qq(SELECT DISTINCT accession, species, comment, mrna_seq FROM genome);
    my $info;
    system("mkdir $config->{base}/blast") if (!-r  "$config->{base}/blast");
    open(OUTPUT, ">$config->{base}/blast/$output") or die("Could not open the fasta output file. $!");
    if (defined($species)) {
	$statement .= ' WHERE species = \'$species\'';
    }
    $info = $me->MySelect($statement);
    my $count = 0;
    foreach my $datum (@{$info}) {
	$count++;
	if (!defined($datum)) {
	    print "Problem with $count element\n";
	    next;
	}
	else {	
	    my $id = $count;
	    my $accession = $datum->[0];
	    my $species = $datum->[1];
	    my $comment = $datum->[2];
	    my $sequence = $datum->[3];
	    print OUTPUT ">gi|$id|gb|$accession $species $comment
$sequence
";
	}
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
    return ($filename);
}

sub MakeTempfile {
    my $args = shift;
    $File::Temp::KEEP_ALL = 1;
    my $fh = new File::Temp(DIR => defined($args->{directory}) ? $args->{directory} : $config->{workdir},
			    TEMPLATE => defined($args->{template}) ? $args->{template} : 'slip_XXXXX',
			    UNLINK => defined($args->{unlink}) ? $args->{unlink} : 0,
			    SUFFIX => defined($args->{SUFFIX}) ? $args->{SUFFIX} : '.fasta',);

    my $filename = $fh->filename();
    AddOpen($filename);
    return ($fh);
}

sub AddOpen {
    my $file = shift;
    my @open_files = @{$PRFConfig::config->{open_files}};

    if (ref($file) eq 'ARRAY') {
	foreach my $f (@{$file}) {
	    push(@open_files, $f);
	}
    }
    else {
	push(@open_files, $file);
    }
    $PRFConfig::config->{open_files} = \@open_files;
}

sub RemoveFile {
    my $file = shift;
    my @open_files = @{$PRFConfig::config->{open_files}};
    my @new_open_files = ();
    my $num_deleted = 0;
    my @comp = ();
    
    if ($file eq 'all') {
	foreach my $f (@{open_files}) {
	    unlink($f);
	    print STDERR "Deleting: $f\n";
	    $num_deleted++;
	}
	$PRFConfig::config->{open_files} = \@new_open_files;
	return($num_deleted);
    }

    elsif (ref($file) eq 'ARRAY') {
	@comp = @{$file};
    }
    else {
	push(@comp, $file);
    }

    foreach my $f (@open_files) {
	foreach my $c (@comp) {
	    if ($c eq $f) {
		$num_deleted++;
		unlink($f);
	    }
	}
	push(@new_open_files, $f);
    }
    $PRFConfig::config->{open_files} = \@new_open_files;
    return($num_deleted);
}

sub MakeFasta {
    my $seq = shift;
    my $start = shift;
    my $end = shift;
    my $fh = PRFdb::MakeTempfile();
    my $filename = $fh->filename;
    my $output = {
	fh => $fh,
	filename => $filename,
	string => '',
	no_slipstring => '',
    };
    my @seq_array;
    if (ref($seq) eq 'ARRAY') {
	@seq_array = @{$seq};
    }
    else {
	@seq_array = split(//, $seq);
    }
    my $slipstring = '';
    ### $start .. $end !!! This means that all numbers will be relative to the AUG even if the AUG
    ### is not the first base of the sequence.  Therefore the position number will need to be incremented
    ### by the same number of bases or confusion will result.   
    foreach my $c ($start .. $end) {
	if (defined($seq_array[$c])) {
	    $output->{string} .= $seq_array[$c];
	    if ($c >= ($start + 7)) {
		$output->{no_slipstring} .= $seq_array[$c];
	    }
	    else {
		$slipstring .= $seq_array[$c];
	    }
	}
    }
    $output->{slipsite} = $slipstring;
    $output->{string} =~ tr/atgcu/AUGCU/;
    $output->{no_slipstring} =~ tr/atgcu/AUGCU/;
    my $data = ">$slipstring $start $end
$output->{string}
";
    print $fh $data;
    close($fh);
    return($output);
}


####
### Get and Set Bootstrap data
####
sub Get_Boot {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $start = shift;
  PRF_Error("Undefined value in Get_Boot", $species, $accession)
      unless (defined($species) and defined($accession));
  my $statement;
  if (defined($start)) {
      $statement = qq(SELECT * FROM boot WHERE accession = ? AND start = ? ORDER BY start);
  } 
  else {
      $statement = qq(SELECT * from boot where accession = ? ORDER BY start);
  }
  my $info = $me->MySelect({
      statement =>$statement,
      vars => [$accession, $start],
      type => 'hash',
      descriptor => 1});
  return ($info);
}

sub Get_Slippery_From_Sequence {
  my $me = shift;
  my $sequence = shift;
  my $start = shift;
  my @reg = split(//, $sequence);
  my $slippery = "$reg[$start]" . "$reg[$start+1]" . "$reg[$start+2]" . "$reg[$start+3]" . "$reg[$start+4]" . "$reg[$start+5]" . "$reg[$start+6]";
  return ($slippery);
}

sub Id_to_AccessionSpecies {
  my $me = shift;
  my $id = shift;
  my $start = shift;
  PRF_Error("Undefined value in Id_to_AccessionSpecies", $id) unless (defined($id));
  my $statement = qq(SELECT accession, species from genome where id = ?);
  my $data = $me->MySelect({
      statement => $statement,
      vars => [$id],
      type => 'row'});
  my $accession = $data->[0];
  my $species = $data->[1];
  my $return = {accession => $accession, species => $species,};
  return ($return);
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
  $sth->execute($message, $accession);
}

sub Get_Entire_Queue {
    my $me = shift;
    my $table = 'queue';
    if (defined($config->{queue_table})) {
	$table = $config->{queue_table};
    }
    my $return;
    my $statement = qq(SELECT id FROM $table WHERE checked_out='0');
    my $ids = $me->MySelect({statement =>$statement});
    return ($ids);
}

sub Add_Webqueue {
    my $me = shift;
    my $id = shift;
    my $check = $me->MySelect({statement => qq/SELECT count(id) FROM webqueue WHERE genome_id = '$id'/, type => 'single'});
    return(undef) if ($check > 0);
    my $statement = qq/INSERT INTO webqueue VALUES('','$id','0','','0','')/;
    my ($cp,$cf,$cl) = caller();
    my $rc = $me->MyExecute({statement => $statement, caller => "$cp,$cf,$cl",});
    return(1);
}

sub Set_Queue {
    my $me = shift;
    my $id = shift;
    my $table = $config->{queue_table};
    my $num_existing_stmt = qq(SELECT count(id) FROM $table WHERE genome_id = '$id');
    my $num_existing = $me->MySelect({
	statement => $num_existing_stmt,
	type => 'single',});
    if (!defined($num_existing) or $num_existing == 0) {
	my $statement = qq/INSERT INTO $table VALUES('','$id','0','','0','')/;
	my ($cp,$cf,$cl) = caller();
	my $rc = $me->MyExecute({statement => $statement, caller => "$cp,$cf,$cl",});
	my $last_id = $me->MySelect({statement => 'SELECT LAST_INSERT_ID()', type => 'single'});
	return ($last_id);
    }
    else {
	my $id_existing_stmt = qq(SELECT id FROM $table WHERE genome_id = '$id');
	my $id_existing = $me->MySelect({
	    statement => $id_existing_stmt,
	    type => 'single'
	    });
	return($id_existing);
    }
}

sub Clean_Table {
    my $me = shift;
    my $type = shift;
    my $table = $type . '_' . $config->{species};
    my $statement = "DELETE from $table";
    my ($cp,$cf,$cl) = caller();
    $me->MyExecute({statement =>$statement, caller=>"$cp, $cf, $cl"});
}

sub Drop_Table {
    my $me = shift;
    my $table = shift;
    my $statement = "DROP table $table";
    my ($cp,$cf,$cl) = caller();
    $me->MyExecute({statement => $statement, caller =>"$cp, $cf, $cl"});
}

sub FillQueue {
    my $me = shift;
    my $table = 'queue';
    if (defined($config->{queue_table})) {
	$table = $config->{queue_table};
    }
    $me->Create_Queue() unless ($me->Tablep($table));
    my $best_statement = "INSERT into $table (genome_id, checked_out, done) SELECT id, 0, 0 from genome";
    my ($cp,$cf,$cl) = caller();
    $me->MyExecute({statement => $best_statement, caller =>"$cp, $cf, $cl"});
}

sub Copy_Genome {
    my $me = shift;
    my $old_db = shift;
    my $new_db = $config->{db};
    my $statement = qq/INSERT INTO ${new_db}.genome
(accession,species,genename,locus,ontology_function,ontology_component,ontology_process,version,comment,mrna_seq,protein_seq,orf_start,orf_stop,direction,omim_id)
SELECT accession,species,genename,locus,ontology_function,ontology_component,ontology_process,version,comment,mrna_seq,protein_seq,orf_start,orf_stop,direction,omim_id from ${old_db}.genome/;
    my ($cp,$cf,$cl) = caller();
    $me->MyExecute({statement => $statement, caller =>"$cp, $cf, $cl"});
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
    my ($cp,$cf,$cl) = caller();
    $me->MyExecute({statement => $statement, caller => "$cp, $cf, $cl"});
}

sub Get_Input {
    my $me = shift;
    my $queue_table = $config->{queue_table};
    my $genome_table = $config->{genome_table};
    my $query = qq(SELECT ${queue_table}.id, ${queue_table}.genome_id, ${genome_table}.accession,
${genome_table}.species, ${genome_table}.mrna_seq, ${genome_table}.orf_start,
${genome_table}.direction FROM ${queue_table}, ${genome_table} WHERE ${queue_table}.checked_out = '0'
AND ${queue_table}.done = '0' AND ${queue_table}.genome_id = ${genome_table}.id LIMIT 1);
    my $ids = $me->MySelect({
	statement => $query,
	type => 'row' });
    my $id = $ids->[0];
    my $genome_id = $ids->[1];
    my $accession = $ids->[2];
    my $species = $ids->[3];
    my $mrna_seq = $ids->[4];
    my $orf_start = $ids->[5];
    my $direction = $ids->[6];
    if (!defined($id) or $id eq '' or !defined($genome_id) or $genome_id eq '') {
	return (undef);
    }
    my $update = qq(UPDATE $queue_table SET checked_out='1', checked_out_time=current_timestamp() WHERE id=?);
    my ($cp,$cf,$cl) = caller();
    $me->MyExecute({statement => $update,  vars => [$id], caller => "$cp, $cf, $cl"});
    my $return = {
	queue_id => $id,
	genome_id => $genome_id,
	accession => $accession,
	species => $species,
	mrna_seq => $mrna_seq,
	orf_start => $orf_start,
	direction => $direction,
    };
    return ($return);
}

sub Grab_Queue {
    my $me = shift;
    my $queue = undef;
    if ($config->{check_webqueue} == 1) {
	### Then first see if anything is in the webqueue
	$queue = $me->Get_Queue('webqueue');
	if (defined($queue)) {
	    return ($queue);
	}
	else {
	    $queue = $me->Get_Queue();
	    return ($queue);
	}
    } ## End check webqueue
    else {
	$queue = $me->Get_Queue();
	if (!defined($queue)) {
	    print "There are no more entries in the queue.\n";
	}
	return ($queue);
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
	$me->Reset_Queue($table, 'complete');
	my $return = {sequence  => "$sequence",
		   orf_start => $start,
		   orf_stop  => $stop,};
	return ($return);
    }
    else {
	return (undef);
    }
}

sub Get_Slippery_From_RNAMotif {
    my $me = shift;
    my $filename = shift;
    open(IN, "<$filename");
    ## OPEN IN in Get_Slippery_From_RNAMotif
    while (my $line = <IN>) {
	chomp $line;
	if ($line =~ /^\>/) {
	    my ($slippery, $crap) = split(/ /, $line);
	    $slippery =~ s/\>//g;
	    return ($slippery);
	}
    }
    close(IN);
    ## CLOSE IN in Get_Slippery_From_RNAMotif
    return (undef);
}

sub Insert_Genome_Entry {
    my $me = shift;
    my $datum = shift;
    ## Check to see if the accession is already there
    my $check = qq(SELECT id FROM genome where accession=?);
    my $already_id = $me->MySelect({statement => $check,
				    vars => [$datum->{accession}],
				    type => 'single'});
    ## A check to make sure that the orf_start is not 0.  If it is, set it to 1 so it is consistent with the
    ## crap from the SGD
    $datum->{orf_start} = 1 if (!defined($datum->{orf_start}) or $datum->{orf_start} == 0);
    if (defined($already_id)) {
	print "The accession $datum->{accession} is already in the database with id: $already_id\n";
	return ($already_id);
    }
    my $statement = qq(INSERT INTO genome
(accession,species,genename,version,comment,mrna_seq,protein_seq,orf_start,orf_stop,direction)
VALUES('$datum->{accession}', '$datum->{species}', '$datum->{genename}', '$datum->{version}', '$datum->{comment}', '$datum->{mrna_seq}', '$datum->{protein_seq}', '$datum->{orf_start}', '$datum->{orf_stop}', '$datum->{direction}'));
     my ($cp,$cf,$cl) = caller();
     $me->MyExecute({statement => $statement,caller => "$cp, $cf, $cl",});
     ## The following line is very important to ensure that multiple
     ## calls to this don't end up with
     ## Increasingly long sequences
     foreach my $k (keys %{$datum}) {$datum->{$k} = undef;}
     my $last_id = $me->MySelect({statement => 'SELECT LAST_INSERT_ID()', type => 'single'});
     return ($last_id);
}

sub Insert_Noslipsite {
    my $me = shift;
    my $accession = shift;
    my $statement = "INSERT INTO noslipsite
(accession)
VALUES($accession)";
    my ($cp,$cf,$cl) = caller();
    $me->MyExecute({statement =>$statement, caller => "$cp, $cf, $cl"});
    my $last_id = $me->MySelect({statement => 'SELECT LAST_INSERT_ID()', type => 'single'});
    return ($last_id);
}

sub Get_MFE {
    my $me = shift;
    my $identifier = shift; ## { genome_id => #, species => #, accession => #, start => # }
    my $statement = '';
    my $info;
    if (defined($identifier->{genome_id})) {
	$statement = qq(SELECT id, genome_id, species, accession, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode FROM mfe where genome_id = ?);
	$info = $me->MySelect({statement =>$statement,
			       vars => [$identifier->{genome_id}],
			       type => 'hash',
			       descriptor => [qq(id genome_id species accession start slipsite seqlength sequence output parsed parens mfe pairs knotp barcode)],});
    } 
    elsif (defined($identifier->{accession} and defined($identifier->{start}))) {
	$statement = qq(SELECT id, genome_id, species, accession, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode FROM mfe where accession = ? and start = ?);
	$info = $me->MySelect({statement => $statement,
			       vars => [$identifier->{accession}, $identifier->{start}],
			       type => 'hash',
			       descriptor => [qq(id genome_id species accession start slipsite seqlength sequence output parsed parens mfe pairs knotp barcode)],});
    }
    return ($info);
}

sub Put_Nupack {
    my $me = shift;
    my $data = shift;
    my $table = shift;
    my $mfe_id = shift;
    if (defined($table) and $table eq 'landscape') {
	$mfe_id = $me->Put_MFE_Landscape('nupack', $data);
    } 
    elsif (defined($table)) {
	$mfe_id = $me->Put_MFE('nupack', $data, $table);
    } 
    else {
	$mfe_id = $me->Put_MFE('nupack', $data);
    }
    return($mfe_id);
}

sub Put_Hotknots {
    my $me = shift;
    my $data = shift;
    my $table = shift;
    my $mfe_id = shift;
    if (defined($table) and $table eq 'landscape') {
	$mfe_id = $me->Put_MFE_Landscape('hotknots', $data);
    }
    elsif (defined($table)) {
	$mfe_id = $me->Put_MFE('hotknots', $data, $table);
    }
    else {
	$mfe_id = $me->Put_MFE('hotknots', $data);
    }
    return($mfe_id);
}

sub Put_Vienna {
    my $me = shift;
    my $data = shift;
    my $table = shift;
    my $mfe_id = shift;
    if (defined($table) and $table eq 'landscape') {
	$mfe_id = $me->Put_MFE_Landscape('vienna', $data);
    }
    elsif (defined($table)) {
	$mfe_id = $me->Put_MFE('vienna', $data, $table);
    }
    else {
	$mfe_id = $me->Put_MFE('vienna', $data);
    }
    return($mfe_id);
}

sub Put_Pknots {
    my $me = shift;
    my $data = shift;
    my $table = shift;
    my $mfe_id;
    if (defined($table) and $table eq 'landscape') {
	$mfe_id = $me->Put_MFE_Landscape('pknots', $data);
    }
    elsif (defined($table)) {
	$mfe_id = $me->Put_MFE('pknots', $data, $table);
    }
    else {
	$mfe_id = $me->Put_MFE('pknots', $data);
    }
    return($mfe_id);
}

sub Put_MFE {
    my $me = shift;
    my $algo = shift;
    my $data = shift;
    my $table = shift;
    $table = 'mfe' unless (defined($table));
    ## What fields do we want to fill in this MFE table?
    my @pknots = ('genome_id', 'species', 'accession', 'start', 'slipsite', 'seqlength', 'sequence', 'output', 'parsed', 'parens', 'mfe', 'pairs', 'knotp', 'barcode');
    my $errorstring = Check_Insertion(\@pknots, $data);
    if (defined($errorstring)) {
	$errorstring = "Undefined value(s) in Put_MFE: $errorstring";
	PRF_Error($errorstring, $data->{species}, $data->{accession});
    }
    $data->{sequence} =~ tr/actgu/ACTGU/;
    my $statement = qq(INSERT INTO $table (genome_id, species, algorithm, accession, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?));
    
    my ($cp,$cf,$cl) = caller();
    $me->MyExecute({statement => $statement,
		    vars => [$data->{genome_id}, $data->{species}, $algo, $data->{accession}, $data->{start}, $data->{slipsite}, $data->{seqlength}, $data->{sequence}, $data->{output}, $data->{parsed}, $data->{parens}, $data->{mfe}, $data->{pairs}, $data->{knotp}, $data->{barcode}],
		    caller => "$cp, $cf, $cl",});
    
    my $put_id = $me->MySelect({statement => 'SELECT LAST_INSERT_ID()', type => 'single'});
    return ($put_id);
}    ## End of Put_MFE

sub Put_MFE_Landscape {
    my $me = shift;
    my $algo = shift;
    my $data = shift;
    my $species = $data->{species};
    ## What fields do we want to fill in this MFE table?
    my @filled;
    if ($algo eq 'vienna') {
	@filled = ('genome_id','species','accession','start','seqlength','sequence','parens','mfe');
    }
    else {
	@filled = ('genome_id', 'species', 'accession', 'start', 'seqlength', 'sequence', 'output', 'parsed', 'parens', 'mfe', 'pairs', 'knotp', 'barcode');
    }
    my $errorstring = Check_Insertion( \@filled, $data);
    if (defined($errorstring)) {
	$errorstring = "Undefined value(s) in Put_MFE_Landscape: $errorstring";
	PRF_Error($errorstring, $data->{accession});
    }

    $data->{sequence} =~ tr/actgu/ACTGU/;
    my $table = "landscape-$species";
    my $statement = qq(INSERT INTO $table (id, genome_id, species, algorithm, accession, start, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?));
    
    my ($cp,$cf,$cl) = caller();
    $me->MyExecute({statement => $statement,
		    vars => ['',$data->{genome_id}, $data->{species}, $algo, $data->{accession}, $data->{start}, $data->{seqlength}, $data->{sequence}, $data->{output}, $data->{parsed}, $data->{parens}, $data->{mfe}, $data->{pairs}, $data->{knotp}, $data->{barcode}],
		    caller =>"$cp, $cf, $cl",});
    
    my $get_inserted_id = qq(SELECT LAST_INSERT_ID());
    my $id = $me->MySelect(statement => $get_inserted_id, type => 'single');
    return ($id);
}    ## End put_mfe_landscape

sub Put_Stats {
    my $me = shift;
    my $data = shift;
    foreach my $species (@{$data->{species}}) {
	foreach my $seqlength (@{$data->{seqlength}}) {
	    foreach my $max_mfe (@{$data->{max_mfe}}) {
		foreach my $algorithm (@{$data->{algorithm}}) {
		    print "Now doing $species $seqlength $max_mfe $algorithm\n";
		    my $statement = qq/INSERT DELAYED INTO stats
(species, seqlength, max_mfe, min_mfe, algorithm, num_sequences, avg_mfe, stddev_mfe, avg_pairs, stddev_pairs, num_sequences_noknot, avg_mfe_noknot, stddev_mfe_noknot, avg_pairs_noknot, stddev_pairs_noknot, num_sequences_knotted, avg_mfe_knotted, stddev_mfe_knotted, avg_pairs_knotted, stddev_pairs_knotted, avg_zscore, stddev_zscore)
VALUES
('$species', '$seqlength', 
(SELECT max(mfe) FROM mfe WHERE algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength'),
(SELECT min(mfe) FROM mfe WHERE algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength'),
'$algorithm',
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
(SELECT stddev(pairs) FROM mfe WHERE knotp = '1' AND algorithm = '$algorithm' AND species = '$species' AND seqlength = '$seqlength' AND mfe <= '$max_mfe'),
(SELECT avg(zscore) FROM boot WHERE mfe_method = '$algorithm' AND species = '$species' AND seqlength = '$seqlength'),
(SELECT stddev(zscore) FROM boot WHERE mfe_method = '$algorithm' AND species = '$species' AND seqlength = '$seqlength')
)/;
          my ($cp,$cf,$cl) = caller();
          $me->MyExecute({statement => $statement,
			  caller => "$cp, $cf, $cl",});
        }
      }
    }
  }
}

sub Put_Boot {
    my $me = shift;
    my $data = shift;
    my $id = $data->{genome_id};
    my @boot_ids = ();
    ## What fields are required?
    foreach my $mfe_method (keys %{$config->{boot_mfe_algorithms}}) {
#  foreach my $mfe_method ( keys %{$data}) {
#      next if ($mfe_method =~ /\d+/);
	my $mfe_id = $data->{mfe_id};
	
	foreach my $rand_method (keys %{$config->{boot_randomizers}}) {
#      foreach my $rand_method (keys %{$data->{$mfe_method}}) {
#	  next if ($rand_method =~ /\d+/);
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
      my $undefined_values = Check_Defined( { genome_id => $data->{genome_id}, mfe_id => $mfe_id, species => $species, accession => $accession, start => $start, seqlength => $seqlength, iterations => $iterations, rand_method => $rand_method, mfe_method => $mfe_method, mfe_mean => $mfe_mean, mfe_sd => $mfe_sd, mfe_se => $mfe_se, pairs_mean => $pairs_mean, pairs_sd => $pairs_sd, pairs_se => $pairs_se, mfe_values => $mfe_values } );
      if ($undefined_values) {
        $errorstring = "An error occurred in Put_Boot, undefined values: $undefined_values\n";
        PRF_Error( $errorstring, $species, $accession );
        print "$errorstring, $species, $accession\n";
      }
      my ($cp, $cf, $cl) = caller();
      $me->MyExecute({statement => $statement,
		      vars => [ $data->{genome_id}, $mfe_id, $species, $accession, $start, $seqlength, $iterations, $rand_method, $mfe_method, $mfe_mean, $mfe_sd, $mfe_se, $pairs_mean, $pairs_sd, $pairs_se, $mfe_values ], 
		      caller => "$cp, $cf, $cl",});

       my $boot_id = $me->MySelect({statement => 'SELECT LAST_INSERT_ID()', type => 'single'});
       push(@boot_ids, $boot_id);
    }    ### Foreach random method
  }    ## Foreach mfe method
  return(\@boot_ids);
}    ## End of Put_Boot


sub Put_Single_Boot {
    my $me = shift;
    my $data = shift;
    my $mfe_method = shift;
    my $rand_method = shift;
    my $id = $data->{genome_id};
    my $mfe_id = $data->{mfe_id};
    my @boot_ids = ();
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
('$data->{genome_id}' ,'$mfe_id', '$species', '$accession', '$start', '$seqlength', '$iterations', '$rand_method', '$mfe_method', '$mfe_mean', '$mfe_sd', '$mfe_sd', '$pairs_mean', '$pairs_sd', '$pairs_se', '$mfe_values'));
    
    my $undefined_values = Check_Defined( { genome_id => $data->{genome_id}, mfe_id => $mfe_id, species => $species, accession => $accession, start => $start, seqlength => $seqlength, iterations => $iterations, rand_method => $rand_method, mfe_method => $mfe_method, mfe_mean => $mfe_mean, mfe_sd => $mfe_sd, mfe_se => $mfe_se, pairs_mean => $pairs_mean, pairs_sd => $pairs_sd, pairs_se => $pairs_se, mfe_values => $mfe_values } );
    
    if ($undefined_values) {
	$errorstring = "An error occurred in Put_Boot, undefined values: $undefined_values\n";
	PRF_Error( $errorstring, $species, $accession );
	print "$errorstring, $species, $accession\n";
    }
    my ($cp, $cf, $cl) = caller();
    my $rows = $me->MyExecute({statement => $statement,
			       caller => "$cp, $cf, $cl",});
    
    my $boot_id = $me->MySelect({statement => 'SELECT LAST_INSERT_ID()', type => 'single'});
    print "Inserted $boot_id\n";
    return($boot_id);
}

sub Put_Overlap {
    my $me = shift;
    my $data = shift;
    my $statement = qq(INSERT DELAYED INTO overlap
(genome_id, species, accession, start, plus_length, plus_orf, minus_length, minus_orf) VALUES
(?,?,?,?,?,?,?,?));
    my ( $cp, $cf, $cl ) = caller();
    $me->MyExecute({statement => $statement,
		    vars => [$data->{genome_id}, $data->{species}, $data->{accession}, $data->{start}, $data->{plus_length}, $data->{plus_orf}, $data->{minus_length}, $data->{minus_orf}], 
		    caller =>"$cp, $cf, $cl",});
    my $id = $data->{overlap_id};
    return ($id);
}    ## End of Put_Overlap

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
    open( SQL, ">>failed_sql_statements.txt" );
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

sub Check_Insertion {
    my $list = shift;
    my $data = shift;
    my $errorstring = undef;
    foreach my $column (@{$list}) {
	$errorstring .= "$column " unless (defined($data->{$column}));
    }
    return ($errorstring);
}

sub Check_Defined {
    my $args = shift;
    my $return = '';
    foreach my $k (keys %{$args}) {
	if (!defined($args->{$k})) {
	    $return .= "$k,";
	}
    }
    return ($return);
}

sub Tablep {
    my $me = shift;
    my $table = shift;
    my $statement = qq(SHOW TABLES LIKE '$table');
    my $info = $me->MySelect($statement);
    my $answer = scalar(@{$info});
    return (scalar(@{$info}));
}

sub Create_Genome {
    my $me = shift;
    my $statement = qq/CREATE table genome (
id $config->{sql_id},
accession $config->{sql_accession},
gi_number $config->{gi_number},
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
found_snp bool,
snp_lastupdate TIMESTAMP DEFAULT '00:00:00',
lastupdate $config->{sql_timestamp},
INDEX(accession),
INDEX(genename),
PRIMARY KEY (id))/;
    my ($cp, $cf, $cl) = caller();
    $me->MyExecute({statement =>$statement, 
		    caller => "$cp, $cf, $cl",});
}

sub Create_NoSlipsite {
    my $me = shift;
    my $statement = qq/CREATE table noslipsite (
id $config->{sql_id},
accession $config->{sql_accession},
lastupdate $config->{sql_timestamp},
PRIMARY KEY (id))/;
    my ($cp, $cf, $cl) = caller();
    $me->MyExecute({statement => $statement,
		    caller => "$cp, $cf, $cl",});
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
  $me->MyExecute({statement => $statement,
		caller => "$cp, $cf, $cl",})
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
avg_zscore float,
stddev_zscore float,
PRIMARY KEY (id)));
    my ($cp, $cf, $cl) = caller();
    $me->MyExecute({statement => $statement,
		    caller => "$cp, $cf, $cl",});
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
    $me->MyExecute({statement => $statement, caller =>"$cp, $cf, $cl",});
}

sub Create_Queue {
    my $me = shift;
    my $table = shift;
    if (!defined($table)) {
	if (defined( $config->{queue_table})) {
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
    $me->MyExecute({statement =>$statement,  caller =>"$cp, $cf, $cl",});
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
has_snp bool DEFAULT FALSE,
lastupdate $config->{sql_timestamp},
INDEX(genome_id),
INDEX(accession),
PRIMARY KEY(id))\;
    my ($cp, $cf, $cl) = caller();
    $me->MyExecute({statement => $statement,  caller =>"$cp, $cf, $cl",});
}

sub Create_MFE_Utr {
    my $me = shift;
    my $statement = qq\CREATE TABLE mfe_utr (
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
    $me->MyExecute({statement => $statement,  caller =>"$cp, $cf, $cl",});
}

sub Create_Variations {
    my $me = shift;
    my $statement = qq\CREATE TABLE variations (
id $config->{sql_id},
dbSNP text,
accession $config->{sql_accession},
start int,
stop int,
complement int,
vars text,
frameshift char(1),
note text,
INDEX(dbSNP),
INDEX(accession),
PRIMARY KEY(id))\;
    my ($cp, $cf, $cl) = caller();
    $me->MyExecute({statement => $statement,caller=>"$cp, $cf, $cl",});
}

sub Create_Landscape {
    my $me = shift;
    my $species = shift;
    my $table = "landscape_$species";
    my $statement = qq\CREATE TABLE $table (
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
    $me->MyExecute({statement =>$statement, caller => "$cp, $cf, $cl",});
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
picture_filename text,
lastupdate $config->{sql_timestamp},
INDEX(genome_id),
INDEX(mfe_id),
INDEX(accession),
PRIMARY KEY(id))\;
    my ($cp, $cf, $cl) = caller();
    $me->MyExecute({statement => $statement, caller =>"$cp, $cf, $cl",});
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
    $me->MyExecute({statement => $statement, caller =>"$cp, $cf, $cl",});
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
    $me->MyExecute({statement => $statement, caller => "$cp, $cf, $cl"});
}


1;
