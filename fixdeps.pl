#!/usr/local/bin/perl -w
use strict;
use lib "$ENV{PRFDB_HOME}/lib";
use local::lib "$ENV{PRFDB_HOME}/usr/perl";
require "$ENV{PRFDB_HOME}/lib/MyDeps.pm";

print "Note:  If you do not have apache installed, Apache::* modules will fail.
This is not fatal unless you want to run a webserver.\n";
sleep 5;

MyDeps::Res();