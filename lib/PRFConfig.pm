$ENV{EFNDATA} = "/usr/local/bin/efndata";
my $prefix = '/home/trey/browser';
$PRFConfig::config = {
                      do_nupack => 1,                       ## Run nupack on sequences?
                      do_pknots => 0,                       ## Run pknots on sequence?
                      do_mfold => 0,                        ## Run mfold on the sequence as a mfe bootstrap?
                      do_boot => 1,                         ## Perform our faux bootstrap
                      boot_repetitions => 100,
                      boot_mfe_algorithms => { mfold => \&RNAFolders::Mfold_MFE, },
                      boot_randomizers => {coin => \&MoreRandom::CoinRandom, },
                      privqueue => "$prefix/private_queue", ## Location of private queue
                      pubqueue => "$prefix/public_queue",   ## Location of public queue
                      errorfile => "$prefix/prfdb.err",     ## Location of error file
                      logfile => "$prefix/prfdb.log",       ## Location of output file (shows how long each step is taking)
                      basedir => $prefix,                   ## The base directory of this crap
                      tmpdir => "$prefix/work",             ## Temporary directory, fasta files live there
                      nupack_dir => "$prefix/work",         ## Where does nupack live?
                      nupack => "$prefix/work/Fold.out",    ## Redundant?
                      rnamotif => '/usr/local/bin/rnamotif', ## Location of rnamotif
                      rmprune => '/usr/local/bin/rmprune',  ## Location of rmprune
                      mfold => '/usr/local/bin/mfold',      ## Location of mfold
                      pknots => '/usr/local/bin/pknots',    ## Location of pknots
                      zcat => '/usr/bin/zcat',              ## Location of zcat (rename to gzcat for OSX)
                      db => 'atbprfdb',                     ## Name of mysql database
                      host => 'prfdb.umd.edu',              ## Mysql database hostname
                      user => 'trey',                       ## Mysql username
                      pass => 'Iactilm2',                   ## Mysql password
                      INCLUDE_PATH => 'html/',              ## Template directory for html templates
                      INTERPOLATE => 1,                     ## Template interpolation of variables
                      POST_CHOMP => 1,                      ## Template get rid of newlines
                      PRE_PROCESS => 'header',              ## Template html headers
                      EVAL_PERL => 1,                       ## Template evaluate inline perl code (never use this but love it)
                      ABSOLUTE => 1,
                      species => 'homo_sapiens',            ## default species (needed?)
                      input => 'inputfile',                 ## Input file for loading genomes
                      action => 'die',                      ## Default action for multiple action script(s)
                      dboutput => 'dbi',                    ## Place output into dbi
                      dbinput => 'dbi',                     ## Receive input from dbi
                      descriptor_template => "$prefix/descr/template.desc",  ## Rnamotif template descriptor file
                      descriptor_file => "$prefix/descr/rnamotif_descriptor.desc",  ## Rnamotif descriptor output
                      slip_site_1 => '^n\{3\}$',            ## Rnamotif first 3 bases of slippery site
                      slip_site_2 => '^w\{3\}$',            ## Rnamotif bases 4-6 of slippery site
                      slip_site_3 => '^h\{3\}$',            ## Rnamotif bases 7-9 of slippery site
                      slip_site_spacer_min => 5,            ## Rnamotif slippery site spacer minimum
                      slip_site_spacer_max => 9,            ## Rnamotif slippery site spacer max
                      stem1_min => 4,                       ## Rnamotif stem
                      stem1_max => 20,                      ## Rnamotif stem
                      stem1_bulge => 0.8,                   ## Rnamotif stem percentage match
                      stem1_spacer_min => 1,                ## Rnamotif first spacer min
                      stem1_spacer_max => 3,                ## Rnamotif first spacer max
                      stem2_min => 4,                       ## Rnamotif stem2 min
                      stem2_max => 20,                      ## Rnamotif stem2 max
                      stem2_bulge => 0.8,                   ## Rnamotif stem2 percentage max
                      stem2_loop_min => 0,                  ## Rnamotif second loop min
                      stem2_loop_max => 3,                  ## Rnamotif second loop max
                      stem2_spacer_min => 0,                ## Rnamotif second spacer min
                      stem2_spacer_max => 100,              ## Rnamotif second spacer max
                     };
$PRFConfig::config->{dsn} = "DBI:mysql:database=$PRFConfig::config->{db};host=$PRFConfig::config->{host}";
my $err = $PRFConfig::config->{errorfile};
my $out = $PRFConfig::config->{logfile};
my $error_counter = 0;

sub Out {
  my $message = shift;
  open(OUTFH, ">>$out") or die "Unable to open the log file $out: $!\n";
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my $month = $mon + 1;
  my $y = $year + 1900;
  my $datestring = "$hour:$min:$sec $mday/$month/$y";
  print OUTFH "$datestring\t$message\n";
  close(OUTFH);
}

sub Error {
  my $message = shift;
  open(ERRFH, ">>$err") or die "Unable to open the log file $err: $!\n";
  $error_counter++;
  if ($error_counter >= 20) {
    die("Passed 20 errors, check the error log $PRFConfig::config->{errfile}");
  }
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my $month = $mon + 1;
  my $y = $year + 1900;
  my $datestring = "$hour:$min:$sec $mday/$month/$y";
  print ERRFH "$datestring\t$message\n";
  close(ERRFH);
}

1;
