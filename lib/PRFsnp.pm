package PRFsnp;

use strict;
use DBI;
use IO::File;
use lib "../lib";
use PRFConfig qw / PRF_Error PRF_Out /;
use PRFdb;
use Bio::DB::GenBank;
#use Bio::DB::EUtilities;
use LWP;
use IO::String;

my $config = $PRFConfig::config;
my $db = new PRFdb(config=>$config);
my $gb = new Bio::DB::GenBank;
my $browser = LWP::UserAgent->new();

sub new {
    my ($class, $args) = @_;
    my $me = bless {}, $class;
    foreach my $key (%{$args}) {
	$me->{$key} = $args->{$key};
    }
    if (!defined($me->{species})) {
	die "PRFsnp instantiation failed, please define species argument";
    }
    if (defined($me->{report_filehandle})) {
	# open ($me->{report_filehandle}, ">>prfsnp.out") or die ("Dead! prfsnp.out: $!");
    }
    $me->report("New PRFsnp object instantiated for $me->{species}\n");
    return ($me);
}

sub report {
    my $me = shift;
    my $string = shift;
    # if (defined($me->{report_filehandle})) {
	print ($string);
    # }
}

sub EUtil {
    my $args = shift;
    my $url = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/' . (delete $args->{util}) . '.fcgi?';
    foreach my $key (keys %{$args}) {
	$url .= $key . '=' . $args->{$key} . '&'; 
    }
    # print ("Now Fetching: $url\n"); 
    chop($url);
    my $response = $browser->get($url);
    if (defined($response)) {
	return $response->content();
    }
    sleep(3);
    return undef;
}

sub Get_Set_GI_Numbers {
    my $me = shift;
    my $args = shift;
    my $species = $args->{species};
    my $statement = 'SELECT accession, gi_number FROM genome WHERE species = ? AND gi_number IS NULL';
    my $data = $db->MySelect(statement => $statement, vars => [$me->{species}],);

    my @gi_stream = '';

    foreach my $datum (@{$data}) {
	my $accession = $datum->[0];
	my $gi_number = $datum->[1];
	push(@gi_stream, $accession) if (!defined($gi_number) or $gi_number eq '');
    }

    while ($#gi_stream > 0) {
	my @small_gi_stream = splice(@gi_stream, 0, 500);
	my $seq_stream = $gb->get_Stream_by_id(\@small_gi_stream);
	while (my $seq = $seq_stream->next_seq()) {
	    my $accession = $seq->accession_number;
	    my $gi_number = $seq->primary_id;
	    my $statement = "UPDATE genome SET gi_number = ? WHERE accession = ?";
	    $me->report("Now Executing: $statement\n");
	    $db->MyExecute(statement => $statement, vars => [$gi_number, $accession]);
	}
	sleep(3);
    }
}

sub Fill_Table_snp {
    my $me = shift;
    my $args = shift;
    my $statement = "SELECT gi_number FROM genome WHERE snp_lastupdate = '0000-00-00 00:00:00' AND species = ?";
    my $update = $db->MySelect(statement => $statement, vars => [$me->{species}], type => 'flat',);
    while ($#$update > 0) {
	my @small_update = splice(@{$update}, 0, 49);
	my $string = EUtil({util => 'efetch',
			    db => 'nucleotide',
			    id => join(',', @small_update),
			    extrafeat => 1,
			    rettype => 'genbank',});
	my $stringio = IO::String->new($string);
	my $fetch = Bio::SeqIO->new(-fh => $stringio, -format => 'genbank',);
	while (my $seq = $fetch->next_seq()) {
	    my $acc = $seq->accession_number();
	    my $gid = $seq->primary_id();
	    my @features = $seq->get_SeqFeatures();
	    foreach my $feat (@features) {
		if ($feat->primary_tag eq 'variation') {
		    my $location = '';
		    if ($feat->start == $feat->end) {
			$location = $feat->start;
		    } else {
			$location = $feat->start . '..' . $feat->end;
		    }
		    my $orient = $feat->strand;
		    my $alleles = '';
		    my $cluster_id = '';
		    my $anno_group = $feat->annotation;
		    foreach my $key ($anno_group->get_all_annotation_keys) {
			my @annotations = $anno_group->get_Annotations($key);
			foreach my $annotation (@annotations) {
			    if ($annotation->tagname eq 'replace') {
				my $tmp = $annotation->as_text;
				my ($stuff, $allele) = split(/:\s+/, $tmp);
				if ($allele eq '') {
				    $alleles = '-';
				}
				$alleles .= uc($allele) . '/';
			    }
			    if ($annotation->tagname eq 'db_xref') {
				my $tmp = $annotation->as_text;
				my ($stuff, $value) = split(/:\s+/, $tmp);
				my ($dbid, $cid) = split(/:/, $value);
				$cluster_id = $cid;
			    }
			}
		    }
		    chop($alleles);
		    my $statement = 'INSERT DELAYED IGNORE INTO snp (cluster_id, gene_acc, gene_gi, location, alleles, orientation) VALUES(?,?,?,?,?,?)'; 
		    $me->report("Now Executing: $statement With Vars: $cluster_id, $acc, $gid, $location, $alleles, $orient\n");
		    $db->MyExecute(statement => $statement, vars => [$cluster_id, $acc, $gid, $location, $alleles, $orient]);
		    my $update_stmt = 'UPDATE genome SET snp_lastupdate=CURRENT_TIMESTAMP WHERE accession = ?';
		    $me->report("Now Executing: $update_stmt With Vars: $acc\n");
		    $db->MyExecute(statement => $update_stmt, vars => [$acc]);
		}
	    }
	}
    }
}

sub Create_Table_snp {
    my $me = shift;
    my $statement = qq/CREATE table snp (
					 id $config->{sql_id},
					 gene_acc $config->{sql_accession},
					 gene_gi $config->{gi_number},
					 location varchar(14),
					 alleles varchar(40),
					 orientation tinyint,
					 frameshift varchar(1),
					 mfe_ids text,
					 timestamp $config->{sql_timestamp},
					 INDEX(cluster_id),
					 INDEX(gene_gi),
					 INDEX(gene_acc),
					 PRIMARY KEY (id))/;
    $me->MyExecute(statement => $statement,);
}

sub Compute_Frameshift {
    my $me = shift;
    my $args = shift;
    my $mt = qq"mfe_$species";
    my $statement = 'SELECT id, accession, start, seqlength, parsed FROM $mt WHERE species = ?';
    my $mfe_data = $db->MySelect(statement => $statement, vars => [$me->{species}], type => 'list_of_hashes',);
    foreach my $mfe_row (@{$mfe_data}) {
	my $mfe_id = $mfe_row->{id};
	my $acc = $mfe_row->{accession};
	my $mfe_start = $mfe_row->{start}; ## MFE table is 1-indexed?, while snp is 1-indexed.
	my $mfe_end = $mfe_start + $mfe_row->{seqlength};
	# $me->report("MFE START: $mfe_start MFE END: $mfe_end\n");
	if ($mfe_start eq '' or $mfe_end eq '') {
	    $me->report("THROW MFE: $mfe_id\n");
	}
	my @parsed = split(/\s+/, $mfe_row->{parsed});
	my $conditional = '';
	if (!defined($args->{mode}) or $args->{mode} ne 'replace') {
	    $conditional .= 'AND frameshift IS NULL ';
	}
	$statement = "SELECT id, location, mfe_ids FROM snp WHERE gene_acc = ? $conditional";
	chop($statement); ## trim trailing whitespace
	my $snp_data = $db->MySelect(statement => $statement, type => 'list_of_hashes', vars => [$acc],);
	foreach my $snp_row (@{$snp_data}) {
	    my $snp_id = $snp_row->{id};
	    my $snp_start = $snp_row->{location};
	    my $snp_end = '';
	    if ($snp_start =~ /\.\./) {
		($snp_start, $snp_end) = split(/\.\./, $snp_start);
	    } else {
		$snp_end = $snp_start;
	    }
	    # $me->report("SNP START: $snp_start SNP END: $snp_end\n");
	    if ($snp_start eq '' or $snp_end eq '') {
		$me->report("THROW SNP: $snp_id\n");
	    }
	    my $snp_mfe_ids = '';
	    if (defined($snp_row->{mfe_ids}) and $snp_row->{mfe_ids} ne '') {
		my @snp_mfe_tmp = ($snp_row->{mfe_ids});
		@snp_mfe_tmp = split(/,\s+/, $snp_row->{mfe_ids}) if ($snp_row->{mfe_ids} =~ /,\s+/);
		my $mfe_id_insert = 1;
		foreach my $mid (@snp_mfe_tmp) {
		    $mfe_id_insert = 0 if ($mid eq $mfe_id);
		}
		push(@snp_mfe_tmp, $mfe_id) if ($mfe_id_insert);
		$snp_mfe_ids = join(', ', @snp_mfe_tmp);
	    } else {
		$snp_mfe_ids = $mfe_id;
	    }
	    my $frameshift = 'n';
	    if ($snp_start >= $mfe_start and $snp_start < ($mfe_start + 7)) {
		$frameshift = 's'; 
	    } elsif ($snp_start >= ($mfe_start + 7) and $snp_start <= $mfe_end) {
		$frameshift = 'f';
		my $f = 1000000;
		for (my $i = 0; $i <= ($snp_end - $snp_start); $i++) {
		    my $loc = $snp_start - $mfe_start - 1 + $i;
		    # $me->report("LOCATION: $loc" . join('', @parsed) . "\n");
		    $f = $parsed[$loc] if ($parsed[$loc] ne '.' and $f > $parsed[$loc]);
		}
		$frameshift = $f if ($f < 1000000);
	    }
	    if ($frameshift eq 's' or $frameshift =~ /\d+/ or $frameshift eq 'f') {
		my $statement = 'UPDATE IGNORE $mt SET has_snp = TRUE WHERE id = ?';
		$db->MyExecute(statement => $statement, vars => [$mfe_id],);
	    }
	    $statement = 'UPDATE IGNORE snp SET frameshift = ?, mfe_ids = ? WHERE id = ?';
	    $me->report("Now Executing: $statement With Vars: $frameshift, $snp_mfe_ids, $snp_id\n");
	    $db->MyExecute(statement => $statement, vars => [$frameshift, $snp_mfe_ids, $snp_id],);
	}
    }
}

sub Get_Set_OMIMs {
    my $me = shift;
    my $args = shift;
    my $statement = "SELECT gi_number FROM genome WHERE omim_id IS NULL AND species = ?";
    my $update = $db->MySelect(statement => $statement, vars => [$me->{species}], type => 'flat',);
    while ($#$update > 0) {
	my @small_update = splice(@{$update}, 0, 49);
	my $string = EUtil({util => 'efetch',
			    db => 'nucleotide',
			    id => join(',', @small_update),
			    rettype => 'genbank',});
	my $stringio = IO::String->new($string);
	my $fetch = Bio::SeqIO->new(-fh => $stringio, -format => 'genbank',);
	while (my $seq = $fetch->next_seq()) {
	    my $acc = $seq->accession_number();
	    my $gid = $seq->primary_id();
	    my @features = $seq->get_SeqFeatures();
	    foreach my $feat (@features) {
		if ($feat->primary_tag eq 'gene') {
		    my $omim = '';
		    my $anno_group = $feat->annotation;
		    foreach my $key ($anno_group->get_all_annotation_keys) {
			my @annotations = $anno_group->get_Annotations($key);
			foreach my $annotation (@annotations) {
			    if ($annotation->tagname eq 'db_xref') {
				my $tmp = $annotation->as_text;
				my ($stuff, $value) = split(/:\s+/, $tmp);
				my ($dbid, $cid) = split(/:/, $value);
				if ($dbid eq 'MIM') {
				    $omim = $cid;
				}
			    }
			}
		    }
		    if ($omim ne '') {
			my $update_stmt = 'UPDATE genome SET omim_id = ? WHERE accession = ?';
			$me->report("Now Executing: $update_stmt With Vars: $omim, $acc\n");
			$db->MyExecute(statement => $update_stmt, vars => [$omim, $acc]);
		    }  ## end if the omim is something
		} ## end if the primary tag is seq
	    } ## foreach feature
	} ## while next_seq
    } ## while update > 0
}  ## End Get_Set_OMIMids


1;
