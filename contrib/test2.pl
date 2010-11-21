#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use lib "$ENV{PRFDB_HOME}/usr/lib/perl5";
use lib "$ENV{PRFDB_HOME}/lib";
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile Callstack Cleanup";
#use RNAMotif;
#use RNAFolders;
#use Bootlace;
#use Overlap;
#use SeqMisc;
#use PRFBlast;
#use Agree;
$config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
$SIG{INT} = \&PRFdb::Cleanup;
my $species_list = $db->MySelect("show tables");
my $genome = $db->MyExecute("ALTER TABLE genome drop column species");
foreach my $species_es (@{$species_list}) {
    my $table = $species_es->[0];
    if ($table =~ /^boot_/) {
      my $boot = $db->MyExecute("ALTER TABLE $table drop column species");
    } elsif ($table =~ /^landscape_/) {
      my $landscape = $db->MyExecute("ALTER TABLE $table drop column species");
    }
    print "On $table\n";
    $db->MyExecute("analyze table $table");
    $db->MyExecute("optimize table $table");
}

