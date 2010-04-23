#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use DBI;
use lib "$ENV{HOME}/usr/lib/perl5";
use lib 'lib';
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile";
use RNAMotif_Search;
use RNAFolders;
use Bootlace;
use Overlap;
use SeqMisc;
use PRFBlast;
use Agree;
$SIG{INT} = 'CLEANUP';
$SIG{BUS} = 'CLEANUP';
$SIG{SEGV} = 'CLEANUP';
$SIG{PIPE} = 'CLEANUP';
$SIG{ABRT} = 'CLEANUP';
$SIG{QUIT} = 'CLEANUP';

$config = new PRFConfig(config_file => "$ENV{HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
setpriority(0,0,$config->{niceness});
$ENV{LD_LIBRARY_PATH} .= ":$config->{ENV_LIBRARY_PATH}" if(defined($config->{ENV_LIBRARY_PATH}));

my $overlaps = $db->MySelect("SELECT accession, genome_id, start FROM mfe WHERE species = 'saccharomyces_cerevisiae' and knotp = '1'");
my $last_acc = '';
my $last_start = '';
foreach my $datum (@{$overlaps}) {
    my $acc = $datum->[0];
    my $id = $datum->[1];
    my $start = $datum->[2];
    if ($acc eq $last_acc and $start eq $last_start) {
	next;
    }
    else {
	$last_acc = $acc;
	$last_start = $start;
    }
    my $seq = $db->MySelect(type => 'single', statement => "SELECT mrna_seq FROM gene_seq WHERE info_id = '$id'");
#    print "TESTME: $start
#$seq\n\n";
    my @seqtmp = split(//, $seq);
    my @seqtmp2 = @seqtmp;
    my $len = scalar(@seqtmp);
    my $offset = $start - $len;
    @seqtmp2 = splice(@seqtmp2, 0, ($start + 5));
    @seqtmp = splice(@seqtmp, ($start + 4)); 
#    my $string;
#    foreach my $c (@seqtmp2) { $string .= $c; }
#    my $minus_string;
#    foreach my $c (@seqtmp) {$minus_string .= $c; }
#    my $composite = $string . $minus_string;
    my @comp = (@seqtmp2, @seqtmp);
    my $seqobj = new SeqMisc(sequence => \@comp);
    my $amino_seq = $seqobj->{aaseq};
    my $amino_string;
    my $boundary = $start / 3;
    my $count = 0;
    LOOP: foreach my $c (@{$amino_seq}) {
	last LOOP if ($c eq '*');
	if ($count < $boundary) {
	    $amino_string .= lc($c);
	} else {
	    $amino_string .= $c;
	}
	$count++;
    }
    print ">$acc $start
$amino_string\n";
}
    
