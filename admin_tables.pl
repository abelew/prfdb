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
my ($action, $object, $adjective1, $adjective2) = split(/_/, $config->{action});

if ($config->{action} =~ /^create/) {
  if ($object eq 'data') {
	Create_Data($adjective1, $adjective2);
  }
  elsif ($object eq 'rnamotif') {
	Create_Rnamotif($adjective1, $adjective2);
  }
  elsif ($object eq 'fasta') {
	Create_Fasta();
  }
  elsif ($object eq 'nupack') {
	Create_Nupack($adjective1, $adjective2);
  }
  else {
	Create_Genome();
  }
}
elsif ($action eq 'load' and $object eq 'genome') {
  Load_Genome_Table($adjective1, $adjective2);
}
elsif ($action eq 'start') {
  Create_Rnamotif($adjective1, $adjective2);
  Create_Nupack($adjective1, $adjective2);
  Create_Genome();
  Load_Genome_Table($adjective1, $adjective2);
}
else {
  die("I do not know what to do. Known actions are:
--action create_genome_genus_species
--action create_nupack_genus_species
--action create_rnamotif_genus_species
--action create_pknots_genus_species
--action load_genome_genus_species --input input_file
--action start_genus_species --input input_file
");
}


sub Create_Genome {
  my $table = 'genome_' . $config->{species};
  my $statement = "CREATE table $table  (accession varchar(10) not null, version int not null, comment blob not null, sequence blob not null, primary key (accession))";
  print "Statement: $statement\n";
  my $sth = $dbh->prepare("$statement");
  $sth->execute;
}

sub Create_Fasta {
  my $statement = "CREATE table fasta (id int not null auto_increment, species varchar(80), start int, comment varchar(80), sequence blob, primary key (id))";
  my $sth = $dbh->prepare($statement);
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

sub Create_Nupack {
  my $genus = shift;
  my $species = shift;
  my $tablename = "nupack_" . $genus . '_' . $species;
  my $statement = "CREATE table $tablename (id int not null auto_increment, accession varchar(80), start int, slipsite char(7), seqlength int, sequence char(200), paren_output char(200), pairs blob, mfe float, knotp bool, primary key(id))";
  my $sth = $dbh->prepare("$statement");
  $sth->execute;
}

sub Create_Rnamotif {
  my $genus = shift;
  my $species = shift;
  my $tablename = "rnamotif_" . $genus . '_' . $species;
  my $statement = "CREATE table $tablename (id int not null auto_increment, accession varchar(80), start int, total int, permissable int, data blob, output blob, primary key (id))";
  my $sth = $dbh->prepare("$statement");
  $sth->execute;
}

sub Load_Genome_Table {
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
		Insert_Genome_Entry(\%datum);
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
  Insert_Genome_Entry(\%datum);
}

sub Insert_Genome_Entry {
  my $datum = shift;
  my $qa = $dbh->quote($datum->{accession});
  my $qv = $dbh->quote($datum->{version});
  my $qc = $dbh->quote($datum->{comment});
  my $qs = $dbh->quote($datum->{sequence});
  my $table = "genome_" . $config->{species};
  my $statement = "INSERT into $table values($qa, $qv, $qc, $qs)";
  $datum->{sequence} = undef;
#  print "TEST: $statement\n";
  my $sth = $dbh->prepare($statement);
  $sth->execute;
}
