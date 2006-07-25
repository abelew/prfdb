#! /usr/bin/perl -w
use strict;
use lib '../lib';

use PRFdb;
my $db = new PRFdb;
my $select = qq(SELECT genome_id, accession from mfe where species='homo_sapiens');

my $ids = $db->MySelect($select, 'hash', '1');
foreach my $num (keys %{$ids}) {
    my $test = qq(SELECT id from genome where accession='$ids->{$num}->{accession}');
    my $tmpid = $db->MySelect($test, 'hash');
    if ($tmpid->{id} != $ids->{$num}->{genome_id}) {
	
	my $update = qq(UPDATE mfe SET genome_id='$tmpid->{id}' WHERE accession='$ids->{$num}->{accession}');
	print "UPDATE: $update\n";
	$db->Execute($update);
    }
    else {
	print "Matched: Genome_id: $tmpid->{id} to MFE_ID: $ids->{$num}->{genome_id}\n";
    } 
}


