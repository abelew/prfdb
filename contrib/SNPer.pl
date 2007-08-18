#!/usr/bin/perl -w

use strict;
use DBI;
use lib "../lib";
use PRFConfig qw / PRF_Error PRF_Out /;
use PRFdb;
use PRFsnp;
use Bio::DB::GenBank;
use Bio::DB::EUtilities;
use LWP;
use IO::String;

my $prfsnp = new PRFsnp({ species => 'homo_sapiens', });

$prfsnp->Compute_Frameshift();

