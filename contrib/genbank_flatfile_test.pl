#!/usr/local/bin/perl -w 
use strict;
use local::lib "$ENV{PRFDB_HOME}/usr/perl";
use lib "$ENV{PRFDB_HOME}/lib";
use lib ".";
use MyGenbank;
use vars qw"$db $config";
die("Could not load PRFConfig.\n$@\n") unless (eval "use PRFConfig; 1");
$config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
die("Could not load PRFdb.\n$@\n") unless (eval "use PRFdb qw'AddOpen RemoveFile Callstack Cleanup'; 1");
$db = new PRFdb(config => $config);
die("Could not load RNAMotif.\n$@\n") unless (eval "use RNAMotif; 1");
die("Could not load RNAFolders.\n$@\n") unless (eval "use RNAFolders; 1");
die("Could not load Bootlace.\n$@\n") unless (eval "use Bootlace; 1");
die("Could not load Overlap.\n$@\n") unless (eval "use Overlap; 1");
die("Could not load SeqMisc.\n$@\n") unless (eval "use SeqMisc; 1");
die("Could not load PRFBlast.\n$@\n") unless (eval "use PRFBlast; 1");
die("Could not load Agree.\n$@\n") unless (eval "use Agree; 1");
my $load_return = eval("use PRFGraph; 1");
warn("Could not load PRFGraph, disabling graphing routines.\n$@\n") unless($load_return);

die("Could not load Bio::DB::Universal.\n $@\n") unless (eval "use Bio::DB::Universal; 1");
die("Could not load Bio::Index::GenBank.\n $@\n") unless (eval "use Bio::Index::GenBank; 1");

my $import_genbank = "$ENV{PRFDB_HOME}/contrib/tmp_sequence.gb";


my $in  = Bio::SeqIO->new(-file => $import_genbank,
			  -format => 'genbank');
while (my $seq = $in->next_seq()) {
    my $genbank = new MyGenbank(seq => $seq);
    ## Available pieces:
    # _annotation Bio::Annotation::Collection=HASH(0x3481ac0)
    # _as_feat ARRAY(0x34ce688)
    # _dates ARRAY(0x34cde90)
    # _division PRI
    # _molecule mRNA
    # _root_verbose 0
    # _secondary_accession ARRAY(0x34ce670)
    #  _seq_version 1
    # primary_seq Bio::PrimarySeq=HASH(0x34ce460)
    # species Bio::Species=HASH(0x34870b0)


    my @comments = @{$genbank->{annotation_comments}};
    my @titles = @{$genbank->{annotation_reference_titles}};
    my @authors = @{$genbank->{annotation_reference_authors}};
    print "ANNOTATIONS: @comments\n
TITLES:
@titles
AUTHORS
@authors
ORF_START: $genbank->{CDS_orf_start}
Location: $genbank->{source_location_map}
SPLICED_SEQUENCE: $genbank->{spliced_sequence}
\n";
    sleep(10);
}


#	sleep(1);
#	my @cds = grep {$_->primary_tag eq 'CDS'} $seq->get_SeqFeatures();
#	$accession = $seq->accession_number();
#	print "GOT Accession. $accession\n";
#	my ($protein_sequence, $orf_start, $orf_stop);
#	my $binomial_species = $seq->species->binomial();
#	my ($genus, $species) = split(/ /, $binomial_species);
#	my $full_species = qq(${genus}_${species});
#	$full_species =~ tr/[A-Z]/[a-z]/;
#	my $full_comment = $seq->desc();
#	my $defline = "lcl||gb|$accession|species|$full_comment\n";
#	my ($genename, $desc) = split(/\,/, $full_comment);
#	my $mrna_sequence = $seq->seq();
#	my @mrna_seq = split(//, $mrna_sequence);
#	my $counter = 0;
#	my $num_cds = scalar(@cds);
#	
#	my %datum_orig = (
#	    accession => $accession,
#	    species => $full_species,
#	    defline => $defline,
#	    );
#	
#	foreach my $feature (@cds) {
#	    $counter++;
#	    my $primary_tag = $feature->primary_tag();
#	    print "TESTME: $primary_tag\n";
#	    $protein_sequence = $feature->seq->translate->seq();
#	    $orf_start = $feature->start();
#	    $orf_stop = $feature->end();
#	    my ($direction, $start, $stop);
#	    if (!defined($feature->{_location}{_strand})) {
#		$direction = 'undefined';
#		$start = $orf_start;
#		$stop = $orf_stop;
#	    } elsif ($feature->{_location}{_strand} == 1) {
#		$direction = 'forward';
#		$start = $orf_start;
#		$stop = $orf_stop;
#	    } elsif ($feature->{_location}{_strand} == -1) {
#		$direction = 'reverse';
#		$start = $orf_stop;
#		$stop = $orf_start;
#	    }
#	    my $padding = 300;
#	    my $tmp_mrna_sequence = '';
#	    my $mrna_seqlength = $orf_stop - $orf_start;
#	    my $orf_start_pad = $orf_start - $padding;
#	    my $orf_stop_pad = $orf_stop + $padding;
#	    foreach my $c (($orf_start_pad - 1) .. ($orf_stop_pad - 1)) {
#		next if (!defined($mrna_seq[$c]));
#		$tmp_mrna_sequence .= $mrna_seq[$c];
#	    }
#	    if ($direction eq 'reverse') {
#		$tmp_mrna_sequence =~ tr/ATGCatgcuU/TACGtacgaA/;
#		$tmp_mrna_sequence = reverse($tmp_mrna_sequence);
#	    }
#	    #	print "The sequences for this guy is $tmp_mrna_sequence\n";
#	    ### Don't change me, this is provided by genbank
#	    ### FINAL TEST IF $startpos is DEFINED THEN OVERRIDE WHATEVER YOU FOUND
#	    my $genename = '';
#	    if (defined($feature->{_gsf_tag_hash}->{gene}->[0])) {
#		$genename .= $feature->{_gsf_tag_hash}->{gene}->[0];
#	    }
#	    if (defined($feature->{_gsf_tag_hash}->{product}->[0])) {
#		$genename .= ", $feature->{_gsf_tag_hash}->{product}->[0]";
#	    }
#	    my $db_xrefs = "";
#	    my $omim_id = "";
#	    my $hgnc_id = "";
#	    if (defined($feature->{_gsf_tag_hash}->{db_xref}->[0])) {
#		my $db_xref_list = $feature->{_gsf_tag_hash}->{db_xref};
#		foreach my $db (@{$db_xref_list}) {
#		    $db_xrefs .= "$db ";
#		    if ($db =~ /^MIM\:/) {
#			$db =~ s/^MIM\://g;
#			$omim_id .= "$db ";
#		    }    ## Is it in omim?
#		    if ($db =~ /^HGNC\:/) {
#			$db =~ s/^HGNC\://g;
#			$hgnc_id .= "$db ";
#		    }
#		}
#	    }
#	} ## Foreach feature @cds
#   } ## Foreach sequence
#}
