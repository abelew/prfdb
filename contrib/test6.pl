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


my $species = 'saccharomyces_cerevisiae';
my $slipsites = 'all';
my $seqlength = '100';
my $mfe_method = 'hotknots';
my $width = 800;
my $height = 800;
my $url = qq"/images/pie/${species}_${slipsites}_${seqlength}_${mfe_method}.svg";
my $filename = qq"$ENV{PRFDB_HOME}${url}";
my $pie = new PRFGraph(config => $config);
$pie->Make_Summary_Pie($filename,$width,$height,$species,$slipsites,$seqlength,$mfe_method);
