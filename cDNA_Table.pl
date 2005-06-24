#! /usr/bin/perl -w
use strict;
use DBI;

my $dsn = "DBI:mysql:database=prfdbhs;host=localhost";
my $dbh = DBI->connect($dsn, 'trey', 'Iactilm2');

Create_Table();
Load_Table();



sub Create_Table {
  my $statement = "CREATE table cdna_ome (accession varchar(10) not null, version int not null, comment blob not null, sequence blob not null, primary key (accession))";
  my $sth = $dbh->prepare("$statement");
  $sth->execute;
}

sub Load_Table {
  open(IN, "</home/trey/dinman/prfdbhs/hs_mgc_mrna.fasta") or die "Could not open the human cdna\n $!\n";
  my %datum = (accession => undef, version => undef, comment => undef, sequence => undef);
  while(my $line = <IN>) {
	chomp $line;
	if ($line =~ /^\>/) {
	  if (defined($datum{accession})) {
		Insert_Entry(\%datum);
	  }
	  my ($gi, $id, $gb, $accession_version, $comment) = split(/\|/, $line);
	  my ($accession, $version) = split(/\./, $accession_version);
	  $datum{accession} = $accession;
	  $datum{version} = $version;
	  $datum{comment} = $comment;
#	  print "TEST: $accession $version $comment\n";
#	  sleep(1);
	}
	else {
	  $datum{sequence} .= $line;
	}
  }
  Insert_Entry(\%datum);
}

sub Insert_Entry {
  my $datum = shift;
  my $qa = $dbh->quote($datum->{accession});
  my $qv = $dbh->quote($datum->{version});
  my $qc = $dbh->quote($datum->{comment});
  my $qs = $dbh->quote($datum->{sequence});
  my $statement = "INSERT into cdna_ome values($qa, $qv, $qc, $qs)";
  $datum->{sequence} = undef;
#  print "TEST: $statement\n";
  my $sth = $dbh->prepare($statement);
  $sth->execute;
}
