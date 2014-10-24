package PRFdb::Get;
use strict;
use PRFdb;
our @ISA = qw(PRFdb);
our $AUTOLOAD;

sub GenomeId_From_Accession {
    my $me = shift;
    my $accession = shift;
    my $info = $me->MySelect(statement => qq"SELECT id FROM genome WHERE accession = ?", vars => [$accession], type => 'single');
    return($info);
}

sub GenomeId_From_QueueId {
    my $me = shift;
    my $queue_id = shift;
    my $config = $me->{config};
    my $info = $me->MySelect(statement => qq"SELECT genome_id FROM $config->{queue_table} WHERE id = ?", vars => [$queue_id], type => 'single');
    return ($info);
}



sub All_Sequences {
    my $me = shift;
    my $crap = $me->MySelect("SELECT accession, mrna_seq FROM genome");
    return ($crap);
}

sub Boot {
    my $me = shift;
    my $species = shift;
    my $accession = shift;
    my $start = shift;
    my $config = $me->{config};
    my $table = ($species =~ /virus/ ? "boot_virus" : "boot_$species");
    $config->PRF_Error("Undefined value in Get_Boot", $species, $accession)
	unless (defined($species) and defined($accession));
    my $statement;
    if (defined($start)) {
	$statement = qq(SELECT * FROM $table WHERE accession = ? AND start = ? ORDER BY start);
    } 
    else {
	$statement = qq(SELECT * from $table where accession = ? ORDER BY start);
    }
    my $info = $me->MySelect(statement =>$statement, vars => [$accession, $start], type => 'hash', descriptor => 1);
    return ($info);
}

sub Import_Queue {
    my $me = shift;
#    my $first = $me->MyExecute(statement => "LOCK TABLES import_queue WRITE");
    my $stmt = qq"SELECT id, accession FROM import_queue WHERE checked_out = '0' LIMIT 1";
    my $datum = $me->MySelect(statement => $stmt);
    my $id = $datum->[0]->[0];
    my $accession = $datum->[0]->[1];
    my $stmt2 = qq"UPDATE import_queue SET checked_out = '1' WHERE id = ?";
    $me->MyExecute(statement => $stmt2, vars => [$id]);
#    $me->MyExecute(statement => "UNLOCK TABLES");
    return($accession);
}

sub Queue {
    my $me = shift;
    my $queue_name = shift;
    my $table = 'queue';
    my $config = $me->{config};
    if (defined($queue_name)) {
	$table = $queue_name;
    } elsif (defined($config->{queue_table})) {
	$table = $config->{queue_table};
    }
    unless ($me->Tablep($table)) {
	$me->Create_Queue($table);
	$me->Reset_Queue($table, 'complete');
    }
    ## This id is the same id which uniquely identifies a sequence in the genome database
    my $single_id;
    my $first = $me->MyExecute(statement => "LOCK TABLES $table WRITE");
    if ($config->{randomize_id}) {
	$single_id = qq"SELECT id, genome_id FROM $table WHERE checked_out IS NULL OR checked_out = '0' ORDER BY RAND() LIMIT 1";
    } else {
	print "TESTME: $table\n";
	$single_id = qq"SELECT id, genome_id FROM $table WHERE checked_out = '0' LIMIT 1";
    }
    my $ids = $me->MySelect(statement => $single_id, type => 'row');
    print "TESTME: AFTER IF $ids $ids->[0] genome_id: $ids->[1]\n";
    my $id = $ids->[0];
    my $genome_id = $ids->[1];
    ##if (!defined($id) or $id eq '' or !defined($genome_id) or $genome_id eq '') {
	## This should mean there are no more entries to fold in the queue
	## Lets check this for truth -- first see if any are not done
	## This should come true if the webqueue is empty for example.
	## There is a problem with this, in the case where there is only one left, it
	## will return that single ID over and over again until it finishes.
    ##my $done_id = qq"SELECT id, genome_id FROM $table WHERE done = '0' LIMIT 1";
    ##my $ids = $me->MySelect(statement => $done_id, type =>'row');
    ##$id = $ids->[0];
    ##$genome_id = $ids->[1];
    if (!defined($id) or $id eq '' or !defined($genome_id) or $genome_id eq '') {
	print "TESTME: $id or $genome_id was undefined!\n";
	return(undef);
    }
    ##}
    print "Updating $table setting checked out for $id\n";
    my $update = qq"UPDATE $table SET checked_out='1', checked_out_time=current_timestamp() WHERE id=?";
    $me->MyExecute(statement => $update, vars=> [$id]);
    $me->MyExecute(statement => "UNLOCK TABLES");
    ## Check and make sure the ID still exists (I pruned a bunch out)
    my $exists = $me->MySelect(statement => qq"SELECT count(genome_id) FROM gene_info WHERE genome_id=?", vars => [$genome_id], type => 'single');
    my $ret;
    print "TESTME: $exists select count(genome_id) from gene_info where genome_id = $genome_id\n";
    if ($exists == 0) {
	$me->MyExecute(statement => qq"UPDATE $table SET done='1' WHERE id=?", vars => [$id],);
	my $tries = 0;
	while ($tries < 1000) {
	    $tries++;
	    $ret = $me->Get_Queue();
	}
	$ret = undef;
    } else {
	$ret = {
	    queue_table => $table,
	    queue_id  => $id,
	    genome_id => $genome_id,
	};
    }
    return ($ret);
}

sub Input {
    my $me = shift;
    my $config = $me->{config};
    my $queue_table = $config->{queue_table};
    my $genome_table = $config->{genome_table};
    my $query = qq(SELECT ${queue_table}.id, ${queue_table}.genome_id, ${genome_table}.accession,
		   ${genome_table}.species, ${genome_table}.mrna_seq, ${genome_table}.orf_start,
		   ${genome_table}.direction FROM ${queue_table}, ${genome_table} WHERE ${queue_table}.checked_out = '0'
		   AND ${queue_table}.done = '0' AND ${queue_table}.genome_id = ${genome_table}.id LIMIT 1);
    my $ids = $me->MySelect(statement => $query,type => 'row');
    my $id = $ids->[0];
    my $genome_id = $ids->[1];
    my $accession = $ids->[2];
    my $species = $ids->[3];
    my $mrna_seq = $ids->[4];
    my $orf_start = $ids->[5];
    my $direction = $ids->[6];
    if (!defined($id) or $id eq '' or !defined($genome_id) or $genome_id eq '') {
	return (undef);
    }
    my $update = qq(UPDATE $queue_table SET checked_out='1', checked_out_time=current_timestamp() WHERE id=?);
    $me->MyExecute(statement => $update,  vars => [$id],);
    my $return = {
	queue_id => $id,
	genome_id => $genome_id,
	accession => $accession,
	species => $species,
	mrna_seq => $mrna_seq,
	orf_start => $orf_start,
	direction => $direction,
    };
    return ($return);
}



sub Entire_Queue {
    my $me = shift;
    my $table = 'queue';
    my $config = $me->{config};
    if (defined($config->{queue_table})) {
	$table = $config->{queue_table};
    }
    my $return;
    my $statement = qq(SELECT id FROM $table WHERE checked_out='0');
    my $ids = $me->MySelect(statement =>$statement);
    return ($ids);
}

sub MFE {
    my $me = shift;
    my $identifier = shift; ## { genome_id => #, species => #, accession => #, start => # }
    my $statement = '';
    my $info;
    if (defined($identifier->{genome_id})) {
	$statement = qq(SELECT id, genome_id, species, accession, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode FROM mfe where genome_id = ?);
	$info = $me->MySelect(statement =>$statement, vars => [$identifier->{genome_id}], type => 'hash',
			       descriptor => [qq(id genome_id species accession start slipsite seqlength sequence output parsed parens mfe pairs knotp barcode)],);
    } 
    elsif (defined($identifier->{accession} and defined($identifier->{start}))) {
	$statement = qq(SELECT id, genome_id, species, accession, start, slipsite, seqlength, sequence, output, parsed, parens, mfe, pairs, knotp, barcode FROM mfe where accession = ? and start = ?);
	$info = $me->MySelect(statement => $statement, vars => [$identifier->{accession}, $identifier->{start}], type => 'hash',
			       descriptor => [qq(id genome_id species accession start slipsite seqlength sequence output parsed parens mfe pairs knotp barcode)],);
    }
    return ($info);
}


sub Slippery_From_Sequence {
    my $me = shift;
    my $sequence = shift;
    my $start = shift;
    my @reg = split(//, $sequence);
    my $slippery = "$reg[$start]" . "$reg[$start+1]" . "$reg[$start+2]" . "$reg[$start+3]" . "$reg[$start+4]" . "$reg[$start+5]" . "$reg[$start+6]";
    return ($slippery);
}


sub OMIM {
    my $me = shift;
    my $id = shift;
    my $statement = qq(SELECT omim_id FROM genome WHERE id = ?);
    my $omim = $me->MySelect(statement => $statement, vars => [$id], type => 'single');
    if (!defined($omim) or $omim eq 'none') {
	return (undef);
    }
    elsif ($omim =~ /\d+/) {
	return ($omim);
    }
    else {
	my $uni = new Bio::DB::Universal;
	my $seq = $uni->get_Seq_by_id($id);
	my @cds = grep {$_->primary_tag eq 'CDS'} $seq->get_SeqFeatures();
	my $omim_id = '';
	foreach my $feature (@cds) {
	    my $db_xref_list = $feature->{_gsf_tag_hash}->{db_xref};
	    foreach my $db (@{$db_xref_list}) {
		if ($db =~ /^MIM\:/) {
		    $db =~ s/^MIM\://g;
		    $omim_id .= "$db ";
		}    ## Is it in omim?
	    }    ## Possible databases
	}    ## CDS features
	$statement = qq"UPDATE genome SET omim_id = ? WHERE id = ?";
	$me->MyExecute(statement => $statement, vars => [ $omim_id, $id ],);
	return ($omim_id);
    }
}

sub Sequence {
    my $me = shift;
    my $accession = shift;
    my $statement = qq"SELECT mrna_seq FROM genome WHERE accession = ?";
    my $sequence  = $me->MySelect(statement => $statement, vars => [$accession], type => 'single');
    if ($sequence) {
	return ($sequence);
    }
    else {
	return (undef);
    }
}

sub Sequence_from_id {
    my $me = shift;
    my $id = shift;
    my $statement = qq"SELECT mrna_seq FROM genome WHERE id = ?";
    my $sequence = $me->MySelect(statement => $statement, vars => [$id], type => 'single');
    if ($sequence) {
	return ($sequence);
    }
    else {
	return (undef);
    }
}

sub Sequence_From_Fasta {
    my $filename = shift;
    my $return = '';
    open(IN, "<$filename") or print "Could not open $filename in Get_Sequence_From_Fasta $!\n";
    while (my $line = <IN>) {
	next if ($line =~ /^\>/);
	$return .= $line;
    }
    close(IN);
    return ($return);
}

sub MFE_ID {
    my $me = shift;
    my $genome_id = shift;
    my $start = shift;
    my $seqlength = shift;
    my $mfe_method = shift;
    my $species = $me->MySelect(statement => "SELECT species FROM gene_info WHERE genome_id = ?", type => 'single', vars => [$genome_id]);
    my $mfe_table = "mfe_$species";
    $mfe_table = 'mfe_virus' if ($mfe_table =~ /virus/);
    my $statement = qq"SELECT id FROM $mfe_table WHERE genome_id = ? AND start = ? AND seqlength = ? AND mfe_method = ? LIMIT 1";
    my $mfe = $me->MySelect(statement =>$statement, vars => [$genome_id, $start, $seqlength, $mfe_method], type => 'single');
    return ($mfe);
}

sub Num_RNAfolds {
    my $me = shift;
    my $mfe_method = shift;
    my $genome_id = shift;
    my $slipsite_start = shift;
    my $seqlength = shift;
    my $table = shift;
    my $species = $me->MySelect(statement => "SELECT species FROM gene_info WHERE genome_id = ?", type => 'single', vars => [$genome_id]);
    my $mfe_table = "mfe_$species";
    $table = $mfe_table unless (defined($table));
    if ($table =~ /virus/) {
	if ($table =~ /boot/) {
	    $table = "boot_virus";
	} elsif ($table =~ /landscape/) {
	    $table = "landscape_virus";
	} else {
	    $table = "mfe_virus";
	}
    }
    my $return = {};
#    my $statement = qq"SELECT count(id) FROM $table WHERE genome_id = ? AND mfe_method = ? AND start = ? AND seqlength = ?";
    my $statement = qq"SELECT count(id) FROM $table WHERE genome_id = '$genome_id' AND mfe_method = '$mfe_method' AND start = '$slipsite_start' AND seqlength = '$seqlength'";
#    my $count = $me->MySelect(statement =>$statement, vars => [$genome_id, $mfe_method, $slipsite_start, $seqlength], type => 'single');
    my $count = $me->MySelect(statement =>$statement, type => 'single');
#    print "TESTME: $statement\n$count\n";
    if (!defined($count) or $count eq '') {
	$count = 0;
    }
    return ($count);
}

sub Num_Bootfolds {
    my $me = shift;
    my %args = @_;
    my $species = $args{species};
    my $genome_id = $args{genome_id};
    my $start = $args{start};
    my $seqlength = $args{seqlength};
    my $mfe_method = $args{mfe_method};
    my $table = ($species =~ /virus/ ? "boot_virus" : "boot_$species");
    my $return = {};
    my $statement = qq/SELECT count(id) FROM $table WHERE genome_id = ? and start = ? and seqlength = ? and mfe_method = ?/;
    print "Testing Boot num: $statement
genome_id: $genome_id    start: $start   seqlength: $seqlength  mfe: $mfe_method\n";
    my $count = $me->MySelect(statement => $statement, vars => [$genome_id, $start, $seqlength, $mfe_method], type =>'single');
    return ($count);
}

sub mRNA {
    my $me = shift;
    my $accession = shift;
    my $statement = qq"SELECT mrna_seq FROM genome WHERE accession = ?";
    my $info = $me->MySelect(statement => $statement, vars => [$accession], type => 'hash');
    my $mrna_seq  = $info->{mrna_seq};
    if ($mrna_seq) {
	return ($mrna_seq);
    }
    else {
	return (undef);
    }
}

sub ORF {
    my $me = shift;
    my $accession = shift;
    my $statement = qq"SELECT id, orf_start, orf_stop, mrna_seq FROM genome WHERE accession = ?";
    my $info = $me->MySelect(statement => $statement, vars => [$accession], type => 'hash');
    my $mrna_seq = $info->{mrna_seq};
    ### A PIECE OF CODE TO HANDLE PULLING SUBSEQUENCES FROM CDS
    my $start = $info->{orf_start} - 1;
    my $stop = $info->{orf_stop} - 1;
    my $offset = $stop - $start;
    my $sequence = substr($mrna_seq, $start, $offset);
    ## If I remove the substring, Then it should return from the start
    ## codon to the end of the mRNA which is good                                  
    ## For searching over viral sequence!
    ### DONT SCAN THE ENTIRE MRNA, ONLY THE ORF
    if ($sequence) {
	my $return = {sequence  => "$sequence",
		      orf_start => $start,
		      orf_stop  => $stop,};
	return ($return);
    }
    else {
	return (undef);
    }
}

sub Slippery_From_RNAMotif {
    my $me = shift;
    my $filename = shift;
    open(IN, "<$filename");
    ## OPEN IN in Get_Slippery_From_RNAMotif
    while (my $line = <IN>) {
	chomp $line;
	if ($line =~ /^\>/) {
	    my ($slippery, $crap) = split(/ /, $line);
	    $slippery =~ s/\>//g;
	    return ($slippery);
	}
    }
    close(IN);
    ## CLOSE IN in Get_Slippery_From_RNAMotif
    return (undef);
}




sub AUTOLOAD {
    my $me = shift;
    my $name = $AUTOLOAD;
    print "Unable to find the function: $name in PRFdb::Get\n";
    $name =~ s/.*://;   # strip fully-qualified portion
    if (@_) {
	return $me->{$name} = shift;
    } else {
	return $me->{$name};
    }
}

1;
