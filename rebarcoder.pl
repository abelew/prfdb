#!/usr/bin/perl -w
#
# This script will rebarcode the pknots table in prfdb05.
use strict;
use DBI;
use lib "scripts/browser/lib";
use PkParse;

#############################
print "starting...\n";
my $db_host = 'prfdb.no-ip.org';
my $db_user = 'jonathan';
my $db_pass = 'larson6276';
my $db = 'prfdb05';

#############################
# set up the db's and such
my $sth = "";
my $dsn = "DBI:mysql:database=$db;host=$db_host";

my $dbh = DBI->connect(
    $dsn,
    $db_user,
    $db_pass,
    { RaiseError => 1, AutoCommit => 1 }
) or die $DBI::errstr;

my $parser = new PkParse();

#############################
# get gene names from old database
$sth = $dbh->prepare("select id,pk_output from pknots where parsed is null") or die $dbh->errstr;
$sth->execute;

while(my ($id,$pko) = $sth->fetchrow_array ) {
    print "##########\n$id\t";
    my @lines = split(/\n/,$pko);
    my $pknot = "";
    while( @lines ){
        shift(@lines); shift(@lines);
        $pknot .= shift(@lines); shift (@lines);
        $pknot =~ s/\s+/ /g;
        $pknot =~ s/^\s//;
        #print "#"x10,"\n$pknot\n"; <STDIN>;
    }
    
    my @noob = split(/ /,$pknot);   
    my $structure = $parser->Unzip(\@noob);
    my $new_struc = PkParse::ReBarcoder($structure);
    my $condensed = PkParse::Condense($new_struc);
    
    
    #print "$pknot\n";
    #print "@{$structure}\n";
    #print "@{$new_struc}\n";
    print $condensed,"\n";
    
    #my $upd = $dbh->prepare("update pknots set parsed=\"@{$new_struc}\", barcode=\"$condensed\" where id=\"$id\"") or die $dbh->errstr;
    #$upd->execute;
}

#print join " ", (%gene_list);

#############################
$dbh->disconnect;



