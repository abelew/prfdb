#!/usr/bin/perl -w
use strict;
use lib '../lib';
use PRFdb;
use PRFConfig;
use PRFGraph;

our $config = $PRFConfig::config;
our $db = new PRFdb;
our $graph = new PRFGraph;

my $stuff = $db->MySelect({statement => qq/SELECT id FROM mfe/,});
foreach my $id_array (@{$stuff}) {
    my $id = $id_array->[0];
    print "On $id\n";
    my $mfes = $db->MySelect({statement => qq/SELECT * FROM mfe WHERE id = '$id'/, type => 'hash', descriptor => 1,});
    my $mfe_id = $id;
#    my @mfe_values_check = ('id','genome_id','accession','species','algorithm','start','slipsite','seqlength','sequence','output','parsed','parens','mfe','pairs','knotp','barcode');
    #my $check_boot_stmt = qq/SELECT * FROM boot WHERE mfe_id = '$mfe_id' AND genome_id = '$mfes->{$mfe_id}->{genome_id}' AND accession = '$mfes->{$mfe_id}->{accession}' AND species = '$mfes->{$mfe_id}->{species}' AND mfe_method = '$mfes->{$mfe_id}->{algorithm}' AND seqlength = '$mfes->{$mfe_id}->{seqlength}'/;
    #my $boots = $db->MySelect({statement => $check_boot_stmt,});
    #my $num_boot_ids = scalar(@{$boots});
    #print "MFEID: $mfe_id has $num_boot_ids\n";

    my $pk_output = $mfes->{$mfe_id}->{output};
    if ($pk_output =~ /^\s+/) {
	print "$mfe_id starts with a space.  $mfes->{$mfe_id}->{algorithm} $mfes->{$mfe_id}->{seqlength} $mfes->{$mfe_id}->{mfe} $mfes->{$mfe_id}->{start}\n";
	$pk_output =~ s/^\s+//g;
	$pk_output =~ s/\s+/ /g;
	my $update = qq/UPDATE mfe SET output = '$pk_output' WHERE id = '$mfe_id'/;
	print "Update with $update\n";
	$db->Execute($update);
    }

    my $feynman_pic = new PRFGraph({mfe_id => $mfe_id,
				    accession => $mfes->{$mfe_id}->{accession},
				   });
    my $feynman_output_filename = $feynman_pic->Picture_Filename({type => 'feynman',});
    $feynman_output_filename =~ s/\.png/\.svg/g;
    if (!-r $feynman_output_filename) {
	my $feynman_dimensions = $feynman_pic->Make_Feynman();
    }
#    $feynman_pic->Retarded($feynman_output_filename);
}
