package PRFdb;
use strict;
use DBI;
use PRFConfig;
use SeqMisc;
use File::Temp qw / tmpnam /;
use Fcntl ':flock';    # import LOCK_* constants
use Bio::DB::Universal;
use Log::Log4perl;
use Log::Log4perl::Level;
use Bio::Root::Exception;
use Error qw(:try);
use vars qw($VERSION);
our @ISA = qw(Exporter);
our @EXPORT = qw(AddOpen RemoveFile callstack);    # Symbols to be exported by default

$VERSION = '20091101';
Log::Log4perl->easy_init($WARN);
our $log = Log::Log4perl->get_logger('stack'),
### Holy crap global variables!
my $config;
my $dbh;
###

sub new {
    my ($class, %arg) = @_;
    if (defined($arg{config})) {
	$config = $arg{config};
    }
    my $me = bless {
	user => $config->{database_user},
	num_retries => 60,
	retry_time => 15,
    }, $class;
    if ($config->{checks}) {
	$me->Create_Genome() unless ($me->Tablep('genome'));
	$me->Create_Queue() unless ($me->Tablep($config->{queue_table}));
	$me->Create_MFE() unless ($me->Tablep('mfe'));
	$me->Create_Errors() unless ($me->Tablep('errors'));
	$me->Create_Agree() unless ($me->Tablep('agree'));
	$me->Create_NumSlipsite() unless ($me->Tablep('numslipsite'));
	if (defined($config->{index_species})) {
	    my @sp = @{$config->{index_species}};
	    foreach my $s (@sp) {
		my $boot_table = ($s =~ /virus/ ? "boot_virus" : "boot_$s");
	        unless ($me->Tablep($boot_table)) {
		    $me->Create_Boot($boot_table);
		}
		my $landscape_table = "landscape_$s";
		unless ($me->Tablep($landscape_table)) {
		    $me->Create_Landscape($landscape_table);
		}
	    }
	}
    }
    $me->{errors} = undef;
    return ($me);
}

sub callstack {
  my ($path, $line, $subr);
  my $max_depth = 30;
  my $i = 1;
  if ($log->is_warn()) {
    $log->warn("--- Begin stack trace ---");
    while ((my @call_details = (caller($i++))) && ($i<$max_depth)) {
      $log->warn("$call_details[1] line $call_details[2] in function $call_details[3]");
    }
    $log->warn("--- End stack trace ---");
  }
}

sub Disconnect {
    $dbh->disconnect() if (defined($dbh));
}

sub MySelect {
    my $me = shift;
    my %args = ();
    my $input;
    my $input_type = ref($_[0]);
    my ($statement, $vars, $type, $descriptor);
    if ($input_type eq 'HASH') {
        $input = $_[0];
	$statement = $input->{statement};
	$vars = $input->{vars};
	$type = $input->{type};
	$descriptor = $input->{descriptor};
    } elsif (!defined($_[1])) {
	$statement = $_[0];
    } else {
	%args = @_;
	$statement = $args{statement};
	$vars = $args{vars};
	$type = $args{type};
	$descriptor = $args{descriptor};
        $input = \%args;
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
    } else {
	$rv = $sth->execute();
    }
    
    if (!defined($rv)) {
	callstack();
	my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
	print STDERR "$hour:$min:$sec $mon-$mday Execute failed for: $statement
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
    } elsif (defined($type) and $type eq 'row') {
	## If $type is defined, AND if you ask for a row, do a selectrow_arrayref
	$return = $sth->fetchrow_arrayref();
	$selecttype = 'selectrow_arrayref';
    }

    ## A flat select is one in which the returned elements are returned as a single flat arrayref
    ## If you ask for multiple columns, then it will return a 2d array ref with the first d being the cols
    elsif (defined($type) and $type eq 'single') {
	my $tmp = $sth->fetchrow_arrayref();
	$return = $tmp->[0];
    } elsif (defined($type) and $type eq 'flat') {
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
	} else {
	    foreach my $c (0 .. $#$data) {
		my @elems = @{$data->[$c]};
		foreach my $d (0 .. $#elems) {
		    $ret[$d][$c] = $data->[$c]->[$d];
		}
	    }
	}
	$return = \@ret;
	## Endif flat
    } elsif (defined($type) and $type eq 'list_of_hashes') { 
	$return = $sth->fetchall_arrayref({});
	$selecttype = 'selectall_arrayref({})';     
    } elsif (defined($type)) {    ## Usually defined as 'hash'
	## If only $type is defined, do a selectrow_hashref
	$return = $sth->fetchrow_hashref();
	$selecttype = 'selectrow_hashref';
    } else {
    ## The default is to do a selectall_arrayref
	$return = $sth->fetchall_arrayref();
	$selecttype = 'selectall_arrayref';
    }

    if (defined($DBI::errstr)) {
	my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
	print STDERR "$hour:$min:$sec $mon-$mday Execute failed for: $statement
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
    my %args = ();
    my $input;
    my $input_type = ref($_[0]);
    my ($statement, $vars, $caller);
    if ($input_type eq 'HASH') {
        $input = $_[0];
	$caller = $input->{caller};
	$vars = $input->{vars};
	$statement = $input->{statement};
    } elsif (!defined($_[1])) {
	$statement = $_[0];
    } else {
	%args = @_;
	$statement = $args{statement};
	$vars = $args{vars};
	$caller = $args{caller};
        $input = \%args;
    }

    my $dbh = $me->MyConnect($statement);
    my $sth = $dbh->prepare($statement);
    my $rv;
    if (defined($input->{vars})) {
	$rv = $sth->execute(@{$input->{vars}}) or callstack();
    } else {
	$rv = $sth->execute() or callstack();
    }
    
    my $rows = 0;
    if (!defined($rv)) {
	my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
	print STDERR "$hour:$min:$sec $mon-$mday Execute failed for: $statement
from: $input->{caller}
with: error $DBI::errstr\n";
	print STDERR "Host: $config->{database_host} Db: $config->{database_name}\n" if (defined($config->{debug}) and $config->{debug} > 0);
	$me->{errors}->{statement} = $statement;
	$me->{errors}->{errstr} = $DBI::errstr;
	if (defined($input->{caller})) {
	    $me->{errors}->{caller} = $input->{caller};
	}
	return(undef);
    } else {
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
    my $stuff = $me->MySelect(statement => $final_statement,);

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
    $dbh = DBI->connect_cached("dbi:$config->{database_type}:database=$config->{database_name};host=$config->{database_host}",
			       $config->{database_user},
			       $config->{database_pass},
			       { AutoCommit => 1},) or callstack();
    
    my $retry_count = 0;
    if (!defined($dbh) or
	(defined($DBI::errstr) and
	 $DBI::errstr =~ m/(?:lost connection|Unknown MySQL server host|mysql server has gone away)/ix)) {
	my $success = 0;
	while ($retry_count < $me->{num_retries} and $success == 0) {
	    $retry_count++;
	    sleep $me->{retry_time};
	    $dbh = DBI->connect_cached(
				       "dbi:$config->{database_type}:database=$config->{database_name};host=$config->{database_host}",
				       $config->{database_user},
				       $config->{database_pass},);
	    if (defined($dbh) and
		(!defined($dbh->errstr) or $dbh->errstr eq '')) {
		$success++;
	    }
	}
    }

    if (!defined($dbh)) {
	$me->{errors}->{statement} = $statement, Write_SQL($statement) if (defined($statement));
	$me->{errors}->{errstr} = $DBI::errstr;
	my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
	my $error = qq"$hour:$min:$sec $mon-$mday Could not open cached connection: dbi:$config->{database_type}:database=$config->{database_name};host=$config->{database_host}, $DBI::err. $DBI::errstr";
	die($error);
    }
    $dbh->{mysql_auto_reconnect} = 1;
    $dbh->{InactiveDestroy} = 1;
    return ($dbh);
}

sub Get_GenomeId_From_Accession {
    my $me = shift;
    my $accession = shift;
    my $info = $me->MySelect(statement => qq"SELECT id FROM genome WHERE accession = ?", vars => [$accession], type => 'single');
    return ($info);
}

sub Get_GenomeId_From_QueueId {
    my $me = shift;
    my $queue_id = shift;
    my $info = $me->MySelect(statement => qq"SELECT genome_id FROM $config->{queue_table} WHERE id = ?", vars => [$queue_id], type => 'single');
    return ($info);
}

sub Get_All_Sequences {
    my $me = shift;
    my $crap = $me->MySelect("SELECT accession, mrna_seq FROM genome");
    return ($crap);
}

sub Keyword_Search {
    my $me = shift;
    my $species = shift;
    my $keyword = shift;
    my $statement = qq"SELECT accession, comment FROM genome WHERE comment like ? ORDER BY accession";
    my $info = $me->MySelect(statement => $statement, vars => ['%$keyword%']);
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
	$fh = PRFdb::MakeTempfile(SUFFIX => '.bpseq');
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

    my $input_stmt = qq"SELECT sequence, output, slipsite FROM mfe WHERE id = ?";
    my $input = $me->MySelect(statement => $input_stmt,	vars => [$mfeid], type => 'row');
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
    my $statement = qq"SELECT DISTINCT accession, species, comment, mrna_seq FROM genome";
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
    my %args = @_;
    $File::Temp::KEEP_ALL = 1;
    my $fh = new File::Temp(DIR => defined($args{directory}) ? $args{directory} : $config->{workdir},
			    TEMPLATE => defined($args{template}) ? $args{template} : 'slip_XXXXX',
			    UNLINK => defined($args{unlink}) ? $args{unlink} : 0,
			    SUFFIX => defined($args{SUFFIX}) ? $args{SUFFIX} : '.fasta',);

    my $filename = $fh->filename();
    AddOpen($filename);
    return ($fh);
}

sub AddOpen {
    my $file = shift;
    my @open_files = @{$config->{open_files}};

    if (ref($file) eq 'ARRAY') {
	foreach my $f (@{$file}) {
	    push(@open_files, $f);
	}
    }
    else {
	push(@open_files, $file);
    }
    $config->{open_files} = \@open_files;
}

sub Remove_Duplicates {
    my $me = shift;
    my $accession = shift;
    my $info = $me->MySelect(qq"SELECT id,start,seqlength,algorithm FROM mfe WHERE accession = '$accession'");
    my @duplicate_ids;
    my $dups = {};
    my $count = 0;
    foreach my $datum (@{$info}) {
	my $id = $datum->[0];
	my $start = $datum->[1];
	my $seqlength = $datum->[2];
	my $alg = $datum->[3];

	if (!defined($dups->{$start})) {  ## Start
	    $dups->{$start} = {};
	}
	
	if (!defined($dups->{$start}->{$seqlength})) {
	    $dups->{$start}->{$seqlength} = {};
	    $dups->{$start}->{$seqlength}->{pknots} = [];
	    $dups->{$start}->{$seqlength}->{nupack} = [];
	    $dups->{$start}->{$seqlength}->{hotknots} = [];
	}
	my @array = @{$dups->{$start}->{$seqlength}->{$alg}};
	push(@array, $id);
	$dups->{$start}->{$seqlength}->{$alg} = \@array;
    }
    
    foreach my $st (sort keys %{$dups}) {
	foreach my $len (sort keys %{$dups->{$st}}) {
	    my @nupack = @{$dups->{$st}->{$len}->{nupack}};
	    my @pknots = @{$dups->{$st}->{$len}->{pknots}};
	    my @hotknots = @{$dups->{$st}->{$len}->{hotknots}};
	    shift @nupack;
	    shift @pknots;
	    shift @hotknots;
	    foreach my $id (@nupack) {
		$me->MyExecute("DELETE FROM mfe WHERE id = '$id'");
		$count++;
	    }
	    foreach my $id (@pknots) {
		$me->MyExecute("DELETE FROM mfe WHERE id = '$id'");
		$count++;
	    }
	    foreach my $id (@hotknots) {
		$me->MyExecute("DELETE FROM mfe WHERE id = '$id'");
		$count++;
	    }
	}
    }
    return($count);
}

sub RemoveFile {
    my $file = shift;
    my @open_files = @{$config->{open_files}};
    my @new_open_files = ();
    my $num_deleted = 0;
    my @comp = ();
    
    if ($file eq 'all') {
	foreach my $f (@{open_files}) {
	    unlink($f);
	    print STDERR "Deleting: $f\n" if (defined($config->{debug}) and $config->{debug} > 0);
	    $num_deleted++;
	}
	$config->{open_files} = \@new_open_files;
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
    $config->{open_files} = \@new_open_files;
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
    my $table = ($species =~ /virus/ ? "boot_virus" : "boot_$species");
    $config->PRF_Error("Undefined value in Get_Boot", $species, $accession)
	unless (defined($species) and defined($accession));
    my $statement;
    if (defined($start)) {
	$statement = qq(SELECT * FROM $table WHERE accession = ? AND start = ? ORDER BY start);
    } 
    else {
	$statement = qq(SELECT * from $table where accession = ? ORDER BY start);
    }
    my $info = $me->MySelect(statement =>$statement, vars => [$accession, $start], type => 'hash', descriptor => 1);
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
    $config->PRF_Error("Undefined value in Id_to_AccessionSpecies", $id) unless (defined($id));
    my $statement = qq(SELECT accession, species from genome where id = ?);
    my $data = $me->MySelect(statement => $statement, vars => [$id], type => 'row');
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
    my $ids = $me->MySelect(statement =>$statement);
    return ($ids);
}

sub Add_Webqueue {
    my $me = shift;
    my $id = shift;
    my $check = $me->MySelect(statement => qq/SELECT count(id) FROM webqueue WHERE genome_id = '$id'/, type => 'single');
    return(undef) if ($check > 0);
    my $statement = qq/INSERT INTO webqueue VALUES('','$id','0','','0','')/;
    my ($cp,$cf,$cl) = caller();
    my $rc = $me->MyExecute(statement => $statement, caller => "$cp,$cf,$cl",);
    return(1);
}

sub Set_Queue {
    my $me = shift;
    my %args = @_;
    my $id = $args{id};
    my $table = 'queue';
    if (defined($config->{queue_table})) {
	$table = $config->{queue_table};
    }
    if (defined($args{queue_table})) {
	$table = $args{queue_table};
    }
    my $num_existing_stmt = qq"SELECT count(id) FROM $table WHERE genome_id = '$id'";
    my $num_existing = $me->MySelect(statement => $num_existing_stmt,type => 'single',);
    if (!defined($num_existing) or $num_existing == 0) {
	my $statement = qq"INSERT INTO $table VALUES('','$id','0','','0','')";
	my ($cp,$cf,$cl) = caller();
	my $rc = $me->MyExecute(statement => $statement, caller => "$cp,$cf,$cl",);
	my $last_id = $me->MySelect(statement => 'SELECT LAST_INSERT_ID()', type => 'single');
	return ($last_id);
    }
    else {
	my $id_existing_stmt = qq(SELECT id FROM $table WHERE genome_id = '$id');
	my $id_existing = $me->MySelect(statement => $id_existing_stmt, type => 'single');
	return($id_existing);
    }
}

sub Clean_Table {
    my $me = shift;
    my $type = shift;
    my $table = $type . '_' . $config->{species};
    my $statement = "DELETE from $table";
    my ($cp,$cf,$cl) = caller();
    $me->MyExecute(statement =>$statement, caller=>"$cp, $cf, $cl");
}

sub Drop_Table {
    my $me = shift;
    my $table = shift;
    my $statement = "DROP table $table";
    my ($cp,$cf,$cl) = caller();
    $me->MyExecute(statement => $statement, caller =>"$cp, $cf, $cl");
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
    $me->MyExecute(statement => $best_statement, caller =>"$cp, $cf, $cl");
}

sub Copy_Genome {
    my $me = shift;
    my $old_db = shift;
    my $new_db = $config->{db};
    my $statement = qq/INSERT INTO ${new_db}.genome
(accession,species,genename,locus,ontology_function,ontology_component,ontology_process,version,comment,mrna_seq,protein_seq,orf_start,orf_stop,direction,omim_id)
    SELECT accession,species,genename,locus,ontology_function,ontology_component,ontology_process,version,comment,mrna_seq,protein_seq,orf_start,orf_stop,direction,omim_id from ${old_db}.genome/;
my ($cp,$cf,$cl) = caller();
$me->MyExecute(statement => $statement, caller =>"$cp, $cf, $cl");
}

sub Reset_Queue {
    my $me = shift;
    my %args = @_;
    my $table = $args{table};
    my $complete = $args{complete};
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
    $me->MyExecute(statement => $statement, caller => "$cp, $cf, $cl");
}

sub Get_Input {
    my $me = shift;
    my $queue_table = $config->{queue_table};
    my $genome_table = $config->{genome_table};
    my $query = qq(SELECT ${queue_table}.id, ${queue_table}.genome_id, ${genome_table}.accession,
		   ${genome_table}.species, ${genome_table}.mrna_seq, ${genome_table}.orf_start,
		   ${genome_table}.direction FROM ${queue_table}, ${genome_table} WHERE ${queue_table}.checked_out = '0'
		   AND ${queue_table}.done = '0' AND ${queue_table}.genome_id = ${genome_table}.id LIMIT 1);
    my $ids = $me->MySelect(statement => $query,type => 'row');
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
    $me->MyExecute(statement => $update,  vars => [$id], caller => "$cp, $cf, $cl");
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
	} else {
	    $queue = $me->Get_Queue();
	    return ($queue);
	}
	## End check webqueue
    } else {
	$queue = $me->Get_Queue();
	if (!defined($queue)) {
	    print "There are no more entries in the queue.\n";
	}
	return ($queue);
    }
}

sub Get_Import_Queue {
    my $me = shift;
    my $stmt = qq"SELECT accession FROM import_queue LIMIT 1";
    my $id = $me->MySelect(statement => $stmt, type => 'single');
    return($id);
}

sub Get_Queue {
    my $me = shift;
    my $queue_name = shift;
    my $table = 'queue';
    if (defined($queue_name)) {
	$table = $queue_name;
    } elsif (defined($config->{queue_table})) {
	$table = $config->{queue_table};
    }
    unless ($me->Tablep($table)) {
	$me->Create_Queue($table);
	$me->Reset_Queue($table, 'complete');
    }
    ## This id is the same id which uniquely identifies a sequence in the genome database
    my $single_id;
    if ($config->{randomize_id}) {
	$single_id = qq"SELECT id, genome_id FROM $table WHERE checked_out = '0' ORDER BY RAND() LIMIT 1";
    } else {
	$single_id = qq"SELECT id, genome_id FROM $table WHERE checked_out = '0' LIMIT 1";
    }
    my $ids = $me->MySelect(statement => $single_id, type => 'row');
    my $id = $ids->[0];
    my $genome_id = $ids->[1];
    if (!defined($id) or $id eq '' or !defined($genome_id) or $genome_id eq '') {
	## This should mean there are no more entries to fold in the queue
	## Lets check this for truth -- first see if any are not done
	## This should come true if the webqueue is empty for example.
	my $done_id = qq(SELECT id, genome_id FROM $table WHERE done = '0' LIMIT 1);
	my $ids = $me->MySelect(statement => $done_id, type =>'row');
	$id = $ids->[0];
	$genome_id = $ids->[1];
	if (!defined($id) or $id eq '' or !defined($genome_id) or $genome_id eq '') {
	    return(undef);
	}
    }
    my $update = qq"UPDATE $table SET checked_out='1', checked_out_time=current_timestamp() WHERE id=?";
    my ($cp, $cf, $cl) = caller();
    $me->MyExecute(statement => $update, vars=> [$id], caller =>"$cp, $cf, $cl");
    my $return = {
	queue_table => $table,
	queue_id  => $id,
	genome_id => $genome_id,
    };
    return ($return);
}

sub Copy_Queue {
    my $me = shift;
    my $old_table = shift;
    my $new_table = shift;
    my $statement = "INSERT INTO $new_table SELECT * FROM $old_table";
    my ($cp,$cf,$cl) = caller();
    $me->MyExecute(statement => $statement, caller =>"$cp, $cf, $cl");
}

sub Done_Queue {
    my $me = shift;
    my $table = shift;
    my $id = shift;
    if (!defined($table)) {
	if (defined($config->{queue_table})) {
	    $table = $config->{queue_table};
	}
	else {
	    $table = 'queue';
	}
    }
    my $update = qq/UPDATE $table SET done='1', done_time=current_timestamp() WHERE genome_id=?/;
    my ($cp,$cf,$cl) = caller();
    $me->MyExecute(statement => $update, vars => [$id], caller =>"$cp, $cf, $cl");
}

sub Import_Fasta {
    my $me = shift;
    my $file = shift;
    my $style = shift;
    my $startpos = shift;
    my @return_array;
    print "Starting Import_Fasta  with with style = $style\n";
    open(IN, "<$file") or die "Could not open the input file. $!";
    my %datum = (accession => undef, genename => undef, version => undef, comment => undef, mrna_seq => undef);
    my $linenum = 0;
    if (defined($config->{species})) {
	print "Species is defined as $config->{species}\n";
    } else {
	die ("Species must be defined.");
    }
    while (my $line = <IN>) {
	$linenum++;
	chomp $line;
	if ($line =~ /^\>/) {
            ## Do the actual insertion here, regardless of style
            if ($linenum > 1) {
                if (defined($config->{startpos})) {
                    $datum{orf_start} = $config->{startpos};
                }
                else {
                    $datum{orf_start} = 1;
                }
                if (defined($config->{endpos})) {
                    if ($config->{endpos} > 0) {
                        $datum{orf_stop} = $config->{end_pos};
                    }
                    else {  ## A negative offset
                        $datum{orf_stop} = length($datum{mrna_seq}) - $config->{endpos};
                    }
                }
                else {
                    $datum{orf_stop} = length($datum{mrna_seq});
                }
                my $genome_id = $me->Insert_Genome_Entry(\%datum);
                my $queue_id = $me->Set_Queue(id => $genome_id,);
                my $queue_num = "$queue_id";
                print "Added $queue_num\n";
                push(@return_array, $queue_num);
            }
	    if (defined($style)) {
		if ($style eq 'sgd') {
		    %datum = (accession => undef,
			      genename => undef,
			      version => undef,
			      comment => undef,
			      mrna_seq => undef,);
		    my ($fake_accession, $comment)  = split(/\,/, $line);
		    my ($accession, $genename) = split(/ /,  $fake_accession);
		    $accession =~ s/^\>//g;
                    $accession =~ s/ORFN//g;
		    $datum{accession} = $accession;
		    $datum{genename} = $genename;
		    $datum{comment} = $comment;
		    $datum{genename} = $genename;
		    $datum{protein_seq} = '';
		    $datum{direction} = 'forward';
		    $datum{defline} = $line;
                    $datum{species} = $config->{species};
		}    ## End if the style is sgd
		elsif ($style eq 'celegans') {
                    %datum = (accession => undef,
                              genename => undef,
                              version => undef,
                              comment => undef,
                              mrna_seq => undef,);
                    my ($accession, $genename) = split(/\|/, $line);
                    $accession =~ s/\>//g;
                    $datum{genename} = $genename;
                    $datum{accession} = $accession;
                    $datum{species} = $config->{species};
		    if (!defined($datum{genename})) {
                        $datum{genename} = $datum{accession};
                    }
                    if (!defined($datum{version})) {
                        $datum{version} = 1;
                    }
                }    ## End if the style is sgd

		elsif ($style eq 'celegans') {
                    %datum = (
			      accession => undef,
			      genename => undef,
			      version => undef,
			      comment => undef,
			      mrna_seq => undef
			      );
                    my ($accession, $genename) = split(/\|/, $line);
                    $accession =~ s/\>//g;
                    $datum{genename} = $genename;
                    $datum{accession} = $accession;
                    $datum{species} = $config->{species};
                }


		elsif ($style eq 'mgc') {
		    %datum = (accession => undef,
			      genename => undef,
			      version => undef,
			      comment => undef,
			      mrna_seq => undef,);
		    my ($gi_trash, $gi_id, $gb_trash, $accession_version, $comment) = split(/\|/, $line);
		    my ($accession, $version);
		    if ($accession_version =~ m/\./) {
			($accession, $version) = split(/\./, $accession_version);
		    }
		    else {
			$accession = $accession_version;
			$version   = '0';
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
	    }    ## End if the style is defined.
	    else {
		print "Style is not defined.\n";
	    }
	}    ## End if you are on a > line
	else {
	    $line =~ s/\s//g;
	    $line =~ s/\d//g;
	    $datum{mrna_seq} .= $line;
	    ## The line after every Import_CDS had better clear datum{mrna_seq} or the sequence
	    ## will grow with every new sequence.
	}    ## Not an accession line
    }    ## End looking at every line.
    close(IN);
    if (!defined($datum{species})) {
        $datum{species} = $config->{species};
    }
    $datum{orf_start} = 0;
    $datum{orf_stop}  = length($datum{mrna_seq});
    if (!defined($datum{protein_seq}) or $datum{protein_seq} eq '') {
	my $seq = new SeqMisc(sequence => $datum{mrna_seq});
	my $aa_seq = $seq->{aaseq};
	my $aa = '';
	foreach my $c (@{$aa_seq}) { $aa .= $c; }
	$datum{protein_seq} = $aa;
    }
    
    my $genome_id = $me->Insert_Genome_Entry(\%datum);
    my $queue_id = $me->Set_Queue(id => $genome_id,);
    print "Added $queue_id\n" if(defined($config->{debug}));
    push(@return_array, $queue_id);
    return (\@return_array);
}

sub Import_Genbank_Flatfile {
    my $me = shift;
    my $input_file = shift;
    my $species = shift;
    my $padding = shift;

    my $uni = new Bio::DB::Universal();
    my $in  = Bio::SeqIO->new(-file => $input_file,
			      -format => 'genbank');
    while (my $seq = $in->next_seq()) {
	my $accession = $seq->accession();
	my @cds = grep {$_->primary_tag eq 'CDS'} $seq->get_SeqFeatures();
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
	my @mrna_seq = split(//, $mrna_sequence);
	my $counter = 0;
	my $num_cds = scalar(@cds);
	foreach my $feature (@cds) {
	    $counter++;
	    my $primary_tag = $feature->primary_tag();
	    $protein_sequence = $feature->seq->translate->seq();
	    $orf_start = $feature->start();
	    $orf_stop = $feature->end();
	    #    print "START: $orf_start STOP: $orf_stop $feature->{_location}{_strand}\n";
	    ### $feature->{_location}{_strand} == -1 or 1 depending on the strand.
	    my ($direction, $start, $stop);
	    if (!defined($feature->{_location}{_strand})) {
		$direction = 'undefined';
		$start = $orf_start;
		$stop = $orf_stop;
	    }
	    elsif ($feature->{_location}{_strand} == 1) {
		$direction = 'forward';
		$start = $orf_start;
		$stop = $orf_stop;
	    }
	    elsif ($feature->{_location}{_strand} == -1) {
		$direction = 'reverse';
		$start = $orf_stop;
		$stop = $orf_start;
	    }
	    if (defined($padding)) {
		$orf_start = $orf_start - $padding;
		$orf_stop = $orf_stop + $padding;
	    }
	    my $tmp_mrna_sequence = '';
	    foreach my $c (($orf_start - 1) .. ($orf_stop - 1)) {
		next if (!defined($mrna_seq[$c]));
		$tmp_mrna_sequence .= $mrna_seq[$c];
	    }
	    if ($direction eq 'reverse') {
		$tmp_mrna_sequence =~ tr/ATGCatgcuU/TACGtacgaA/;
		$tmp_mrna_sequence = reverse($tmp_mrna_sequence);
	    }
	    my $mrna_seqlength = length($tmp_mrna_sequence);
	    my %datum = (### FIXME
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
			 defline => $defline,);
	    # my $return;
	    # my $genome_id = $me->Insert_Genome_Entry(\%datum);
	    # if (defined($genome_id)) {
	    # my $return = "Inserting $mrna_seqlength bases into the genome table with id: $genome_id\n";
	    # $me->Set_Queue(id => $genome_id);
	    # }
	    # else {
	    # $return .= "Did not insert anything into the genome table.\n";
	    # my $gid = $me->MySelect(
	    # statement => "SELECT id FROM genome WHERE accession = '$datum{accession}'",
	    # type => 'single');
	    # print "Doing set_Queue with genome_id $gid\n";
	    # $me->Set_Queue(id => $gid);
	    # }
	    # print $return;
	    #}
	    #return ($return);
	    foreach my $k (keys %datum) {
		print "key: $k data: $datum{$k}\n";
	    }
	} ## foreach feature in @cds
	print "Done this CDS\n\n\n";
    } # NEXT_SEQ
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
    my $return = undef;
    my $uni = new Bio::DB::Universal;
    my $seq;
    try {
	$seq = $uni->get_Seq_by_id($accession);
    }
    catch Bio::Root::Exception with {
	my $err = shift;
	return("Error $err");
    };
    if (!defined($seq)) {
	print "seq is not defined\n";
	return(undef);
    }
    my @cds = grep {$_->primary_tag eq 'CDS'} $seq->get_SeqFeatures();
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
    return(0) if ($num_cds == 0); ## This return 0 is important, don't undef it.
    foreach my $feature (@cds) {
	my $tmp_mrna_sequence = $mrna_sequence;
	$counter++;
	my $primary_tag = $feature->primary_tag();
	$protein_sequence = $feature->seq->translate->seq();
	$orf_start = $feature->start();
	$orf_stop = $feature->end();
	#    print "START: $orf_start STOP: $orf_stop $feature->{_location}{_strand}\n";
	### $feature->{_location}{_strand} == -1 or 1 depending on the strand.
	my $direction;
	if (!defined($feature->{_location}{_strand})) {
	    $direction = 'forward';
	} elsif ($feature->{_location}{_strand} == 1) {
	    $direction = 'forward';
	} elsif ($feature->{_location}{_strand} == -1) {
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
	} else {
	    $config->PRF_Error("WTF: Direction is not forward or reverse");
	    $direction = 'forward';
	}
	### Don't change me, this is provided by genbank
	### FINAL TEST IF $startpos is DEFINED THEN OVERRIDE WHATEVER YOU FOUND
	if (defined($startpos)) {
	    $orf_start = $startpos;
	}
	my $mrna_seqlength = length($tmp_mrna_sequence);
	my %datum = (### FIXME
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
		     defline => $defline,);
	my $genome_id = $me->Insert_Genome_Entry(\%datum);
	if (defined($genome_id)) {
	    $return = $mrna_seqlength;
	    $me->Set_Queue(id => $genome_id);
	} else {
	    $return = 0;
	    my $gid = $me->MySelect(statement => "SELECT id FROM genome WHERE accession = '$datum{accession}'",	type => 'single');
	    $me->Set_Queue(id => $gid);
	}
    }
    return ($return);
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
    return ($orf_sequence);
}

sub Get_OMIM {
    my $me = shift;
    my $id = shift;
    my $statement = qq(SELECT omim_id FROM genome WHERE id = ?);
    my $omim = $me->MySelect(statement => $statement, vars => [$id], type => 'single');
    if (!defined($omim) or $omim eq 'none') {
	return (undef);
    }
    elsif ($omim =~ /\d+/) {
	return ($omim);
    }
    else {
	my $uni = new Bio::DB::Universal;
	my $seq = $uni->get_Seq_by_id($id);
	my @cds = grep {$_->primary_tag eq 'CDS'} $seq->get_SeqFeatures();
	my $omim_id = '';
	foreach my $feature (@cds) {
	    my $db_xref_list = $feature->{_gsf_tag_hash}->{db_xref};
	    foreach my $db (@{$db_xref_list}) {
		if ($db =~ /^MIM\:/) {
		    $db =~ s/^MIM\://g;
		    $omim_id .= "$db ";
		}    ## Is it in omim?
	    }    ## Possible databases
	}    ## CDS features
	$statement = qq(UPDATE genome SET omim_id = ? WHERE id = ?);
	my ($cp,$cf,$cl) = caller();
	$me->MyExecute(statement => $statement, vars => [ $omim_id, $id ], caller =>"$cp, $cf, $cl",);
	return ($omim_id);
    }
}

sub Get_Sequence {
    my $me = shift;
    my $accession = shift;
    my $statement = qq(SELECT mrna_seq FROM genome WHERE accession = ?);
    my $sequence  = $me->MySelect(statement => $statement, vars => [$accession], type => 'single');
    if ($sequence) {
	return ($sequence);
    }
    else {
	return (undef);
    }
}

sub Get_Sequence_from_id {
    my $me = shift;
    my $id = shift;
    my $statement = qq(SELECT mrna_seq FROM genome WHERE id = ?);
    my $sequence = $me->MySelect(statement => $statement, vars => [$id], type => 'single');
    if ($sequence) {
	return ($sequence);
    }
    else {
	return (undef);
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
    return ($return);
}

sub Get_MFE_ID {
    my $me = shift;
    my $genome_id = shift;
    my $start = shift;
    my $seqlength = shift;
    my $algorithm = shift;
    my $statement = qq(SELECT id FROM mfe WHERE genome_id = ? AND start = ? AND seqlength = ? AND algorithm = ? LIMIT 1);
    my $mfe = $me->MySelect(statement =>$statement, vars => [$genome_id, $start, $seqlength, $algorithm], type => 'single');
    return ($mfe);
}

sub Get_Num_RNAfolds {
    my $me = shift;
    my $algo = shift;
    my $genome_id = shift;
    my $slipsite_start = shift;
    my $seqlength = shift;
    my $table = shift;
    $table = 'mfe' unless (defined($table));
    $table = "boot_virus" if ($table =~ /boot/ and $table =~ /virus/);
    $table = "landscape_virus" if ($table =~ /landscape/ and $table =~ /virus/);
    my $return = {};
    my $statement = qq/SELECT count(id) FROM $table WHERE genome_id = ? AND algorithm = ? AND start = ? AND seqlength = ?/;
    my $count = $me->MySelect(statement =>$statement, vars => [$genome_id, $algo, $slipsite_start, $seqlength], type => 'single');
    if (!defined($count) or $count eq '') {
	$count = 0;
    }
    return ($count);
}

sub Get_Num_Bootfolds {
    my $me = shift;
    my %args = @_;
    my $species = $args{species};
    my $genome_id = $args{genome_id};
    my $start = $args{start};
    my $seqlength = $args{seqlength};
    my $method = $args{method};
    my $table = ($species =~ /virus/ ? "boot_virus" : "boot_$species");
    my $return = {};
    my $statement = qq/SELECT count(id) FROM $table WHERE genome_id = ? and start = ? and seqlength = ? and mfe_method = ?/;
    my $count = $me->MySelect(statement => $statement, vars => [$genome_id, $start, $seqlength, $method], type =>'single');
    return ($count);
}

sub Get_mRNA {
    my $me = shift;
    my $accession = shift;
    my $statement = qq/SELECT mrna_seq, orf_start, orf_stop FROM genome WHERE accession = ?/;
    my $info = $me->MySelect(statement => $statement, vars => [$accession], type => 'hash');
    my $mrna_seq  = $info->{mrna_seq};
    if ($mrna_seq) {
	return ($mrna_seq);
    }
    else {
	return (undef);
    }
}

sub Get_ORF {
    my $me = shift;
    my $accession = shift;
    my $statement = qq"SELECT mrna_seq, orf_start, orf_stop FROM genome WHERE accession = ?";
    my $info = $me->MySelect(statement => $statement, vars => [$accession], type => 'hash');
    my $mrna_seq = $info->{mrna_seq};
    ### A PIECE OF CODE TO HANDLE PULLING SUBSEQUENCES FROM CDS                                                         
    my $start = $info->{orf_start} - 1;
    my $stop = $info->{orf_stop} - 1;
    my $offset = $stop - $start;
    my $sequence = substr($mrna_seq, $start, $offset);
    ## If I remove the substring, Then it should return from the start
    ## codon to the end of the mRNA which is good                                  
    ## For searching over viral sequence!
    ### DONT SCAN THE ENTIRE MRNA, ONLY THE ORF
    if ($sequence) {
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
    my $already_id = $me->MySelect(statement => $check, vars => [$datum->{accession}], type => 'single');
    ## A check to make sure that the orf_start is not 0.  If it is, set it to 1 so it is consistent with the
    ## crap from the SGD
    $datum->{orf_start} = 1 if (!defined($datum->{orf_start}) or $datum->{orf_start} == 0);
    if (defined($already_id)) {
	print "The accession $datum->{accession} is already in the database with id: $already_id\n";
	return ($already_id);
    }
    $datum->{version} = 0 if (!defined($datum->{version}));
    $datum->{comment} = "" if (!defined($datum->{comment}));
#    my $statement = qq(INSERT INTO genome
#(accession,species,genename,version,comment,mrna_seq,protein_seq,orf_start,orf_stop,direction)
#    VALUES('$datum->{accession}', '$datum->{species}', '$datum->{genename}', '$datum->{version}', '$datum->{comment}', '$datum->{mrna_seq}', '$datum->{protein_seq}', '$datum->{orf_start}', '$datum->{orf_stop}', '$datum->{direction}'));
    my $statement = qq"INSERT DELAYED INTO genome
(accession,species,genename,version,comment,mrna_seq,protein_seq,orf_start,orf_stop,direction)
VALUES(?,?,?,?,?,?,?,?,?,?)";
my ($cp,$cf,$cl) = caller();
$me->MyExecute(statement => $statement,
               caller => "$cp, $cf, $cl",
               vars => [$datum->{accession}, $datum->{species}, $datum->{genename}, $datum->{version}, $datum->{comment}, $datum->{mrna_seq}, $datum->{protein_seq}, $datum->{orf_start}, $datum->{orf_stop}, $datum->{direction}],);
## The following line is very important to ensure that multiple
## calls to this don't end up with
## Increasingly long sequences
foreach my $k (keys %{$datum}) {$datum->{$k} = undef;}
my $last_id = $me->MySelect(statement => 'SELECT LAST_INSERT_ID()', type => 'single');
return ($last_id);
}

sub Insert_Numslipsite {
    my $me = shift;
    my $accession = shift;
    my $num_slipsite = shift;
    my $statement = qq/INSERT IGNORE INTO numslipsite
(accession, num_slipsite)
VALUES('$accession', '$num_slipsite')/;
    my ($cp,$cf,$cl) = caller();
    $me->MyExecute(statement =>$statement, caller => "$cp, $cf, $cl");
    my $last_id = $me->MySelect(statement => 'SELECT LAST_INSERT_ID()', type => 'single');
    return ($last_id);
}

sub Get_MFE {
    my $me = shift;
    my $identifier = shift; ## { genome_id => #, species => #, accession => #, start => # }
    my $statement = '';
    my $info;
    if (defined($identifier->{genome_id})) {
	$statement = qq(SELECT id, genome_id, species, accession, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode FROM mfe where genome_id = ?);
	$info = $me->MySelect(statement =>$statement, vars => [$identifier->{genome_id}], type => 'hash',
			       descriptor => [qq(id genome_id species accession start slipsite seqlength sequence output parsed parens mfe pairs knotp barcode)],);
    } 
    elsif (defined($identifier->{accession} and defined($identifier->{start}))) {
	$statement = qq(SELECT id, genome_id, species, accession, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode FROM mfe where accession = ? and start = ?);
	$info = $me->MySelect(statement => $statement, vars => [$identifier->{accession}, $identifier->{start}], type => 'hash',
			       descriptor => [qq(id genome_id species accession start slipsite seqlength sequence output parsed parens mfe pairs knotp barcode)],);
    }
    return ($info);
}

sub Put_Nupack {
    my $me = shift;
    my $data = shift;
    my $table = shift;
    my $mfe_id = shift;
    if (defined($table) and $table =~ /^landscape/) {
	$mfe_id = $me->Put_MFE_Landscape('nupack', $data, $table);
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
    if (defined($table) and $table =~ /^landscape/) {
	$mfe_id = $me->Put_MFE_Landscape('hotknots', $data, $table);
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
    if (defined($table) and $table =~ /^landscape/) {
	$mfe_id = $me->Put_MFE_Landscape('vienna', $data, $table);
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
    if (defined($table) and $table =~ /^landscape/) {
	$mfe_id = $me->Put_MFE_Landscape('pknots', $data, $table);
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
	$config->PRF_Error($errorstring, $data->{species}, $data->{accession});
    }
    $data->{sequence} =~ tr/actgu/ACTGU/;
    my $statement = qq(INSERT INTO $table (genome_id, species, algorithm, accession, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?));
    
    my ($cp,$cf,$cl) = caller();
    $me->MyExecute(statement => $statement, vars => [$data->{genome_id}, $data->{species}, $algo, $data->{accession}, $data->{start}, $data->{slipsite}, $data->{seqlength}, $data->{sequence}, $data->{output}, $data->{parsed}, $data->{parens}, $data->{mfe}, $data->{pairs}, $data->{knotp}, $data->{barcode}], caller => "$cp, $cf, $cl",);
    
    my $put_id = $me->MySelect(statement => 'SELECT LAST_INSERT_ID()', type => 'single');
    return ($put_id);
}    ## End of Put_MFE

sub Put_MFE_Landscape {
    my $me = shift;
    my $algo = shift;
    my $data = shift;
    my $table = shift;
    ## What fields do we want to fill in this MFE table?
    $table = 'landscape_virus' if ($table =~ /virus/);
	
    my @filled;
    if ($algo eq 'vienna') {
	@filled = ('genome_id','species','accession','start','seqlength','sequence','parens','mfe');
    }
    else {
	@filled = ('genome_id', 'species', 'accession', 'start', 'seqlength', 'sequence', 'output', 'parsed', 'parens', 'mfe', 'pairs', 'knotp', 'barcode');
    }
    my $errorstring = Check_Insertion(\@filled, $data);
    if (defined($errorstring)) {
	$errorstring = "Undefined value(s) in Put_MFE_Landscape: $errorstring";
	$config->PRF_Error($errorstring, $data->{accession});
    }
    if (defined($data->{sequence})) {
	$data->{sequence} =~ tr/actgu/ACTGU/;
    } else {
	callstack();
	print STDERR "Sequence is not defined for Species:$data->{species}, Accession:$data->{accession}, Start:$data->{start}, Seqlength:$data->{seqlength}\n";
	return(undef);
    }
    my $statement = qq"INSERT DELAYED INTO $table (genome_id, species, algorithm, accession, start, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
    my ($cp,$cf,$cl) = caller();
    my $rows = $me->MyExecute(statement => $statement, vars => [$data->{genome_id}, $data->{species}, $algo, $data->{accession}, $data->{start}, $data->{seqlength}, $data->{sequence}, $data->{output}, $data->{parsed}, $data->{parens}, $data->{mfe}, $data->{pairs}, $data->{knotp}, $data->{barcode}], caller =>"$cp,$cf,$cl",);
    return ($rows);
}    ## End put_mfe_landscape

sub Put_Agree {
    my $me = shift;
    my %args = @_;
    my $agree = $args{agree};
    my $check = $me->MySelect(statement => "SELECT count(id) FROM agree WHERE accession = ? AND start = ? AND length = ?", vars => [$args{accession}, $args{start}, $args{length}], type => 'single');
    return(undef) if ($check >= 1);
    my ($cp,$cf,$cl) = caller();
    my $stmt = qq"INSERT DELAYED INTO agree (accession, start, length, all_agree, no_agree, n_alone, h_alone, p_alone, hplusn, nplusp, hplusp, hnp) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)";
    my $rows = $me->MyExecute(statement => $stmt,
		   vars => [$args{accession}, $args{start}, $args{length}, $agree->{all}, $agree->{none}, $agree->{n}, $agree->{h}, $agree->{p}, $agree->{hn}, $agree->{np}, $agree->{hp}, $agree->{hnp}],
		   caller =>"$cp,$cf,$cl");
    return($rows);
}

sub Put_Stats {
    my $me = shift;
    my $data = shift;
    my $finished = shift;
    my $inserted_rows = 0;
    $finished = [] if (!defined($finished));
	
    OUT: foreach my $species (@{$data->{species}}) {
	foreach my $sp (@{$finished}) {
	    next OUT if ($sp eq $species);
	}
	my $table = ($species =~ /virus/ ? "boot_virus" : "boot_$species");
	$me->MyExecute(statement => qq"DELETE FROM stats WHERE species = '$species'");
	foreach my $seqlength (@{$data->{seqlength}}) {
	    foreach my $max_mfe (@{$data->{max_mfe}}) {
		foreach my $algorithm (@{$data->{algorithm}}) {
		    #  0    1    2     3     4    5     6     7     8
		    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		    my $timestring = "$mon/$mday $hour:$min.$sec";
		    print "$timestring  Now doing $species $seqlength $max_mfe $algorithm\n";
		    my $statement = qq"INSERT DELAYED INTO stats
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
(SELECT avg(zscore) FROM $table WHERE mfe_method = '$algorithm' AND species = '$species' AND seqlength = '$seqlength'),
(SELECT stddev(zscore) FROM $table WHERE mfe_method = '$algorithm' AND species = '$species' AND seqlength = '$seqlength')
    )";
                  my ($cp,$cf,$cl) = caller();
                  my $rows = $me->MyExecute(statement => $statement, caller => "$cp, $cf, $cl",);
                  $inserted_rows = $inserted_rows + $rows;
                }
            }
        }
    }
  return($inserted_rows);
}

sub Put_Boot {
    my $me = shift;
    my $data = shift;
    my $id = $data->{genome_id};
    my @boot_ids = ();
    my $rows = 0;
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
		$config->PRF_Error($errorstring, $species, $accession);
	    }
	    my $boot_table = ($species =~ /virus/ ? "boot_virus" : "boot_$species");
#	    my $statement = qq"INSERT INTO $boot_table
	    my $statement = qq"INSERT DELAYED INTO $boot_table
(genome_id, mfe_id, species, accession, start, seqlength, iterations, rand_method, mfe_method, mfe_mean, mfe_sd, mfe_se, pairs_mean, pairs_sd, pairs_se, mfe_values)
    VALUES
(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
            my $undefined_values = Check_Defined(genome_id => $data->{genome_id}, mfe_id => $mfe_id, species => $species, accession => $accession, start => $start, seqlength => $seqlength, iterations => $iterations, rand_method => $rand_method, mfe_method => $mfe_method, mfe_mean => $mfe_mean, mfe_sd => $mfe_sd, mfe_se => $mfe_se, pairs_mean => $pairs_mean, pairs_sd => $pairs_sd, pairs_se => $pairs_se, mfe_values => $mfe_values);
            if ($undefined_values) {
              $errorstring = "An error occurred in Put_Boot, undefined values: $undefined_values\n";
              $config->PRF_Error( $errorstring, $species, $accession );
              print "$errorstring, $species, $accession\n";
            }
            my ($cp, $cf, $cl) = caller();
            my $inserted_rows = $me->MyExecute(statement => $statement, vars => [ $data->{genome_id}, $mfe_id, $species, $accession, $start, $seqlength, $iterations, $rand_method, $mfe_method, $mfe_mean, $mfe_sd, $mfe_se, $pairs_mean, $pairs_sd, $pairs_se, $mfe_values ], caller => "$cp, $cf, $cl",);
            $rows = $rows + $inserted_rows;

#            my $boot_id = $me->MySelect(statement => 'SELECT LAST_INSERT_ID()', type => 'single');
#            push(@boot_ids, $boot_id);
          }    ### Foreach random method
    }    ## Foreach mfe method
#    return(\@boot_ids);
     return($rows);
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
	$config->PRF_Error($errorstring, $species, $accession);
    }
    my $table = ($species =~ /virus/ ? "boot_virus" : "boot_$species");
#    my $statement = qq"INSERT INTO $table
    my $statement = qq"INSERT DELAYED INTO $table
(genome_id, mfe_id, species, accession, start, seqlength, iterations, rand_method, mfe_method, mfe_mean, mfe_sd, mfe_se, pairs_mean, pairs_sd, pairs_se, mfe_values)
    VALUES
('$data->{genome_id}','$mfe_id','$species','$accession','$start','$seqlength','$iterations','$rand_method','$mfe_method','$mfe_mean','$mfe_sd','$mfe_sd','$pairs_mean','$pairs_sd','$pairs_se','$mfe_values')";

    my $undefined_values = Check_Defined(genome_id => $data->{genome_id}, mfe_id => $mfe_id, species => $species, accession => $accession, start => $start, seqlength => $seqlength, iterations => $iterations, rand_method => $rand_method, mfe_method => $mfe_method, mfe_mean => $mfe_mean, mfe_sd => $mfe_sd, mfe_se => $mfe_se, pairs_mean => $pairs_mean, pairs_sd => $pairs_sd, pairs_se => $pairs_se, mfe_values => $mfe_values);

    if ($undefined_values) {
        $errorstring = "An error occurred in Put_Boot, undefined values: $undefined_values\n";
        $config->PRF_Error($errorstring, $species, $accession);
        print "$errorstring, $species, $accession\n";
    }
    my ($cp, $cf, $cl) = caller();
    my $rows = $me->MyExecute(statement => $statement, caller => "$cp, $cf, $cl",);

#    my $boot_id = $me->MySelect(statement => 'SELECT LAST_INSERT_ID()', type => 'single');
#    print "Inserted $boot_id\n";
#    return($boot_id);
     return($rows);
}

sub Put_Overlap {
    my $me = shift;
    my $data = shift;
    my $statement = qq(INSERT DELAYED INTO overlap
(genome_id, species, accession, start, plus_length, plus_orf, minus_length, minus_orf) VALUES
(?,?,?,?,?,?,?,?));
my ($cp,$cf,$cl) = caller();
$me->MyExecute(statement => $statement, vars => [$data->{genome_id}, $data->{species}, $data->{accession}, $data->{start}, $data->{plus_length}, $data->{plus_orf}, $data->{minus_length}, $data->{minus_orf}], caller =>"$cp,$cf,$cl",);
my $id = $data->{overlap_id};
return ($id);
}    ## End of Put_Overlap

sub Update_Nosy {
    my $me = shift;
    my $ip = shift;
    my $stmt = qq"REPLACE INTO nosy SET ip = '$ip'";
    my ($cp,$cf,$cl) = caller();
    $me->MyExecute(statement => $stmt, caller => "$cp,$cf,$cl",);
}

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
    my %args = @_;
    my $return = '';
    foreach my $k (keys %args) {
	if (!defined($args{$k})) {
	    $return .= "$k,";
	}
    }
    return ($return);
}

sub Tablep {
    my $me = shift;
    my $table = shift;
    if ($table =~ /virus/) {
	if ($table =~ /^boot_/) {
	    $table = 'boot_virus';
	} elsif ($table =~ /^landscape_/) {
	    $table = 'landscape_virus';
	}
    }
    my $statement = qq"SHOW TABLES LIKE '$table'";
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
average_mfe text,
snp_lastupdate TIMESTAMP DEFAULT '00:00:00',
lastupdate $config->{sql_timestamp},
INDEX(accession),
INDEX(genename),
PRIMARY KEY (id))/;
    my ($cp, $cf, $cl) = caller();
    $me->MyExecute(statement =>$statement, caller => "$cp, $cf, $cl",);
}

sub Create_Agree {
    my $me = shift;
    my $statement = qq"CREATE table agree (
id $config->{sql_id},
accession $config->{sql_accession},
start int,
length int,
all_agree int,
no_agree int,
n_alone int,
h_alone int,
p_alone int,
hplusn int,
nplusp int,
hplusp int,
hnp int,
PRIMARY KEY (id))";
    my ($cp, $cf, $cl) = caller();
    $me->MyExecute(statement =>$statement, caller => "$cp, $cf, $cl",);
}

sub Create_Index_Stats {
    my $me = shift;
    my $statement = qq/CREATE table index_stats (
id $config->{sql_id},
species $config->{sql_species},
num_genome int,
num_mfe_entries int,
num_mfe_knotted int,
PRIMARY KEY (id))/;
    my ($cp, $cf, $cl) = caller();
    $me->MyExecute(statement =>$statement, caller => "$cp, $cf, $cl",);
}

sub Create_NumSlipsite {
    my $me = shift;
    my $statement = qq/CREATE table numslipsite (
id $config->{sql_id},
accession $config->{sql_accession},
num_slipsite int,
lastupdate $config->{sql_timestamp},
PRIMARY KEY (id))/;
    my ($cp, $cf, $cl) = caller();
    $me->MyExecute(statement => $statement, caller => "$cp, $cf, $cl",);
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
    $me->MyExecute(statement => $statement, caller => "$cp, $cf, $cl",)
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
    $me->MyExecute(statement => $statement, caller => "$cp, $cf, $cl",);
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
    $me->MyExecute(statement => $statement, caller =>"$cp, $cf, $cl",);
}

sub Create_Import_Queue {
    my $me = shift;
    my $table = 'import_queue';
    my $stmt = qq"CREATE TABLE $table (
id $config->{sql_id},
accession $config->{sql_accession},
PRIMARY KEY (id))";
    my ($cp, $cf, $cl) = caller();
    $me->MyExecute(statement =>$stmt, caller => "$cp, $cf, $cl");
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
    $me->MyExecute(statement =>$statement,  caller =>"$cp, $cf, $cl",);
}

sub Create_MFE {
    my $me = shift;
    my $statement = qq\CREATE TABLE mfe (
id $config->{sql_id},
genome_id int,
species $config->{sql_species},
accession $config->{sql_accession},
algorithm char(20),
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
compare_mfes varchar(30),
has_snp bool DEFAULT FALSE,
bp_mstop int,
lastupdate $config->{sql_timestamp},
INDEX(genome_id),
INDEX(accession),
PRIMARY KEY(id))\;
    my ($cp, $cf, $cl) = caller();
    $me->MyExecute(statement => $statement,  caller =>"$cp, $cf, $cl",);
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
    $me->MyExecute(statement => $statement,  caller =>"$cp, $cf, $cl",);
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
    $me->MyExecute(statement => $statement,caller=>"$cp, $cf, $cl",);
}

sub Create_Nosy {
    my $me = shift;
    my $statement = qq\CREATE TABLE nosy (
ip char(15),
visited $config->{sql_timestamp},
PRIMARY KEY(ip))\;
    my ($cp, $cf, $cl) = caller();
    $me->MyExecute(statement =>$statement, caller => "$cp, $cf, $cl",);
    print "Created nosy\n" if (defined($config->{debug}));
}


sub Create_Landscape {
    my $me = shift;
    my $table = shift;
    $table = 'landscape_virus' if ($table =~ /virus/);
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
    $me->MyExecute(statement =>$statement, caller => "$cp, $cf, $cl",);
    print "Created $table\n" if (defined($config->{debug}));
}

sub Create_Boot {
    my $me = shift;
    my $table = shift;
    $table = 'boot_virus' if ($table =~ /virus/);
    my $statement = qq\CREATE TABLE $table (
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
zscore float,
lastupdate $config->{sql_timestamp},
INDEX(genome_id),
INDEX(mfe_id),
INDEX(accession),
PRIMARY KEY(id))\;
    my ($cp, $cf, $cl) = caller();
    $me->MyExecute(statement => $statement, caller =>"$cp, $cf, $cl",);
    print "Created $table\n" if (defined($config->{debug}));
}

sub Create_Wait {
    my $me = shift;
    my $stmt = qq"CREATE table wait (wait int, primary key(wait))";
    $me->MyExecute(statement => $stmt);
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
    $me->MyExecute(statement => $statement, caller => "$cp, $cf, $cl");
}


1;
