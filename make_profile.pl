#!/usr/local/bin/perl -w
use strict;
use POSIX;
use DBI;
use Time::HiRes;

use lib "$ENV{HOME}/usr/lib/perl5";
use lib 'lib';
use PRFConfig;
use PRFdb;
use GD::Graph::mixed;
use GD::SVG;
my $img = GD::SVG::Image->new();

my $config = $PRFConfig::config;
my $db     = new PRFdb;
chdir( $config->{basedir} );
if ( defined( $ARGV[0] ) ) {
  if ( $ARGV[0] eq '-q' ) {
    my $finished_accessions = $db->MySelect("SELECT distinct(accession) FROM landscape");
    foreach my $acc ( @{$finished_accessions} ) {
      print "$acc->[0]\n";
    }
  } else {
    my $accession = $ARGV[0];
    my $gene      = $db->MySelect("SELECT genename FROM genome WHERE accession='$accession'");
    print "$gene->[0]->[0]\n";
    my $data = $db->MySelect("SELECT start, algorithm, pairs, mfe FROM landscape WHERE accession='$accession' ORDER BY start, algorithm");

    #    my $slipsites = $db->MySelect("SELECT distinct(start) FROM mfe WHERE accession='$accession' AND knotp='1'");
    my $slipsites = $db->MySelect("SELECT distinct(start) FROM mfe WHERE accession='$accession' ORDER BY start");

    my $info        = {};
    my @points      = ();
    my $avg_counter = 0;
    my $avg_sum     = 0;
    foreach my $datum ( @{$data} ) {
      $avg_counter = $avg_counter + 2;
      my $place = $datum->[0];
      push( @points, $place );
      if ( $datum->[1] eq 'pknots' ) {
        $info->{$place}->{pknots} = $datum->[3];
        $avg_sum = $avg_sum + $datum->[3];
      } elsif ( $datum->[1] eq 'nupack' ) {
        $info->{$place}->{nupack} = $datum->[3];
        $avg_sum = $avg_sum + $datum->[3];
      }
    }
    my $average   = $avg_sum / $avg_counter;
    my $site_info = {};
    foreach my $site ( @{$slipsites} ) {
      $site_info->{ $site->[0] } = 'slipsite';
    }

    my ( @axis_x, @slipsites_y, @nupack_y, @pknots_y );
    my $end_spot = $points[$#points] + 105;
    my $current  = 0;
    while ( $current <= $end_spot ) {
      push( @axis_x, $current );
      if ( defined( $info->{$current} ) ) {
        push( @nupack_y, $info->{$current}->{nupack} );
        push( @pknots_y, $info->{$current}->{pknots} );
        if ( defined( $site_info->{$current} ) ) {
          push( @slipsites_y, $average );
        } else {
          push( @slipsites_y, undef );
        }
      }

      elsif ( defined( $site_info->{$current} ) ) {
        push( @slipsites_y, $average );
        push( @nupack_y,    undef );
        push( @pknots_y,    undef );
      }

      else {
        push( @slipsites_y, undef );
        push( @nupack_y,    undef );
        push( @pknots_y,    undef );
      }
      $current++;
    }

    my @mfe_data = ( \@axis_x, \@nupack_y, \@pknots_y, \@slipsites_y );
    my $width    = $end_spot;
    my $graph    = new GD::Graph::mixed( $width, 400 );
    $graph->set(
      x_label           => 'Distance on ORF',
      y_label           => 'kcal/mol',
      y_label_skip      => 2,
      y_number_format   => "%.2f",
      x_labels_vertical => 1,
      x_label_skip      => 100,
      dclrs             => [qw(blue red black)],
      default_type      => 'lines',
      types             => [qw(lines lines points)],
      markers           => [10],
      marker_size       => 160,
    ) or die $graph->error;

    my $gd = $graph->plot( \@mfe_data ) or die( $graph->error );

    open( IMG, ">$accession.png" ) or die $!;
    binmode IMG;
    print IMG $gd->png;
    close IMG;
  }
} else {
  die("This requires an accession.");
}
