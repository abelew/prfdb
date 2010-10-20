# Before 'make install' is performed, this script
# should be run with 'make test'

use Test::More qw(no_plan);

## First the base modules required
use_ok(Number::Format);
use_ok(DBI);
use_ok(Getopt::Long);
use_ok(File::Temp);
use_ok(Fcntl);
## Then the more random ones for graphing and such
use_ok(GD::Graph);
use_ok(GD::Text);
use_ok(GD::SVG);
use_ok(SVG);
use_ok(Statistics::Basic);
use_ok(Statistics::Distributions);
use_ok(Bio::DB::Universal);
use_ok(AppConfig);
