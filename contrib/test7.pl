#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use lib "$ENV{PRFDB_HOME}/lib";
use local::lib "$ENV{PRFDB_HOME}/usr/perl";
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile Callstack Cleanup";
use SeqMisc;
use Data::Dumper;
my $config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
$db = new PRFdb(config => $config);

my $sequences = $db->MySelect("SELECT mrna_seq, orf_start, orf_stop FROM genome,gene_info WHERE gene_info.species = 'homo_sapiens' AND gene_info.genome_id = genome.id");

my $zero_orf_array = [0,0,0];
my $zero_fp_array = [0,0,0];
my $zero_tp_array = [0,0,0];
my $mone_orf_array = [0,0,0];
my $pone_orf_array = [0,0,0];
my $mone_fp_array = [0,0,0];
my $pone_fp_array = [0,0,0];
my $mone_tp_array = [0,0,0];
my $pone_tp_array = [0,0,0];

foreach my $sequence (@{$sequences}) {
    my ($seq, $start, $stop) = @{$sequence};
    my $len = $stop - ($start - 1);
    my @s = split(//, $seq);
    my @fp = @s;
    my @tp = @s;
    my @orf = @s;
    @orf = splice(@orf, $start - 1, $len);
    my @new_fp = splice(@fp, 0, $start);
    @tp = splice(@tp, $start -1 + $len);
    my $orf_obj_zero = new SeqMisc(sequence => \@orf);
    my $orf_obj_pone = new SeqMisc(sequence => \@orf);
    my $orf_obj_mone = new SeqMisc(sequence => \@orf);
    my $fp_obj_zero = new SeqMisc(sequence => \@fp);
    my $fp_obj_pone = new SeqMisc(sequence => \@fp);
    my $fp_obj_mone = new SeqMisc(sequence => \@fp);
    my $tp_obj_zero = new SeqMisc(sequence => \@tp);
    my $tp_obj_pone = new SeqMisc(sequence => \@tp);
    my $tp_obj_mone = new SeqMisc(sequence => \@tp);

    
    $zero_orf_array = $orf_obj_zero->Codon_Distribution(sequence => $orf_obj_zero->{aaseq}, dist_array => $zero_orf_array);
    $mone_orf_array = $orf_obj_mone->Codon_Distribution(sequence => $orf_obj_mone->{aaminusone}, dist_array => $mone_orf_array);
    $pone_orf_array = $orf_obj_pone->Codon_Distribution(sequence => $orf_obj_pone->{aaplusone}, dist_array => $pone_orf_array);


    $zero_fp_array = $fp_obj_zero->Codon_Distribution(sequence => $fp_obj_zero->{aaseq}, dist_array => $zero_fp_array);
    $mone_fp_array = $fp_obj_mone->Codon_Distribution(sequence => $fp_obj_mone->{aaminusone}, dist_array => $mone_fp_array);
    $pone_fp_array = $fp_obj_pone->Codon_Distribution(sequence => $fp_obj_pone->{aaplusone}, dist_array => $pone_fp_array);


    $zero_tp_array = $tp_obj_zero->Codon_Distribution(sequence => $tp_obj_zero->{aaseq}, dist_array => $zero_tp_array);
    $mone_tp_array = $tp_obj_mone->Codon_Distribution(sequence => $tp_obj_mone->{aaminusone}, dist_array => $mone_tp_array);
    $pone_tp_array = $tp_obj_pone->Codon_Distribution(sequence => $tp_obj_pone->{aaplusone}, dist_array => $pone_tp_array);

}

open(OUT, ">test7.out");
my $d = 0;
print OUT "orf_zero;orf_minus;orf_plus;fp_zero,fp_minus;fp_plus;tp_zero;tp_minus;tp_plus\n";
while ($d < 100000) {
    $zero_orf_array->[$d] = 0 unless(defined($zero_orf_array->[$d]));
    $mone_orf_array->[$d] = 0 unless(defined($mone_orf_array->[$d]));
    $pone_orf_array->[$d] = 0 unless(defined($pone_orf_array->[$d]));
    $zero_fp_array->[$d] = 0 unless(defined($zero_fp_array->[$d]));
    $mone_fp_array->[$d] = 0 unless(defined($mone_fp_array->[$d]));
    $pone_fp_array->[$d] = 0 unless(defined($pone_fp_array->[$d]));
    $zero_tp_array->[$d] = 0 unless(defined($zero_tp_array->[$d]));
    $mone_tp_array->[$d] = 0 unless(defined($mone_tp_array->[$d]));
    $pone_tp_array->[$d] = 0 unless(defined($pone_tp_array->[$d]));
    print OUT "$zero_orf_array->[$d];$mone_orf_array->[$d];$pone_orf_array->[$d];$zero_fp_array->[$d];$mone_fp_array->[$d];$pone_fp_array->[$d];$zero_tp_array->[$d];$mone_tp_array->[$d];$pone_tp_array->[$d]\n";
    $d++;
}
close(OUT);

#my $dumper = new Data::Dumper($dist_array);
#open(OUT, ">dist.txt");
#print OUT $dumper->Dump;
#close(OUT);
