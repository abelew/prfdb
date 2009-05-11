#!/usr/bin/perl -w  -I/usr/share/httpd/prfdb/usr/lib/perl5/site_perl/

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
my $counter = 0;
my @answer = ();
while (my $line = <PK>) {
  my ($num, $letter, $bound) = split(/\s+/, $line);
  if ($bound == 0) {
	$answer[$counter] = undef;
  }
  else {
	$answer[$counter] = $bound;
  }
}

my $string = '';
for my $c (0 .. $#answer) {
  if (defined($answer[$c])) {
	$string .= "$answer[$c] ";
  }
  else {
	$string .= ". ";
  }
}
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
