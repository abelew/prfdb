use Test::More qw(no_plan);
BEGIN {
  use lib qq"$ENV{PRFDB_HOME}/lib";
  use lib "$ENV{PRFDB_HOME}/usr/lib/perl5";
}

## First the base modules required
use_ok(PRFConfig);
is(defined($ENV{PRFDB_HOME}), 1, 'PRFDB_HOME is not defined.  Perhaps set it in your shell.');
is(-f "$ENV{PRFDB_HOME}/prfdb.conf", 1, 'cannot find the prfdb.conf file');
use PRFConfig;
my $config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
is(defined($config), 1, 'PRFConfig did not load properly');
is($config->{database_name} ne 'test', 1, 'The database should not be test, did you set up your prfdb.conf?');
is($config->{database_user} ne 'guest', 1, 'The database user should not be guest.');
is($config->{database_pass} ne 'guest', 1, 'The database user should not be guest.');
if ($config->{has_modperl}) {
   use MyDeps;
   MyDeps::Resolve('apache');
}