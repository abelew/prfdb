package Landscape;
use strict;
use DBI;
use PRFConfig qw / PRF_Error PRF_Out /;
use PRFdb;
use GD::Graph::mixed;
use GD::SVG;

my $config = $PRFConfig::config;
my $db = new PRFdb;

sub new {
  my ($class, %arg) = @_;
  if (defined($arg{config})) {
    $config = $arg{config};
  }
  my $me = bless {
  }, $class;
  return($me);
}


sub Make_Picture {
  my $me = shift;
  my $accession = shift;
  my $filename = qq($config->{base}/landscapes/$accession.png);
  system("touch $filename");
  my $img = GD::SVG::Image->new();
  my $gene = $db->MySelect("SELECT genename FROM genome WHERE accession='$accession'");
  my $data = $db->MySelect("SELECT start, algorithm, pairs, mfe FROM landscape WHERE accession='$accession' ORDER BY start, algorithm");
  my $slipsites = $db->MySelect("SELECT distinct(start) FROM mfe WHERE accession='$accession' ORDER BY start");
  my $start_stop = $db->MySelect("SELECT orf_start, orf_stop FROM genome WHERE accession = '$accession'");

  my $info = {};
  my @points = ();
  my $avg_counter = 0;
  my $avg_sum = 0;
  foreach my $datum (@{$data}) {
    $avg_counter = $avg_counter + 2;
    my $place = $datum->[0];
    push(@points, $place);
    if ($datum->[1] eq 'pknots') {
      $info->{$place}->{pknots} = $datum->[3];
      $avg_sum = $avg_sum + $datum->[3];
    }
    elsif ($datum->[1] eq 'nupack') {
      $info->{$place}->{nupack} = $datum->[3];
      $avg_sum = $avg_sum + $datum->[3];
    }
  }  ## End foreach spot
  my $average = $avg_sum / $avg_counter;
  my $site_info = {};
  foreach my $site (@{$slipsites}) {
    $site_info->{$site->[0]} = 'slipsite';
  }
  $site_info->{$start_stop->[0]->[0]} = 'start';
  $site_info->{$start_stop->[0]->[1]} = 'stop';
#  print "TESTME START: $start_stop->[0]->[0] STOP: $start_stop->[0]->[1]<br>\n";

  my (@axis_x, @slipsites_y, @nupack_y, @pknots_y, @start_y, @stop_y);
  my $end_spot = $points[$#points] + 105;
  my $current = 0;
  while ($current <= $end_spot) {
    push(@axis_x, $current);
    if (defined($info->{$current})) {
      push(@nupack_y, $info->{$current}->{nupack});
      push(@pknots_y, $info->{$current}->{pknots});
      if (defined($site_info->{$current})) {
	if ($site_info->{$current} eq 'start') {
	  push(@start_y, $average);
	  push(@slipsites_y, undef);
	  push(@stop_y, undef);
	}
	elsif ($site_info->{$current} eq 'stop') {
	  push(@start_y, undef);
	  push(@slipsites_y, undef);
	  push(@stop_y, $average);
	}
	elsif ($site_info->{$current} eq 'slipsite') {
	  push(@start_y, undef);
	  push(@slipsites_y, $average);
	  push(@stop_y, undef);
	}
      }
      else {
	  push(@start_y, undef);
	  push(@slipsites_y, undef);
	  push(@stop_y, undef);
      }
    }


    elsif (defined($site_info->{$current})) {
      if ($site_info->{$current} eq 'start') {
	push(@start_y, $average);
	push(@slipsites_y, undef);
	push(@stop_y, undef);
      }
      elsif ($site_info->{$current} eq 'stop') {
	push(@start_y, undef);
	push(@slipsites_y, undef);
	push(@stop_y, $average);
      }
      elsif ($site_info->{$current} eq 'slipsite') {
	push(@start_y, undef);
	push(@slipsites_y, $average);
	push(@stop_y, undef);
      }
      else {
	push(@start_y, undef);
	push(@slipsites_y, undef);
	push(@stop_y, undef);
      }
    }


    else {
      push(@slipsites_y, undef);
      push(@nupack_y, undef);
      push(@pknots_y, undef);
      push(@start_y, undef);
      push(@stop_y, undef);
    }
    $current++;
  }

  my @mfe_data = (\@axis_x, \@nupack_y, \@pknots_y, \@slipsites_y, \@start_y, \@stop_y);
  my $width = $end_spot;
  my $graph = new GD::Graph::mixed($width, 400);
  $graph->set(
	      x_label => 'Distance on ORF',
	      y_label => 'kcal/mol',
	      y_label_skip => 2,
	      y_number_format => "%.2f",
	      x_labels_vertical => 1,
	      x_label_skip => 100,
	      dclrs => [qw(blue red black green red)],
	      default_type => 'lines',
	      types => [qw(lines lines points points points)],
	      markers => [10],
	      marker_size => 160,
	     ) or die $graph->error;

  my $gd = $graph->plot(\@mfe_data) or die($graph->error);

  open(IMG, ">$filename") or die $!;
  binmode IMG;
  print IMG $gd->png;
  close IMG;
  return($filename);
}

