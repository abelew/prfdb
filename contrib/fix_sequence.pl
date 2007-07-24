#! /usr/bin/perl -w
use strict;
use lib '../lib';

use PRFdb;
use PRFConfig;
my $config = $PRFConfig::config;
my $db     = new PRFdb;

my $stmt = qq/select id,sequence from mfe where sequence regexp('.T.')/;
my $stuff = $db->MySelect($stmt);
foreach my $s (@{$stuff}) {
    my $id = $s->[0];
    my $sequence = $s->[1];
    my $new_sequence = $sequence;
    $new_sequence =~ tr/T/U/;
    
    my $update2 = qq/update mfe set sequence = '$new_sequence' where id = '$id'/;
    $db->Execute($update2);
    print "$update2\n";
}
