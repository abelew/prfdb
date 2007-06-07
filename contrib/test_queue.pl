#! /usr/bin/perl -w
use strict;
use lib '../lib';
use PRFConfig;
use PRFdb;

my $db = new PRFdb;
my $info = $db->Grab_Queue('private');
my $species = $info->{species};
my $accession = $info->{accession};
print "TELL ME: $species $accession\n";
