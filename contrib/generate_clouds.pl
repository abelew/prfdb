#!/usr/bin/perl -w
use strict;
use lib '../lib';
use PRFdb;
use PRFConfig;
use PRFGraph;

our $config = $PRFConfig::config;
our $db = new PRFdb;
our $graph = new PRFGraph;

unless ($db->Tablep('cloud_images')) {
    $db->Create_CloudImages();
}
unless ($db->Tablep('bar_images')) {
    $db->Create_BarImages();
}

my @species = ('saccharomyces_cerevisiae', 'mus_musculus', 'homo_sapiens',);
my @seqlength = (100);
my @knotted = (0,1);
my @slipsite = ('all', 'AAAAAAA', 'AAAAAAU', 'AAAAAAC', 'AAAUUUA', 'AAAUUUU', 'AAAUUUC', 'UUUAAAA', 'UUUAAAU', 'UUUAAAC', 'UUUUUUA', 'UUUUUUU', 'UUUUUUC', 'CCCAAAA', 'CCCAAAU', 'CCCAAAC', 'CCCUUUA', 'CCCUUUU', 'CCCUUUC', 'GGGAAAA', 'GGGAAAU', 'GGGAAAC', 'GGGAAAG', 'GGGUUUA', 'GGGUUUU', 'GGGUUUC');
foreach my $spec (@species) {
    print "Working on: Species: $spec\n";
    foreach my $seqlen (@seqlength) {
	print "  Seqlength: $seqlen\n";
	    foreach my $slip (@slipsite) {
		print "    Slip: $slip\n";
		my ($points_stmt, $averages_stmt);
		foreach my $knotp (@knotted) {
		    print "      Knot: $knotp\n";
		    if (!$knotp) {
			$points_stmt = qq(SELECT mfe.mfe, boot.zscore, mfe.accession, mfe.knotp, mfe.slipsite FROM mfe, boot WHERE boot.zscore IS NOT NULL AND mfe.mfe > -80 AND mfe.mfe < 5 AND boot.zscore > -10 AND boot.zscore < 10 AND mfe.species = ? AND mfe.seqlength = ? AND mfe.id = boot.mfe_id);
			$averages_stmt = qq(SELECT avg(mfe.mfe), avg(boot.zscore), stddev(mfe.mfe), stddev(boot.zscore) FROM mfe, boot WHERE boot.zscore IS NOT NULL AND mfe.mfe > -80 AND mfe.mfe < 5 AND boot.zscore > -10 AND boot.zscore < 10 AND mfe.species = ? AND mfe.seqlength = ? AND mfe.id = boot.mfe_id);
		    }
		    else {
			$points_stmt = qq(SELECT mfe.mfe, boot.zscore, mfe.accession, mfe.knotp, mfe.slipsite FROM mfe, boot WHERE boot.zscore IS NOT NULL AND mfe.mfe > -80 AND mfe.mfe < 5 AND boot.zscore > -10 AND boot.zscore < 10 AND mfe.species = ? AND mfe.seqlength = ? AND mfe.id = boot.mfe_id AND mfe.knotp = '1');
			$averages_stmt = qq(SELECT avg(mfe.mfe), avg(boot.zscore), stddev(mfe.mfe), stddev(boot.zscore) FROM mfe, boot WHERE boot.zscore IS NOT NULL AND mfe.mfe > -80 AND mfe.mfe < 5 AND boot.zscore > -10 AND boot.zscore < 10 AND mfe.species = ? AND mfe.seqlength = ? AND mfe.id = boot.mfe_id AND mfe.knotp = '1');
		    }
		    my $points = $db->MySelect({statement => $points_stmt, vars => [$spec,$seqlen]});
		    my $averages = $db->MySelect({statement => $averages_stmt, vars => [$spec,$seqlen], type => 'row', });
		    my $cloud_args = {
			species => $spec,
			points => $points,
			averages => $averages,
			pknot => $knotp,
			slipsites => $slip,
		    };
		    my $stuff = $graph->Make_Cloud($cloud_args);
		    my $cloud_insert = qq(INSERT into cloud_images (species, seqlength, knotted, slipsite, map, data) VALUES (?,?,?,?,?,?));
		    my ( $cp, $cf, $cl ) = caller();
		    my $rc = $db->Execute($cloud_insert, [$spec, $seqlen, $knotp, $slip, $stuff->{map}, $stuff->{cloud}], [$cp,$cf,$cl]);

		    if (defined($stuff->{bar_total})) {
			my $bars_insert = qq(INSERT into bar_images (species, seqlength, knotted, total, significant, percent_sig) VALUES (?, ?, ?, ?, ?, ?));
			( $cp, $cf, $cl ) = caller();
			$rc = $db->Execute($bars_insert, [$spec, $seqlen, $knotp, $stuff->{bar_total}, $stuff->{bar_significant}, $stuff->{percent}], [$cp,$cf,$cl]);
		    }

	 	} ## foreach knotted
	    } ## foreach slipsite
    } ## foreach seqlength
} ## foreach species
