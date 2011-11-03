#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use local::lib "$ENV{PRFDB_HOME}/usr/perl";
use lib "$ENV{PRFDB_HOME}/lib";
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile Callstack Cleanup";
use MyGenbank;
use autodie qw":all";
use Bio::DB::Universal;
use Bio::SeqIO;

## Currently required fields.

## genome table		## gene_info
# accession		# accession
# gi_number		# species
# genename		# genename
# locus			# comment
# ontology_function	# defline
# ontology_component	# publications
# ontology_process	# hgnc_id
# version		# omim_id
# comment		# db_xrefs
# defline		# hgnc_name
# mrna_seq		# gene_synonyms
# protein_seq		# refseq_comment
# orf_start
# orf_stop
# direction
# omim_id




$config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
$SIG{INT} = \&PRFdb::Cleanup;
my $uni = new Bio::DB::Universal();
my $in = new Bio::SeqIO(-file => "tmp_sequence.gb", -format => 'genbank');
while (my $seq = $in->next_seq()) {
    my $insert_data = {};

    my $info = new MyGenbank(seq => $seq);
    my $publications = $info->{annotation_reference_titles};
    my @publications_array = @{$publications};
    @publications_array = () if !@publications_array;
    my $xrefs = $info->{gene_xrefs};
    my @xrefs_array = @{$xrefs};
    my $omim_id = $info->{omim_id};
    my $hgnc_id = $info->{hgnc_id};
    my $hgnc_name = $info->{gene_name};
    my $accession = $info->{accession};
    my @gene_synonyms = @{$info->{gene_synonyms}} if ($info->{gene_synonyms});
    my $refseq_comments = $info->{annotation_comments};
    my @comments = @{$refseq_comments};

    my $publication_string = "";
    foreach my $pub (@publications_array) {
	$publication_string .= "$pub \t ";
    }
    my $xrefs_string = "@xrefs_array";
    my $synonyms_string = "@gene_synonyms";
    my $comments_string = "@comments";

    my $stmt = qq"UPDATE gene_info SET publications = ?, hgnc_id = ?, omim_id = ?, db_xrefs = ?, hgnc_name = ?, gene_synonyms = ?, refseq_comment = ? WHERE accession = ?";
    $db->MyExecute(statement => $stmt, vars => [$publication_string, $hgnc_id, $omim_id, $xrefs_string, $hgnc_name, $synonyms_string, $comments_string, $accession]);

}
