#!/usr/bin/perl
use lib '/usr/local/prfdb/prfdb_test/lib';
use vars qw($config $db);
use PRFConfig;
use PRFdb qw(AddOpen RemoveFile);
use SeqMisc;
use Bio::Seq;
use Bio::SeqIO;
use Bio::SearchIO::blast;
use Bio::Tools::Run::RemoteBlast;

$config = new PRFConfig(config_file => '/usr/local/prfdb/prfdb_test/prfdb.conf');
$db = new PRFdb(config => $config);

my $stmt = qq"SELECT mfe.accession, mfe.mfe, mfe.start, mfe.bp_mstop, genome.mrna_seq FROM mfe,genome WHERE bp_mstop > '150' and genome.id = mfe.genome_id";
my $answer = $db->MySelect($stmt);
my $last_seq = '';
#open(OUT, ">>blast_hits.out");
print STDERR "Done mysql query.\n";
my $count = 0;
LOOP: foreach my $ans (@{$answer}) {
    $count++;
    print STDERR "Finished $count\n";
    my ($accession, $mfe, $start, $bp, $seq) = @{$ans};
    open(CHECK, "<blast_hits.done");
    while (my $line = <CHECK>) {
	chomp $line;
	next LOOP if ($line eq $accession);
    }
    close(CHECK);
    sleep 20;
    my @seqarray = split(//, $seq);
    my @removed = splice(@seqarray, 0, $start); ## array offset length
    shift @seqarray;
    shift @seqarray;
    my $newseq = '';
    foreach my $c (@seqarray) { $newseq .= $c; }
#    print "$newseq\n";
    my $seq = new SeqMisc(sequence => $newseq);
    my @minus_seq = @{$seq->{aaseq}};
    my $minus_string = '';
    foreach my $c (@minus_seq) {
	last if ($c eq '*');
	$minus_string .= $c;
    }
    next LOOP if ($last_seq eq $minus_string);
    my $pattern = qq"$minus_string\$";
    print STDERR "$pattern\n";
    next LOOP if ($last_seq =~ m/$pattern/);
    $pattern = qq"$last_seq\$";
    next LOOP if ($minus_string =~ m/$pattern/);
    print STDERR "$pattern\n";
    $last_seq = $minus_string;
    print "$accession $mfe $start $bp\n$minus_string\n";
#    print OUT "$accession $mfe $start $bp\n$minus_string\n";
    Blast_Fun($minus_string, $accession);
    open(DONE, ">>blast_hits.done");
    print DONE "$accession\n";
    close(DONE);
}
close(OUT);

sub Blast_Fun {
    my $sequence = shift;
    my $accession = shift;
    $sequence =~ tr/Uu/Tt/;
    my $string = qq">$accession
$sequence
";
    my $filename = $db->Sequence_to_Fasta($string);
    my @params = (-readmethod => 'SearchIO', -prog => 'blastp', -data => 'nr',);
    my $factory = new Bio::Tools::Run::RemoteBlast(@params);
    my $v = 1;
    my $r = $factory->submit_blast($filename);
#    print STDERR "waiting..." if($v > 0);
    while (my @rids = $factory->each_rid ) {
	foreach my $rid ( @rids ) {
	    my $rc = $factory->retrieve_blast($rid);
	    if( !ref($rc) ) {
		if( $rc < 0 ) {
		    $factory->remove_rid($rid);
		}
#		print STDERR "." if ( $v > 0 );
		sleep 5;
	    } else {
		my $result = $rc->next_result();
		#save the output
		my $filename = $result->query_name()."\.out";
		$factory->save_output($filename);
		$factory->remove_rid($rid);
		#print OUT "\nQuery Name: ", $result->query_name(), "\n";
		print "\nQuery Name: ", $result->query_name(), "\n";
		while ( my $hit = $result->next_hit ) {
		    next unless ( $v > 0);
		    print OUT "\thit name is ", $hit->name, "\n";
		    while( my $hsp = $hit->next_hsp ) {
			#print OUT "\t\tscore is ", $hsp->score, "\n";
			print "\t\tscore is ", $hsp->score, "\n";
		    }
		}
	    }
	}
    }
}
