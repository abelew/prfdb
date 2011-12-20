package RNAMotif;
use strict;
use lib '.';
use PRFdb;
use Template;
use PRFConfig qw / PRF_Out /;
use vars qw($VERSION);
$VERSION='20111119';
my $config;
my %slippery_sites = (aaaaaaa => 'A AAA AAA', aaaaaac => 'A AAA AAC', aaaaaat => 'A AAA AAT',
		      aaauuua => 'A AAT TTA', aaauuuc => 'A AAT TTC', aaauuuu => 'A AAT TTT',
		      cccaaaa => 'C CCA AAA', cccaaac => 'C CCA AAC', cccaaat => 'C CCA AAT',
		      cccuuua => 'C CCT TTA', cccuuuc => 'C CCT TTC', cccuuuu => 'C CCT TTT',
		      gggaaaa => 'G GGA AAA', gggaaac => 'G GGA AAC', gggaaat => 'G GGA AAT',
		      ggguuua => 'G GGT TTA', ggguuuc => 'G GGT TTC', ggguuuu => 'G GGT TTT',
		      uuuaaaa => 'T TTA AAA', uuuaaac => 'T TTA AAC', uuuaaau => 'T TTA AAT',
		      uuuuuua => 'T TTT TTA', uuuuuuc => 'T TTT TTC', uuuuuuu => 'T TTT TTT',
		      ## Theoretically non-allowed slipsites below
		      aaaaaag => 'A AAA AAG', uuuuuug => 'T TTT TTG', aaauuug => 'A AAT TTG',
		      uuuaaag => 'T TTA AAG', gggaaag => 'G GGA AAG', ggguuug => 'G GGT TTG',
		      cccaaag => 'C CCA AAG', cccuuug => 'C CCT TTG',
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
		open(RNAMOT, "$command |") or Callstack(message => "RNAMotif_Search:: Search, Unable to run rnamotif.");
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
		open(NOSLIP, ">$filename") or Callstack(die => 1, message => "Could not open $filename.");
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
    my %args = @_;
    my $config = $args{config};
    my $template_config = $config;
    $template_config->{PRE_PROCESS} = undef;
    my $template = new Template($template_config);
    my $rnamotif_template_file = qq"$ENV{PRFDB_HOME}/descr/$config->{exe_rnamotif_template}";
    if (!-r $rnamotif_template_file) {
	Callstack(die => 1, message => "Need an rnamotif template");
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
			   $config->{exe_rnamotif_descriptor}) or Callstack(die => 1, message =>  $template->error());
    }    ## Unless the rnamotif descriptor file exists.
}


## Generate rnamotif descriptor files from any sequence in the PRFdb
## A descriptor for L-A would look like
## GGAGUGGUAGGUCUUACGAUGCCAGCUGUAAUGCCUACCGGAGAACCUACAGCUGGCG
## 11..11111111.1111...22222221111.11111111.....11...2222222.
# h5(tag='h1_1',minlen=2,maxlen=2,pairfrac=1.0)
# ss(tag='h1_1',minlen=2,maxlen=2)
# h5(tag='h1_2',minlen=8,maxlen=8,pairfrac=1.0)
# ss(tag='h1_2',minlen=1,maxlen=1)
# h5(tag='h1_3',minlen=4,maxlen=4)
# ss(tag='l1',minlen=3,maxlen=3)
# h5(tag='h2_1',minlen=7,maxlen=7)
# h3(tag='h1_3')
# ss(tag='h1_4',minlen=1,maxlen=1)
# h3(tag='h1_2')
# ss(tag='h1_5',minlen=5,maxlen=5)
# h3(tag='h1_1')
# ss(tag='l2', minlen=3,maxlen=3)
# h3(tag='h2_1')
## So will need a few counters: specifically helix 5p (h5), helix 3p (h3), loop (ss)
##  helices will need to have the ability to be split (as per h2_2) and have a counter of bulges
sub Generic_Descriptor {
    my $me = shift;
    my $struct = shift;
    my $parens = shift;
    my $output = undef;
    ## first make an array showing the state of each base, ss_#, h5_#, h3_#
    ## But after this pass the ss_#s will have to be rewritten
    my @str = split(//, $struct);
    my @par = split(//, $parens); ## This can provide an easy way to see 5p vs 3p stems
    my @tokens = ();
    my $ss_counter = 0;
    foreach my $c (0 .. $#str) {
	if ($str[$c] eq '.') {
#	    $tokens[$c] = "ss_$ss_counter";
	    $tokens[$c] = 'ss';
	    $ss_counter++;
	} elsif ($par[$c] eq '[' or $par[$c] eq '{' or
		 $par[$c] eq '(' or $par[$c] eq '<') {
	    $tokens[$c] = "h5_$str[$c]";
	} elsif ($par[$c] eq ']' or $par[$c] eq '}' or
		 $par[$c] eq ')' or $par[$c] eq '>') {
	    $tokens[$c] = "h3_$str[$c]";
	}
    }  ## End initial tokenizing
    ## Now have an array which looks like
    ## (h5_1,h5_1,ss_0,ss_1,h5_1,h5_1,h5_1,ss_2,h5_1,h5_1,ss_3,ss_4,h5_2,h5_2,h5_2,h3_1,h3_1,h3_1...)
    ## Now make a simplified version which will have only 1 instance of each stem type
    ## ([h5_1,2] , [ss,2] , [h5_1,3] , [ss,1]...)
    my @simple_tokens = ();
    my $last_token = undef;  ## $tokens[$c - 1]
    my $curr_token = undef;  ## $tokens[$c]
    my $next_token = undef;  ## $tokens[$c + 1]
    my $int_count = 1;
    my $helix_int_count = 1;
    my %helixes_counter = ();
    foreach my $c (0 .. $#tokens) {
	$last_token = $tokens[$c - 1];
	$curr_token = $tokens[$c];
	if ($c == $#tokens) {
	    $next_token = '0'; 
	} else {
	    $next_token = $tokens[$c + 1];
	}

	if ($curr_token eq $last_token and $curr_token eq $next_token) {
	    $int_count++;
	} elsif ($curr_token eq $next_token) {
	    $int_count++;
	} else {
	    if ($curr_token =~ /^h5/) {
		if (!defined($helixes_counter{$curr_token})) {
		    $helixes_counter{$curr_token}->{final} = 1;
		    $helixes_counter{$curr_token}->{current} = 1;
		} else { $helixes_counter{$curr_token}->{final}++; }
	    }
	    my @current = ($curr_token, $int_count);
	    push(@simple_tokens, \@current);
	    $int_count = 1;
	}
    }
    ## Now we have ((h5_1,2) , (ss,2) , (h5_1,8) , (ss,1) , (h5_1,4) ,
    ## (ss,3) , (h5_2,7) , (h3_1,4) , (ss,1) , (h3_1,8) , (ss,5) ,
    ## (h3_1,2) , (ss,3) , (h3_2,7)) which corresponds nicely to a rnamotif descriptor file.
    my $descriptor_string = "parms\n  wc += gu;\n\ndescr\n";
    my $stem_count = 0;
    foreach my $datum (@simple_tokens) {
	my @tmp = @{$datum};
	my $type = $tmp[0];
	my $len = $tmp[1];
	if ($type eq 'ss') {
	    $stem_count++;
	    $descriptor_string .= "  ss(tag='$stem_count',minlen=$len,maxlen=$len)\n";
	} elsif ($type =~ /^h5/) {
	    $stem_count++;

	    my @tmp = split(/_/, $type);
	    my $stem = $tmp[1];
	    $descriptor_string .= "  h5(tag='h${stem}_${helixes_counter{$type}->{current}}',minlen=$len,maxlen=$len)\n";
	    $helixes_counter{$type}->{current}++;
	} else {
	    my @tmp = split(/_/, $type);
	    my $stem = $tmp[1];
	    $helixes_counter{"h5_$stem"}->{current}--;
	    my $counter = $helixes_counter{"h5_$stem"}->{current};
	    $descriptor_string .= "  h3(tag='h${stem}_${counter}')\n";
	}
    }
    print $descriptor_string;
    return($descriptor_string);
}

sub Make_Descriptor {
    my $me = shift;
    my $str = shift;
    my $par = shift;
    my $descr = $me->Generic_Descriptor($str, $par);
    my $file = PRFdb::MakeTempfile();
    open(IN, ">$file");
    print IN $descr;
    close(IN);
    return($file);
}

sub Generic_Search_All {
    my $me = shift;
    my $str = shift;
    my $par = shift;
    my $species = shift;
    my $descriptor_file = $me->Make_Descriptor($str,$par);
    my $stmt = qq"SELECT accession FROM genome WHERE species = '$species'";
    #print "TESTME $stmt\n";
    my $db = new PRFdb(config => $config);
    my $accessions = $db->MySelect(statement => $stmt,);
    my $count = 0;
    foreach my $accession (@{$accessions}) {
	$count++;
	if (($count % 100) == 0) {
	    print "Done $count\n";
	}
	my $acc = $accession->[0];
	$me->Generic_Search($descriptor_file, $acc);
    }
}

sub Generic_Search {
    my $me = shift;
    my $descriptor = shift;
    my $accession = shift;
    my $stmt = qq"SELECT mrna_seq FROM genome WHERE accession = '$accession'";
    my $db = new PRFdb(config => $config);
    my $sequence = $db->MySelect(statement => $stmt, type => 'single');
    my @information = split(//, $sequence);
    my $inf = PRFdb::MakeFasta(\@information, 0, $#information);
    my $fh = $inf->{fh};
    my $filename = $inf->{filename};
    my $command = qq"$config->{exe_rnamotif} -context -descr $descriptor $filename 2>$filename.err | $config->{exe_rmprune}";
#    my $command = qq"$config->{exe_rnamotif} -context -descr $descriptor $filename";
    print "RNAMotif, running $command\n" if (defined($config->{debug}));
#    print "TESTME: $command\n";
    open(RNAMOT, "$command |") or Callstack(message => "RNAMotif_Search:: Search, Unable to run rnamotif.");
    while (my $line = <RNAMOT>) {
	print $line;
    }
    close(RNAMOT);
#    local $| = 1;
#    system($command);
    PRFdb::RemoveFile($filename);
}

sub Get_Next_Stem {
    my $me = shift;
    my $ref = shift;
    my $count = shift;
    $count++;
    foreach my $c ($count .. $#$ref) {
	if ($ref->[$count] ne '.') {
	    return($ref->[$count]);
	}
    }
    return(undef);
}

1;
