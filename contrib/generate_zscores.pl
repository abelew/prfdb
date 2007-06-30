#! /usr/bin/perl -w
use strict;
use DBI;
use lib '../lib';
use PRFConfig;
use PRFdb;
my $config = $PRFConfig::config;
my $db = new PRFdb;

my $all_boot_stmt = qq(SELECT id, mfe_id, mfe_mean, mfe_sd FROM boot WHERE zscore is NULL);
my $all_boot = $db->MySelect($all_boot_stmt);
foreach my $boot (@{$all_boot}) {
    my $id = $boot->[0];
    my $mfe_id = $boot->[1];
    my $mfe_mean = $boot->[2];
    my $mfe_sd = $boot->[3];
    my $mfe_stmt = qq(SELECT mfe FROM mfe WHERE id = '$mfe_id');
    my $mfe_ref = $db->MySelect($mfe_stmt,[],'row');
    my $mfe = $mfe_ref->[0];
    $mfe_sd = 1 if (!defined($mfe_sd) or $mfe_sd == 0);
    $mfe = 0 if (!defined($mfe));
    $mfe_mean = 0 if (!defined($mfe_mean));
    my $zscore = sprintf("%.3f", ($mfe - $mfe_mean) / $mfe_sd);
    my $update_stmt = qq(UPDATE boot SET zscore = '$zscore' WHERE id = '$id');
    $db->Execute($update_stmt);
}
