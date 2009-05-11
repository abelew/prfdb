#!/usr/bin/env perl -w -I/usr/share/httpd/prfdb/usr/lib/perl5/site_perl/

use strict;
use lib '../lib';
use PRFdb;
use PRFConfig;
use PRFGraph;
use PkParse;

our $config = $PRFConfig::config;
our $db = new PRFdb;
our $graph = new PRFGraph;

my $inputfile = $ARGV[0];
my $seqfile = $ARGV[1];
my $outputfile = $ARGV[2];

open(FASTA, "<$seqfile");
my $sequence = '';
while (my $l = <FASTA>) {
    next if ($l =~ /^\>/);
    chomp $l;
    $sequence = $sequence . $l;
}
print "TEST: $sequence\n";
close(FASTA);
open(NU, "<$inputfile");
my $count         = 0;
my @nupack_output = ();
my $pairs         = 0;
my $return;
while ( my $line = <NU> ) {
    if ( $line =~ /Error opening loop data file: dataS_G.rna/ ) {
	PRF_Error("RNAFolders::Nupack_NOPAIRS, Missing dataS_G.rna!");
    }
    $count++;
    ## The first 15 lines of nupack output are worthless.
    next unless ( $count > 14 );
    chomp $line;
    if ( $count == 15 ) {
	my ( $crap, $len ) = split( /\ \=\ /, $line );
	$return->{seqlength} = $len;
    } elsif ( $count == 17 ) {    ## Line 17 returns the input sequence
	$return->{sequence} = $line;
    } elsif ( $line =~ /^\d+\s\d+$/ ) {
	my ( $fiveprime, $threeprime ) = split( /\s+/, $line );
	my $five  = $fiveprime - 1;
	my $three = $threeprime - 1;
	$nupack_output[$three] = $five;
	$nupack_output[$five]  = $three;
	$pairs++;
	$count--;
    } elsif ( $count == 18 ) {    ## Line 18 returns paren output
	$return->{parens} = $line;
    } elsif ( $count == 19 ) {    ## Get the MFE here
	my $tmp = $line;
	$tmp =~ s/^mfe\ \=\ //g;
	$tmp =~ s/\ kcal\/mol//g;
	$return->{mfe} = $tmp;
    } elsif ( $count == 20 ) {    ## Is it a pseudoknot?
	if ( $line eq 'pseudoknotted!' ) {
	    $return->{knotp} = 1;
	} else {
	    $return->{knotp} = 0;
	}
    }
}    ## End of the line reading the nupack output.
close(NU);

for my $c ( 0 .. $#nupack_output ) {
    $nupack_output[$c] = '.' unless ( defined $nupack_output[$c] );
}
my $nupack_output_string = '';
foreach my $char (@nupack_output) { $nupack_output_string .= "$char "; }
my $string = $nupack_output_string;
#$return->{pairs}  = $pairs;
#my $parser;

$string =~ s/\s+/ /g;
my $parser = new PkParse(debug=>0);

my @struct_array = split( /\s+/, $string );
my $out          = $parser->Unzip( \@struct_array );
my $new_struc    = PkParse::ReBarcoder($out);
my $barcode      = PkParse::Condense($new_struc);
my $parsed       = '';
foreach my $char ( @{$out} ) {
    $parsed .= $char . ' ';
}
my $pk_output = PkParse::ReOrder_Stems($parsed);

my $feynman_pic = new PRFGraph({
    sequence => $sequence,
    parsed => $pk_output,
    output => $string,
			       });
#my $feynman_output_filename = $feynman_pic->Picture_Filename({type => 'feynman',});
my $feynman_output_filename = $outputfile;
my $feynman_dimensions = $feynman_pic->Make_Feynman($outputfile);
print "Done, dimensions: $feynman_dimensions\n";
