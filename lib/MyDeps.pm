package MyDeps;
use CPAN;
use strict;
use Test::More;
#use vars qw($VERSION);
#our @ISA = qw(Exporter);
#our @EXPORT = qw(deps);    # Symbols to be exported by default

our @use_deps = (
    'Agree',
    'Apache::DBI',
    'Apache2::Request',
    'Apache2::Upload',
    'AppConfig',
    'Bio::Seq',
    'Bio::SeqIO',
    'Bio::Tools::Run::StandAloneBlast',
    'Bootlace',
    'DBI',
    'Error',
    'Fcntl',
    'File::Temp',
    'GD',
    'GD::Graph',
    'GD::SVG',
    'Getopt::Long',
    'HTML::Mason',
    'HTMLMisc',
    'IO::Handle',
    'IPC::System::Simple',
    'Log::Any::Test',
    'Log::Log4perl',
    'Math::Stat',
    'Overlap',
    'PkParse',
    'PRFdb',
    'PRFConfig',
    'PRFGraph',
    'PRFBlast',
    'RNAFolders',
    'PRFsnp',
    'RNAMotif',
    'SeqMisc',
    'Statistics::Basic',
    'Statistics::Distributions',
    'SVG',
    'SVG::TT::Graph::Line',
    'Sys::SigAction',
    'Template',
    ## The following are only needed if you are running a webserver...
    );

our @require_deps = (
    'handle.pl',
    );

sub Test {
    foreach my $d (@use_deps) {
	my $response = use_ok($d);
	diag("Testing usability of $d\n");
	if ($response != 1) {
	    diag("$d appears to be missing.  Please run fixdeps.pl\n");
	}
    }
}

sub Res_locallib {
	my $load_return = eval("use local::lib; 1");
	if (!$load_return) {
	    CPAN::Shell->install("local::lib");
	}
}
sub Res {
    Res_locallib();
    $ENV{FTP_PASSIVE}=1;
    if (!-r "$ENV{HOME}/.cpan/CPAN/MyConfig.pm") {
## Dropped CPAN options here:
##  'makepl_arg' => q[PREFIX=$ENV{PRFDB_HOME}/usr],
##  'mbuild_install_arg' => q[PREFIX=$ENV{PRFDB_HOME}/usr],

#	system("mkdir -pv $ENV{HOME}/.cpan/CPAN");
#	system(qq"cat > $ENV{HOME}/.cpan/CPAN/MyConfig.pm <<eof
#\\\$CPAN::Config = {
#  'auto_commit' => q[1],
#  'build_cache' => q[10],
#  'cache_metadata' => q[1],
#  'commandnumber_in_prompt' => q[1],
#  'connect_to_internet_ok' => q[1],
#  'cpan_home' => q[$ENV{HOME}/.cpan],
#  'dontload_hash' => {  },
#  'ftp_passive' => q[1],
#  'ftp_proxy' => q[],
#  'getcwd' => q[cwd],
#  'histfile' => q[$ENV{HOME}/.cpan/histfile],
#  'histsize' => q[100],
#  'http_proxy' => q[],
#  'inactivity_timeout' => q[0],
#  'index_expire' => q[1],
#  'inhibit_startup_message' => q[0],
#  'keep_source_where' => q[$ENV{HOME}/.cpan/sources],
#  'make_arg' => q[],
#  'makepl_arg', => q[INSTALL_BASE=$ENV{PRFDB_HOME}/usr/perl],
#  'make_install_arg' => q[],
#  'make_install_make_command' => q[/usr/bin/make],
#  'mbuild_arg' => q[],
#  'mbuild_install_build_command' => q[./Build],
#  'mbuildpl_arg' => q[],
#  'pager' => q[less],
#  'prerequisites_policy' => q[follow],
#  'term_is_latin' => q[0],
#  'term_ornaments' => q[1],
#  'urllist' => q[http://mirrors.kernel.org/pub/CPAN,],[ftp://cpan.erlbaum.net/CPAN/],[ftp://mirrors.24-7-solutions.net/pub/CPAN/],[ftp://cpan-du.viaverio.com/pub/CPAN/],[ftp://cpan.pair.com/pub/CPAN/],[ftp://mirror.hiwaay.net/CPAN/],
#  'use_sqlite' => q[0],
#};
#	1;
#__END__
#eof");
    }
    foreach my $d (@use_deps) {
	print "Loading $d\n";
	my $load_return = eval("use $d; 1");
	if (!$load_return) {
	    my $dep_count = 0;
	    while ($dep_count <= 5) {
		$dep_count++;
		my $missing = $@;
		if ($missing =~ /Global/) {
		    print "syntax error found in $d.\n";
		    print "$@";
		} elsif ($missing =~ /^Can\'t locate/) {
		    my @response = split(/ /, $missing);
		    $missing = $response[2];
		    $missing =~ s/\//::/g;
		    $missing =~ s/\.pm//g;
		    print "Going to install $missing\n";
		    CPAN::Shell->force("install", $missing);
		}
#	print "TESTME: $d $load_return $@\n";
#	     diag("$d appears to be missing, building in $ENV{PRFDB_HOME}/src/perl\n");
#	    CPAN::Shell->install($d);
	    }
	}
    }
}

1;
