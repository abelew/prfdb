#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use DBI;
use lib "$ENV{HOME}/usr/lib/perl5";
use lib 'lib';
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile";
use RNAMotif;
use RNAFolders;
use Bootlace;
use Overlap;
use SeqMisc;
use PRFBlast;
use Agree;
$SIG{INT} = 'CLEANUP';
$SIG{BUS} = 'CLEANUP';
$SIG{SEGV} = 'CLEANUP';
$SIG{PIPE} = 'CLEANUP';
$SIG{ABRT} = 'CLEANUP';
$SIG{QUIT} = 'CLEANUP';

$config = new PRFConfig(config_file => "$ENV{HOME}/prfdb.conf");
$db = new PRFdb(config => $config);


my $rnamotif = new RNAMotif(config => $config);
my $str = '11..11111111.1111...22222221111.11111111.....11...2222222';
my $par = '((..((((((((.((((...{{{{{{{)))).)))))))).....))...}}}}}}}';
$rnamotif->Generic_Search_All($str, $par, 'saccharomyces_cerevisiae');


