#!/usr/bin/perl -w
use strict;
use lib "lib";
use PRFConfig;
use CGI qw/:standard :html3/;
use CGI::Carp qw(fatalsToBrowser carpout);
use strict;
use Template;
#use Stem_Search;
use RNAMotif_Search;
use PRFdb;
use RNAFolders;
use DBI;

my $config = $PRFConfig::config;

my $dbh = DBI->connect($config->{dsn}, $config->{user}, $config->{pass});

my $fun = new CGI;
print $fun->header;
my $base = "http://" . $ENV{HTTP_HOST} . $ENV{SCRIPT_NAME};
my $template = new Template($config);

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
  my $db = new PRFdb;
  my $species = $fun->param('species');
  $species =~ s/\ /_/g;
  my $accession = $fun->param('accession');
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
  $template->process($input, $vars) or die $template->error();
}

sub Dig {
  my $filename = '';
  my @params = $fun->param();
#  foreach my $p (@params) {
#	print "TEST: $p<br>\n";
#	my $tmp = $fun->param(-name => $p);
#	print "TMP: $tmp<br>\n";
#	if ($p =~ /^\d+$/) { $filename = $fun->param(-name => $p); }
#  }
  my $filename = $fun->param('filename');
  my $fold = new RNAFolders(file => $filename);
  $fold->Nupack();
  print "TEST: $filename<br>\n";
}
