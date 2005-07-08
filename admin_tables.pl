#! /usr/bin/perl -w
use strict;
use DBI;
use Getopt::Long;
use lib 'lib';
use PRFConfig;

my $config = $PRFConfig::config;

GetOptions(
		   'species=s' => \$config->{species},
		   'input=s' => \$config->{input},
		   'db=s' => \$config->{db},
		   'host=s' => \$config->{host},
		   'user=s' => \$config->{user},
		   'pass=s' => \$config->{pass},
		   'action=s' => \$config->{action},
		   );

my $dbh = DBI->connect($PRFConfig::config->{dsn}, $PRFConfig::config->{user}, $PRFConfig::config->{pass});
my ($action, $object, $adjective1, $adjective2) = split(/_/, $config->{action});
if ($config->{action} =~ /^remove/) {
  $config->{species} = $object . '_' . $adjective1;
  Clean_Table('genome');
  Clean_Table('nupack');
  Clean_Table('rnamotif');
  Clean_Table('pknots');
  Drop_Table('genome');
  Drop_Table('nupack');
  Drop_Table('rnamotif');
  Drop_Table('pknots');
}
elsif ($config->{action} =~ /^clean/) {
  $config->{species} = $adjective1 . '_' . $adjective2;
  Clean_Table($object, $adjective1, $adjective2);
}
elsif ($config->{action} =~ /^create/) {
  $config->{species} = $adjective1 . '_' . $adjective2;
  if ($object eq 'data') {
	Create_Data($adjective1, $adjective2);
  }
  elsif ($object eq 'rnamotif') {
	Create_Rnamotif($adjective1, $adjective2);
  }
  elsif ($object eq 'nupack') {
	Create_Nupack($adjective1, $adjective2);
  }
  elsif ($object eq 'genome') {
	Create_Genome($adjective1, $adjective2);
  }
}
elsif ($action eq 'load' and $object eq 'genome') {
  $config->{species} = $adjective1 . '_' . $adjective2;
  Load_Genome_Table($adjective1, $adjective2);
}
elsif ($action eq 'start') {
  $config->{species} = $object . '_' . $adjective1;
  Create_Rnamotif();
  Create_Nupack();
  Create_Genome();
  Create_Pknots();
  Load_Genome_Table();
}
else {
  Error("Incorrect usage of admin_tables.pl ARGV: @ARGV");
  die("I do not know what to do. Known actions are:
--action create_genome_genus_species
--action create_nupack_genus_species
--action create_rnamotif_genus_species
--action create_pknots_genus_species
--action load_genome_genus_species --input input_file
--action start_genus_species --input input_file
--action clean_genus_species
--action remove_genus_species
--action drop_genus_species
");
}

sub Clean_Table {
  my $type = shift;
  my $table = $type . '_' . $config->{species};
  my $statement = "DELETE from $table";
  my $sth = $dbh->prepare("$statement");
  $sth->execute or Error("Could not execute statement: $statement in Create_Genome");
}

sub Drop_Table {
  my $type = shift;
  my $table = $type . '_' . $config->{species};
  my $statement = "DROP table $table";
  my $sth = $dbh->prepare("$statement");
  $sth->execute or Error("Could not execute statement: $statement in Create_Genome");
}

sub Create_Genome {
  my $table = 'genome_' . $config->{species};
  my $statement = "CREATE table $table  (accession varchar(10) not null, version int not null, comment blob not null, sequence blob not null, primary key (accession))";
  print "Statement: $statement\n";
  my $sth = $dbh->prepare("$statement");
  $sth->execute or die("Could not execute statement: $statement in Create_Genome");
}

sub Create_Pknots {
  my $tablename = 'pknots_' . $config->{species};
  my $statement = "CREATE table $tablename (id int not null auto_increment, process varchar(80), start int, length int, struct_start int, logodds float, mfe float, cor_mfe float, pairs int, pseudop tinyint, slipsite varchar(80), spacer varchar(80), sequence blob, structure blob, parsed blob, primary key (id))";
  my $sth = $dbh->prepare("$statement");
  $sth->execute;
}

sub Create_Nupack {
  my $tablename = 'nupack_' . $config->{species};
  my $statement = "CREATE table $tablename (id int not null auto_increment, accession varchar(80), start int, slipsite char(7), seqlength int, sequence char(200), paren_output char(200), pairs blob, mfe float, knotp bool, primary key(id))";
  my $sth = $dbh->prepare("$statement");
  $sth->execute;
}

sub Create_Rnamotif {
  my $tablename = "rnamotif_" . $config->{species};
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
