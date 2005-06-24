#! /usr/bin/perl -w
use strict;
use DBI;
use Getopt::Long;

my $config = {  species => 'homo_sapiens',
			  input => 'intputfile',
			  db => 'atbprfdb',
			  host => 'localhost',
			  user => 'trey',
			  pass => 'Iactilm2',
			  action => 'die',
			 };
GetOptions(
		   'species=s' => \$config->{species},
		   'input=s' => \$config->{input},
		   'db=s' => \$config->{db},
		   'host=s' => \$config->{host},
		   'user=s' => \$config->{user},
		   'pass=s' => \$config->{pass},
		   'action=s' => \$config->{action},
		   );

my $dsn = "DBI:mysql:database=$config->{db};host=$config->{host}";
my $dbh = DBI->connect($dsn, $config->{user}, $config->{pass});

if ($config->{action} =~ /^create/) {
  my ($action, $object, $adjective1, $adjective2) = split(/_/, $config->{action});
  if ($object eq 'data') {
	Create_Data($adjective1, $adjective2);
  }
  else {
	Create_Table();
  }
}
elsif ($config->{action} eq 'load') {
  Load_Table();
}
else {
  die("I do not know what to do.  The action should be in the form of something like:
create_data_homo_sapiens or create_table_homo_sapiens");
}


sub Create_Table {
  my $statement = "CREATE table $config->{species}  (accession varchar(10) not null, version int not null, comment blob not null, sequence blob not null, primary key (accession))";
  print "Statement: $statement\n";
  my $sth = $dbh->prepare("$statement");
  $sth->execute;
}

sub Create_Data {
  my $genus = shift;
  my $species = shift;
  my $tablename = "data_" . $genus . '_' . $species;
  my $statement = "CREATE table $tablename (id int not null auto_increment, process varchar(80), start int, length int, struct_start int, logodds float, mfe float, cor_mfe float, pairs int, pseudop tinyint, slipsite varchar(80), spacer varchar(80), sequence blob, structure blob, parsed blob, primary key (id))";
  my $sth = $dbh->prepare("$statement");
  $sth->execute;
}


sub Load_Table {
  if ($config->{input} =~ /gz$/) {
	open(IN, "zcat $config->{input} |") or die "Could not open the fasta file\n $!\n";
  }
  else {
	open(IN, "<$config->{input}") or die "Could not open the fasta file\n $!\n";
  }
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
  my $statement = "INSERT into $config->{species} values($qa, $qv, $qc, $qs)";
  $datum->{sequence} = undef;
#  print "TEST: $statement\n";
  my $sth = $dbh->prepare($statement);
  $sth->execute;
}