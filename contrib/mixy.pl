#! /usr/bin/perl -w
## Jonathan phone  240 447 4039
use lib '.';
use Mixy;
my @seqArray = qw/
	GGGATCCCAAAAAAA
	GCGATCGCAAAAAAT
	CCGATCGGAAAAAAT
	CCAATTGGAAAAAAC
	CGAATTCGAAAAAGC
	CGGATCCGAACCCGC
	TGGATCCAAACCCGG
	AGGATCCTTTGGGCC
	CGGATCCGTTGGGCC
	CTGATCAGTTGGGTA
	CTCAAGAGTCCCCCC
/;

my $freq = new Mixy(seqs => \@seqArray);
my $sequences = $freq->{sequences};
#print "How many columns: $freq->{columns} rows: $freq->{rows}\n";
#print "What is at col 7, row 2:$sequences->[1]->[6]\n";
#print "How many As are in column 1?  $freq->{col_freq}->[0]->{A} \n";
#print "Ts in col 1? $freq->{col_freq}->[0]->{T}\n";
#print "How many As are there in row 4? $freq->{row_freq}->[3]->{A}\n";
#print "What is the ratio of As in row 4? $freq->{row_ratio}->[3]->{A}\n";
#print "What is the ratio of As in the 3rd column: $freq->{col_ratio}->[0]->{A}\n";
print "What is the joint frequency of A in col 1, C in col 7: $freq->{joint_freq}->[0]->[0]->{GG}\n";


my @mixies = @{$freq->{mixy}};
LOOP: for my $first (0 .. $#mixies) {
#  for my $second (0 .. @{$mixies[$first]}) {
  for my $second (0 .. @{$mixies[$first]}) {
#    if ($second > $first) {
#      print "\n";
#      next LOOP;
#    }
    if (!defined($mixies[$first]->[$second])) {
      next;
    }
    else {
      my $t = sprintf("%.2f", $mixies[$first]->[$second]);
      print "$t ";
    }
  }
  print "\n";
}
