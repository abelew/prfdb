#!/usr/bin/perl -w
use strict;
use CGI qw/:standard :html3/;
use CGI::Carp qw(fatalsToBrowser carpout);
use Template;
use lib "lib";
use PRFConfig;
use PRFdb;
use RNAMotif_Search;

my $config = $PRFConfig::config;                             ## All configuration information exists here
chdir($config->{basedir});                                   ## Change into the home directory of the folder daemon
my $db = new PRFdb;                                          ## Set up a database configuration
my $fun = new CGI;                                           ## Start a new CGI object
print $fun->header;                                          ## Immediately print a header
my $template = new Template($config);                        ## And a new Template
my $base = "http://" . $ENV{HTTP_HOST} . $ENV{SCRIPT_NAME};

#### MAIN BLOCK OF CODE RIGHT HERE
if ($fun->path_info() eq '/start' || $fun->path_info() eq '') {
    Frontpage();
}
elsif ($fun->path_info() eq '/explore') {
    Explore();
}
elsif ($fun->path_info() eq '/dig') {
    Dig();
}
elsif ($fun->path_info() eq '/examine') {
    Examine();
}
elsif ($fun->path_info() eq '/pubqueue_add') {
    Pubqueue_Add();
}
elsif ($fun->path_info() eq '/clean') {
    RNAMotif_Search->Remove_Old();
}
print $fun->endform , $fun->end_html;
####  END MAIN BLOCK OF CODE

sub Frontpage {
  my $vars = {
      startform => $fun->startform(-action=>"$base/explore"),
      species => $fun->popup_menu(-name=>'species',
				  -values=>['homo sapiens'],),
      accession => $fun->textfield(-name => 'accession', -size => 40),
      search => $fun->textfield(-name => 'search', -size => 40),
      submit => $fun->submit(),
  };
  my $input = 'start.html';
  $template->process($input, $vars) || die $template->error();
}

sub Explore {
  No_Species() unless($fun->param('species') ne '');
  my $species = $fun->param('species');
  $species =~ s/\ /_/g;

  if ($fun->param('accession') eq '' and $fun->param('search') eq '') {
    No_Accession();
  }
  elsif($fun->param('accession') eq '') {  ## Then perform a keyword search...
    Keyword_Search($species, $fun->param('search'));
  }
  else {
    Dig($species, $fun->param('accession'));
  }
}

sub Accession_Search {
  my $species = shift;
  my $accession = shift;
  my $vars = {
             };
  my $input = 'accession_search.html';
  $template->process($input, $vars) or die $template->error();
}

sub Keyword_Search {
  my $species = shift;
  my $keyword = shift;
  my $return = {};
  my $hits = $db->Keyword_Search($species, $keyword);
  foreach my $hit (keys %{$hits}) {
    $hits->{$hit} =~ s/^Homo sapiens//g;
    $hits->{$hit} =~ s/\(.*//g;
  }
  my $next_step = "$base/dig";
  my $vars = {
              startform => $fun->startform(-action => $next_step),
              next_step => $next_step,
              species => $species,
              # submit => $fun->submit(),
              hits => $hits,
             };
  my $input = 'keyword.html';
  $template->process($input, $vars) or die $template->error();
}

sub No_Accession {
  print "You gave no accession.\n";
  exit;
}

sub Dig {
    my $sp = shift;
    my $ac = shift;
    my $filename = '';
    my @params = $fun->param();
    my ($species, $accession);
    $species = (defined($sp)) ? $sp : $fun->param('species');
    $accession = (defined($ac)) ? $ac : $fun->param('accession');
    my ($nupack_structures, $pknots_structures, $boot_structures);
    
    ## Check to see if this has already been generated.
    my $slipsites_data = $db->Get_RNAmotif($species, $accession);
    my $sequence = $db->Get_Sequence($species, $accession);
    my $need_search = 0;
    unless ($slipsites_data) {
	$need_search = 1;
	my $stemsearch = new RNAMotif_Search;
	$slipsites_data = $stemsearch->Search($sequence, $config->{max_stem_length});
	$db->Put_RNAmotif($species, $accession, $slipsites_data);
    }
    my $slipsites = {};
    my $filenames = {};
    foreach my $k (keys %{$slipsites_data}) {
	$slipsites->{$k} = $slipsites_data->{$k}{start};
	$filenames->{$k} = $slipsites_data->{$k}{filename} if ($need_search);
    }
    
    my $length = length($sequence);
    my $ratio = $length / 80;
    my @diagram = ();
    
    for my $c (0 .. 79) { $diagram[$c] = 0; }
    for my $start (keys %{$slipsites}) {
	my $pos = $start / $ratio;
	$diagram[$pos] = $diagram[$pos] + 1;
    }
    for my $c (0 .. 79) { $diagram[$c] = '-' if ($diagram[$c] eq '0'); }
    
    
    ## Gather information
    my $nupack_structures;
    my ($nu_accessions, $nu_lengths, $nu_starts, $nu_mfes, $nu_parens, $nu_parses, $nu_knots);
    if ($PRFConfig::config->{do_nupack}) {
	$nupack_structures = $db->Get_Nupack($species, $accession);
    if (defined($nupack_structures) or scalar(%{$nupack_structures}) ne '0') {  ## Already have folded structures for the given accession
	foreach my $id (keys %{$nupack_structures}) {
        ## $k is an id in the database, of which there should be 1 for every start site at this locus.
	    $nu_accessions->{$id} = $nupack_structures->{$id}{accession};
	    $nu_lengths->{$id} = $nupack_structures->{$id}{seqlength};
	    $nu_starts->{$id} = $nupack_structures->{$id}{start};
	    $nu_mfes->{$id} = $nupack_structures->{$id}{mfe};
	    $nu_parens->{$id} = $nupack_structures->{$id}{paren_output};
	    $nu_parses->{$id} = $nupack_structures->{$id}{parsed};
	    $nu_parses->{$id} =~ s/\s+//g;
	    $nu_parses->{$id} =~ s/^.{1}//g;  ## I have no clue why there is a leading .
	    $nu_knots->{$id} = $nupack_structures->{$id}{knotp};
	} 
    } 
    else {  ## Do not have nupack structures
	    Ask_For_Fold('nupack', $species, $accession);
	}
    } ## End do_nupack


    my $pknots_structures;
    my ($pk_accessions, $pk_lengths, $pk_starts, $pk_mfes, $pk_parens, $pk_parses, $pk_knots);
    if ($PRFConfig::config->{do_pknots}) {
	$pknots_structures = $db->Get_Pknots05($species, $accession);
	if (defined($pknots_structures) or scalar(%{$pknots_structures}) ne '0') {  ## Already have folded structures for the given accession
	    foreach my $id (keys %{$pknots_structures}) {
		$pk_accessions->{$id} = $pknots_structures->{$id}{accession};
		$pk_lengths->{$id} = $pknots_structures->{$id}{seqlength};
		$pk_starts->{$id} = $pknots_structures->{$id}{start};
		$pk_mfes->{$id} = $pknots_structures->{$id}{mfe};
		$pk_parens->{$id} = $pknots_structures->{$id}{paren_output};
		$pk_parses->{$id} = $pknots_structures->{$id}{parsed};
		$pk_knots->{$id} = $pknots_structures->{$id}{knotp};
	    }
	}
	else {  ## Do not have pknots structures
	    Ask_For_Fold('pknots', $species, $accession);
	}
    } ## End do_pknots
    
    
    my ($bo_accessions, $bo_starts, $bo_iterations, $bo_rand_method, $bo_mfe_method, $bo_mfe_mean, $bo_mfe_sd, $bo_mfe_se, $bo_pairs_mean, $bo_pairs_mfe, $bo_pairs_sd, $bo_pairs_se);
    my $boot_info = $db->Get_Boot($species, $accession);
    if (defined($boot_info) or scalar(%{$boot_info}) ne '0') {  ## Already have folded structures for the given accession
	foreach my $id (keys %{$boot_info}) {
	    $bo_accessions->{$id} = $boot_info->{$id}{accession};
	    $bo_starts->{$id} = $boot_info->{$id}{start};
	    $bo_iterations->{$id} = $boot_info->{$id}{iterations};
	    $bo_rand_method->{$id} = $boot_info->{$id}{rand_method};
	    $bo_mfe_method->{$id} = $boot_info->{$id}{mfe_method};
	    $bo_mfe_mean->{$id} = $boot_info->{$id}{mfe_mean};
	    $bo_mfe_sd->{$id} = $boot_info->{$id}{mfe_sd};
	    $bo_mfe_se->{$id} = $boot_info->{$id}{mfe_se};
	    $bo_pairs_mfe->{$id} = $boot_info->{$id}{pairs_mfe};
	    $bo_pairs_sd->{$id} = $boot_info->{$id}{pairs_sd};
	    $bo_pairs_se->{$id} = $boot_info->{$id}{pairs_se};
	}
    }  ## End check for bootstrap info


    my $next_step = "$base/examine";
    my $vars = {
	startform => $fun->startform(-action => $next_step),
	next_step => $next_step,
	species => $species,
	accession => $accession,
	slipsites => $slipsites,
	filenames => $filenames,
	ratio => $ratio,
	length => $length,
	diagram => \@diagram,
	# submit => $fun->submit(),
	nu_accessions => $nu_accessions,
	nu_lengths => $nu_lengths,
	nu_starts => $nu_starts,
	nu_mfes => $nu_mfes,
	nu_parens => $nu_parens,
	nu_parses => $nu_parses,
	nu_knots => $nu_knots,
	pk_accessions => $pk_accessions,
	pk_lengths => $pk_lengths,
	pk_starts => $pk_starts,
	pk_mfes => $pk_mfes,
	pk_parens => $pk_parens,
	pk_parses => $pk_parses,
	pk_knots => $pk_knots,
	bo_accessions => $bo_accessions,
	bo_starts => $bo_starts,
	bo_iterations => $bo_iterations,
	bo_rand_method => $bo_rand_method,
	bo_mfe_method => $bo_mfe_method,
	bo_mfe_mean => $bo_mfe_mean,
	bo_mfe_sd => $bo_mfe_sd,
	bo_mfe_se => $bo_mfe_se,
	bo_pairs_mean => $bo_pairs_mean,
	bo_pairs_sd => $bo_pairs_sd,
	bo_pairs_se => $bo_pairs_se,
    };
    my $input = 'dig.html';
    $template->process($input, $vars) or die $template->error();
}  ## End Dig


sub Ask_For_Fold {
    my $algorithm = shift;
    my $species = shift;
    my $accession = shift;
    
    my $entries = $db->Get_Pubqueue();
    my $num_entries = scalar(@{$entries});
    my $next_step = "$base/pubqueue_add";
    my $vars = {
	startform => $fun->startform(-action => $next_step),
	entries => $num_entries,
	next_step => $next_step,
	species => $species,
	accession => $accession,
	algorithm => $algorithm,
	submit => $fun->submit(),
    };
    my $input = 'ask.html';
    $template->process($input, $vars) or die $template->error();
}

sub Examine {
    my $sp = shift;
    my $ac = shift;
    my $st = shift;
    my ($species, $accession, $start);
    $species = (defined($sp)) ? $sp : $fun->param('species');
    $accession = (defined($ac)) ? $ac : $fun->param('accession');
    $start = (defined($st)) ? $st : $fun->param('start');
    
    if ($PRFConfig::config->{do_nupack}) {
	print "TESTME: species: $species accession: $accession start: $start<br>\n";
	
	my $next_step = 'unknown';
	my $vars = {
	    startform => $fun->startform(-action => $next_step),
#              next_step => $next_step,
	    species => $species,
	    accession => $accession,
	    start => $start,
	    # submit => $fun->submit(),
	};
    }
}

sub Pubqueue_Add {
    my $sp = shift;
    my $ac = shift;
    my $st = shift;
    my ($species, $accession, $start);
    $species = (defined($sp)) ? $sp : $fun->param('species');
    $accession = (defined($ac)) ? $ac : $fun->param('accession');
    $start = (defined($st)) ? $st : $fun->param('start');
    my $entries = $db->Set_Pubqueue($species, $accession);
    
    my $next_step = "$base/added";
    my $vars = {
	startform => $fun->startform(-action => $next_step),
	next_step => $next_step,
	species => $species,
	accession => $accession,
	submit => $fun->submit(),
    };
    my $input = 'added.html';
    $template->process($input, $vars) or die $template->error();
}

###################
## There is nothing to see here
###################
sub AUTOLOAD {
    my $attempt = our $AUTOLOAD;
    $attempt =~ s/.*:://;
    print "I have not yet defined $attempt.\n";
}
