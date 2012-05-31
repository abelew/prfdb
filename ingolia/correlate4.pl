#!/usr/bin/perl
use strict;
use warnings;
use autodie qw":all";
use Bio::SeqIO;
use Data::Dumper;
use Roman;
use JSON;

my @filenames = ('footprints_rich', 'footprints_starved', 'mrna_rich', 'mrna_starved');
my $chromosomes = {};

foreach my $experiment (@filenames) {
    my $new_time = localtime;
    print "$new_time\t$experiment\n";
    Yeast();
    Ingolia($experiment);
}
Make_JSON();

sub Yeast {
    for my $chr (01 .. 16) {
	$chr = sprintf("%02d", $chr);
	my $input = "yeast_chromosomes/chr${chr}.gbf\n";
	my $rom = uc(roman($chr));
	$chr = "chr${rom}";
	$chromosomes->{$chr} = {};
	Gather_Yeast($input, $chr);
    }
}

sub Make_JSON {
    my $in_json = new JSON->allow_nonref;
    foreach my $ch (keys %{$chromosomes}) {
	my %chr = %{$chromosomes->{$ch}};
	foreach my $sta (keys %chr) {
	    my $fp_rich = $chr{$sta}->{footprints_rich};
	    my $fp_starved = $chr{$sta}->{footprints_starved};
	    my $m_rich = $chr{$sta}->{mrna_rich};
	    my $m_starved = $chr{$sta}->{mrna_starved};
	    my $name = $chr{$sta}->{common};
	    my $distance = $chr{$sta}->{end} - $sta;
	    open(JS2, ">json/${name}.json");
	    my @footprints_rich = ();
	    my @footprints_starved = ();
	    my @mrna_rich = ();
	    my @mrna_starved = ();
	    my $finished = 0;
	    my $position = 0;
	    while ($finished == 0) {
		if ($position > $distance) {
		    $finished = 1;
		    last;
		}
		if ($fp_rich->{$position}) {
		    $footprints_rich[$position] = [$position, $fp_rich->{$position}];
		} else {
		    $footprints_rich[$position] = [$position, 0];
		}
		if ($fp_starved->{$position}) {
		    $footprints_starved[$position] = [$position, $fp_starved->{$position}];
		} else {
		    $footprints_starved[$position] = [$position,0];
		}
		if ($m_rich->{$position}) {
		    $mrna_rich[$position] = [$position, $m_rich->{$position}];
		} else {
		    $mrna_rich[$position] = 0;
		}
		if ($m_starved->{$position}) {
		    $mrna_starved[$position] = [$position, $m_starved->{$position}];
		} else {
		    $mrna_starved[$position] = 0;
		}
		$position++;
	    }	    
	    my @hits_json = (
		{label => "footprints_rich", data => \@footprints_rich},
		{label => "footprints_starved", data => \@footprints_starved},
		{label => "mrna_rich", data => \@mrna_rich},
		{label => "mrna_starved", data => \@mrna_starved}
		);
	    my $hits_json_text = to_json(\@hits_json, {utf8 => 1, pretty => 0});
	    print JS2 $hits_json_text;
	    close JS2;
	}
    }
}

sub Gather_Yeast {
    my $input = shift;
    my $chr = shift;
    my $in = new Bio::SeqIO(-file => "<$input");
    while (my $inseq = $in->next_seq) {
	my @cds = grep {$_->primary_tag eq 'CDS'} $inseq->get_SeqFeatures();
	foreach my $feat (@cds) {
	    my $orf_start = $feat->start();
	    my $orf_stop = $feat->end();
	    my $gsf = $feat->{_gsf_tag_hash};
	    # Exposes the following:
	    # translation GO_component GO_function locus_tag gene GO_process note db_xref codon_start product
	    my @xrefs = @{$gsf->{db_xref}};
	    my @commons = $gsf->{locus_tag};
	    my $xref = $xrefs[0];
	    my $common = $commons[0][0];
	    $chromosomes->{$chr}->{$orf_start}->{hits} = {};
	    $chromosomes->{$chr}->{$orf_start}->{end} = $orf_stop;
	    $chromosomes->{$chr}->{$orf_start}->{sgd} = $xref;
	    $chromosomes->{$chr}->{$orf_start}->{common} = $common;
	}
    }  ## End for each sequence in the chromosome
    
    my $chr_json = new JSON->allow_nonref;
    my $chromosomes_text = to_json($chromosomes, {utf8 => 1, pretty => 0});
    open(JS, ">correlate.json");
    print JS $chromosomes_text;
    close(JS);
}

sub Ingolia {
    my $experiment = shift;
    my $input = $experiment . '.txt';
#    my $in_ingolia = "test.txt";
    open(INGOLIA, "<$input");
    while (my $line = <INGOLIA>) {
	next if ($line =~ /^\#/);
	next if ($line =~ /^\s+$/);
	chomp $line;
	my ($tag_seq, $tag_count, $score, $refname, $refstart, $refend, $len, $ambig) = split(/\s+/, $line);
	next if ($refname =~ /Mito/);
	next if ($refname =~ /micron/);
#	print "TESTME $tag_seq $tag_count $score $refname $refstart $refend $len $ambig\n";
#	$refname =~ s_chr//g;
#	print "TESTME: $refname\n";
	my %chr = %{$chromosomes->{$refname}};
	foreach my $seqstart (keys %chr) {
	    if ($seqstart < $refstart) {
		my $seqend = $chr{$seqstart}->{end};
		my $common = $chr{$seqstart}->{common};
		my $sgd = $chr{$seqstart}->{sgd};
		if ($refend < $seqend) {
		    my $offset = $refstart - $seqstart;
		    if ($chromosomes->{$refname}->{$seqstart}->{$experiment}->{$offset}) {
			$chromosomes->{$refname}->{$seqstart}->{$experiment}->{$offset}++;
#			print "Hit at $offset of $common $sgd.  This is $refname $seqstart and starts at $refstart\n";
		    } else {
			$chromosomes->{$refname}->{$seqstart}->{$experiment}->{$offset} = 1;
		    }
		}
#		} else {  ## Otherwise no hit.
#		    
#		}
	    }
	}
    } ## End while
    close(INGOLIA);
}
