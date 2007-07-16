#! /usr/bin/perl -w
use strict;
use lib '../lib';

use PRFdb;
use PRFConfig;
my $config = $PRFConfig::config;
my $db     = new PRFdb;
my %stmts = (
    AAAAAAT => 'AAAAAAU',
    AAATTTA => 'AAAUUUA',
    AAATTTC => 'AAAUUUC',
    AAATTTT => 'AAAUUUU',
    CCCAAAT => 'CCCAAAU',
    CCCTTTA => 'CCCUUUA',
    CCCTTTC => 'CCCUUUC',
    CCCTTTT => 'CCCUUUU',
    GGGAAAT => 'GGGAAAU',
    GGGTTTA => 'GGGUUUA',
    GGGTTTC => 'GGGUUUC',
    GGGTTTT => 'GGGUUUU',
    TTTAAAA => 'UUUAAAA',
    TTTAAAC => 'UUUAAAC',
    TTTAAAT => 'UUUAAAU',
    TTTTTTA => 'UUUUUUA',
    TTTTTTC => 'UUUUUUC',
    TTTTTTT => 'UUUUUUU',
);

foreach my $k (keys %stmts) {
    my $stmt = qq(UPDATE mfe SET slipsite = ? WHERE slipsite = ?);
#    my $stmt = qq(UPDATE mfe SET slipsite = '$stmts{$k}' WHERE slipsite = '$k');
    print "STATEMENT: $stmt: $stmts{$k}  $k\n";
    $db->Execute($stmt, [$stmts{$k}, $k]);
}
