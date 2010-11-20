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
use PRFdb::Create;
use PRFdb::Get;
our @ISA = qw(Exporter);
# Symbols to be exported by default
our @EXPORT = qw"AddOpen RemoveFile Callstack Cleanup";
our $AUTOLOAD;
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
    my @handles = ();
    my $me = bless {
	user => $config->{database_user},
	num_retries => 60,
	retry_time => 15,
	handles => \@handles
    }, $class;
    if ($config->{checks}) {
	$me->Create_Genome() unless ($me->Tablep('genome'));
	$me->Create_Gene_Info() unless ($me->Tablep('gene_info'));
	$me->Create_Queue() unless ($me->Tablep($config->{queue_table}));
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
		my $mfe_table = "mfe_$s";
		unless ($me->Tablep($mfe_table)) {
		    $me->Create_MFE($mfe_table);
		}
	    }
	}
    }
    $me->{errors} = undef;
    return ($me);
}

sub Callstack {
    my %args = @_;
    $log->warn("$args{message}") if ($args{message});
    my ($path, $line, $subr);
    my $max_depth = 30;
    my $i = 1;
    if ($log->is_warn()) {
	$log->warn("--- Begin stack trace ---");
	while ((my @call_details = (caller($i++))) && ($i<$max_depth)) {
	    $log->warn("$call_details[1] line $call_details[2] in function $call_details[3]");
	}
	if (defined($!)) {
	    $log->warn("STDERR: $!");
	}
	$log->warn("--- End stack trace ---");
    }
    if ($args{die}) {
	my $die_message = qq"";
	$die_message .= "$args{message}" if (defined($args{message}));
	$die_message .= ": $!" if (defined($!));
	die($die_message);
    }
}

sub Disconnect {
    my $num_disconnected = 0;
    my $me = undef;
    my @handles = ();
    if (ref($_[0]) eq 'PRFdb') {
	$me = shift @_;
	@handles = @{$me->{handles}};
    }

    if (@_) {
	foreach my $num (@_) {
	    $num_disconnected++;
	    print "Disconnecting $num now\n";
	    my $handle = $PRFdb::handles->[$num];
	    my $rc = $handle->disconnect();
	    Callstack() unless ($rc);
	}
    } else {
	if (defined($PRFdb::handles)) {
	    my @handles = @{$PRFdb::handles};
	}
	foreach my $num (@handles) {
	    $num_disconnected++;
	    print "Disconnecting $num_disconnected now\n";
	    my $handle = $PRFdb::handles->[$num_disconnected];
	    my $rc = $handle->disconnect() if (defined($handle));
	}
    }
    return($num_disconnected);
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
	Callstack(die => 1, message => "No statement in MySelect");
    }

#    $me->dbh = $me->MyConnect($statement);
    my $dbh_num = $me->MyConnect($statement);
    my $dbh = $me->{handles}->[$dbh_num];
    my $selecttype;
    my $sth = $dbh->prepare($statement);
    my $rv;
    if (defined($vars)) {
	$rv = $sth->execute(@{$vars});
    } else {
	$rv = $sth->execute();
    }
    
    if (!defined($rv)) {
	my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
	Callstack(message => qq"$hour:$min:$sec $mon-$mday Execute failed for: $statement
with: error $DBI::errstr\n");
	$me->{errors}->{statement} = $statement;
	$me->{errors}->{errstr} = $DBI::errstr;
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
	Callstack(message => "$hour:$min:$sec $mon-$mday Execute failed for: $statement
with: error $DBI::errstr\n");
	$me->{errors}->{statement} = $statement;
	$me->{errors}->{errstr} = $DBI::errstr;
	Write_SQL($statement);
    }
    return ($return);
}

sub MyExecute {
    my $me = shift;
    my %args = ();
    my $input;
    my $input_type = ref($_[0]);
    my ($statement, $vars);
    if ($input_type eq 'HASH') {
        $input = $_[0];
	$vars = $input->{vars};
	$statement = $input->{statement};
    } elsif (!defined($_[1])) {
	$statement = $_[0];
    } else {
	%args = @_;
	$statement = $args{statement};
	$vars = $args{vars};
        $input = \%args;
    }

    my $dbh_num = $me->MyConnect($statement);
    my $dbh = $me->{handles}->[$dbh_num];
    my $sth = $dbh->prepare($statement);
    my $rv;
    my @vars;
    if (defined($input->{vars})) {
	@vars = @{$input->{vars}};
    }
    if (scalar(@vars) > 0) {
	$rv = $sth->execute(@{$input->{vars}}) or Callstack();
    } else {
	$rv = $sth->execute() or Callstack();
    }
    
    my $rows = 0;
    if (!defined($rv)) {
	my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
	Callstack(message => "$hour:$min:$sec $mon-$mday Execute failed for: $statement
with: error $DBI::errstr\n");
	print STDERR "Host: $config->{database_host} Db: $config->{database_name}\n" if (defined($config->{debug}) and $config->{debug} > 0);
	$me->{errors}->{statement} = $statement;
	$me->{errors}->{errstr} = $DBI::errstr;
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
    my $alt_dbd = shift;
    my $alt_user = shift;
    my $alt_pass = shift;
    my @hosts = @{$config->{database_host}};
    my $host = sub {
	my $value = shift;
	my $range = scalar(@hosts);
	$range = 1 if ($range == 0);
	my $index = $value % $range;
	return($hosts[$index]);
    };
    my $hostname = $host->($config->{database_retries});
    my $dbd;
    if (defined($alt_dbd)) {
	$dbd = $alt_dbd;
    } else {
	$dbd = qq"dbi:$config->{database_type}:database=$config->{database_name};host=$hostname";
    }
    my $dbh;
    use Sys::SigAction qw( set_sig_handler );
    eval {
	my $h = set_sig_handler('ALRM', sub {return("timeout");});
	#implement 2 second time out
	alarm($config->{database_timeout});  ## The timeout in seconds as defined by PRFConfig
	my ($user, $pass);
	if (defined($alt_user)) {
	    $user = $alt_user;
	    $pass = $alt_pass;
	} else {
	    $user = $config->{database_user};
	    $pass = $config->{database_pass};
	}
	$dbh = DBI->connect_cached($dbd, $user, $pass, $config->{database_args},) or Callstack();
	alarm(0);
    }; #original signal handler restored here when $h goes out of scope
    alarm(0);
    if (!defined($dbh) or
	(defined($DBI::errstr) and
	 $DBI::errstr =~ m/(?:lost connection|Server shutdown|Can\'t connect|Unknown MySQL server host|mysql server has gone away)/ix)) {  ##'
	my $success = 0;
	while ($config->{database_retries} < $me->{num_retries} and $success == 0) {
	    $config->{database_retries}++;
	    $hostname = $host->($config->{database_retries});
	    $dbd = qq"dbi:$config->{database_type}:database=$config->{database_name};host=$hostname";
	    print STDERR "Doing a retry, attempting to connect to $dbd\n";
	    eval {
		my $h = set_sig_handler( 'ALRM' ,sub { return("timeout") ; } );
		alarm($config->{database_timeout});  ## The timeout in seconds as defined by PRFConfig
		$dbh = DBI->connect_cached($dbd, $config->{database_user}, $config->{database_pass}, $config->{database_args},) or Callstack();
		alarm(0);
 	    }; #original signal handler restored here when $h goes out of scope
	    alarm(0);
	    if (defined($dbh) and
		(!defined($dbh->errstr) or $dbh->errstr eq '')) {
		$success++;
	    }
	} ## End of while
    }
    
    if (!defined($dbh)) {
	$me->{errors}->{statement} = $statement, Write_SQL($statement) if (defined($statement));
	$me->{errors}->{errstr} = $DBI::errstr;
	my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
	my $error = qq"$hour:$min:$sec $mon-$mday Could not open cached connection: dbi:$config->{database_type}:database=$config->{database_name};host=$config->{database_host}, $DBI::err. $DBI::errstr";
	Callstack(die => 1, message => $error);
    }
    $dbh->{mysql_auto_reconnect} = 1;
    $dbh->{InactiveDestroy} = 1;
    my $hands = $me->{handles};
    my $num_handles = $#$hands;
    my $new_handle = $num_handles + 1;
    $me->{handles}->[$new_handle] = $dbh;
    return($new_handle);
}

sub Reconnect {
    my $me = shift;
    my $prune = shift;
    my $species_list = $me->MySelect("select distinct(species) from gene_info");
    foreach my $species_es (@{$species_list}) {
	my $species = $species_es->[0];
	next if ($species =~ /virus/);
	my $mt = "mfe_$species";
	my $bt = "boot_$species";
	my $boots = $me->MySelect(statement => "SELECT * FROM $bt", type => 'list_of_hashes');
	foreach my $boot (@{$boots}) {
	    ## Find the correct mfe entry
	    my $stmt = qq"SELECT id, genome_id FROM $mt WHERE accession = ? AND start =  ? AND seqlength = ? AND algorithm = ?";
	    my $connector_id = $me->MySelect(statement => $stmt, vars => [$boot->{accession}, $boot->{start}, $boot->{seqlength}, $boot->{mfe_method}],);
	    my @connector = @{$connector_id};
	    if (scalar(@connector) > 1) {
		print "PROBLEM, more than 1 connector.\n";
		my $count = 0;
		foreach my $conn (@connector) {
		    if ($prune) {
			$me->MyExecute("DELETE FROM $mt WHERE id = '$connector[$count]->[0]'") unless($count == 0);
		    }
		    print "Tell me the mfe_id: $conn->[0] and genome_id: $conn->[1]\n";
		    $count++;
		}
	    } else {
		my ($id, $mgid) = ($connector[0]->[0], $connector[0]->[1]);
		if (!defined($mgid) or !defined($id)) {
		    print "There was an undefined element! $boot->{id} datum should be deleted.\n";
		    $me->MyExecute("DELETE FROM $bt WHERE id = '$boot->{id}'");
		} elsif ($id eq $boot->{mfe_id}) {
		    next;
		} else {
		    print "To Connect $species id:$boot->{id} bgid:$boot->{genome_id} mgid:$mgid, the mfe_id:$boot->{mfe_id}  must become:$id\n";
		    $me->MyExecute("UPDATE $bt set mfe_id = '$id' WHERE id = '$boot->{id}'");
		}
	    }
	}
    }
}

sub Keyword_Search {
    my $me = shift;
    my $species = shift;
    my $keyword = shift;
    my $statement = qq"SELECT accession, comment FROM gene_info WHERE comment like ? ORDER BY accession";
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
    my $species = shift;
    my $mfeid = shift;
    my $outputfile = shift;
    my $add_slipsite = shift;
    my ($fh, $filename);
    if (!defined($outputfile)) {
	$fh = PRFdb::MakeTempfile(SUFFIX => '.bpseq');
	$filename = $fh->filename;
    } elsif (ref($outputfile) eq 'GLOB') {
	$fh = $outputfile;
    } else {
	$fh = \*OUT;
	open($fh, ">$outputfile");
	$filename = $outputfile;
    }
    my $mfe_table = "mfe_$species";
    my $input_stmt = qq"SELECT sequence, output, slipsite FROM $mfe_table WHERE id = ?";
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
	} elsif ($in_array[$c] eq '.') {
	    my $position = $c + 1;
	    $output .= "$position $seq_array[$c] 0\n";
	} else {
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
    my $statement = qq"SELECT DISTINCT genome_id, accession, comment, FROM gene_info";
    my $info;
    system("mkdir $config->{base}/blast") if (!-r  "$config->{base}/blast");
    open(OUTPUT, " | gzip --stdout -f - >> $config->{base}/blast/$output") or Callstack(die => 1, message => "Could not open the fasta output file.");
    if (defined($species)) {
	$statement .= " WHERE species = \'$species\'";
    }
    $info = $me->MySelect($statement);
    my $count = 0;
    foreach my $datum (@{$info}) {
	$count++;
	if (!defined($datum)) {
	    print "Problem with $count element\n";
	    next;
	} else {
	    my $sequence = $me->MySelect(statement => "SELECT mrna_seq FROM genome WHERE id = ?", vars => [$datum->[0]], type => 'single');
	    my $id = $datum->[0];
	    my $accession = $datum->[1];
	    my $species = $datum->[2];
	    my $comment = $datum->[3];
	    my $string = qq(>gi|$id|gb|$accession $species $comment
$sequence
);
	    print OUTPUT $string;
	}
    }
    close(OUTPUT);
#    system("/usr/bin/gzip $config->{base}/blast/$output");
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
    my $species = $me->MySelect(statement => "SELECT species FROM gene_info WHERE accession = ?", vars => [$accession], type => 'single');
    my $mfe_table = "mfe_$species";
    my $info = $me->MySelect(qq"SELECT id,start,seqlength,algorithm FROM $mfe_table WHERE accession = '$accession'");
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
	    my $mfe_table = "mfe_$species";
	    foreach my $id (@nupack) {
		$me->MyExecute("DELETE FROM $mfe_table WHERE id = '$id'");
		$count++;
	    }
	    foreach my $id (@pknots) {
		$me->MyExecute("DELETE FROM $mfe_table WHERE id = '$id'");
		$count++;
	    }
	    foreach my $id (@hotknots) {
		$me->MyExecute("DELETE FROM $mfe_table WHERE id = '$id'");
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
		unlink("$f.err") if (-r "$f.err");
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

sub Id_to_AccessionSpecies {
    my $me = shift;
    my $id = shift;
    my $start = shift;
    Callstack(message => "Undefined value in Id_to_AccessionSpecies") unless (defined($id));
    my $statement = qq"SELECT accession, species from gene_info where id = ?";
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

sub Add_Webqueue {
    my $me = shift;
    my $id = shift;
    my $check = $me->MySelect(statement => qq"SELECT count(id) FROM webqueue WHERE genome_id = '$id'", type => 'single');
    return(undef) if ($check > 0);
    my $statement = qq"INSERT INTO webqueue VALUES('','$id','0','','0','')";
    my $rc = $me->MyExecute(statement => $statement,);
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
	my $rc = $me->MyExecute(statement => $statement,);
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
    $me->MyExecute(statement =>$statement,);
}

sub Drop_Table {
    my $me = shift;
    my $table = shift;
    my $statement = "DROP table $table";
    $me->MyExecute(statement => $statement,);
}

sub FillQueue {
    my $me = shift;
    my $table = 'queue';
    if (defined($config->{queue_table})) {
	$table = $config->{queue_table};
    }
    $me->Create_Queue() unless ($me->Tablep($table));
    my $best_statement = "INSERT into $table (genome_id, checked_out, done) SELECT id, 0, 0 from genome";
    $me->MyExecute(statement => $best_statement,);
}

sub Copy_Genome {
    my $me = shift;
    my $old_db = shift;
    my $new_db = $config->{db};
    my $statement = qq/INSERT INTO ${new_db}.genome
(accession,species,genename,locus,ontology_function,ontology_component,ontology_process,version,comment,mrna_seq,protein_seq,orf_start,orf_stop,direction,omim_id)
    SELECT accession,species,genename,locus,ontology_function,ontology_component,ontology_process,version,comment,mrna_seq,protein_seq,orf_start,orf_stop,direction,omim_id from ${old_db}.genome/;
$me->MyExecute(statement => $statement,);
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
    $me->MyExecute(statement => $statement,);
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

sub Copy_Queue {
    my $me = shift;
    my $old_table = shift;
    my $new_table = shift;
    my $statement = "INSERT INTO $new_table SELECT * FROM $old_table";
    $me->MyExecute(statement => $statement,);
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
    my $update = qq"UPDATE $table SET done='1', done_time=current_timestamp() WHERE genome_id=?";
    $me->MyExecute(statement => $update, vars => [$id],);
}

sub Import_Fasta {
    my $me = shift;
    my $file = shift;
    my $style = shift;
    my $startpos = shift;
    my @return_array;
    print "Starting Import_Fasta  with with style = $style\n";
    open(IN, "<$file") or Callstack(die => 1, message => "Could not open the input file.");
    my %datum = (accession => undef, genename => undef, version => undef, comment => undef, mrna_seq => undef);
    my $linenum = 0;
    if (defined($config->{species})) {
	print "Species is defined as $config->{species}\n";
    } else {
	Callstack(die => 1, message => "Species must be defined.");
    }
    while (my $line = <IN>) {
	$linenum++;
	chomp $line;
	if ($line =~ /^\>/) {
            ## Do the actual insertion here, regardless of style
            if ($linenum > 1) {
                if (defined($config->{startpos})) {
                    $datum{orf_start} = $config->{startpos};
                } else {
                    $datum{orf_start} = 1;
                }
                if (defined($config->{endpos})) {
                    if ($config->{endpos} > 0) {
                        $datum{orf_stop} = $config->{end_pos};
                    } else {  ## A negative offset
                        $datum{orf_stop} = length($datum{mrna_seq}) - $config->{endpos};
                    }
                } else {
                    $datum{orf_stop} = length($datum{mrna_seq});
                }
		## Insert the entry here and add the queue entry

		if (!defined($datum{protein_seq}) or $datum{protein_seq} eq '') {
		    my $seq = new SeqMisc(sequence => $datum{mrna_seq});
		    my $aa_seq = $seq->{aaseq};
		    my $aa = '';
		    foreach my $c (@{$aa_seq}) { $aa .= $c; }
		    $datum{protein_seq} = $aa;
		}
                my $genome_id = $me->Insert_Genome_Entry(\%datum);
#  This is repeated at the end of this function, I need to make sure that is kosher
		if (defined($genome_id)) {
		    print "1: Added $genome_id\n";
		    push(@return_array, $genome_id);
		}
            }  ## End if linenum == 1

	    if (defined($style)) {
		if ($style eq 'sgd') {
		    %datum = (accession => undef,
			      genename => undef,
			      version => undef,
			      comment => undef,
			      mrna_seq => undef,);
		    my ($fake_accession, $comment) = split(/\,/, $line);
		    my ($accession, $genename) = split(/ /,  $fake_accession);
		    $accession =~ s/^\>//g;
		    $datum{accession} = $accession;
		    $datum{genename} = $genename;
		    $datum{comment} = $comment;
		    $datum{genename} = $genename;
		    $datum{protein_seq} = '';
		    $datum{direction} = 'forward';
		    $datum{defline} = $line;
		    $datum{species} = $config->{species};
		    if (!defined($datum{genename})) {
			$datum{genename} = $datum{accession};
		    }
		    if (!defined($datum{version})) {
			$datum{version} = 1;
		    }
		    ## End if the style is sgd
		} elsif ($style eq 'celegans') {
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
		    ## End if the style is of C. elegans
		} elsif ($style eq 'mgc') {
		    %datum = (accession => undef,
			      genename => undef,
			      version => undef,
			      comment => undef,
			      mrna_seq => undef,);
		    my ($gi_trash, $gi_id, $gb_trash, $accession_version, $comment) = split(/\|/, $line);
		    my ($accession, $version);
		    if ($accession_version =~ m/\./) {
			($accession, $version) = split(/\./, $accession_version);
		    } else {
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
		    ## End if the style is from the mammalian gene collection
		} elsif ($style eq 'misc') {
		    %datum = (accession => undef,
			      genename => undef,
			      version => undef,
			      comment => undef,
			      mrna_seq => undef,);
		    my @tmp_split = split(/ /, $line);
		    my $accession = $tmp_split[0];
		    $accession =~ s/\>//g;
		    my $comment = $line;
		    my $genename = $accession;
		    $accession =~ s/^\>//g;
		    $accession =~ s/ORFN//g;
		    $comment =~ s/^\>//g;
		    $datum{accession} = $accession;
		    $datum{genename} = $genename;
		    $datum{comment} = $comment;
		    $datum{genename} = $genename;
		    $datum{protein_seq} = '';
		    $datum{direction} = 'forward';
		    $datum{defline} = $line;
		    $datum{species} = $config->{species};
		    ## End if the style is misc
		}
	    } else {
		print "Style is not defined.\n";
	    }
	    ## End if you are on a > line
	} else {
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
    push(@return_array, $genome_id);
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
	    Callstack(message => "WTF: Direction is not forward or reverse");
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
	    my $gid = $me->MySelect(statement => "SELECT id FROM genome WHERE accession = '$datum{accession}'", type => 'single');
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

sub Insert_Genome_Entry {
    my $me = shift;
    my $datum = shift;
    ## Check to see if the accession is already there
    my $check = qq"SELECT id FROM genome where accession = ?";
    my $already_id = $me->MySelect(statement => $check, vars => [$datum->{accession}], type => 'single');
    ## A check to make sure that the orf_start is not 0.  If it is, set it to 1 so it is consistent with the
    ## crap from the SGD
    $datum->{orf_start} = 1 if (!defined($datum->{orf_start}) or $datum->{orf_start} == 0);
    if (defined($already_id)) {
	print "The accession $datum->{accession} is already in the database with id: $already_id\n";
	return (undef);
    }
    $datum->{version} = 0 if (!defined($datum->{version}));
    $datum->{comment} = "" if (!defined($datum->{comment}));
#    my $statement = qq(INSERT INTO genome
#(accession,species,genename,version,comment,mrna_seq,protein_seq,orf_start,orf_stop,direction)
#    VALUES('$datum->{accession}', '$datum->{species}', '$datum->{genename}', '$datum->{version}', '$datum->{comment}', '$datum->{mrna_seq}', '$datum->{protein_seq}', '$datum->{orf_start}', '$datum->{orf_stop}', '$datum->{direction}'));
    my $statement = qq"INSERT INTO genome
(accession, genename, version, comment, mrna_seq, orf_start, orf_stop, direction)
VALUES(?,?,?,?,?,?,?,?)";
    $me->MyExecute(statement => $statement,
               vars => [$datum->{accession}, $datum->{species}, $datum->{genename}, $datum->{version}, $datum->{comment}, $datum->{mrna_seq}, $datum->{orf_start}, $datum->{orf_stop}, $datum->{direction}],);
    my $last_id = $me->MySelect(statement => 'SELECT LAST_INSERT_ID()', type => 'single');
    my $queue_id = $me->Set_Queue(id => $last_id,);
    my $gene_info_stmt = qq"INSERT INTO gene_info
(genome_id, accession, species, genename, comment)
VALUES(?,?,?,?,?)";
    my $gene_info = $me->MyExecute(statement => $gene_info_stmt,
                                   vars => [$last_id,$datum->{accession},$datum->{species},$datum->{genename},$datum->{comment}]);

## The following line is very important to ensure that multiple
## calls to this don't end up with
## Increasingly long sequences
    foreach my $k (keys %{$datum}) {$datum->{$k} = undef;}
    return ($last_id);
}

sub Insert_Numslipsite {
    my $me = shift;
    my $accession = shift;
    my $num_slipsite = shift;
    my $statement = qq/INSERT IGNORE INTO numslipsite
(accession, num_slipsite)
VALUES('$accession', '$num_slipsite')/;
    $me->MyExecute(statement =>$statement,);
    my $last_id = $me->MySelect(statement => 'SELECT LAST_INSERT_ID()', type => 'single');
    return ($last_id);
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
    ## What fields do we want to fill in this MFE table?
    my @pknots = ('genome_id', 'accession', 'start', 'slipsite', 'seqlength', 'sequence', 'output', 'parsed', 'parens', 'mfe', 'pairs', 'knotp', 'barcode');
    my $errorstring = Check_Insertion(\@pknots, $data);
    if (defined($errorstring)) {
	$errorstring = "Undefined value(s) in Put_MFE: $errorstring";
	Callstack(message => $errorstring);
    }
    my $species = $data->{species};
    my $table = qq"mfe_$species";
    $data->{sequence} =~ tr/actgun/ACTGUN/;
    my $statement = qq(INSERT INTO $table (genome_id, algorithm, accession, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?));
    
    $me->MyExecute(statement => $statement, vars => [$data->{genome_id}, $data->{species}, $algo, $data->{accession}, $data->{start}, $data->{slipsite}, $data->{seqlength}, $data->{sequence}, $data->{output}, $data->{parsed}, $data->{parens}, $data->{mfe}, $data->{pairs}, $data->{knotp}, $data->{barcode}],);
    
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
    } else {
	@filled = ('genome_id', 'species', 'accession', 'start', 'seqlength', 'sequence', 'output', 'parsed', 'parens', 'mfe', 'pairs', 'knotp', 'barcode');
    }
    my $errorstring = Check_Insertion(\@filled, $data);
    if (defined($errorstring)) {
	$errorstring = "Undefined value(s) in Put_MFE_Landscape: $errorstring";
	Callstack(message => $errorstring);
    }
    if (defined($data->{sequence})) {
	$data->{sequence} =~ tr/actgu/ACTGU/;
    } else {
	Callstack(message => qq"Sequence is not defined for Species:$data->{species}, Accession:$data->{accession}, Start:$data->{start}, Seqlength:$data->{seqlength}");
	return(undef);
    }
    my $statement = qq"INSERT DELAYED INTO $table (genome_id, species, algorithm, accession, start, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
    my $rows = $me->MyExecute(statement => $statement, vars => [$data->{genome_id}, $data->{species}, $algo, $data->{accession}, $data->{start}, $data->{seqlength}, $data->{sequence}, $data->{output}, $data->{parsed}, $data->{parens}, $data->{mfe}, $data->{pairs}, $data->{knotp}, $data->{barcode}],);
    return ($rows);
}    ## End put_mfe_landscape

sub Put_Agree {
    my $me = shift;
    my %args = @_;
    my $agree = $args{agree};
    my $check = $me->MySelect(statement => "SELECT count(id) FROM agree WHERE accession = ? AND start = ? AND length = ?", vars => [$args{accession}, $args{start}, $args{length}], type => 'single');
    return(undef) if ($check >= 1);
    my $stmt = qq"INSERT DELAYED INTO agree (accession, start, length, all_agree, no_agree, n_alone, h_alone, p_alone, hplusn, nplusp, hplusp, hnp) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)";
    my $rows = $me->MyExecute(statement => $stmt,
			      vars => [$args{accession}, $args{start}, $args{length}, $agree->{all}, $agree->{none}, $agree->{n}, $agree->{h}, $agree->{p}, $agree->{hn}, $agree->{np}, $agree->{hp}, $agree->{hnp}],);
    return($rows);
}

sub Put_Stats {
    my $me = shift;
    my $data = shift;
    my $finished = shift;
    my $inserted_rows = 0;
    $finished = [] if (!defined($finished));
    my $st_count = 0;
    my $st_total = scalar(@{$data->{species}});
    OUT: foreach my $species (@{$data->{species}}) {
	$st_count++;
	foreach my $sp (@{$finished}) {
	    next OUT if ($sp eq $species);
	}
	print "Starting Put_Stats for $species.  Number $st_count of $st_total.\n";
	my $table = ($species =~ /virus/ ? "boot_virus" : "boot_$species");
	$me->MyExecute(statement => qq"DELETE FROM stats WHERE species = '$species'");
	foreach my $seqlength (@{$data->{seqlength}}) {
	    foreach my $max_mfe (@{$data->{max_mfe}}) {
		foreach my $algorithm (@{$data->{algorithm}}) {
		    my $mfe_table = ($species =~ /virus/ ? "mfe_virus" : "mfe_$species");
		    #  0    1    2     3     4    5     6     7     8
		    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		    my $timestring = "$mon/$mday $hour:$min.$sec";
#		    print "$timestring  Now doing $species $seqlength $max_mfe $algorithm\n";
		    my $weedout_string = qq"WHERE species = '$species' AND algorithm = '$algorithm' AND seqlength = '$seqlength'";
 		    my $max_mfe = $me->MySelect(type => 'single', statement => "/* 1 of 19 */ SELECT max(mfe) FROM $mfe_table $weedout_string");
		    my $min_mfe = $me->MySelect(type => 'single', statement => "/* 2 of 19 */ SELECT min(mfe) FROM $mfe_table $weedout_string");
		    my $num_sequences = $me->MySelect(type => 'single', statement => "/* 3 of 19 */ SELECT count(id) FROM $mfe_table $weedout_string AND mfe <= '$max_mfe'");
		    my $avg_mfe = $me->MySelect(type => 'single', statement => "/* 4 of 19 */ SELECT avg(mfe) FROM $mfe_table $weedout_string AND mfe <= '$max_mfe'");
		    my $stdev_mfe = $me->MySelect(type => 'single', statement => "/* 5 of 19 */ SELECT stddev(mfe) FROM $mfe_table $weedout_string AND mfe <= '$max_mfe'");
		    my $avg_pairs = $me->MySelect(type => 'single', statement => "/* 6 of 19 */ SELECT avg(pairs) FROM $mfe_table $weedout_string AND mfe <= '$max_mfe'");
		    my $stdev_pairs = $me->MySelect(type => 'single', statement => "/* 7 of 19 */ SELECT stddev(pairs) FROM $mfe_table $weedout_string AND mfe <= '$max_mfe'");
		    my $num_sequences_noknot = $me->MySelect(type => 'single', statement => "/* 8 of 19 */ SELECT count(id) FROM $mfe_table $weedout_string AND knotp = '0' AND mfe <= '$max_mfe'");
		    my $avg_mfe_noknot = $me->MySelect(type => 'single', statement => "/* 9 of 19 */ SELECT avg(mfe) FROM $mfe_table $weedout_string AND knotp = '0' AND mfe <= '$max_mfe'");
		    my $stdev_mfe_noknot = $me->MySelect(type => 'single', statement => "/* 10 of 19 */ SELECT stddev(mfe) FROM $mfe_table $weedout_string AND knotp = '0' AND mfe <= '$max_mfe'");
		    my $avg_pairs_noknot = $me->MySelect(type => 'single', statement => "/* 11 of 19 */ SELECT avg(pairs) FROM $mfe_table $weedout_string AND knotp = '0' AND mfe <= '$max_mfe'");
		    my $stdev_pairs_noknot = $me->MySelect(type => 'single', statement => "/* 12 of 19 */ SELECT stddev(pairs) FROM $mfe_table $weedout_string AND knotp = '0' AND mfe <= '$max_mfe'");
		    my $num_sequences_knotted = $me->MySelect(type => 'single', statement => "/* 13 of 19 */ SELECT count(id) FROM $mfe_table $weedout_string AND knotp = '1' AND mfe <= '$max_mfe'");
		    my $avg_mfe_knotted = $me->MySelect(type => 'single', statement => "/* 14 of 19 */ SELECT avg(mfe) FROM $mfe_table $weedout_string AND knotp = '1' AND mfe <= '$max_mfe'");
		    my $stdev_mfe_knotted = $me->MySelect(type => 'single', statement => "/* 15 of 19 */ SELECT stddev(mfe) FROM $mfe_table $weedout_string AND knotp = '1' AND mfe <= '$max_mfe'");
		    my $avg_pairs_knotted = $me->MySelect(type => 'single', statement => "/* 16 of 19 */ SELECT avg(pairs) FROM $mfe_table $weedout_string AND knotp = '1' AND mfe <= '$max_mfe'");
		    my $stdev_pairs_knotted = $me->MySelect(type => 'single', statement => "/* 17 of 19 */ SELECT stddev(pairs) FROM $mfe_table $weedout_string AND knotp = '1' AND mfe <= '$max_mfe'");
		    my $avg_zscore = $me->MySelect(type => 'single', statement => "/* 18 of 19 */ SELECT avg(zscore) FROM $table WHERE mfe_method = '$algorithm' AND species = '$species' AND seqlength = '$seqlength'");
		    my $stdev_zscore = $me->MySelect(type => 'single', statement => "/* 19 of 19 */SELECT stddev(zscore) FROM $table WHERE mfe_method = '$algorithm' AND species = '$species' AND seqlength = '$seqlength'");
#		    print "species:$species  seqlength:$seqlength  max_mfe:$max_mfe  min_mfe:$min_mfe  algorithm:$algorithm  num_seq:$num_sequences  avg_mfe:$avg_mfe  stdev_mfe:$stdev_mfe  avg_pairs:$avg_pairs  stdev_pairs:$stdev_pairs  num_nokn:$num_sequences_noknot  avg_mfe_no:$avg_mfe_noknot  stdev_mfe_no:$stdev_mfe_noknot  avg_pairs_no:$avg_pairs_noknot  stdev_pairs_no:$stdev_pairs_noknot  num_knot:$num_sequences_knotted  avg_mfe_knot:$avg_mfe_knotted  stdev_mfe_knotted:$stdev_mfe_knotted  avg_pairs_knot:$avg_pairs_knotted  stdev_pairs:kno:$stdev_pairs_knotted  avg_z:$avg_zscore  stdev_zscore:$stdev_zscore\n";
		    my $statement = qq"INSERT DELAYED INTO stats
(species, seqlength, max_mfe, min_mfe, algorithm, num_sequences, avg_mfe, stddev_mfe, avg_pairs, stddev_pairs, num_sequences_noknot, avg_mfe_noknot, stddev_mfe_noknot, avg_pairs_noknot, stddev_pairs_noknot, num_sequences_knotted, avg_mfe_knotted, stddev_mfe_knotted, avg_pairs_knotted, stddev_pairs_knotted, avg_zscore, stddev_zscore)
    VALUES
('$species', '$seqlength', '$max_mfe', '$min_mfe', '$algorithm', '$num_sequences', '$avg_mfe', '$stdev_mfe', '$avg_pairs', '$stdev_pairs', '$num_sequences_noknot', '$avg_mfe_noknot', '$stdev_mfe_noknot', '$avg_pairs_noknot', '$stdev_pairs_noknot', '$num_sequences_knotted', '$avg_mfe_knotted', '$stdev_mfe_knotted', '$avg_pairs_knotted', '$stdev_pairs_knotted', '$avg_zscore', '$stdev_zscore')";
#                  print "STATEMENT: $statement\n";
                  my $rows = $me->MyExecute(statement => $statement,);
                  if (defined($me->{errors}->{errstr})) {
                    print "The statement: $me->{errors}->{statement} had an error:
$me->{errors}->{errstr}\n";
                  }
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
		Callstack(message => $errorstring);
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
              Callstack(message => $errorstring);
            }
            my $inserted_rows = $me->MyExecute(statement => $statement, vars => [ $data->{genome_id}, $mfe_id, $species, $accession, $start, $seqlength, $iterations, $rand_method, $mfe_method, $mfe_mean, $mfe_sd, $mfe_se, $pairs_mean, $pairs_sd, $pairs_se, $mfe_values ],);
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
	Callstack(message => $errorstring);
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
        Callstack(message => $errorstring);
    }
    my $rows = $me->MyExecute(statement => $statement,);

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
$me->MyExecute(statement => $statement, vars => [$data->{genome_id}, $data->{species}, $data->{accession}, $data->{start}, $data->{plus_length}, $data->{plus_orf}, $data->{minus_length}, $data->{minus_orf}],);
my $id = $data->{overlap_id};
return ($id);
}    ## End of Put_Overlap

sub Update_Nosy {
    my $me = shift;
    my $ip = shift;
    my $stmt = qq"REPLACE INTO nosy SET ip = '$ip'";
    $me->MyExecute(statement => $stmt,);
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

sub ReSync {
    my $me = shift;
    my $other_dbd = qq"dbi:$config->{database_type}:database=mysql;host=$config->{database_otherhost}";
    my $local_dbd = qq"dbi:$config->{database_type}:database=mysql;host=localhost";
    print "TESTME: $other_dbd\n";
    my $statement = "SHOW MASTER STATUS";
    my $other_dbh_num = $me->MyConnect($statement, $other_dbd, 'root', 'rsoqolt');
    my $local_dbh_num = $me->MyConnect($statement, $local_dbd, 'root', 'rsoqolt');
    my $other_dbh = $me->{handles}->[$other_dbh_num];
    my $local_dbh = $me->{handles}->[$local_dbh_num];
    my $o_sth = $other_dbh->prepare($statement);
    my $l_sth = $local_dbh->prepare($statement);
    my $o_rv = $o_sth->execute();
    my $l_rv = $l_sth->execute();
    my $o_return = $o_sth->fetchrow_arrayref();
    my $l_return = $l_sth->fetchrow_arrayref();
    my $o_file = $o_return->[0];
    my $l_file = $l_return->[0];
    my $o_pos = $o_return->[1];
    my $l_pos = $l_return->[1];
    my $l_reset = qq"CHANGE MASTER TO MASTER_LOG_FILE='$o_file', MASTER_LOG_POS=$o_pos";
    my $o_reset = qq"CHANGE MASTER TO MASTER_LOG_FILE='$l_file', MASTER_LOG_POS=$l_pos";
    print "Local log file and position is: $l_file $l_pos\n";
    print "Changing remote master with: $o_reset\n";
    print "Remote log file and position is: $o_file $o_pos\n";
    print "Changing local master with: $l_reset\n";
    $o_sth = $other_dbh->prepare($o_reset);
    $l_sth = $local_dbh->prepare($l_reset);
    $o_rv = $o_sth->execute();
    $l_rv = $l_sth->execute();
    $l_reset = "START SLAVE";
    $o_reset = "START SLAVE";
    $o_sth = $other_dbh->prepare($o_reset);
    $l_sth = $local_dbh->prepare($l_reset);
    $o_rv = $o_sth->execute();
    $l_rv = $l_sth->execute();
}

sub Cleanup {
    print "\n\nCaught Fatal signal. @_\n\n";    
    PRFdb::Disconnect();
    PRFdb::RemoveFile('all') if (defined($config->{remove_end}));
    exit(0);
}

sub AUTOLOAD {
    my $me = shift;
    my $type = ref($me) or Callstack(), warn("$me is not an object");
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    if ($name =~ /^Create_/) {
	my $newname = $name;
	$newname =~ s/Create_//g;
	$newname = "PRFdb::Create::$newname";
	{
	    no strict 'refs';
	    &$newname($me, @_);
	}
    } elsif ($name =~ /^Get_/) {
	my $newname = $name;
	$newname =~ s/Get_//g;
	$newname = "PRFdb::Get::$newname";
	{
	    no strict 'refs';
	    &$newname($me, @_);
	}
    }
#    if (@_) {
#	return $me->{$name} = shift;
#    } else {
#	return $me->{$name};
#    }
}

1;
