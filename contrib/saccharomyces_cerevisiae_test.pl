#! /usr/bin/perl -w
use strict;
use lib 'lib';
use PRFConfig;
use PRFdb;

my $config = $PRFConfig::config;
my $db = new PRFdb;
my $species = $ARGV[0];
$PRFConfig::config->{input} = 'data/orf_coding.fasta';
$species = 'saccharomyces_cerevisiae';
die("NEED SPECIES") unless defined($species);

$db->Load_ORF_Data();
