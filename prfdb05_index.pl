#!/usr/bin/perl -w

# PREAMBLE ******************
# print out NOW, instead of later.
use strict;
use CGI qw/:standard :html3/;
use CGI::Carp qw(fatalsToBrowser carpout);
use DBI;
use Template;

# configuration
#my $base = "http://" . $ENV{HTTP_HOST} . $ENV{SCRIPT_NAME};

my $config = {
    INCLUDE_PATH => 'templates',  # or list ref
    INTERPOLATE  => 1,               # expand "$var" in plain text
    POST_CHOMP   => 1,               # cleanup whitespace
    EVAL_PERL    => 1,               # evaluate Perl code blocks
};

# set vars
my $cgi = new CGI;
my $template = Template->new($config);
my $text_body = "";

# get parameters
if ($cgi->param('browse') ){ &BROWSE; }
else{
    &BROWSE;
}

my $vars = { text_body => $text_body };

#print $cgi->header,start_html;
print $cgi->header;
$template->process("default.dwt",$vars) || die $template->error();
#print $cgi->end_html;


sub BROWSE{
    my $results = "";
    if( $cgi -> param('query') ){
        
    }
    my $browse_vars = {
        results => $results
    };
    $template->process("browser.lbi",$browse_vars,\$text_body) || die $template->error();
}

sub CHECKPARAMS{
    my $p = shift;
    my $r = $p;    
    if($p =~ /[^\w-]/){ 
        $p =~ s/[^\w-]/_/g;
        $r = "<p>Your query <b>$p</b> contains non-alphanumeric characters. Please stop hacking us or <a href='../database/prfdbSeqTools/gene_lookup.htm'>try again</a>.</p>";
    }elsif(length($p) > 7){
        $r = "<p>Your query's name is too long. Must be less than 7 characters in length. Please try <a href='../database/prfdbSeqTools/gene_lookup.htm'>try again</a>.</p>";
    }
    unless($p){
        $r = "<p>You did not enter a query name. Please <a href='../database/prfdbSeqTools/gene_lookup.htm'>try again</a>.</p>" ;
    }   
    return $r;
}


1; 
