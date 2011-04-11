package Mixy;
# Time-stamp: <Fri Aug 20 11:34:56 2004 Ashton Trey Belew (abelew@wesleyan.edu)>

sub new {
  my ($class, %args) = @_;
  my $me = bless
	{
	 seqs => $args{seqs},
	 sequences => {},
	 rows => undef,
	 columns => undef,
	 col_freq => {},
	 col_ratio => {},
	 dicol_freq => {},
	 dicol_ratio => {},
	 joint_freq => {},
	 mixy => {},
	}, $class;

  my @seqs = @{$me->{seqs}};
  $me->{rows} = scalar(@seqs);
  my @sequences;
  for my $c (0 .. $#seqs) {
	my @tmp = split(//, $seqs[$c]);
	$me->{columns} = scalar(@tmp);
	$sequences[$c] = \@tmp;
  }
## To find the element of the 2nd column, 7th row (the 1st C) do:
## $me->{sequences}->[1]->[6]
  $me->{sequences} = \@sequences;


  ## Now make row frequencies using @sequences
  my @row_freq = ();
  for my $row (0 .. ($me->{rows} - 1)) {
	$row_freq[$row] = {};
	for my $col (0 .. ($me->{columns} - 1)) {
	  my $nt = $sequences[$row]->[$col];
	  $row_freq[$row]->{$nt}++;
	}
  }
  ## To access the number of As in the 2nd row:
  ## $me->{row_freq}->[1]->{A}
  $me->{row_freq} = \@row_freq;

  ## Now make row ratios using @sequences
  my @row_ratio = ();
  for my $row (0 .. ($me->{rows} - 1)) {
	$row_ratio[$row] = {};
	for my $nt ('A', 'T', 'G', 'C') {
	  next if (!defined $row_freq[$row]->{$nt});
	  $row_ratio[$row]->{$nt} = $row_freq[$row]->{$nt} / $me->{columns};
	}
  }
  ## To access the ratio of As in the first row:
  ## $me->{row_ratio}->[0]->{A}
  $me->{row_ratio} = \@row_ratio;

  ## Now make column frequencies using @sequences
  my @col_freq = ();
  for my $col (0 .. ($me->{columns} - 1)) {
	$col_freq[$col] = {};
	for my $row (0 .. ($me->{rows} - 1)) {
	  my $nt = $sequences[$row]->[$col];
	  $col_freq[$col]->{$nt}++;
	}
  }
  ## To access the number of As in the 2nd column:
  ## $me->{col_freq}->[1]->{A}
  $me->{col_freq} = \@col_freq;

  ## Now make column ratios using
  my @col_ratio = ();
  for my $col (0 .. ($me->{columns} - 1)) {
	$col_ratio[$col] = {};
	for my $nt ('A', 'T', 'G', 'C') {
	  next if (!defined $col_freq[$col]->{$nt});
	  $col_ratio[$col]->{$nt} = $col_freq[$col]->{$nt} / $me->{rows};
	}
  }
  ## To access the ratios of As in the third column:
  ## $me->{col_ratio}->[2]->{A}
  $me->{col_ratio} = \@col_ratio;

  ## Joint distribution fun
  my @joint_freq = ();
  for my $row (0 .. ($me->{rows} - 1)) {
    for my $first_col (0 .. ($me->{columns} - 1)) {
      #    for my $second_col ($first_col .. ($me->{columns} - 1)) {
      for my $second_col (0 .. ($me->{columns} - 1)) {
	foreach my $nt1 (keys %{$col_freq[$first_col]}) {
	  foreach my $nt2 (keys %{$col_freq[$second_col]}) {
	    my $key = $nt1 . $nt2;
	    if ($sequences[$row]->[$first_col] eq $nt1 and $sequences[$row]->[$second_col] eq $nt2) {
	      $joint_freq[$first_col][$second_col]->{$key}++;
	    }
	  } ## For all defined nucleotides
	}  ## For all defined nucleotides
      } ## Iterate over columns
    } ## Iterate over columns
  }  ## Iterate over all rows
  $me->{joint_freq} = \@joint_freq;

  ### Now get the ratios from the frequencies...
  my @joint_ratio = ();
    for my $first_col (0 .. ($me->{columns} - 1)) {
      for my $second_col (0 .. ($me->{columns} - 1)) {
	foreach my $dinuc (keys %{$joint_freq[$first_col]->[$second_col]}) {
	  $joint_ratio[$first_col]->[$second_col]->{$dinuc} = $joint_freq[$first_col]->[$second_col]->{$dinuc} / $me->{rows};
      }
    }
  }
  $me->{joint_ratio} = \@joint_ratio;

  my @mixy = ();
  TOP_LOOP: for my $first_col (0 .. ($me->{columns} - 1)) {
    for my $second_col (0 .. ($me->{columns} - 1)) {
      if ($first_col == $second_col) {
	$mixy[$first_col][$second_col] = 0;
	next TOP_LOOP;
      }
      my $mixy_count = 0;
      foreach my $key (keys %{$joint_ratio[$first_col]->[$second_col]}) {
	my ($fst, $scnd) = split(//, $key);
#	my $first_freq = $col_ratio[$first_col]->{$fst};
#	my $second_freq = $col_ratio[$second_col]->{$scnd};
#	my $joint = $joint_ratio[$first_col]->[$second_col]->{$key};
##	print "TESTING: k: $key 1: $first_freq 2: $second_freq d: $joint\n", <STDIN>;
#	my $ratio = $joint / ($first_freq * $second_freq);
	my $ratio = $joint_ratio[$first_col]->[$second_col]->{$key} / ($col_ratio[$first_col]->{$fst} * $col_ratio[$second_col]->{$scnd});
	my $log2_ratio = log($ratio) / log(2.0);
	my $final = $joint * $log2_ratio;
	$mixy_count = $mixy_count + $final;
      }  ## Each key of AA AT AG AC ...
      $mixy[$first_col][$second_col] = $mixy_count;
#      print "The mixy score at: $first_col, $second_col is $mixy_count\n", <STDIN>;
    }  ## For everything in the second column
  }  ## And the first column
  $me->{mixy} = \@mixy;

  return($me);
}

1;
