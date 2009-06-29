package PRFConfig;
use strict;
use AppConfig qw/:argcount :expand/;
use Getopt::Long;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(PRF_Out PRF_Error config);    # Symbols to be exported by default

#our @EXPORT_OK = qw();  # Symbols to be exported on request
our $VERSION = 1.00;                           # Version number

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
},);
####
## Set up some reasonable defaults here
####
$PRFConfig::config->{niceness} = 10;
$PRFConfig::config->{debug} = undef;
$PRFConfig::config->{base} = '.';
$PRFConfig::config->{open_files} = [];
$PRFConfig::config->{checks} = 0;
$PRFConfig::config->{add_to_path} = "/usr/local/bin:/usr/bin";
$PRFConfig::config->{has_modperl} = 0;
$PRFConfig::config->{index_species} = ['saccharomyces_cerevisiae', 'homo_sapiens', 'bos_taurus', 'danio_rerio', 'mus_musculus', 'rattus_norvegicus', 'xenopus_laevis', 'xenopus_tropicalis', 'saccharomyces_kudriavzevii', 'saccharomyces_castellii', 'saccharomyces_kluyveri', 'saccharomyces_bayanus', 'saccharomyces_paradoxus', 'saccharomyces_mikatae', 'caenorhabiditis_elegans', 'virus'];
$PRFConfig::config->{species_limit} = undef;
$PRFConfig::config->{snp_species_limit} = 'homo_sapiens';
$PRFConfig::config->{workdir} = 'work';
$PRFConfig::config->{blastdir} = 'blast';
$PRFConfig::config->{queue_table} = 'queue';
$PRFConfig::config->{check_webqueue} = 1;
$PRFConfig::config->{genome_table} = 'genome';
$PRFConfig::config->{seqlength} = [100,75,50];
$PRFConfig::config->{landscape_seqlength} = 105;
$PRFConfig::config->{window_space} = 15;
$PRFConfig::config->{do_nupack} = 1;
$PRFConfig::config->{do_pknots} = 1;
$PRFConfig::config->{do_hotknots} = 1;
$PRFConfig::config->{do_boot} = 1;
$PRFConfig::config->{do_landscape} = 1;
$PRFConfig::config->{do_utr} = 0;
$PRFConfig::config->{nupack_nopairs_hack} = 0;
$PRFConfig::config->{arch_specific_exe} = 0;
$PRFConfig::config->{boot_iterations} = 100;
$PRFConfig::config->{boot_mfe_algorithms} = {pknots => \&RNAFolders::Pknots_Boot, nupack => \&RNAFolders::Nupack_Boot, hotknots => \&RNAFolders::Hotknots_Boot, };
$PRFConfig::config->{boot_randomizers} = {array => \&SeqMisc::ArrayShuffle,};
$PRFConfig::config->{database_type} = 'mysql';
$PRFConfig::config->{db} = 'prfconfigdefault_db';
$PRFConfig::config->{host} = 'prfconfigdefault_host';
$PRFConfig::config->{user} = 'prfconfigdefault_user';
$PRFConfig::config->{pass} = 'prfconfigdefault_pass';
$PRFConfig::config->{INCLUDE_PATH} = 'html/';
$PRFConfig::config->{INTERPOLATE} = 1;
$PRFConfig::config->{POST_CHOMP} = 1;
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
$PRFConfig::config->{using_pbs} = 0;
$PRFConfig::config->{pbs_template} = 'pbs_template';
$PRFConfig::config->{pbs_arches} = 'aix4 irix6 linux-ia64';
$PRFConfig::config->{pbs_shell} = '/bin/sh';
$PRFConfig::config->{pbs_memory} = '1600';
$PRFConfig::config->{pbs_cpu} = '1';
$PRFConfig::config->{pbs_partialname} = 'fold';
$PRFConfig::config->{num_daemons} = '20';
$PRFConfig::config->{condor_memory} = '512';
$PRFConfig::config->{condor_os} = 'OSX';
$PRFConfig::config->{condor_arch} = 'PPC';
$PRFConfig::config->{condor_universe} = 'vanilla';
$PRFConfig::config->{perl} = '/usr/local/bin/perl';
$PRFConfig::config->{daemon_name} = 'folder_daemon.pl';
$PRFConfig::config->{rnamotif} = 'rnamotif';
$PRFConfig::config->{rnamotif_template} = 'rnamotif_template';
$PRFConfig::config->{rnamotif_descriptor} = 'descr/rnamotif_template.out';
$PRFConfig::config->{rmprune} = 'rmprune';
$PRFConfig::config->{pknots} = 'pknots';
$PRFConfig::config->{hotknots} = 'HotKnot';
$PRFConfig::config->{rnafold} = 'RNAfold';
$PRFConfig::config->{nupack} = 'Fold.out';
$PRFConfig::config->{zcat} = 'zcat';
$PRFConfig::config->{nupack_boot} = 'Fold.out.boot';
$PRFConfig::config->{sql_id} = 'int not null auto_increment';
$PRFConfig::config->{sql_species} = 'varchar(80)';
$PRFConfig::config->{sql_accession} = 'varchar(40)';
$PRFConfig::config->{gi_number} = 'varchar(80)';
$PRFConfig::config->{sql_genename} = 'varchar(120)';
$PRFConfig::config->{sql_comment} = 'text not null';
$PRFConfig::config->{sql_timestamp} = 'TIMESTAMP ON UPDATE CURRENT_TIMESTAMP DEFAULT CURRENT_TIMESTAMP';
$PRFConfig::config->{sql_index} = $PRFConfig::config->{sql_id};
$PRFConfig::config->{logfile} = 'prfdb.log';
$PRFConfig::config->{errorfile} = 'prfdb.errors';
$PRFConfig::config->{dirvar} = undef;
$PRFConfig::config->{max_mfe} = 10.0;
$PRFConfig::config->{stem_colors} = "black blue red green purple orange brown darkslategray";  ## This gets dropped into an array
## The zeroth element is a non-stem, thus black
$PRFConfig::config->{graph_font} = 'arial.ttf';
$PRFConfig::config->{distribution_graph_x_size} = 400;
$PRFConfig::config->{distribution_graph_y_size} = 300;
$PRFConfig::config->{landscape_graph_x_size} = 800;
$PRFConfig::config->{landscape_graph_y_size} = 600;
$PRFConfig::config->{graph_font_size} = 9;
$PRFConfig::config->{ENV_LIBRARY_PATH} = $ENV{LD_LIBRARY_PATH};
my $config_file;
if (defined($ENV{PRFDBHOME})) {
    $config_file = "$ENV{PRFDBHOME}/prfdb.conf";
}
else {
    $config_file = 'prfdb.conf';
}
if (!-r $config_file) {
    my $cwd = `pwd`;
    print STDERR "Can't find prfdb.conf in $cwd\n";
    die;
}
my $open = $appconfig->file('prfdb.conf');
my %data = $appconfig->varlist("^.*");
for my $config_option (keys %data) {
    $PRFConfig::config->{$config_option} = $data{$config_option};
    undef $data{$config_option};
}
my %conf;
GetOptions(## If this gets set, then the prf_daemon will exit before it gets to the queue
	   'nodaemon:i' => \$conf{nodaemon},  
	   'debug:i' => \$conf{debug},
	   ## Print some help information
	   'help|version' => \$conf{help},      
	   ## An accession to specifically fold.  If it is not already in the db  
	   ## Import it and then fold it.
	   'accession|i:s' => \$conf{accession},
	   'blast:s' => \$conf{blast},
	   'makeblast' => \$conf{makeblast},
	   'index_stats' => \$conf{index_stats},
           ## Create a local blast database from the genome
	   'optimize:s' => \$conf{optimize},
	   ## Use mysql to optimize a table
	   'species:s' => \$conf{species},
	   'copyfrom:s' => \$conf{copyfrom},
	   ## Another database from which to copy the genome table
	   'import:s' => \$conf{import_accession},
	   ## A single accession to import
	   'input_file:s' => \$conf{input_file},
	   ## A file of accessions to import and queue
	   'input_fasta:s' => \$conf{input_fasta},
	   ## A file of fasta data to import and queue
	   'fasta_style:s' => \$conf{fasta_style},
	   ## The style of input fasta (sgd, ncbi, etc)
	   ## By default this should be 0/1, but for some yeast genomes it may be 1000
	   'fillqueue' => \$conf{fillqueue},
	   ## A boolean to see if the queue should be filled.
	   'resetqueue' => \$conf{resetqueue},
	   ## A boolean to reset the queue
	   'stats' => \$conf{stats},
	   ## Generate stats
	   'startpos:s' => \$conf{startpos},
	   ## A specific start position to fold a single sequence at,
	   ## also usable by inputfasta or inputfile
	   'startmotif:s' => \$conf{startmotif},
	   ## A specific start motif to start folding at
	   'length:i' => \$conf{seqlength},
	   ## i == integer
	   'landscape_length:i' => \$conf{landscape_seqlength},
	   'nupack:i' => \$conf{do_nupack},
	   ## If no type definition is given, it is boolean
	   'pknots:i' => \$conf{do_pknots},
	   ## The question is, will these be set to 0 if not applied?
	   'hotknots:i' => \$conf{do_hotknots},
	   ## The question is, will these be set to 0 if not applied?
	   'boot:i' => \$conf{do_boot},
	   'utr:i' => \$conf{do_utr},
	   'workdir:s' => \$conf{workdir},
	   'nupack_nopairs:i' => \$conf{nupack_nopairs_hack},
	   'arch:i' => \$conf{arch_specific_exe},
	   'iterations:i' => \$conf{boot_iterations},
	   'db|d:s' => \$conf{db},
	   'host:s' => \$conf{host},
	   'user:s' => \$conf{user},
	   'pass:s' => \$conf{pass},
	   'slip_site_1:s' => \$conf{slip_site_1},
	   'slip_site_2:s' => \$conf{slip_site_2},
	   'slip_site_3:s' => \$conf{slip_site_3},
	   'slip_site_spacer_min:i' => \$conf{slip_site_spacer_min},
	   'slip_site_spacer_max:i' => \$conf{slip_site_spacer_max},
	   'stem1_min:i' => \$conf{stem1_min},
	   'stem1_max:i' => \$conf{stem1_max},
	   'stem1_bulge:i' => \$conf{stem1_bulge},
	   'stem1_spacer_min:i' => \$conf{stem1_spacer_min},
	   'stem1_spacer_max:i' => \$conf{stem1_spacer_max},
	   'stem2_min:i' => \$conf{stem2_min},
	   'stem2_max:i' => \$conf{stem2_max},
	   'stem2_bulge:i' => \$conf{stem2_bulge},
	   'stem2_loop_min:i' => \$conf{stem2_loop_min},
	   'stem2_loop_max:i' => \$conf{stem2_loop_max},
	   'stem2_spacer_min:i' => \$conf{stem2_spacer_min},
	   'stem2_spacer_max:i' => \$conf{stem2_spacer_max},
	   'checks:i' => \$conf{checks},
	   'make_jobs' => \$conf{make_jobs},
	   'make_landscape' => \$conf{make_landscape},);
foreach my $opt (keys %conf) {
    if (defined($conf{$opt})) {
	$PRFConfig::config->{$opt} = $conf{$opt};
    }
}

if (defined($PRFConfig::config->{checks}) and $PRFConfig::config->{checks} == 1) {
    $PRFConfig::config->{debug} = 0;
}
if (defined($PRFConfig::config->{debug})) {
    $PRFConfig::config->{checks} = 1;
}

$PRFConfig::config->{dsn} = qq(DBI:$PRFConfig::config->{database_type}:database=$PRFConfig::config->{db};host=$PRFConfig::config->{host});
if (ref($PRFConfig::config->{boot_mfe_algorithms}) eq '') {
    $PRFConfig::config->{boot_mfe_algorithms} = eval($PRFConfig::config->{boot_mfe_algorithms});
}
if (ref($PRFConfig::config->{boot_randomizers}) eq '') {
    $PRFConfig::config->{boot_randomizers} = eval($PRFConfig::config->{boot_randomizers});
}
if (ref($PRFConfig::config->{index_species}) eq '') {
    $PRFConfig::config->{index_species} = eval($PRFConfig::config->{index_species});
}
if (ref($PRFConfig::config->{seqlength}) eq '') {
    $PRFConfig::config->{seqlength} = eval($PRFConfig::config->{seqlength});
}
my $err = $PRFConfig::config->{errorfile};
my $out = $PRFConfig::config->{logfile};
my $error_counter = 0;
$PRFConfig::config->{workdir} = $PRFConfig::config->{base} . '/' . $PRFConfig::config->{workdir};
$PRFConfig::config->{blastdir} = $PRFConfig::config->{base} . '/' . $PRFConfig::config->{blastdir};
foreach my $dir (split(/:/, $PRFConfig::config->{add_to_path})) {
    $ENV{PATH} = $ENV{PATH} . ':' . $dir;
}
$ENV{PATH} = $ENV{PATH} . ':' . $PRFConfig::config->{workdir};
$ENV{BLASTDB} = qq($PRFConfig::config->{base}/blast);

if ($PRFConfig::config->{arch_specific_exe} == 1) {
    ## If we have architecture specific executables, then
    ## They should live in directories named after their architecture
    my @modified_exes = ('rnamotif', 'rmprune', 'pknots', 'zcat');
    open(UNAME, "/usr/bin/env uname -a |");
    ## OPEN UNAME in PRFConfig
    my $arch;
    while (my $line = <UNAME>) {
	chomp $line;
	if ($line =~ /\w/) {
	    $arch = $line;
	}
    }
    close(UNAME);
    ## CLOSE UNAME in PRFConfig
    chomp $arch;
    if ($arch =~ /IRIX/) {
	$ENV{PATH} = $ENV{PATH} . ':' . $PRFConfig::config->{workdir} . '/irix';
    }
    elsif ($arch =~ /Linux/) {
	$ENV{PATH} = $ENV{PATH} . ':' . $PRFConfig::config->{workdir} . '/linux';
    }
    elsif ($arch =~ /Darwin/) {
	$ENV{PATH} = $ENV{PATH} . ':' . $PRFConfig::config->{workdir} . '/osx';
    } 
    elsif ($arch =~ /AIX/) {
	$ENV{PATH} = $ENV{PATH} . ':' . $PRFConfig::config->{workdir} . '/aix';
    }

    foreach my $exe (@modified_exes) {
	if ($arch =~ /IRIX/) {
	    my $exe_path = join('', $PRFConfig::config->{workdir} , '/irix/', $PRFConfig::config->{$exe});
	    $PRFConfig::config->{$exe} = $exe_path;
	}
	elsif ($arch =~ /AIX/) {
	    my $exe_path = join('', $PRFConfig::config->{workdir} , '/aix/', $PRFConfig::config->{$exe});
	    $PRFConfig::config->{$exe} = $exe_path;
	}
	elsif ($arch =~ /Darwin/) {
	    my $exe_path = join('', $PRFConfig::config->{workdir} , '/osx/', $PRFConfig::config->{$exe});
	    $PRFConfig::config->{$exe} = $exe_path;
	}
	elsif ($arch =~ /Linux/) {
	    my $exe_path = join('', $PRFConfig::config->{workdir} , '/linux/', $PRFConfig::config->{$exe});
	    $PRFConfig::config->{$exe} = $exe_path;
	}
	else {
	    die("Architecture $arch not available.");
	}
    }    ## For every modified executable

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
    elsif ($arch =~ /Darwin/) {
	$PRFConfig::config->{nupack} .= ".osx";
	$PRFConfig::config->{nupack_boot} .= ".osx";
    }
}    ## End checking if multiple architectures are in use
$ENV{EFNDATA} = $PRFConfig::config->{workdir};
$ENV{ENERGY_FILE} = qq($PRFConfig::config->{workdir}/dataS_G.rna);

$ENV{EFNDATA} = $PRFConfig::config->{workdir};
$ENV{ENERGY_FILE} = qq($PRFConfig::config->{workdir}/dataS_G.rna);

sub PRF_Out {
    my $message = shift;
    open(OUTFH, ">>$out") or die "Unable to open the log file $out: $!\n";
    ## OPEN OUTFH in PRF_Out
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
    my $month = $mon + 1;
    my $y = $year + 1900;
    my $datestring = qq($hour:$min:$sec $mday/$month/$y);
    print OUTFH "$datestring\t$message\n";
    close(OUTFH);
    ## CLOSE OUTFH in PRF_Out
}

sub PRF_Error {
    my $message = shift;
    my $accession = shift;
    open(ERRFH, ">>$err") or die "Unable to open the log file $err: $!\n";
    ## OPEN ERRFH in PRF_Error
    my $db = new PRFdb;
    $db->Error_Db($message, $accession);
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
    my $month = $mon + 1;
    my $y = $year + 1900;
    my $datestring = qq($hour:$min:$sec $mday/$month/$y);
    print ERRFH "$datestring\t$message\n";
    close(ERRFH);
    ## CLOSE ERRFH in PRF_Err
}

sub Go_Away {
    return ();
}

1;
