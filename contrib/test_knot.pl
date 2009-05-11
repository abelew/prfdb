#!/usr/bin/perl -w -I/usr/share/httpd/prfdb/usr/lib/perl5/site_perl/

use strict;
use DBI;
use lib '../lib';
use PRFConfig;
use PRFdb;
use PkParse;
my $config = $PRFConfig::config;
my $db = new PRFdb;
my $parser = new PkParse;

my $barcodes = $db->MySelect(qq(SELECT barcode FROM mfe where algorithm = 'hotknots' limit 100));
foreach my $code (@{$barcodes}) {
    my $barcode = $code->[0];
    my $test = $parser->Knotp($barcode);
    print "TESTME: $barcode $test\n";
    
}
