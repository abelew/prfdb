#! /usr/bin/perl -w
use strict;
use lib 'lib';
use PRFConfig;
my $config = $PRFConfig::config;

$PRFConfig::config->{db} = 'prfdb05';
$PRFConfig::config->{dsn} = "DBI:mysql:database=$PRFConfig::config->{db};host=$PRFConfig::config->{host}";

use PRFdb;
my $db = new PRFdb(config => $config);
my $dbh = $db->{dbh};

#my $statement = "SELECT id, parsed, parens FROM mfe WHERE output is null or output not like '% %'";
my $statement = "SELECT id, parsed, parens FROM mfe WHERE species = 'homo_sapiens'";
#my $statement = "SELECT id, parsed, parens FROM mfe WHERE id = '191309'";
my $info = $dbh->selectall_arrayref($statement);
foreach my $piece (@{$info}) {
  my @output = ();
  my ($id, $parsed, $parens) = @{$piece};
  $parsed =~ s/\s//g;
  $parens = '.' . $parens;
  my @parse = split(//, $parsed);
  my @paren = split(//, $parens);
  my @opar = @parse;
  my @oparen = @paren;
  my $len = scalar(@paren);
  ## First pass, fill the output array with .'s
  my $c;
  for $c (0 .. $len) {
    $output[$c] = '.';
  }
  ## Second pass:
  for $c (0 .. $len) {
    next if (!defined($paren[$c]));
    if ($paren[$c] eq '(' or $paren[$c] eq '{') {
      my $stemid = $parse[$c];
      my $position = Get_Last($stemid, \@parse);
#      print "TESTME: $position $stemid\n";
      $output[$c] = $position;
      $output[$position] = $c;
      $paren[$c] = '.';
      $paren[$position] = '.';
      $parse[$c] = '.';
      $parse[$position] = '.';
    }
  }
#  print "TESTME:
#@opar
#@oparen
#@output
#";
  my $out = '';
  foreach my $char (@output) { $out .= "$char "; }
  my $update = "UPDATE mfe set output = '$out' where id = '$id'";
  my $sth = $dbh->prepare($update);
  $sth->execute;
}

sub Get_Last {
  my $id = shift;
  my $parsed = shift;
  my $last = scalar(@{$parsed}) - 1;
  for ($last; $last >= 0; $last--) {
#    print "TESTMENOW: $last $parsed->[$last]\n";
    return($last) if ("$parsed->[$last]" eq "$id");
  }
}
