
package PRFConfig;
use strict;
use AppConfig qw/:argcount :expand/;
use Getopt::Long;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(PRF_Out PRF_Error config);    # Symbols to be exported by default
our $AUTOLOAD;

=head1 NAME

    MyConfig - A configuration system for the PRFdb
   
=head1 SYNOPSIS

    use MyConfig;
    my $config = new MyConfig(option => value, another => value2);
    print "The option is $config->option or $config->{option}";
    $config->{option} = 'new value';  $config->option("new value");
    ## When used with a config file 'myconfig.conf'
    option=new value
    ## When used on the command line
    ./script --option "new value"
    ## Order of preference, highest to lowest:  command line, config file, constructor
    ## So if you set something in the constructor and have it in your config file, no dice.

=head1 DESCRIPTION

    This aims to make dealing with lots of configuration options easy

=cut


sub new {
    my ($class, %arg) = @_;
    my $me = bless {}, $class;
    foreach my $key (keys %arg) {
	$me->{$key} = $arg{$key} if (defined($arg{$key}));
    }

    $me->{appconfig} = AppConfig->new({
	CASE => 1,
	CREATE => 1,
	PEDANTIC => 0,
#	ERROR => eval(),
	GLOBAL => {
	    EXPAND => EXPAND_ALL,
	    EXPAND_ENV => 1,
	    EXPAND_UID => 1,
	    DEFAULT => "<unset>",
	    ARGCOUNT => 1,
	},});

    ## First fill out a set of default configuration values
    ## The following for loop will include all of these in conf_specification_temp
    ## which will in turn be passed to GetOpts
    ## As a result, _all_ of these variables may be overridden on the command line.
    $me->{ABSOLUTE} = 1 if (!defined($me->{ABSOLUTE}));
    $me->{add_to_path} = "/usr/bin:/usr/local/bin" if (!defined($me->{add_to_path}));
    $me->{arch_specific_exe} = 0 if (!defined($me->{arch_specific_exe}));
    $me->{base} = $ENV{PRFDB_HOME} if (!defined($me->{base}));
    $me->{blastdir} = 'blast' if (!defined($me->{blastdir}));
    $me->{boot_iterations} = 100 if (!defined($me->{boot_iterations}));
    $me->{boot_mfe_algorithms} = {pknots => \&RNAFolders::Pknots_Boot, nupack => \&RNAFolders::Nupack_Boot, hotknots => \&RNAFolders::Hotknots_Boot,} if (!defined($me->{boot_mfe_algorithms}));
    $me->{boot_randomizers} = {array => \&SeqMisc::ArrayShuffle,} if (!defined($me->{boot_randomizers}));
    $me->{check_webqueue} = 1 if (!defined($me->{check_webqueue}));
    $me->{checks} = 0 if (!defined($me->{checks}));
    $me->{config_file} = 'prfdb.conf' if (!defined($me->{config_file}));
    $me->{create_boot} = 0 if (!defined($me->{create_boot}));
    $me->{daemon_name} = 'prf_daemon.pl' if (!defined($me->{daemon_name}));
    $me->{database_args} = {AutoCommit => 1} if (!defined($me->{database_args}));
    $me->{database_host} = ['localhost',] if (!defined($me->{database_host}));
    $me->{database_name} = 'test' if (!defined($me->{database_name}));
    $me->{database_pass} = 'guest' if (!defined($me->{database_pass}));
    $me->{database_retries} = 0 if (!defined($me->{database_retries}));
    $me->{database_timeout} = 5 if (!defined($me->{database_timeout}));
    $me->{database_type} = 'mysql' if (!defined($me->{database_type}));
    $me->{database_user} = 'guest' if (!defined($me->{database_user}));
    $me->{debug} = undef if (!defined($me->{debug}));
    $me->{dirvar} = undef if (!defined($me->{dirvar}));
    $me->{do_agree} = 1 if (!defined($me->{do_agree}));
    $me->{do_comparison} = 1 if (!defined($me->{do_comparison}));
    $me->{do_nupack} = 1 if (!defined($me->{do_nupack}));
    $me->{do_pknots} = 1 if (!defined($me->{do_pknots}));
    $me->{do_hotknots} = 1 if (!defined($me->{do_hotknots}));
    $me->{do_boot} = 1 if (!defined($me->{do_boot}));
    $me->{do_landscape} = 1 if (!defined($me->{do_landscape}));
    $me->{do_utr} = 0 if (!defined($me->{do_utr}));
    $me->{ENV_LIBRARY_PATH} = $ENV{LD_LIBRARY_PATH} if (!defined($me->{ENV_LIBRARY_PATH}));
    $me->{EVAL_PERL} = 0 if (!defined($me->{EVAL_PERL}));
    $me->{exe_hotknots} = 'HotKnot' if (!defined($me->{exe_hotknots}));
    $me->{exe_nupack} = 'Fold.out.nopairs' if (!defined($me->{exe_nupack}));
    $me->{exe_nupack_boot} = 'Fold.out.boot.nopairs' if (!defined($me->{exe_nupack_boot}));
    $me->{exe_pknots} = 'pknots' if (!defined($me->{exe_pknots}));
    $me->{exe_perl} = '/usr/local/bin/perl -w' if (!defined($me->{exe_perl}));
    $me->{exe_rmprune} = 'rmprune' if (!defined($me->{exe_rmprune}));
    $me->{exe_rnafold} = 'RNAfold' if (!defined($me->{exe_rnafold}));
    $me->{exe_rnamotif} = 'rnamotif' if (!defined($me->{exe_rnamotif}));
    $me->{exe_rnamotif_descriptor} = 'descr/rnamotif_template.out' if (!defined($me->{exe_rnamotif_descriptor}));
    $me->{exe_rnamotif_template} = 'rnamotif_template' if (!defined($me->{exe_rnamotif_template}));
    $me->{exe_zcat} = 'zcat' if (!defined($me->{exe_zcat}));
    $me->{genome_table} = 'genome' if (!defined($me->{genome_table}));
    $me->{graph_distribution_x_size} = 400 if (!defined($me->{graph_distribution_x_size}));
    $me->{graph_distribution_y_size} = 300 if (!defined($me->{graph_distribution_y_size}));
    $me->{graph_font} = 'arial.ttf' if (!defined($me->{graph_font}));
    $me->{graph_font_size} = 9 if (!defined($me->{graph_font_size}));
    $me->{graph_landscape_x_size} = 800 if (!defined($me->{graph_landscape_x_size}));
    $me->{graph_landscape_y_size} = 600 if (!defined($me->{graph_landscape_y_size}));
    $me->{graph_stem_colors} = "black blue red green purple orange brown darkslategray" if (!defined($me->{graph_stem_colors}));
    $me->{has_modperl} = 0 if (!defined($me->{has_modperl}));
    $me->{index_species} = ['saccharomyces_cerevisiae', 'homo_sapiens', 'bos_taurus', 'danio_rerio', 'mus_musculus', 'rattus_norvegicus', 'xenopus_laevis', 'xenopus_tropicalis', 'saccharomyces_kudriavzevii', 'saccharomyces_castellii', 'saccharomyces_kluyveri', 'saccharomyces_bayanus', 'saccharomyces_paradoxus', 'schizosaccharomyces_pombe', 'saccharomyces_mikatae', 'caenorhabiditis_elegans', 'escherichia_coli', 'drosophila_melanogaster', 'virus'] if (!defined($me->{index_species}));
    $me->{INCLUDE_PATH} = 'html/' if (!defined($me->{INCLUDE_PATH}));
    $me->{INTERPOLATE} = 1 if (!defined($me->{INTERPOLATE}));
    $me->{landscape_seqlength} = 105 if (!defined($me->{landscape_seqlength}));
    $me->{log} = 'prfdb.log' if (!defined($me->{log}));
    $me->{log_error} = 'prfdb.errors' if (!defined($me->{log_error}));
    $me->{maintenance_skip_sleep} = 0 if (!defined($me->{maintenance_skip_sleep}));
    $me->{maintenance_skip_optimize} = 0 if (!defined($me->{maintenance_skip_optimize}));
    $me->{maintenance_skip_stats} = 0 if (!defined($me->{maintenance_skip_stats}));
    $me->{maintenance_skip_index} = 0 if (!defined($me->{maintenance_skip_index}));
    $me->{maintenance_skip_clouds} = 0 if (!defined($me->{maintenance_skip_clouds}));
    $me->{max_mfe} = 10.0 if (!defined($me->{max_mfe}));
    $me->{niceness} = 20 if (!defined($me->{niceness}));
    $me->{nupack_nopairs_hack} = 1 if (!defined($me->{nupack_nopairs_hack}));
    $me->{open_files} = [] if (!defined($me->{open_files}));
    $me->{output_file} = 'output.txt' if (!defined($me->{output_file}));
    $me->{pbs_arches} = 'linux' if (!defined($me->{pbs_arches}));
    $me->{pbs_cpu} = '1' if (!defined($me->{pbs_cpu}));
    $me->{pbs_cputime} = '24:00:00' if (!defined($me->{pbs_cputime}));
    $me->{pbs_memory} = '2000' if (!defined($me->{pbs_memory}));
    $me->{pbs_num_daemons} = '20' if (!defined($me->{num_daemons}));
    $me->{pbs_partialname} = 'fold' if (!defined($me->{pbs_partialname}));
    $me->{pbs_shell} = '/bin/bash' if (!defined($me->{pbs_shell}));
    $me->{pbs_template} = 'pbs_template' if (!defined($me->{pbs_template}));
    $me->{POST_CHOMP} = 1 if (!defined($me->{POST_CHOMP}));
    $me->{queue_table} = 'queue' if (!defined($me->{queue_table}));
    $me->{randomize_id} = 0 if (!defined($me->{randomize_id}));
    $me->{seqlength} = [100,75,50] if (!defined($me->{seqlength}));
    $me->{slip_site_1} = '^n\{3\}$' if (!defined($me->{slip_site_1}));
    $me->{slip_site_2} = '^w\{3\}$' if (!defined($me->{slip_site_2}));
    $me->{slip_site_3} = '^h\{3\}$' if (!defined($me->{slip_site_3}));
    $me->{slip_site_spacer_min} = 5 if (!defined($me->{slip_site_spacer_min}));
    $me->{slip_site_spacer_max} = 9 if (!defined($me->{slip_site_spacer_max}));
    $me->{snp_species_limit} = 'homo_sapiens' if (!defined($me->{snp_species_limit}));
    $me->{species_limit} = undef if (!defined($me->{species_limit}));
    $me->{sql_accession} = 'varchar(40)' if (!defined($me->{sql_accession}));
    $me->{sql_comment} = 'text not null' if (!defined($me->{sql_comment}));
    $me->{sql_genename} = 'varchar(120)' if (!defined($me->{sql_genename}));
    $me->{sql_gi_number} = 'varchar(80)' if (!defined($me->{sql_gi_number}));
    $me->{sql_id} = 'serial' if (!defined($me->{sql_id}));
    $me->{sql_index} = $PRFConfig::config->{sql_id} if (!defined($me->{sql_index}));
    $me->{sql_species} = 'varchar(80)' if (!defined($me->{sql_species}));
    $me->{sql_timestamp} = 'TIMESTAMP ON UPDATE CURRENT_TIMESTAMP DEFAULT CURRENT_TIMESTAMP' if (!defined($me->{sql_timestamp}));
    $me->{stem1_min} = 4 if (!defined($me->{stem1_min}));
    $me->{stem1_max} = 20 if (!defined($me->{stem1_max}));
    $me->{stem1_bulge} = 0.8 if (!defined($me->{stem1_bulge}));
    $me->{stem1_spacer_min} = 0 if (!defined($me->{stem1_spacer_min}));
    $me->{stem1_spacer_max} = 4 if (!defined($me->{stem1_spacer_max}));
    $me->{stem2_min} = 4 if (!defined($me->{stem2_min}));
    $me->{stem2_max} = 20 if (!defined($me->{stem2_max}));
    $me->{stem2_bulge} = 0.8 if (!defined($me->{stem2_bulge}));
    $me->{stem2_loop_min} = 0 if (!defined($me->{stem2_loop_min}));
    $me->{stem2_loop_max} = 3 if (!defined($me->{stem2_loop_max}));
    $me->{stem2_spacer_min} = 0 if (!defined($me->{stem2_spacer_min}));
    $me->{stem2_spacer_max} = 100 if (!defined($me->{stem2_spacer_max}));
    $me->{use_database} = 0 if (!defined($me->{use_database}));
    $me->{using_pbs} = 0 if (!defined($me->{using_pbs}));
    $me->{window_space} = 15 if (!defined($me->{window_space}));
    $me->{workdir} = 'work' if (!defined($me->{workdir}));
    $me->{z_test} = 'z_test' if (!defined($me->{z_test}));
    my ($open, %data, $config_option);
    if (-r $me->{config_file}) {
	$open = $me->{appconfig}->file($me->{config_file});
	%data = $me->{appconfig}->varlist("^.*");
	for $config_option (keys %data) {
	    $me->{$config_option} = $data{$config_option};
	    undef $data{$config_option};
	}
    }
#    else {
#	my $cwd = `pwd`;
#	print STDERR "Can't find the config file $me->{config_file} in $cwd\n";
#	die;
#   }

    ## This makes all of the above options over-rideable on the command line.
    my (%conf, %conf_specification, %conf_specification_temp);
    foreach my $default (keys %{$me}) {
	$conf_specification{"$default:s"} = \$conf{$default};
    }
    %conf_specification_temp = (
	'accession|i:s' => \$conf{accession},
	'arch:i' => \$conf{arch_specific_exe},
	'blast:s' => \$conf{blast},
	'boot:i' => \$conf{do_boot},
	'clear_queue' => \$conf{clear_queue},
	'copyfrom:s' => \$conf{copyfrom},
	'create_tables' => \$conf{create_tables},
	'dbexec:s' => \$conf{dbexec},
	'fasta_style:s' => \$conf{fasta_style},
	'fillqueue' => \$conf{fillqueue},
	'help|version' => \$conf{help},
	'hotknots:i' => \$conf{do_hotknots},
	'import:s' => \$conf{import_accession},
	'import_genbank:s' => \$conf{import_genbank},
	'import_genbank_accession:s' => \$conf{import_genbank_accession},
	'index_stats' => \$conf{index_stats},
	'input' => \$conf{input},
	'input_fasta:s' => \$conf{input_fasta},
	'input_file:s' => \$conf{input_file},
	'iterations:i' => \$conf{boot_iterations},
	'make_jobs' => \$conf{make_jobs},
	'landscape_length:i' => \$conf{landscape_seqlength},
	'length:i' => \$conf{seqlength},
	'make_landscape' => \$conf{make_landscape},
	'makeblast' => \$conf{makeblast},
	'maintain' => \$conf{maintain},
	'nodaemon:i' => \$conf{nodaemon},
	'nupack_nopairs:i' => \$conf{nupack_nopairs_hack},
	'optimize:s' => \$conf{optimize},
	'output' => \$conf{output},
	'pknots:i' => \$conf{do_pknots},
	'process_import_queue' => \$conf{process_import_queue},
	'randomize' => \$conf{randomize_id},
	'resetqueue' => \$conf{resetqueue},
	'shell' => \$conf{shell},
	'species:s' => \$conf{species},
	'startmotif:s' => \$conf{startmotif},
	'startpos:s' => \$conf{startpos},
	'do_stats:s' => \$conf{do_stats},
	'stats' => \$conf{stats},
	'utr:i' => \$conf{do_utr},
	'workdir:s' => \$conf{workdir},
	'zscore' => \$conf{zscore},
	'resync' => \$conf{resync},
	);
    ## This makes both of the above groups command-line changeable
    foreach my $name (keys %conf_specification_temp) {
	$conf_specification{$name} = $conf_specification_temp{$name};
    }
    undef(%conf_specification_temp);
    GetOptions(%conf_specification);

    ## This puts every option defined above into the PRFConfig namespace.
    foreach my $opt (keys %conf) {
	if (defined($conf{$opt})) {
	    $me->{$opt} = $conf{$opt};
	}
    }
    undef(%conf);
    if (defined($me->{help})) {
	Help();
    }
    if (defined($me->{blast_db})) {
	$ENV{BLASTDB} = qq"$me->{blast_db}/blast";
    }

    if (defined($me->{checks}) and $me->{checks} == 1) {
	$me->{debug} = 0;
    }
    if (defined($me->{debug})) {
	$me->{checks} = 1;
    }
    if (ref($me->{database_host}) eq '') {
	$me->{database_host} = eval($me->{database_host});
	$me->{database_otherhost} = $me->{database_host}->[1];
    }
    if (ref($me->{boot_mfe_algorithms}) eq '') {
	$me->{boot_mfe_algorithms} = eval($me->{boot_mfe_algorithms});
    }
    if (ref($me->{boot_randomizers}) eq '') {
	$me->{boot_randomizers} = eval($me->{boot_randomizers});
    }
    if (ref($me->{index_species}) eq '') {
	$me->{index_species} = eval($me->{index_species});
    }
    if (ref($me->{seqlength}) eq '') {
	$me->{seqlength} = eval($me->{seqlength});
    }
    if (defined($me->{shell})) {
	my $host = $me->{database_host}->[0];
	system("mysql -u $me->{database_user} --password=$me->{database_pass} -h $host $me->{database_name}");
	exit(0);
    }

    my $err = $me->{log_error};
    my $out = $me->{log};
    my $error_counter = 0;
    $me->{workdir} = $me->{base} . '/' . $me->{workdir};
    $me->{blastdir} = $me->{base} . '/' . $me->{blastdir};
    foreach my $dir (split(/:/, $me->{add_to_path})) {
	$ENV{PATH} = $ENV{PATH} . ':' . $dir;
    }
    $ENV{PATH} = $ENV{PATH} . ':' . $me->{workdir};
    $ENV{BLASTDB} = qq"$me->{base}/blast";


    if ($me->{arch_specific_exe} == 1) {
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
	    $ENV{PATH} = $ENV{PATH} . ':' . $me->{workdir} . '/irix';
	} elsif ($arch =~ /Linux/) {
	    $ENV{PATH} = $ENV{PATH} . ':' . $me->{workdir} . '/linux';
	} elsif ($arch =~ /Darwin/) {
	    $ENV{PATH} = $ENV{PATH} . ':' . $me->{workdir} . '/osx';
	} elsif ($arch =~ /AIX/) {
	    $ENV{PATH} = $ENV{PATH} . ':' . $me->{workdir} . '/aix';
	}
	foreach my $exe (@modified_exes) {
	    if ($arch =~ /IRIX/) {
		my $exe_path = join('', $me->{workdir} , '/irix/', $me->{$exe});
		$me->{$exe} = $exe_path;
	    } elsif ($arch =~ /AIX/) {
		my $exe_path = join('', $me->{workdir} , '/aix/', $me->{$exe});
		$me->{$exe} = $exe_path;
	    } elsif ($arch =~ /Darwin/) {
		my $exe_path = join('', $me->{workdir} , '/osx/', $me->{$exe});
		$me->{$exe} = $exe_path;
	    } elsif ($arch =~ /Linux/) {
		my $exe_path = join('', $me->{workdir} , '/linux/', $me->{$exe});
		$me->{$exe} = $exe_path;
	    } else {
		die("Architecture $arch not available.");
	    }
	}    ## For every modified executable
	
	if ($arch =~ /IRIX/) {
	    $me->{nupack} .= ".irix";
	    $me->{nupack_boot} .= ".irix";
	} elsif ($arch =~ /AIX/) {
	    $me->{nupack} .= ".aix";
	    $me->{nupack_boot} .= ".aix";
	} elsif ($arch =~ /Linux/) {
	    $me->{nupack} .= ".linux";
	    $me->{nupack_boot} .= ".linux";
	} elsif ($arch =~ /Darwin/) {
	    $me->{nupack} .= ".osx";
	    $me->{nupack_boot} .= ".osx";
	}
    }    ## End checking if multiple architectures are in use
    $ENV{EFNDATA} = $me->{workdir};
    $ENV{ENERGY_FILE} = qq"$me->{workdir}/dataS_G.rna";
    $ENV{EFNDATA} = $me->{workdir};
    $ENV{ENERGY_FILE} = qq"$me->{workdir}/dataS_G.rna";
    #$me->{remove_end} = 1;
    $me->{remove_end} = undef;
    return($me);
}

sub PRF_Out {
    my $me = shift;
    my $message = shift;
    my $out = $me->{log};
    open(OUTFH, ">>$out") or die "Unable to open the log file $out: $!\n";
    ## OPEN OUTFH in PRF_Out
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
    my $month = $mon + 1;
    my $y = $year + 1900;
    my $datestring = qq"$hour:$min:$sec $mday/$month/$y";
    print OUTFH "$datestring\t$message\n";
    close(OUTFH);
    ## CLOSE OUTFH in PRF_Out
}

sub PRF_Error {
    my $me = shift;
    my $message = shift;
    my $accession = shift;
    my $err = $me->{log_error};
    open(ERRFH, ">>$err") or die "Unable to open the log file $err: $!\n";
    ## OPEN ERRFH in PRF_Error
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
    my $month = $mon + 1;
    my $y = $year + 1900;
    my $datestring = qq"$hour:$min:$sec $mday/$month/$y";
    print ERRFH "$datestring\t$message\n";
    close(ERRFH);
    ## CLOSE ERRFH in PRF_Err
}

sub AddOpen {
    my $me = shift;
    my $file = shift;
    my @open_files = @{$me->{open_files}};

    if (ref($file) eq 'ARRAY') {
	foreach my $f (@{$file}) {
	    push(@open_files, $f);
	}
    } else {
	push(@open_files, $file);
    }
    $me->{open_files} = \@open_files;
    my $num_open_files = scalar(@open_files);
    return($num_open_files);
}

sub RemoveFile {
    my $me = shift;
    my $file = shift;
    my @open_files = @{$me->{open_files}};
    my @new_open_files = ();
    my $num_deleted = 0;
    my @comp = ();
    
    if ($file eq 'all') {
	foreach my $f (@{open_files}) {
	    unlink($f);
	    print STDERR "Deleting: $f\n" if (defined($me->{debug}) and $me->{debug} > 0);
	    $num_deleted++;
	}
	$me->{open_files} = \@new_open_files;
	return($num_deleted);
    } elsif (ref($file) eq 'ARRAY') {
	@comp = @{$file};
    } else {
	push(@comp, $file);
    }

    foreach my $f (@open_files) {
	foreach my $c (@comp) {
	    if ($c eq $f) {
		$num_deleted++;
		unlink($f);
	    }
	}
	push(@new_open_files, $f);
    }
    $me->{open_files} = \@new_open_files;
    return($num_deleted);
}

sub Help {
    my $helpstring = qq"
The prfdb takes many possible options including: (consult PRFConfig.pm for more)
accession      fold a particular accession
blast          provide it an accession and it will blast it to the rest of the prfdb
makeblast      create a local blast database from all the sequences in the genome table
optimize       perform a mysql specific optimization of the tables in the db
species        specify a species to work with
copyfrom       copy the genome table from one database to another
import         provide a single accession to import into the prfdb
input_file     provide the filename containing one accession per line
input_fasta    provide the filename containing fasta input (keep in mind the NCBI format)
fasta_style    see input_fasta -- currently can handle sgd and ncbi styles
fillqueue      fill up the queue with everything from the genome table
resetqueue     set all entries in the queue to unexamined
startpos       explicitly set the start position for a folding -- for use with --accession
startmotif     start at a particular subsequence (I don't think this is completed)
length         set the window size
landscape_length set the landscape window size
nupack         explicitly turn on/off nupack
pknots         explicitly turn on/off pknots
hotknots       explicitly turn on/off hotknots
boot           turn on/off randomization
utr            turn on/off the folding in the 3' utr
checks         perform a series of checks to see if the database is ready for use
";
    print $helpstring;
    exit(0);
}


sub AUTOLOAD {
    my $me = shift;
    my $type = ref($me) or die("$me is not an object");
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion
    if (@_) {
	return $me->{$name} = shift;
    } else {
	return $me->{$name};
    }
}

#END {
#    my $me = shift;
#    if (defined($me->{dbh})) {
#	$me->{dbh}->disconnect();
#    }
#    $me->RemoveFile('all');
#}

1;
