package PRFdb;
## Time-stamp: <Wed May 23 09:55:46 2012 Ashton Trey Belew (abelew@wesleyan.edu)>
use strict;
use DBI;
use PRFConfig;
use SeqMisc;
use File::Temp qw / tmpnam /;
use Fcntl ':flock';    # import LOCK_* constants
use Bio::Root::RootI;
use base qw(Bio::Root::RootI);
use Bio::DB::Universal;
use Log::Log4perl;
use Log::Log4perl::Level;
use Bio::Root::Exception;
use Error qw(:try);
use vars qw($VERSION);
use PRFdb::Create;
use PRFdb::Get;
use PRFdb::Put;
our @ISA = qw(Exporter);
# Symbols to be exported by default
our @EXPORT = qw"AddOpen RemoveFile Callstack Cleanup";
our $AUTOLOAD;
$VERSION = '20111119';
Log::Log4perl->easy_init($WARN);
our $log = Log::Log4perl->get_logger('stack'),
### Holy crap global variables!
our $config;
our $dbh;
###

# $Id $
#
# BioPerl module for PRFdb
#
# Cared for by Ashton Trey Belew <abelew@gmail.com>
#
# Copyright Ashton Trey Belew
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

PRFdb - The database routines of the Programmed Ribosomal Frameshift Database

=head1 SYNOPSIS

  use PRFdb qw" Callstack AddOpen RemoveFile Cleanup ";
  my $db = new PRFdb(config => $config);
  my $lots_of_information = $db->MySelect("SELECT * FROM gene_info");

=head1 DESCRIPTION

The B<PRFdb> module pretty much requires a functional B<PRFConfig>
object in order to find its myriad of configurable variables.
It attempts to create an easy and fast environment for performing
SQL queries/inserts/updates across the PRFdb, including automatic
failover between database nodes, the ability to request specific
datatypes from select statements without having to remember the
various function names from DBI, and pretty reasonable error
reporting functionality.
All tables which are used in the PRFdb may be found in PRFdb::Create,
Functions which perform common selects from the database are in
PRFdb::Get and those which perform common inserts are in
PRFdb::Put; these are most commonly accessed via AUTOLOAD.
Describe the interface here

=head1 AUTHOR - Ashton Trey Belew

Email abelew@gmail.com

=cut

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
        handles => \@handles,
        config => $config,
        rpw => $config->{database_root_password},
    }, $class;
    if ($config->{checks}) {
        $me->Create_Genome() unless ($me->Tablep('genome'));
        $me->Create_Gene_Info() unless ($me->Tablep('gene_info'));
        $me->Create_Queue() unless ($me->Tablep($config->{queue_table}));
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
    return($me);
}

=head2 Callstack
    
 Title   : Callstack
 Usage   : Callstack(message => 'Some message.', die => 1)
 Function: A super simple way to throw debugging messages and give a
 stacktrace.  This should be replaced with Bio::Root::Exception, but
 that is for another day.

=cut
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

=head2 Disconnect

 Title   : Disconnect
 Usage   : $db->Disconnect()
 Function: Handles disconnecting from an arbitrary number of existing database
 handles.
 Returns : The number of handles which were closed.

=cut
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
#	    print "Disconnecting $num now\n";
            my $handle = $PRFdb::handles->[$num];
            my $rc = $handle->disconnect();
            Callstack() unless ($rc);
        }
    }
    else {
        if (defined($PRFdb::handles)) {
            my @handles = @{$PRFdb::handles};
        }
        foreach my $num (@handles) {
            $num_disconnected++;
#	    print "Disconnecting $num_disconnected now\n";
            my $handle = $PRFdb::handles->[$num_disconnected];
            my $rc = $handle->disconnect() if (defined($handle));
        }
    }
    return($num_disconnected);
}

=head2 MySelect

 Title   : MySelect
 Usage   : my $result = $db->MySelect("SELECT * FROM sometable");

MySelect attempts to make SQL select statements via DBI quick and flexible
in an environment where at any time one or more database nodes might not be
responding.
MySelect can take either a raw select statement or a raw hash which looks
like "statement => 'some select statement', type => 'single'"
If it receives a string, it will return an array reference with one element
per row of the database returned.  Otherwise it will return the following:

type => 'hash', descriptor => ['id','accession']  : returns a hash reference
with the names of each key as defined by the descriptor.

type => 'row' : returns a single row as an array reference.

type => 'single' : returns a scalar with a single value.

type => 'flat'  : flattens an array reference returned by fetchall_arrayref

type => 'list_of_hashes' : a list of hashes with the names of the columns in the table

type => undef : a list of array references

=cut
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
    }
    elsif (!defined($_[1])) {
        $statement = $_[0];
    }
    else {
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
    print STDERR "$statement\n" if ($config->{debug});
    my $dbh_num = $me->MyConnect($statement);
    my $dbh = $me->{handles}->[$dbh_num];
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
    }
    elsif (defined($type) and $type eq 'row') {
        ## If $type is defined, AND if you ask for a row, do a selectrow_arrayref
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
        ## Endif flat
    } 
    elsif (defined($type) and $type eq 'list_of_hashes') { 
        $return = $sth->fetchall_arrayref({});
        $selecttype = 'selectall_arrayref({})';     
    }
    elsif (defined($type)) {    ## Usually defined as 'hash'
        ## If only $type is defined, do a selectrow_hashref
        $return = $sth->fetchrow_hashref();
        $selecttype = 'selectrow_hashref';
    }
    else {
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
    }
    return ($return);
}

=head2 MyExecute

 Title   : MyExecute
 Usage   : my $modified_entries = $db->MyExecute("UPDATE table SET something");
 Returns : The number of modified columns
 Args    : An optional pair of statement => "SOME SQL STATEMENT ?" and vars => ['variable1','variable2'...]

  MyExecute handles performing non-select statements, unlike MySelect which goes
to some effort to provide various returns, Execute takes effort to make sure
insert/update/etc statements are properly setup and completed and only returns
the number of modified rows in the table.

=cut
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
    }
    elsif (!defined($_[1])) {
        $statement = $_[0];
    }
    else {
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
    }
    else {
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
    }
    else {
        $rows = $dbh->rows();
    }
    return($rows);
}

=head2 MyGet

Little used because it is too clever.  Takes args in the following format:
table => 'mfe_saccharomyces_cerevisiae', order => 'column_to_sort_by',
criterion => [column1, =, column2, = ],
Thus one could use it to quickly generate SELECT statements by just
feeding a hash of the things you actually want.

=cut
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

=head2 MyConnect

MyConnect is called early by prf_daemon as well as the apache handler.
It in turn makes use of DBI::connect_cached and Sys::SigAction in order
to skip between multiple database nodes in the event one is not
responding.  Every time it makes a successful connection, it appends a
new handle onto the PRFdb->{handles} list.
Finally, it returns the cached DBI database handle.

=cut
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
    }
    else {
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
        }
        else {
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
        $me->{errors}->{statement} = $statement if (defined($statement));
        $me->{errors}->{errstr} = $DBI::errstr;
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime time;
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

=head2 Bootlace_Check

 Title   : Bootlace_Check
 Usage   : my $modified = $db->Bootlace_Check(1);
 Function: Checks over the MFE and Bootlace tables and looks for mistakes.
 Returns : The number of modified (and optionally) deleted rows.

=cut
sub Bootlace_Check {
    my $me = shift;
    my $prune = shift;
    my $species_list = $me->MySelect("select distinct(species) from gene_info");
    my $count_modified = 0;
    foreach my $species_es (@{$species_list}) {
        my $species = $species_es->[0];
        next if ($species =~ /virus/);
        my $mt = "mfe_$species";
        $mt = 'mfe_virus' if ($mt =~ /virus/);
        my $bt = "boot_$species";
        $bt = 'boot_virus' if ($bt =~ /virus/);
        my $boots = $me->MySelect(statement => "SELECT * FROM $bt", type => 'list_of_hashes');
        foreach my $boot (@{$boots}) {
            ## Find the correct mfe entry
            my $stmt = qq"SELECT id, genome_id FROM $mt WHERE accession = ? AND start =  ? AND seqlength = ? AND mfe_method = ?";
            my $connector_id = $me->MySelect(statement => $stmt, vars => [$boot->{accession}, $boot->{start}, $boot->{seqlength}, $boot->{mfe_method}],);
            my @connector = @{$connector_id};
            if (scalar(@connector) > 1) {
                print "PROBLEM, more than 1 connector.\n";
                my $count = 0;
                foreach my $conn (@connector) {
                    if ($prune) {
                        $count_modified++;
                        $me->MyExecute("DELETE FROM $mt WHERE id = '$connector[$count]->[0]'") unless($count == 0);
                    }
                    print "Tell me the mfe_id: $conn->[0] and genome_id: $conn->[1]\n";
                    $count++;
                }
            } 
            else {
                my ($id, $mgid) = ($connector[0]->[0], $connector[0]->[1]);
                if (!defined($mgid) or !defined($id)) {
                    print "There was an undefined element! $boot->{id} datum should be deleted.\n";
                    $count_modified++;
                    $me->MyExecute("DELETE FROM $bt WHERE id = '$boot->{id}'");
                }
                elsif ($id eq $boot->{mfe_id}) {
                    next;
                }
                else {
                    print "To Connect $species id:$boot->{id} bgid:$boot->{genome_id} mgid:$mgid, the mfe_id:$boot->{mfe_id}  must become:$id\n";
                    $count_modified++;
                    $me->MyExecute("UPDATE $bt set mfe_id = '$id' WHERE id = '$boot->{id}'");
                }
            }
        }
    }
    return($count_modified);
}

=head2 Mfeid_to_Bpseq

 Title   : Mfeid_to_Bpseq
 Usage   : my $output_file = $db->Mfeid_to_Bpseq(species => 'homo_sapiens', mfeid => '10', output => 'some_file.bpseq');
 Returns : Generates a .bpseq file for a given ID in the MFE database.

=cut
sub Mfeid_to_Bpseq {
    my ($me, %args) = @_;
    my $species = $args{species};
    my $mfeid = $args{mfeid};
    my $outputfile = $args{output};
    my $add_slipsite = $args{add_slip};
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
    my $final_filename = $me->Make_Bpseq(output => \@in_array, sequence => \@seq_array, output_file => $outputfile);
    
    return($final_filename);
}

=head2 Mfeid_to_Seq

 Title   : Mfeid_to_Seq
 Usage   : my $seq_filename = $db->Mfeid_to_Seq(species => 'saccharomyces_cerevisiae', mfeid => '12');
 Function: Creates a seq file from an ID number in the mfe table, primarily used for hotknots.

=cut
sub Mfeid_to_Seq {
    my ($me, %args) = @_;
    my $species = $args{species};
    my $mfeid = $args{mfeid};
    my $outputfile = $args{output};
    my $type = $args{type};
    my $add_slipsite = $args{add_slip};
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
    
    my $final_filename;
    if ($type eq 'bpseq') {
        $final_filename = $me->Make_Bpseq(output => \@in_array, sequence => \@seq_array, output_file => $outputfile);
    }
    elsif ($type eq 'ct') {
        $final_filename = $me->Make_CT(output => \@in_array, sequence => \@seq_array, output_file => $outputfile);
    }
    else {
        return;
    }
    
    return($final_filename);
}

=head2 Make_CT

 Title   : Make_CT
 Usage   : my $filename = $db->Make_CT(output => ['.'...], sequence => ['A','U'...], output_file => 'some_file.ct');
 Function: Create a Context Table file from the output of pknots etc.
 Returns : The filename of the created file.

=cut
sub Make_CT {
    my ($me, %args) = @_;
    my @in_array = @{$args{output}};
    my @seq_array = @{$args{sequence}};
    my $output_file = $args{output_file};
    my ($fh, $filename);
    if (!defined($output_file)) {
        $fh = PRFdb::MakeTempfile(SUFFIX => '.ct');
        $output_file = $fh->filename;
    }
    elsif (ref($output_file) eq 'GLOB') {
        $fh = $output_file;
    }
    else {
        $fh = \*OUT;
        open($fh, ">$output_file");
    }

    my $bases = scalar(@seq_array);
    print STDERR "HERE WITH CT $output_file\n";
    my $output_string = "$bases  $output_file\n";
    foreach my $c (0 .. $#seq_array) {
        my $position = $c + 1;
        my $last = $c;
        my $next = $c+2;
        if (!defined($in_array[$c])) {  ## Why did I do this?
            $output_string .= "$c $seq_array[$c] $last $next $seq_array[$c]\n";
        }
        elsif ($in_array[$c] eq '.') {
            $output_string .= "$position $seq_array[$c] $last $next 0\n";
        }
        else {
            my $bound_position = $in_array[$c] + 1;
            $output_string .= "$position $seq_array[$c] $last $next $bound_position\n";
        }
    }
    print $fh $output_string;
    return($output_file);
}

=head2 Make_Bpseq

 Title   : Make_Bpseq
 Usage   : my $outfile = $db->Make_Bpseq(output => ['4','3','.','1','0'], ['g','c','a','g','c']);
 Function: Creates a .bpseq file using the information from two arrays: 1.  a list of the base pairs from a sequence and 2.  The sequence.

=cut
sub Make_Bpseq {
    my ($me, %args) = @_;
    my @in_array = @{$args{output}};
    my @seq_array = @{$args{sequence}};
    my $output_file = $args{output_file};
    my ($fh, $filename);
    if (!defined($output_file)) {
        $fh = PRFdb::MakeTempfile(SUFFIX => '.bpseq');
        $output_file = $fh->filename;
    }
    elsif (ref($output_file) eq 'GLOB') {
        $fh = $output_file;
    }
    else {
        $fh = \*OUT;
        open($fh, ">$output_file");
    }
    
    my $output;
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
    return($output_file);
}

=head2 Genome_to_Fasta

 Title   : Genome_to_Fasta
 Usage   : my $count = $db->Genome_to_Fasta(output => 'saccharomyces_cerevisiae.fasta', species => 'saccharomyces_cerevisiae');
 Returns : The number of elements gathered from the database

=cut
sub Genome_to_Fasta {
    my ($me, %args) = @_;
    my $output = $args{output};
    my $species = $args{species};
    my $statement = qq"SELECT DISTINCT genome_id, accession, comment, FROM gene_info";
    my $info;
    system("mkdir $ENV{PRFDB_HOME}/blast") if (!-r  "$ENV{PRFDB_HOME}/blast");
    open(OUTPUT, "| gzip --stdout -f - >> $ENV{PRFDB_HOME}/blast/$output") or Callstack(die => 1, message => "Could not open the fasta output file.");
    if (defined($species)) {
        $statement .= qq" WHERE species = '$species'";
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
            my $string = qq">gi|$id|gb|$accession $species $comment
$sequence
";
            print OUTPUT $string;
        }
    }
    close(OUTPUT);
#    system("/usr/bin/gzip $ENV{PRFDB_HOME}/blast/$output");
    return($count);
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

=head2 MakeTempfile

 Title   : MakeTempfile
 Usage   : my $file_handle = MakeTempfile();
 Function: Calls File::Temp to make temporary files for the PRFdb.  Some (hopefully decent) defaults are set.
 Returns : A filehandle to the new file.

=cut
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

=head2 AddOpen

 Title   : AddOpen
 Usage   : my $open_files = AddOpen('filename')
 Function: Maintains a list of files opened by the PRFdb in the $config namespace.
 It is the responsibility of the Destructor in MAIN() to clear this list and make
 sure everything is deleted.  (Note the call to PRFdb::RemoveFile('all') in END())
 Returns : The number of files currently open.

=cut
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
    return(scalar(@open_files));
}

=head2 Remove_Duplicates

 Title   : Remove_Duplicates
 Usage   : my $count_removed = $db->Remove_Duplicates('NM_00579');
 Function: Deletes duplicate entries from the mfe tables.
 Returns : The number of deleted entries.

=cut
sub Remove_Duplicates {
    my $me = shift;
    my $accession = shift;
    my $species = $me->MySelect(statement => "SELECT species FROM gene_info WHERE accession = ?", vars => [$accession], type => 'single');
    my $mfe_table = "mfe_$species";
    $mfe_table = 'mfe_virus' if ($mfe_table =~ /virus/);
    my $info = $me->MySelect(qq"SELECT id,start,seqlength,mfe_method FROM $mfe_table WHERE accession = '$accession'");
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

=head2 RemoveFile

 Title   : RemoveFile
 Usage   : my $num_deleted = $db->RemoveFile('all');
 Function: Removes temporary files, usually when the prfdb shuts down.  The 'all' keyword
   tells it to delete everythig in its private list of opened files, populated by AddFile()
 Returns : The number of files deleted.

=cut
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

=head2 MakeFasta

 Title   : MakeFasta
 Usage   : my $fasta_file = $db->MakeFasta("ATGATGATG","1","3");
 Function: Create a fasta given a sequence, a start, and end position.
 Returns : A hash containing the relevant information: filehandle of the new file, its name, the sequence.

=cut
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

=head2 Id_to_AccessionSpecies

 Title   : Id_to_AccessionSpecies
 Usage   : my $acc_spec = $db->Id_to_AccessionSpecies('12','0');
 Function: Given an ID and start position of ORF, provide the accession and species for a given entry.
 Args    : something analagous to: { species => 'saccharomyces_cerevisiae', accession => 'NM_00012' }

=cut
sub Id_to_AccessionSpecies {
    my $me = shift;
    my $id = shift;
    my $start = shift;
    Callstack(message => "Undefined value in Id_to_AccessionSpecies") unless (defined($id));
    my $statement = qq"SELECT accession, species from gene_info where genome_id = ?";
    my $data = $me->MySelect(statement => $statement, vars => [$id], type => 'row');
    my $accession = $data->[0];
    my $species = $data->[1];
    my $return = {accession => $accession, species => $species,};
    return ($return);
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
        my $id_existing_stmt = qq"SELECT id FROM $table WHERE genome_id = '$id'";
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
        }
        else {
            $queue = $me->Get_Queue();
            return ($queue);
        }
        ## End check webqueue
    } 
    else {
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
    }
    else {
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
                ## Insert the entry here and add the queue entry
                
                if (!defined($datum{protein_seq}) or $datum{protein_seq} eq '') {
                    my $seq = new SeqMisc(sequence => $datum{mrna_seq});
                    my $aa_seq = $seq->{aaseq};
                    my $aa = '';
                    foreach my $c (@{$aa_seq}) { $aa .= $c; }
                    $datum{protein_seq} = $aa;
                }
                my $genome_id = $me->Put_Genome_Entry(\%datum);
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
                } 
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
                    ## End if the style is from the mammalian gene collection
                }
                elsif ($style eq 'misc') {
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
            }
            else {
                print "Style is not defined.\n";
            }
            ## End if you are on a > line
        }
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
    
    my $genome_id = $me->Put_Genome_Entry(\%datum);
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
            } elsif ($feature->{_location}{_strand} == 1) {
                $direction = 'forward';
                $start = $orf_start;
                $stop = $orf_stop;
            } elsif ($feature->{_location}{_strand} == -1) {
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
                print "key: $k data: $datum{$k}\n" if ($config->{debug});
            }
        } ## foreach feature in @cds
        print "Done this CDS\n\n\n";
    } # NEXT_SEQ
}

sub Collect_Cloud {
    my $me = shift;
    my %args = %{@_};
    my $species = $args{species};
    my $seqlength = $args{seqlength};
    my $filters = $args{filters};
    my ($points, $averages);
    
    if ($species != "virus") {
        my $mt = qq"mfe_$species";
        my $bt = qq"boot_$species";
        my $points_stmt = qq"SELECT $mt.mfe, $bt.zscore, $mt.accession, $mt.knotp, $mt.slipsite, $mt.start, genome.genename FROM $mt, $bt, genome WHERE $bt.zscore IS NOT NULL AND $mt.mfe > -80 AND $mt.mfe < 5 AND $bt.zscore > -10 AND $bt.zscore < 10 AND $mt.seqlength = $seqlength AND $mt.id = $bt.mfe_id AND ";
        my $averages_stmt = qq"SELECT avg($mt.mfe), avg($bt.zscore), stddev($mt.mfe), stddev($bt.zscore) FROM $mt, $bt WHERE $bt.zscore IS NOT NULL AND $mt.mfe > -80 AND $mt.mfe < 5 AND $bt.zscore > -10 AND $bt.zscore < 10 AND $mt.seqlength = $seqlength AND $mt.id = $bt.mfe_id AND ";
        
        foreach my $filter (@{$filters}) {
            if ($filter eq 'pseudoknots only') {
                $points_stmt .= "$mt.knotp = '1' AND ";
                $averages_stmt .= "$mt.knotp = '1' AND ";
            }
            elsif ($filter eq 'coding sequence only') {
                $points_stmt .= "";
                $averages_stmt .= "";
            }
        }
        $points_stmt .= " $mt.genome_id = genome.id";
        $averages_stmt =~ s/AND $//g;
        $points = $me->MySelect(statement => $points_stmt, vars => [$species]);
        $averages = $me->MySelect(statement => $averages_stmt, vars => [$species], type => 'row',);
    } else {  ## If the species _IS_ virus, then we have to do more work, but I am stupid and am not sure what to do...
    }
    return({points => $points, averages => $averages});
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
    $full_species =~ s/\(//g;
    $full_species =~ s/\)//g;
    $full_species =~ s/\-/\_/g;
    
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
        my $genome_id = $me->Put_Genome_Entry(\%datum);
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

=head2 Check_Insertion

 Title   : Check_Insertion
 Function: A quick sanity check to ensure that the fields of a table are defined before performing an insertion.
 Example : $db->Check_Insertion(columns => ['some_column','another_column'], data => 'some_data');
 Returns : undef if all is well, otherwise a string describing the missing columns.

=cut
sub Check_Insertion {
    my ($me,%args) = @_;
    my $list = $args{columns};
    my $data = $args{data};
    my $errorstring = undef;
    foreach my $column (@{$list}) {
        $errorstring .= "$column " unless (defined($data->{$column}));
    }
    return ($errorstring);
}

sub Check_Defined {
    my $me = shift;
    my %args = @_;
    my $return = '';
    foreach my $k (keys %args) {
        if (!defined($args{$k})) {
            $return .= "$k,";
        }
    }
    return ($return);
}

=head2 Tablep

 Title   : Tablep
 Function: See if a table exists.
 Example : $db->Tablep('Some_Table');
 Returns : The number of tables similar to 'Some_Table'
 Args    : A tablename.

=cut
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

=head2 StartSlave

 Title   : StartSlave
 Usage   : This may be used to set up and start a slave MySQL server.
 Example : $db->StartSlave(1); ## To run a command to grant replication, thus # $db->StartSlave() # if unneeded
 Returns : If it completes, it will return the value of ReSync()
 Args    : Any arguments passed tell it to grant replication to the new slave.

=cut
sub StartSlave {
    my $me = shift;
    my $grant_replication = shift;
    if ($grant_replication) {
        my $other_dbd = qq"dbi:$config->{database_type}:database=mysql;host=$config->{database_otherhost}";
        my $stmt = qq"GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '$config->{database_user}'\@'$ENV{PRFDB_IP}' IDENTIFIED BY '$config->{database_password}'";
        my $other_dbh_num = $me->MyConnect($stmt, $other_dbd, 'root', $me->{rpw}) or
            Callstack(message => "Unable to connect to $other_dbd", die => 1);
        my $other_dbh = $me->{handles}->[$other_dbh_num];
        my $o_sth = $other_dbh->prepare($stmt);
        my $o_rv = $o_sth->execute() or
            Callstack(message => "Unable to run: $stmt.", die => 1);
    }
    my $ret = $me->ReSync('slave');
    return($ret);
}

=head2 ReSync

 Title   : ReSync
 Function: Synchronize a slave MySQL server to the master.
 Example : $db->ReSync('slave');  ## or $db->ReSync(); ## For a master server
 Returns : Well, lets face it, if you are in a position where you need to perform a database synchronization, then
           something is likely wrong and this function will probably return a callstack which will tell you what is
           wrong.  If it does suceed, it will return the status of the last two statements.
 Args    : Any arguments tells this to set itself as a slave.

=cut
sub ReSync {
   my ($me,@slave) = @_;
   unless($me->{rpw}) {
       die("This requires root access to the database.");
   }
   my $other_dbd = qq"dbi:$config->{database_type}:database=mysql;host=$config->{database_otherhost}";
   my $local_dbd = qq"dbi:$config->{database_type}:database=mysql;host=localhost";
   my $statement = "SHOW MASTER STATUS";
   my $other_dbh_num = $me->MyConnect($statement, $other_dbd, 'root', $me->{rpw}) or
       Callstack(message => "Could not connect to $other_dbd.", die => 1);
   my $local_dbh_num = $me->MyConnect($statement, $local_dbd, 'root', $me->{rpw}) or
       Callstack(message => "Could not connect to $local_dbd.", die => 1);
    my $other_dbh = $me->{handles}->[$other_dbh_num];
    my $local_dbh = $me->{handles}->[$local_dbh_num];
    my $pre_statement = "STOP SLAVE";
    my $o_stop = $other_dbh->prepare($pre_statement);
    my $l_stop = $local_dbh->prepare($pre_statement);
    my $o_rv_stop = $o_stop->execute() or
	Callstack(message => "Could not execute $pre_statement on $other_dbd", die => 1);
    my $l_rv_stop = $l_stop->execute() or
	Callstack(message => "Could not execute $pre_statement on $local_dbd", die => 1);
   ## If an argument is passed to this, synchronize it as a slave.
   my $ret;
    if (@slave) {
        my $o_sth = $other_dbh->prepare($statement);
        my $o_rv = $o_sth->execute();
        my $o_return = $o_sth->fetchrow_arrayref();
        my $o_file = $o_return->[0];
        my $o_pos = $o_return->[1];
        my $l_reset = qq"CHANGE MASTER TO MASTER_LOG_FILE='$o_file', MASTER_LOG_POS=$o_pos";
        print "Remote log file and position is: $o_file $o_pos\n";
        print "Changing local master with:\n$l_reset\n";
        my $l_sth = $local_dbh->prepare($l_reset);
        my $l_rv = $l_sth->execute();
        $l_reset = "START SLAVE";
        $l_sth = $local_dbh->prepare($l_reset);
        $l_rv = $l_sth->execute();
        $ret = [$l_rv, $o_rv];
    } else {
        my $l_sth = $local_dbh->prepare($statement);
        my $l_rv = $l_sth->execute();
        my $l_return = $l_sth->fetchrow_arrayref();
        my $l_file = $l_return->[0];
        my $l_pos = $l_return->[1];
        my $o_reset = qq"CHANGE MASTER TO MASTER_LOG_FILE='$l_file', MASTER_LOG_POS=$l_pos";
        print "Local log file and position is: $l_file $l_pos\n";
        print "Changing remote master with: $o_reset\n";
        my $o_sth = $other_dbh->prepare($o_reset);
        my $o_rv = $o_sth->execute();
        $o_reset = "START SLAVE";
        $o_sth = $other_dbh->prepare($o_reset);
        $o_rv = $o_sth->execute();
        $ret = [$l_rv, $o_rv];
    }
   return($ret);
}

sub Cleanup {
    print "\n\nCaught Fatal signal. @_\n\n";    
    PRFdb::Disconnect();
    PRFdb::RemoveFile('all') if (defined($config->{remove_end}));
    exit(0);
}

sub DESTROY {
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
    } elsif ($name =~ /^Put_/) {
        my $newname = $name;
        $newname =~ s/Put_//g;
        $newname = "PRFdb::Put::$newname";
        {
            no strict 'refs';
            &$newname($me, @_);
        }
    } else {
        print "Unable to find the function $name in PRFdb.pm\n";
    }
#    if (@_) {
#	return $me->{$name} = shift;
#    } else {
#	return $me->{$name};
#    }
}

1;


__END__

=head2 Miscellaneous

Pretty much the rest of PRFdb.pm works to convert from one format
(fasta, the database, bpseq) to another (Ibid).  Because it handles
both flat files and database connections, it makes extensive use of
File::Temp and uses AddOpen and RemoveFile to keep track of the number
of temporary files created on disk.  These two functions are very
important to ensure that we don't end up filling the disk of
the HPCC cluster with millions of small temporary files created by
MakeFasta and friends.
In addition, this holds the importing code, and so makes use of
Bio::DB::Universal to download and import new sequences.

=cut
