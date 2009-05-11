#!/usr/bin/perl -w -I/usr/share/httpd/prfdb/usr/lib/perl5/site_perl/

use strict;
use DBI;
use lib '../lib';
use PRFConfig;
use PRFdb;
my $config = $PRFConfig::config;
my $db = new PRFdb;

my $spec = $ARGV[0];
my @algos = ('pknots','nupack','hotknots');
foreach my $alg (@algos) {
    my $start_stats = $db->MySelect({
	statement => "SELECT * from stats where species = '$spec' and algorithm = '$alg' and seqlength = '100'",
	type => 'list_of_hashes'});

    my $total_hepts = $start_stats->[0]->{num_sequences};
    my $total_mean = $start_stats->[0]->{avg_mfe};
    my $total_stdev = $start_stats->[0]->{stddev_mfe};

    my $knot_hepts = $start_stats->[0]->{num_sequences_knotted};
    my $knot_mean = $start_stats->[0]->{avg_mfe_knotted};
    my $knot_stdev = $start_stats->[0]->{stddev_mfe_knotted};
  
    my $mean_z = $start_stats->[0]->{avg_zscore};
    my $stddev_z = $start_stats->[0]->{stddev_zscore};

    my $sig_mfe = $total_mean - $total_stdev;
    my $sig_mfe_knot = $knot_mean - $knot_stdev;
    my $sig_z = $mean_z - $stddev_z;

    my $sigsig_mfe = $total_mean - ($total_stdev * 2);
    my $sigsig_mfe_knot = $knot_mean - ($knot_stdev * 2);
    my $sigsig_z = $mean_z - ($stddev_z * 2);

    my $all_stmt = qq/SELECT count(mfe.id) FROM mfe,boot WHERE mfe.seqlength = '100' AND mfe.algorithm = '$alg' AND mfe.mfe < '$sig_mfe' AND mfe.id = boot.mfe_id AND boot.zscore < '$sig_z'/;;
    my $pseudo_stmt = qq/SELECT count(mfe.id) FROM mfe,boot WHERE mfe.seqlength = '100' AND mfe.algorithm = '$alg' AND mfe.mfe < '$sig_mfe' AND knotp = '1' AND mfe.id = boot.mfe_id AND boot.zscore < '$sig_z'/;
    my $all_stmt_2 = qq/SELECT count(mfe.id) FROM mfe,boot WHERE mfe.seqlength = '100' AND mfe.algorithm = '$alg' AND mfe.mfe < '$sigsig_mfe' AND mfe.id = boot.mfe_id AND boot.zscore < '$sigsig_z'/;
    my $pseudo_stmt_2 =  qq/SELECT count(mfe.id) FROM mfe,boot WHERE mfe.seqlength = '100' AND mfe.algorithm = '$alg' AND mfe.mfe < '$sigsig_mfe' AND knotp = '1' AND mfe.id = boot.mfe_id AND boot.zscore < '$sigsig_z'/;

#    print "TESTME: $all_stmt
#$pseudo_stmt\n";
    my $count_sig_all = $db->MySelect({
	statement => $all_stmt,
	type => 'single',
	});
    my $count_pseudo_all = $db->MySelect({
	statement => $pseudo_stmt,
	type => 'single',
    });
    my $count_sig_all_2 = $db->MySelect({
	statement => $all_stmt_2,
	type => 'single',
    });
    my $count_pseudo_all_2 = $db->MySelect({
	statement => $pseudo_stmt_2,
	type => 'single',
    });
    print "alg;100bp hepts;mean mfe;hept knot;mfe knot;mean z;num sig;num sig knot; numsigsig;numsigsig knot\n";
    my $string = qq/$alg $total_hepts $total_mean $knot_hepts $knot_mean $mean_z $count_sig_all $count_pseudo_all $count_sig_all_2 $count_pseudo_all_2/;
    print "$string\n";

}
