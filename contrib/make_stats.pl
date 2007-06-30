#! /usr/bin/perl -w
use strict;
use DBI;
use lib "$ENV{HOME}/usr/lib/perl5";
use lib 'lib';
use PRFConfig;
use PRFdb;
my $config = $PRFConfig::config;
$config->{db} = 'prfdb_test';
my $db = new PRFdb;

$db->Create_Stats();
my $data = {
  species   => [ 'homo_sapiens', 'saccharomyces_cerevisiae', 'mus_musculus' ],
  seqlength => [ 50, '100', ],
  max_mfe   => [ '10.0', ],
  algorithm => [ 'nupack', 'pknots' ],
};
$db->Put_Stats($data);
