#! /usr/bin/perl -w
use strict;
use lib '../lib';
use SeqMisc;
use PRFdb;
use PRFConfig;
my $config = new PRFConfig(config_file => '/usr/local/prfdb/prfdb_test/prfdb.conf');
my $db = new PRFdb(config => $config);
my $stmt = qq"SELECT sequence FROM mfe limit 1";
#my $stmt = qq"SELECT sequence FROM mfe ORDER BY RAND() limit 1";
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
if ($num->{A} >= $num->{T} and $num->{A} >= $num->{G} and $num->{A} >= $num->{C}) {
    push(@order, 'A');
    if ($num->{T} >= $num->{G} and $num->{T} >= $num->{C}) {
	push(@order, 'T');
	if ($num->{G} >= $num->{C}) {
	    push(@order, 'G'), push(@order, 'C');
	} else {
	    push(@order, 'C'), push(@order, 'G');
	}
    } elsif ($num->{G} >= $num->{C} and $num->{G} >= $num->{T}) {
	push(@order, 'G');
	if ($num->{C} >= $num->{T}) {
	    push(@order, 'C'), push(@order, 'T');
	} else {
	    push(@order, 'T'), push(@order, 'C');
	}
    } elsif ($num->{C} >= $num->{G} and $num->{C} >= $num->{T}) {
	push(@order, 'C');
	if ($num->{G} >= $num->{T}) {
	    push(@order, 'G'), push(@order, 'T');
	} else {
	    push(@order, 'T'), push(@order, 'G');
	}
    }
} elsif ($num->{T} >= $num->{G} and $num->{T} >= $num->{C} and $num->{T} >= $num->{A}) {
    push(@order, 'T');
    if ($num->{A} >= $num->{G} and $num->{A} >= $num->{C}) {
	push(@order, 'A');
	if ($num->{G} >= $num->{C}) {
	    push(@order, 'G'), push(@order, 'C');
	} else {
	    push(@order, 'C'), push(@order, 'G');
	}
    } elsif ($num->{G} >= $num->{A} and $num->{G} >= $num->{C}) {
	push(@order, 'G');
	if ($num->{A} >= $num->{C}) {
	    push(@order, 'C'), push(@order, 'A');
	} else {
	    push(@order, 'A'), push(@order, 'C');
	}
    } elsif ($num->{C} >= $num->{A} and $num->{C} >= $num->{G}) {
	push(@order, 'C');
	if ($num->{A} >= $num->{G}) {
	    push(@order, 'A'), push(@order, 'G');
	} else {
	    push(@order, 'G'), push(@order, 'A');
	}
    }
} elsif ($num->{G} >= $num->{C} and $num->{G} >= $num->{A} and $num->{G} >= $num->{T}) {
    push(@order, 'G');
    if ($num->{A} >= $num->{C} and $num->{A} >= $num->{T}) {
	push(@order, 'A');
	if ($num->{C} >= $num->{T}) {
	    push(@order, 'C'), push(@order, 'T');
	} else {
	    push(@order, 'T'), push(@order, 'C');
	}
    } elsif ($num->{C} >= $num->{A} and $num->{C} >= $num->{T}) {
	push(@order, 'C');
	if ($num->{A} >= $num->{T}) {
	    push(@order, 'A'), push(@order, 'T');
	} else {
	    push(@order, 'T'), push(@order, 'A');
	}
    } elsif ($num->{T} >= $num->{A} and $num->{T} >= $num->{C}) {
	push(@order, 'T');
	if ($num->{A} >= $num->{C}) {
	    push(@order, 'A'), push(@order, 'C');
	} else {
	    push(@order, 'C'), push(@order, 'A');
	}
    }
} else {
    push(@order, 'C');
    if ($num->{A} >= $num->{G} and $num->{A} >= $num->{T}) {
	push(@order, 'A');
	if ($num->{G} >= $num->{T}) {
	    push(@order, 'G'), push(@order, 'T');
	} else {
	    push(@order, 'T'), push(@order, 'G');
	}
    } elsif ($num->{G} >= $num->{T} and $num->{G} >= $num->{A}) {
	push(@order, 'G');
	if ($num->{T} >= $num->{A}) {
	    push(@order, 'T'), push(@order, 'A');
	} else {
	    push(@order, 'A'), push(@order, 'T');
	}
    } elsif ($num->{T} >= $num->{A} and $num->{T} >= $num->{A}) {
	push(@order, 'T');
	if ($num->{A} >= $num->{G}) {
	    push(@order, 'A'), push(@order, 'G');
	} else {
	    push(@order, 'G'), push(@order, 'A');
	}
    }
}
print "Nums: A:$num->{A} T:$num->{T} C:$num->{C} G:$num->{G} total:$total\n";
my @new = ();
my %pairs = ('A' => ['T'],
	     'T' => ['A','G'],
	     'G' => ['C','T'],
	     'C' => ['G'],);
my $min;
my $fun = 4;
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
#    print "MIN: $min\n";
    my $c = 0;
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
