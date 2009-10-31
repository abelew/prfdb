package Agree;
use PRFdb;

sub new {
    my ($class, %arg) = @_;
    my $me = bless {
	nupack_id => $arg{nupack_id},
	pknots_id => $arg{pknots_id},
	hotknots_id => $arg{hotknots_id},
	config => $arg{config},
    }, $class;
}

sub Do {
    my $me = shift;
    my %args = @_;
    my $stmt = qq"SELECT sequence, slipsite, parsed, output, algorithm FROM mfe WHERE id = ? or id = ? or id = ?";
    my $info = $db->MySelect(statement => $stmt, vars => [$me->{pknots_id}, $me->{nupack_id}, $me->{hotknots_id}],);

    my $sequence = $info->[0]->[0];
    $slipsite = $info->[0]->[1];
    my (@parsed, @pkout, @algorithm);
    my @seq = split(//, $sequence);
    foreach my $datum (@{$info}) {
	push(@parsed, $datum->[2]);
	push(@pkout, $datum->[3]);
	push(@algorithm, $datum->[4]);
    }


    my $struct;
    LOOP: for my $c (0 .. 120) {  ## Grossly overshoot the number of basepairs
	for my $d (0 .. $#pkout) {   ## The 3 or so algorithms available
	    my @pktmp = split(/\s+/, $pkout[$d]);
	    my @patmp = split(/\s+/, $parsed[$d]);
	    next LOOP if (!defined($pktmp[$c]));
	    $struct->{$c}->{$algorithm[$d]}->{partner} = $pktmp[$c];
	    $patmp[$c] = '.' if (!defined($patmp[$c]));
	    $struct->{$c}->{$algorithm[$d]}->{stemnum} = $patmp[$c];
	}
    }
    
    my $comp = {};
    my $agree = {
	all => 0,
	none => 0,
	n => 0,
	h => 0,
	p => 0,
	hn => 0,
	np => 0,
	hp => 0,
	hnp => 0,
    };
    my $c = -1;
    while ($c < 200) {
	$c++;
	next if (!defined($struct->{$c}));
	my $n = $struct->{$c}->{nupack}->{partner};
	my $h = $struct->{$c}->{hotknots}->{partner};
	my $p = $struct->{$c}->{pknots}->{partner};
	if (!defined($n)) {
	    print "n not defined\n";
	    next;
	} elsif (!defined($h)) {
	    print "h not defined\n";
	    next;
	} elsif (!defined($p)) {
	    print "$p not defined\n";
	    next;
	}

#	sleep(1);
	if ($struct->{$c}->{hotknots}->{partner} eq '.' and $struct->{$c}->{pknots}->{partner} eq '.' and $struct->{$c}->{nupack}->{partner} eq '.') {
	    $agree->{none}++;
	    ## Nothing is 0
	} elsif (($n eq $h) and ($n eq $p)) {
	    $agree->{all}++;
	    ## All 3 same is 1
	} elsif (($n ne $h) and ($n ne $p)) {
	    $agree->{hnp}++;
	    ## nupack is 2
	    ## hotknots is 3
	    ## pknots is 4
	} elsif ($n eq '.' and $h eq '.') {
	    $agree->{p}++;
	} elsif ($n eq '.' and $p eq '.') {
	    $agree->{h}++;
	} elsif ($h eq '.' and $p eq '.') {
	    $agree->{n}++;
	} elsif ($n eq '.') {
	    $agree->{hp}++;
	} elsif ($h eq '.') {
	    $agree->{np}++;
	} elsif ($p eq '.') {
	    $agree->{hn}++;
	} elsif ($n eq $p) {
	    $agree->{hnp}++;
	} elsif ($p eq $h) {
	    $agree->{hnp}++;
	}
    }
    return($agree);
}


1;
