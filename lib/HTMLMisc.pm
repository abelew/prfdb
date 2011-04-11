package HTMLMisc;

sub Make_Species {
    my $species = shift;
    $species =~ s/_/ /g;
    $species = ucfirst($species);
    return($species);
}

sub Make_Nums {
  my $sequence = shift;
  my @nums = ('&nbsp;', '&nbsp;', '&nbsp;', '&nbsp;', '&nbsp;', '&nbsp;', 0);
  my $num_string = '';
  my @seq = split(//, $sequence);
  my $c = 0;
  my $count = 10;
  foreach my $char (@seq) {
	$c++;
	if (($c % 10) == 0) {
#	  $num_string .= "$count";
	  push(@nums, $count);
	  $count = $count + 10;
	} elsif ($c == 1) {
	  push(@nums, '&nbsp;');
#	  $num_string .= "&nbsp;";
	} elsif ((($c - 1) % 10) == 0) {
	  next;
	} else {
	  push(@nums, '&nbsp;');
#	  $num_string .= "&nbsp;";
	}
  }
  my $len = 0;
  foreach my $n (@nums) {
	if ($n eq '&nbsp;') {
	    $len++;
	} elsif ($n > 9) {
	    $len = $len + 2;
	} elsif ($n > 99) {
	    $len = $len + 3;
	} elsif ($n == 0) {
	    $len++;
	}
  }
  my $spacer;
  $spacer = scalar(@seq) - $len;
#  $spacer = $len %10;
  $spacer = 0 if ($spacer == 10);

#  print "Len: $len Num spacer: $spacer<br>\n";
  foreach my $c (1 .. $spacer) {
      push(@nums, '.');
  }
  
  foreach my $c (@nums) {
      $num_string .= $c;
  }
  return($num_string);
}


sub Make_Minus {
    my $sequence = shift;
    my $minus_string = '..';
    my @seq = split(//, $sequence);
    shift @seq;
    shift @seq;
    my $c = 2;
    my $codon = '';
    foreach my $char (@seq) {
	$c++;	
	next if ($c == 3);  ## Hack to make it work
	if (($c % 3) == 0) {
	    if ($codon eq 'UAG' or $codon eq 'UAA' or $codon eq 'UGA' or
		$codon eq 'uag' or $codon eq 'uaa' or $codon eq 'uga') {
		$minus_string .= $codon;
	    } else {
		$minus_string .= '...';
	    }
	    $codon = $char;
	## if on a third base of the -1 frame
	} else {
	    $codon .= $char;
	}
    } ## End foreach character of the sequence
    while (length($minus_string) < $vars->{seqlength}) {
	$minus_string .= '.';
    }
    return($minus_string);
}

sub Color_Stems {
    my $brackets = shift;
    my $parsed = shift;
    my $stem_colors = shift;
    my @br = split(//, $brackets);
    my @pa = split(//, $parsed);
    my @colors = split(/ /, $stem_colors);
    my $bracket_string = '';
    for my $t (0 .. $#pa) {
	if ($pa[$t] eq '.') {
	    $br[$t] = '.' if (!defined($br[$t]));
	    $bracket_string .= $br[$t];
	} else {
	    my $color_code = $pa[$t] % @colors;
	    next if (!defined($br[$t]));
	    my $append = qq(<font color="$colors[$color_code]">$br[$t]</font>);
	    $bracket_string .= $append;
	}
    }
    return($bracket_string);
}

sub Create_Pretty_mRNA {
    my %args = @_;
    my $accession = $args{accession};
    my $mrna_seq = $args{mrna_seq};
    my $orf_start = $args{orf_start};
    my $orf_stop = $args{orf_stop};
    my $slipsites = $args{slipsites};
    my $minus_bp = $args{minus_bp};
    my $show_frame = $args{show_frame};
    my $snps = $args{snps};
    my @s = split(//, $mrna_seq);

    use SeqMisc;
    my $seqobj = new SeqMisc(sequence => \@s);
    my $amino_seq = $seqobj->{aaseq};
    my @a = @{$amino_seq};
    my @o = @{$seqobj->{aaminusone}};
    my @t = @{$seqobj->{aaminustwo}};

    ### A filter over the course of the nucleotide array to replace elements which are slipsites etc
    my $startstop_count = 0;
    my $start_position = $orf_start - 1;
    my $stop_position = $orf_stop - 3;
    while ($startstop_count < 3) {
	$s[$start_position] = qq(<font color="Green">$s[$start_position]</font></a>);
	$s[$stop_position] = qq(<font color="Red">$s[$stop_position]</font></a>);
	$start_position++;
	$stop_position++;
	$startstop_count++;
    }

    my $slipcount = 0;
    for my $count (0 .. $#$slipsites) {
	my $slip = $slipsites->[$count];
	my $minus = $minus_bp->[$count];
	my $slipcount = -1;
	while ($slipcount < 6) {
	    my $num_bp = $slip + $slipcount;
	    $s[$num_bp] = qq(<a href="detail.html?accession=$accession&slipstart=$slip" title="View the details for $accession at position $slip"><font color="Blue">$s[$num_bp]</font></a>);
	    $slipcount++;
	}


	my $minuscount = 6;
	while ($minuscount < 9) {
	    my $num = $slip + $minus + $minuscount;
	    $s[$num] = qq(<font color="Orange">$s[$num]</font>);
	    $minuscount++;
	}
    }


    foreach my $snp_position (keys %{$snps}) {
	if ($snps->{$snp_position} !~ /HASH/) {
	    my $snp_end = $snps->{$snp_position};
	    my $link = qq(http://www.ncbi.nlm.nih.gov/sites/entrez?db=snp&cmd=search&term=$snps->{$snp_end}->{cluster_id});
	    $s[$snp_position] = qq(<a class="snp" href=$link title="Position:$snp_position, view dbSNP:$snps->{$snp_end}->{cluster_id} with alleles $snps->{$snp_end}->{alleles} at NCBI" rel="external" target="_blank">$s[$snp_position]);
	    $s[$snps->{$snp_position} - 1] = qq($s[$snps->{$snp_position}]</a>);
	    delete $snps->{$snp_end};
	    delete $snps->{$snp_position};
	} else {
	    my $link = qq"http://www.ncbi.nlm.nih.gov/sites/entrez?db=snp&cmd=search&term=$snps->{$snp_position}->{cluster_id}";
	    $s[$snp_position - 1] = qq(<a class="snp" href=$link title="Position: $snp_position, view dbSNP:$snps->{$snp_position}->{cluster_id} with alleles $snps->{$snp_position}->{alleles} at NCBI" rel="external" target="_blank">$s[$snp_position - 1]</a>);
	    delete($snps->{$snp_position});
	}
    }


    ## Last filter is to shift the frame so it reads evenly on the screen
    my $start_pad = $orf_start - 1;
    my $pad_bp = 2 - ($start_pad % 3);
    my $frame = $start_pad % 3;
    my @tmp;
    if ($frame == 2) {
	@tmp = @a;
	@a = @o;
	@o = @t;
	@t = @tmp;
	unshift(@a, ' '); unshift(@o, ' '); unshift(@t, ' ');
    } elsif ($frame == 1) {
	@tmp = @a;
	@a = @t;
	@t = @tmp;
	unshift(@a, ' '); unshift(@o, ' '); unshift(@t, ' ');
    } else {
	unshift(@a, ' '); unshift(@o, ' '); unshift(@t, ' ');
    }
    
    while ($pad_bp >= 0) {
	unshift(@s, ' ');
	$pad_bp--;
    }
    my $nuc_len = scalar(@s);
    my $aa_len = scalar(@a);
    my $mo_len = scalar(@o);
    my $mt_len = scalar(@t);
    my $leftover = ($nuc_len % 48) + 48;
    while ($leftover > 0) {
	push(@s, '');
	push(@a, ''), push(@a, '') ,push(@a, '');
	push(@o, ''), push(@o, '') ,push(@o, '');
	push(@t, ''), push(@t, '') ,push(@t, '');
	$leftover--;
    }

    my $counter = 0;
    my $counterplus = 53;
    my $increment = 53;
    my $blank = '';
    my ($all, $none, $zero, $one, $two) = '';
    open(ALL,'>', \$all);
    open(ZERO, '>', \$zero);
    open(NONE,'>', \$none);
    open(ONE,'>', \$one);
    open(TWO,'>', \$two);
    while ($s[0] ne '') {
	$counter++;
	$counterplus++;
	if ($show_frame eq 'all') {
	    format ALL  =
@<<<<<   @*@*@* @*@*@* @*@*@*  @*@*@* @*@*@* @*@*@*   @*@*@* @*@*@* @*@*@*  @*@*@* @*@*@* @*@*@*   @*@*@* @*@*@* @*@*@*  @*@*@* @*@*@* @*@*@* @>>>>>>
$counter, shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s),shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), $counterplus
@<<<<<   @   @   @    @   @   @     @   @   @    @   @   @     @   @   @    @   @   @ @<<<<<
$blank,shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),$blank
@<<<<<    @   @   @    @   @   @     @   @   @    @   @   @     @   @   @    @   @   @  @<<<<<
$blank,shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),$blank
@<<<<<     @   @   @    @   @   @     @   @   @    @   @   @     @   @   @    @   @   @  @<<<<<
$blank,shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),$blank
.
        write ALL;
        $counter = $counter + $increment;
        $counterplus = $counterplus + $increment;
      } elsif ($show_frame eq 'zero') {
	    format ZERO  =
@<<<<<   @*@*@* @*@*@* @*@*@*  @*@*@* @*@*@* @*@*@*   @*@*@* @*@*@* @*@*@*  @*@*@* @*@*@* @*@*@*   @*@*@* @*@*@* @*@*@*  @*@*@* @*@*@* @*@*@* @>>>>>>
$counter, shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s),shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), $counterplus
@<<<<<   @   @   @    @   @   @     @   @   @    @   @   @     @   @   @    @   @   @ @<<<<<
$blank,shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),shift(@a),$blank
.
        write ZERO;
        $counter = $counter + $increment;
        $counterplus = $counterplus + $increment;
      } elsif ($show_frame eq 'one') {
        format ONE  =
@<<<<<   @*@*@* @*@*@* @*@*@*  @*@*@* @*@*@* @*@*@*   @*@*@* @*@*@* @*@*@*  @*@*@* @*@*@* @*@*@*   @*@*@* @*@*@* @*@*@*  @*@*@* @*@*@* @*@*@* @>>>>>>
$counter, shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s),shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), $counterplus
@<<<<<    @   @   @    @   @   @     @   @   @    @   @   @     @   @   @    @   @   @  @<<<<<
$blank,shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),shift(@o),$blank
.
        write ONE;
        $counter = $counter + $increment;
        $counterplus = $counterplus + $increment;
      } elsif ($show_frame eq 'two') {
        format TWO  =
@<<<<<   @*@*@* @*@*@* @*@*@*  @*@*@* @*@*@* @*@*@*   @*@*@* @*@*@* @*@*@*  @*@*@* @*@*@* @*@*@*   @*@*@* @*@*@* @*@*@*  @*@*@* @*@*@* @*@*@* @>>>>>>
$counter, shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s),shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), $counterplus
@<<<<<     @   @   @    @   @   @     @   @   @    @   @   @     @   @   @    @   @   @  @<<<<<
$blank,shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),shift(@t),$blank
.
          write TWO;
          $counter = $counter + $increment;
          $counterplus = $counterplus + $increment;
        } else {
          format NONE  =
@<<<<<   @*@*@* @*@*@* @*@*@*  @*@*@* @*@*@* @*@*@*   @*@*@* @*@*@* @*@*@*  @*@*@* @*@*@* @*@*@*   @*@*@* @*@*@* @*@*@*  @*@*@* @*@*@* @*@*@* @>>>>>>
$counter, shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s),shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), shift(@s), $counterplus
.
         write NONE;
         $counter = $counter + $increment;
         $counterplus = $counterplus + $increment;
        }
    }  ## End while

  my $ret;
  if ($show_frame eq 'all') {
      return($all);
#      $ret = $all;
  } elsif ($show_frame eq 'zero') {
      return($zero);
#      $ret = $zero;
  } elsif ($show_frame eq 'one') {
      return($one);
#      $ret = $one;
  } elsif ($show_frame eq 'two') {
      return($two);
#      $ret = $two;
  } else {
      return($none);
#      $ret = $none;
  }

   return($ret);
}


1;
