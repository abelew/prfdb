#!/usr/bin/perl
use Bio::Seq;
use Bio::SeqIO;
use Bio::SearchIO::blast;
use Bio::Tools::Run::RemoteBlast;

my $blast_output = new Bio::SearchIO(-format => 'blast',);
$sequence =~ tr/Uu/Tt/;
#my $seq = new Bio::Seq(-display_id => 'query',
#		       -seq => $sequence,);
my @params = (-readmethod => 'SearchIO',
	      -prog => 'blastn',
	      -data => 'nr',);
my $factory = new Bio::Tools::Run::RemoteBlast(@params);
my $v = 1;

my $str = Bio::SeqIO->new(-file=>'test.fasta' , -format => 'fasta' );
while (my $input = $str->next_seq()) {
    my $r = $factory->submit_blast($input);

    print STDERR "waiting..." if( $v > 0 );
    while ( my @rids = $factory->each_rid ) {
	foreach my $rid ( @rids ) {
	    my $rc = $factory->retrieve_blast($rid);
	    if( !ref($rc) ) {
		if( $rc < 0 ) {
		    $factory->remove_rid($rid);
		}
		print STDERR "." if ( $v > 0 );
		sleep 5;
	    } else {
		my $result = $rc->next_result();
                 #save the output
		my $filename = $result->query_name()."\.out";
		$factory->save_output($filename);
		$factory->remove_rid($rid);
		print "\nQuery Name: ", $result->query_name(), "\n";
		while ( my $hit = $result->next_hit ) {
		    next unless ( $v > 0);
		    print "\thit name is ", $hit->name, "\n";
		    while( my $hsp = $hit->next_hsp ) {
			print "\t\tscore is ", $hsp->score, "\n";
		    }
		}
	    }
	}
    }
}

