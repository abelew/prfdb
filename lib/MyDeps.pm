package MyDeps;
use CPAN;
use strict;
use Test::More;
#use vars qw($VERSION);
#our @ISA = qw(Exporter);
#our @EXPORT = qw(deps);    # Symbols to be exported by default

our @deps = (
    'Number::Format',
    'File::Temp',
    'DBI',
    'AppConfig',
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
    );

our @apache_deps = (
    'Apache::DBI',
    'Apache2::Request',
    'Apache2::Upload',
    'Apache::DBI',
    'HTML::Mason',
    );

sub Resolve {
    my $type = shift;
    my @array;
    if (!defined($type)) {
	@array = @deps;
    } else {
	@array = @apache_deps;
    }
    $ENV{CFLAGS}="-I$ENV{PRFDB_HOME}/usr/include -L$ENV{PRFDB_HOME}/usr/lib";
    $ENV{LD_LIBRARY_PATH}="$ENV{LD_LIBRARY_PATH}:$ENV{PRFDB_HOME}/usr/lib";
    foreach my $d (@array) {
	my $response = use_ok($d);
	diag("Testing for $d\n");
	if ($response != 1) {
	    diag("$d appears to be missing, building in $ENV{PRFDB_HOME}/src/perl\n");
	    CPAN->mkmyconfig;
	    CPAN::Shell->o('autocommit', 1);
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
