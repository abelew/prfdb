#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use DBI;
use lib "$ENV{HOME}/usr/lib/perl5";
use lib "$ENV{HOME}/prfdb/lib";
use lib '../lib';
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile";
use RNAMotif_Search;
use RNAFolders;
use Bootlace;
use Overlap;
use SeqMisc;
use PRFBlast;
use PRFGraph;

$config = new PRFConfig(config_file => "$ENV{HOME}/prfdb.conf");
$db = new PRFdb(config => $config);

my $everything = $db->MySelect("SELECT accession, seqlength, start FROM mfe");
foreach my $datum (@{$everything}) {
    my $accession = $datum->[0];
    my $seqlength = $datum->[1];
    my $start = $datum->[2];
    print "Working with $accession $seqlength $start\n";
    if ($seqlength ne '100' and $seqlength ne '75' and $seqlength ne '50') {
	print "Skipping.\n";
	next;
    }
    my $ids = $db->MySelect(statement => "SELECT id FROM mfe WHERE accession = ? AND seqlength = ? AND start = ?", vars => [$accession, $seqlength, $start]);
    my @id = ();
    foreach my $i (@{$ids}) {
	push(@id, $i->[0]);
    }
    my $num_ids = scalar(@id);
    if ($num_ids != 3) {
	print "Skipping $accession $start $seqlength\n";
	next;
    }
    my $overlap_pic = new PRFGraph({config=>$config, ids => \@id, mfe_id => $seqlength, accession => $accession});
    my $overlap_url = $overlap_pic->Picture_Filename({type => 'ofeynman', url => 'url',});
    my $overlap_output_filename = $overlap_pic->Picture_Filename({type => 'ofeynman',});
    my $ofeynman_dimensions = {};
    if (!-r $overlap_output_filename) {
	$ofeynman_dimensions = $overlap_pic->Make_OFeynman();
    }
    my $overlap_width = $ofeynman_dimensions->{width};
    my $overlap_height = $ofeynman_dimensions->{height};
    my $agree = $ofeynman_dimensions->{agree};
    $db->Put_Agree(accession => $accession, start => $start, length => $seqlength, agree => $agree);
    undef $overlap_pic;
    undef $ids;
    undef @id;
    undef $overlap_url;
    undef $overlap_output_filename;
    undef $ofeynman_dimensions;
    undef $agree;
}
