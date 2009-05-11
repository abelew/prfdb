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

open(PK, "<$inputfile");
my ($string, $counter, $line_to_read,$crap,$return,);
while (my $line = <PK>) {
    $counter++;
    chomp $line;
    ### The NAM field prints out the name of the sequence
    ### Which is set to the slippery site in RNAMotif
    if ( $line =~ /^NAM/ ) {
	( $crap, $return->{slipsite} ) = split( /NAM\s+/, $line );
	$return->{slipsite} =~ tr/actgTu/ACUGUU/;
    } elsif ( $line =~ /^\s+\d+\s+[A-Z]+/ ) {
	$line_to_read = $counter + 2;
    } elsif ( defined($line_to_read) and $line_to_read == $counter ) {
	$line =~ s/^\s+//g;
	$line =~ s/$/ /g;
	$string .= $line;
    } elsif ( $line =~ /\/mol\)\:\s+/ ) {
	( $crap, $return->{mfe} ) = split( /\/mol\)\:\s+/, $line );
    } elsif ( $line =~ /found\:\s+/ ) {
	( $crap, $return->{pairs} ) = split( /found\:\s+/, $line );
    }
}    ## For every line of pknots
close(PK);
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
$feynman_output_filename =~ s/\.png/\.svg/g;
my $feynman_dimensions = $feynman_pic->Make_Feynman($outputfile);
print "Done, dimensions: $feynman_dimensions\n";
