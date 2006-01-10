#! /usr/bin/perl -w
use strict;
use lib 'lib';
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

open(OUT, ">parens.txt");
my $statement = "SELECT id, output from pknots";
my $info = $dbh->selectall_arrayref($statement);
foreach my $piece (@{$info}) {
  my ($accession, $pkoutput) = @{$piece};
  $pkoutput =~ s/\s+/ /g;
  my @pkout = split(/\s+/, $pkoutput);

  my $parens = PkParse::MAKEBRACKETS(\@pkout);
  print OUT "$accession\t$parens\n";
}
