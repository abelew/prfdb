#!/usr/bin/perl -w 
use strict;
use lib '../lib';
use PRFdb;
use PRFConfig;
my $config = $PRFConfig::config;
my $db = new PRFdb;

my $accession = $ARGV[0];
my $start = $ARGV[1];

my $mfeid = $db->MySelect("SELECT id FROM mfe WHERE accession = '$accession' and start = '$start'", [], 'row');
my $id = $mfeid->[0];
my $bp_seq = $db->Mfeid_to_Bpseq($id, 'slipsite');
print $bp_seq

