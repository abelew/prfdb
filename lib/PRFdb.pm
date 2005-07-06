package PRFdb;
use strict;
use DBI;

sub new {
  my ($class, %arg) = @_;
  my $me = bless {
				  db => 'atbprfdb',
				  host => 'localhost',
				  user => 'trey',
				  pass => 'Iactilm2',
				 }, $class;
  my $dsn = "DBI:mysql:database=$me->{db};host=$me->{host}";
  $me->{dbh} = DBI->connect($dsn, $me->{user}, $me->{pass});
  return ($me);
  print "Here\n";
}

sub Get_Sequence {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $statement = "SELECT * FROM $species WHERE accession = '$accession'";
  my $info = $me->{dbh}->selectall_arrayref($statement);
  my $sequence = $info->[0]->[0];
  if ($sequence) {
	return($sequence);
  }
  else {
	return(undef);
  }
}

sub Get_RNAmotif {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $return = {};
  my $table = "rnamotif_$species";
  my $statement = "SELECT total, permissable, data, output FROM $table WHERE accession = '$accession'";
  my $dbh = $me->{dbh};
  my $info = $dbh->selectall_arrayref($statement);
#  return(0) if (scalar(@{$info}) == 0);
  return(0) unless(defined($info));
  return(0) if (scalar(@{$info}) == 0);
  foreach my $start (@{$info}) {
	$return->{$start}{total} = $info->[$start]->[0];
	$return->{$start}{permissable} = $info->[$start]->[1];
	$return->{$start}{filedata} = $info->[$start]->[2];
	$return->{$start}{output} = $info->[$start]->[3];
  }
  return($return);
}

sub Put_RNAmotif {
  my $me = shift;
  my $species = shift;
  my $accession = shift;
  my $slipsites_data = shift;
  my $table = "rnamotif_" . $species;
  my $statement = "INSERT INTO $table (id, accession, start, total, permissable, data, output) VALUES (?,?,?,?,?,?,?)";
  my $sth = $me->{dbh}->prepare($statement);
  foreach my $start (keys %{$slipsites_data}) {
	my $total = $slipsites_data->{$start}{total};
	my $permissable = $slipsites_data->{$start}{permissable};
	my $filename = $slipsites_data->{$start}{filename};
	my $filedata = $slipsites_data->{$start}{filedata};
	my $output = $slipsites_data->{$start}{output};
	$sth->execute(undef, $accession, $start, $total, $permissable, $filedata, $output);
  }
  $me->{dbh}->commit;
}

1;
