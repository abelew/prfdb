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

$config = new PRFConfig(config_file => "$ENV{HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
my $extensions_stmt = qq"SELECT genome_id, minus_orf, start FROM overlap";
my $data = $db->MySelect($extensions_stmt);
foreach my $datum (@{$data}) {
    sleep(10);
    my ($id, $ext, $start) = @{$datum};
    next unless (length($ext) > 30);
    my $stmt = qq"SELECT accession, species, genename FROM genome WHERE id = '$id'";
    my $gene_info = $db->MySelect($stmt);
    my $da = $gene_info->[0];
    my $accession = $gene_info->[0][0];
    my $species = $gene_info->[0][1];
    my $genename = $gene_info->[0][2];
    my $done = $db->MySelect(statement => "SELECT done FROM overlap_blast_done WHERE accession = '$accession' and start = '$start'", type => 'single');
    next if ($done);
    print "\n\nWorking on $accession $species $genename\n";
    my $blast = new PRFBlast(config=>$config);
    my $info = $blast->Search($ext, 'remote', 'blastp');
    if (defined($info->{hits})) {
	my @hits = @{$info->{hits}};
	foreach my $c (0 .. $#hits) {
	    print "Hit number: $c, name: $info->{hits}->[$c]->{hit_name}
length: $info->{hits}->[$c]->{length}
description: $info->{hits}->[$c]->{description}
score: $info->{hits}->[$c]->{score}
significance: $info->{hits}->[$c]->{significance}\n";
	    my @hsps = ();
	    if (defined(@{$info->{hits}->[$c]->{hsps}})) {
		@hsps = @{$info->{hits}->[$c]->{hsps}};
	    }
	    foreach my $d (0 .. $#hsps) {
		print "HSP: $d evalue: $info->{hits}->[$c]->{hsps}->[$d]->{evalue}
Gaps: $info->{hits}->[$c]->{hsps}->[$d]->{gaps}
Identical: $info->{hits}->[$c]->{hsps}->[$d]->{num_identical}
Score: $info->{hits}->[$c]->{hsps}->[$d]->{score}
$info->{hits}->[$c]->{hsps}->[$d]->{query_string}
$info->{hits}->[$c]->{hsps}->[$d]->{homology_string}
$info->{hits}->[$c]->{hsps}->[$d]->{hit_string}
";
	    }
	}
    } else {
	print "No hits for $species $accession $genename\n";
    }
    $db->MyExecute("INSERT INTO overlap_blast_done (accession, start, done) VALUES ('$accession', '$start', 1)");
}
