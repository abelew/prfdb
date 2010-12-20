#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use lib "$ENV{PRFDB_HOME}/usr/lib/perl5";
use lib "$ENV{PRFDB_HOME}/lib";
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile Callstack Cleanup";
use PRFGraph;
$config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
$SIG{INT} = \&PRFdb::Cleanup;
#my $graph = new PRFGraph(config => $config);
#$graph->Make_Summary_Pie(800,800,'saccharomyces_cerevisiae','all','100','all');
$db->Create_Stats() if (!$db->Tablep('stats'));
my $datum = {
#	species => ['homo_sapiens'],
    species => $config->{index_species},
#	seqlength => [100],
    seqlength => $config->{seqlength},
    max_mfe => [$config->{max_mfe}],
#	algorithm => ['nupack'],
    algorithm => $config->{algorithms},
    };
$db->Put_Stats($datum);
