$ENV{EFNDATA} = "/usr/local/bin/efndata";
my $prefix = '/home/trey/browser';
$PRFConfig::config = {
                      do_nupack => 1,
                      do_pknots => 0,
                      privqueue => "$prefix/private_queue",
                      pubqueue => "$prefix/public_queue",
                      errorfile => "$prefix/prfdb.log",
                      basedir => $prefix,
                      tmpdir => "$prefix/work",
                      nupack_dir => "$prefix/work",
                      nupack => "$prefix/work/Fold.out",
                      rnamotif => '/usr/local/bin/rnamotif',
                      rmprune => '/usr/local/bin/rmprune',
                      pknots => '/usr/local/bin/pknots',
                      db => 'atbprfdb',
                      host => 'localhost',
                      user => 'trey',
                      pass => 'Iactilm2',
                      max_stem_length => 100,
                      INCLUDE_PATH => 'html/',
                      INTERPOLATE => 1,
                      POST_CHOMP => 1,
                      PRE_PROCESS => 'header',
                      EVAL_PERL => 1,
                      species => 'homo_sapiens',
                      input => 'inputfile',
                      action => 'die',
                      dboutput => 'dbi',
                      dbinput => 'dbi',
};
$PRFConfig::config->{dsn} = "DBI:mysql:database=$PRFConfig::config->{db};host=$PRFConfig::config->{host}";
my $err = $PRFConfig::config->{errorfile};
`touch $err` unless(-w $err);
open(ERRFH, ">>$err") or die "Unable to open the log file $err: $!\n";
my $error_counter = 0;

sub Error {
  my $message = shift;
  $error_counter++;
  if ($error_counter >= 20) {
    die("Passed 20 errors, check the error log $PRFConfig::config->{errfile}");
  }
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my $month = $mon + 1;
  my $y = $year + 1900;
  my $datestring = "$hour:$min:$sec $mday/$month/$y";
  print ERRFH "$datestring\t$message\n";
}

1;
