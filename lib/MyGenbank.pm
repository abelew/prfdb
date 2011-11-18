package MyGenbank;
use strict;
use Bio::Seq;
use Bio::SeqIO;
use Bio::DB::Universal;
use Data::Dumper;
use vars qw($VERSION);
$VERSION='20111119';

sub new {
    my ($class, %arg) = @_;
    my $me = bless {
	seq => $arg{seq},
    }, $class;
#    $Data::Dumper::Indent = 1;
#    print Dumper($me->{seq});

    $me->Gather();

    ## Split out the database cross references if they exist.
    if ($me->{cds_xrefs}) {
	$me->Split_Data($me->{cds_xrefs});
    }
    if ($me->{gene_xrefs}) {
	$me->Split_Data($me->{gene_xrefs});
    }
    if ($me->{misc_features_synonyms} and $me->{gene_synonyms}) {
	my @misc = @{$me->{misc_features_synonyms}};
#	print "TESTME: GOT $me->{misc_features_synonyms} AND $me->{gene_synonyms} MISC:@misc GENE:@gene \n";
    }

    return($me);
}

sub Merge_Data {
    my $me = shift;
    my $datum_1 = shift;
    my $datum_2 = shift;
    my @dat_1 = @{$datum_1};
    my @dat_2 = @{$datum_2};
    return($me);
}

sub Split_Data {
    my $me = shift;
    my $datum = shift;
    my @dat = @{$datum};
    foreach my $ref (@dat) {
	next if (!defined($ref));
	if ($ref =~ /^MIM\:/) {
	    $me->{omim_id} = "" if (!defined($me->{omim_id}));
	    $ref =~ s/^MIM\://g;
	    $me->{omim_id} .= "$ref ";
	} elsif ($ref =~ /^HGNC\:/) {
	    $me->{hgnc_id} = "" if (!defined($me->{hgnc_id}));
	    $ref =~ s/^HGNC\://g;
	    $me->{hgnc_id} .= "$ref ";
	} elsif ($ref =~ /^GeneID\:/) {
	    $me->{gene_id} = "" if (!defined($me->{gene_id}));
	    $ref =~ s/^GeneID\://g;
	    $me->{gene_id} .= "$ref ";
	}
    }
    return($me);
}

sub Gather {
    my $me = shift;
    my $seq = $me->{seq};
    $me->{accession} = $seq->accession_number();
    my $binomial_species = $seq->species->binomial();
    my ($genus, $species) = split(/ /, $binomial_species);
    $me->{species} = qq"${genus}_${species}";
    $me->{species} =~ tr/[A-Z]/[a-z]/;
    $me->{full_comment} = $seq->desc();
    my ($genename, $desc) = split(/\,/, $me->{full_comment});
    $me->{genename} = $genename;
    $me->{desc} = $desc;
    $me->{molecule} = $seq->{_molecule};
    $me->{mrna_seq} = $seq->seq();
    $me->{annotation_comments} = [];
    $me->{annotation_reference_titles} = [];
    $me->{annotation_reference_authors} = [];
    $me->{annotation_reference_pubmeds} = [];
    $me->{annotation_reference_journals} = [];

    $me->{misc_features_synonyms} = [];
    $me->{misc_features_genes} = [];
    $me->{misc_features_notes} = [];

    $me->{cds_products} = [];
    $me->{cds_xrefs} = [];
    $me->{cds_protein_ids} = [];
    
    $me->{spliced_sequence} = "";

    ## Annotation information here
    my $annotations = $seq->annotation();
    my @annotation_types = $annotations->get_all_annotation_keys();
    foreach my $type (@annotation_types) {
	my @annotation_values = $annotations->get_Annotations($type);
	foreach my $value (@annotation_values) {
	    my $tree = $value->hash_tree();
	    if ($type eq 'comment') {
		my $comment_text = $value->as_text;
		$comment_text =~ s/REVIEWED REFSEQ: This record has been curated by NCBI staff.//g;
		$comment_text =~ s/This sequence is a reference standard in the RefSeqGene project.//g;
		$comment_text =~ s/VALIDATED REFSEQ: This record has undergone validation or preliminary review.//g;
		$comment_text =~ s/\[provided by RefSeq, .+\]\.//g;
		push(@{$me->{annotation_comments}}, $comment_text);
	    } elsif ($type eq 'reference') {
		push(@{$me->{annotation_reference_titles}}, $tree->{title});
		push(@{$me->{annotation_reference_authors}}, $tree->{authors});
		push(@{$me->{annotation_reference_pubmeds}}, $tree->{pubmed});
		push(@{$me->{annotation_reference_journals}}, $tree->{localtion});
		push(@{$me->{annotation_reference_medlines}}, $tree->{medline});
	    }
	}
    }

    ## Primary Seq here
    my $primary_seq = $seq->{primary_seq};
    $me->{primary_display_id} = $primary_seq->display_id();
    $me->{primary_seq} = $primary_seq->seq();
    $me->{primary_accession} = $primary_seq->accession_number();
    $me->{primary_description} = $primary_seq->desc();
    $me->{primary_alphabet} = $primary_seq->alphabet();
    $me->{primary_circular} = $primary_seq->is_circular();

    ## Features here
    my @features = $seq->get_SeqFeatures();
    foreach my $feature (@features) {
	my $tag = $feature->primary_tag;
	## Tags include: source, gene, mRNA, CDS, misc_feature, polyA_signal, polyA_site so far...
	if ($tag eq 'source') {
	    my $gsf = $feature->{_gsf_tag_hash};
	    my $location = $feature->{_location};
	    $me->{source_location_map} = $gsf->{map}->[0];
	    ## Also have, _source_tag, _gsf_seq, _gsf_seq_id, _primary_tag
	} elsif ($tag eq 'mRNA') {
	    my $gsf = $feature->{_gsf_tag_hash};
	    my $gsf_seq = $feature->{_gsf_seq};
	    my $location = $feature->{_location};
	    #foreach my $k (keys %{$feature}) {
	#	print "MRNA!KEY: $k VAL: $feature->{$k}\n";
	    #}
	    #print Dumper $gsf_seq;
	    #print Dumper $location;
	} elsif ($tag eq 'gene') {
	    my $gsf = $feature->{_gsf_tag_hash};
	    $me->{gene_xrefs} = $gsf->{db_xref};
	    $me->{gene_synonyms} = $gsf->{gene_synonym};
	    $me->{gene_name} = "@{$gsf->{gene}}";
	    $me->{gene_note} = $gsf->{note};
	} elsif ($tag eq 'CDS') {
	    my $gsf = $feature->{_gsf_tag_hash};
	    my $gsf_seq = $feature->{_gsf_seq};
	    #foreach my $k (keys %{$feature}) {
	    #print "KEY: $k VAL: $feature->{$k}\n";
	    #}
	    #print Dumper $gsf;
 	    #print Dumper $gsf_seq;
	    push(@{$me->{cds_products}}, $gsf->{product});
	    push(@{$me->{cds_xrefs}}, $gsf->{xref});
	    push(@{$me->{cds_protein_ids}}, $gsf->{protein_id});
	    $me->{spliced_sequence} .= $feature->spliced_seq->seq;

	    $me->{CDS_protein_seq} = $feature->seq->translate->seq();
	    $me->{CDS_orf_start} = $feature->start();
	    $me->{CDS_orf_stop} = $feature->end();
	    $me->{CDS_strand} = $feature->strand();
	} elsif ($tag eq 'misc_feature') {
	    my $gsf = $feature->{_gsf_tag_hash};
	    push(@{$me->{misc_features_synonyms}}, $gsf->{gene_synonym});
	    push(@{$me->{misc_features_gene}}, $gsf->{gene});
	    push(@{$me->{misc_features_note}}, $gsf->{note});
	} elsif ($tag eq 'polyA_signal') {
	    my $gsf = $feature->{_gsf_tag_hash};
	} elsif ($tag eq 'polyA_site') {
	    my $gsf = $feature->{_gsf_tag_hash};
	}
    }

}


1;
