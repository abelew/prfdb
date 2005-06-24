#! /usr/bin/perl -w
use strict;
use DBI;

my $dsn = "DBI:mysql:database=prfdbhs;host=localhost";
my $dbh = DBI->connect($dsn, 'trey', 'Iactilm2');

my %data = Get_All_Slipsites();

sub Get_All_Slipsites {
  my $statement = "SELECT accession , sequence from cdna_ome";
  my $array_ref = $dbh->selectall_arrayref($statement);
  my $return = {};
  foreach my $gene (@{$array_ref}) {
	my $accession = $gene->[0];
	my $seq = $gene->[1];
	my @seq_string = split(/\n/, $seq);
	my $sequence = '';
	foreach my $sst (@seq_string) {
	  chomp $sst;
	  $sst =~ s/\s//g;
	  $sequence = $sequence . $sst;
	}
	my $slips = Slip_Filter($sequence);
	if (defined($slips)) {
		$return->{$accession} = slips;
	  }
  }
  return($return);
}

sub Slip_Filter {
  my $seq = shift;
  
}
