package RNAMotif_Search;
use strict;
use lib '.';
use PRFdb;
use PRFConfig;

my %slippery_sites = (
					  aaaaaaa => 'A AAA AAA',
					  aaaaaac => 'A AAA AAC',
					  aaaaaat => 'A AAA AAT',
					  aaauuua => 'A AAT TTA',
					  aaauuuc => 'A AAT TTC',
					  aaauuuu => 'A AAT TTT',
					  cccaaaa => 'C CCA AAA',
					  cccaaac => 'C CCA AAC',
					  cccaaat => 'C CCA AAT',
					  cccuuua => 'C CCT TTA',
					  cccuuuc => 'C CCT TTC',
					  cccuuuu => 'C CCT TTT',
					  gggaaaa => 'G GGA AAA',
					  gggaaac => 'G GGA AAC',
					  gggaaag => 'G GGA AAG',
					  gggaaat => 'G GGA AAT',
					  ggguuua => 'G GGT TTA',
					  ggguuuc => 'G GGT TTC',
					  ggguuuu => 'G GGT TTT',
					  uuuaaaa => 'T TTA AAA',
					  uuuaaac => 'T TTA AAC',
					  uuuaaau => 'T TTA AAT',
					  uuuuuua => 'T TTT TTA',
					  uuuuuuc => 'T TTT TTC',
					  uuuuuuu => 'T TTT TTT',);

sub new {
  my ($class, %arg) = @_;
  my $me = bless {}, $class;
  $me->{max_stem_length} = 100;
  $me->{stem_length} = 6;
  $me->{max_dist_from_slip} = 15;

  return($me);
}

## Search: Given a cDNA sequence, put all slippery sites into @slipsites
## Put all of those which are followed by a stem into @slipsite_stems
sub Search {
  my $me = shift;
  my $sequence = shift;
  my $length = shift;
  my $db = new PRFdb();
 my %return = ();
  $sequence =~ s/A+$//g;
  my @information = split(//, $sequence);
  my $end_trim = 70;

#  for my $c (0 .. ($#information - $end_trim)) {  ## Recurse over every nucleotide
  for my $c (0 .. $#information) {  ## Recurse over every nucleotide
    if ((($c + 1) % 3) == 0) {  ## Check for correct reading frame
      my $next_seven = "$information[$c] " . $information[$c + 1] . $information[$c + 2] . "$information[$c + 3] " . $information[$c + 4] . $information[$c + 5] . $information[$c + 6] if (defined($information[$c + 6]));
      ## Check for a slippery site from this position
      my $slipsite = Slip_p($next_seven) if (defined($next_seven));
      if ($slipsite) {  ## Then check that a slippery site is in the correct frame
        my $start = $c;
        my $end = $c + $me->{max_stem_length};
        my $fh = PRFdb::MakeTempfile();
        my $filename = $fh->filename;
        my $string = '';
        ### Move start up 7 nucleotides in the case of a description file which does not specify a slippery site
        #foreach my $c (($start + 7) .. $end) {
        foreach my $c ($start .. $end) {
          $string .= $information[$c] if (defined($information[$c]));
        }
        $string =~ tr/ATGCU/atgcu/ if (defined($string));
        $string =~ tr/t/u/;
        my $data = ">$slipsite $start $end
$string
";
        print $fh $data;
        #print $data;
#		my $command = "/usr/local/bin/rnamotif -descr descr/$slipsite.desc $filename | /usr/local/bin/rmprune";
        my $command = "/usr/local/bin/rnamotif -context -descr descr/trey.desc $filename 2>rnamotif.err | /usr/local/bin/rmprune";
        open(RNAMOT, "$command |") or die("Unable to run rnamotif. $!");
        my $permissable = 0;
        my $nonpermissable = 0;
        my $total = 0;
        my $rnamotif_output = '';
        while(my $line = <RNAMOT>) {
          next if ($line =~ /^\>/);
          next if ($line =~ /^ss/);
          next if ($line =~ /^\#+/);
#		  print "$line<br>\n";
          $rnamotif_output .= $line;
          chomp $line;
          my ($spec, $score, $num1, $num2, $num3, $leader, $slip1, $slip2, $slip3, $spacer, $stem1_5, $loop1, $stem2_5, $loop2, $stem1_3, $loop3, $stem2_3, $footer) = split(/ +/, $line);
          my $full_slip = $slip1 . $slip2 . $slip3;
          $full_slip =~ tr/t/u/;
          if ($leader eq '.' and ($full_slip eq $spec)) {
            $permissable++;
          }
          else {
            $nonpermissable++;
          }
          $total++;
#		  print "$line<br>\n";
        }  ## End the while loop
        $return{$start}{total} = $total;
        $return{$start}{filename} = $filename;
        $return{$start}{output} = $rnamotif_output;
#		}
      } ## End checking for a slippery site
    }  ## End the reading frame check
  }  ## End searching over the sequence
  return(\%return);
}  ## End Search

sub Slip_p {
  my $septet = shift;
  foreach my $slip (keys %slippery_sites) {
    return($slip) if ($slippery_sites{$slip} eq $septet);
  }
  return(0);
}

1;
