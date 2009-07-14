#!/usr/bin/perl
use strict;

BEGIN {
    use lib 'lib';
    $ENV{PATH} = '/bin:/usr/bin:/usr/local/bin';
    $ENV{CDPATH} = '' if defined $ENV{CDPATH};
    $ENV{SHELL} = '/bin/bash' if defined $ENV{SHELL};
    $ENV{ENV} = '' if defined $ENV{ENV};
    $ENV{IFS} = '' if defined $ENV{IFS};

    use CGI qw(-private_tempfiles);
    #bring this in before mason, to make sure we
    #set private_tempfiles
}

package PRFdb::Mason;
use vars qw($config $db $Handler $r);

#This drags in RT's config.pm
BEGIN {
    use PRFConfig;
    $config = $PRFConfig::config;
    use PRFdb;
    use HTML::Mason::ApacheHandler;
    $db = new PRFdb(config => $config);
}

my $Handler = new HTML::Mason::ApacheHandler(
	comp_root => [[ local => $RT::MasonLocalComponentRoot ],
		      (map {[ "plugin-".$_->Name => $_->ComponentRoot ]} @{RT->Plugins}),
		      [ standard => $RT::MasonComponentRoot ] ],
	default_escape_flags => 'h',
	data_dir             => "$RT::MasonDataDir",
        allow_globals        => [qw(%session)],
        # Turn off static source if we're in developer mode.
        static_source        => (RT->Config->Get('DevelMode') ? '0' : '1'), 
        use_object_files     => (RT->Config->Get('DevelMode') ? '0' : '1'), 
        autoflush            => 0,
        error_format         => (RT->Config->Get('DevelMode') ? 'html': 'brief'),
        request_class        => 'RT::Interface::Web::Request',
	named_component_subs => $INC{'Devel/Cover.pm'} ? 1 : 0,
					     ) };

#if ($show_error) {
#    $h = HTML::Mason::CGIHandler->new
#        ( comp_root => [
#              [main => “/usr/local/www/GroovieWebapp/site”],
#              [libs => “/usr/local/www/GroovieWebapp/libs”]
#          ],
#          data_dir => “/usr/local/www/GroovieWebapp/mdata”,
#          allow_globals => [qw($Schema $Session)]
#	  );

);

sub handler {
    ($r) = @_;
    local $SIG{__WARN__};
    local $SIG{__DIE__};
    my $status;
    my %session;
    eval { $status = $Handler->handle_request($r) };
    undef(%session);
    $Handler->CleanupRequest();
    return($status);
}

1;
