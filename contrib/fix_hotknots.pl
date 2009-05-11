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

my $barcodes = $db->MySelect(qq(SELECT id,barcode FROM mfe where algorithm = 'hotknots'));
foreach my $code (@{$barcodes}) {
    my $id = $code->[0];
    my $barcode = $code->[1];
    my $test = $parser->Knotp($barcode);
    print "TESTME: $barcode $test\n";
    if ($test) {
	print "$barcode is knotted.";
	my $fix = $db->MyExecute("UPDATE mfe SET knotp = '1' WHERE id = '$id'");
    }
}
