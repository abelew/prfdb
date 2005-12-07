#!/usr/bin/perl -w

# PREAMBLE ******************
# print out NOW, instead of later.
use strict;
use CGI qw/:standard :html3/;
use CGI::Carp qw(fatalsToBrowser carpout);
use DBI;
use Template;
use lib "lib";
#use PRFConfig;
#use PRFdb;
#use RNAMotif_Search;

# configuration
#my $base = "http://" . $ENV{HTTP_HOST} . $ENV{SCRIPT_NAME};


# set vars
my $cgi = new CGI;
print $cgi->header;

my $config = {
    INCLUDE_PATH => 'templates',  # or list ref
    INTERPOLATE  => 1,               # expand "$var" in plain text
    POST_CHOMP   => 1,               # cleanup whitespace
    EVAL_PERL    => 1,               # evaluate Perl code blocks
};
my $template = Template->new($config);
my $text_body = "";


my $db = "prfdb05";
my $dbhost = "prfdb.no-ip.org";
my $user = "apacheuser";
my $pass = "2vjwotuhew";
my $dsn = "dbi:mysql:$db:hostname=$dbhost";
my %attr = { RaiseError => 1, AutoCommit => 1};
my $dbh = &DBI_Connect($dsn, $user, $pass, \%attr);

# get parameters
if($cgi->param('browse') ){ &BROWSE; }
elsif( $cgi -> param('detail')){ &DETAIL; }
else{
    &BROWSE;
}

my $vars = { text_body => $text_body };

$template->process("default.dwt",$vars) || die $template->error();

sub DETAIL{
    my $body = "";
    my $select = $cgi->param('select');
    my $query = $cgi->param('query');
    my $slipstart = $cgi->param('slipstart');
    
    # clean offending badness
    $select =~ s/[^\w\s-:]/_/g;
    $query =~ s/[^\w\s-:]/_/g;
    $slipstart =~ s/[^\d]/_/g;
    
    my $q1 = ""; # 1st query; a reference to a 2D-array representing all the rows of the result set.
    my $sql = "";
    if( $query and $select eq 'accession' ){
        $sql = "select species,genename,comment from genome where accession = \"$query\"";
    }else{
        # RUN FOR YOUR LIFE!
        $body .= "$query was not found in &DETAIL\n";
        my $browse_vars = { results => $body };
        $template->process("browser.lbi",$browse_vars,\$text_body) || die $template->error();
        return;
    }
    
    my $q1 = &DBI_doSQL( $dbh, $sql);

    # get the ONE row in the result set.
    my $row = pop(@$q1);
    my ($sliplist,$sig_count,$ss_count) = &SLIPLIST( $query, $slipstart ); # $$row[1] = accession ID

    my $detail_list = "";
    my $vars={
        accession => $query,
        species => $$row[0],
        genename => $$row[1],
        comments => $$row[2],
        sig_count => $sig_count,
        ss_count => $ss_count,
        sliplist => $sliplist
    };
    
    $template->process("detail_header.lbi", $vars, \$body) || die $template->error();
    my $q2 = DBI_doSQL($dbh, "select id, slipsite, barcode, mfe, pairs from pknots where accession = \"$query\" and start = $slipstart order by mfe" );
    while(my $r = shift(@$q2)){
        my $temp_seq = $$r[1];
        my $detail_vars = {
            id => $$r[0],
            start => $slipstart,
            slip => $$r[1],
            barcode => $$r[2],
            mfe => $$r[3],
            bp => $$r[4]
        };
        $template->process("detail_body.lbi", $detail_vars, \$body) || die $template->error();
    }
    $template->process("detail_footer.lbi", "", \$body) || die $template->error();
    
    my $browse_vars = { results => $body };
    $template->process("browser.lbi", $browse_vars, \$text_body) || die $template->error();
}

sub BROWSE{
    my $body = "";
    my $select = $cgi->param('select');
    my $query = $cgi->param('query');
    
    # clean offending badness
    $select =~ s/[^\w\s-:]/_/g;
    $query =~ s/[^\w\s-:]/_/g;
    
    my $q1 = ""; # 1st query; a reference to a 2D-array representing all the rows of the result set.
    my $sql = "";
    if( $query and $select eq 'genename' ){
        $sql = "select id,accession,species,genename,comment,lastupdate,mrna_seq from genome where genename regexp \"$query\"";
    }elsif( $query and $select eq 'accession' ){
        $sql = "select id,accession,species,genename,comment,lastupdate,mrna_seq from genome where accession regexp \"$query\"";
    }else{
        # RUN FOR YOUR LIFE!
        my $browse_vars = { results => $body };
        $template->process("browser.lbi",$browse_vars,\$text_body) || die $template->error();
        return;
    }

    $q1 = DBI_doSQL( $dbh, $sql);
    if( scalar(@$q1) == 0 ){
        #display no match page.
        $body .= "<p>\"$query\" was not found in our database. Please try again.</p>";
    }elsif( scalar( @$q1) > 1){
        #display multi-genome page.
        # the following is just for a place holder
        #$body .= "<p>\"$query\" found more than one choice in the PRFdb. Please be more specific.</p>";
         $body .= &MULTIMATCH($q1,$body);
    }else{
        $body .= &SINGLEMATCH($q1,$body );
        #display single match page.
    }
    
    my $browse_vars = { results => $body };
    $template->process("browser.lbi",$browse_vars,\$text_body) || die $template->error();
}

#############
# MULTIMATCH
sub MULTIMATCH{
    my $q1 = shift;
    my $body = shift;
    
    # id,accession,species,genename,comment,lastupdate,mrna_seq
    $template->process("multimatch_header.lbi","",\$body) || die $template->error();
    for(my $i = 0; $i < @$q1; $i++){
        my $row = $$q1[$i];
        
        #count the number of slippery sites for this accession
        my $q2= &DBI_doSQL($dbh,"select count(distinct start) from pknots where accession=\'$$row[1]\'");
        my $r2 = shift(@$q2);
        
        my $vars = {
            counter => $i+1,
            accession => $$row[1],
            species => $$row[2],
            genename => $$row[3],
            comments => $$row[4],
            ss_count => $$r2[0]
        };
        $template->process("multimatch_body.lbi",$vars,\$body) || die $template->error();
    }
    $template->process("multimatch_footer.lbi","",\$body) || die $template->error();
    return $body;
}

#############
# SINGLEMATCH
sub SINGLEMATCH{
    my $q1 = shift;
    my $body = shift;
    
    #my $sig_count = 0;
    #my $ss_count = 0;
    
    # get the ONE row in the result set.
    my $row = pop(@$q1);
    
    my ($sliplist,$sig_count,$ss_count) = &SLIPLIST( $$row[1] ); # $$row[1] = accession ID
    
    $$row[6] = &PRETTY_MRNA($$row[1],$$row[6]);
    
    my $vars={
        id => $$row[0],
        accession => $$row[1],
        species => $$row[2],
        genename => $$row[3],
        comments => $$row[4],
        timestamp => $$row[5],
        mrna_seq => $$row[6],
        sig_count => $sig_count,
        ss_count => $ss_count,
        sliplist => $sliplist
    };
    $template->process("genome.lbi",$vars,\$body) || die $template->error();
    return $body;
}

sub SLIPLIST{
    my $accession = shift;
    my $highlighted_slip = shift;
    my $sig_count = 0;
    my $ss_count = 0;

    # find the number of slippery sites, there position, etc.
    # we could add direct links here for each slippery site.
    # also, this next block is very close to similar block in &PRETTY_MRNA; fix later.
    my $q2 = DBI_doSQL($dbh, "select distinct start,slipsite,count(id) from pknots where accession = \'$accession\' group by start order by start" );
    my $sliplist = "";
    $template->process("sliplist_header.lbi","",\$sliplist) || die $template->error();
    while(my $r = shift(@$q2)){ 
        my $sliplist_vars = {
            accession => $accession,
            slipstart => $$r[0],
            slipseq => $$r[1],
            pknotscount => $$r[2]
        };
        $ss_count++;
        $sig_count += $$r[2];
        if( $highlighted_slip eq $$r[0] ){
            $template->process("sliplist_body_highlighted.lbi",$sliplist_vars,\$sliplist) || die $template->error();
        }else{
            $template->process("sliplist_body.lbi",$sliplist_vars,\$sliplist) || die $template->error();
        }
    }
    $template->process("sliplist_footer.lbi","",\$sliplist) || die $template->error();
    return ($sliplist,$sig_count,$ss_count);
}

#############
# PRETTY mRNA
sub PRETTY_MRNA{
    my $accession = shift;
    my $seq = shift;
    my @seq = split( //, $seq);
    
    # EDIT THESE TAGS TO ADD href links later on...
    my $prefont_ss = "<font color=\"#FF0000\"><strong>";
    my $postfont_ss = "</strong></font>";
    
    my $resultset = DBI_doSQL($dbh, "select distinct start from pknots where accession = \'$accession\' order by start" );
    my $slips = " ";
    while(my $r = shift(@$resultset)){ $slips .= " $$r[0] "; }
    
    $seq = "";
    my $slipcounter = 0;
    my $x  = "";
    for(my $i = 0; $i <= @seq; $i++){
        $seq .= $seq[$i];
        $x = $i+2;
        if( $slips =~ / $x /){
            unless($slipcounter){ $seq .= $prefont_ss; }
            $slipcounter = 8;
            $slips =~ s/ $x //;
        }
        if( $slipcounter > 1 ){ $slipcounter-- }
        elsif( $slipcounter == 1) { $slipcounter--; $seq .= $postfont_ss; }        
    }
    $seq =~ s/($prefont_ss[ATGC])/$1 /g;
    $seq =~ s/([ATGC]{3})/$1 /g;
    
    # color the -1 Frame stops tga tag taa
    # yeah.. this is a mess; but it work
    $seq =~ s/T \<\/strong\>\<\/font>(AA|AG|GA)/\<\/strong\>\<\/font\>\<font color =\"#0000FF\"\>\<strong\>T $1\<\/strong\>\<\/font\>/g;
    $seq =~ s/(#FF0000.*?)T (AA|GA|AG)/$1\<font color =\"#0000FF\"\>\<strong\>T $2\<\/strong\>\<\/font\>/g;
    return $seq;
}

#############
# DBI_Connect
# 
# REQUIRES:
#	DBI module
# PARAMETERS:
#	1 - datasource name (e.g. DBI:ODBC:PRFdb);
#	2 - user name for the database
#	3 - password
#
# RETURNS:
#	$dbh - the database handle
sub DBI_Connect {
	my($datasource,$username, $password,$attr) = @_;
	my $dbh;
	my $conn_error;
	
	# Try connecting to the database, as usual.  If that fails, print
	# an error message and exit.
	unless ($dbh = DBI->connect($datasource, $username, $password, $attr)) {
		$conn_error = DBI->errstr();
		print "Failed to connect to $datasource: $conn_error";
		exit();
	}
	
	return $dbh;
}

#############
# DBI_doSQL
#
# REQUIRES:
#	DBI module
#	valid database handle with open connection to database
# PARAMETERS:
#	1 - database handle (e.g. $dbh);
#	2 - sql statment
#
# RETURNS:
#	\@resultSet - an array of arrays (@record1[col1,col2,col3],@record2[col1,col2,col3],etc...)
sub DBI_doSQL{
	my($dbh,$statement) = @_;
	my $sth;
	my $returncode;
	my $prep_error;
	my $data_error;
	my @resultSet = ();
	my @record = ();
	
	unless( $sth = $dbh->prepare($statement) ){
		$prep_error = $dbh->errstr;
		print "SQL syntax error!\n\n$prep_error\n\nYour statement was \n\n$statement\n\nExiting...\n";
		exit();
	}
	
	if( $returncode = $sth -> execute() ) {
		while(@record = $sth -> fetchrow_array() ){ push(@resultSet, [@record] ); }
		$sth -> finish();
	} else {
		$data_error = $dbh->errstr;
		print "SQL execution error!\n\n$data_error\n\nYour statement was \n\n$statement\n\n";
		exit();
	}
	return \@resultSet;
}

#############
# DBI_Disconnect
#
# REQUIRES:
#	DBI module
# PARAMETERS:
#	1 - $dbh, database handle
#
# RETURNS:
#	$rc - string, the return code.
sub DBI_Disconnect{
	my ($dbh) = @_;
	my $rc = $dbh->disconnect or warn $dbh->errstr; 
}

1; 
