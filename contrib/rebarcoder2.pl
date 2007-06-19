#!/usr/bin/perl -w
#
# This script will rebarcode the pknots table in prfdb05.
use strict;
use DBI;
use lib "../lib";
use PkParse3;

#############################
#print "starting...\n";
my $db_host = 'prfdb.no-ip.org';
my $db_user = 'trey';
my $db_pass = 'Iactilm2';
my $db      = 'prfdb05';

#############################
# set up the db's and such
my $sth = "";
my $dsn = "DBI:mysql:database=$db;host=$db_host";

my $dbh = DBI->connect( $dsn, $db_user, $db_pass, { RaiseError => 1, AutoCommit => 1 } ) or die $DBI::errstr;

my $parser = new PkParse3();

#############################
# get gene names from old database
#$sth = $dbh->prepare("select id,output from pknots where barcode is null") or die $dbh->errstr;
#$sth = $dbh->prepare("select id,output,parsed from mfe where barcode is null order by rand()") or die $dbh->errstr;

#$sth = $dbh->prepare("select id,output,parsed from mfe where barcode is null") or die $dbh->errstr;
#$sth = $dbh->prepare("select id,output,parsed from mfe where barcode is null and id > '192777'") or die $dbh->errstr;
#$sth = $dbh->prepare("select id,output,parsed from mfe where barcode is null and id > '197865'") or die $dbh->errstr;
#$sth = $dbh->prepare("select id,output,parsed from mfe where barcode is null and id > '198525'") or die $dbh->errstr;
#$sth = $dbh->prepare("select id,output,parsed from mfe where barcode is null and id > '202900'") or die $dbh->errstr;
$sth = $dbh->prepare("select id,output,parsed from mfe") or die $dbh->errstr;
$sth->execute;

while ( my ( $id, $pko, $parsed ) = $sth->fetchrow_array ) {

  #  print "TESTME: $id $pko\n";
  #    print "##########\n$id\t";
  #    my @lines = split(/\n/,$pko);
  #    my $pknot = "";
  #    while( @lines ){
  #        shift(@lines); shift(@lines);
  #        $pknot .= shift(@lines); shift (@lines);
  #        $pknot =~ s/\s+/ /g;
  #        $pknot =~ s/^\s//;
  #print "#"x10,"\n$pknot\n"; <STDIN>;
  #    }
  #  print "TESTING: $parsed
  #$pko\n";
  $pko =~ s/^\s+//g;
  $pko =~ s/\s+/ /g;
  my @noob      = split( / /, $pko );
  my $structure = $parser->Unzip( \@noob );
  my $new_struc = PkParse3::ReBarcoder($structure);
  my $condensed = PkParse3::Condense($new_struc);
  my $brackets  = PkParse3::MAKEBRACKETS( \@noob );
  my @parens    = split( //, $brackets );

  #print "$pknot\n";
  foreach my $char (@noob) {
    $char = sprintf( "%3s", $char );
    print "$char";
  }
  print "\n\n";
  my $parsed_string = '';

  #    print "@noob\n";   print "@{$structure}\n";
  foreach my $char ( @{$new_struc} ) {
    $parsed_string .= "$char ";
    $char = sprintf( "%3s", $char );
    print "$char";
  }
  print "\n\n";
  foreach my $char (@parens) {
    $char = sprintf( "%3s", $char );
    print "$char";
  }
  print "\n\n";

  #    print "@{$new_struc}\n";
  print "$condensed\n";
  my $update_string = qq(UPDATE mfe SET barcode = '$condensed', parsed = '$parsed_string', parens = '$brackets' WHERE id = '$id';);
  print "$update_string\n";
  print "--------------------------------------------------------------------------------\n";

  #    print "ID: $id\n";

  #    my $update = "update mfe set barcode = \"$condensed\", parsed = \"@{$new_struc}\" where id = \"$id\"";
  #    print "$update\n";
  #    my $upd = $dbh->prepare("update pknots set parsed=\"@{$new_struc}\", barcode=\"$condensed\" where id=\"$id\"") or die $dbh->errstr;
  #    print "WOULD DO: $upd\n";
  #    $upd->execute;
}

#print join " ", (%gene_list);

#############################
#$dbh->disconnect;
