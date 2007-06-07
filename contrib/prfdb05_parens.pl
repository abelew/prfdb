#! /usr/bin/perl -w
use strict;
use lib '../lib';
use PRFConfig;
use PkParse;
$PRFConfig::config->{db} = 'prfdb05';
$PRFConfig::config->{dsn} = "DBI:mysql:database=$PRFConfig::config->{db};host=$PRFConfig::config->{host}";
my $config = $PRFConfig::config;
use PRFdb;

my $db = new PRFdb(config => $config);
my $dbh = $db->{dbh};
print "TESTME: $db->{dsn}\n";
my $parser = new PkParse;

my $statement = "SELECT id, parsed, output from mfe where parens is null";
my $info = $dbh->selectall_arrayref($statement);
foreach my $piece (@{$info}) {
  my ($id, $parsed, $pkoutput) = @{$piece};
  $pkoutput =~ s/\s+/ /g;
  my @pkout = split(/\s+/, $pkoutput);

  my $parens = PkParse::MAKEBRACKETS(\@pkout);
  print "$id\n$parsed\n$parens\n\n";
  my $update = "update mfe set parens='$parens' where id='$id'";
  my $sth = $dbh->prepare($update);
  $sth->execute;
}
