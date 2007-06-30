#! /usr/bin/perl -w
use strict;
use lib '../lib';
use PRFdb;
use RNAFolders;

my $db     = new PRFdb;
my $parser = new PkParse();
my $accession = $ARGV[0];

my $select = qq(SELECT id,genome_id,species,accession,start,sequence FROM mfe WHERE algorithm = 'nupack' and accession = '$accession' ORDER BY id);
print "Starting $select\n";
my $info = $db->MySelect($select);
foreach my $id (@{$info}) {
  my $mfe_id = $id->[0];
  my $genome_id = $id->[1];
  my $species = $id->[2];
  my $accession = $id->[3];
  my $start = $id->[4];
  my $seq = $id->[5];
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
  unlink($inputfile);
}


