#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use lib "$ENV{PRFDB_HOME}/usr/lib/perl5";
use lib "$ENV{PRFDB_HOME}/lib";
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile Callstack Cleanup";
use PRFGraph;
use autodie qw":all";
use MicroRNA;

$config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
$SIG{INT} = \&PRFdb::Cleanup;
#my $graph = new PRFGraph(config => $config);
## mature.fa hairpin.fa
my $t = new MicroRNA(config => $config);
$t->Miranda_PRF("NM_000579","473");
