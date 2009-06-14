#!/usr/bin/perl -w -I/usr/local/prfdb/prfdb_beta/lib
use strict;
use CGI qw/:standard :html3/;
use CGI::Carp qw(fatalsToBrowser carpout);
use Template;
chdir("/usr/local/prfdb/prfdb_beta");
use lib "/usr/local/prfdb/prfdb_beta/lib";
use PRFConfig;
use PRFdb;
use PRFBlast;
use PRFGraph;
#use SeqMisc;
use Bootlace;
$ENV{HTTP_HOST} = 'Youneedtodefinedahostname' if (!defined($ENV{HTTP_HOST}));
$ENV{SCRIPT_NAME} = 'index.cgi' if (!defined($ENV{SCRIPT_NAME}));
umask(0022);
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
our $path = $cgi->path_info;
our $category = $path;
$category =~ s/\///g;
$category = substr($category,0,5);

our @species_values = @{$config->{index_species}};
push(@species_values, 'all');
our @single_seqlength = @{$config->{seqlength}};
our $single_seqlen = shift(@single_seqlength);

our %species_labels;
foreach my $value (@species_values) {
  my $long_name = $value;
  $long_name =~ s/_/ /g;
  $long_name = ucfirst($long_name);
  $species_labels{$value} = $long_name;
}

our $vars = {
    base => $base,
    basedir => $basedir,
    startsearchform => $cgi->startform( -action => "$base/search_perform" ),
    search_species_limit => $cgi->popup_menu(-name =>'search_species_limit', -values => \@species_values, -labels => \%species_labels, -default => 'all'),
    searchquery => $cgi->textfield(-name => 'query', -size => 20),
    searchform => "$base/searchform",
    importform => "$base/import",
    filterform => "$base/filter_start",
    snpform => "$base/snpstart",
    downloadform => "$base/download",
    cloudform => "$base/cloudform",
    helpform => "$base/help",
    seqlength => $single_seqlen,
    searchsubmit => $cgi->submit(-name => 'search submit', -value => 'Search'),
    category => $category,
    summary => {
	'bos_taurus' => {
	    name => 'Bos taurus',
	    sequences => 49266,
	    genes => 3305,
	    total => 9187,},
	'danio_rerio' => {
	    name => 'Danio rerio',
	    sequences => 25836,
	    genes => 1929,
	    total => 6197,},
	'homo_sapiens' => {
	    name => 'Homo sapiens',
	    sequences => 102404,
	    genes => 6732,
	    total => 17893,},
	'mus_musculus' => {
	    name => 'Mus musculus',
	    sequences => 86837,
	    genes => 5933,
	    total => 15620,},
	'rattus_norvegicus' => {
	    name => 'Rattus norvegicus',
	    sequences => 26979,
	    genes => 1959,
	    total => 5341,},
	'saccharomyces_cerevisiae' => {
	    name => 'Saccharomyces cerevisiae',
	    sequences => 150045,
	    genes => 4128,
	    total => 6352,},
	'xenopus_laevis' => {
	    name => 'Xenopus laevis',
	    sequences => 79485,
	    genes => 4808,
	    total => 9325,},
	'xenopus_tropicalis' => {
	    name => 'Xenopus tropicalis',
	    sequences => 44299,
	    genes => 2663,
	    total => 5126,},
	'saccharomyces_kudriavzevii' => {
	    name => 'Saccharomyces kudriavzevii',
	    sequences => 48447,
	    genes => 2212,
	    total => 3778,},
	'saccharomyces_castellii' => {
	    name => 'Saccharomyces castellii',
	    sequences => 73836,
	    genes => 2964,
	    total => 4681, },
	'saccharomyces_bayanus' => {
	    name => 'Saccharomyces bayanus',
	    sequences => 71433,
	    genes =>  2951,
	    total => 4970, },
## SELECT COUNT(id) FROM mfe WHERE species = 'homo_sapiens'
## SELECT COUNT(DISTINCT(accession)) FROM mfe WHERE knotp = '1' and species = 'homo_sapiens'
## SELECT COUNT(id) FROM genome WHERE species = 'homo_sapiens'
	'saccharomyces_paradoxus' => {
	    name => 'Saccharomyces paradoxus',
	    sequences => 9700,
	    genes => 436,
	    total => 8955, },
    },    
};

our $download_header = qq(Content-type: application/x-octet-stream
Content-Disposition:attachment;filename=);

MAIN();

sub MAIN {
#### MAIN BLOCK OF CODE RIGHT HERE
    if ($path eq '/download_sequence') {
	Download_Sequence($cgi->param('accession'));
	exit(0);
    }
    elsif ($path eq '/download_svg') {
	Download_PNG($cgi->param('accession'), $cgi->param('mfeid'));
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
    elsif ($path eq '/download_all_genome') {
	Download_All($cgi->param('species'), 'genome');
	exit(0);
    }
    elsif ($path eq '/download_all_mfe') {
	Download_All($cgi->param('species'), 'mfe');
	exit(0);
    }
    elsif (defined($cgi->param('output_format')) and $cgi->param('output_format') eq 'tab delimited') {
	my $species = $cgi->param('hidden_species');
	my $filename = qq($species.tab);
	local $| = 1;
	print $download_header;
	print "$filename\n\n";
	Perform_Third_Filter();
    }
    elsif ($path eq '/download_all_boot') {
	Download_All($cgi->param('species'), 'boot');
	exit(0);
    }

    print $cgi->header;
    $template->process( 'header.html', $vars ) or
	Print_Template_Error($template), die;

    if ($path eq '/start' or $path eq '') {
	Print_Index();
    }
    elsif ($path eq '/help') {
	$template->process('help.html', $vars) or
	    Print_Template_Error($template), die;
    }
    elsif ($path =~ /^\/help_(\w+$)/) {
	my $helpfile = qq(help_${1}.html);
	   $template->process($helpfile, $vars) or
	   Print_Template_Error($template), die;
    }
    elsif ($path eq '/cloud_mfe_z') {
	Print_MFE_Z();
    } 
    elsif ($path eq '/download') {
	Print_Download();
    }
    elsif ($path eq '/choose_download') {
	Print_Choose_Download();
    } 
    elsif ($path eq '/import') {
	Print_Import_Form();
    } 
    elsif ($path eq '/pictures') {
	Generate_Pictures();
    }
    elsif ($path eq '/stats') {
	my $data = {
	    species => \@species_values,
	    seqlength => [50,75,100],
	    max_mfe => ['10.0'],
	    algorithm => ['nupack','pknots','hotknots']};
	$db->Put_Stats($data);
	print "Generated stats.<br>\n";
	Print_Index();
    }
    elsif ($path eq '/perform_import') {
	Perform_Import();
	Print_Import_Form();
    }
    elsif ($path eq '/landscape') {
	Check_Landscape();
    }
    elsif ($path eq '/cloudform') {
	Print_Cloudform();
    } 
    elsif ($path eq '/cloud') {
	Cloud();
    }
    elsif (defined($cgi->param('blastsearch'))) {
	my $input_sequence = $cgi->param('blastsearch');
	Print_Blast('local',$input_sequence);
    } 
    elsif ($path eq '/searchform') {
	Print_Search_Form();
    }
    elsif ($path eq '/search_perform') {
	Perform_Search();	
    }
    elsif ($path eq '/overlaysearch_perform') {
	Perform_OverlaySearch();
    }
    elsif ($path eq '/filter_start') {
	Start_Filter();
    }
    elsif ($path eq '/filter_second') {
	Perform_Second_Filter();
    }
    elsif ($path eq '/filter_third') {
	Perform_Third_Filter();
    } 
    elsif ($path eq '/browse') {
	Print_Single_Accession();
    } 
    elsif ($path eq '/list_slipsites') {
	Print_Sliplist();
    }
    elsif ($path eq '/detail') {
	Print_Detail_Slipsite();
    }
    elsif ($path eq '/search_local_blast') {
	print "Performing Local BLAST search now, this may take a moment.<br>\n";
	Print_Blast('local');
    } 
    elsif ($path eq '/remote_blast') {
	print "Performing Remote BLAST search now, this may take a moment.<br>\n";
	Print_Blast('remote');
    } 
    elsif ($path eq '/snpstart') {
	Start_SNP_Filter();
    }
    elsif ($path eq '/snpfilter') {
	#Perform_SNP_Filter();
    }
    elsif ($path eq '/showstats') {
	Print_Stats();
    }

    print $cgi->endform;
    $template->process( 'footer.html', $vars ) or
	Print_Template_Error($template), die;
    exit(0);
}

sub Print_Index {
    my %species_info = ();
#    foreach my $spec (@{$config->{index_species}}) {
#	$species_info{$spec}{count} = $db->MySelect({
#	    statement => "SELECT count(id) FROM mfe WHERE species LIKE '%$spec%'",
#	    type => 'single'});
#	my $nicename = $spec;
#	$nicename =~ s/_/ /g;
#	$nicename = ucfirst($nicename);
#	$species_info{$spec}{nicename} = $nicename;
#	$species_info{$spec}{genes} = $db->MySelect({
#	    statement => "SELECT count(id) FROM genome WHERE species LIKE '%$spec%'",
#	    type => 'single'});
#	$species_info{$spec}{done_genes} = $db->MySelect({
#	    statement => "SELECT count(distinct(genome_id)) FROM mfe WHERE species LIKE '%$spec%'",
#	    type => 'single'});
#    }
    my $lastupdate_statement = qq(SELECT species, lastupdate, accession FROM mfe );
    if (defined($config->{species_limit})) {
	$lastupdate_statement .= qq(WHERE species = '$config->{species_limit}' );
    }
    $lastupdate_statement .= qq(ORDER BY lastupdate DESC LIMIT 1);
    my $lastupdate = $db->MySelect({
	statement => $lastupdate_statement,
	type => 'row'});

#    $vars->{species_info} = \%species_info;
    $vars->{last_species} = $lastupdate->[0];
    $vars->{last_species} = ucfirst($vars->{last_species});
    $vars->{last_species} =~ s/_/ /g;
    $vars->{lastupdate} = $lastupdate->[1];
    $vars->{last_accession} = $lastupdate->[2];
    $template->process( 'index.html', $vars ) or
	Print_Template_Error($template), die;
}

sub Print_Download {
  my %labels = ();
  if (defined($config->{index_species})) {
      $vars->{species} = $cgi->popup_menu(-name => 'species',
					  -values => \@species_values,
					  -labels => \%species_labels,
					  );
  }
  else {
      my @values = ('saccharomyces_cerevisiae', 'homo_sapiens', 'mus_musculus','danio_rerio','bos_taurus', 'xenopus_laevis', 'xenopus_tropicalis', 'rattus_norvegicus', 'all');
      foreach my $value (@values) {
	  my $long_name = $value;
	  $long_name =~ s/_/ /g;
	  $long_name = ucfirst($long_name);
	  $labels{$value} = $long_name;
      }
      $vars->{species} = $cgi->popup_menu(-name => 'species',
					  -default => ['homo_sapiens'],
					  -values => \@values,
					  -labels => \%labels,
					  );
  }
  $vars->{download_submit} = $cgi->submit(-name=>'download_species', -value => 'Choose Download');
  $vars->{download_startform} = $cgi->startform(-action => "$base/choose_download");
  $template->process( 'download.html', $vars ) or
      Print_Template_Error($template), die;
}

sub Print_Choose_Download {
    $vars->{the_species} = $cgi->param('species');
    $vars->{chosen_species} = $cgi->param('species');
    $vars->{chosen_species} =~ s/_/ /g;
    $vars->{chosen_species} = ucfirst($vars->{chosen_species});
    $template->process('chosen_download.html', $vars) or
	Print_Template_Error($template), die;
}

sub Print_Search_Form {
    $vars->{blast_startform} = $cgi->startform(-action => "$base/search_blast");
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
    my %labels;
    $vars->{newstartform} = $cgi->startform( -action => "$base/cloud" );
    $vars->{seqlength} = $cgi->popup_menu(-name => 'seqlength', -values => $config->{seqlength},-default=> $vars->{seqlength});
    $vars->{slipsites} = $cgi->popup_menu(-name => 'slipsites',
					  -default => 'all',
					  -values => ['all',
						      'AAAUUUA', 'UUUAAAU', 'AAAAAAA',
						      'UUUAAAA', 'UUUUUUA', 'AAAUUUU',
						      'UUUUUUU', 'UUUAAAC', 'AAAAAAU',
						      'AAAUUUC', 'AAAAAAC', 'GGGUUUA',
						      'UUUUUUC', 'GGGAAAA', 'CCCUUUA',
						      'CCCAAAC', 'CCCAAAA', 'GGGAAAU',
						      'GGGUUUU', 'GGGAAAC', 'CCCUUUC',
						      'CCCUUUU', 'GGGAAAG', 'GGGUUUC',]);
    
    $vars->{cloud_filters} = $cgi->checkbox_group(
         					  -name => 'cloud_filters',
#						  -values => ['pseudoknots only', 'coding sequence only'],);
						  -values => ['pseudoknots only',],);
    $vars->{species} = $cgi->popup_menu(-name => 'species',
					-values => \@species_values,
					-labels => \%species_labels,
					);
    $vars->{cloudsubmit} = $cgi->submit();
    $template->process( 'cloudform.html', $vars ) or
	Print_Template_Error($template), die;
}

sub Print_MFE_Z {
    my $mfe = $cgi->param('mfe');
    my $z = $cgi->param('z');
#    print "MFE: $mfe Z: $z<br>\n";
    my $species = $cgi->param('species');
    my $seqlength = $cgi->param('seqlength');
    my $pknot = $cgi->param('pknot');
    my $slipsites = $cgi->param('slipsite');
#    $mfe = sprintf('%.0f', $mfe);
#    $z = sprintf('%.0f', $z);
    my $mfe_plus_factor;
    my $mfe_minus_factor;
    my $mfe_plus = $mfe + 0.1;
    my $mfe_minus = $mfe - 0.1;
    my $z_plus = $z + 0.1;
    my $z_minus = $z - 0.1;
    my ($stmt, $stuff);

    if (defined($slipsites) and $species eq 'all' and defined($pknot)) {
	$stmt = qq(SELECT distinct mfe.accession, mfe.start, mfe.id FROM mfe, boot WHERE mfe.seqlength = $seqlength AND ROUND(mfe.mfe,2) = ROUND($mfe,2) AND ROUND(boot.zscore,1) = ROUND($z,1) AND mfe.knotp = '1' AND mfe.id = boot.mfe_id AND mfe.slipsite = '$slipsites' ORDER BY mfe.start,mfe.accession);
    }
    elsif (defined($slipsites) and $species eq 'all' and !defined($pknot)) {
	$stmt = qq(SELECT distinct mfe.accession, mfe.start, mfe.id FROM mfe, boot WHERE mfe.seqlength = $seqlength AND ROUND(mfe.mfe,2) = ROUND($mfe,2) AND ROUND(boot.zscore,1) = ROUND($z,1) AND mfe.id = boot.mfe_id AND mfe.slipsite = '$slipsites' ORDER BY mfe.start,mfe.accession);
    }
    elsif (defined($slipsites) and $species ne 'all' and defined($pknot)) {
	$stmt = qq(SELECT distinct mfe.accession, mfe.start, mfe.id FROM mfe, boot WHERE mfe.species = '$species' AND mfe.seqlength = $seqlength AND ROUND(mfe.mfe,2) = ROUND($mfe,2) AND ROUND(boot.zscore,1) = ROUND($z,1) AND mfe.knotp = '1' AND mfe.id = boot.mfe_id AND mfe.slipsite = '$slipsites' ORDER BY mfe.start,mfe.accession);
    }
    elsif (defined($slipsites) and $species ne 'all' and !defined($pknot)) {
	$stmt = qq(SELECT distinct mfe.accession, mfe.start, mfe.id FROM mfe, boot WHERE mfe.species = '$species' AND mfe.seqlength = $seqlength AND ROUND(mfe.mfe,2) = ROUND($mfe,2)  AND ROUND(boot.zscore,1) = ROUND($z,1) AND mfe.id = boot.mfe_id AND mfe.slipsite = '$slipsites' ORDER BY mfe.start,mfe.accession);
    }
    elsif (!defined($slipsites) and $species eq 'all' and defined($pknot)) {
	$stmt = qq(SELECT distinct mfe.accession, mfe.start, mfe.id FROM mfe, boot WHERE mfe.seqlength = $seqlength AND ROUND(mfe.mfe,2) = ROUND($mfe,2)  AND ROUND(boot.zscore,1) = ROUND($z,1) AND mfe.knotp = '1' AND mfe.id = boot.mfe_id ORDER BY mfe.start,mfe.accession);
    }
    elsif (!defined($slipsites) and $species eq 'all' and !defined($pknot)) {
	$stmt = qq(SELECT distinct mfe.accession, mfe.start, mfe.id FROM mfe, boot WHERE mfe.seqlength = $seqlength AND ROUND(mfe.mfe,2) = ROUND($mfe,2) AND ROUND(boot.zscore,1) = ROUND($z,1) AND mfe.id = boot.mfe_id ORDER BY mfe.start,mfe.accession);
    }
    elsif (!defined($slipsites) and $species ne 'all' and defined($pknot)) {
	$stmt = qq(SELECT distinct mfe.accession, mfe.start, mfe.id FROM mfe, boot WHERE mfe.species = '$species' AND mfe.seqlength = $seqlength AND ROUND(mfe.mfe,2) = ROUND($mfe,2) AND ROUND(boot.zscore,1) = ROUND($z,1)  AND mfe.knotp = '1' AND mfe.id = boot.mfe_id ORDER BY mfe.start,mfe.accession);
    }
    elsif (!defined($slipsites) and $species ne 'all' and !defined($pknot)) {
	$stmt = qq(SELECT distinct mfe.accession, mfe.start, mfe.id FROM mfe, boot WHERE mfe.species = '$species' AND mfe.seqlength = $seqlength AND ROUND(mfe.mfe,2) = ROUND($mfe,2) AND ROUND(boot.zscore,1) = ROUND($z,1)  AND mfe.id = boot.mfe_id ORDER BY mfe.start,mfe.accession);
    }
    else {
	print "WTF<br>\n";
	$stmt = qq(WTF);
    }
    $stuff = $db->MySelect({statement => $stmt, });
    if ($#$stuff == 0) {
	  $cgi->param(-name => 'id', -value => $stuff->[0]->[2]);
	  $cgi->param(-name => 'accession', -value => $stuff->[0]->[0]);
	  $cgi->param(-name => 'slipstart', -value => $stuff->[0]->[1]);
	  ## Go directly to the accession/slipsite detail...
	  Print_Detail_Slipsite();
	}
	else {
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
	my $gene_stmt = qq(SELECT genename,comment,omim_id FROM genome WHERE accession = ?);
	my $g = $db->MySelect({
	    statement => $gene_stmt,
	    vars => [$accession],
	    type => 'row'});
	my $genename = $g->[0];
	my $comments = $g->[1];
	my $omim_id = $g->[2];

	$vars->{accession} = $accession;
	$vars->{start} = $start;
	$vars->{genename} = $genename;
	$vars->{comments} = $comments;
	$vars->{omim_id} = $omim_id;
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
}

sub Print_Stats {
    my @spec = @{$config->{index_species}};
 #   my @spec = ('bos_taurus');
#    my @algos = ('pknots','nupack','hotknots');
    my @algos = ('pknots','nupack');
#    my @lengths = @{$config->{seqlength}};
    my @lengths = ('100');

    $vars->{species} = \@spec;
    $vars->{algorithms} = \@algos;
    $vars->{lengths} = \@lengths;
    
    my @spec_fun;
    foreach my $species (@spec) {
	next if ($species eq 'virus');
	my @len_fun;
	foreach my $len (@lengths) {
	    my @algo_fun;
	    foreach my $alg (@algos) {


		my $start_stats = $db->MySelect({
		    statement => "SELECT * from stats where species = '$species' and algorithm = '$alg' and seqlength = '$len'",
		    type => 'list_of_hashes'});

		my $total_hepts = $start_stats->[0]->{num_sequences};
		my $total_mean = $start_stats->[0]->{avg_mfe};
		my $total_stdev = $start_stats->[0]->{stddev_mfe};

		my $knot_hepts = $start_stats->[0]->{num_sequences_knotted};
		my $knot_mean = $start_stats->[0]->{avg_mfe_knotted};
		my $knot_stdev = $start_stats->[0]->{stddev_mfe_knotted};
  
		my $mean_z = $start_stats->[0]->{avg_zscore};
		my $stddev_z = $start_stats->[0]->{stddev_zscore};

		my $sig_mfe = $total_mean - $total_stdev;
		my $sig_mfe_knot = $knot_mean - $knot_stdev;
		my $sig_z = $mean_z - $stddev_z;

		my $sigsig_mfe = $total_mean - ($total_stdev * 2);
		my $sigsig_mfe_knot = $knot_mean - ($knot_stdev * 2);
		my $sigsig_z = $mean_z - ($stddev_z * 2);

		my $all_stmt = qq/SELECT count(mfe.id) FROM mfe,boot WHERE mfe.seqlength = '$len' AND mfe.algorithm = '$alg' AND mfe.mfe < '$sig_mfe' AND mfe.id = boot.mfe_id AND boot.zscore < '$sig_z'/;;
		my $pseudo_stmt = qq/SELECT count(mfe.id) FROM mfe,boot WHERE mfe.seqlength = '$len' AND mfe.algorithm = '$alg' AND mfe.mfe < '$sig_mfe' AND knotp = '1' AND mfe.id = boot.mfe_id AND boot.zscore < '$sig_z'/;
		my $all_stmt_2 = qq/SELECT count(mfe.id) FROM mfe,boot WHERE mfe.seqlength = '$len' AND mfe.algorithm = '$alg' AND mfe.mfe < '$sigsig_mfe' AND mfe.id = boot.mfe_id AND boot.zscore < '$sigsig_z'/;
		my $pseudo_stmt_2 =  qq/SELECT count(mfe.id) FROM mfe,boot WHERE mfe.seqlength = '100' AND mfe.algorithm = '$alg' AND mfe.mfe < '$sigsig_mfe' AND knotp = '1' AND mfe.id = boot.mfe_id AND boot.zscore < '$sigsig_z'/;

		my $count_sig_all = $db->MySelect({
		    statement => $all_stmt,
		    type => 'single',
		});
		my $count_pseudo_all = $db->MySelect({
		    statement => $pseudo_stmt,
		    type => 'single',
		});
		my $count_sig_all_2 = $db->MySelect({
		    statement => $all_stmt_2,
		    type => 'single',
		});
		my $count_pseudo_all_2 = $db->MySelect({
		    statement => $pseudo_stmt_2,
		    type => 'single',
		});

		my $inner_stats = {
		    species => $species,
		    length => $len,
		    algorithm => $alg,
		    total_hepts => $total_hepts,
		    total_mean => $total_mean,
		    knot_hepts => $knot_hepts,
		    knot_mean => $knot_mean,
		    mean_z => $mean_z,
		    count_sig_all => $count_sig_all,
		    count_pseudo_all => $count_pseudo_all,
		    count_sig_all_2 => $count_sig_all_2,
		    count_sig_pseudo_all_2 => $count_pseudo_all_2,
		};

		push(@algo_fun, $inner_stats);

#		$vars->{stats}->{$species}->{$alg}->{$len}->{total_hepts} = $total_hepts;
#		$vars->{stats}->{$species}->{$alg}->{$len}->{total_mean} = $total_mean;
#		$vars->{stats}->{$species}->{$alg}->{$len}->{knot_hepts} = $knot_hepts;
#		$vars->{stats}->{$species}->{$alg}->{$len}->{knot_mean} = $knot_mean;
#		$vars->{stats}->{$species}->{$alg}->{$len}->{mean_z} = $mean_z;
#		$vars->{stats}->{$species}->{$alg}->{$len}->{count_sig_all} = $count_sig_all;
#		$vars->{stats}->{$species}->{$alg}->{$len}->{count_pseudo_all} = $count_pseudo_all;
#		$vars->{stats}->{$species}->{$alg}->{$len}->{count_sig_all_2} = $count_sig_all_2;
#		$vars->{stats}->{$species}->{$alg}->{$len}->{count_pseudo_all_2} = $count_pseudo_all_2;
	    }
	    push(@len_fun, \@algo_fun);
	}
	push(@spec_fun, \@len_fun);;
    }
    $vars->{stats} = \@spec_fun;
    $template->process('stats.html',$vars) or
	Print_Template_Error($template), die;
}

sub Print_Detail_Slipsite {
  my $id = $cgi->param('id');
  my $accession = $cgi->param('accession');
  my $slipstart = $cgi->param('slipstart');
  $vars->{accession} = $accession;
  $vars->{slipstart} = $slipstart;
  my ($detail_stmt, $info);
  Remove_Duplicates($accession);
  if (!defined($slipstart)) {
      $detail_stmt = qq(SELECT * FROM mfe WHERE accession = ? ORDER BY start, seqlength DESC,algorithm DESC);
      $info = $db->MySelect({
	  statement => $detail_stmt,
	  vars => [$accession,]});
  }
  else {
      $detail_stmt = qq(SELECT * FROM mfe WHERE accession = ? AND start = ? ORDER BY seqlength DESC,algorithm DESC);
      $info = $db->MySelect({
	  statement => $detail_stmt,
	  vars => [$accession, $slipstart]});
  }

  ## id,genome_id,accession,species,algorithm,start,slipsite,seqlength,sequence,output,parsed,parens,mfe,pairs,knotp,barcode,lastupdate
  ## 0  1         2         3       4         5     6        7         8        9      10     11     12  13    14    15      16

  $vars->{species} = $info->[0]->[3];
  $vars->{genome_id} = $info->[0]->[1];

  my $genome_stmt = qq(SELECT genename FROM genome where id = ?);
  my $genome_info = $db->MySelect({
      statement =>$genome_stmt,
      vars => [$vars->{genome_id}],});
  $vars->{genename} = $genome_info->[0]->[0];
  foreach my $structure (@{$info}) {
      my $id = $structure->[0];
      my $mfe = $structure->[12];
      $vars->{mfe_id} = $structure->[0];
      my $boot_stmt = qq(SELECT mfe_values, mfe_mean, mfe_sd, mfe_se, zscore FROM boot WHERE mfe_id = '$id');
      my $boot = $db->MySelect({
	  statement => $boot_stmt,
	  type => 'row'});
      my ($ppcc_values, $filename, $chart, $chartURL, $zscore, $randMean, 
	  $randSE, $ppcc, $mfe_mean, $mfe_sd, $mfe_se, $boot_db);

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
	      genome_id => $structure->[1],
	      nupack_mfe_id => $structure->[0],
	      pknots_mfe_id => $structure->[0],
	      inputfile => $inputfile,
	      species => $structure->[3],
	      accession => $structure->[2],
	      start => $structure->[5],
	      seqlength => $structure->[7],
	      iterations => $config->{boot_iterations},
	      boot_mfe_algorithms => $config->{boot_mfe_algorithms},
	      randomizers => $config->{boot_randomizers},
	      );
	  my $bootlaces = $boot->Go();
	  $db->Put_Boot($bootlaces);
	  chdir($config->{base});
      }

      if (!defined($accession)) {
	  print "Accession is not defined";
	  exit(0);
      }
      if (!defined($slipstart)) {
#	  print "The slipstart is not defined";
	  $slipstart = '';
      }
      my $acc_slip = qq/$accession-$slipstart/;
      my $feynman_pic = new PRFGraph({mfe_id => $id, accession => $accession});
      my $pre_feynman_url = $feynman_pic->Picture_Filename({type=> 'feynman', url => 'url',});
      my $feynman_url = $basedir . '/' . $pre_feynman_url;
      my $feynman_output_filename = $feynman_pic->Picture_Filename( {type => 'feynman', });
      my $feynman_dimensions = {};
      if (!-r $feynman_output_filename) {
	  $feynman_dimensions = $feynman_pic->Make_Feynman();
      }
      else {
	  $feynman_dimensions = $feynman_pic->Get_Feynman_ImageSize($feynman_output_filename);
      }
      
      if (defined($boot)) {
	  my $mfe_values = $boot->[0];
	  my @mfe_values_array = split(/\s+/, $mfe_values);
	  $chart = new PRFGraph({
	      real_mfe => $mfe,
	      list_data => \@mfe_values_array,
	      accession  => $acc_slip,
	      mfe_id => $id,
	  }
      );
	  my $ppcc_values = $chart->Get_PPCC();
	  $filename = $chart->Picture_Filename({type => 'distribution',});
	  my $pre_chartURL = $chart->Picture_Filename({type => 'distribution', url => 'url',});
	  $chartURL = $basedir . '/' . $pre_chartURL;

	  if (!-r $filename) {
	      $chart = $chart->Make_Distribution();
	  }

	  $mfe_mean = $boot->[1];
	  $mfe_sd = $boot->[2];
	  $mfe_se = $boot->[3];
	  $boot_db = $boot->[4];
	  if ($mfe_sd == 0) {
	      $zscore = 0;
	  }
	  else {
	      $mfe = 0 if (!defined($mfe));
	      $mfe_mean = 0 if (!defined($mfe_mean));
	      $mfe_sd = 1 if (!defined($mfe_sd));
	      $zscore = sprintf("%.2f", ($mfe - $mfe_mean) / $mfe_sd);
	  }
	  $randMean = sprintf("%.1f", $mfe_mean);
	  $randSE = sprintf("%.1f", $mfe_se);
	  $ppcc = sprintf("%.4f", $ppcc_values);
      }
      else {  ##Boot is not defined!
	  $chart = "undef";
	  $chartURL = qq($basedir/html/no_data.gif);
	  $mfe_mean = "undef";
	  $mfe_sd = "undef";
	  $mfe_se = "undef";
	  $zscore = "UNDEF";
	  $randMean = "UNDEF";
	  $randSE = "UNDEF";
	  $ppcc = "UNDEF";
      }
      $vars->{algorithm} = $structure->[4];
      $vars->{slipstart} = $structure->[5];
      $vars->{slipsite} = $structure->[6];
      $vars->{seqlength} = $structure->[7];
      $vars->{pk_input} = $structure->[8];
      $vars->{pk_input} =~ tr/atgcu/ATGCU/;
      $vars->{pk_output} = $structure->[9];
      $vars->{parsed} = $structure->[10];
      $vars->{parsed} =~ s/\s+//g;
      $vars->{brackets} = $structure->[11];
      $vars->{mfe} = $mfe;
      $vars->{pairs} = $structure->[13];
      $vars->{knotp} = $structure->[14];
      $vars->{barcode} = $structure->[15];

      my @in = split(//, $vars->{pk_input});
      my @par = split(//, $vars->{parsed});
      $vars->{gc_content} = Get_GC(\@in);
      $vars->{gc_stems} = Get_GC(\@in, \@par);

      my $delta = $vars->{seqlength} - length($vars->{parsed});
      $vars->{parsed} .= '.' x $delta;
      $vars->{brackets} .= '.' x $delta;

      $vars->{chart} = $chart;
      $vars->{chartURL} = $chartURL;
      $vars->{feynman} = $feynman_pic;
      $vars->{feynman_url} = $feynman_url;

      $vars->{mfe_mean} = $mfe_mean;
      $vars->{mfe_sd} = $mfe_sd;
      $vars->{mfe_se} = $mfe_se;
      $vars->{zscore} = $zscore;
      $vars->{randmean} = $randMean;
      $vars->{randse} = $randSE;
      $vars->{ppcc} = $ppcc;
      $vars->{boot_db} = $boot_db;

      $vars->{minus_stop} = Color_Stems(Make_Minus($vars->{pk_input}), $vars->{parsed});
      $vars->{numbers} = Make_Nums($vars->{pk_input});
      $vars->{pk_input} = Color_Stems($vars->{pk_input}, $vars->{parsed});
      $vars->{brackets} = Color_Stems($vars->{brackets}, $vars->{parsed});
      $vars->{parsed} = Color_Stems($vars->{parsed}, $vars->{parsed});
      $vars->{species} =~ s/_/ /g;
      $vars->{species} = ucfirst($vars->{species});

      $vars->{feynman_height} = $feynman_dimensions->{height};
      $vars->{feynman_width} = $feynman_dimensions->{width};

      if ($vars->{accession} =~ /^SGDID/) {
	  $vars->{short_accession} = $vars->{accession};
	  $vars->{short_accession} =~ s/^SGDID\://g;
      }
      elsif ($vars->{accession} =~ /^BC/) {
	  $vars->{short_accession} = undef;
	  $vars->{genbank_accession} = $vars->{accession};
      }

      $template->process("detail_body.html", $vars) or
	  Print_Template_Error($template), die;
  }    ## End foreach structure in the database
  my $num_algos = 0;
  $num_algos++ if ($config->{do_pknots} == 1);
  $num_algos++ if ($config->{do_nupack} == 1);
  $num_algos++ if ($config->{do_hotknots} == 1);
  my $num_expected_mfes = scalar(@{$config->{seqlength}}) * $num_algos;
  my $num_have = $db->MySelect({statement => qq/SELECT count(id) FROM mfe WHERE accession = '$vars->{accession}' AND start = '$vars->{slipstart}'/, type => 'single'});
  $db->Add_Webqueue($vars->{genome_id}) if ($num_have < $num_expected_mfes);
}

sub Get_GC {
    my $arr = shift;
    my $par = shift;
    my $gc;
    if (!defined($par)) {
	my $len = scalar(@{$arr});
	my $num_strong = 0;
	foreach my $char (@{$arr}) {
	    $num_strong++ if ($char eq 'c' or $char eq 'g' or $char eq 'G' or $char eq 'C');
	}
        $len = 1 if (!defined($len) or ($len == 0));
	$gc = $num_strong * 100.0 / $len;
    }
    else {
	my $num_strong = 0;
	my $total = 0;
	for my $c (0 .. $#$par) {
	    next if ($par->[$c] eq '.');
	    $num_strong++ if ($arr->[$c] eq 'c' or $arr->[$c] eq 'g' or $arr->[$c] eq 'C' or $arr->[$c] eq 'G');
	    $total++;
	}
	$gc = (($total == 0) ? 0 : $num_strong * 100.0 / $total);
#	$gc = $num_strong * 100.0 / $total;
    }
    $gc = sprintf('%.1f', $gc);
    return($gc);
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
	    next if (!defined($br[$t]));
	    my $append = qq(<font color="$colors[$color_code]">$br[$t]</font>);
	    $bracket_string .= $append;
	}
    }
    return($bracket_string);
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

sub Print_Single_Accession {
  my $datum = shift;
  my $fun = ref($datum);
  my $accession;
  if (!defined($datum) ) {
      $accession = $cgi->param('accession');
      $datum = Get_Accession_Info($accession);
      $datum->{accession} = $accession;
  }
  else {
      $accession = $datum->{accession};
  }
  $vars->{id} = $datum->{id};
  $vars->{counter} = $datum->{counter};
  $vars->{accession} = $accession;
  $vars->{omim_id} = $datum->{omim_id};
  if ($vars->{accession} =~ /^SGDID/) {
      $vars->{short_accession} = $vars->{accession};
      $vars->{short_accession} =~ s/^SGDID\://g;
  }
  elsif ($vars->{accession} =~ /^BC/) {
      $vars->{short_accession} = undef;
      $vars->{genbank_accession} = $vars->{accession};
  }
  $vars->{species} = $datum->{species};
  $vars->{species} =~ s/_/ /g;
  $vars->{species} = ucfirst($vars->{species});
  $vars->{genename} = $datum->{genename};
  $vars->{comments} = $datum->{comment};
  $vars->{orf_start} = $datum->{orf_start};
  $vars->{orf_stop} = $datum->{orf_stop};
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
  my $table = "landscape_$datum->{species}";
  my $landscape_num = $db->MySelect("SELECT count(id) FROM $table WHERE accession = '$accession'");
  $vars->{landscape_num} = $landscape_num->[0][0];

  $template->process( 'genome.html',          $vars ) or
      Print_Template_Error($template), die;
  $template->process( 'sliplist_header.html', $vars ) or
      Print_Template_Error($template), die;

  my $num_stops_printed = 0;
  my $num_starts_printed = 0;
  $vars->{slipcount} = 0;
  while (my $slip_info = shift( @{$slipsite_information})) {
      $vars->{slipcount}++;
      $vars->{slipstart}   = $slip_info->[0];
      $vars->{slipseq}     = $slip_info->[1];
      $vars->{pknotscount} = $slip_info->[2];
      $vars->{sig_count} += $vars->{pknotscount};
      if ($vars->{orf_start} < $vars->{slipstart} and $num_starts_printed == 0) {
	  $num_starts_printed++;
	  $template->process('sliplist_start_codon.html', $vars) or
	      Print_Template_Error($template), die;
      }
      if ($vars->{orf_stop} <= $vars->{slipstart} and $num_stops_printed == 0) {
	  $num_stops_printed++;
	  $template->process('sliplist_stop_codon.html', $vars) or
	      Print_Template_Error($template), die;
      }
      $template->process('sliplist.html', $vars) or
	  Print_Template_Error($template), die;
  }
  $template->process('sliplist_start_codon.html', $vars) if ($num_starts_printed == 0);
  $template->process('sliplist_stop_codon.html', $vars) if ($num_stops_printed == 0);
  $template->process('sliplist_footer.html', $vars) or
      Print_Template_Error($template), die;
  ## Before the RNA sequence, put in the picture of the ORF
  my $pic = new PRFGraph({accession => $accession});
  my $filename = $pic->Picture_Filename({type => 'landscape',});
  if (!-r $filename) {
      $pic->Make_Landscape($datum->{species});
  }
  my $url = $pic->Picture_Filename({type => 'landscape', url => 'url'});
  $vars->{picture} = $url;
  
  $template->process('mrna_sequence.html', $vars) or
      Print_Template_Error($template), die;
}

sub Print_Multiple_Accessions {
  my $data = shift;    ## From Perform_Search by default
  $template->process('multimatch_header.html', $vars) or
      Print_Template_Error($template), die;
  foreach my $id (sort { $data->{$b}->{slipsite_count} <=> $data->{$a}->{slipsite_count} } keys %{$data}) {
      $vars->{id} = $data->{$id}->{id};
      $vars->{counter} = $data->{$id}->{counter};
      $vars->{accession} = $data->{$id}->{accession};
      $vars->{species} = $data->{$id}->{species};
      $vars->{species} =~ s/_/ /g;
      $vars->{species} = ucfirst($vars->{species});
      $vars->{genename} = $data->{$id}->{genename};
      $vars->{comments} = $data->{$id}->{comment};
      $vars->{slipsite_count} = $data->{$id}->{slipsite_count};
      $vars->{structure_count} = $data->{$id}->{structure_count};
      if ($vars->{accession} =~ /^SGDID/) {
	  $vars->{short_accession} = $vars->{accession};
	  $vars->{short_accession} =~ s/^SGDID\://g;
      }
      elsif ($vars->{accession} =~ /^BC/) {
	  $vars->{short_accession} = undef;
	  $vars->{genbank_accession} = $vars->{accession};
      }
      $template->process('multimatch_body.html', $vars) or
	  Print_Template_Error($template), die;
  }                    ## Foreach every entry in @entries
  $template->process('multimatch_footer.html', $vars) or
      Print_Template_Error($template), die;
}    ## Else there is more than one match for the given search string.

sub Perform_Search {
    my $mode = shift;
    my $query = $cgi->param('query');
    my $query_statement = qq/SELECT * FROM genome WHERE /;
    if (defined($config->{species_limit})) {
	$query_statement .= qq/species = '$config->{species_limit}' AND /;
    }
    elsif ($cgi->param('search_species_limit') ne 'all') {
	my $sp = $cgi->param('search_species_limit');
	$query_statement .= qq/species regexp '$sp' AND /;
    }
    
    if (defined($mode) and $mode eq 'snp') {
	my $bool_genefilter = $cgi->param('gene');
	if ($bool_genefilter eq 'on') {
	    if (defined($cgi->param('gene_text'))) {
		$query_statement .= '';
	    }
	    elsif (defined($cgi->param('gene_upload'))) {
		$query_statement .= '';
	    }
	}

	$query_statement .= '';
    }
    else {
	$query_statement .= qq/(species regexp '$query' OR genename regexp '$query' OR accession regexp '$query' OR locus regexp '$query' OR comment regexp '$query')/;
    }
    my $entries = $db->MySelect({ statement => $query_statement,
				  type => 'hash',
				  descriptor => 1,});
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

sub Perform_OverlaySearch {
    my $query = $cgi->param('overlayquery');
    $query =~ s/\s+//g;
    my $seqlength = $cgi->param('seqlength');
    my $cloud_url = $cgi->param('cloud_url');
    my $species = $cgi->param('species');
    $vars->{new_accession} = $db->MySelect({statement => qq/SELECT accession FROM genome WHERE accession regexp '$query' or genename regexp '$query' or locus regexp '$query' or comment regexp '$query'/, type => 'single'});
    my $query_statement = qq/SELECT mfe.mfe, boot.zscore, mfe.start, mfe.algorithm FROM mfe,boot WHERE boot.zscore IS NOT NULL AND mfe.mfe > -80 AND mfe.mfe < 5 AND boot.zscore > -10 AND boot.zscore < 10 AND mfe.seqlength = 100 AND mfe.species = '$species' AND mfe.id = boot.mfe_id AND mfe.accession = '$vars->{new_accession}'/;
    my $overlay_points = $db->MySelect({statement => $query_statement,});
    $vars->{cloud_url} = $cloud_url;
    $vars->{inputstring} = $query;
    $vars->{overlay_output} = PRFdb::MakeTempfile({directory => 'images/tmp', SUFFIX => '.png', template => 'cloud_XXXXX',});
    $vars->{overlay_map} = "$vars->{overlay_output}" . '.map';
    $vars->{overlay_url} = $basedir . '/' . $vars->{overlay_output};
    my $args = {
	seqlength => 100,
	url => $base,
	species => 'saccharomyces_cerevisiae',
	points => $overlay_points,
	filename => $vars->{overlay_output},
	map => $vars->{overlay_map},
	accession => $vars->{new_accession},
	inputstring => $vars->{inputstring},
    };
    
    my $cloud = new PRFGraph();
    my $overlay_data = $cloud->Make_Overlay($args);
    $template->process('cloud_overlay.html', $vars) or
	Print_Template_Error($template), die;
    open(OUT, "<$vars->{overlay_map}");
    while (my $l = <OUT>) { print $l };
    close(OUT);
}

sub Perform_Import {
  my $accession = $cgi->param('import_accession');
  my $result = $db->Import_CDS($accession);
  $vars->{import_result} = $result;
  $template->process('import_result.html', $vars) or
      Print_Template_Error($template), die;
}

sub ErrorPage {
  $template->process('error.html', $vars) or
      Print_Template_Error($template), die;
}

sub Start_Filter {
  my $species;
  if (defined($config->{species_limit})) {
      $species = [$config->{species_limit}];
      $vars->{species} = $cgi->popup_menu(
	  -name => 'species',
	  -values => $species,
	  );
  }
  else {
      $vars->{species} = $cgi->popup_menu(
	  -name => 'species',
	  -values => \@species_values,
	  -labels => \%species_labels,
	  );
  }
  #  unshift (@{$species}, 'All');
  $vars->{startform} = $cgi->startform(-action => "$base/filter_second");
  $vars->{filter_submit} = $cgi->submit(-name => 'filter_second', -value => 'Filter PRFdb');
  $vars->{algorithm} = $cgi->popup_menu(
      -name    => 'algorithm',
      -values  => ['pknots', 'nupack'],
      -default => 'pknots'
  );
  $template->process('filterform.html', $vars) or
      Print_Template_Error($template), die;
}

sub Perform_Second_Filter {
    my $species = $cgi->param('species');
    my $algorithm = $cgi->param('algorithm');
    $vars->{startform} = $cgi->startform( -action => "$base/filter_third" );
    my $stats_stmt = qq(SELECT * FROM stats WHERE species = ? AND algorithm = ? AND seqlength = ?);
    my $stats = $db->MySelect({
	statement => $stats_stmt,
	vars => [$species, $algorithm, $vars->{seqlength}],
	type => 'hash' });
    foreach my $k (sort keys %{$stats}) {
	$vars->{$k} = $stats->{$k};
	if ($vars->{$k} =~ /.*\.\d+$/) {
	    $vars->{$k} = sprintf("%.2f", $vars->{$k});
	}
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
    $vars->{choose_limit} = $cgi->textfield(-name => 'choose_limit',
					    -value => 100,
					    -size=> 5,
					    -maxlength=> 3,);
    $vars->{choose_mfe} = $cgi->textfield(-name => 'choose_mfe',
					  -value => sprintf("%.2f", ($vars->{avg_mfe} - $vars->{stddev_mfe})),
					  -size => 6,
					  -maxlength => 6);
    $vars->{choose_pairs} = $cgi->textfield(-name => 'choose_pairs',
					    -value => sprintf("%.2f", ($vars->{avg_pairs} + $vars->{stddev_pairs})),
					    -size => 6,
					    -maxlength => 6);
    $vars->{choose_format} = $cgi->popup_menu(-name => 'output_format', -values => ['tab delimited', 'text',],);
    $vars->{filters} = $cgi->checkbox_group(
	-name   => 'filters',
	-values => ['pseudoknots only',],
#    [ 'pseudoknots only', 'lowest mfe only', 'longest window', 'less than mean mfe', 'less than mean zR' ],
	-defaults => ['pseudoknots only',],
#    -rows     => 3,
#    -columns  => 3
      );
    $vars->{species} = $species;
    $vars->{nicespecies} = $species;
    $vars->{nicespecies} =~ s/_/ /g;
    $vars->{nicespecies} = ucfirst($vars->{nicespecies});
    $vars->{algorithm} = $algorithm;

    $vars->{hidden_species} = $cgi->hidden(-name => 'hidden_species', -value => $species);
    $vars->{hidden_algorithm} = $cgi->hidden( -name => 'hidden_algorithm', -value => $algorithm);
    $vars->{filter_submit} = $cgi->submit( -name => 'filter_third', -value => 'Filter PRFdb');
    $template->process( 'secondfilterform.html', $vars ) or
	Print_Template_Error($template), die;
}

sub Perform_Third_Filter {
    my @filters   = $cgi->param('filters');
    my $species = $cgi->param('hidden_species');
    my $algorithm = $cgi->param('hidden_algorithm');
    my $max_mfe = $cgi->param('choose_mfe');
    my $seqlength = $vars->{seqlength};
    my $limit = $cgi->param('choose_limit');
    my $format = $cgi->param('output_format');
    $vars->{output_format} = $format;
    $vars->{choose_limit} = $limit;
    $vars->{species} = $species;
    $vars->{algorithm} = $algorithm;
    $vars->{hidden_species} = $cgi->hidden(-name =>'hidden_species', -value => $species);
    $vars->{hidden_algorithm} = $cgi->hidden(-name => 'hidden_algorithm', -value => $algorithm);

    my $columns;
    if ($format eq 'tab delimited') {
	$columns = '*';
    }
    else {
	$columns = 'id, accession, start';
    }
    
    my $statement = qq(SELECT $columns FROM mfe WHERE species = '$species' AND algorithm = '$algorithm' AND seqlength = '$seqlength' AND );
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
    if ($format eq 'text') {
	foreach my $datum (@{$info}) {
	    $cgi->param(-name => 'id', -value => $datum->[0]);
	    $cgi->param(-name => 'accession', -value => $datum->[1]);
	    $cgi->param(-name => 'slipstart', -value => $datum->[2]);
	    Print_Detail_Slipsite();
	}
#	  $vars->{id} = $datum->[0];
#	  $vars->{genome_id} = $datum->[1];
#	  $vars->{accession} = $datum->[2];
#      #species: saccharomyces_cerevisiae = $datum->[3];
#      #algorithm: pknots = $datum->[4];
#	  $vars->{start} = $datum->[5];
#	  $vars->{slipsite} = $datum->[6];
#	  $vars->{seqlength} = $datum->[7];
#	  $vars->{sequence} = $datum->[8];
#	  $vars->{output} = $datum->[9];
#	  $vars->{parsed} = $datum->[10];
#	  $vars->{parens} = $datum->[11];
#	  $vars->{mfe} = $datum->[12];
#	  $vars->{pairs} = $datum->[13];
#	  $vars->{knotp} = $datum->[14];
#	  $vars->{barcode} = $datum->[15];
#	  $vars->{lastupdate} = $datum->[16];
#	  $template->process('filter_finished.html', $vars ) or
#	    Print_Template_Error($template), die;
#	}
#	$template->process( 'thirdfilter.html', $vars ) or
#	  Print_Template_Error($template), die;
#  } ## end if the format is 'text'
  }	
    else {  ## Then the format is tab delimited
#		print $download_header;
	print "Species\tAccession\tAlgorithm\tSequence Length\tStart\tSlipsite\tMFE\tBase Pairs\tPseudoknotted\tSequence\tPknots output\tParsed output\tParenthesis output\tBarcode\n";
	foreach my $datum (@{$info}) {
	    print "$datum->[3]\t$datum->[2]\t$datum->[4]\t$datum->[7]\t$datum->[5]\t$datum->[6]\t$datum->[12]\t$datum->[13]\t$datum->[14]\t$datum->[8]\t$datum->[9]\t$datum->[11]\t$datum->[15]\n";
	}
    }
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
    my $snp_statement = qq(SELECT id, cluster_id, location, alleles FROM snp WHERE gene_acc = ?);
    my $snp_data = $db->MySelect({ statement => $snp_statement,
				   vars => [$accession],
				   type => 'list_of_hashes' });
    
    my $snp_struct = {};
    foreach my $snp_row (@{$snp_data}) {
	my $snp_start = $snp_row->{location};
	my $snp_end = '';
	if ($snp_start =~ /\.\./) {
	    ($snp_start, $snp_end) = split(/\.\./, $snp_start);
	    $snp_struct->{($snp_start + $start_padding_bases)} = ($snp_end + $start_padding_bases);
	    $snp_struct->{($snp_end + $start_padding_bases)} = $snp_row;
	} else {
	    $snp_struct->{($snp_start + $start_padding_bases)} = $snp_row;
	}
    }
    for my $d ( 0 .. $#$slipsite_positions ) {
	$corrected_slipsites[$d] = $slipsite_positions->[$d] + $start_padding_bases;    ## Lazy
    }
    ## If you make an array of stems, keep this in mind.
    
    my $first_pass  = '';
    my @codon_array = ();
    
    while ($start_padding_bases >= 0) { unshift(@seq_array, '&nbsp;'), $start_padding_bases--;}
    my $new_seq_length = $#seq_array;
    my $end_padding_bases = $new_seq_length % 3;
  while ($end_padding_bases >= 0) { push(@seq_array, '&nbsp;'), $end_padding_bases--; }
    my $codon_string = '';
    my $minus_one_stop_switch = 'off';

    for my $seq_counter (0 .. $#seq_array) {

	if ($minus_one_stop_switch eq 'on') {
	    if ((( $seq_counter % 3) == 2) and $seq_array[$seq_counter] eq 'T' and ($seq_array[$seq_counter + 1] eq 'A') and ($seq_array[$seq_counter + 2] eq 'A')) {
		$seq_array[$seq_counter] = qq(<strong><font color = "Orange">$seq_array[$seq_counter]</font></strong>);
		$seq_array[$seq_counter + 1] = qq(<strong><font color = "Orange">$seq_array[$seq_counter + 1]</font></strong>);
		$seq_array[$seq_counter + 2] = qq(<strong><font color = "Orange">$seq_array[$seq_counter + 2]</font></strong>);
		$minus_one_stop_switch = 'off';
	    }
	    elsif ((($seq_counter % 3) == 2) and $seq_array[$seq_counter] eq 'T' and ($seq_array[$seq_counter + 1] eq 'G') and ($seq_array[$seq_counter + 2] eq 'A')) {
		$seq_array[$seq_counter] = qq(<strong><font color = "Orange">$seq_array[$seq_counter]</font></strong>);
		$seq_array[$seq_counter + 1] = qq(<strong><font color = "Orange">$seq_array[$seq_counter + 1]</font></strong>);
		$seq_array[$seq_counter + 2] = qq(<strong><font color = "Orange">$seq_array[$seq_counter + 2]</font></strong>);
		$minus_one_stop_switch = 'off';
	    }
	    elsif ((($seq_counter % 3) == 2) and $seq_array[$seq_counter] eq 'T' and ($seq_array[$seq_counter + 1] eq 'A') and ($seq_array[$seq_counter + 2] eq 'G')) {
		$seq_array[$seq_counter] = qq(<strong><font color = "Orange">$seq_array[$seq_counter]</font></strong>);
		$seq_array[$seq_counter + 1] = qq(<strong><font color = "Orange">$seq_array[$seq_counter + 1]</font></strong>);
		$seq_array[$seq_counter + 2] = qq(<strong><font color = "Orange">$seq_array[$seq_counter + 2]</font></strong>);
		$minus_one_stop_switch = 'off';
	    }
	}    ## If the minus one stop switch is on.

	if ($seq_counter >= $corrected_orf_start and ($seq_counter < ($corrected_orf_start + 3))) {
	    $seq_array[$seq_counter] = qq(<strong><font color = "Green">$seq_array[$seq_counter]</font></strong>);
	}    ## End if the current bases are a part of the start codon
	if ($seq_counter >= ($corrected_orf_stop - 2) and ($seq_counter < ($corrected_orf_stop + 1))) {
	    $seq_array[$seq_counter] = qq(<strong><font color = "Red">$seq_array[$seq_counter]</font></strong>);
	}    ## End if the current bases are a part of a stop codon

	if (defined($snp_struct->{$seq_counter})) {
	    if ($snp_struct->{$seq_counter} !~ /HASH/) {
		my $snp_end = $snp_struct->{$seq_counter};
		my $link = qq(http://www.ncbi.nlm.nih.gov/sites/entrez?db=snp&cmd=search&term=$snp_struct->{$snp_end}->{cluster_id});
		$seq_array[$seq_counter] = qq(<a class="snp" href=$link title="View dbSNP:$snp_struct->{$snp_end}->{cluster_id} with alleles $snp_struct->{$snp_end}->{alleles} at NCBI" rel="external" target="_blank">$seq_array[$seq_counter]);
		$seq_array[$snp_struct->{$seq_counter}] = qq($seq_array[$snp_struct->{$seq_counter}]</a>);
		delete $snp_struct->{$snp_end};
		delete $snp_struct->{$seq_counter};
	    } 
	    else {
		my $link = qq(http://www.ncbi.nlm.nih.gov/sites/entrez?db=snp&cmd=search&term=$snp_struct->{$seq_counter}->{cluster_id});
		$seq_array[$seq_counter] = qq(<a class="snp" href=$link title="View dbSNP:$snp_struct->{$seq_counter}->{cluster_id} with alleles $snp_struct->{$seq_counter}->{alleles} at NCBI" rel="external" target="_blank">$seq_array[$seq_counter]</a>);
		delete $snp_struct->{$seq_counter};
	    }
	}

    for my $c (0 .. $#corrected_slipsites) {
	if ($seq_counter >= $corrected_slipsites[$c] and $seq_counter < $corrected_slipsites[$c] + 7) {
	    $seq_array[$seq_counter] = qq(<strong><a href="$base/detail?accession=$accession&slipstart=$slipsite_positions->[$c]" title="View the details for $accession at posisition $slipsite_positions->[$c]"><font color = "Blue">$seq_array[$seq_counter]</font></a></strong>);
        $minus_one_stop_switch = 'on';
	}
    }    ## End foreach slipstart

	if (($seq_counter % 3) == 0) {
	    if ($seq_counter != 0) {
		push(@codon_array, $codon_string);
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
	if (($codon_count % 15) == 0) {
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
	    
	    $first_pass = join('', $first_pass, $codon, "$end_base_string<br>\n$start_base_string");
	} 
	else {
	    $first_pass = join('', $first_pass, $codon, ' ');
	}
    }  ## End foreach codon
    my $suffix = qq(&nbsp;$total_seq_length);
    $first_pass = join('', $first_pass, $suffix);
    return ($first_pass);
}

sub Get_Accession_Info {
    my $accession = shift;
    $accession = lc($accession) unless ($accession =~ /^SGDID/);
    my $query_statement = qq(SELECT id, species, genename, comment, orf_start, orf_stop, lastupdate, mrna_seq, omim_id FROM genome WHERE accession = ?);
    my $entry = $db->MySelect({
	statement => $query_statement,
	vars => [$accession],
	type => 'row', });
    my $data = {
	id => $entry->[0],
	species => $entry->[1],
	genename => $entry->[2],
	comment => $entry->[3],
	orf_start => $entry->[4],
	orf_stop => $entry->[5],
	lastupdate => $entry->[6],
	mrna_seq => $entry->[7],
    };
    my $slipsite_structure_count = $db->MySelect({
	statement => "SELECT count(distinct(start)), count(distinct(id)) FROM mfe WHERE accession = ?",
	vars => [$accession],
	type => 'row',});
    $data->{slipsite_count}  = $slipsite_structure_count->[0];
    $data->{structure_count} = $slipsite_structure_count->[1];
    return ($data);
}

sub Print_Blast {
    my $is_local = shift;
    my $input_sequence = shift;
    my $blast = new PRFBlast;
    my $accession;
    my $start;
    my $sequence;
    if (defined($input_sequence)) {
	$sequence = $input_sequence;
    }
    else {
	$accession = $cgi->param('accession');
	$start = $cgi->param('start');
	if (defined($start)) {
	    $sequence = $db->MySelect({
		statement => "SELECT sequence FROM mfe WHERE accession = ? AND start = ? LIMIT 1",
		vars => [$accession,$start],
		type => 'single',});
	}
	else {
	    $sequence = $db->MySelect({
		statement => "SELECT mrna_seq FROM genome WHERE accession = ? LIMIT 1",
		vars => [$accession],
		type => 'single',});
	}
    }

    $sequence =~ tr/Uu/Tt/;
    $sequence =~ s/\s//g;
    print "TELL ME: $sequence<br>\n";
    
    my $local_info = $blast->Search($sequence, $is_local);
    
    my (%hit_names, %accessions, %lengths, %descriptions, %scores, %significances, %bitses);
    my (%hsps_evalue, %hsps_expect, %hsps_gaps, %hsps_querystring, %hsps_homostring, %hsps_hitstring, %hsps_numid, %hsps_numcon, %hsps_length, %hsps_score);
    if (!defined($local_info->{hits})) {
	print "There were no hits in the blast database.<br>\n";
	return(0);
    }
    my @hits = @{$local_info->{hits}};
    foreach my $c (0 .. $#hits) {
	$hit_names{$c} = $local_info->{hits}->[$c]->{hit_name};
	$accessions{$c} = $local_info->{hits}->[$c]->{accession};
	$lengths{$c} = $local_info->{hits}->[$c]->{length};
	$descriptions{$c} = $local_info->{hits}->[$c]->{description};
	$scores{$c} = $local_info->{hits}->[$c]->{score};
	$hit_names{$c} = $local_info->{hits}->[$c]->{hit_name};
	$significances{$c} = $local_info->{hits}->[$c]->{significance};
	$bitses{$c} = $local_info->{hits}->[$c]->{bits};
	
	my @hsps = ();
	if (defined(@{$local_info->{hits}->[$c]->{hsps}})) {
	    @hsps = @{$local_info->{hits}->[$c]->{hsps}};
	}
	
	foreach my $d (0 .. $#hsps) {
	    $hsps_evalue{$c}{$d} = $local_info->{hits}->[$c]->{hsps}->[$d]->{evalue};
	    $hsps_expect{$c}{$d} = $local_info->{hits}->[$c]->{hsps}->[$d]->{expect};
	    $hsps_gaps{$c}{$d} = $local_info->{hits}->[$c]->{hsps}->[$d]->{gaps};
	    $hsps_querystring{$c}{$d} = $local_info->{hits}->[$c]->{hsps}->[$d]->{query_string};
	    $hsps_homostring{$c}{$d} = $local_info->{hits}->[$c]->{hsps}->[$d]->{homology_string};
	    $hsps_hitstring{$c}{$d} = $local_info->{hits}->[$c]->{hsps}->[$d]->{hit_string};
	    $hsps_numid{$c}{$d} = $local_info->{hits}->[$c]->{hsps}->[$d]->{num_identical};
	    $hsps_numcon{$c}{$d} = $local_info->{hits}->[$c]->{hsps}->[$d]->{num_conserved};
	    $hsps_length{$c}{$d} = $local_info->{hits}->[$c]->{hsps}->[$d]->{length};
	    $hsps_score{$c}{$d} = $local_info->{hits}->[$c]->{hsps}->[$d]->{score};
	}
    }
    
    $vars->{query_length} = $local_info->{query_length};
    $vars->{num_hits} = $local_info->{num_hits};
    $vars->{hit_names} = \%hit_names;
    $vars->{accessions} = \%accessions;
    $vars->{lengths} = \%lengths;
    $vars->{descriptions} = \%descriptions;
    $vars->{scores} = \%scores;
    $vars->{hit_names} = \%hit_names;
    $vars->{significances} = \%significances;
    $vars->{bitses} = \%bitses;
    $vars->{hsps_evalue} = \%hsps_evalue;
    $vars->{hsps_expect} = \%hsps_expect;
    $vars->{hsps_gaps} = \%hsps_gaps;
    $vars->{hsps_querystring} = \%hsps_querystring;
    $vars->{hsps_homostring} = \%hsps_homostring;
    $vars->{hsps_hitstring} = \%hsps_hitstring;
    $vars->{hsps_numid} = \%hsps_numid;
    $vars->{hsps_numcon} = \%hsps_numcon;
    $vars->{hsps_length} = \%hsps_length;
    $vars->{hsps_score} = \%hsps_score;
    
    $template->process('blast.html', $vars) or
	Print_Template_Error($template), die;
}

sub Check_Landscape {
    my $accession = $cgi->param('accession');
    my $pic = new PRFGraph({accession => $accession});
    
    my $filename = $pic->Picture_Filename({type => 'landscape',});
    if (!-r $filename) {
	$pic->Make_Landscape();
    }
    my $url = $pic->Picture_Filename({type => 'landscape', url => 'url'});
    $vars->{picture} = $url;
    $vars->{accession} = $accession;
    my $stmt = qq(SELECT orf_start, orf_stop FROM genome WHERE accession = '$accession');
    my $tmp  = $db->MySelect({
	statement => $stmt,
	type => 'row'});
    $vars->{start} = $tmp->[0];
    $vars->{stop} = $tmp->[1];
    $template->process('landscape.html', $vars) or
	Print_Template_Error($template), die;
}

sub Cloud {
    my $species = $cgi->param('species');
    $species = 'saccharomyces_cerevisiae' if (!defined($species));
    my @filters = $cgi->param('cloud_filters');
    my $slipsites = $cgi->param('slipsites');
    $slipsites = 'all' if (!defined($slipsites));
    my $seqlength = $cgi->param('seqlength');
    $seqlength = 100 if (!defined($seqlength));
    if (!defined($seqlength)) { $seqlength = ['100'] };		
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
    $suffix .= "-${seqlength}";
    my $cloud_output_filename = $cloud->Picture_Filename({type => 'cloud', species => $species, suffix => $suffix,});
    
    my $cloud_url = $cloud->Picture_Filename({type => 'cloud', species => $species, url => 'url', suffix => $suffix,});
    $cloud_url = $basedir . '/' . $cloud_url;
    
    if (!-f $cloud_output_filename) {
	my ($points_stmt, $averages_stmt, $points, $averages);
	if ($species eq 'all') {
	    $points_stmt = qq(SELECT mfe.mfe, boot.zscore, mfe.accession, mfe.knotp, mfe.slipsite, mfe.start FROM mfe, boot WHERE boot.zscore IS NOT NULL AND mfe.mfe > -80 AND mfe.mfe < 5 AND boot.zscore > -10 AND boot.zscore < 10 AND mfe.seqlength = $seqlength AND mfe.id = boot.mfe_id AND );
	    $averages_stmt = qq(SELECT avg(mfe.mfe), avg(boot.zscore), stddev(mfe.mfe), stddev(boot.zscore) FROM mfe, boot WHERE boot.zscore IS NOT NULL AND mfe.mfe > -80 AND mfe.mfe < 5 AND boot.zscore > -10 AND boot.zscore < 10 AND mfe.seqlength = $seqlength AND mfe.id = boot.mfe_id AND );
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
	    $points_stmt = qq(SELECT mfe.mfe, boot.zscore, mfe.accession, mfe.knotp, mfe.slipsite, mfe.start, genome.genename FROM mfe, boot, genome WHERE boot.zscore IS NOT NULL AND mfe.mfe > -80 AND mfe.mfe < 5 AND boot.zscore > -10 AND boot.zscore < 10 AND mfe.species = ? AND mfe.seqlength = $seqlength AND mfe.id = boot.mfe_id AND );
	    $averages_stmt = qq(SELECT avg(mfe.mfe), avg(boot.zscore), stddev(mfe.mfe), stddev(boot.zscore) FROM mfe, boot WHERE boot.zscore IS NOT NULL AND mfe.mfe > -80 AND mfe.mfe < 5 AND boot.zscore > -10 AND boot.zscore < 10 AND mfe.species = ? AND mfe.seqlength = $vars->{seqlength} AND mfe.id = boot.mfe_id AND );
	    
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
	    
	    $points_stmt .= " mfe.genome_id = genome.id";
	    $averages_stmt =~ s/AND $//g;
	    $points = $db->MySelect({statement => $points_stmt, vars => [$species]});
	    $averages = $db->MySelect({
		statement => $averages_stmt,
		vars => [$species],
		type => 'row', });
	}
	my $cloud_data;
	my $args;
	if (defined($pknots_only)) {
	    $args = {
		seqlength => $seqlength,
		species => $species,
		points => $points,
		averages => $averages,
		filename => $cloud_output_filename,
		url => $base,
		pknot => 1,
		slipsites => $slipsites
	    };
	}
	else {
	    $args = {
		seqlength => $seqlength,
		species => $species,
		points => $points,
		averages => $averages,
		filename => $cloud_output_filename,
		url => $base,
		slipsites => $slipsites,
	    };
	}
	$cloud_data = $cloud->Make_Cloud($args);
    }
    $vars->{species} = $species;
    $vars->{nicespecies} = $species;
    $vars->{nicespecies} =~ s/_/ /g;
    $vars->{nicespecies} = ucfirst($vars->{nicespecies});
    $vars->{cloud_file} = $cloud_output_filename;
    $vars->{cloud_url} = $cloud_url;
    $vars->{pknots_only} = $pknots_only;
    $vars->{seqlength} = $seqlength;
    
    $vars->{startoverlayform} = $cgi->startform(-action => "$base/overlaysearch_perform");
    $vars->{overlayquery} = $cgi->textfield(-name => 'overlayquery', -size => 20);
    $vars->{overlaysubmit} = $cgi->submit(-name => 'search overlay', -value => 'Overlay');
    
    if ($slipsites ne 'all') {
	$vars->{slipsites} = $slipsites;
    }
    $vars->{map_url} = "$vars->{cloud_url}" . '.map'; 
    $vars->{map_file} = "$vars->{cloud_file}" . '.map';
    $template->process('cloud.html', $vars) or
	Print_Template_Error($template), die;
    open (OUT, "<$vars->{map_file}");
    while (my $l = <OUT>) { print $l };
    close (OUT);
}

sub Download_All {
    my $species = shift;
    my $table = shift;
    
    my $filename = qq(${table}_${species}.csv);
    print $download_header;
    print "$filename\n\n";
    
    my $keys = $db->MySelect("DESCRIBE $table");
    my $key_string = '';
    foreach my $k (@{$keys}) {
	$key_string .= "$k->[0], ";
    }
    $key_string =~ s/, $//g;
    print "$key_string\n";
    
    
    my $stmt = qq(SELECT * FROM $table);
    if ($species ne 'all') {
	$stmt .= " WHERE species = '$species'";
    }
    my $big_stuff = $db->MySelect($stmt);
    my $stuff_string = '';
    foreach my $stuff (@{$big_stuff}) {
	foreach my $item (@{$stuff}) {
	    $stuff_string .= "$item, ";
	}
	$stuff_string =~ s/, $//g;
	print "$stuff_string\n";
    }
}

sub Download_Sequence {
    my $accession = shift;
    my $stmt = qq(SELECT comment,mrna_seq FROM genome WHERE accession = ?);
    my $seq = $db->MySelect({
	statement => $stmt,
	vars => [$accession],
	type => 'row', });
    my @tmp = split(//, $seq->[1]);
    my $filename = qq(${accession}.fasta);
    $filename =~ s/SGDID://g;
    print $download_header;
    print "$filename\n\n";
    print ">$accession $seq->[0]";
    foreach my $c (0 .. $#tmp) {
	print "\n" if (($c %80) == 0);
	print $tmp[$c];
    }
}

sub Download_PNG {
    my $accession = shift;
    my $mfeid = shift;
    my $pic = new PRFGraph({accession => $accession});
    my $filename = $pic->Picture_Filename({type => 'feynman',});
    $filename =~ s/\.svg//g;
    $filename .= "-$mfeid.svg";
    my $tmp_download_header = qq(Content-type: image/png\n\n);
#Content-Disposition:attachment;filename=);
    print $tmp_download_header;
    my $output_filename = qq($accession-$mfeid.png);
#    print "$output_filename\n\n";
    my $fh = new File::Temp();
    my $fname = $fh->filename;
    my $command = qq(/usr/bin/rsvg-convert -d 1080 -p 1080 $filename);
    open (CONVERT, "$command |");
    my $buffer = '';
    use constant BUFFER_SIZE => 1024;
    while (read(CONVERT, $buffer, BUFFER_SIZE)) {
	print $buffer;
    }
    close CONVERT;
}

sub Download_Bpseq {
    my $id = shift;
    my $fh = \*STDOUT;
    my $ref = ref($fh);
    my $filename = qq(${id}.bpseq);
    print $download_header;
    print "$filename\n\n";
    $db->Mfeid_to_Bpseq($id, $fh);
}

sub Download_Subsequence {
    my $id = shift;
    my $stmt = qq(SELECT genome.comment,mfe.accession,mfe.sequence,mfe.start FROM genome,mfe WHERE mfe.id = ? and mfe.genome_id=genome.id);
    my $seq = $db->MySelect({statement => $stmt, vars => [$id], type => 'row'});
    my @tmp = split(//, $seq->[2]);
    my $filename = qq($seq->[1]_$seq->[3].fasta);
    $filename =~ s/SGDID://g;
    print $download_header;
    print "$filename\n\n";
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
    my $filename = qq($seq->[1]_$seq->[3].parens);
    $filename =~ s/SGDID://g;
    print $download_header;
    print "$filename\n\n";
    print "#$seq->[1] starting at $seq->[3]: $seq->[0]
$seq->[2]
";
}

sub Download_Parsed {
    my $id = shift;
    my $stmt = qq(SELECT genome.comment,mfe.accession,mfe.parsed,mfe.start FROM genome,mfe WHERE mfe.id = ? and mfe.genome_id=genome.id);
    my $seq = $db->MySelect({ statement => $stmt, vars => [$id], type =>'row'});
    my $filename = qq($seq->[1]_$seq->[3].parsed);
    $filename =~ s/SGDID://g;
    print $download_header;
    print "$filename\n\n";
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

sub Start_SNP_Filter {
    my $species;
    if (defined($config->{snp_species_limit})) {
	$species = [$config->{snp_species_limit}];
    } else {
	$species = $db->MySelect({statement => "SELECT distinct(species) from genome", 
				  type => 'flat'});
    }
    #  unshift (@{$species}, 'All');
    $vars->{startform} = $cgi->start_multipart_form(-action => "$base/snpfilter",
						    -name   => 'snpform',);
    my %labels = ();
    foreach my $value (@{$species}) {
	my $long_name = $value;
	$long_name =~ s/_/ /g;
	$long_name = ucfirst($long_name);
	$labels{$value} = $long_name;
    }
    $vars->{species} = $cgi->popup_menu(-name => 'species',
					-values => $species,
					-labels => \%labels,
					-default => 'homo_sapiens', );
    
    $vars->{frameshift} = $cgi->popup_menu(-id => 'frameshift',
					   -name => 'frameshift',
					   -values => ['s', 'd', 'sdf', 'n', 'null'],
					   -labels  => {'s' => 'slippery site',
							'd' => 'stem',
							'sdf' => 'PRF signal',
							'n' => 'NOT PRF signal',
							'null' => 'No SNPs'},
					   -default => 's',
					   -onChange => 'stemdigit()',);
    $vars->{snp_digit} = $cgi->textfield(-name  => 'snp_digit',
					 -size  => '5',
					 -maxlength => '10',);
    $vars->{gene} = $cgi->checkbox(-name    => 'gene', 
					-value   => 'off',
					-label   => '', 
					-onClick => 'toggleinput()');
    $vars->{gene_toggle} = $cgi->radio_group(-name    => 'genetoggle',
					     -values  => ['text', 'upload'],
					     -default => 'text', 
					     -labels  => {'text' => 'Text Input', 'upload' => 'Upload List',},
					     -onclick => 'togglegene(this)',);
    $vars->{gene_text} = $cgi->textarea(-name => 'gene_text',
					-rows => 12,
					-columns => 100,);
    $vars->{gene_upload} = $cgi->filefield(-name => 'gene_upload',
					   -default => '',
					   -size => 25,);
    $vars->{filter_submit} = $cgi->submit(-name => 'snpfilter', -value => 'Filter PRFdb for SNPs');
    $template->process('snpform.html', $vars) or
	Print_Template_Error($template), die;
}

sub Generate_Pictures {
    my $slipsites = ['all', 'AAAUUUA', 'UUUAAAU', 'AAAAAAA', 'UUUAAAA', 'UUUUUUA', 'AAAUUUU', 'UUUUUUU', 'UUUAAAC', 'AAAAAAU', 'AAAUUUC', 'AAAAAAC', 'GGGUUUA', 'UUUUUUC', 'GGGAAAA', 'CCCUUUA', 'CCCAAAC', 'CCCAAAA', 'GGGAAAU', 'GGGUUUU', 'GGGAAAC', 'CCCUUUC', 'CCCUUUU', 'GGGAAAG', 'GGGUUUC',];
    my @pknot = ('yes','no');
    foreach my $seqlen (@{$config->{seqlength}}) {
	foreach my $pk (@pknot) {
	    foreach my $spec (@species_values) {
		foreach my $slip (@{$slipsites}) {
		    
		    print "Generating picture for $spec slipsite: $slip knotted: $pk seqlength: $seqlen<br>\n";
		    $cgi->param(-name => 'seqlength', -value => $seqlen);
		    $cgi->param(-name => 'species', -value => $spec);
		    $cgi->param(-name => 'slipsites', -value => $slip);
		    if ($pk eq 'yes') {
			$cgi->param(-name => 'cloud_filters', -value => ['pseudoknots only']);
		    }
		    else {
			$cgi->param(-name => 'cloud_filters', -value => []);
		    }
		    Cloud();
		} ## Foreach slipsite
	    } ## foreach species
	}  ## if pknotted
    } ## seqlengths
}

sub Remove_Duplicates {
    my $accession = shift;
    my $info = $db->MySelect("SELECT id,start,seqlength,algorithm FROM mfe WHERE accession = '$accession'");
    my @duplicate_ids;
    my $dups = {};
    foreach my $datum (@{$info}) {
	my $id = $datum->[0];
	my $start = $datum->[1];
	my $seqlength = $datum->[2];
	my $alg = $datum->[3];

	if (!defined($dups->{$start})) {  ## Start
	    $dups->{$start} = {};
	}
	
	if (!defined($dups->{$start}->{$seqlength})) {
	    $dups->{$start}->{$seqlength} = {};
	    $dups->{$start}->{$seqlength}->{pknots} = [];
	    $dups->{$start}->{$seqlength}->{nupack} = [];
	    $dups->{$start}->{$seqlength}->{hotknots} = [];
	}
	my @array = @{$dups->{$start}->{$seqlength}->{$alg}};
	push(@array, $id);
	$dups->{$start}->{$seqlength}->{$alg} = \@array;
    }
    
    foreach my $st (sort keys %{$dups}) {
	foreach my $len (sort keys %{$dups->{$st}}) {
	    my @nupack = @{$dups->{$st}->{$len}->{nupack}};
	    my @pknots = @{$dups->{$st}->{$len}->{pknots}};
	    my @hotknots = @{$dups->{$st}->{$len}->{hotknots}};
	    shift @nupack;
	    shift @pknots;
	    shift @hotknots;
	    foreach my $id (@nupack) {
		$db->MyExecute("DELETE FROM mfe WHERE id = '$id'");
	    }
	    foreach my $id (@pknots) {
		$db->MyExecute("DELETE FROM mfe WHERE id = '$id'");
	    }
	    foreach my $id (@hotknots) {
		$db->MyExecute("DELETE FROM mfe WHERE id = '$id'");
	    }
	}
    }
}
