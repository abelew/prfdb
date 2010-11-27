#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use lib "$ENV{PRFDB_HOME}/usr/lib/perl5";
use lib "$ENV{PRFDB_HOME}/lib";
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile Callstack Cleanup";
$config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
$SIG{INT} = \&PRFdb::Cleanup;
my $stmt = qq"SELECT accession,start,mfe FROM mfe_homo_sapiens WHERE algorithm = 'nupack' AND seqlength = '100' ORDER by mfe";
my $mfe_values = $db->MySelect($stmt);
$stmt = qq"SELECT accession,start,zscore FROM boot_homo_sapiens WHERE mfe_method = 'nupack' AND seqlength = '100' ORDER by zscore";
my $z_values = $db->MySelect($stmt);
my $num_mfe = $#$mfe_values;
my $num_z = $#$z_values;
my %score;
for my $c (0 .. $num_mfe) {
    my $accession = $mfe_values->[$c]->[0];
    my $start = $mfe_values->[$c]->[1];
    $score{$accession}{$start}{mfe} = $mfe_values->[$c]->[2];
    $score{$accession}{$start}{mfe_score} = ($c / $num_mfe);
}
for my $d (0 .. $num_z) {
    my $accession = $z_values->[$d]->[0];
    my $start = $z_values->[$d]->[1];
    $score{$accession}{$start}{z} = $z_values->[$d]->[2];
    $score{$accession}{$start}{z_score} = ($d / $num_z);
}
foreach my $k (keys %score) {
    foreach my $s (keys %{$score{$k}}) {
	$score{$k}{$s}{total} = $score{$k}{$s}{mfe_score} + $score{$k}{$s}{z_score};
	print "$k: $s: Score: $score{$k}{$s}{total}\n";
    }
}
