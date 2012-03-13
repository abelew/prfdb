#!/usr/bin/env perl
use strict;
use warnings;
use JSON;
use autodie qw(:all);
use local::lib "$ENV{PRFDB_HOME}/usr/perl";
use Data::Dumper;

my $orf = ($ARGV[0] ? $ARGV[0] : 'all');
my $data;
my $total_reads = { # taken from the quant files above
    mrna_rich => 3541965 + 1451219,
    mrna_star => 857584 + 2375965,
    foot_star => 2040043 + 788626,
    foot_rich => 1698134 + 3151832,
};

if ($orf eq 'all') {
    Gen_All();
} else {
    $orf .= ".json";
    Gen($orf);
}

sub Gen_All {
    opendir(my $js, 'json');
    while (readdir($js)) {
	my $filename = $_;
	next if ($filename =~ /^\./);
	Gen($filename, 'all');
    }
    closedir($js);
}

sub Gen {
    my $filename = shift;
    my $all = shift;
    open(IN, "<json/$filename");
    my $json_text = '';
    while (my $line = <IN>) {
	chomp $line;
	$json_text .= $line;
    }
    close(IN);
    my $datum = decode_json $json_text;
#    foreach my $k (sort keys %{$datum}) {
    my $first_label = $datum->[0]->{label};
    my @foot_rich_list = @{$datum->[0]->{data}};
    my $second_label = $datum->[1]->{label};
    my @foot_star_list = @{$datum->[1]->{data}};
    my $third_label = $datum->[2]->{label};
    my @mrna_rich_list = @{$datum->[2]->{data}};
    my $fourth_label = $datum->[3]->{label};
    my @mrna_star_list = @{$datum->[3]->{data}};
    my $num_mrna_rich = scalar(@mrna_rich_list);
    my $num_mrna_star = scalar(@mrna_star_list);
    my $num_foot_rich = scalar(@foot_rich_list);
    my $num_foot_star = scalar(@foot_star_list);
    my ($cov_foot_rich, $cov_foot_star, $cov_mrna_rich, $cov_mrna_star);
    my $total_foot_rich = 0;
    my $total_mrna_rich = 0;
    my $total_foot_star = 0;
    my $total_mrna_star = 0;
    foreach my $point (@mrna_rich_list) {
	next unless ($point);
	$total_mrna_rich += $point->[1] if ($point->[1]);
    }
    $cov_mrna_rich = sprintf("%.2f", ($total_mrna_rich / $num_mrna_rich));
    foreach my $point (@mrna_star_list) {
	next unless ($point);
	$total_mrna_star += $point->[1] if ($point->[1]);
    }
    $cov_mrna_star = sprintf("%.2f", ($total_mrna_star / $num_mrna_star));
    foreach my $point (@foot_rich_list) {
	next unless ($point);
	$total_foot_rich += $point->[1] if ($point->[1]);
    }
    $cov_foot_rich = sprintf("%.2f", ($total_foot_rich / $num_foot_rich));
    foreach my $point (@foot_star_list) {
	next unless ($point);
	$total_foot_star += $point->[1] if ($point->[1]);
    }
    $cov_foot_star = sprintf("%.2f", ($total_foot_star / $num_foot_star));
    $data->{$filename}->{total_mrna_rich} = $total_mrna_rich;
    $data->{$filename}->{total_mrna_star} = $total_mrna_star;
    $data->{$filename}->{total_foot_rich} = $total_foot_rich;
    $data->{$filename}->{total_foot_star} = $total_foot_star;
    $data->{$filename}->{cov_mrna_rich} = $cov_mrna_rich;
    $data->{$filename}->{cov_mrna_star} = $cov_mrna_star;
    $data->{$filename}->{cov_foot_rich} = $cov_foot_rich;
    $data->{$filename}->{cov_foot_star} = $cov_foot_star;

    if ($all) {
	open(OUT, ">coverage-all.json");
    } else {
	open(OUT, ">coverage-${filename}");
	my $name = $filename;
	$name =~ s/\.json//g;
	my $rpkM_mrna_rich = sprintf("%.2f", ($cov_mrna_rich / (($num_mrna_rich / 1000) * ($total_reads->{mrna_rich} / 1000000))));
	my $rpkM_mrna_star = sprintf("%.2f", ($cov_mrna_star / (($num_mrna_star / 1000) * ($total_reads->{mrna_star} / 1000000))));
	my $rpkM_foot_rich = sprintf("%.2f", ($cov_foot_rich / (($num_foot_rich / 1000) * ($total_reads->{foot_rich} / 1000000))));
	my $rpkM_foot_star = sprintf("%.2f", ($cov_foot_star / (($num_foot_star / 1000) * ($total_reads->{foot_star} / 1000000))));
	print "Name:$name\t
rpkM: mrna_rich: $rpkM_mrna_rich\t mrna_star: $rpkM_mrna_star\t fp_rich: $rpkM_foot_rich\t fp_star: $rpkM_foot_star
coverage: mrna_rich: $cov_mrna_rich\t mrna_star: $cov_mrna_star\t foot_rich: $cov_foot_rich\t foot_star: $cov_foot_star
reads: mrna_rich: $num_mrna_rich\t mrna_star: $num_mrna_star\t foot_rich: $num_foot_rich\t foot_star: $num_foot_star\n";
    }
#1: feature name
#2: normalized read density [rpkM] = $4 / (($5 / 1000) * ($6 / 1000000))
#3: read density [rpk]
#4: read count
#5: feature target length [nt]
#6: total CDS-aligned reads
    my $out_json = encode_json($data);
    print OUT $out_json;
    close OUT;
}
