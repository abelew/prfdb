#!/usr/bin/perl -w
use strict;
use CGI qw/:standard :html3/;
use CGI::Carp qw(fatalsToBrowser carpout);
use Template;
use lib "lib";
use PRFConfig;
use PRFdb;
use PRF_Blast;
use PRFGraph;
use MoreRandom;
use Bootlace;
umask(0000);
my $config = $PRFConfig::config;
## All configuration information exists here
chdir( $config->{basedir} );
## Change into the home directory of the folder daemon
my $db = new PRFdb;    
## Set up a database configuration
my $cgi = new CGI;
## Start a new CGI object
my $template = new Template($config);
## And a new Template
my $base    = "http://" . $ENV{HTTP_HOST} . $ENV{SCRIPT_NAME};
my $basedir = $base;
$ENV{BLASTDB} = $config->{blastdir};
$basedir =~ s/\/index.cgi.*//g;
my $vars = {
  base         => $base,
  basedir      => $basedir,
  startsearchform => $cgi->startform( -action => "$base/perform_search"),
  searchquery => $cgi->textfield(-name => 'query', -size => 20),
  searchform   => "$base/searchform",
  importform   => "$base/import",
  filterform   => "$base/start_filter",
  downloadform => "$base/download",
  submit       => $cgi->submit,
};

#### MAIN BLOCK OF CODE RIGHT HERE
my $path = $cgi->path_info;
print $cgi->header;
$template->process( 'header.html', $vars ) or print $template->error(), die;
if ( $path eq '/start' or $path eq '' ) {
  ## The default page
  ## Templates read: header.html index.html
  ## Next Steps: (header) searchform filterform download.htm
  Print_Search_Form();
  Print_Index();
} elsif ( $path eq '/download' ) {
  Print_Download();
} elsif ( $path eq '/import' ) {
  Print_Import_Form();
} elsif ( $path eq '/perform_import' ) {
  Perform_Import();
  Print_Import_Form();
} elsif ( $path eq '/landscape' ) {
  Check_Landscape();
} elsif ( $path eq '/searchform' ) {
  ## If you click on the 'search' link
  ## Templates read: searchform.html
  ## Next Steps: /search
  Print_Search_Form();
} elsif ( $path eq '/perform_search' ) {
  ## Perform the search outlined in searchform
  ## Templates Read: multimatch_header.html multimatch_body.html multimatch_footer.html
  ## Next Steps: /refinesearch /browse(see slipsites for accession)
  ## If a single hit is found in the search, then do Browse_Single
  ## Templates Read:
  ## Next Steps:
  Print_Search_Form();
  Perform_Search();
} elsif ( $path eq '/start_filter' ) {
  Start_Filter();
} elsif ( $path eq '/browse' ) {
  ## Look for individual slippery sites in a single accession
  ## Templates Read: sliplist_header.html sliplist.html
  ## Next Steps:
  Print_Search_Form();
  Print_Single_Accession();
} elsif ( $path eq '/filter' ) {
  Perform_Filter();
} elsif ( $path eq '/list_slipsites' ) {
  Print_Sliplist();
} elsif ( $path eq '/detail' ) {
  Print_Detail_Slipsite();
} elsif ( $path eq '/local_blast' ) {
  Print_Search_Form();
  Print_Blast('local');
} elsif ( $path eq '/remote_blast' ) {
  Print_Search_Form();
  Print_Blast('remote');
}
$template->process( 'footer.html', $vars ) or print $template->error(), die;
print $cgi->endform, $cgi->end_html;
exit(0);

sub Print_Index {
  $template->process( 'index.html', $vars ) or print $template->error(), die;
}

sub Print_Download {
  $template->process( 'download.html', $vars ) or print $template->error(), die;
}

sub Print_Search_Form {
  $template->process( 'searchform.html', $vars ) or print $template->error(), die;
}

sub Print_Import_Form {
  $vars->{startform} = $cgi->startform( -action => "$base/perform_import" );
  $vars->{import} = $cgi->textfield( -name => 'import_accession', -size => 20 );
  $template->process( 'import.html', $vars ) or print $template->error(), die;
}

sub Print_Detail_Slipsite {
  my $id        = $cgi->param('id');
  my $accession = $cgi->param('accession');
  my $slipstart = $cgi->param('slipstart');
  $vars->{accession} = $accession;
  $vars->{slipstart} = $slipstart;
  my $detail_stmt = qq(SELECT * FROM mfe WHERE accession = ? AND start = ? ORDER BY seqlength DESC);
  ## id,genome_id,accession,species,algorithm,start,slipsite,seqlength,sequence,output,parsed,parens,mfe,pairs,knotp,barcode,lastupdate
  ## 0  1         2         3       4         5     6        7         8        9      10     11     12  13    14    15      16
  my $info = $db->MySelect( $detail_stmt, [ $accession, $slipstart ] );
  $vars->{species} = $info->[0]->[3];
  $vars->{genome_id} = $info->[0]->[1];
  $vars->{mfe_id} = $info->[0]->[0];

  my $genome_stmt = qq(SELECT genename FROM genome where id = ?);
  my $genome_info = $db->MySelect( $genome_stmt, [ $vars->{genome_id} ] );
  $vars->{genename} = $genome_info->[0]->[0];
  $template->process( "detail_header.html", $vars ) or print $template->error(), die;
  foreach my $structure ( @{$info} ) {
    my $id = $structure->[0];
    my $mfe = $structure->[12];
    my $boot_stmt = qq(SELECT mfe_values, mfe_mean, mfe_sd, mfe_se FROM boot WHERE mfe_id = ?);
    my $boot = $db->MySelect( $boot_stmt, [$id], 'row' );
    my ( $ppcc_values, $filename, $chart, $chartURL, $zscore, $randMean, $randSE, $ppcc, $mfe_mean, $mfe_sd, $mfe_se );

    if (!defined($boot) and $config->{do_boot}) {
	$vars->{accession} = $structure->[2];
	$template->process( 'generate_boot.html', $vars) or print $template->error(), die;

	my $data = ">tmp
$structure->[8]
";
	my $inputfile = $db->Sequence_to_Fasta($data);
	my $boot = new Bootlace(
        genome_id           => $structure->[1],
        nupack_mfe_id       => $structure->[0],
        pknots_mfe_id       => $structure->[0],
        inputfile           => $inputfile,
        species             => $structure->[3],
        accession           => $structure->[2],
        start               => $structure->[5],
        seqlength           => $structure->[7],
        iterations          => $config->{boot_iterations},
        boot_mfe_algorithms => $config->{boot_mfe_algorithms},
        randomizers         => $config->{boot_randomizers},
      );
	my $bootlaces = $boot->Go();
	$db->Put_Boot($bootlaces);
    }

    if ( defined($boot) ) {
      my $mfe_values       = $boot->[0];
      my @mfe_values_array = split( /\s+/, $mfe_values );
      my $acc_slip         = qq/$accession-$slipstart/;
      $chart = new PRFGraph(
        {
	    real_mfe => $mfe,
	    list_data => \@mfe_values_array,
	    accession  => $acc_slip,
	    mfe_id => $id,
        }
      );
      my $ppcc_values = $chart->Get_PPCC();
      $filename = $chart->Picture_Filename( { type => 'distribution', } );
      my $pre_chartURL = $chart->Picture_Filename( { type => 'distribution', url => 'url', } );
      $chartURL = $basedir . '/' . $pre_chartURL;

      if ( !-r $filename ) {
        $chart = $chart->Make_Distribution();
      }

      $mfe_mean = $boot->[1];
      $mfe_sd   = $boot->[2];
      $mfe_se   = $boot->[3];
      $zscore   = sprintf( "%.2f", ( $mfe - $mfe_mean ) / $mfe_sd );
      $randMean = sprintf( "%.1f", $mfe_mean );
      $randSE   = sprintf( "%.1f", $mfe_se );
      $ppcc     = sprintf( "%.4f", $ppcc_values );
    }
    else {  ##Boot is not defined!
      $chart    = "undef";
      $chartURL = "images/no_data.gif";
      $mfe_mean = "undef";
      $mfe_sd   = "undef";
      $mfe_se   = "undef";
      $zscore   = "UNDEF";
      $randMean = "UNDEF";
      $randSE   = "UNDEF";
      $ppcc     = "UNDEF";
    }
    $vars->{algorithm}  = $structure->[4];
    $vars->{slipstart}  = $structure->[5];
    $vars->{slipsite}   = $structure->[6];
    $vars->{seqlength}  = $structure->[7];
    $vars->{pk_input}   = $structure->[8];
    $vars->{pk_input}   =~ tr/atgcu/ATGCU/;
    $vars->{pk_output}  = $structure->[9];
    $vars->{parsed}     = $structure->[10];
    $vars->{parsed}     =~ s/\s+//g;
    $vars->{brackets}   = $structure->[11];
    $vars->{mfe}        = $mfe;
    $vars->{pairs}      = $structure->[13];
    $vars->{knotp}      = $structure->[14];
    $vars->{barcode}    = $structure->[15];
    $vars->{lastupdate} = $structure->[16];

    my $delta = $vars->{seqlength} - length($vars->{parsed});
    $vars->{parsed} .= '.' x $delta;
    $vars->{brackets} .= '.' x $delta;

    $vars->{chart}    = $chart;
    $vars->{chartURL} = $chartURL;
    $vars->{mfe_mean} = $mfe_mean;
    $vars->{mfe_sd}   = $mfe_sd;
    $vars->{mfe_se}   = $mfe_se;
    $vars->{zscore}   = $zscore;
    $vars->{randmean} = $randMean;
    $vars->{randse}   = $randSE;
    $vars->{ppcc}     = $ppcc;

    $vars->{pk_input} = Color_Stems($vars->{pk_input}, $vars->{parsed});
    $vars->{brackets} = Color_Stems($vars->{brackets}, $vars->{parsed});
    $vars->{parsed} = Color_Stems($vars->{parsed}, $vars->{parsed});
    $vars->{species} =~ s/_/ /g;
    $vars->{species} =~ tr/[a-z]/[A-Z]/;

    $template->process( "detail_body.html", $vars ) or print $template->error(), die;
  }    ## End foreach structure in the database
  $template->process( "detail_list_footer.html", $vars );
}

sub Color_Stems {
    my $brackets = shift;
    my $parsed = shift;
    my @br = split(//, $brackets);
    my @pa = split(//, $parsed);
    my $colors = {
	1 => 'blue',
	2 => 'red',
	3 => 'green',
	4 => 'purple',
	5 => 'orange',
	6 => 'brown',
	7 => 'yellow',
    };
    my $bracket_string = '';
    for my $t (0 .. $#pa) {
	if ($pa[$t] eq '.') {
	    $br[$t] = '.' if (!defined($br[$t]));
	    $bracket_string .= $br[$t];
	}
	else {
	    my $append = qq(<font color="$colors->{$pa[$t]}">$br[$t]</font>);
	    $bracket_string .= $append;
	}
    }
    return($bracket_string);
}


sub Print_Single_Accession {
  my $datum = shift;
  my $accession;
  if ( !defined($datum) ) {
    $accession          = $cgi->param('accession');
    $datum              = Get_Accession_Info($accession);
    $datum->{accession} = $accession;
  } else {
    $accession = $datum->{accession};
  }
  $vars->{id}              = $datum->{id};
  $vars->{counter}         = $datum->{counter};
  $vars->{accession}       = $accession;
  $vars->{species}         = $datum->{species};
  $vars->{genename}        = $datum->{genename};
  $vars->{comments}        = $datum->{comment};
  $vars->{slipsite_count}  = $datum->{slipsite_count};
  $vars->{structure_count} = $datum->{structure_count};
  $vars->{pretty_mrna_seq} = Create_Pretty_mRNA($accession);

  # find the number of slippery sites, positions, etc.  ## ALREADY DONE!!
  my $slipsite_information = $db->MySelect("SELECT distinct start, slipsite, count(id) FROM mfe WHERE accession = '$accession' GROUP BY start ORDER BY start");
  $template->process( 'genome.html',          $vars ) or print $template->error(), die;
  $template->process( 'sliplist_header.html', $vars ) or print $template->error(), die;
  my $highlighted_slip;

  while ( my $slip_info = shift( @{$slipsite_information} ) ) {
    $vars->{slipstart}   = $slip_info->[0];
    $vars->{slipseq}     = $slip_info->[1];
    $vars->{pknotscount} = $slip_info->[2];
    $vars->{sig_count} += $vars->{pknotscount};
    $template->process( 'sliplist.html', $vars ) or print $template->error(), die;
  }
  $template->process( 'sliplist_footer.html', $vars ) or print $template->error(), die;
  $template->process( 'mrna_sequence.html',   $vars ) or print $template->error(), die;
}

sub Print_Multiple_Accessions {
  my $data = shift;    ## From Perform_Search by default
  $template->process( 'multimatch_header.html', $vars ) or print $template->error() . "<br>\n";
  foreach my $id ( sort { $data->{$b}->{slipsite_count} <=> $data->{$a}->{slipsite_count} } keys %{$data} ) {
    $vars->{id}              = $data->{$id}->{id};
    $vars->{counter}         = $data->{$id}->{counter};
    $vars->{accession}       = $data->{$id}->{accession};
    $vars->{species}         = $data->{$id}->{species};
    $vars->{genename}        = $data->{$id}->{genename};
    $vars->{comments}        = $data->{$id}->{comment};
    $vars->{slipsite_count}  = $data->{$id}->{slipsite_count};
    $vars->{structure_count} = $data->{$id}->{structure_count};
    $template->process( 'multimatch_body.html', $vars ) or print $template->error(), die;
  }                    ## Foreach every entry in @entries
  $template->process( 'multimatch_footer.html', $vars ) or print $template->error(), die;
}    ## Else there is more than one match for the given search string.

sub Perform_Search {
  my $query = $cgi->param('query');

  #  my $query_statement = qq(SELECT id, accession, species, genename, comment, lastupdate, mrna_seq FROM genome WHERE genename regexp ? OR accession regexp ? OR locus regexp ? OR comment regexp ?);
  my $query_statement = qq(SELECT id, accession, species, genename, comment, lastupdate, mrna_seq FROM genome WHERE (genename regexp '$query' OR accession regexp '$query' OR locus regexp '$query' OR comment regexp '$query'));

  #  my $entries = $db->MySelect($query_statement, [$query, $query, $query, $query]);
  my $entries = $db->MySelect($query_statement);
  my $counter = 0;
  my $data    = ();
  foreach my $entry ( @{$entries} ) {
    $data->{$counter}->{id}        = $entry->[0];
    $data->{$counter}->{accession} = $entry->[1];
    my $accession = $entry->[1];
    $data->{$counter}->{species}    = $entry->[2];
    $data->{$counter}->{genename}   = $entry->[3];
    $data->{$counter}->{comment}    = $entry->[4];
    $data->{$counter}->{lastupdate} = $entry->[5];
    $data->{$counter}->{mrna_seq}   = $entry->[6];
    my $slipsite_structure_count = $db->MySelect( "SELECT count(distinct(start)), count(distinct(id)) FROM mfe WHERE accession = ?", [$accession], 'row' );
    $data->{$counter}->{slipsite_count}  = $slipsite_structure_count->[0];
    $data->{$counter}->{structure_count} = $slipsite_structure_count->[1];
    $counter++;
  }

  if ( scalar( @{$entries} ) == 0 ) {
    $vars->{error} = "No entry was found in the database with genename, accession, locus, nor comment $query<br>\n";
  } elsif ( scalar( @{$entries} ) == 1 ) {
    Print_Single_Accession( $data->{0} );
  }         ## Elsif there is a single match for this search
  else {    ## More than 1 return from the search...
    Print_Multiple_Accessions($data);
  }
}

sub Perform_Import {
  my $accession = $cgi->param('import_accession');
  my $result    = $db->Import_CDS($accession);
  $vars->{import_result} = $result;
  $template->process( 'import_result.html', $vars ) or print $template->error(), die;
}

sub ErrorPage {
  $template->process( 'error.html', $vars ) or print $template->error(), die;
}

sub Start_Filter {
  my $species = $db->MySelect( "SELECT distinct(species) from genome", [], 'flat' );

  #  unshift (@{$species}, 'All');
  $vars->{startform} = $cgi->startform( -action => "$base/filter" );
  $vars->{species} = $cgi->popup_menu(
    -name    => 'species',
    -values  => $species,
    -default => 'saccharomces_cerevisiae',
  );
  $vars->{algorithm} = $cgi->popup_menu(
    -name    => 'algorithm',
    -values  => [ 'pknots', 'nupack' ],
    -default => 'pknots'
  );
  $vars->{filters} = $cgi->checkbox_group(
    -name   => 'filters',
    -values => [ 'pseudoknots only', 'lowest mfe only', 'longest window', 'less than mean mfe', 'less than mean zR' ],
    -defaults => [ 'pseudoknots only', 'lowest mfe only' ],
    -rows     => 3,
    -columns  => 3
  );
  $template->process( 'filterform.html', $vars ) or print $template->error(), die;
}

sub Perform_Filter {
  my $species   = $cgi->param('species');
  my @filters   = $cgi->param('filters');
  my $statement = "SELECT mfe.*, boot.zscore FROM mfe,boot WHERE mfe < 0 AND ";
  if ( $species ne 'All' ) {
    $statement .= "species = '$species' AND ";
  }
  foreach my $filter (@filters) {
    if ( $filter eq 'pseudoknots only' ) {
      $statement .= "knotp = '1' AND ";
    } elsif ( $filter eq 'longest window' ) {
      $statement .= "seqlength = (SELECT max(seqlength) FROM mfe) AND ";
    } elsif ( $filter eq 'less than mean mfe' ) {
      $statement .= "mfe <= (SELECT avg(mfe) FROM mfe WHERE seqlength >= 50) AND ";
    } elsif ( $filter eq 'less than mean zR' ) {
      $statement .= "less than mean zR AND ";
    }
  }
  $statement =~ s/AND $/ORDER BY accession,mfe/g;
  $vars->{select_statement} = $statement;

  my $data;
  my $count     = 1;
  my $HOW_CLOSE = 0.1;
  my $MAX_MFE   = -15.0;

  my $entries = $db->MySelect($statement);
  foreach my $entry ( @{$entries} ) {
    my $id         = $entry->[0];
    my $genome_id  = $entry->[1];
    my $accession  = $entry->[2];
    my $species    = $entry->[3];
    my $algorithm  = $entry->[4];
    my $start      = $entry->[5];
    my $slipsite   = $entry->[6];
    my $seqlength  = $entry->[7];
    my $sequence   = $entry->[8];
    my $output     = $entry->[9];
    my $parsed     = $entry->[10];
    my $parens     = $entry->[11];
    my $mfe        = $entry->[12];
    my $pairs      = $entry->[13];
    my $knotp      = $entry->[14];
    my $barcode    = $entry->[15];
    my $lastupdate = $entry->[16];
    my $zr         = $entry->[17];
    $mfe = sprintf( "%.2f", $mfe );

    if ( defined( $data->{$accession} ) ) {
      $count++;
      $data->{$accession}->{$count}->{mfe}   = $mfe;
      $data->{$accession}->{$count}->{id}    = $id;
      $data->{$accession}->{$count}->{knotp} = $knotp;
    } else {
      $count                                 = 1;
      $data->{$accession}->{$count}->{mfe}   = $mfe;
      $data->{$accession}->{$count}->{id}    = $id;
      $data->{$accession}->{$count}->{knotp} = $knotp;
    }
  }
  my @accessions_to_consider = ();
ACC: foreach my $acc ( sort( keys %{$data} ) ) {
    my %mfe_count  = %{ $data->{$acc} };
    my $lowest_mfe = -1000;
  MFE: foreach my $c ( sort { $mfe_count{$a} <=> $mfe_count{$b} } keys %mfe_count ) {
      my $mfe   = $mfe_count{$c}->{mfe};
      my $knotp = $mfe_count{$c}->{knotp};
      my $id    = $mfe_count{$c}->{id};
      if ( $c == 1 ) {
        $lowest_mfe = $mfe;
        if ( $knotp == 1 ) {
          if ( $mfe >= $MAX_MFE ) {
            $lowest_mfe = -100.0;
            next ACC;
          }
          print "MFE: $mfe ACC: $acc ID: $id\n";
          $lowest_mfe = -1000.0;
          next ACC;
        }
      } elsif ( $mfe <= ( $lowest_mfe + $HOW_CLOSE ) ) {
        if ( $knotp == 1 ) {
          if ( $mfe >= $MAX_MFE ) {
            $lowest_mfe = -100.0;
            next ACC;
          }
          print "MFE: $mfe ACC: $acc ID: $id\n";
          $lowest_mfe = -1000;
          next ACC;
        }
      } else {
        $lowest_mfe = -1000;
        next ACC;
      }
    }    ## End foreach
    $lowest_mfe = -1000;
  }    ## End foreach acc
  $template->process( 'filter.html', $vars ) or print $template->error(), die;
}

sub Print_Sliplist {

}

sub Create_Pretty_mRNA {
  my $accession = shift;
  my $result    = '';
  my $info      = $db->MySelect( "SELECT mrna_seq, orf_start, orf_stop, direction FROM genome WHERE accession = ?", [$accession], 'row' );
  my $mrna_seq  = $info->[0];
  my $orf_start = $info->[1];
  my $orf_stop  = $info->[2];
  my $direction = $info->[3];
  my @seq_array = split( //, $mrna_seq );
  ## First step:  Figure out how many bases we need to pad to get the start codon in the 0 frame.
  ## The orf_start is a 1 indexed integer
  my $pre_padding_bases = $orf_start % 3;
  my $start_padding_bases;
  if ($pre_padding_bases == 0) {
      $start_padding_bases = 0;
  }
  elsif ($pre_padding_bases == 1) {
      $start_padding_bases = 2;
  }
  elsif ($pre_padding_bases == 2) {
      $start_padding_bases = 1;
  }
  else {
      $start_padding_bases = 10;
  }
  my $slipsite_positions = $db->MySelect( "SELECT DISTINCT start FROM mfe WHERE accession = ? ORDER BY start", [$accession], 'flat' );
  ## Each slipsite_position will probably have to have the number of start_padding_bases added to it
  ## Now move all attributes by the number of padding bases, otherwise the non bases will get colored.
  my $corrected_orf_start = $orf_start + $start_padding_bases;
  my $corrected_orf_stop  = $orf_stop + $start_padding_bases;
  my @corrected_slipsites = ();
  for my $d ( 0 .. $#$slipsite_positions ) {
    $corrected_slipsites[$d] = $slipsite_positions->[$d] + $start_padding_bases;    ## Lazy
  }
  ## If you make an array of stems, keep this in mind.

  my $first_pass  = '';
  my @codon_array = ();
  while ( $start_padding_bases >= 0 ) { unshift( @seq_array, '&nbsp;' ), $start_padding_bases--; }
  my $new_seq_length    = $#seq_array;
  my $end_padding_bases = $new_seq_length % 3;
  while ( $end_padding_bases >= 0 ) { push( @seq_array, '&nbsp;' ), $end_padding_bases--; }
  my $codon_string          = '';
  my $minus_one_stop_switch = 'off';
  for my $seq_counter ( 0 .. $#seq_array ) {

    if ( $minus_one_stop_switch eq 'on' ) {
      if ( ( ( $seq_counter % 3 ) == 2 ) and $seq_array[$seq_counter] eq 'T' and ( $seq_array[ $seq_counter + 1 ] eq 'A' ) and ( $seq_array[ $seq_counter + 2 ] eq 'A' ) ) {
        $seq_array[$seq_counter]       = qq(<strong><font color = "Orange">$seq_array[$seq_counter]</font></strong>);
        $seq_array[ $seq_counter + 1 ] = qq(<strong><font color = "Orange">$seq_array[$seq_counter + 1]</font></strong>);
        $seq_array[ $seq_counter + 2 ] = qq(<strong><font color = "Orange">$seq_array[$seq_counter + 2]</font></strong>);
        $minus_one_stop_switch         = 'off';
      } elsif ( ( ( $seq_counter % 3 ) == 2 ) and $seq_array[$seq_counter] eq 'T' and ( $seq_array[ $seq_counter + 1 ] eq 'G' ) and ( $seq_array[ $seq_counter + 2 ] eq 'A' ) ) {
        $seq_array[$seq_counter]       = qq(<strong><font color = "Orange">$seq_array[$seq_counter]</font></strong>);
        $seq_array[ $seq_counter + 1 ] = qq(<strong><font color = "Orange">$seq_array[$seq_counter + 1]</font></strong>);
        $seq_array[ $seq_counter + 2 ] = qq(<strong><font color = "Orange">$seq_array[$seq_counter + 2]</font></strong>);
        $minus_one_stop_switch         = 'off';
      } elsif ( ( ( $seq_counter % 3 ) == 2 ) and $seq_array[$seq_counter] eq 'T' and ( $seq_array[ $seq_counter + 1 ] eq 'A' ) and ( $seq_array[ $seq_counter + 2 ] eq 'G' ) ) {
        $seq_array[$seq_counter]       = qq(<strong><font color = "Orange">$seq_array[$seq_counter]</font></strong>);
        $seq_array[ $seq_counter + 1 ] = qq(<strong><font color = "Orange">$seq_array[$seq_counter + 1]</font></strong>);
        $seq_array[ $seq_counter + 2 ] = qq(<strong><font color = "Orange">$seq_array[$seq_counter + 2]</font></strong>);
        $minus_one_stop_switch         = 'off';
      }
    }    ## If the minus one stop switch is on.

    if ( $seq_counter >= $corrected_orf_start and ( $seq_counter < ( $corrected_orf_start + 3 ) ) ) {
      $seq_array[$seq_counter] = qq(<strong><font color = "Green">$seq_array[$seq_counter]</font></strong>);
    }    ## End if the current bases are a part of the start codon
    if ( $seq_counter >= ( $corrected_orf_stop - 2 ) and ( $seq_counter < ( $corrected_orf_stop + 1 ) ) ) {
      $seq_array[$seq_counter] = qq(<strong><font color = "Red">$seq_array[$seq_counter]</font></strong>);
    }    ## End if the current bases are a part of a stop codon

    for my $c ( 0 .. $#corrected_slipsites ) {
      if ( $seq_counter >= $corrected_slipsites[$c] and $seq_counter < $corrected_slipsites[$c] + 7 ) {
        $seq_array[$seq_counter] = qq(<strong><a href="$base/detail?accession=$accession&slipstart=$slipsite_positions->[$c]"><font color = "Blue">$seq_array[$seq_counter]</font></a></strong>);
        $minus_one_stop_switch = 'on';
      }
    }    ## End foreach slipstart

    if ( ( $seq_counter % 3 ) == 0 ) {
      if ( $seq_counter != 0 ) {
        push( @codon_array, $codon_string );
      }
      $codon_string = '';
    }
    $codon_string = $codon_string . $seq_array[$seq_counter];
  }    ## End the first pass of the sequence array
  my $codon_count = 0;
  foreach my $codon (@codon_array) {
    $codon_count++;
    if ( ( $codon_count % 15 ) == 0 ) {
      $first_pass = join( '', $first_pass, $codon, "<br>\n" );
    } else {
      $first_pass = join( '', $first_pass, $codon, ' ' );
    }
  }

  #  print "<font face=\"Courier\">
  #$first_pass
  #<br></font>\n";
  return ($first_pass);
}

#  my $prefont_ss = qq(<font color="#FF0000"><strong>);
#  my $postfont_ss = qq(</strong></font>);
#  my $resultset = $db->MySelect(qq(SELECT DISTINCT start FROM mfe WHERE accession = '$accession' ORDER BY start));
#  my $slips = ' ';
#  while (my $result = shift(@{$resultset})) {
#    $slips .= " $result->[0] ";
#  }
#  my $slipcounter = 0;
#  my $x = "";
#  my $new_seq = '';
#  for my $c (0 .. $#seq_array) {
#    $new_seq .= $seq_array[1];
#    $x = $c + 2;
#    if ($slips =~ / $x /) {
#      unless ($slipcounter) {
#	$new_seq .= $prefont_ss;
#      }
#      $slipcounter = 8;
#      $slips =~ s/ $x //;
#    }
#    if ($slipcounter > 1) {
#      $slipcounter --;
#    }
#    elsif ($slipcounter == 1) {
#      $slipcounter--;
#      $new_seq .= $postfont_ss;
#    }
#  }
#  $new_seq =~ s/($prefont_ss[ATGC])/$1 /g;
#  $new_seq =~ s/([ATGC]3)/$1 /g;
#  ### Color the -1 Frame stops
#    $new_seq =~ s/T \<\/strong\>\<\/font>(AA|AG|GA)/\<\/strong\>\<\/font\>\<font color =\"#0000FF\"\>\<strong\>T $1\<\/strong\>\<\/font\>/g;
#    $new_seq =~ s/(#FF0000.*?)T (AA|GA|AG)/$1\<font color =\"#0000FF\"\>\<strong\>T $2\<\/strong\>\<\/font\>/g;
#    return $new_seq;
#}

sub Get_Accession_Info {
  my $accession       = shift;
  my $query_statement = qq(SELECT id, species, genename, comment, lastupdate, mrna_seq FROM genome WHERE accession = ?);

  #  my $entries = $db->MySelect($query_statement, [$query, $query, $query, $query]);
  my $entry = $db->MySelect( $query_statement, [$accession], 'row' );
  my $data = {
    id         => $entry->[0],
    species    => $entry->[1],
    genename   => $entry->[2],
    comment    => $entry->[3],
    lastupdate => $entry->[4],
    mrna_seq   => $entry->[5],
  };
  my $slipsite_structure_count = $db->MySelect( "SELECT count(distinct(start)), count(distinct(id)) FROM mfe WHERE accession = ?", [$accession], 'row' );
  $data->{slipsite_count}  = $slipsite_structure_count->[0];
  $data->{structure_count} = $slipsite_structure_count->[1];
  return ($data);
}

sub Print_Blast {
  my $local      = shift;
  my $blast      = new PRF_Blast;
  my $accession  = $cgi->param('accession');
  my $mrna_seq   = $db->MySelect( "SELECT mrna_seq FROM genome WHERE accession = ?", [$accession], 'row' );
  my $sequence   = $mrna_seq->[0];
  my $local_info = $blast->Search( $sequence, $local );

  my ( %hit_names, %accessions, %lengths, %descriptions, %scores, %significances, %bitses );
  my ( %hsps_evalue, %hsps_expect, %hsps_gaps, %hsps_querystring, %hsps_homostring, %hsps_hitstring, %hsps_numid, %hsps_numcon, %hsps_length, %hsps_score );
  my @hits = @{ $local_info->{hits} };
  foreach my $c ( 0 .. $#hits ) {
    $hit_names{$c}     = $local_info->{hits}->[$c]->{hit_name};
    $accessions{$c}    = $local_info->{hits}->[$c]->{accession};
    $lengths{$c}       = $local_info->{hits}->[$c]->{length};
    $descriptions{$c}  = $local_info->{hits}->[$c]->{description};
    $scores{$c}        = $local_info->{hits}->[$c]->{score};
    $hit_names{$c}     = $local_info->{hits}->[$c]->{hit_name};
    $significances{$c} = $local_info->{hits}->[$c]->{significance};
    $bitses{$c}        = $local_info->{hits}->[$c]->{bits};
    my @hsps = @{ $local_info->{hits}->[$c]->{hsps} };

    foreach my $d ( 0 .. $#hsps ) {
      $hsps_evalue{$c}{$d}      = $local_info->{hits}->[$c]->{hsps}->[$d]->{evalue};
      $hsps_expect{$c}{$d}      = $local_info->{hits}->[$c]->{hsps}->[$d]->{expect};
      $hsps_gaps{$c}{$d}        = $local_info->{hits}->[$c]->{hsps}->[$d]->{gaps};
      $hsps_querystring{$c}{$d} = $local_info->{hits}->[$c]->{hsps}->[$d]->{query_string};
      $hsps_homostring{$c}{$d}  = $local_info->{hits}->[$c]->{hsps}->[$d]->{homology_string};
      $hsps_hitstring{$c}{$d}   = $local_info->{hits}->[$c]->{hsps}->[$d]->{hit_string};
      $hsps_numid{$c}{$d}       = $local_info->{hits}->[$c]->{hsps}->[$d]->{num_identical};
      $hsps_numcon{$c}{$d}      = $local_info->{hits}->[$c]->{hsps}->[$d]->{num_conserved};
      $hsps_length{$c}{$d}      = $local_info->{hits}->[$c]->{hsps}->[$d]->{length};
      $hsps_score{$c}{$d}       = $local_info->{hits}->[$c]->{hsps}->[$d]->{score};
    }
  }

  my $vars = {
    query_length     => $local_info->{query_length},
    num_hits         => $local_info->{num_hits},
    hit_names        => \%hit_names,
    accessions       => \%accessions,
    lengths          => \%lengths,
    descriptions     => \%descriptions,
    scores           => \%scores,
    hit_names        => \%hit_names,
    significances    => \%significances,
    bitses           => \%bitses,
    hsps_evalue      => \%hsps_evalue,
    hsps_expect      => \%hsps_expect,
    hsps_gaps        => \%hsps_gaps,
    hsps_querystring => \%hsps_querystring,
    hsps_homostring  => \%hsps_homostring,
    hsps_hitstring   => \%hsps_hitstring,
    hsps_numid       => \%hsps_numid,
    hsps_numcon      => \%hsps_numcon,
    hsps_length      => \%hsps_length,
    hsps_score       => \%hsps_score,
  };
  $template->process( 'blast.html', $vars ) or die $template->error();
}

sub Check_Landscape {
  my $accession = $cgi->param('accession');
  my $pic       = new PRFGraph( {accession => $accession });

  my $filename = $pic->Picture_Filename( { type => 'landscape', });
  if ( !-r $filename ) {
    $pic->Make_Landscape();
  }
  my $url = $pic->Picture_Filename( { type => 'landscape', url => 'url' } );
  $vars->{picture}   = $url;
  $vars->{accession} = $accession;
  $template->process( 'landscape.html', $vars ) or print $template->error(), die;
}
