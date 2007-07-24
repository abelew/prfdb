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
$ENV{HTTP_HOST} = 'funkytown' if (!defined($ENV{HTTP_HOST}));
$ENV{SCRIPT_NAME} = 'index.cgi' if (!defined($ENV{SCRIPT_NAME}));
umask(0000);
our $config = $PRFConfig::config;
## All configuration information exists here
chdir( $config->{base} );
## Change into the home directory of the folder daemon
our $db = new PRFdb;    
## Set up a database configuration
our $cgi = new CGI;
## Start a new CGI object
our $template = new Template($config);
## And a new Template
our $base    = "http://" . $ENV{HTTP_HOST} . $ENV{SCRIPT_NAME};
our $basedir = $base;
$ENV{BLASTDB} = $config->{blastdir};
$basedir =~ s/\/index.cgi.*//g;
our $vars = {
  base         => $base,
  basedir      => $basedir,
  startsearchform => $cgi->startform( -action => "$base/perform_search"),
  searchquery => $cgi->textfield(-name => 'query', -size => 20),
  searchform   => "$base/searchform",
  endsearchform => $cgi->endform(),
  importform   => "$base/import",
  filterform   => "$base/start_filter",
  downloadform => "$base/download",
  cloudform => "$base/cloudform",
  helpform => "$base/help",
  seqlength => $config->{seqlength},
  submit       => $cgi->submit,
};

MAIN();

sub MAIN {
#### MAIN BLOCK OF CODE RIGHT HERE
    my $path = $cgi->path_info;
    if ($path eq '/download_sequence') {
	Download_Sequence($cgi->param('accession'));
	exit(0);
    }
    elsif ($path eq '/download_bpseq') {
	Download_Bpseq($cgi->param('mfeid'));
	exit(0);
    }
    elsif ($path eq '/download_subseq') {
	Download_Subsequence($cgi->param('mfeid'));
	exit(0);
    }
    elsif ($path eq '/download_parens') {
	Download_Parens($cgi->param('mfeid'));
	exit(0);
    }
    elsif ($path eq '/download_parsed') {
	Download_Parsed($cgi->param('mfeid'));
	exit(0);
    }

    print $cgi->header;
    $template->process( 'header.html', $vars ) or
	Print_Template_Error($template), die;
    if ( $path eq '/start' or $path eq '' ) {
	Print_Index();
    } elsif ($path eq '/help') {
	$template->process('help.html', $vars) or
	    Print_Template_Error($template), die;
    } elsif ($path =~ /^\/help_(\w+$)/) {
	my $helpfile = qq(help_${1}.html);
	$template->process($helpfile, $vars) or
	    Print_Template_Error($template), die;
    } elsif ($path eq '/mfe_z') {
	Print_MFE_Z();
    } elsif ( $path eq '/download' ) {
	Print_Download();
    } elsif ( $path eq '/import' ) {
	Print_Import_Form();
    } elsif ( $path eq '/perform_import' ) {
	Perform_Import();
	Print_Import_Form();
    } elsif ( $path eq '/landscape' ) {
	Check_Landscape();
    } elsif ($path eq '/cloudform') {
	Print_Cloudform();
    } elsif ( $path eq '/cloud' ) {
	Cloud();
    } elsif ( $path eq '/searchform' ) {
	Print_Search_Form();
    } elsif ($path eq '/blast_search') {
	my $input_sequence = $cgi->param('blastsearch');
	Print_Blast('local',$input_sequence);
    } elsif ( $path eq '/perform_search') {
	Perform_Search();
    } elsif ( $path eq '/start_filter' ) {
	Start_Filter();
    } elsif ($path eq '/second_filter') {
	Perform_Second_Filter();
    } elsif ( $path eq '/third_filter') {
	Perform_Third_Filter();
    } elsif ( $path eq '/browse' ) {
	Print_Single_Accession();
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
    $template->process( 'footer.html', $vars ) or
	Print_Template_Error($template), die;
    print $cgi->endform, $cgi->end_html;
    exit(0);
}

sub Print_Index {
    my %species_info = ();
    foreach my $spec (@{$config->{index_species}}) {
	$species_info{$spec}{count} = $db->MySelect({
	    statement => "SELECT count(id) FROM mfe WHERE species = '$spec'",
	    type => 'single'});
	my $nicename = $spec;
	$nicename =~ s/_/ /g;
	$nicename = ucfirst($nicename);
	$species_info{$spec}{nicename} = $nicename;	
    }
    my $lastupdate_statement = qq(SELECT species, lastupdate, accession FROM mfe );
    if (defined($config->{species_limit})) {
	$lastupdate_statement .= qq(WHERE species = '$config->{species_limit}' );
    }
    $lastupdate_statement .= qq(ORDER BY lastupdate DESC LIMIT 1);
    my $lastupdate = $db->MySelect({
	statement => $lastupdate_statement,
	type => 'row'});

    $vars->{species_info} = \%species_info;
    $vars->{last_species} = $lastupdate->[0];
    $vars->{last_species} = ucfirst($vars->{last_species});
    $vars->{last_species} =~ s/_/ /g;
    $vars->{lastupdate} = $lastupdate->[1];
    $vars->{last_accession} = $lastupdate->[2];
    $template->process( 'index.html', $vars ) or
	Print_Template_Error($template), die;
}

sub Print_Download {
  $template->process( 'download.html', $vars ) or
      Print_Template_Error($template), die;
}

sub Print_Search_Form {
    $vars->{blast_startform} = $cgi->startform( -action => "$base/blast_search" );
    $vars->{blastsearch} = $cgi->textarea( -name => 'blastsearch', -rows => 12, -columns => 80, );
    $vars->{blast_submit} = $cgi->submit( -name => 'blastsearch', -value => 'Perform Blast Search');
    $template->process( 'searchform.html', $vars ) or
	Print_Template_Error($template), die;
}

sub Print_Import_Form {
    $vars->{startform} = $cgi->startform( -action => "$base/perform_import" );
    $vars->{import} = $cgi->textfield( -name => 'import_accession', -size => 20 );
    $template->process( 'import.html', $vars ) or
	Print_Template_Error($template), die;
}

sub Print_Cloudform {
    $vars->{newstartform} = $cgi->startform( -action => "$base/cloud" );
    $vars->{slipsites} = $cgi->popup_menu(-name => 'slipsites',
					  -default => 'all',
					  -values => ['all',
						      'AAAAAAA', 'AAAAAAU', 'AAAAAAC',
						      'AAAUUUA', 'AAAUUUU', 'AAAUUUC',
						      'UUUAAAA', 'UUUAAAU', 'UUUAAAC',
						      'UUUUUUA', 'UUUUUUU', 'UUUUUUC',
						      'CCCAAAA', 'CCCAAAU', 'CCCAAAC',
						      'CCCUUUA', 'CCCUUUU', 'CCCUUUC',
						      'GGGAAAA', 'GGGAAAU', 'GGGAAAC',
						      'GGGUUUA', 'GGGUUUU', 'GGGUUUC',]);
    $vars->{cloud_filters} = $cgi->checkbox_group(
						  -name => 'cloud_filters',
#						  -values => ['pseudoknots only', 'coding sequence only'],);
						  -values => ['pseudoknots only',],);
    if (defined($config->{species_limit})) {
	$vars->{species} = $cgi->popup_menu(-name => 'species',
					    -default => [$config->{species_limit}],
					    -values => [$config->{species_limit}],);
    }
    else {
	$vars->{species} = $cgi->popup_menu( -name => 'species',
					     -default => ['homo_sapiens'],
					     -values => ['saccharomyces_cerevisiae', 'homo_sapiens', 'mus_musculus','all']);
    }
    $template->process( 'cloudform.html', $vars ) or
	Print_Template_Error($template), die;
}

sub Print_MFE_Z {
    my $mfe = $cgi->param('mfe');
    my $z = $cgi->param('z');
    my $species = $cgi->param('species');
    my $seqlength = $cgi->param('seqlength');
    my $pknot = $cgi->param('pknot');
    my $slipsites = $cgi->param('slipsite');
    $mfe = sprintf('%.0f', $mfe);
    $z = sprintf('%.0f', $z);
    my $mfe_plus_factor;
    my $mfe_minus_factor;
    if ($species eq 'homo_sapiens') {
	$mfe_plus_factor = 1.0;
	$mfe_minus_factor = 1.0;
    }
    elsif ($species eq 'mus_musculus') {
	$mfe_plus_factor = 0.8;
	$mfe_minus_factor = 0.8;
    }
    else {
	$mfe_plus_factor = 1.0;
	$mfe_minus_factor = 1.0;
    }
    my $mfe_plus = $mfe + $mfe_plus_factor;
    my $mfe_minus = $mfe - $mfe_minus_factor;
    my $z_plus = $z + 0.4;
    my $z_minus = $z - 0.4;
    my ($stmt, $stuff);
    
    if (defined($slipsites) and $species eq 'all' and defined($pknot)) {
	$stmt = qq(SELECT distinct mfe.accession, mfe.start FROM mfe, boot WHERE mfe.seqlength = $seqlength AND mfe.mfe >= $mfe_minus AND mfe.mfe <= $mfe_plus AND boot.zscore >= $z_minus AND boot.zscore <= $z_minus AND mfe.knotp = '1' AND mfe.id = boot.mfe_id AND mfe.slipsite = '$slipsites' ORDER BY mfe.accession,mfe.start);
    }
    elsif (defined($slipsites) and $species eq 'all' and !defined($pknot)) {
	$stmt = qq(SELECT distinct mfe.accession, mfe.start FROM mfe, boot WHERE mfe.seqlength = $seqlength AND mfe.mfe >= $mfe_minus AND mfe.mfe <= $mfe_plus AND boot.zscore >= $z_minus AND boot.zscore <= $z_plus AND mfe.id = boot.mfe_id AND mfe.slipsite = '$slipsites' ORDER BY mfe.accession,mfe.start);
    }
    elsif (defined($slipsites) and $species ne 'all' and defined($pknot)) {
	$stmt = qq(SELECT distinct mfe.accession, mfe.start FROM mfe, boot WHERE mfe.species = '$species' AND mfe.seqlength = $seqlength AND mfe.mfe >= $mfe_minus AND mfe.mfe <= $mfe_plus AND boot.zscore >= $z_minus AND boot.zscore <= $z_plus AND mfe.knotp = '1' AND mfe.id = boot.mfe_id AND mfe.slipsite = '$slipsites' ORDER BY mfe.accession,mfe.start);
    }
    elsif (defined($slipsites) and $species ne 'all' and !defined($pknot)) {
	$stmt = qq(SELECT distinct mfe.accession, mfe.start FROM mfe, boot WHERE mfe.species = '$species' AND mfe.seqlength = $seqlength AND mfe.mfe >= $mfe_minus AND mfe.mfe <= $mfe_plus AND boot.zscore >= $z_minus AND boot.zscore <= $z_plus AND mfe.id = boot.mfe_id AND mfe.slipsite = '$slipsites' ORDER BY mfe.accession,mfe.start);
    }

    elsif (!defined($slipsites) and $species eq 'all' and defined($pknot)) {
	$stmt = qq(SELECT distinct mfe.accession, mfe.start FROM mfe, boot WHERE mfe.seqlength = $seqlength AND mfe.mfe >= $mfe_minus AND mfe.mfe <= $mfe_plus AND boot.zscore >= $z_minus AND boot.zscore <= $z_plus AND mfe.knotp = '1' AND mfe.id = boot.mfe_id ORDER BY mfe.accession,mfe.start);
    }
    elsif (!defined($slipsites) and $species eq 'all' and !defined($pknot)) {
	$stmt = qq(SELECT distinct mfe.accession, mfe.start FROM mfe, boot WHERE mfe.seqlength = $seqlength AND mfe.mfe >= $mfe_minus AND mfe.mfe <= $mfe_plus AND boot.zscore >= $z_minus AND boot.zscore <= $z_plus AND mfe.id = boot.mfe_id ORDER BY mfe.accession,mfe.start);
    }
    elsif (!defined($slipsites) and $species ne 'all' and defined($pknot)) {
	$stmt = qq(SELECT distinct mfe.accession, mfe.start FROM mfe, boot WHERE mfe.species = '$species' AND mfe.seqlength = $seqlength AND mfe.mfe >= $mfe_minus AND mfe.mfe <= $mfe_plus AND boot.zscore >= $z_minus AND boot.zscore <= $z_plus AND mfe.knotp = '1' AND mfe.id = boot.mfe_id ORDER BY mfe.accession,mfe.start);
    }
    elsif (!defined($slipsites) and $species ne 'all' and !defined($pknot)) {
	$stmt = qq(SELECT distinct mfe.accession, mfe.start FROM mfe, boot WHERE mfe.species = '$species' AND mfe.seqlength = $seqlength AND mfe.mfe >= $mfe_minus AND mfe.mfe <= $mfe_plus AND boot.zscore >= $z_minus AND boot.zscore <= $z_plus AND mfe.id = boot.mfe_id ORDER BY mfe.accession,mfe.start);
    }
    else {
	print "WTF<br>\n";
	$stmt = qq(WTF);
    }
    $stuff = $db->MySelect({statement => $stmt, });
    $vars->{mfe} = $mfe;
    $vars->{mfe_plus} = $mfe_plus;
    $vars->{mfe_minus} = $mfe_minus;
    $vars->{z} = $z;
    $vars->{z_plus} = $z_plus;
    $vars->{z_minus} = $z_minus;
    $vars->{species} = $species;
    $template->process('mfe_z_header.html', $vars) or
	Print_Template_Error($template), die;
    foreach my $datum (@{$stuff}) {
	my $accession = $datum->[0];
	my $start = $datum->[1];
	my $gene_stmt = qq(SELECT genename,comment FROM genome WHERE accession = ?);
	my $g = $db->MySelect({
	    statement => $gene_stmt,
	    vars => [$accession],
	    type => 'row'});
	my $genename = $g->[0];
	my $comments = $g->[1];
	$vars->{accession} = $accession;
	$vars->{start} = $start;
	$vars->{genename} = $genename;
	$vars->{comments} = $comments;
	if ($vars->{accession} =~ /^SGDID/) {
	    $vars->{short_accession} = $vars->{accession};
	    $vars->{short_accession} =~ s/^SGDID\://g;
	}
        elsif ($vars->{accession} =~ /^BC/) {
	    $vars->{short_accession} = undef;
            $vars->{genbank_accession} = $vars->{accession};
        }
	$template->process('mfe_z_body.html', $vars) or
	    Print_Template_Error($template), die;

    }
}

sub Print_Detail_Slipsite {
  my $id        = $cgi->param('id');
  my $accession = $cgi->param('accession');
  my $slipstart = $cgi->param('slipstart');
  $vars->{accession} = $accession;
  $vars->{slipstart} = $slipstart;
  my $detail_stmt = qq(SELECT * FROM mfe WHERE accession = ? AND start = ? ORDER BY seqlength DESC,algorithm DESC);
  my $info = $db->MySelect({
      statement => $detail_stmt,
      vars => [ $accession, $slipstart ] });
  ## id,genome_id,accession,species,algorithm,start,slipsite,seqlength,sequence,output,parsed,parens,mfe,pairs,knotp,barcode,lastupdate
  ## 0  1         2         3       4         5     6        7         8        9      10     11     12  13    14    15      16

  $vars->{species} = $info->[0]->[3];
  $vars->{genome_id} = $info->[0]->[1];

  my $genome_stmt = qq(SELECT genename FROM genome where id = ?);
  my $genome_info = $db->MySelect({
      statement =>$genome_stmt,
      vars => [ $vars->{genome_id} ],
				  });
  $vars->{genename} = $genome_info->[0]->[0];
  $template->process( "detail_header.html", $vars ) or
      Print_Template_Error($template), die;
  foreach my $structure ( @{$info} ) {
    my $id = $structure->[0];
    my $mfe = $structure->[12];
    $vars->{mfe_id} = $structure->[0];
#    my $boot_stmt = qq(SELECT mfe_values, mfe_mean, mfe_sd, mfe_se, zscore FROM boot WHERE mfe_id = ?);
    my $boot_stmt = qq(SELECT mfe_values, mfe_mean, mfe_sd, mfe_se, zscore FROM boot WHERE mfe_id = '$id');
    my $boot = $db->MySelect({
	statement => $boot_stmt,
#	vars => [$id],
	type => 'row'});
    my ( $ppcc_values, $filename, $chart, $chartURL, $zscore, $randMean, $randSE, $ppcc, $mfe_mean, $mfe_sd, $mfe_se, $boot_db );

    if (!defined($boot) and $config->{do_boot} == 2) {
	## Add it to the webqueue
	$db->Set_Queue($vars->{genome_id}, 'webqueue');
    }
    elsif (!defined($boot) and $config->{do_boot} == 1) {
	$vars->{accession} = $structure->[2];
	$template->process( 'generate_boot.html', $vars) or
	    Print_Template_Error($template), die;

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
	chdir($config->{base});
    }

    my $acc_slip         = qq/$accession-$slipstart/;
    my $feynman_pic = new PRFGraph({mfe_id => $id, accession => $accession});
    my $pre_feynman_url = $feynman_pic->Picture_Filename({type=> 'feynman', url => 'url',});
    my $feynman_url = $basedir . '/' . $pre_feynman_url;
    $feynman_url =~ s/\.png/\.svg/g;
#    ## Feynman
    my $feynman_output_filename = $feynman_pic->Picture_Filename( {type => 'feynman', });
    $feynman_output_filename =~ s/\.png/\.svg/g;
    my $feynman_dimensions = {};
    if (!-r $feynman_output_filename) {
	$feynman_dimensions = $feynman_pic->Make_Feynman();
    }
    else {
	$feynman_dimensions = Retarded($feynman_output_filename);
    }
## This requires an X server connection -- perhaps I can solve this
## By logging in at boot time as 'website' and starting a null Xserver on
## :6 and then setting env{display} to :6
    if ( defined($boot) ) {
      my $mfe_values       = $boot->[0];
      my @mfe_values_array = split( /\s+/, $mfe_values );
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
      $boot_db  = $boot->[4];
      if ($mfe_sd == 0) { 
        $zscore = 0;
      }
      else {
        $zscore   = sprintf( "%.2f", ( $mfe - $mfe_mean ) / $mfe_sd );
      }
      $randMean = sprintf( "%.1f", $mfe_mean );
      $randSE   = sprintf( "%.1f", $mfe_se );
      $ppcc     = sprintf( "%.4f", $ppcc_values );
    }
    else {  ##Boot is not defined!
      $chart    = "undef";
      $chartURL = qq($basedir/html/no_data.gif);
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
    # $vars->{lastupdate} = $structure->[16];

    my $delta = $vars->{seqlength} - length($vars->{parsed});
    $vars->{parsed} .= '.' x $delta;
    $vars->{brackets} .= '.' x $delta;

    $vars->{chart}    = $chart;
    $vars->{chartURL} = $chartURL;
    $vars->{feynman}  = $feynman_pic;
    $vars->{feynman_url} = $feynman_url;

    $vars->{mfe_mean} = $mfe_mean;
    $vars->{mfe_sd}   = $mfe_sd;
    $vars->{mfe_se}   = $mfe_se;
    $vars->{zscore}   = $zscore;
    $vars->{randmean} = $randMean;
    $vars->{randse}   = $randSE;
    $vars->{ppcc}     = $ppcc;
    $vars->{boot_db}  = $boot_db;

    $vars->{numbers} = Make_Nums($vars->{pk_input});
    $vars->{pk_input} = Color_Stems($vars->{pk_input}, $vars->{parsed});
    $vars->{brackets} = Color_Stems($vars->{brackets}, $vars->{parsed});
    $vars->{parsed} = Color_Stems($vars->{parsed}, $vars->{parsed});
    $vars->{species} =~ s/_/ /g;
    $vars->{species} = ucfirst($vars->{species});

    $vars->{feynman_height} = $feynman_dimensions->{height};
    $vars->{feynman_height} += 1;
    $vars->{feynman_width} = $feynman_dimensions->{width};
    $vars->{feynman_width} += 1;

    $template->process( "detail_body.html", $vars ) or
	Print_Template_Error($template), die;
  }    ## End foreach structure in the database
  $template->process( "detail_list_footer.html", $vars );
}

sub Color_Stems {
    my $brackets = shift;
    my $parsed = shift;
    my @br = split(//, $brackets);
    my @pa = split(//, $parsed);
    my @colors = split(/ /, $config->{stem_colors});
    my $bracket_string = '';
    for my $t (0 .. $#pa) {
	if ($pa[$t] eq '.') {
	    $br[$t] = '.' if (!defined($br[$t]));
	    $bracket_string .= $br[$t];
	}
	else {
	    my $color_code = $pa[$t] % @colors;
	    my $append = qq(<font color="$colors[$color_code]">$br[$t]</font>);
	    $bracket_string .= $append;
	}
    }
    return($bracket_string);
}

sub Make_Nums {
    my $sequence = shift;
    my $num_string = '';
    my @seq = split(//, $sequence);
    my $c = 0;
    my $count = 10;
    foreach my $char (@seq) {
	$c++;
	if (($c % 10) == 0) {
	    $num_string .= "$count";
	    $count = $count + 10;
	}
	elsif ($c == 1) {
	    $num_string .= "&nbsp;";
	}
	elsif ((($c - 1) % 10) == 0) {
	    next;
	}
	else {
	    $num_string .= "&nbsp;";
	}
    }
    return($num_string);
}

sub Print_Single_Accession {
  my $datum = shift;
  my $fun = ref($datum);
  my $accession;
  if ( !defined($datum) ) {
      $accession          = $cgi->param('accession');
      $datum              = Get_Accession_Info($accession);
      $datum->{accession} = $accession;
  } 
  else {
      $accession = $datum->{accession};
  }
  $vars->{id}              = $datum->{id};
  $vars->{counter}         = $datum->{counter};
  $vars->{accession}       = $accession;
  if ($vars->{accession} =~ /^SGDID/) {
      $vars->{short_accession} = $vars->{accession};
      $vars->{short_accession} =~ s/^SGDID\://g;
  }
  elsif ($vars->{accession} =~ /^BC/) {
      $vars->{short_accession} = undef;
      $vars->{genbank_accession} = $vars->{accession};
  }
  $vars->{species}         = $datum->{species};
  $vars->{species} =~ s/_/ /g;
  $vars->{species} = ucfirst($vars->{species});
  $vars->{genename}        = $datum->{genename};
  $vars->{comments}        = $datum->{comment};
  $vars->{orf_start}       = $datum->{orf_start};
  $vars->{orf_stop}        = $datum->{orf_stop};
  $vars->{slipsite_count}  = $datum->{slipsite_count};
  $vars->{structure_count} = $datum->{structure_count};
  $vars->{pretty_mrna_seq} = Create_Pretty_mRNA($accession);

  my $slipsite_information_stmt;
  if ($config->{do_utr} == 1) {
      $slipsite_information_stmt = qq/SELECT distinct start, slipsite, count(id) FROM mfe WHERE accession = ? GROUP BY start ORDER BY start/;
  }
  else {
      $slipsite_information_stmt = qq/SELECT distinct start, slipsite, count(id) FROM mfe WHERE accession = ? AND start < (SELECT orf_stop FROM genome WHERE accession = ?) GROUP BY start ORDER BY start/;
  }
  my $slipsite_information = $db->MySelect({
      statement => $slipsite_information_stmt, 
      vars => [$accession, $accession], });
  $template->process( 'genome.html',          $vars ) or
      Print_Template_Error($template), die;
  $template->process( 'sliplist_header.html', $vars ) or
      Print_Template_Error($template), die;

  my $num_stops_printed = 0;
  my $num_starts_printed = 0;
  while ( my $slip_info = shift( @{$slipsite_information} ) ) {
    $vars->{slipstart}   = $slip_info->[0];
    $vars->{slipseq}     = $slip_info->[1];
    $vars->{pknotscount} = $slip_info->[2];
    $vars->{sig_count} += $vars->{pknotscount};
    if ($vars->{orf_start} < $vars->{slipstart} and $num_starts_printed == 0) {
	$num_starts_printed++;
	$template->process( 'sliplist_start_codon.html', $vars ) or 
	    Print_Template_Error($template), die;
    }
    if ($vars->{orf_stop} <= $vars->{slipstart} and $num_stops_printed == 0) {
	$num_stops_printed++;
	$template->process( 'sliplist_stop_codon.html', $vars ) or
	    Print_Template_Error($template), die;
    }
    $template->process( 'sliplist.html', $vars ) or
	Print_Template_Error($template), die;
  }
  $template->process( 'sliplist_start_codon.html', $vars ) if ($num_starts_printed == 0);
  $template->process( 'sliplist_stop_codon.html', $vars ) if ($num_stops_printed == 0);
  $template->process( 'sliplist_footer.html', $vars ) or
      Print_Template_Error($template), die;
  $template->process( 'mrna_sequence.html',   $vars ) or
      Print_Template_Error($template), die;
}

sub Print_Multiple_Accessions {
  my $data = shift;    ## From Perform_Search by default
  $template->process( 'multimatch_header.html', $vars ) or
      Print_Template_Error($template), die;
  foreach my $id ( sort { $data->{$b}->{slipsite_count} <=> $data->{$a}->{slipsite_count} } keys %{$data} ) {      
    $vars->{id}              = $data->{$id}->{id};
    $vars->{counter}         = $data->{$id}->{counter};
    $vars->{accession}       = $data->{$id}->{accession};
    $vars->{species}         = $data->{$id}->{species};
    $vars->{species} =~ s/_/ /g;
    $vars->{species} = ucfirst($vars->{species});
    $vars->{genename}        = $data->{$id}->{genename};
    $vars->{comments}        = $data->{$id}->{comment};
    $vars->{slipsite_count}  = $data->{$id}->{slipsite_count};
    $vars->{structure_count} = $data->{$id}->{structure_count};
    if ($vars->{accession} =~ /^SGDID/) {
	$vars->{short_accession} = $vars->{accession};
	$vars->{short_accession} =~ s/^SGDID\://g;
    }
    elsif ($vars->{accession} =~ /^BC/) {
	$vars->{short_accession} = undef;
        $vars->{genbank_accession} = $vars->{accession};
    }
    $template->process( 'multimatch_body.html', $vars ) or
	Print_Template_Error($template), die;
  }                    ## Foreach every entry in @entries
  $template->process( 'multimatch_footer.html', $vars ) or
      Print_Template_Error($template), die;
}    ## Else there is more than one match for the given search string.

sub Perform_Search {
  my $query = $cgi->param('query');
  my $query_statement = qq/SELECT *  FROM genome WHERE /;
  if (defined($config->{species_limit})) {
      $query_statement .= qq/species = '$config->{species_limit}' AND /;
  }
  $query_statement .= qq/(genename regexp '$query' OR accession regexp '$query' OR locus regexp '$query' OR comment regexp '$query')/;
  
  my $entries = $db->MySelect({
      statement => $query_statement,
      type => 'hash',
      descriptor => 1, });
  foreach my $c (keys %{$entries}) {
      my $slip_stmt = qq(SELECT count(distinct(start)), count(distinct(id)) FROM mfe WHERE accession = ?);
      my $slipsite_structure_count = $db->MySelect({
	  statement => $slip_stmt,
	  vars => [$entries->{$c}->{accession}],
	  type => 'row', });
      $entries->{$c}->{slipsite_count} = $slipsite_structure_count->[0];
      $entries->{$c}->{structure_count} = $slipsite_structure_count->[1];
  }
  my $entries_count = scalar keys %{$entries};
  if ( $entries_count == 0) {
    $vars->{error} = "No entry was found in the database with genename, accession, locus, nor comment $query<br>\n";
  } elsif ( $entries_count == 1 ) {
      my @id = keys %{$entries};
    Print_Single_Accession( $entries->{$id[0]} );
  }         ## Elsif there is a single match for this search
  else {    ## More than 1 return from the search...
    Print_Multiple_Accessions($entries);
  }
}

sub Perform_Import {
  my $accession = $cgi->param('import_accession');
  my $result    = $db->Import_CDS($accession);
  $vars->{import_result} = $result;
  $template->process( 'import_result.html', $vars ) or
      Print_Template_Error($template), die;
}

sub ErrorPage {
  $template->process( 'error.html', $vars ) or
      Print_Template_Error($template), die;
}

sub Start_Filter {
    my $species;
    if (defined($config->{species_limit})) {
	$species = [$config->{species_limit}];
    }
    else {
	$species = $db->MySelect({
	    statement => "SELECT distinct(species) from genome", 
	    type => 'flat' });
    }
  #  unshift (@{$species}, 'All');
  $vars->{startform} = $cgi->startform( -action => "$base/second_filter" );
  $vars->{filter_submit} = $cgi->submit( -name => 'second_filter', -value => 'Filter PRFdb');
  $vars->{species} = $cgi->popup_menu(
    -name    => 'species',
    -values  => $species,
    -default => 'saccharomyces_cerevisiae',
  );
  $vars->{algorithm} = $cgi->popup_menu(
    -name    => 'algorithm',
    -values  => [ 'pknots', 'nupack' ],
    -default => 'pknots'
  );
  $template->process( 'filterform.html', $vars ) or
      Print_Template_Error($template), die;
}

sub Perform_Second_Filter {
  my $species   = $cgi->param('species');
  my $algorithm = $cgi->param('algorithm');
  $vars->{startform} = $cgi->startform( -action => "$base/third_filter" );
  my $stats_stmt = qq(SELECT * FROM stats WHERE species = ? AND algorithm = ? AND seqlength = ?);
  my $stats = $db->MySelect({
      statement => $stats_stmt,
      vars => [$species, $algorithm, $config->{seqlength}],
      type => 'hash' });

  foreach my $k (sort keys %{$stats}) {
      $vars->{$k} = $stats->{$k};
  }
  ## This fills out:
#algorithm: pknots
#avg_mfe: -15.6069
#avg_mfe_knotted: -15.5157
#avg_mfe_noknot: -15.6304
#avg_pairs: 24.2449
#avg_pairs_knotted: 26.5261
#avg_pairs_noknot: 23.6581
#id: 4
#max_mfe: 10
#num_sequences: 12932
#num_sequences_knotted: 2646
#num_sequences_noknot: 10286
#seqlength: 100
#species: saccharomyces_cerevisiae
#stddev_mfe: 4.43644
#stddev_mfe_knotted: 4.03963
#stddev_mfe_noknot: 4.5326
#stddev_pairs: 5.02694
#stddev_pairs_knotted: 4.14184
#stddev_pairs_noknot: 5.06703
  $vars->{choose_limit} = $cgi->textfield(-name => 'choose_limit',);
  $vars->{choose_mfe} = $cgi->textfield(-name => 'choose_mfe', -value => ($vars->{avg_mfe} - $vars->{stddev_mfe}));
  $vars->{choose_pairs} = $cgi->textfield(-name => 'choose_pairs', -value => ($vars->{avg_pairs} + $vars->{stddev_pairs}));

  $vars->{filters} = $cgi->checkbox_group(
    -name   => 'filters',
    -values => [ 'pseudoknots only', ],
#    [ 'pseudoknots only', 'lowest mfe only', 'longest window', 'less than mean mfe', 'less than mean zR' ],
    -defaults => [ 'pseudoknots only', ],
#    -rows     => 3,
#    -columns  => 3
      );
  $vars->{species} = $species;
  $vars->{algorithm} = $algorithm;

  $vars->{hidden_species} = $cgi->hidden(-name => 'hidden_species', -value => $species);
  $vars->{hidden_algorithm} = $cgi->hidden( -name => 'hidden_algorithm', -value => $algorithm);
  $vars->{filter_submit} = $cgi->submit( -name => 'third_filter', -value => 'Filter PRFdb');
  $template->process( 'secondfilterform.html', $vars ) or
      Print_Template_Error($template), die;
}

sub Perform_Third_Filter {
    my @filters   = $cgi->param('filters');
    my $species = $cgi->param('hidden_species');
    my $algorithm = $cgi->param('hidden_algorithm');
    my $max_mfe = $cgi->param('choose_mfe');
    my $seqlength = $config->{seqlength};
    my $limit = $cgi->param('choose_limit');
    $vars->{choose_limit} = $limit;
    $vars->{species} = $species;
    $vars->{algorithm} = $algorithm;
    $vars->{hidden_species} = $cgi->hidden(-name =>'hidden_species', -value => $species);
    $vars->{hidden_algorithm} = $cgi->hidden(-name => 'hidden_algorithm', -value => $algorithm);

    my $statement = qq(SELECT * FROM mfe WHERE species = '$species' AND algorithm = '$algorithm' AND seqlength = '$seqlength' AND );
    foreach my $filter (@filters) {
	if ( $filter eq 'pseudoknots only' ) {
	    $statement .= "knotp = '1' AND ";
	}
    }
    if (defined($max_mfe)) {
	$statement .= "mfe < '$max_mfe' AND ";
    }

  $statement =~ s/AND $/ORDER BY accession,mfe/g;

    if (defined($limit) and $limit ne '') {
	$statement .= " LIMIT $limit";
    }

    my $info = $db->MySelect($statement);
    foreach my $datum (@{$info}) {
	$vars->{id} = $datum->[0];
	$vars->{genome_id} = $datum->[1];
	$vars->{accession} = $datum->[2];
      #species: saccharomyces_cerevisiae = $datum->[3];
      #algorithm: pknots = $datum->[4];
	$vars->{start} = $datum->[5];
	$vars->{slipsite} = $datum->[6];
	$vars->{seqlength} = $datum->[7];
	$vars->{sequence} = $datum->[8];
	$vars->{output} = $datum->[9];
	$vars->{parsed} = $datum->[10];
	$vars->{parens} = $datum->[11];
	$vars->{mfe} = $datum->[12];
	$vars->{pairs} = $datum->[13];
	$vars->{knotp} = $datum->[14];
	$vars->{barcode} = $datum->[15];
	$vars->{lastupdate} = $datum->[16];
	$template->process('filter_finished.html', $vars ) or
	    Print_Template_Error($template), die;
    }
  $template->process( 'thirdfilter.html', $vars ) or
      Print_Template_Error($template), die;
}

sub Print_Sliplist {

}

sub Create_Pretty_mRNA {
  my $accession = shift;
  my $result    = '';
  my $st = qq(SELECT mrna_seq, orf_start, orf_stop, direction FROM genome WHERE accession = ?);
  my $info      = $db->MySelect({
      statement => $st,
      vars => [$accession], 
      type => 'row'});
  my $mrna_seq  = $info->[0];
  my $orf_start = $info->[1];
  my $orf_stop  = $info->[2];
  my $direction = $info->[3];
  my @seq_array = split( //, $mrna_seq );
  my $total_seq_length = scalar(@seq_array);
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
  my $decrement = $start_padding_bases + 1;
  my $slipsite_positions = $db->MySelect({
      statement =>"SELECT DISTINCT start FROM mfe WHERE accession = ? ORDER BY start",
      vars => [$accession],
      type =>'flat'});
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
  my $base_count = 1;
  my $end_base_string = '';
  my $start_base_string = '';
  foreach my $codon (@codon_array) {
      if ($codon_count == 0) {
	  my $prefix = qq(${base_count}&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;);
	  $base_count = $base_count - $decrement;
	  $first_pass = join('', $prefix, $first_pass);
      }
      $codon_count++;
      if ( ( $codon_count % 15 ) == 0 ) {
	  $base_count = $base_count + 45;
	  my $suffix_base_count = $base_count - 1;
	  if ($base_count > 99999) { 
	      $start_base_string = qq(${base_count}&nbsp;);
	      $end_base_string = qq(&nbsp;$suffix_base_count);
	  } elsif ($base_count > 9999) {
	      $start_base_string = qq(${base_count}&nbsp;&nbsp;); 
	      $end_base_string = qq(&nbsp;&nbsp;$suffix_base_count);
	  } elsif ($base_count > 999) {
	      $start_base_string = qq(${base_count}&nbsp;&nbsp;&nbsp;); 
	      $end_base_string = qq(&nbsp;&nbsp;&nbsp;$suffix_base_count);
	  } elsif ($base_count > 99) {
	      $start_base_string = qq(${base_count}&nbsp;&nbsp;&nbsp;&nbsp;); 
	      $end_base_string = qq(&nbsp;&nbsp;&nbsp;&nbsp;$suffix_base_count);
	  }
	  elsif ($base_count > 9) {
	      $start_base_string = qq(${base_count}&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;); 
	      $end_base_string = qq(&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$suffix_base_count);
	  }
	  
	  $first_pass = join( '', $first_pass, $codon, "$end_base_string<br>\n$start_base_string" );
      } 
      else {
	  $first_pass = join( '', $first_pass, $codon, ' ' );
      }
  }  ## End foreach codon
  my $suffix = qq(&nbsp;$total_seq_length);
  $first_pass = join( '', $first_pass, $suffix);
  return ($first_pass);
}

sub Get_Accession_Info {
  my $accession       = shift;
  my $query_statement = qq(SELECT id, species, genename, comment, orf_start, orf_stop, lastupdate, mrna_seq FROM genome WHERE accession = ?);
  my $entry = $db->MySelect({
      statement => $query_statement,
      vars => [$accession],
      type => 'row', });
  my $data = {
    id         => $entry->[0],
    species    => $entry->[1],
    genename   => $entry->[2],
    comment    => $entry->[3],
    orf_start  => $entry->[4],
    orf_stop   => $entry->[5],
    lastupdate => $entry->[6],
    mrna_seq   => $entry->[7],
  };
  my $slipsite_structure_count = $db->MySelect({
      statement => "SELECT count(distinct(start)), count(distinct(id)) FROM mfe WHERE accession = ?",
      vars => [$accession],
      type => 'row', });
  $data->{slipsite_count}  = $slipsite_structure_count->[0];
  $data->{structure_count} = $slipsite_structure_count->[1];
  return ($data);
}

sub Print_Blast {
  my $local      = shift;
  my $input_sequence = shift;
  my $blast      = new PRF_Blast;
  
  my $accession;
  my $sequence;
  if (defined($input_sequence)) {
      $sequence = $input_sequence;
  }
  else {
      $accession  = $cgi->param('accession');
      $sequence   = $db->MySelect({
	  statement => "SELECT mrna_seq FROM genome WHERE accession = ?",
	  vars => [$accession],
	  type => 'single', });
  }
  
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


  $vars->{query_length} = $local_info->{query_length};
  $vars->{num_hits}         = $local_info->{num_hits};
  $vars->{hit_names}        = \%hit_names;
  $vars->{accessions}       = \%accessions;
  $vars->{lengths}          = \%lengths;
  $vars->{descriptions}     = \%descriptions;
  $vars->{scores}           = \%scores;
  $vars->{hit_names}        = \%hit_names;
  $vars->{significances}    = \%significances;
  $vars->{bitses}           = \%bitses;
  $vars->{hsps_evalue}      = \%hsps_evalue;
  $vars->{hsps_expect}      = \%hsps_expect;
  $vars->{hsps_gaps}        = \%hsps_gaps;
  $vars->{hsps_querystring} = \%hsps_querystring;
  $vars->{hsps_homostring}  = \%hsps_homostring;
  $vars->{hsps_hitstring}   = \%hsps_hitstring;
  $vars->{hsps_numid}       = \%hsps_numid;
  $vars->{hsps_numcon}      = \%hsps_numcon;
  $vars->{hsps_length}      = \%hsps_length;
  $vars->{hsps_score}       = \%hsps_score;

  $template->process( 'blast.html', $vars ) or
      Print_Template_Error($template), die;
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
  my $stmt = qq(SELECT orf_start, orf_stop FROM genome WHERE accession = '$accession');
  my $tmp  = $db->MySelect({
      statement => $stmt,
      type => 'row'});
  $vars->{start} = $tmp->[0];
  $vars->{stop} = $tmp->[1];
  $template->process( 'landscape.html', $vars ) or
      Print_Template_Error($template), die;
}

sub Cloud {
    my $species = $cgi->param('species');
    my @filters = $cgi->param('cloud_filters');
    my $slipsites = $cgi->param('slipsites');
    my $cloud = new PRFGraph();

    my $pknots_only = undef;

    my $suffix = undef;
    foreach my $filter (@filters) {
	if ($filter eq 'pseudoknots only') {
	    $suffix .= "-pknot";
	    $pknots_only = 1;
	}
	elsif ($filter eq 'coding sequence only') {
	    $suffix .= "-cs";
	}
    }
    if ($slipsites eq 'all') {
	$suffix .= "-all";
    }
    else {
	$suffix .= "-${slipsites}";
    }

    my $cloud_output_filename = $cloud->Picture_Filename({type => 'cloud', species => $species, suffix => $suffix,});
    my $cloud_url = $cloud->Picture_Filename({type => 'cloud', species => $species, url => 'url', suffix => $suffix,});
    $cloud_url = $basedir . '/' . $cloud_url;
    if (!-f $cloud_output_filename) {
	my ($points_stmt, $averages_stmt, $points, $averages);
	if ($species eq 'all') {
	    $points_stmt = qq(SELECT mfe.mfe, boot.zscore, mfe.accession, mfe.knotp, mfe.slipsite FROM mfe, boot WHERE boot.zscore IS NOT NULL AND mfe.mfe > -80 AND mfe.mfe < 5 AND boot.zscore > -10 AND boot.zscore < 10 AND mfe.seqlength = $config->{seqlength} AND mfe.id = boot.mfe_id AND );
#	    $averages_stmt = qq(SELECT avg(mfe.mfe), avg(boot.zscore), stddev(mfe.mfe), stddev(boot.zscore) FROM MFE, boot WHERE boot.zscore IS NOT NULL AND mfe.mfe > -80 AND mfe.mfe < 5 AND boot.zscore > -10 AND boot.zscore < 10 AND mfe.species = ? AND mfe.seqlength = $config->{seqlength} AND mfe.id = boot.mfe_id AND );
	    $averages_stmt = qq(SELECT avg(mfe.mfe), avg(boot.zscore), stddev(mfe.mfe), stddev(boot.zscore) FROM MFE, boot WHERE boot.zscore IS NOT NULL AND mfe.mfe > -80 AND mfe.mfe < 5 AND boot.zscore > -10 AND boot.zscore < 10 AND mfe.seqlength = $config->{seqlength} AND mfe.id = boot.mfe_id AND );
	    foreach my $filter (@filters) {
		if ($filter eq 'pseudoknots only') {
		    $points_stmt .= "mfe.knotp = '1' AND ";
		    $averages_stmt .= "mfe.knotp = '1' AND ";
		}
		elsif ($filter eq 'coding sequence only') {
		    $points_stmt .= "";
		}
	    }

	    $points_stmt =~ s/AND $//g;
	    $averages_stmt =~ s/AND $//g;
	    $points = $db->MySelect({statement => $points_stmt,});
	    $averages = $db->MySelect({statement =>$averages_stmt, type => 'row',});
	}
	else {
	    $points_stmt = qq(SELECT mfe.mfe, boot.zscore, mfe.accession, mfe.knotp, mfe.slipsite FROM mfe, boot WHERE boot.zscore IS NOT NULL AND mfe.mfe > -80 AND mfe.mfe < 5 AND boot.zscore > -10 AND boot.zscore < 10 AND mfe.species = ? AND mfe.seqlength = $config->{seqlength} AND mfe.id = boot.mfe_id AND );
	    $averages_stmt = qq(SELECT avg(mfe.mfe), avg(boot.zscore), stddev(mfe.mfe), stddev(boot.zscore) FROM MFE, boot WHERE boot.zscore IS NOT NULL AND mfe.mfe > -80 AND mfe.mfe < 5 AND boot.zscore > -10 AND boot.zscore < 10 AND mfe.species = ? AND mfe.seqlength = $config->{seqlength} AND mfe.id = boot.mfe_id AND );

	    foreach my $filter (@filters) {
		if ($filter eq 'pseudoknots only') {
		    $points_stmt .= "mfe.knotp = '1' AND ";
		    $averages_stmt .= "mfe.knotp = '1' AND ";
		}
		elsif ($filter eq 'coding sequence only') {
		    $points_stmt .= "";
		    $averages_stmt .= "";
		}
	    }

	    $points_stmt =~ s/AND $//g;
	    $averages_stmt =~ s/AND $//g;
	    $points = $db->MySelect({statement => $points_stmt, vars => [$species]});
	    $averages = $db->MySelect({
		statement => $averages_stmt,
		vars => [$species],
		type => 'row', });
	}

	my $cloud_data;
	if (defined($pknots_only)) {
	    $cloud_data = $cloud->Make_Cloud($species, $points, 
					     $averages, $cloud_output_filename, $base,
					     {pknot => 1, slipsites => $slipsites});
	}
	else {
	    $cloud_data = $cloud->Make_Cloud($species, $points,
					     $averages, $cloud_output_filename, $base,
					     {slipsites => $slipsites});
	}
    }
    $vars->{species} = $species;
    $vars->{nicespecies} = $species;
    $vars->{nicespecies} =~ s/_/ /g;
    $vars->{nicespecies} = ucfirst($vars->{nicespecies});
    $vars->{cloud_file} = $cloud_output_filename;
    $vars->{cloud_url} = $cloud_url;
    if ($slipsites ne 'all') {
	$vars->{slipsites} = $slipsites;
    }
    $vars->{map_url} = "$vars->{cloud_url}" . '.map'; 
    $vars->{map_file} = "$vars->{cloud_file}" . '.map';
    $template->process( 'cloud.html', $vars ) or
	Print_Template_Error($template), die;
}

sub Download_Sequence {
    my $accession = shift;
    my $stmt = qq(SELECT comment,mrna_seq FROM genome WHERE accession = ?);
    my $seq = $db->MySelect({
	statement => $stmt,
	vars => [$accession],
	type => 'row', });
    my @tmp = split(//, $seq->[1]);
    print "Content-type: text/plain\n\n";
    print ">$accession $seq->[0]";
    foreach my $c (0 .. $#tmp) {
	print "\n" if (($c %80) == 0);
	print $tmp[$c];
    }
}

sub Download_Bpseq {
    my $id = shift;
    my $fh = \*STDOUT;
    my $ref = ref($fh);
    print "Content-type: text/plain\n\n";
    $db->Mfeid_to_Bpseq($id, $fh);
}

sub Download_Subsequence {
    my $id = shift;
    my $stmt = qq(SELECT genome.comment,mfe.accession,mfe.sequence,mfe.start FROM genome,mfe WHERE mfe.id = ? and mfe.genome_id=genome.id);
    my $seq = $db->MySelect({statement => $stmt, vars => [$id], type => 'row'});
    my @tmp = split(//, $seq->[2]);
    print "Content-type: text/plain\n\n";
    print ">$seq->[1] starting at $seq->[3]: $seq->[0]";
    foreach my $c (0 .. $#tmp) {
	print "\n" if (($c %80) == 0);
	print $tmp[$c];
    }
}

sub Download_Parens {
    my $id = shift;
    my $stmt = qq(SELECT genome.comment,mfe.accession,mfe.parens,mfe.start FROM genome,mfe WHERE mfe.id = ? and mfe.genome_id=genome.id);
    my $seq = $db->MySelect({statement =>$stmt, vars =>[$id], type =>'row'});
    print "Content-type: text/plain\n\n";
    print "#$seq->[1] starting at $seq->[3]: $seq->[0]
$seq->[2]
";
}

sub Download_Parsed {
    my $id = shift;
    my $stmt = qq(SELECT genome.comment,mfe.accession,mfe.parsed,mfe.start FROM genome,mfe WHERE mfe.id = ? and mfe.genome_id=genome.id);
    my $seq = $db->MySelect({ statement => $stmt, vars => [$id], type =>'row'});
    print "Content-type: text/plain\n\n";
    print "#$seq->[1] starting at $seq->[3]: $seq->[0]
$seq->[2]
";
}

sub Print_Template_Error {
    my $t = shift;
    my $err = $t->error();
    my $string = $err->as_string();
    print $string;
}

sub Retarded {
    my $filename = shift;
    my $FU = qq(grep height $filename  | awk -F'height="' '{print \$2}' | awk -F'"' '{print \$1}' | head -n 1);
    open(F, "$FU |");
    my $rep;
    while (my $line = <F>) {
	chomp $line;
	$rep .= $line;
    }
    close(F);

    my $FU2 = qq(grep width $filename  | awk -F'width="' '{print \$2}' | awk -F'"' '{print \$1}' | head -n 1);
    open(F2, "$FU2 |");
    my $rep2;
    while (my $line = <F2>) {
	chomp $line;
	$rep2 .= $line;
    }
    close(F);

    my $ret = {};
    $ret->{height} = $rep;
    $ret->{width} = $rep2;
    return($ret);
}
