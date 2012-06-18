#!/usr/local/bin/perl
use warnings;
use strict;
use lib "$ENV{PRFDB_HOME}/lib";
use local::lib "$ENV{PRFDB_HOME}/usr/perl";
use autodie qw":all";
use JSON;
use vars qw"$db $config";
use lib "$ENV{PRFDB_HOME}/lib";
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile Callstack Cleanup";
use Data::Dumper;
use PerlIO;

$Data::Dumper::Purity = 1;
my $config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
my $db = new PRFdb(config => $config);

my %starts;
#my $input_file = "hs_mgc_mrna.sam";
#my $input_file = "pc3_all_fp.fastq.sam";
my $input_file = "fp_filtered_sequences.fastq.sam";
open(IN, "<$input_file");
my $added = 0;
LOOP: while (my $line = <IN>) {
    chomp($line);
    my $imported = 0;
    my ($read_id, $flag, $refname, $ref_position, $map_quality, $cigar, $ref_seq, $next_position, $obs_temp_len, $segment_seq, $segment_qual, $align_score, $second_score, $num_ambig, $num_mismatch, $num_gaps, $gaps_extended, $num_changes, $ident_trans_string) = split(/\t/, $line);
    my ($gi, $gid, $gb, $accession) = split(/\|/, $refname);
    $accession =~ s/\..+$//g;
    if (!defined($accession)) {
	next LOOP;
    }
    if (defined($starts{$accession})) {
	next LOOP;
    } else {
	my $st = $db->MySelect(type => 'single', vars => [ $accession ], statement => "SELECT orf_start FROM genome WHERE accession = ?");
	if (!defined($st)) {
	    my $newdb = new PRFdb(config => $config);
	    my $new = $newdb->Import_CDS($accession);
	    $imported++;
	    $st = $newdb->MySelect(type => 'single', vars => [ $accession ], statement => "SELECT orf_start FROM genome WHERE accession = ?");
	    $newdb->Disconnect();
	    $newdb = undef;
	}
	$added++;
	$starts{$accession} = $st;
	print STDERR "$added\t$accession\t$st\t$imported\n";
    }
}
close(IN);
print Dumper \%starts;

open(JUSTINCASE, ">starts.txt");
foreach my $k (keys %starts) {
    print JUSTINCASE "$k\t$starts{$k}\n";
}
close(JUSTINCASE);
