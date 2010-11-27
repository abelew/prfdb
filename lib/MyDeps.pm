package MyDeps;
use CPAN;
use strict;
use Test::More;
#use vars qw($VERSION);
#our @ISA = qw(Exporter);
#our @EXPORT = qw(deps);    # Symbols to be exported by default

our @use_deps = (
	     'PRFdb',
	     'PRFConfig',
	     'PRFGraph',
	     'PRFBlast',
	     'RNAFolders',
	     'PRFsnp',
	     'Overlap',
	     'Agree',
	     'Bootlace',
	     'HTMLMisc',
	     'PkParse',
	     'SeqMisc',
	     'RNAMotif',
	     ## The following are only needed if you are running a webserver...
	     'Apache::DBI',
	     'Apache2::Request',
	     'Apache2::Upload',
	     'Apache::DBI',
	     'HTML::Mason',
	     );

our @require_deps = (
		     'handle.pl',
		     );

sub Test {
    foreach my $d (@deps) {
	my $response = use_ok($d);
	diag("Testing usability of $d\n");
	if ($response != 1) {
	    diag("$d appears to be missing.  Please run fixdeps.pl\n");
	}
    }
}

sub Res {
    $ENV{CFLAGS}="-I$ENV{PRFDB_HOME}/usr/include -L$ENV{PRFDB_HOME}/usr/lib";
    $ENV{LD_LIBRARY_PATH}="$ENV{LD_LIBRARY_PATH}:$ENV{PRFDB_HOME}/usr/lib";
    $ENV{FTP_PASSIVE}=1;
    if (!-r "$ENV{HOME}/.cpan/CPAN/MyConfig.pm") {
	system("mkdir -pv $ENV{HOME}/.cpan/CPAN");
	system(qq"cat > $ENV{HOME}/.cpan/CPAN/MyConfig.pm <<eof
\\\$CPAN::Config = {
  'auto_commit' => q[1],
  'build_cache' => q[10],
  'cache_metadata' => q[1],
  'commandnumber_in_prompt' => q[1],
  'connect_to_internet_ok' => q[1],
  'cpan_home' => q[$ENV{HOME}/.cpan],
  'dontload_hash' => {  },
  'ftp_passive' => q[1],
  'ftp_proxy' => q[],
  'getcwd' => q[cwd],
  'histfile' => q[$ENV{HOME}/.cpan/histfile],
  'histsize' => q[100],
  'http_proxy' => q[],
  'inactivity_timeout' => q[0],
  'index_expire' => q[1],
  'inhibit_startup_message' => q[0],
  'keep_source_where' => q[$ENV{HOME}/.cpan/sources],
  'make_arg' => q[],
  'make_install_arg' => q[],
  'make_install_make_command' => q[/usr/bin/make],
  'makepl_arg' => q[PREFIX=$ENV{PRFDB_HOME}/usr],
  'mbuild_arg' => q[],
  'mbuild_install_arg' => q[PREFIX=$ENV{PRFDB_HOME}/usr],
  'mbuild_install_build_command' => q[./Build],
  'mbuildpl_arg' => q[],
  'pager' => q[less],
  'prerequisites_policy' => q[follow],
  'term_is_latin' => q[0],
  'term_ornaments' => q[1],
  'urllist' => [q[http://mirrors.kernel.org/pub/CPAN,]],
  'use_sqlite' => q[0],
};
	1;
__END__
eof");
    }
    foreach my $d (@deps) {
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
		    CPAN::Shell->install($missing);
		}
#	print "TESTME: $d $load_return $@\n";
#	     diag("$d appears to be missing, building in $ENV{PRFDB_HOME}/src/perl\n");
#	    CPAN::Shell->install($d);
	    }
	}
    }
}

1;
