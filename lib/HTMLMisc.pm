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
	}
	elsif ($c == 1) {
	  push(@nums, '&nbsp;');
#	  $num_string .= "&nbsp;";
	}
	elsif ((($c - 1) % 10) == 0) {
	  next;
	}
	else {
	  push(@nums, '&nbsp;');
#	  $num_string .= "&nbsp;";
	}
  }
  my $len = 0;
  foreach my $n (@nums) {
	if ($n eq '&nbsp;') {
	    $len++;
	} 
	elsif ($n > 9) {
	    $len = $len + 2;
	}
	elsif ($n > 99) {
	    $len = $len + 3;
	}
	elsif ($n == 0) {
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
	    }
	    else {
		$minus_string .= '...';
	    }
	    $codon = $char;
	}  ## if on a third base of the -1 frame
	else {
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
	}
	else {
	    my $color_code = $pa[$t] % @colors;
	    next if (!defined($br[$t]));
	    my $append = qq(<font color="$colors[$color_code]">$br[$t]</font>);
	    $bracket_string .= $append;
	}
    }
    return($bracket_string);
}

1;
