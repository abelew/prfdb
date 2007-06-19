#! /usr/bin/perl -w
## #!/bin/sh
## for accession in `awk '{print $2}' PRFDB_FILE`
##   do
##   OMIMP=`./access_to_omim.pl $accession | grep OMIM`
##   if [ "${OMIMP}" -ne "" ]; then
##      echo $accession is in omim
##   fi
## done

use strict;
use Bio::DB::Universal;

my $accession = $ARGV[0];

my $uni = new Bio::DB::Universal;
my $seq = $uni->get_Seq_by_id($accession);
my @cds = grep { $_->primary_tag eq 'CDS' } $seq->get_SeqFeatures();
my ( $protein_sequence, $orf_start, $orf_stop );
my $binomial_species = $seq->species->binomial();
my ( $genus, $species ) = split( / /, $binomial_species );
my $full_species = qq(${genus}_${species});
$full_species =~ tr/[A-Z]/[a-z]/;
my $full_comment = $seq->desc();
my ( $genename, $desc ) = split( /\,/, $full_comment );
my $mrna_sequence = $seq->seq();
my $counter       = 0;
my $num_cds       = scalar(@cds);

foreach my $feature (@cds) {

  foreach my $k ( keys %{$feature} ) {
    print "key: $k value: $feature->{$k}\n";
  }

  my $gsf = $feature->{_gsf_tag_hash};
  foreach my $k ( keys %{$gsf} ) {
    print "key: $k value: $gsf->{$k}\n";
  }

  my $db_xrefs = $feature->{_gsf_tag_hash}->{db_xref};
  foreach my $ref ( @{$db_xrefs} ) {
    print "THE DB IS: $ref\n";
  }
  my $tmp_mrna_sequence = $mrna_sequence;
  $counter++;
  my $primary_tag = $feature->primary_tag();
  $protein_sequence = $feature->seq->translate->seq();
  $orf_start        = $feature->start();
  $orf_stop         = $feature->end();
  ### $feature->{_location}{_strand} == -1 or 1 depending on the strand.
  my $direction;
  if ( $feature->{_location}{_strand} == 1 ) {
    $direction = 'forward';
  } elsif ( $feature->{_location}{_strand} == -1 ) {
    $direction = 'reverse';
    my $tmp_start = $orf_start;
    $orf_start = $orf_stop - 1;
    $orf_stop  = $tmp_start - 2;
    my $fake_orf_stop = 0;
    undef $tmp_start;
    my @tmp_sequence = split( //, $tmp_mrna_sequence );
    my $tmp_length   = scalar(@tmp_sequence);
    my $sub_sequence = '';

    while ( $orf_start > $fake_orf_stop ) {
      $sub_sequence .= $tmp_sequence[$orf_start];
      $orf_start--;
    }
    $sub_sequence =~ tr/ATGCatgcuU/TACGtacgaA/;
    $tmp_mrna_sequence = $sub_sequence;
  } else {
    print PRF_Error("WTF: Direction is not forward or reverse\n");
  }
  ### Don't change me, this is provided by genbank
  #    print "TESTME: $orf_start $orf_stop\n\n";
  my $version => $seq->{_seq_version};
}

