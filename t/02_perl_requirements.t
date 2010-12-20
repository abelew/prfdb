BEGIN {
  use lib qq"$ENV{PRFDB_HOME}/lib";
  use lib "$ENV{PRFDB_HOME}/usr/lib/perl5";
}
use Test::More qw(no_plan);
use MyDeps;
MyDeps::Test();

