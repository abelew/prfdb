package MyDeps;
use CPAN;
use strict;
use Test::More;
use lib "$ENV{PRFDB_HOME}/lib";
use local::lib "$ENV{PRFDB_HOME}/usr/perl";

use vars qw($VERSION);
$VERSION='20111119';

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
    'Chart::Clicker',
    'DBI',
    'Devel::Trace',
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
    'JSON',
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

sub Res {
    use local::lib "$ENV{PRFDB_HOME}/usr/perl";
    my @lst = @_;
    unless (@lst) {
	@lst = @use_deps;
    }
    $ENV{FTP_PASSIVE} = 1;
    foreach my $module (@lst) {
        print "Loading $module\n";
        my $load_return = eval("use $module; 1");
        if (defined($module)) {
            my $version = $module->VERSION;
            print "Its version is: $version\n";
        }
        if (!$load_return) {
            my $dep_count = 0;
            while ($dep_count <= 50) {
                $dep_count++;
                my $missing = $@;
                if ($missing =~ /Global/) {
                    print "syntax error found in $module.\n";
                    print "$@";
                } elsif ($missing =~ /^Can\'t locate/) {
                    my @response = split(/ /, $missing);
                    $missing = $response[2];
                    $missing =~ s/\//::/g;
                    $missing =~ s/\.pm//g;
                    print "Going to install $missing\n";
                    CPAN::Shell->force("install", $missing);
                }
            }
        }
    }
}

1;
