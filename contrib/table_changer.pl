#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use lib "$ENV{PRFDB_HOME}/lib";
use local::lib "$ENV{PRFDB_HOME}/usr/perl";
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile Callstack Cleanup";
use autodie qw":all";
$config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
$SIG{INT} = \&PRFdb::Cleanup;

Alter_Tables();

sub Alter_Tables {
    my $tables = $db->MySelect(qq"SHOW TABLES LIKE 'mfe_%'");
    foreach my $table (@{$tables}) {
	my $t = $table->[0];
	my $alter = $db->MyExecute("ALTER TABLE $t CHANGE algorithm rand_method char(10)");
    }
}

