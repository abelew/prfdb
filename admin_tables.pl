#!/usr/bin/perl
use strict;

use DBI;
use Getopt::Long;
use lib "$ENV{HOME}/usr/lib/perl5";
use lib 'lib';
use PRFConfig qw( PRF_Error );
use PRFdb;
use Bio::DB::Universal;
use Bio::DB::GenBank;

$^W=1;

my $config = $PRFConfig::config;

GetOptions(
		   'species=s' => \$config->{species},
		   'input=s' => \$config->{input},
		   'db=s' => \$config->{db},
		   'host=s' => \$config->{host},
		   'user=s' => \$config->{user},
		   'pass=s' => \$config->{pass},
		   'action=s' => \$config->{action},
		   'import=s' => \$config->{import},
		   );
my $db = new PRFdb;
my ($action, $object, $adjective1, $adjective2) = split(/_/, $config->{action});

if (defined($config->{import})) {
  $db->Import_Accession($config->{import});
}
elsif ($config->{action} =~ /^remove/) {
  $config->{species} = $object . '_' . $adjective1;
  $db->Clean_Table('genome');
  $db->Clean_Table('nupack');
  $db->Clean_Table('rnamotif');
  $db->Clean_Table('pknots');
  $db->Clean_Table('boot');
  $db->Drop_Table('genome');
  $db->Drop_Table('nupack');
  $db->Drop_Table('rnamotif');
  $db->Drop_Table('pknots');
  $db->Drop_Table('boot');
}
elsif ($config->{action} =~ /^clean/) {
  $config->{species} = $adjective1 . '_' . $adjective2;
  $db->Clean_Table($object, $adjective1, $adjective2);
}
elsif ($config->{action} =~ /^create/) {
  $config->{species} = $adjective1 . '_' . $adjective2;
  if ($object eq 'queue') {
    $db->Create_Queue();
  }
  elsif ($object eq 'data') {
    $db->Create_Data($adjective1, $adjective2);
  }
  elsif ($object eq 'rnamotif') {
    $db->Create_Rnamotif($adjective1, $adjective2);
  }
  elsif ($object eq 'nupack') {
    $db->Create_Nupack($adjective1, $adjective2);
  }
  elsif ($object eq 'pknots') {
    $db->Create_Pknots($adjective1, $adjective2);
  }
  elsif ($object eq 'genome') {
    $db->Create_Genome($adjective1, $adjective2);
  }
  elsif ($object eq 'boot') {
    $db->Create_Boot($adjective1, $adjective2);
  }
}
elsif ($action eq 'load' and $object eq 'genome') {
  $config->{species} = $adjective1 . '_' . $adjective2;
  $db->Load_Genome_Table($adjective1, $adjective2);
}
elsif ($action eq 'start') {
  $config->{species} = $object . '_' . $adjective1;
  $db->Create_Rnamotif();
  $db->Create_Nupack();
  $db->Create_Genome();
  $db->Create_Pknots();
  $db->Create_Boot();
  $db->Load_Genome_Table();
}
elsif ($action eq 'fillqueue') {
  $db->FillQueue();
}
elsif ($action eq 'pubqueue') {
  print "TESTME: $action $object\n";
  $db->Set_Pubqueue($object);
}
else {
  PRF_Error("Incorrect usage of admin_tables.pl ARGV: @ARGV");
  die("I do not know what to do. Known actions are:
--action create_genome_genus_species
--action create_nupack_genus_species
--action create_rnamotif_genus_species
--action create_pknots_genus_species
--action load_genome_genus_species --input input_file
--action start_genus_species --input input_file
--action clean_genus_species
--action remove_genus_species
--action drop_genus_species
");
}

