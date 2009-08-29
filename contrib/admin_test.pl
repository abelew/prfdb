#! /usr/bin/perl -w
use strict;
use lib '../lib';
use PRFConfig;
use PRFdb;

my $config = new PRFConfig(config_file=>'/usr/local/prfdb/prfdb_beta/prfdb.conf');
print "TEST: $config->{database_user}\n";
my $db = new PRFdb(config=>$config);
$db->Create_Nosy();
