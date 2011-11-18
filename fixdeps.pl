#!/usr/bin/env perl
use strict;
use warnings;
BEGIN {
    use lib ($ENV{PRFDB_HOME} ? "$ENV{PRFDB_HOME}/lib" : "./lib");
    use local::lib ($ENV{PRFDB_HOME} ? "$ENV{PRFDB_HOME}/usr/perl" : "./usr/perl");
    unless ($ENV{PRFDB_HOME}) {
	print "Please set the environment variable PRFDB_HOME.
Setting it to .\n";
	$ENV{PRFDB_HOME} = ".";
    }
}
require "$ENV{PRFDB_HOME}/lib/MyDeps.pm";

print "Note:  If you do not have apache installed, Apache::* modules will fail.
This is not fatal unless you want to run a webserver.\n";
sleep 5;

MyDeps::Res();
