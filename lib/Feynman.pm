package Feynman;
use vars qw($VERSION);
my $config;
$VERSION='20111212';

sub new {
    my $class = shift;
    my %arg = @_;
    if ($arg{config}) {
	$config = $arg{config};
    }
    my $me = bless {}, $class;
    foreach my $key (%arg) { $me->{$ke} = $arg{$key} if ($arg{$key}); }
    return ($me);
}

sub deg2rad {PI * $_[0] / 180}




sub CFeynman {
    my $me = shift;
    ## I would like to make a datastructure something like:
    ## $feynman = [
    ##{ base => 'A',          ## The base
    ##  num => 0,             ## It is the first base, I guess not necessary
    ##  previous => [10,10],  ## its position
    ##  current => [8,9],     ## Its position during the last iteration
    ##  bound => 99,          ## What it is bound to...
    ##},
    ## { base => 'G',
    ##   num => 1,
    ##   previous => [11,11],
    ##   current => [10,10],
    ##   bound =>undef,
    ## },
    ## { base => 'U',
    ##   num => 99,
    ##   previous => [12,12],
    ##   current => [11,11],
    ##   bound => 0,
    ##  },
    ## The goal being to have a datastructure which I can use
    ## To draw together the bases on both sides of every stem of a circular feynman.
    ## ];
    ## Thus my first step should be to grab an entry from the database and fill this datastructure up with
    ## the information required to make a simple circular feynman diagram.
    my $id = $me->{mfe_id};
    my $db = new PRFdb(config => $config);
    my $mt = qq"mfe_$me->{species}";
    my $stmt = qq"SELECT sequence, parsed, output FROM $mt WHERE id = ?";
    my $info = $db->MySelect(statement => $stmt, vars => [$id], type => 'row');
    my $sequence = $info->[0];
    my $parsed = $info->[1];
    my $pkout = $info->[2];
    my $seqlength = length($sequence);
    my $character_size = 10;
    my $height_per_nt = 3.5;
    
    my $x_pad = 10;
    my $width = 800;
    my $height = 800;
    
    my $pkt = $pkout;
    my @pktmp = split(/\s+/, $pkt);
    my $max_dist = 0;
    for my $c (0 .. $#pktmp) {
	my $count = $c + 1;
	next if ($pktmp[$c] eq '.');
	my $dist = $pktmp[$c] - $c;
	$max_dist = $dist if ($dist > $max_dist);
	$pktmp[$pktmp[$c]] = '.';
    }
    my $center_x = $width / 2;
    my $center_y = $height / 2;
    
    my $distance_per_char = $character_size - 2;
    my $string_x_distance = $character_size * length($sequence);
    
    my @stems = split(/\s+/, $parsed);
    my @paired = split(/\s+/, $pkout);
    my @seq = split(//, $sequence);
    my $last_stem = $me->Get_Last(\@stems);
    my $bp_per_tsem = $me->Get_Stems(\@stems);
    
    my %return_position = ();
    my $num_characters = scalar(@seq) + 5;
    my $feynman = [];
    for my $c (0 .. $#seq) {
	my $position_info = Char_Position($c, $num_characters, $width, $height);
	my $degrees = $position_info->[2];
	my $rads = $position_info->[3];
	my $position_x = $position_info->[0];
	my $position_y = $position_info->[1];
	$return_position{$c}->{x} = $position_x;
	$return_position{$c}->{y} = $position_y;
	$return_position{$c}->{char} = $seq[$c];
	$return_position{$c}->{stem} = $stems[$c];
	$return_position{$c}->{paired} = $paired[$c];
	my $count = $c+1;
	if ($paired[$c] eq '.') {
	    if ($stems[$c] =~ /\d+/) {
#		$fey->stringRotate(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $colors[$stems[$c]], $degrees);
#		$fey->stringFT($black, gdMediumBoldFont, 4, $degrees, $position_x, $position_y, $seq[$c]);
		$fey->char(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black);
	    } elsif ($stems[$c] eq '.') {
#		$fey->stringRotate(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black, $degrees);
#		$fey->stringFT($black, gdMediumBoldFont, 4, $degrees, $position_x, $position_y, $seq[$c]);
		$fey->char(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black);
	    }
	} elsif ($paired[$c] =~ /\d+/) {
	    my $old_position = Char_Position($paired[$c], $num_characters, $width, $height);
	    my $old_degrees = $old_position->[2];
	    my $old_x = $old_position->[0];
	    my $old_y = $old_position->[1];
	    
	    my $c_x = abs($position_x - $old_x) / 2;
	    my $c_y = abs($position_y - $old_y) / 2;
	    
	    $fey->setThickness(2);
	    $fey->line($old_x+5, $old_y+5, $position_x+5, $position_y+5, $colors[$stems[$c]]);
	    $paired[$paired[$c]] = '.';
#	    $fey->stringRotate(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $colors[$stems[$c]], $degrees);
#	    $fey->stringFT($black, gdMediumBoldFont, 4, $degrees, $position_x, $position_y, $seq[$c]);
	    $fey->char(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black);
	} else { ### Why are there spaces?
#	    $fey->stringRotate(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black, $degrees);
#	    $fey->stringFT($black, gdMediumBoldFont, 4, $degrees, $position_x, $position_y, $seq[$c]);
	    $fey->char(gdMediumBoldFont, $position_x, $position_y, $seq[$c], $black);
	}
    }
    my $output = $me->Picture_Filename(type => 'cfeynman');
    open(OUT, ">$output");
    binmode OUT;
    print OUT $fey->svg;
    close OUT;
    my $command = qq(sed 's/font=\"Helvetica\"/font-family="Courier New"/g' ${output} > ${output}.tmp);
    system($command);
    $command = qq(mv ${output}.tmp ${output});
    system($command);
    
    return(\%return_position);
}


1;
