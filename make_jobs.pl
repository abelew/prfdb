#!/usr/local/bin/perl -w
use strict;
use lib "$ENV{HOME}/usr/perl.irix/lib";
use lib 'lib';
use Template;
use PRFConfig;
my $config = $PRFConfig::config;
chdir( $config->{base} );
my $template_config = $config;
$template_config->{PRE_PROCESS} = undef;
$template_config->{EVAL_PERL}   = 0;
$template_config->{INTERPOLATE} = 0;
$template_config->{POST_CHOMP}  = 0;
my $template = new Template($template_config);

my $base       = $template_config->{base};
my $input_file = "$base/html/job_template";
my @arches     = split( / /, $config->{pbs_arches} );
foreach my $arch (@arches) {
  system("mkdir jobs/$arch") unless ( -d "jobs/$arch" );
  my $archchar = substr($arch,0,3);
  foreach my $daemon ( "01" .. $config->{num_daemons} ) {
    my $output_file  = "jobs/$arch/$daemon";
    my $name         = $template_config->{pbs_partialname};
    my $pbs_fullname = "${name}_${archchar}_${daemon}";
    my $incdir       = "${base}/usr/perl.${arch}/lib";
    my $vars         = {
      pbs_shell   => $template_config->{pbs_shell},
      pbs_memory  => $template_config->{pbs_memory},
      pbs_cpu     => $template_config->{pbs_cpu},
      pbs_arch    => $arch,
      pbs_name    => $pbs_fullname,
      pbs_cput    => $template_config->{pbs_cput},
      perl        => $template_config->{perl},
      incdir      => $incdir,
      daemon_name => $template_config->{daemon_name},
      job_num     => $daemon,
      base        => $config->{base},
    };
    $template->process( $input_file, $vars, $output_file ) or die $template->error();
  }
}

