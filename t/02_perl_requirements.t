BEGIN {
  use lib qq"$ENV{PRFDB_HOME}/lib";
}
use Test::More qw(no_plan);
use MyDeps;
MyDeps::Resolve();

