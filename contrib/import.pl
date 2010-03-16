#! /usr/bin/perl -w
use strict;

#my $accession = $ARGV[0];
#use Bio::DB::RefSeq;

#my $db = new Bio::DB::RefSeq;
#$db->request_format('fasta');

#my $seq = $db->get_Seq_by_acc('NM_006732'); # RefSeq ACC

#foreach my $k (keys %{$seq}) {
#  print  "TEST: $k $seq->{$k}\n";
#}
#print "seq is ", $seq->seq, "\n";
use Bio::DB::Universal;
use Bio::DB::GenBank;
my $uni = new Bio::DB::Universal;

# by default connects to web databases. We can also
# substitute local databases

#    $embl = Bio::Index::EMBL->new( -filename => '/some/index/filename/locally/stored');
#    $uni->use_database('embl',$embl);

# treat it like a normal database. Recognises strings
# like gb|XXXXXX and embl:YYYYYY

#   $seq1 = $uni->get_Seq_by_id("embl:HSHNRNPA");
#   $seq2 = $uni->get_Seq_by_acc("gb|A000012");
my $key  = 'NM_133775';
my $seq3 = $uni->get_Seq_by_id($key);
print "TESTME: $seq3\n";
foreach my $k ( keys %{$seq3} ) {
  print "TEST: $k and $seq3->{$k}\n";
}

#my @annotations = $seq3->_annotation->get_Annotations($key);
my $sp       = $seq3->species->binomial();
my $sequence = $seq3->seq();
my $desc     = $seq3->desc();
print "DESC: $desc\n";

#my $ann = $annotations[0]->as_text();
my $ac = $seq3->annotation();
my $hash;

my $gb    = new Bio::DB::GenBank;
my $seqio = $gb->get_Stream_by_acc($key);

while ( my $seq = $seqio->next_seq ) {
  foreach my $k ( keys %{$seq} ) {
    print "key: $k value: $seq->{$k}\n";
  }
}

foreach my $key ( $ac->get_all_annotation_keys() ) {
  my @values = $ac->get_Annotations($key);
  foreach my $value (@values) {

    # value is an Bio::AnnotationI, and defines a "as_text" method
    #    print "Annotation ",$key," stringified value ",$value->as_text,"\n";

    #    # also defined hash_tree method, which allows data orientated
    #    # access into this object
    #    $hash = $value->hash_tree();
  }
}

#
#
#
#foreach my $k (keys %{$hash}) {
#  print "TEST: $k $hash->{$k}\n";
#}

print "TESTTHESE:
$sp
$sequence

";

