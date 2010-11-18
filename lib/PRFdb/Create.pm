package PRFdb::Create;
use strict;
use PRFdb;
our @ISA = qw(PRFdb);
our $AUTOLOAD;

#### Create all the tables of the PRFdb here
sub Agree {
    my $me = shift;
    my $config = $me->{config};
    my $statement = qq"CREATE table agree (
id $config->{sql_id},
accession $config->{sql_accession},
start int,
length int,
all_agree int,
no_agree int,
n_alone int,
h_alone int,
p_alone int,
hplusn int,
nplusp int,
hplusp int,
hnp int,
PRIMARY KEY (id))";
    $me->MyExecute(statement =>$statement,);
}

sub Boot {
    my $me = shift;
    my $config = $me->{config};
    my $table = shift;
    $table = 'boot_virus' if ($table =~ /virus/);
    my $statement = qq\CREATE TABLE $table (
id $config->{sql_id},
genome_id int,
mfe_id int,
species $config->{sql_species},
accession $config->{sql_accession},
start int,
seqlength int,
iterations int,
rand_method varchar(20),
mfe_method varchar(20),
mfe_mean float,
mfe_sd float,
mfe_se float,
pairs_mean float,
pairs_sd float,
pairs_se float,
mfe_values text,
zscore float,
lastupdate $config->{sql_timestamp},
INDEX(genome_id),
INDEX(mfe_id),
INDEX(accession),
PRIMARY KEY(id))\;
    $me->MyExecute(statement => $statement,);
    print "Created $table\n" if (defined($config->{debug}));
}

sub Errors {
    my $me = shift;
    my $config = $me->{config};
    my $statement = qq\CREATE table errors (
					    id $config->{sql_id},
					    time $config->{sql_timestamp},
					    message blob,
					    accession $config->{sql_accession},
					    PRIMARY KEY(id))\;
    $me->MyExecute(statement => $statement,);
}

sub Evaluate {
    my $me = shift;
    my $config = $me->{config};
    my $statement = qq(CREATE table evaluate (
id $config->{sql_id},
species $config->{sql_species},
accession $config->{sql_accession},
start int,
length int,
pseudoknot bool,
min_mfe float,
PRIMARY KEY (id)));
    $me->MyExecute(statement => $statement,)
}

sub Gene_Info {
   my $me = shift;
   my $config = $me->{config};
   my $statement = qq/CREATE table gene_info (
genome_id bigint,
accession $config->{sql_accession},
species $config->{sql_species},
genename $config->{sql_genename},
comment $config->{sql_comment},
defline text not null,
INDEX(accession),
FULLTEXT(comment),
FULLTEXT(defline),
FULLTEXT(genename),
PRIMARY KEY (genome_id))/;
   $me->MyExecute(statement =>$statement,);
   my $insert_stmt = qq"INSERT IGNORE INTO gene_info (genome_id, accession, species, genename, comment, defline) SELECT id, accession, species, genename, comment, defline FROM genome";
   $me->MyExecute(statement => $insert_stmt,);
}

sub Genome {
    my $me = shift;
    my $config = $me->{config};
    my $statement = qq/CREATE table genome (
id $config->{sql_id},
accession $config->{sql_accession},
gi_number $config->{sql_gi_number},
genename $config->{sql_genename},
locus text,
ontology_function text,
ontology_component text,
ontology_process text,
version int,
comment $config->{sql_comment},
defline blob not null,
mrna_seq longblob not null,
protein_seq text,
orf_start int,
orf_stop int,
direction char(7) DEFAULT 'forward',
omim_id varchar(30),
found_snp bool,
average_mfe text,
snp_lastupdate TIMESTAMP DEFAULT '00:00:00',
lastupdate $config->{sql_timestamp},
INDEX(genename),
PRIMARY KEY (id))/;
    $me->MyExecute(statement =>$statement,);
}

sub Import_Queue {
    my $me = shift;
    my $config = $me->{config};
    my $table = 'import_queue';
    my $stmt = qq"CREATE TABLE $table (
id $config->{sql_id},
accession $config->{sql_accession},
PRIMARY KEY (id))";
    $me->MyExecute(statement =>$stmt,);
}

sub Index_Stats {
    my $me = shift;
    my $config = $me->{config};
    my $statement = qq/CREATE table index_stats (
id $config->{sql_id},
species $config->{sql_species},
num_genome int,
num_mfe_entries int,
num_mfe_knotted int,
PRIMARY KEY (id))/;
    $me->MyExecute(statement =>$statement,);
}

sub NumSlipsite {
    my $me = shift;
    my $config = $me->{config};
    my $statement = qq/CREATE table numslipsite (
id $config->{sql_id},
accession $config->{sql_accession},
num_slipsite int,
lastupdate $config->{sql_timestamp},
PRIMARY KEY (id))/;
    $me->MyExecute(statement => $statement,);
}

sub Species_Summary {
    my $me = shift;
    my $config = $me->{config};
    my $statement = qq"CREATE table species_summary (
id $config->{sql_id},
species $config->{sql_species},
genes int,
nupack_folds int,
pknots_folds int,
hotknots_folds int,
nupack_pseudo int,
pknots_pseudo int,
hotknots_pseudo int,
nupack_sig int,
pknots_sig int,
hotknots_sig int,
PRIMARY KEY (id))";
    $me->MyExecute(statement => $statement,);
}

sub Overlap {
    my $me = shift;
    my $config = $me->{config};
    my $statement = qq(CREATE table overlap (
id $config->{sql_id},
genome_id int,
species $config->{sql_species},
accession $config->{sql_accession},
start int,
plus_length int,
plus_orf text,
minus_length int,
minus_orf text,
lastupdate $config->{sql_timestamp},
PRIMARY KEY (id)));
    $me->MyExecute(statement => $statement,);
}

sub Landscape {
    my $me = shift;
    my $table = shift;
    my $config = $me->{config};
    $table = 'landscape_virus' if ($table =~ /virus/);
    my $statement = qq\CREATE TABLE $table (
id $config->{sql_id},
genome_id int,
species $config->{sql_species},
accession $config->{sql_accession},
algorithm char(10),
start int,
seqlength int,
sequence text,
output text,
parsed text,
parens text,
mfe float,
pairs int,
knotp bool,
barcode text,
lastupdate $config->{sql_timestamp},
INDEX(genome_id),
INDEX(accession),
PRIMARY KEY(id))\;
    $me->MyExecute(statement =>$statement,);
    print "Created $table\n" if (defined($config->{debug}));
}

sub MFE {
    my $me = shift;
    my $table = shift;
    my $config = $me->{config};
    $table = 'mfe_virus' if ($table =~ /virus/);
    my $statement = qq\CREATE TABLE $table (
id $config->{sql_id},
genome_id int,
accession $config->{sql_accession},
algorithm char(20),
start int,
slipsite char(7),
seqlength int,
sequence text,
output text,
parsed text,
parens text,
mfe float,
pairs int,
knotp bool,
barcode text,
compare_mfes varchar(30),
has_snp bool DEFAULT FALSE,
bp_mstop int,
lastupdate $config->{sql_timestamp},
INDEX(genome_id),
INDEX(accession),
PRIMARY KEY(id))\;
    $me->MyExecute(statement => $statement,);
}

sub MFE_Utr {
    my $me = shift;
    my $config = $me->{config};
    my $statement = qq\CREATE TABLE mfe_utr (
id $config->{sql_id},
genome_id int,
species $config->{sql_species},
accession $config->{sql_accession},
algorithm char(10),
start int,
slipsite char(7),
seqlength int,
sequence text,
output text,
parsed text,
parens text,
mfe float,
pairs int,
knotp bool,
barcode text,
lastupdate $config->{sql_timestamp},
INDEX(genome_id),
INDEX(accession),
PRIMARY KEY(id))\;
    $me->MyExecute(statement => $statement,);
}

sub Nosy {
    my $me = shift;
    my $config = $me->{config};
    my $statement = qq\CREATE TABLE nosy (
ip char(15),
visited $config->{sql_timestamp},
PRIMARY KEY(ip))\;
    $me->MyExecute(statement =>$statement,);
    print "Created nosy\n" if (defined($config->{debug}));
}

sub Queue {
    my $me = shift;
    my $table = shift;
    my $config = $me->{config};
    if (!defined($table)) {
	if (defined( $config->{queue_table})) {
	    $table = $config->{queue_table};
	}
	else {
	    $table = 'queue';
	}
    }
    my $statement = qq\CREATE TABLE $table (
id $config->{sql_id},
genome_id int,
checked_out bool,
checked_out_time timestamp default 0,
done bool,
done_time timestamp default 0,
PRIMARY KEY (id))\;
    $me->MyExecute(statement =>$statement,);
}

sub Stats {
    my $me = shift;
    my $config = $me->{config};
    my $statement = qq(CREATE table stats (
id $config->{sql_id},
species $config->{sql_species},
seqlength int,
max_mfe float,
algorithm varchar(10),
num_sequences int,
avg_mfe float,
stddev_mfe float,
avg_pairs float,
stddev_pairs float,
num_sequences_noknot int,
avg_mfe_noknot float,
stddev_mfe_noknot float,
avg_pairs_noknot float,
stddev_pairs_noknot float,
num_sequences_knotted int,
avg_mfe_knotted float,
stddev_mfe_knotted float,
avg_pairs_knotted float,
stddev_pairs_knotted float,
avg_zscore float,
stddev_zscore float,
PRIMARY KEY (id)));
    $me->MyExecute(statement => $statement,);
}

sub Variations {
    my $me = shift;
    my $config = $me->{config};
    my $statement = qq\CREATE TABLE variations (
id $config->{sql_id},
dbSNP text,
accession $config->{sql_accession},
start int,
stop int,
complement int,
vars text,
frameshift char(1),
note text,
INDEX(dbSNP),
INDEX(accession),
PRIMARY KEY(id))\;
    $me->MyExecute(statement => $statement,);
}

sub Wait {
    my $me = shift;
    my $config = $me->{config};
    my $stmt = qq"CREATE table wait (wait int, primary key(wait))";
    $me->MyExecute(statement => $stmt);
}

sub Tables {
    my $me = shift;
    my $config = $me->{config};
    $me->Create_Agree();
    $me->Create_Boot("boot_saccharomyces_cerevisiae");
    $me->Create_Errors();
    $me->Create_Evaluate();
    $me->Create_Gene_Info();
    $me->Create_Genome();
    $me->Create_Import_Queue(); 
    $me->Create_Index_Stats();
    $me->Create_Landscape("landscape_saccharomyces_cerevisiae");
    $me->Create_MFE("mfe_saccharomyces_cerevisiae");
    $me->Create_MFE_Utr();
    $me->Create_Nosy();
    $me->Create_NumSlipsite();
    $me->Create_Overlap();
    $me->Create_Queue();
    $me->Create_Stats();
    $me->Create_Variations();
    $me->Create_Wait();
}

sub AUTOLOAD {
    my $me = shift;
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion
    if (@_) {
	return $me->{$name} = shift;
    } else {
	return $me->{$name};
    }
}

1;
