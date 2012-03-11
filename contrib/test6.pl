#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use lib "$ENV{PRFDB_HOME}/usr/lib/perl5";
use lib "$ENV{PRFDB_HOME}/lib";
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile Callstack Cleanup";
use PRFGraph;
use RNAFolders;

my $config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
$SIG{INT} = \&PRFdb::Cleanup;

my $fold = new RNAFolders;

my $mfe_tables = $db->MySelect("SHOW TABLES LIKE \"mfe_%\"");
my $lan_tables = $db->MySelect("SHOW TABLES LIKE \"landscape_%\"");
my @all_tables = @{$mfe_tables};
push(@all_tables, @{$lan_tables});
foreach my $t (@all_tables) {
    my $table = $t->[0];
    print "Working on $table\n";
    my $data = $db->MySelect("SELECT id, sequence, parens FROM $table");
    my $count = 1;
    foreach my $datum (@{$data}) {
	my ($id, $sequence, $parens) = @{$datum};
	my $mfe_turner = $fold->Compute_Energy(sequence => $sequence, parens => $parens);
	if (!$mfe_turner) {
	    print "cd $ENV{PRFDB_HOME}/bin && $ENV{PRFDB_HOME}/bin/computeEnergy -d $sequence \"$parens\"\n";
	} else {
	    print "TESTME: $mfe_turner\n";
	}

#	if (($count % 100) == 0) {
#	    print "On $count, mfe is: $mfe_turner\n";
#	}
	$db->MyExecute("UPDATE $table SET mfe_turner = '$mfe_turner' WHERE id = '$id'");
	$count++;
    }
}
