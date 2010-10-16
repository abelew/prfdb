# Before 'make install' is performed, this script
# should be run with 'make test'

BEGIN {
 use lib qq"$ENV{PRFDB_HOME}/lib";
## Don't forget to increment me for each new test
 $| = 1; print "1..2\n";
}
END {
 print "not ok 1\n" unless $loaded;
}
use PRFdb;
$loaded = 1;
print "ok 1\n";

# Test 2
my $config = new PRFConfig();
my $result = $config->{z_test};
print ($result eq "z_test" ? "ok 2\n" : "not ok 2\n");
