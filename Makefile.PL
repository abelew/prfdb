use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => 'PRFdb',
    VERSION_FROM => 'lib/PRFdb.pm',  ## Finds $VERSION
    PREREQ_PM => { GD::SVG => 0,
		   SVG => 0,
		   Log::Log4perl => 0,
		   DBI => 0,
		   GD::Graph => 0,
		   Error => 0,
		   Bio::DB::Universal => 0,
		   Statistics::Basic => 0,
		   Statistics::Distributions => 0,
		   File::Temp => 0,
		   Apache2::Request => 0,
		   Apache::DBI => 0,
		   HTML::Mason => 0,
		   AppConfig => 0,
		   Getopt::Long => 0,
                   },
#    ABSTRACT_FROM => 'lib/PRFdb.pm',
    AUTHOR => 'Ashton Trey Belew <abelew@gmail.com>'
    );

