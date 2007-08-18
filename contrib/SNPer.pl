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

# $prfsnp->Get_Set_GI_Numbers();
# $prfsnp->Fill_Table_snp();
# $prfsnp->Compute_Frameshift();
$prfsnp->Get_Set_OMIMs();
