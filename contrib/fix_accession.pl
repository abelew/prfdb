#! /usr/bin/perl -w -I/usr/share/httpd/prfdb/usr/lib/perl5/site_perl/
use strict;
use lib '../lib';
use PRFdb;

my $db     = new PRFdb;
fix('genome');
fix('mfe');
fix('boot');
sub fix {
    my $table = shift;
    my $select = "SELECT id, accession from $table";
    my $info = $db->MySelect($select);
    foreach my $acc (@{$info}) {
	my $accession = $acc->[1];
	my $id = $acc->[0];
	next unless ($accession =~ m/\./);
	my $new_accession = $accession;
	$new_accession =~ s/\./_/g;
	my $update = qq(UPDATE $table set accession = '$new_accession' WHERE id = '$id');
	$db->MyExecute($update);
    }
}
