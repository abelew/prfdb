$ENV{EFNDATA} = "/usr/local/bin/efndata";
$PRFConfig::config = {
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
};
$PRFConfig::config->{dsn} = "DBI:mysql:database=$PRFConfig::config->{db};host=$PRFConfig::config->{host}";
__END__
1;
