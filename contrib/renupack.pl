#! /usr/bin/perl -w
use strict;
use lib '../lib';
use PRFConfig;
use PRFdb;
use RNAFolders;

$SIG{INT} = 'CLEANUP';
$SIG{BUS} = 'CLEANUP';
$SIG{SEGV} = 'CLEANUP';
$SIG{PIPE} = 'CLEANUP';
$SIG{ABRT} = 'CLEANUP';
$SIG{QUIT} = 'CLEANUP';

our $config = $PRFConfig::config;
our $db     = new PRFdb;
my $parser = new PkParse();
my $start_mfe_id = $ARGV[0];
my $default = 314957;

$start_mfe_id = $default unless (defined($start_mfe_id));

my $select = qq(SELECT id,genome_id,species,accession,start,sequence,parsed,output FROM mfe WHERE algorithm = 'nupack' and id > '$start_mfe_id' ORDER BY id);
print "Starting $select\n";
my $info = $db->MySelect($select);
foreach my $id (@{$info}) {
  my $mfe_id = $id->[0];
  my $genome_id = $id->[1];
  my $species = $id->[2];
  my $accession = $id->[3];
  my $start = $id->[4];
  my $seq = $id->[5];
  my $parsed = $id->[6];
  my $output = $id->[7];
  $parsed =~ s/\s+//g;
  my $parsedlength = length($parsed);
  my $seqlength = length($seq);
  print "The parsed length is: $parsedlength and sequence is $seqlength\n";
  next if ($parsedlength == $seqlength);
  my $data = ">tmp
$seq
";
  my $inputfile = $db->Sequence_to_Fasta($data);
  my $fold_search = new RNAFolders(
                                   file => $inputfile,
                                   genome_id => $genome_id,
                                   species   => $species,
                                   accession => $accession,
                                   start     => $start,
                                  );
  my $nupack = $fold_search->Nupack_NOPAIRS();
  my $new_output = $nupack->{output};
  my $new_parens = $nupack->{parens};
  my $new_parsed = $nupack->{parsed};
  my $update = qq(UPDATE mfe set output = '$new_output', parens = '$new_parens', parsed = '$new_parsed' WHERE id = '$mfe_id');
#  print "$update\n";
  my ( $cp, $cf, $cl ) = caller();
  $db->Execute($update, [], [$cp,$cf,$cl]);
  print "Completed $mfe_id\n";
  PRFdb::RemoveFile($inputfile);
}



sub CLEANUP {
    $db->Disconnect();
    PRFdb::RemoveFile('all');
    print "\n\nCaught Fatal signal.\n\n";
}

END {
    $db->Disconnect();
    PRFdb::RemoveFile('all');
}
