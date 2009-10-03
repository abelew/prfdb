package RNAMotif_Search;
use strict;
use lib '.';
use PRFdb;
use Template;
use PRFConfig qw / PRF_Error PRF_Out /;
my $config;
my %slippery_sites = (aaaaaaa => 'A AAA AAA',
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
		      uuuuuuu => 'T TTT TTT',
		      );

sub new {
    my ($class, %arg) = @_;
    my $me = bless {
	config => $arg{config},
    }, $class;
    $config = $me->{config};
    $me->{stem_length} = 6;
    $me->{max_dist_from_slip} = 15;
    return ($me);
}

## Search: Given a cDNA sequence, put all slippery sites into @slipsites
## Put all of those which are followed by a stem into @slipsite_stems
sub Search {
    my $me = shift;
    my $sequence = shift;
    my $orf_start = shift;
    my $seqlength = shift;
    $sequence = uc($sequence);
    my %return = ();
    my @information = split(//, $sequence);
    my $end_trim = 70;
    for my $c (0 .. $#information) {    ## Recurse over every nucleotide
	if ((($c + 1) % 3) == 0) {    ## Check for correct reading frame
	    my $next_seven = qq($information[$c] ${information[$c+1]}${information[$c+2]}${information[$c+3]} ${information[$c+4]}${information[$c+5]}${information[$c+6]}) if (defined($information[$c+6]));
	    ## Check for a slippery site from this position
	    my $slipsite = Slip_p($next_seven) if (defined($next_seven));
	    if ($slipsite) {
		## Then check that a slippery site is in the correct frame
		my $start = $c;
		## The end of the sequence should include 7 more bases so that when
		## We chop off the slippery site we will still have a window of the
		## Desired size.
		my $no_slip_site_start = $start + 7;
		my $end = $c + ($seqlength + 7) -1;
		## One day someone will look at this and wonder
		##  WTF?  However it was done for a reason, to make explicit the 
		##  removal of a single base so that the fasta file
		##  Created by this function will have the correct number of bases
		##  without this -1 the fastafile will have n+1
		##  bases rather than the expected n
		
		my $inf = PRFdb::MakeFasta(\@information, $start, $end);
		my $fh = $inf->{fh};
		my $filename = $inf->{filename};
		my $string = $inf->{string};
		my $no_slip_string = $inf->{no_slipstring};
		my $slipsite = $inf->{slipsite};
		my $start_in_full_sequence = $start + $orf_start + 1;
		my $end_in_full_sequence = $end + $orf_start + 1;
		## These + 1's are required because thus far the start site has been incorrectly calculated.
		my $command = qq"$config->{exe_rnamotif} -context -descr $config->{exe_rnamotif_descriptor} $filename 2>rnamotif.err | $config->{exe_rmprune}";
		print "RNAMotif, running $command\n" if (defined($config->{debug}));
		open(RNAMOT, "$command |") or PRF_Error("RNAMotif_Search:: Search, Unable to run rnamotif: $!", 'rnamotif', '');
		## OPEN RNAMOT in Search
		my $permissable = 0;
		my $nonpermissable = 0;
		my $total = 0;
		my $rnamotif_output = '';
		while (my $line = <RNAMOT>) {
		    next if ($line =~ /^\>/);
		    next if ($line =~ /^ss/);
		    next if ($line =~ /^\#+/);
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
		}    ## End the while loop
		## Close the pipe to rnamotif
		close(RNAMOT);
		## CLOSE RNAMOT in Search
		## Overwrite the fasta file with the same sequence minus the slippery site.
		open(NOSLIP, ">$filename") or die("Could not open $filename $!");
		my $data = ">$slipsite $start_in_full_sequence $end_in_full_sequence
$no_slip_string
";
		print NOSLIP $data;
		close(NOSLIP);
		## This non-slippery-site-containing data will be used throughout the database
		$return{$start_in_full_sequence}{total} = $total;
		$return{$start_in_full_sequence}{filename} = $filename;
		$return{$start_in_full_sequence}{output} = $rnamotif_output;
		$return{$start_in_full_sequence}{permissable} = $permissable;
		$return{$start_in_full_sequence}{filedata} = $data;
		$return{$start_in_full_sequence}{sequence} = $no_slip_string;
	    }    ## End checking for a slippery site
	}    ## End the reading frame check
    }    ## End searching over the sequence
    return (\%return);
}    ## End Search

sub Slip_p {
    my $septet = shift;
    foreach my $slip (keys %slippery_sites) {
	return ($slip) if ($slippery_sites{$slip} eq $septet);
    }
    return (0);
}

sub Descriptor {
    my $template_config = $config;
    $template_config->{PRE_PROCESS} = undef;
    my $template = new Template($template_config);
    my $rnamotif_template_file = qq\$config->{base}/$config->{INCLUDE_PATH}$config->{exe_rnamotif_template}\;
    if (!-r $rnamotif_template_file) {
	die("Need an rnamotif template");
    }
    unless (-r $config->{exe_rnamotif_descriptor}) {
	my $vars = {
	    slip_site_1 => $config->{slip_site_1},
	    slip_site_2 => $config->{slip_site_2},
	    slip_site_3 => $config->{slip_site_3},
	    slip_site_spacer_min => $config->{slip_site_spacer_min},
	    slip_site_spacer_max => $config->{slip_site_spacer_max},
	    stem1_min => $config->{stem1_min},
	    stem1_max => $config->{stem1_max},
	    stem1_bulge => $config->{stem1_bulge},
	    stem1_spacer_min => $config->{stem1_spacer_min},
	    stem1_spacer_max => $config->{stem1_spacer_max},
	    stem2_min => $config->{stem2_min},
	    stem2_max => $config->{stem2_max},
	    stem2_bulge => $config->{stem2_bulge},
	    stem2_loop_min => $config->{stem2_loop_min},
	    stem2_loop_max => $config->{stem2_loop_max},
	    stem2_spacer_min => $config->{stem2_spacer_min},
	    stem2_spacer_max => $config->{stem2_spacer_max},
	};
	$template->process($config->{exe_rnamotif_template}, $vars,
			   $config->{exe_rnamotif_descriptor}) or die $template->error();
    }    ## Unless the rnamotif descriptor file exists.
}

1;
