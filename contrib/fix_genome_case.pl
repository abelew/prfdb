#! /usr/bin/perl -w
use strict;
use lib '../lib';

use PRFdb;
use PRFConfig;
my $config = new PRFConfig(config_file => '/usr/local/prfdb/prfdb_test/prfdb.conf');
my $db = new PRFdb(config => $config);

my $stmt = qq"SELECT id, mrna_seq FROM genome";
my $info = $db->MySelect($stmt);
foreach my $ids (@{$info}) {
    my $changed = undef;
    my ($id, $mrna_seq) = @{$ids};
    if ($mrna_seq =~ /U/) {
	print "Has U\n";
	$changed = 1;
	$mrna_seq =~ s/U/T/g;
    }
    if ($mrna_seq =~ /a/ or $mrna_seq =~ /g/ or $mrna_seq =~ /c/) {
	print "lowercase\n";
	$mrna_seq = uc($mrna_seq);
	$changed = 1;
    }

    if (defined($changed)) {
	my $stmt = qq"UPDATE genome set mrna_seq = '$mrna_seq' WHERE id = '$id'";
	$db->MyExecute($stmt);
	print "Would execute $stmt\n";
    }
}
