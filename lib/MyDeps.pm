package MyDeps;
use CPAN;
use strict;
use Test::More;
#use vars qw($VERSION);
#our @ISA = qw(Exporter);
#our @EXPORT = qw(deps);    # Symbols to be exported by default

our @deps = (
	     'Math::Stat',
	     'Sys::Sigaction',
	     'Number::Format',
	     'File::Temp',
	     'DBI',
	     'AppConfig',
	     'Template',
	     'Getopt::Long',
	     'SVG',
	     'GD::Text',
	     'GD::Graph',
	     'GD::Graph::mixed',
	     'Statistics::Basic',
	     'Statistics::Distributions',
	     'Bio::DB::Universal',
	     'Bio::Seq',
	     'Bio::SearchIO::blast',
	     'GD::SVG',
	     'Log::Log4perl',
	     'Sys::SigAction',
	     ## The following are only needed if you are running a webserver...
	     'Apache::DBI',
	     'Apache2::Request',
	     'Apache2::Upload',
	     'Apache::DBI',
	     'HTML::Mason',
	     
    );

sub Resolve {
    my $type = shift;
    $ENV{CFLAGS}="-I$ENV{PRFDB_HOME}/usr/include -L$ENV{PRFDB_HOME}/usr/lib";
    $ENV{LD_LIBRARY_PATH}="$ENV{LD_LIBRARY_PATH}:$ENV{PRFDB_HOME}/usr/lib";
    foreach my $d (@deps) {
	my $response = use_ok($d);
	diag("Testing for $d\n");
	if ($response != 1) {
	    diag("$d appears to be missing, building in $ENV{PRFDB_HOME}/src/perl\n");
	    CPAN->mkmyconfig;
	    CPAN::Shell->o('autocommit', 1);
	    CPAN::Shell->o('conf', 'prerequisites_policy', 'follow');
	    CPAN::Shell->o('conf', 'urllist', [q[ ], q[ftp://carroll.cac.psu.edu/pub/CPAN/], q[ftp://cpan-du.viaverio.com/pub/CPAN/], q[ftp://cpan-sj.viaverio.com/pub/CPAN/], q[ftp://cpan.calvin.edu/pub/CPAN], q[ftp://cpan.cs.utah.edu/pub/CPAN/], q[ftp://cpan.cse.msu.edu/], q[ftp://cpan.erlbaum.net/CPAN/], q[ftp://cpan.glines.org/pub/CPAN/], q[ftp://cpan.hexten.net/]]);
	    CPAN::Shell->o('conf', 'connect_to_internet_ok', 1);
	    CPAN::Shell->o('conf', 'build_cache', 1024000);
	    CPAN::Shell->o('conf', 'build_dir', "$ENV{PRFDB_HOME}/src/perl");
	    CPAN::Shell->o('conf', 'makepl_arg', "PREFIX=$ENV{PRFDB_HOME}/usr");
	    CPAN::Shell->o('conf', 'make_install_arg', "PREFIX=$ENV{PRFDB_HOME}/usr");
	    CPAN::Shell->o('conf', 'mbuild_install_arg', "PREFIX=$ENV{PRFDB_HOME}/usr");
	    CPAN::Shell->o('conf', 'make_install', "PREFIX=$ENV{PRFDB_HOME}/usr make install ");
	    CPAN::Shell->install($d);
	}
    }
}

1;
