#!/usr/bin/perl -w
use strict;
use lib "lib/";
use CGI qw/:standard :html3/;
use CGI::Carp qw(fatalsToBrowser carpout);
use strict;
use DBI;
use Template;
use Stem_Search;

my $config = {
			  db => 'atbprfdb',
                          host => 'localhost',
                          user => 'trey',
                          pass => 'Iactilm2',
			  max_stem_length => 100,
			  INCLUDE_PATH => 'html/',  # or list ref
			  INTERPOLATE  => 1,               # expand "$var" in plain text
			  POST_CHOMP   => 1,               # cleanup whitespace
			  PRE_PROCESS  => 'header',        # prefix each template
			  POST_PROCESS => 'footer',        # append the footer
			  EVAL_PERL    => 1,               # evaluate Perl code blocks
             };

my $dsn = "DBI:mysql:database=$config->{db};host=$config->{host}";
my $dbh = DBI->connect($dsn, $config->{user}, $config->{pass});

my $fun = new CGI;
print $fun->header;
my $base = "http://" . $ENV{HTTP_HOST} . $ENV{SCRIPT_NAME};
my $template = new Template($config);

if ($fun->path_info() eq '/start' || $fun->path_info() eq '') {
  Part1();
}
if ($fun->path_info() eq '/explore') {
  Explore();
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
  my $species = $fun->param('species');
  $species =~ s/\ /_/g;
  my $accession = $fun->param('accession');
  my $statement = "SELECT * FROM $species WHERE accession = '$accession'";
  my $info = $dbh->selectall_arrayref($statement);
  my $sequence = $info->[3];
  my $stemsearch = new Stem_Search;
  my $slipsites = $stemsearch->Search(sequence => $sequence, length => $config->{max_stem_length});

  my $vars = { startform => $fun->startform(-action => "$base/dig"),
			   slipsites => @{$slipsites},
			   submit => $fun->submit(),
			   };
  my $input = 'explore.html';
  $template->process($input, $vars) or die $template->error();
}
