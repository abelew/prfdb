package HTML::Mason::Commands;
use vars qw($session $dbh $db $ah $req $config);
use local::lib "$ENV{PRFDB_HOME}/usr/perl";
use Apache2::Request;
use Apache2::Upload;
use Apache::DBI;
use Log::Log4perl;
use File::Temp qw/ tmpnam /;
use lib qq"$ENV{PRFDB_HOME}/lib";
use PRFConfig;
use PRFdb qw/ AddOpen RemoveFile Callstack /;
use RNAFolders;
use PRFGraph;
use SeqMisc;
use PRFBlast;
use HTMLMisc;
BEGIN {
    if (!defined($ENV{PRFDB_HOME})) {
	Callstack(die => 1, message => "PRFDB_HOME is not set.  Either set it in your apache env vars or shell profile.");
    }
}
$config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
$ENV{BLASTDIR} = $config->{blastdir};
$ENV{BLASTDATADIR} = $config->{blastdir};
my $database_hosts = $config->{database_host};
Apache::DBI->connect_on_init("DBI:$config->{database_type}:database=$config->{database_name};host=$database_host->[0]", $config->{database_user}, $config->{database_pass}, $config->{database_args}) or print "Can't connect to database: $DBI::errstr $!";
Apache::DBI->setPingTimeOut("DBI:$config->{database_type}:$config->{database_name}:$database_host->[0]", 0);
$db = new PRFdb(config=>$config);

package PRFdb::Handler;
use strict;
use HTML::Mason::ApacheHandler;
BEGIN {
    use Exporter ();
    @PRFdb::Handler::ISA = qw(Exporter);
    @PRFdb::Handler::EXPORT = qw();
    @PRFdb::Handler::EXPORT_OK = qw($req $dbh $dbs);
}
my $req;
my $ah = new HTML::Mason::ApacheHandler(
					comp_root => $ENV{PRFDB_HOME},
					data_dir => $ENV{PRFDB_HOME},
					args_method => "mod_perl",
					request_class => 'MasonX::Request::WithApacheSession',
					session_class => 'Apache::Session::File',
					session_cookie_domain => 'umd.edu',
					session_directory => "$ENV{PRFDB_HOME}/sessions/data",
					session_lock_directory => "$ENV{PRFDB_HOME}/sessions/locks",
					session_use_cookie => 1,
					);
sub handler {
    my ($r) =  @_;

#    my $path_info = $r->uri;
#    my @info = split(/\./, $path_info);
#    print STDERR "$path_info\n";
#    if (scalar(@info < 2)) {
#	print STDERR "less than 2!\n";
#    } else {
#	print STDERR "2 or more\n";
#    }
#
#    if ($path_info =~ /^.*\.\w+$/) {
#	$r->filename($r->document_root . '/error/404.html');
#	return($ah->handle_request($r));
#    }

    my $return = eval { $ah->handle_request($r) };
    if (my $err = $@) {
	$r->pnotes(error => $err);
	$r->filename($r->document_root . '/error/500.html');
	return($ah->handle_request($r));
    }
    return($return);
}

package PRFdb::NotAllowed;
use strict;
use HTML::Mason::ApacheHandler;
BEGIN {
    use Exporter ();
    @PRFdb::Handler::ISA = qw(Exporter);
    @PRFdb::Handler::EXPORT = qw();
    @PRFdb::Handler::EXPORT_OK = qw($req $dbh $dbs);
}
my $req;
my $ah = new HTML::Mason::ApacheHandler(
					comp_root => "$ENV{PRFDB_HOME}/error",
					data_dir  => "$ENV{PRFDB_HOME}/error",
					args_method   => "mod_perl",
#					request_class => 'MasonX::Request',
					);
sub handler {
    my ($r) =  @_;
#    $r->pnotes(error => "Unauthorized");
    $r->filename($r->document_root . '/error/404.html');
    return $ah->handle_request($r);
} 
1;
