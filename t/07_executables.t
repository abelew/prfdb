use Test::More qw"no_plan";

is(-x "$ENV{PRFDB_HOME}/work/Fold.out.nopairs", 1, "Fold.out.nopairs is executable.");
is(-x "$ENV{PRFDB_HOME}/work/Fold.out.boot.nopairs", 1, "Fold.out.nopairs.boot is executable.");
is(-x "$ENV{PRFDB_HOME}/work/HotKnot", 1, "HotKnot is executable.");
is(-x "$ENV{PRFDB_HOME}/work/params", 1, "The HotKnot params directory is executable.");
is(-x "$ENV{PRFDB_HOME}/work/RNAfold", 1, "Vienna RNAfold is executable.");
is(-x "$ENV{PRFDB_HOME}/work/pknots", 1, "pknots is executable.");