#! /usr/bin/perl -w

use strict;
use lib '../lib';
use PRFConfig;
use PRFdb;
use Bio::DB::GenBank;

my $config = PRFConfig::config;

my $PRFdb = new PRFdb;

my $GBdb = new Bio::DB::GenBank(
  -format     => 'native',
  -complexity => 0,
);

$PRFdb->Create_Variations() unless ($PRFdb->Tablep('variations'));

my $statement = qq(SELECT accession FROM genome WHERE species = homo_sapiens );
$statement .= qq(AND WHERE accession NOT IN ( SELECT accession FROM variations));

my $accs = $PRFdb->MySelect( $statement, 'row' );

foreach my $acc ( @{$accs} ) {
  my $seq = $GBdb->get_Seq_by_acc($acc);
  foreach my $feature ( $seq->get_SeqFeatures ) {
    if ( $feature->primary_tag eq 'variation' ) {

      my $mfe_ref = $PRFdb->MySelect( 'SELECT start, slipsite, seqlength, sequence, parsed, mfe, knotp FROM mfe WHERE accession = ?', [$acc] );

      my $knotp = $mfe_ref->{knotp};
      next if ( $knotp != 1 );    ## Not pseudoknotted!?  WHO CARES!?
      my $fstart = $mfe_ref->{start} + 1;    ## Get the start site from mfe
      next if ( !defined($fstart) );         ## If there's no frameshift, why do we care??
      my $fseqlength = $mfe_ref->{seqlength};
      next if ( $fseqlength == 0 );          ## Nobody cares about sequences of length 0
      my $fstop    = ( $fstart + $fseqlength + 7 );    ## Compute the stop site
      my $slipsite = uc( $mfe_ref->{slipsite} );
      $slipsite =~ tr/U/T/;                            ## Get the slipsite from mfe, working w/ DNA
      my $pseq = uc( $mfe_ref->{sequence} );
      $pseq =~ tr/U/T/;                                ## Get the sequence from mfe, working w/ DNA
      my @mfe_parsed = split( /\s+/, $mfe_ref->{parsed} );

      ## Variation Location ~ does dance ~
      my $location    = $feature->{_location};
      my $vstart      = $location->start();
      my $vstop       = $location->end();
      my @complement_test  = split( /\(/, $location->to_FTstring() );
      my $vcomplement = 0;
      if ( $complement_test[0] eq 'complement' ) {
        $vcomplement = 1;
      }

      my $gth = $feature->{_gsf_tag_hash};
      
      my $vnote;
      if ( defined( $gth->{note} ) ) {
        my $notes = $gth->{note};
        foreach my $note ( @{$notes} ) {
          $vnote .= $note;
        }
      }
      
      my $vars;
      if ( defined( $gth->{replace} ) ) {
        my $snps = $gth->{replace};
        foreach my $snp ( @{$snps} ) {
          $vars .= uc($snp);    ## Uppercase is pretty
        }
      } elsif ( defined( $gth->{allele} ) ) {
        my $snps = $gth->{allele};
        foreach my $snp ( @{$snps} ) {
          $vars .= uc($snp);    ## Uppercase is still pretty
        }
      }
      
      my ($db, $dbacc);
      ## Pluck dbSNP accessions
      my $db_xrefs = $gth->{db_xref};
      foreach my $ref ( @{$db_xrefs} ) {
        ( $db, $dbacc ) = split( /:/, $ref );
      }

      ## Compute location of SNP in frameshift
      my $frameshift;
      if ( $vstart >= $fstart && $vstart <= $fstop ) {

        ## Location of SNP in mfe_parsed
        my $locus    = ( $vstart - $fstart - 7 );
        my $v_parsed = $mfe_parsed[$locus];
        if ( !defined($v_parsed) ) {
          # print( ERROUT "$acc: v_parsed " . scalar(@mfe_parsed) . " $locus UNDEF!\n" );
          next;
        }

        if ( $vstart <= ( $fstart + 7 ) ) {
          $frameshift = 's';
        }    ## In a slippery site
        elsif ( $v_parsed ne '.' ) {
          $frameshift = $v_parsed;
        }    ## In a numbered stem
        else {
          $frameshift = 'f';
        }    ## Just in the frameshift
      } else {
        $frameshift = 'n';
      }    ## Not in the frameshift

      my $var_insert_statement = qq{INSERT DELAYED IGNORE INTO variations (dbSNP, accession, start, stop, complement, vars, frameshift, note) values ($dbacc, '$acc', $vstart, $vstop, $vcomplement, '$vars', '$frameshift', '$vnote')};
      $PRFdb->Execute($var_insert_statement);
    }
  }
}    
