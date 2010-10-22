BEGIN {
  use lib qq"$ENV{PRFDB_HOME}/lib";
}
use Test::More qw(no_plan);
use_ok("Agree");
use_ok("Bootlace");
use_ok("PRFBlast");
use_ok("PRFGraph");
use_ok("PRFsnp");
use_ok("RNAFolders");
use_ok("SeqMisc");
use_ok("HTMLMisc");
use_ok("Overlap");
use_ok("PkParse");
use_ok("RNAMotif");
