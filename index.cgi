#!/usr/bin/perl -w
use strict;
use CGI qw/:standard :html3/;
use CGI::Carp qw(fatalsToBrowser carpout);
use Template;
use lib "lib";
use PRFConfig;
use PRFdb;

my $config = $PRFConfig::config;  ## All configuration information exists here
chdir($config->{basedir});  ## Change into the home directory of the folder daemon
my $db = new PRFdb;  ## Set up a database configuration
my $fun = new CGI;   ## Start a new CGI object
print $fun->header;    ## Immediately print a header
my $template = new Template($config);  ## And a new Template
my $base = "http://" . $ENV{HTTP_HOST} . $ENV{SCRIPT_NAME};


if ($fun->path_info() eq '/start' || $fun->path_info() eq '') {
  Part1();
}
elsif ($fun->path_info() eq '/explore') {
  Explore();
}
elsif ($fun->path_info() eq '/dig') {
  Dig();
}
elsif ($fun->path_info() eq '/clean') {
  RNAMotif_Search->Remove_Old();
}

print $fun->endform , $fun->end_html;

sub Part1 {
  my $vars = { startform => $fun->startform(-action=>"$base/explore"),
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
  my $vars = { startform => $fun->startform(-action => $next_step),
               next_step => $next_step,
               species => $species,
#               submit => $fun->submit(),
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
  (defined($sp)) ? $species = $sp : $species = $fun->param('species');
  (defined($ac)) ? $accession = $ac : $accession = $fun->('accession');
  my ($nupack_structures, $pknots_structures, $boot_structures);

  my $sequence = $db->Get_Sequence($species, $accession);
  ## Check to see if this has already been generated.
  my $slipsites_data = $db->Get_RNAmotif($species, $accession);
  unless ($slipsites_data) {
    my $stemsearch = new RNAMotif_Search;
    $slipsites_data = $stemsearch->Search($sequence, $config->{max_stem_length});
    $db->Put_RNAmotif($species, $accession, $slipsites_data);
  }
  my $slipsites = {};
  my $filenames = {};
  foreach my $k (keys %{$slipsites_data}) {
    $slipsites->{$k} = $slipsites_data->{$k}{start};
    $filenames->{$k} = $slipsites_data->{$k}{filename};
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

  my $next_step = "$base/dig";
  my $vars = { startform => $fun->startform(-action => $next_step),
			   next_step => $next_step,
			   accession => $accession,
			   species => $species,
			   slipsites => $slipsites,
			   filenames => $filenames,
			   ratio => $ratio,
			   length => $length,
			   diagram => \@diagram,
#			   submit => $fun->submit(),
			   };
  my $input = 'explore.html';

  $rnamotif_info =$db->Get_RNAMotif($species, $accession)

  if ($PRFConfig::config->{do_nupack}) {
    $nupack_structures = $db->Get_Nupack($species, $accession);
    if (!defined($nupack_structures) or scalar(%{$nupack_structures}) eq '0') {  ## Then a nupack search has not been performed for this accession
      Ask_For_Fold('nupack', $species, $accession);
    }
  }
  if ($PRFConfig::config->{do_pknots}) {
    $pknots_structures = $db->Get_Pknots($species, $accession);
    ## Do a pknots search
  }
#  $boot_structures = $db->Get_Boot($species, $accession);
    foreach my $key (sort keys %{$nupack_structures}) {
      print "TEST: $key accession: $nupack_structures->{$key}->{accession}
start: $nupack_structures->{$key}->{start}
\n";
    }

}


sub AUTOLOAD {
  my $attempt = our $AUTOLOAD;
  $attempt =~ s/.*:://;
  print "I have not yet defined $attempt.\n";
}
