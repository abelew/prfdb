#!/usr/local/bin/perl
use warnings;
use strict;
use lib "$ENV{PRFDB_HOME}/lib";
use local::lib "$ENV{PRFDB_HOME}/usr/perl";
use autodie qw":all";
use JSON;
use vars qw"$db $config";
use lib "$ENV{PRFDB_HOME}/lib";
use PerlIO;
my $json = JSON->new->allow_nonref;

## 0 gi|189442844|gb|BC167793.1| 257 36

## 2 things to collect:  The start position of each new orf.
##                       The hit position of each new hit.
## $hits{BC12121212}->{start} = 100;
## $hits{BC12121212}->{end} = 200;
## $hits{BC12121212}->{json} = ({label => "Zero", data => [[0,0],[3,0],[6,10]...] },{label => "Minus one", data => $mone },{label => "Plus one", data => $pone },);
my %hits = ();

#my $input_file = "hs_mgc_mrna.sam";
my $input_file = "pc3_all_fp.fastq.sam";
#my $input_file = "hs.sam";


## Some notes on the sam file format.
## This .sam file was generated with only the aligned hits included.
## Below is one line.  It it tab delimited and has the following fields
# 1.  ID of the read as per the fastq file
# 2.  A bitwise 'FLAG' code, which is hopefully 0.  There are 3 hex bits, it looks to me that if any are set, it is bad for the read.
# 3.  Reference name
# 4.  Start position of the reference. (1 indexed)
# 5.  Map quality (255 is unavailable), it is -10 * log(likelihood wrong), so 0 is bad, starting at >= 5 things look good.
# 6.  CIGAR string... need to look into this some more. 34M: skipped something in reference, soft-clipped, match
#     M/0 : match, I/1 : ref insertion, D/2 : ref deletion,  N/3 : ref skipped, S/4 : soft clipping, H/5 : hard clipped?, P/6 padding, =/7 : seq match, X/8 : sequence mismatch
# 7.  Reference segment name of the next seqment in the template?  * means unset, I presume all will be *
# 8.  Position of the next setment in the template?  I presume all will be 0
# 9.  signed observed template length -- in this case 0 I presume
# 10. segment sequence
# 11. segment sequence quality field
# 12. AS:  alignment score, not sure yet how to evaluate this
# 13. XS:  2nd best alignment score
# 14. XN:  Number of ambiguous bases
# 15. XM:  Number of mismatches
# 16. XO:  Number of gaps opened
# 17. XG:  Gap extensions
# 18. NM:  Number of changes required to make reference and segment identical
# 19. MD:  String representation of the substitution required to make them identical -- so in this case we see that the end was fubared
##WICMT-SOLEXA2:1:1:287:158#0     0       gi|152013070|gb|BC150298.1|     3620    0       34M     *       0       0       CTGAAAACCTTCAACGAGCCCGGCTCTGATTATC     a_P\aba^[_U^ab]Y_T\a`b_\a`a_QDPa\]      AS:i:-17        XS:i:-17        XN:i:0  XM:i:3  XO:i:0  XG:i:0  NM:i:3  MD:Z:29G2C0T0 YT:Z:UU

open(STARTS, "<starts.txt");
while(my $line = <STARTS>) {
    chomp $line;
    my ($accession, $start) = split(/\t/, $line);
    $hits{$accession}->{start} = $start;
    my @start_json = (
		      {label => "Zero", data => []},
		      {label => "Minus one", data => []},
		      {label => "Plus one", data => []}
		      );
    $hits{$accession}->{json} = \@start_json;
}
close(STARTS);


open(IN, "<$input_file");
while (my $line = <IN>) {
    chomp($line);
    my ($read_id, $flag, $refname, $ref_position, $map_quality, $cigar, $ref_seq, $next_position, $obs_temp_len, $segment_seq, $segment_qual, $align_score, $second_score, $num_ambig, $num_mismatch, $num_gaps, $gaps_extended, $num_changes, $ident_trans_string) = split(/\t/, $line);
    my ($gi, $gid, $gb, $accession) = split(/\|/, $refname);
    $accession =~ s/\..+$//g;

    $ref_position = $ref_position + 15;  ### IMPORTANT!! The +15 is added to position the read properly in the context
    ## of the translating ribosome!  The assumption is that the eukaryotic ribosome will protect 15 bases before the A site...

    if (!defined($hits{$accession}->{start})) {
      print "Problem with $accession -- $line\n";
      exit(1);
    }
    my $relative_position = $ref_position - $hits{$accession}->{start};

    my $frame = ($relative_position % 3);
    my $data = $hits{$accession}->{json};
    my $frame_data = $data->[$frame]->{data}; ## Pull the data field from the 0th entry in the json field
    if ($frame_data->[$ref_position]) {
	my $num_hits = $frame_data->[$ref_position]->[1];
	$num_hits++;
	$frame_data->[$ref_position] = [$ref_position, $num_hits];
    }
    else {
	$frame_data->[$ref_position] = [$ref_position, 1];
    }
    $data->[$frame]->{data} = $frame_data;
    $hits{$accession}->{json} = $data;
}
close(IN);

foreach my $acc (%hits) {
    if (ref($acc) eq 'HASH') {
	next;
	print "TESTME: $acc\n"; # Shouldn't get to this line.
    }
    my $filename = qq"json/${acc}.json";
    open(OUT, ">$filename");
    my $data = $hits{$acc}->{json};
    my $out_json = $json->encode($data);
    print OUT $out_json;
    close OUT;
    my $cmd = qq"sed 's/null\,//g' $filename > t ; mv t $filename";
    system($cmd);
}
