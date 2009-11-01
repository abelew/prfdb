#! /usr/bin/perl -w
use strict;
use lib '../lib';
use SeqMisc;
use PRFdb qw/ AddOpen callstack /;
use PRFConfig;
my $config = new PRFConfig(config_file => '/usr/local/prfdb/prfdb_test/prfdb.conf');
my $db = new PRFdb(config => $config);
my $stmt = qq"SELECT sequence FROM mfe limit 1";
#my $stmt = qq"SELECT sequence FROM mfe ORDER BY RAND() limit 1";
{
callstack();
}
my $info = $db->MySelect($stmt);
my $fun = $info->[0]->[0];
print "Original Sequence: $fun\n";
my $orig = $fun;
my $seq = new SeqMisc(sequence => $fun);
my $ntfreq = $seq->{ntfreq};
my $num = {
    A => $ntfreq->{A},
    T => $ntfreq->{U},
    C => $ntfreq->{C},
    G => $ntfreq->{G},
};
my $total = $num->{A} + $num->{T} + $num->{C} + $num->{G};
my @order = ();
foreach my $nucleotide (sort { $num->{$b} <=> $num->{$a} } keys %{$num}) {
    print "TESTME $nucleotide $num->{$nucleotide}\n";
    push(@order, $nucleotide);
}

print "Nums: A:$num->{A} T:$num->{T} C:$num->{C} G:$num->{G} total:$total\n";
my @new = ();
my %pairs = ('A' => ['T'],
	     'T' => ['A','G'],
	     'G' => ['C','T'],
	     'C' => ['G'],);
my $min;
$fun = 4;
while ($fun > 0) {
    $fun--;
    $min = pop(@order);
    Add();
}
print "TESTME: @order\n";
print "$orig\n";    
print @new , "\n";
print "Remaining A:$num->{A} T:$num->{T} C: $num->{C} G: $num->{G}\n";


sub Add {
callstack();
#    print "MIN: $min\n";
    my $c = 0;
    stacktrace();
#    print "NUM: $num->{$min}\n";
    while ($num->{$min} > $c) {
#	print "TESTME: $num->{$min} and $c\n";
	push(@new, $min);
#	print "Pushing $min\n";
	unshift(@new, $pairs{$min}->[0]) if ($num->{$pairs{$min}->[0]} > 0);
	$num->{$min}--;
	$num->{$pairs{$min}->[0]}--;
    }
}
