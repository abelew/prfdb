#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use DBI;
use lib "$ENV{HOME}/usr/lib/perl5";
use lib "$ENV{HOME}/prfdb/lib";
use lib '../lib';
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile";
use RNAMotif_Search;
use RNAFolders;
use Bootlace;
use Overlap;
use SeqMisc;
use PRFBlast;
use PRFGraph;

$config = new PRFConfig(config_file => "$ENV{HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
my $finished_species = $db->MySelect(statement => "SELECT species FROM finished", type => 'flat');
my $data = {
       species => $config->{index_species},
       seqlength => $config->{seqlength},
       max_mfe => [$config->{max_mfe}],
       algorithm => ['pknots','nupack','hotknots'],
    };
$db->Put_Stats($data, $finished_species);
