package PRFConfig;
## Time-stamp: <Wed Jan 18 14:54:08 2006 Ashton Trey Belew (abelew@wesleyan.edu)>
use strict;
use AppConfig qw/:argcount :expand/;
require      Exporter;
our @ISA       = qw(Exporter);
our @EXPORT    = qw(PRF_Out PRF_Error PRF_Die config);    # Symbols to be exported by default
#our @EXPORT_OK = qw();  # Symbols to be exported on request
our $VERSION   = 1.00;         # Version number

$ENV{EFNDATA} = "$ENV{HOME}/browser/work";
$ENV{ENERGY_FILE} = "$ENV{HOME}/browser/work/dataS_G.rna";

my $appconfig = AppConfig->new({
                                CASE => 1,
                                CREATE => 1,
                                PEDANTIC => 0,
                                ERROR => \&Go_Away,
                                GLOBAL => {
                                           EXPAND => EXPAND_ALL,
                                           EXPAND_ENV => 1,
                                           EXPAND_UID => 1,
                                           DEFAULT => "<unset>",
                                           ARGCOUNT => 1,
                                          },
                              },
                             );
####
## Set up some reasonable defaults here
####
$PRFConfig::config->{max_struct_length} = 99;
$PRFConfig::config->{do_nupack} = 1;
$PRFConfig::config->{do_pknots} = 1;
$PRFConfig::config->{do_boot} = 1;
$PRFConfig::config->{nupack_nopairs_hack} = 0;
$PRFConfig::config->{arch_specific_exe} = 0;
$PRFConfig::config->{boot_iterations} = 100;
$PRFConfig::config->{boot_mfe_algorithms} = { pknots => \&RNAFolders::Pknots_Boot, nupack => \&RNAFolders::Nupack_Boot, };
$PRFConfig::config->{boot_randomizers} = { array => \&MoreRandom::ArrayShuffle, };
$PRFConfig::config->{db} = 'prfconfigdefault_db';
$PRFConfig::config->{host} = 'prfconfigdefault_host';
$PRFConfig::config->{user} = 'prfconfigdefault_user';
$PRFConfig::config->{pass} = 'prfconfigdefault_pass';
$PRFConfig::config->{INCLUDE_PATH} = 'html/';
$PRFConfig::config->{INTERPOLATE} = 1;
$PRFConfig::config->{POST_CHOMP} = 1;
$PRFConfig::config->{PRE_PROCESS} = 'header';
$PRFConfig::config->{EVAL_PERL} = 0;
$PRFConfig::config->{ABSOLUTE} = 1;
$PRFConfig::config->{slip_site_1} = '^n\{3\}$';
$PRFConfig::config->{slip_site_2} = '^w\{3\}$';
$PRFConfig::config->{slip_site_3} = '^h\{3\}$';
$PRFConfig::config->{slip_site_spacer_min} = 5;
$PRFConfig::config->{slip_site_spacer_max} = 9;
$PRFConfig::config->{stem1_min} = 4;
$PRFConfig::config->{stem1_max} = 20;
$PRFConfig::config->{stem1_bulge} = 0.8;
$PRFConfig::config->{stem1_spacer_min} = 1;
$PRFConfig::config->{stem1_spacer_max} = 4;
$PRFConfig::config->{stem2_min} = 4;
$PRFConfig::config->{stem2_max} = 20;
$PRFConfig::config->{stem2_bulge} = 0.8;
$PRFConfig::config->{stem2_loop_min} = 0;
$PRFConfig::config->{stem2_loop_max} = 3;
$PRFConfig::config->{stem2_spacer_min} = 0;
$PRFConfig::config->{stem2_spacer_max} = 100;
$PRFConfig::config->{pbs_template} = 'pbs_template';
$PRFConfig::config->{pbs_arches} = 'aix4 irix6 linux';
$PRFConfig::config->{pbs_shell} = '/bin/bash';
$PRFConfig::config->{pbs_memory} = '1600';
$PRFConfig::config->{pbs_cpu} = '1';
$PRFConfig::config->{pbs_partialname} = 'fold';
$PRFConfig::config->{perl} = '/usr/local/bin/perl';
$PRFConfig::config->{daemon_name} = 'folder_daemon.pl';
$PRFConfig::config->{num_daemons} = '20';
$PRFConfig::config->{rnamotif} = 'rnamotif';
$PRFConfig::config->{rmprune} = 'rmprune';
$PRFConfig::config->{pknots} = 'pknots';
$PRFConfig::config->{nupack} = 'Fold.out';
$PRFConfig::config->{nupack_boot} = 'Fold.out.boot';
$PRFConfig::config->{sql_id} = 'int not null auto_incremenent';
$PRFConfig::config->{sql_species} = 'varchar(80)';
$PRFConfig::config->{sql_accession} = 'varchar(40)';
$PRFConfig::config->{sql_genename} = 'varchar(90)';
$PRFConfig::config->{sql_comment} = 'text not null';
$PRFConfig::config->{sql_timestamp} = 'TIMESTAMP ON UPDATE CURRENT_TIMESTAMP DEFAULT CURRENT_TIMESTAMP';
$PRFConfig::config->{sql_timestamp} = 'TIMESTAMP ON UPDATE CURRENT_TIMESTAMP DEFAULT CURRENT_TIMESTAMP';
$PRFConfig::config->{sql_index} = $PRFConfig::config->{sql_id};

my $open = $appconfig->file('prfdb.conf');
my %data = $appconfig->varlist("^.*");
for my $config_option (keys %data) {
#  $PRFConfig::config->{$config_option} = $data{$config_option};
  $PRFConfig::config->{$config_option} = $data{$config_option};
  undef $data{$config_option};
}
$PRFConfig::config->{boot_mfe_algorithms} = eval($PRFConfig::config->{boot_mfe_algorithms});
$PRFConfig::config->{boot_randomizers} = eval($PRFConfig::config->{boot_randomizers});
$PRFConfig::config->{pbs_shell} = eval($PRFConfig::config->{pbs_shell});

$PRFConfig::config->{dsn} = "DBI:mysql:database=$PRFConfig::config->{db};host=$PRFConfig::config->{host}";
my $err = $PRFConfig::config->{errorfile};
my $out = $PRFConfig::config->{logfile};
my $error_counter = 0;
$ENV{PATH} = $ENV{PATH} . ':' . $PRFConfig::config->{bindir};

if ($PRFConfig::config->{arch_specific_exe} == 1) {

  ## If we have architecture specific executables, then
  ## They should live in directories named after their architecture
  my @modified_exes = ('rnamotif', 'rmprune', 'pknots', 'zcat');
  open(UNAME, "/usr/bin/env uname -a |");
  my $arch;
  while (my $line = <UNAME>) {
    chomp $line;
    if ($line =~ /\w/) {
      $arch = $line;
    }
  }
  close(UNAME);
  chomp $arch;
  if ($arch =~ /IRIX/) {
    $ENV{PATH} = $ENV{PATH} . ':' . $PRFConfig::config->{bindir} . '/irix';
  }
  if ($arch =~ /Linux/) {
    $ENV{PATH} = $ENV{PATH} . ':' . $PRFConfig::config->{bindir} . '/linux';
  }
  elsif ($arch =~ /AIX/) {
    $ENV{PATH} = $ENV{PATH} . ':' . $PRFConfig::config->{bindir} . '/aix';
  }
  foreach my $exe (@modified_exes) {
    my $dirvar = $exe . '_dir';
    if ($arch =~ /IRIX/) {
      my $dir = $PRFConfig::config->{$dirvar};
      $dir .= '/irix';
      $PRFConfig::config->{$dirvar} = $dir;
      my $exe_path = join('', $dir, '/', $PRFConfig::config->{$exe});
      $PRFConfig::config->{$exe} = $exe_path;
    }
    elsif ($arch =~ /AIX/) {
      my $dir = $PRFConfig::config->{$dirvar};
      $dir .= '/aix';
      $PRFConfig::config->{$dirvar} = $dir;
      my $exe_path = join('', $dir, '/', $PRFConfig::config->{$exe});
      $PRFConfig::config->{$exe} = $exe_path;
    }
    elsif ($arch =~ /Linux/) {
      my $dir = $PRFConfig::config->{$dirvar};
      $dir .= '/linux';
      $PRFConfig::config->{$dirvar} = $dir;
      my $exe_path = join('', $dir, '/', $PRFConfig::config->{$exe});
      $PRFConfig::config->{$exe} = $exe_path;
    }
    else {
      die("Architecture $arch not available.");
    }
  } ## For every modified executable

  if ($arch =~ /IRIX/) {
    $PRFConfig::config->{nupack} .= ".irix";
    $PRFConfig::config->{nupack_boot} .= ".irix";
  }
  elsif ($arch =~ /AIX/) {
    $PRFConfig::config->{nupack} .= ".aix";
    $PRFConfig::config->{nupack_boot} .= ".aix";
  }
  elsif ($arch =~ /Linux/) {
    $PRFConfig::config->{nupack} .= ".linux";
    $PRFConfig::config->{nupack_boot} .= ".linux";
  }
}  ## End checking if multiple architectures are in use

sub PRF_Out {
  my $message = shift;
  open(OUTFH, ">>$out") or die "Unable to open the log file $out: $!\n";
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my $month = $mon + 1;
  my $y = $year + 1900;
  my $datestring = "$hour:$min:$sec $mday/$month/$y";
  print OUTFH "$datestring\t$message\n";
  close(OUTFH);
}

sub PRF_Error {
  my $message = shift;
  my $accession = shift;
  open(ERRFH, ">>$err") or die "Unable to open the log file $err: $!\n";
  my $db = new PRFdb;
  $db->Error_Db($message, $accession);
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my $month = $mon + 1;
  my $y = $year + 1900;
  my $datestring = "$hour:$min:$sec $mday/$month/$y";
  print ERRFH "$datestring\t$message\n";
  close(ERRFH);
}

sub Go_Away {
  return();
}


1;


__END__
#$PRFConfig::config = {
#                      max_struct_length => 39,  ## The maximum structure size to be examined
#                      do_nupack => 1,           ## Run nupack on sequences?
#		      do_pknots => 1,           ## Run pknots on sequence?
#                      do_mfold => 0,            ## Run mfold on the sequence as a mfe bootstrap?
#                      do_boot => 1,             ## Perform our faux bootstrap
#                      arch_specific_exe => 0,   ## Architecture specific executables (used for a pbs environment)
#                      boot_iterations => 100,
#                      boot_mfe_algorithms => {
#			  mfold => \&RNAFolders::Pknots_Boot,
#		      },
#                      boot_randomizers => {
#                             coin => \&MoreRandom::CoinRandom,
#			  array => \&MoreRandom::ArrayShuffle,
#                          },
#                      privqueue => "$prefix/private_queue",     ## Location of public queue
#                      pubqueue => "$prefix/public_queue",       ## Location of public queue
#                      errorfile => "$prefix/prfdb.err",         ## Location of error file
#                      logfile => "$prefix/prfdb.log",           ## Location of output file
#                      basedir => $prefix,                       ## The base directory of this crap
#                      tmpdir => "$prefix/work",                 ## Temporary directory, fasta files live there
#                      bindir => "$prefix/work",
#                      nupack_dir => "$prefix/work",             ## Where does nupack live?
#                      nupack => "Fold.out",
#                      rnamotif_dir => "$prefix/work",
#                      rnamotif => 'rnamotif',
#                      rmprune_dir => "$prefix/work",
#                      rmprune => 'rmprune',     ## Location of rmprune
#                      mfold_dir => "$prefix/work",
#                      mfold => 'mfold',         ## Location of mfold
#                      mfold_lib => "$prefix/dat",
#                      pknots_dir => "$prefix/work",
#                      pknots => 'pknots',       ## Location of pknots
#                      zcat_dir => "$prefix/work",
#                      zcat => 'zcat',           ## Location of zcat (rename to gzcat for OSX)
#                      db => 'atbprfdb',         ## Name of mysql database
#                      host => 'prfdb.no-ip.org',## Mysql database hostname
#                      user => 'trey',           ## Mysql username
#                      pass => 'Iactilm2',       ## Mysql password
#                      INCLUDE_PATH => 'html/',  ## Template directory for html templates
#                      INTERPOLATE => 1,         ## Template interpolation of variables
#                      POST_CHOMP => 1,          ## Template get rid of newlines
#                      PRE_PROCESS => 'header',  ## Template html headers
#                      EVAL_PERL => 1,           ## Template evaluate inline perl code
#                      ABSOLUTE => 1,
#                      input => 'inputfile',     ## Input file for loading genomes
#                      action => 'die',          ## Default action for multiple action script(s)
#                      descriptor_template => "$prefix/descr/template.desc",  ## Rnamotif template descriptor file
#                      descriptor_file => "$prefix/descr/rnamotif_descriptor.desc",  ## Rnamotif descriptor output
#                      slip_site_1 => '^n\{3\}$',## Rnamotif first 3 bases of slippery site
#                      slip_site_2 => '^w\{3\}$',## Rnamotif bases 4-6 of slippery site
#                      slip_site_3 => '^h\{3\}$',## Rnamotif bases 7-9 of slippery site
#                      slip_site_spacer_min => 5,## Rnamotif slippery site spacer minimum
#                      slip_site_spacer_max => 9,## Rnamotif slippery site spacer max
#                      stem1_min => 4,           ## Rnamotif stem
#                      stem1_max => 20,          ## Rnamotif stem
#                      stem1_bulge => 0.8,       ## Rnamotif stem percentage match
#                      stem1_spacer_min => 1,    ## Rnamotif first spacer min
#                      stem1_spacer_max => 3,    ## Rnamotif first spacer max
#                      stem2_min => 4,           ## Rnamotif stem2 min
#                      stem2_max => 20,          ## Rnamotif stem2 max
#                      stem2_bulge => 0.8,       ## Rnamotif stem2 percentage max
#                      stem2_loop_min => 0,      ## Rnamotif second loop min
#                      stem2_loop_max => 3,      ## Rnamotif second loop max
#                      stem2_spacer_min => 0,    ## Rnamotif second spacer min
#                      stem2_spacer_max => 100,  ## Rnamotif second spacer max
#                      ### The following define the mysql datatypes for common fields in the database
#                      mysql_index => 'int not null auto_increment',
#                      mysql_species => 'varchar(40) not null',
#                      mysql_accession => 'varchar(80)',
#                      mysql_genename => 'varchar(20)',
#                      mysql_comment => 'text not null',
#                     };
