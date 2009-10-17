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

my @ids = (440655, 440657, 625538);
my $accession = 'NM_000579';
my $overlap_pic = new PRFGraph({config=>$config, ids => \@ids, accession => $accession});
my $overlap_url = $overlap_pic->Picture_Filename({type => 'ofeynman', url => 'url',});
my $overlap_output_filename = $overlap_pic->Picture_Filename({type => 'ofeynman',});
my $ofeynman_dimensions = {};
if (!-r $overlap_output_filename) {
 $ofeynman_dimensions = $overlap_pic->Make_OFeynman();
}
my $overlap_width = $ofeynman_dimensions->{width};
my $overlap_height = $ofeynman_dimensions->{height};
