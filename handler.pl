package HTML::Mason::Commands;
use vars qw($session $dbh $db $ah $req $config);
use Apache2::Request;
use Apache2::Upload;
use Data::Dumper;
use Apache::DBI;
use File::Temp qw/ tmpnam /;
use lib '/usr/local/prfdb/prfdb_test/lib';
use PRFConfig;
use PRFdb qw/ AddOpen RemoveFile /;
use RNAFolders;
use PRFGraph;
use SeqMisc;
use PRFBlast;
use HTMLMisc;

Apache::DBI->connect_on_init('DBI:mysql:prfdb_test:localhost', 'prfdb', 'drevil') or print "Can't connect to database: $DBI::errstr $!";
#Apache::DBI->connect_on_init('DBI:mysql:sessions:localhost', 'sessions', 'cbmg_sessions') or die "Can't connect to database: $DBI::errstr";
Apache::DBI->setPingTimeOut('DBI:mysql:forms:localhost', 0);
#Apache::DBI->setPingTimeOut('DBI:mysql:sessions:localhost', 0);
$config = new PRFConfig(config_file => "/usr/local/prfdb/prfdb_test/prfdb.conf");
$db = new PRFdb(config=>$config);

package PRFdb::Handler;
use strict;
#use HTML::Mason::ApacheHandler(args_method=>'mod_perl');
use HTML::Mason::ApacheHandler;
BEGIN {
    use Exporter ();
    @PRFdb::Handler::ISA = qw(Exporter);
    @PRFdb::Handler::EXPORT = qw();
    @PRFdb::Handler::EXPORT_OK = qw($req $dbh $dbs);
}
my $req;
my $ah = new HTML::Mason::ApacheHandler(
					comp_root => '/usr/local/prfdb/prfdb_test',
					data_dir  => '/usr/local/prfdb/prfdb_test',
					args_method   => "mod_perl",
					request_class => 'MasonX::Request::WithApacheSession',
					session_class => 'Apache::Session::File',
					session_cookie_domain => 'prfdb.umd.edu',
					session_directory => '/tmp/sessions/data',
					session_lock_directory => '/tmp/sessions/locks',
					session_use_cookie => 1,
					);
sub handler {
    my ($r) =  @_;
    my $return = eval { $ah->handle_request($r) };
    if ( my $err = $@ )
    {
	$r->pnotes(error => $err);
	$r->filename($r->document_root . '/error/500.html');
	return $ah->handle_request($r);
    }
    return $return;
}
 
1;
