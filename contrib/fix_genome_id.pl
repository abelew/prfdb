#! /usr/bin/perl -w
use strict;
use lib '../lib';

use PRFdb;
my $db     = new PRFdb;
my $select = qq(SELECT genome_id, accession from mfe ORDER BY genome_id);

my $ids = $db->MySelect( $select, [] );
foreach my $entry (@{$ids}) {
    my $genome_id = $entry->[0];
    my $accession = $entry->[1];
    my $test = qq(SELECT id from genome where accession='$accession');
    my $tmpid = $db->MySelect( $test, [] );
    my $id = $tmpid->[0]->[0];
    if ( $id != $genome_id ) {
	my $update = qq(UPDATE mfe SET genome_id='$id' WHERE accession='$accession');
	print "UPDATE: $update\n";
	$db->Execute($update);
    }
    else {
	print "Matched: Genome_id(from genome): $id to genome_id(from mfe): $genome_id\n";
    }
}

