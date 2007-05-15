package PRF_Blast;
use strict;
use Bio::Seq;
use Bio::Tools::Run::StandAloneBlast;
use Bio::Tools::Run::RemoteBlast;

sub new {
  my ($class, %arg) = @_;
  my $me = bless {
  }, $class;
  return($me);
}

sub Format_Db {
  my $me = shift;
  my $input = shift;  ## Fasta file to format.
  my $command = qq(cd blast && formatdb  -i $input -p F -o T -n prfdb -s);
  system($command);
}

sub Search {
  my $me = shift;
  my $sequence = shift;
  my $location = shift;
  my $return = {};
  my $factory;
  my $blast_output;
  my $result;
  my $seq = new Bio::Seq(
                         -display_id => 'query',
                         -seq => $sequence);

  if ($location eq 'local') {
    print "LOCAL\n";
    my @params = (
                program => 'blastn',
                database => 'prfdb',
                I => 't',  ## -I tells blast to output the GI identifier, which is the id in the genome db
              );
    ## The param array just takes the first letter of the key and passes its value as the argument eg.
    ## -p blastn -d prfdb -I t
    $factory = new Bio::Tools::Run::StandAloneBlast(@params);
    $blast_output = $factory->blastall($seq);  ## A Bio::SeqIO
    $result = $blast_output->next_result;
  }
  else {
    my @params = (
                  -readmethod => 'SearchIO',
                  -prog => 'blastn',
                  -data => 'nr',
                 );
    $factory = new Bio::Tools::Run::RemoteBlast(@params);
#    my $r = $factory->submit_blast($seq);

    my $r = $factory->submit_blast($seq);
    LOOP: while (my @rids = $factory->each_rid()) {
      foreach my $rid (@rids) {
        $blast_output = $factory->retrieve_blast($rid);
        if (!ref($blast_output)) {
          if ($blast_output < 0) {
            $factory->remove_rid($rid);
          }
          print ". ";
          sleep(5);
        }
        else {
          $result = $blast_output->next_result();
#          if (defined($result)) {
            my $filename = $result->query_name() . "\.out";
            $factory->save_output($filename);
            $factory->remove_rid($rid);
#            print "\nQuery Name: ", $result->query_name(), "\n";
#            while ( my $hit = $result->next_hit ) {
#              print "\thit name is ", $hit->name, "\n";
#              while( my $hsp = $hit->next_hsp ) {
#                print "\t\tscore is ", $hsp->score, "\n";
#              }
        } ## End else
#          }
#            last LOOP;
      } ## End each rid
    } ## End all rids
  }
#  print "STILL HAVE RESULT\n";
#  #  my $result = new Bio::SearchIO::blast(
#  #                                        -format => 'blast',
#  #                                       );
#  ## $result is of type Bio::Search::Result::BlastResult
#  ## But is accessed by Bio::SearchIO  and Bio::SearchIO::blast
  my $count = 0;
  ## Global results here
  $return->{algorithm} = $result->algorithm() if (defined($result->algorithm()));
  $return->{algorithm_version} = $result->algorithm_version();
  $return->{query_name} = $result->query_name();
  $return->{query_length} = $result->query_length();
  $return->{query_description} = $result->query_description();
  $return->{database_name} = $result->database_name();
  $return->{database_numletters} = $result->database_letters();
  $return->{available_statistics} = $result->available_statistics();
  $return->{available_parameters} = $result->available_parameters();
  $return->{num_hits} = $result->num_hits();
  print "Summary:
algo  $return->{algorithm}
version  $return->{algorithm_version}
name  $return->{query_name}
len  $return->{query_length}
name  $return->{database_name}
numletters  $return->{database_numletters}
stats  $return->{available_statistics}
params  $return->{available_parameters}
num_hits  $return->{num_hits}
";

  ## Results for each hit here
  while( my $hit = $result->next_hit()) {
    $count++;
    $return->{$count}->{hit_name} = $hit->name();
    $return->{$count}->{length} = $hit->length();
    $return->{$count}->{accession} = $hit->accession();
    $return->{$count}->{description} = $hit->description();
    $return->{$count}->{algorithm} = $hit->algorithm();
#    $return->{$count}->{raw_score} = $hit->raw_score();
    $return->{$count}->{score} = $hit->score();
    $return->{$count}->{significance} = $hit->significance();
    $return->{$count}->{bits} = $hit->bits();
    $return->{$count}->{hsps_array} = $hit->hsps();
#  $return->{$count}->{locus} = $hit->locus();
    $return->{$count}->{rank} = $hit->rank();
    print "  Name: $return->{$count}->{hit_name}
   Description: $return->{$count}->{description}
   Score: $return->{$count}->{score}
   Length: $return->{$count}->{length}\n";

    ## Results for each HSP here
    my $hsp_count = 0;
    while (my $hsp = $hit->next_hsp()) {
      $hsp_count++;
      foreach my $k (sort keys %{$hsp}) {
        $return->{$count}->{hsps}->{$hsp_count}->{algorithm} = $hsp->algorithm() if (defined($hsp->algorithm()));
        $return->{$count}->{hsps}->{$hsp_count}->{evalue} = $hsp->evalue() if (defined($hsp->evalue()));
        $return->{$count}->{hsps}->{$hsp_count}->{expect} = $hsp->expect() if (defined($hsp->expect()));
        $return->{$count}->{hsps}->{$hsp_count}->{frac_identical} = $hsp->frac_identical() if (defined($hsp->frac_identical()));
        $return->{$count}->{hsps}->{$hsp_count}->{frac_conserved} = $hsp->frac_conserved() if (defined($hsp->frac_conserved()));
        $return->{$count}->{hsps}->{$hsp_count}->{gaps} = $hsp->gaps() if (defined($hsp->gaps()));
        $return->{$count}->{hsps}->{$hsp_count}->{query_string} = $hsp->query_string() if (defined($hsp->query_string()));
        $return->{$count}->{hsps}->{$hsp_count}->{hit_string} = $hsp->hit_string() if (defined($hsp->hit_string()));
        $return->{$count}->{hsps}->{$hsp_count}->{length_total} = $hsp->length('total') if (defined($hsp->length('total')));
        $return->{$count}->{hsps}->{$hsp_count}->{length_hit} = $hsp->length('hit') if (defined($hsp->length('hit')));
        $return->{$count}->{hsps}->{$hsp_count}->{length_query} = $hsp->length('query') if (defined($hsp->length('query')));
        $return->{$count}->{hsps}->{$hsp_count}->{length_total} = $hsp->length('total') if (defined($hsp->length('total')));
        $return->{$count}->{hsps}->{$hsp_count}->{hsp_length} = $hsp->hsp_length() if (defined($hsp->hsp_length()));
        $return->{$count}->{hsps}->{$hsp_count}->{num_conserved} = $hsp->num_conserved() if (defined($hsp->num_conserved()));
        $return->{$count}->{hsps}->{$hsp_count}->{num_identical} = $hsp->num_identical() if (defined($hsp->num_identical()));
        $return->{$count}->{hsps}->{$hsp_count}->{rank} = $hsp->rank() if (defined($hsp->rank()));
#        $return->{$count}->{hsps}->{$hsp_count}->{seq_query_identical} = $hsp->seq_inds('query','identical') if (defined($hsp->seq_inds('query','identical')));
        $return->{$count}->{hsps}->{$hsp_count}->{score} = $hsp->score() if (defined($hsp->score()));
        $return->{$count}->{hsps}->{$hsp_count}->{bits} = $hsp->bits() if (defined($hsp->bits()));
        $return->{$count}->{hsps}->{$hsp_count}->{range_query} = $hsp->range('query') if (defined($hsp->range('query')));
        $return->{$count}->{hsps}->{$hsp_count}->{range_hit} = $hsp->range('hit') if (defined($hsp->range('hit')));
        $return->{$count}->{hsps}->{$hsp_count}->{range_query} = $hsp->range('query') if (defined($hsp->range('query')));
        $return->{$count}->{hsps}->{$hsp_count}->{percent_identity} = $hsp->percent_identity() if (defined($hsp->percent_identity()));
#        $return->{$count}->{hsps}->{$hsp_count}->{start_query} = $hsp->start('query') if (defined($hsp->start('query')));
#        $return->{$count}->{hsps}->{$hsp_count}->{start_hit} = $hsp->start('hit') if (defined($hsp->start('hit')));
#        $return->{$count}->{hsps}->{$hsp_count}->{end_query} = $hsp->end('query') if (defined($hsp->end('query')));
#        $return->{$count}->{hsps}->{$hsp_count}->{end_hit} = $hsp->end('hit') if (defined($hsp->end('hit')));
#        $return->{$count}->{hsps}->{$hsp_count}->{matches_query} = $hsp->matches('query') if (defined($hsp->matches('query')));
#        $return->{$count}->{hsps}->{$hsp_count}->{matches_hit} = $hsp->matches('hit') if (defined($hsp->matches('hit')));
#        $return->{$count}->{hsps}->{$hsp_count}->{links} = $hsp->links() if (defined($hsp->links()));

#        if (defined($hsp->{$k})) {
#          $return->{$count}->{hsps}->{$hsp_count}->{$k} = $hsp->{$k};
#          print "KEY: $k VALUE: $hsp->{$k}\n";
#        }

#        print "TESTME: $hit->{_hsplength}\n";
      } ## Foreach key in hsp
    }  ## Foreach hsp
  }  ## Foreach hit
  return($return);
}


1;
