#! /usr/bin/perl -w
use strict;
use lib '../lib';
use PRFConfig;
use PRFdb;

my $config = $PRFConfig::config;
my $db     = new PRFdb;

$db->Create_Rnamotif05();
$db->Create_Nupack05();
$db->Create_Pknots05();
$db->Create_Boot05();
$db->Create_Queue05();
