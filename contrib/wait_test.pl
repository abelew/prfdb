#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use DBI;
use lib "$ENV{HOME}/usr/lib/perl5";
use lib 'lib';
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile";
use RNAMotif_Search;
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
setpriority(0,0,$config->{niceness});
$ENV{LD_LIBRARY_PATH} .= ":$config->{ENV_LIBRARY_PATH}" if(defined($config->{ENV_LIBRARY_PATH}));

my $empty_comment = $db->MySelect("SELECT id, accession, genename FROM gene_info WHERE comment = ''");
foreach my $datum (@{$empty_comment}) {
    my $id = $datum->[0];
    my $ac = $datum->[1];
    my $ge = $datum->[2];
    my $fix = qq(UPDATE gene_info SET comment = ? WHERE id = '$id');
    my $new = "$ac $ge";
    my $fixing = $db->MyExecute(statement => $fix, vars => [$new]);
}
    
