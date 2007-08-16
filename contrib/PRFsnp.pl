#!/usr/bin/perl -w

# package PRFsnp;
use strict;
use DBI;
use IO::File;
use lib "../lib";
use PRFConfig qw / PRF_Error PRF_Out /;
use PRFdb;
use Bio::DB::GenBank;
use Bio::DB::EUtilities;
use LWP;
use IO::String;

open (SNPOUT, ">>prfsnp.out") or die ("Dead: $!");

my $config = $PRFConfig::config;
my $db = new PRFdb;
my $gb = new Bio::DB::GenBank->new();
my $browser = LWP::UserAgent->new();

sub EUtil {
    # print "GET1\n";
    my $args = shift;
    my $url = undef;
    $url = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/' . (delete $args->{util}) . '.fcgi?';
    foreach my $key (keys %{$args}) {
	$url .= $key . '=' . $args->{$key} . '&'; 
    }
    print SNPOUT ("Now Fetching: $url\n"); 
    chop($url);
    my $response = $browser->get($url);
    if (defined($response)) {
	return $response->content();
    }
    sleep(3);
    return undef;
}

my $data = $db->MySelect( "SELECT accession, gi_number FROM genome WHERE species = 'homo_sapiens' AND gi_number IS NULL" );

my @gi_stream = '';

foreach my $datum ( @{$data} ) {
    my $accession = $datum->[0];
    my $gi_number = $datum->[1];
    push(@gi_stream, $accession) if ( !defined($gi_number) or $gi_number eq '' );
}

while ($#gi_stream > 0) {
    my @small_gi_stream = splice(@gi_stream, 0, 500);
    my $seq_stream = $gb->get_Stream_by_id(\@small_gi_stream);

    while ( my $seq = $seq_stream->next_seq() ) {
	my $accession = $seq->accession_number;
	my $gi_number = $seq->primary_id;
	my $statement = "UPDATE genome SET gi_number = ? WHERE accession = ?";
	print SNPOUT ("Now Executing: $statement\n");
	$db->MyExecute({ statement => $statement, vars => [$gi_number, $accession] });
    }
    sleep(3);
}
my $update = $db->MySelect({ statement => "SELECT gi_number FROM genome WHERE snp_lastupdate = '0000-00-00 00:00:00' AND species = 'homo_sapiens'", type => 'flat', } );
# foreach my $update (@{$data}) {
# my $update = [ 'BC005821', 'BC030960' ];
while ($#$update > 0) {
    my @small_update = splice(@{$update}, 0, 49);
    my $string = EUtil({ util       => 'efetch',
			 db         => 'nucleotide',
			 id         => join(',', @small_update),
			 extrafeat  => 1,
			 rettype    => 'genbank', });
    # print "GET2\n";
    my $stringio = IO::String->new($string);
    my $fetch = Bio::SeqIO->new( -fh => $stringio,
				 -format => 'genbank', );
    while ( my $seq = $fetch->next_seq() ) {
	my $acc = $seq->accession_number();
	my $gid = $seq->primary_id();
	my @features = $seq->get_SeqFeatures();
	foreach my $feat (@features) {
	    if ($feat->primary_tag eq 'variation') {
		my $location = '';
		if ($feat->start == $feat->end) {
		    $location = $feat->start;
		} else {
		    $location = $feat->start . '..' . $feat->end;
		}
		my $orient = $feat->strand;
		my $alleles = '';
		my $cluster_id = '';
		my $anno_group = $feat->annotation;
		foreach my $key ($anno_group->get_all_annotation_keys) {
		    my @annotations = $anno_group->get_Annotations($key);
		    foreach my $annotation (@annotations) {
			if ($annotation->tagname eq 'replace') {
			    my $tmp = $annotation->as_text;
			    my ($stuff, $allele) = split(/:\s+/, $tmp);
			    if ($allele eq '') {
				$alleles = '-';
			    }
			    $alleles .= uc($allele) . '/';
			}
			if ($annotation->tagname eq 'db_xref') {
			    my $tmp = $annotation->as_text;
			    my ($stuff, $value) = split(/:\s+/, $tmp);
			    my ($dbid, $cid) = split(/:/, $value);
			    $cluster_id = $cid;
			}
		    }
		}
		chop($alleles);
		my $statement = 'INSERT DELAYED IGNORE INTO snp (cluster_id, gene_acc, gene_gi, location, alleles, orientation) VALUES(?,?,?,?,?,?)'; 
		print SNPOUT ("Now Executing: $statement With Vars: $cluster_id, $acc, $gid, $location, $alleles, $orient\n");
		$db->MyExecute({ statement => $statement, vars => [$cluster_id, $acc, $gid, $location, $alleles, $orient] });
		my $update_stmt = 'UPDATE genome SET snp_lastupdate=CURRENT_TIMESTAMP WHERE accession = ?';
		print SNPOUT ("Now Executing: $update_stmt With Vars: $acc\n");
		$db->MyExecute({ statement => $update_stmt, vars => [$acc] });
	    }
	}
    }
}
close(SNPOUT);
