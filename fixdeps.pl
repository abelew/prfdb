#!/usr/local/bin/perl -w
use strict;
use local::lib "$ENV{PRFDB_HOME}/usr/perl";
use lib "$ENV{PRFDB_HOME}/lib";
require "$ENV{PRFDB_HOME}/lib/MyDeps.pm";

print "Note:  If you do not have apache installed, Apache::* modules will fail.
This is not fatal unless you want to run a webserver.\n";
sleep 5;

MyDeps::Res();
