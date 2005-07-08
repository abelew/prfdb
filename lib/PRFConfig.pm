$ENV{EFNDATA} = "/usr/local/bin/efndata";
$PRFConfig::config = {
		    errorfile => '/home/trey/browser/prfdb.log',
                      basedir => '/home/trey/browser',
                      tmpdir => '/home/trey/browser/work',
                      nupack_dir => '/home/trey/browser/work',
                      nupack => '/home/trey/browser/work/Fold.out',
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
};
$PRFConfig::config->{dsn} = "DBI:mysql:database=$PRFConfig::config->{db};host=$PRFConfig::config->{host}";
my $err = $PRFConfig::config->{errorfile};
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
