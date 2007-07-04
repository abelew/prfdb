package PRF_Condor;
use strict;
use DBI;
use lib 'lib';
use PRFConfig qw / PRF_Error PRF_Out /;
use Template;

my $config = $PRFConfig::config;
$config->{INCLUDE_PATH} = 'templates/';
$config->{PRE_PROCESS}  = undef;
$config->{POST_CHOMP}   = undef;
my $template = new Template($config);
my $dbh;
my $workdir = $config->{tmpdir};
my $base = $config->{base};

sub new {
  my ( $class, %arg ) = @_;
  if ( defined( $arg{config} ) ) {
    $config = $arg{config};
  }
  my $me = bless {
    dsn  => $config->{dsn},
    user => $config->{user},
  }, $class;
  return ($me);
}

sub Create {
  my $me   = shift;
  my $slot = shift;
  my $type = shift;
  my $vars = {
    slot                    => $slot,
    memory                  => '512',
    operating_system        => 'OSX',
    arch                    => 'PPC',
    universe                => 'vanilla',
    should_transfer_files   => 'YES',
    when_to_transfer_output => 'ON_EXIT',
  };
  if ( $type eq 'nupack' ) {
    $vars->{executable}           = 'Fold.out';
    $vars->{transfer_input_files} = "dataS_G.dna, dataS_G.rna, ${slot}.fasta";
    $vars->{arguments}            = " ${slot}.fasta";
  } elsif ( $type eq 'pknots' ) {
    $vars->{executable}           = 'pknots';
    $vars->{transfer_input_files} = "${slot}.fasta";
    $vars->{arguments}            = " -k ${slot}.fasta";
  }
  $template->process( 'condor_template.txt', $vars, "$workdir/${slot}_${type}.job" ) or die $template->error();
}

sub Submit {
  my $me   = shift;
  my $slot = shift;
  my $type = shift;
  chdir($workdir);
  my $command = qq(condor_submit -v ${slot}_${type}.job &);
  print "$command\n";
  system($command);
  chdir($base);
}

sub Check_Log {
  my $me          = shift;
  my $slot        = shift;
  my $log_file    = "${workdir}/${slot}.log";
  my $error_file  = "${workdir}/${slot}.err";
  my $output_file = "$workdir}/${slot}.out";
  `pwd`;
  print "logfile: $log_file\n";
  open( LOG, "<$log_file" ) or die("Could not open $log_file $!\n");
  my $status      = undef;
  my $final_stats = {};

  while ( my $line = <LOG> ) {
    next if ( $line =~ /^\.\.\.$/ );
    next if ( $line =~ /Job was not checkpointed/ );
    $line =~ s/was\s//g;

    #    if ($line =~ /^.*\d\d:\d\d:\d\d\sJob\s(\w+)\s/) {
    if ( $line =~ /Job\s(\w+)/ ) {
      $status = $1;
    }
  }
  close(LOG);
  if ( $status eq 'terminated' ) {
    $final_stats = Get_Status($log_file);
  }
  return ($status);
}

sub Get_Status {
  my $log_file = shift;
  my $stats;
  open( LOG, "<$log_file" ) or die("Cannot open log file in Get_status $!");
  while ( my $line = <LOG> ) {
    if ( $line =~ /\(return value (\d+)\)/ ) {
      $stats->{return_code} = $1;
    } elsif ( $line =~ /\s+Usr (\d+) (\d+:\d+:\d+), Sys (\d+) (\d+:\d+:\d+)\s+\-\s+Run Remote Usage/ ) {
      $stats->{run_remote_user_num}  = $1;
      $stats->{run_remote_user_time} = $2;
      $stats->{run_remote_sys_num}   = $3;
      $stats->{run_remote_sys_time}  = $4;
    } elsif ( $line =~ /\s+Usr (\d+) (\d+:\d+:\d+), Sys (\d+) (\d+:\d+:\d+)\s+\-\s+Run Local Usage/ ) {
      $stats->{run_local_user_num}  = $1;
      $stats->{run_local_user_time} = $2;
      $stats->{run_local_sys_num}   = $3;
      $stats->{run_local_sys_time}  = $4;
    } elsif ( $line =~ /\s+Usr (\d+) (\d+:\d+:\d+), Sys (\d+) (\d+:\d+:\d+)\s+\-\s+Total Remote Usage/ ) {
      $stats->{total_remote_user_num}  = $1;
      $stats->{total_remote_user_time} = $2;
      $stats->{local_remote_sys_num}   = $3;
      $stats->{local_remote_sys_time}  = $4;
    } elsif ( $line =~ /\s+Usr (\d+) (\d+:\d+:\d+), Sys (\d+) (\d+:\d+:\d+)\s+\-\s+Total Local Usage/ ) {
      $stats->{total_local_user_num}  = $1;
      $stats->{total_local_user_time} = $2;
      $stats->{local_local_sys_num}   = $3;
      $stats->{local_local_sys_time}  = $4;
    }
  }
  close(LOG);
  return ($stats);
}

1;
