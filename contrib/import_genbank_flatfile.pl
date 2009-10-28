#!/usr/bin/perl -w
use strict;
use lib '../lib';
use PRFConfig;
use PRFdb;
use Bio::DB::Universal;
use Bio::Index::GenBank;
my $config = new PRFConfig(config_file => "$ENV{HOME}/prfdb.conf");
my $db = new PRFdb(config=>$config);

my $uni = new Bio::DB::Universal();


#my $genbank = new Bio::Index::GenBank(-filename => 'ecoli.gb');
my $in  = Bio::SeqIO->new(-file => "ecoli.gb",
		       -format => 'genbank');
while (my $seq = $in->next_seq()) {
#$uni->use_database('genbank',$genbank);
    my $accession = 'NC_000913';
#my $seq = $uni->get_Seq_by_id($accession);
    my @cds = grep {$_->primary_tag eq 'CDS'} $seq->get_SeqFeatures();
    
    my ($protein_sequence, $orf_start, $orf_stop);
    my $binomial_species = $seq->species->binomial();
    my ($genus, $species) = split(/ /, $binomial_species);
    my $full_species = qq(${genus}_${species});
    $full_species =~ tr/[A-Z]/[a-z]/;
    $config->{species} = $full_species;
    $db->Create_Landscape(qq/landscape_$full_species/);
    $db->Create_Boot(qq/boot_$full_species/);
    my $full_comment = $seq->desc();
    my $defline = "lcl||gb|$accession|species|$full_comment\n";
    my ($genename, $desc) = split(/\,/, $full_comment);
    my $mrna_sequence = $seq->seq();
    my @mrna_seq = split(//, $mrna_sequence);
    my $counter = 0;
    my $num_cds = scalar(@cds);

    my %datum_orig = (
		      accession => $accession,
		      species => $full_species,
		      defline => $defline,
		      );

    foreach my $feature (@cds) {
	$counter++;
#	foreach my $k (keys %{$feature}) {
#	    print "WHAT IS: $k $feature->{$k}\n";
#	}
#	my %fun = %{$feature->{_gsf_tag_hash}};
#	foreach my $l (keys %fun) {
#	    print "WHAT IS GSF: $l $fun{$l}\n";
#	}
	my $primary_tag = $feature->primary_tag();
	$protein_sequence = $feature->seq->translate->seq();
	$orf_start = $feature->start();
	$orf_stop = $feature->end();
	#    print "START: $orf_start STOP: $orf_stop $feature->{_location}{_strand}\n";
	### $feature->{_location}{_strand} == -1 or 1 depending on the strand.
	my ($direction, $start, $stop);
	if (!defined($feature->{_location}{_strand})) {
	    $direction = 'undefined';
	    $start = $orf_start;
	    $stop = $orf_stop;
	}
	elsif ($feature->{_location}{_strand} == 1) {
	    $direction = 'forward';
	    $start = $orf_start;
	    $stop = $orf_stop;
	}
	elsif ($feature->{_location}{_strand} == -1) {
	    $direction = 'reverse';
	    $start = $orf_stop;
	    $stop = $orf_start;
	}
#	    my $fake_orf_stop = 0;
#	    undef $tmp_start;
#	    my @tmp_sequence = split(//, $tmp_mrna_sequence);
#	    my $tmp_length = scalar(@tmp_sequence);
#	    my $sub_sequence = '';
#	    
#	    while ($orf_start > $fake_orf_stop) {
#		$sub_sequence .= $tmp_sequence[$orf_start];
#		$orf_start--;
#	    }
#	    $sub_sequence =~ tr/ATGCatgcuU/TACGtacgaA/;
#	    $tmp_mrna_sequence = $sub_sequence;
#	}
#	else {
#	    print PRF_Error("WTF: Direction is not forward or reverse");
#	    $direction = 'forward';
#	}
	my $padding = 300;
	my $tmp_mrna_sequence = '';
	my $mrna_seqlength = $orf_stop - $orf_start;
	my $orf_start_pad = $orf_start - $padding;
	my $orf_stop_pad = $orf_stop + $padding;
	foreach my $c (($orf_start_pad - 1) .. ($orf_stop_pad - 1)) {
	    next if (!defined($mrna_seq[$c]));
	    $tmp_mrna_sequence .= $mrna_seq[$c];
	}
	if ($direction eq 'reverse') {
	    $tmp_mrna_sequence =~ tr/ATGCatgcuU/TACGtacgaA/;
	    $tmp_mrna_sequence = reverse($tmp_mrna_sequence);
	}
#	print "The sequences for this guy is $tmp_mrna_sequence\n";
	### Don't change me, this is provided by genbank
	### FINAL TEST IF $startpos is DEFINED THEN OVERRIDE WHATEVER YOU FOUND
	my $genename = '';
	if (defined($feature->{_gsf_tag_hash}->{gene}->[0])) {
	    $genename .= $feature->{_gsf_tag_hash}->{gene}->[0];
	}
	if (defined($feature->{_gsf_tag_hash}->{product}->[0])) {
	    $genename .= ", $feature->{_gsf_tag_hash}->{product}->[0]";
	}
	my %datum = (### FIXME
		     accession => qq/$accession-$orf_start/,
		     mrna_seq => $tmp_mrna_sequence,
		     protein_seq => $protein_sequence,
		     orf_start => 301,
		     orf_stop => (301 + $mrna_seqlength),
		     direction => $direction,
		     species => $full_species,
		     genename => $genename,
		     version => $seq->{_seq_version},
		     comment => $feature->{_gsf_tag_hash}->{note}->[0],
		     defline => qq/$defline, $feature->{_gsf_tag_hash}->{gene}->[0], $feature->{_gsf_tag_hash}->{product}->[0]/);
	$db->Insert_Genome_Entry(\%datum);
#	foreach my $k (keys %datum) {
#	    print "key: $k data: $datum{$k}\n";
#	    $datum{$k} = $datum_orig{$k};
#	}
    print "Done this CDS\n\n\n";
    } ## End of foreach @cds
}
