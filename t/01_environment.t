# Before 'make install' is performed, this script
# should be run with 'make test'

use Test::More qw(no_plan);

## First the base modules required
is(defined($ENV{PRFDB_HOME}), 1, 'PRFDB_HOME is defined');