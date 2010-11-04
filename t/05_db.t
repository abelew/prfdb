use Test::More qw(no_plan);
BEGIN {
  use lib qq"$ENV{PRFDB_HOME}/lib";
  use lib qq"$ENV{PRFDB_HOME}/usr/lib/perl5";
}

use_ok(PRFConfig);
use_ok(PRFdb);
use PRFConfig;
my $config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
use PRFdb qw"AddOpen RemoveFile";
my $db = new PRFdb(config => $config);
my $dbh = $db->MyConnect();
is(defined($dbh), 1, 'Unable to connect to the database');
my $genome_table = $db->Tablep('genome');
ok($genome_table > 0, 'genome table');
my $mfe_table = $db->Tablep('mfe');
ok($mfe_table > 0, 'mfe table');
my $gene_info_table = $db->Tablep('gene_info');
ok($gene_info_table > 0, 'gene_info table');
