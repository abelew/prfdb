package PRFdb::Create;
use strict;
our @ISA = qw(PRFdb);
our $AUTOLOAD;


#### Create all the tables of the PRFdb here
sub Do {
    my $me = shift;
    my $table = shift;
    my $stmt = shift;
    return(undef) if ($me->Tablep($table));
    my $ret = $me->MyExecute(statement => $stmt);
    print "Created $table\n" if (defined($me->{config}->{debug}));
    return($ret);
}

sub Agree {
    my $me = shift;
    my $table = "agree";
    my $statement = qq"CREATE table $table (
id $me->{config}->{sql_id},
accession $me->{config}->{sql_accession},
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
    return($me->Create_Do($table, $statement));
}

sub Boot {
    my $me = shift;
    my $table = shift;
    $table = 'boot_virus' if ($table =~ /virus/);
    my $statement = qq"CREATE TABLE $table (
id $me->{config}->{sql_id},
genome_id int,
mfe_id int,
species $me->{config}->{sql_species},
accession $me->{config}->{sql_accession},
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
lastupdate $me->{config}->{sql_timestamp},
INDEX(genome_id),
INDEX(mfe_id),
INDEX(accession),
PRIMARY KEY(id))";
    return($me->Create_Do($table, $statement));
}

sub Errors {
    my $me = shift;
    my $table = "errors";
    my $statement = qq"CREATE table errors (
					    id $me->{config}->{sql_id},
					    time $me->{config}->{sql_timestamp},
					    message blob,
					    accession $me->{config}->{sql_accession},
					    PRIMARY KEY(id))";
    return($me->Create_Do($table, $statement));
}

sub Evaluate {
    my $me = shift;
    my $table = "evaluate";
    my $statement = qq"CREATE table evaluate (
id $me->{config}->{sql_id},
species $me->{config}->{sql_species},
accession $me->{config}->{sql_accession},
start int,
length int,
pseudoknot bool,
min_mfe float,
PRIMARY KEY (id))";
    return($me->Create_Do($table, $statement));
}

sub Gene_Info {
   my $me = shift;
   my $table = "gene_info";
   my $statement = qq"CREATE table $table (
genome_id bigint,
accession $me->{config}->{sql_accession},
species $me->{config}->{sql_species},
genename $me->{config}->{sql_genename},
comment $me->{config}->{sql_comment},
defline text not null,
publications text,  /* a list of pubmed IDs */
db_xrefs text, /* a list of pubmed/etc cross references */
hgnc_id text, /* The canonical gene name's id at genenames.org */
hgnc_name text, /* The canonical gene name at genenames.org */
gene_synonyms text, /* a list of the gene names for this */
refseq_comment text, /* the COMMENT field from refseq */
INDEX(accession),
FULLTEXT(comment),
FULLTEXT(defline),
FULLTEXT(genename),
PRIMARY KEY (genome_id))";
   my $ret = $me->MyExecute(statement => $statement,);
   my $insert_stmt = qq"INSERT IGNORE INTO gene_info (genome_id, accession, species, genename, comment, defline) SELECT id, accession, species, genename, comment, defline FROM genome";
   return($me->Create_Do($table, $statement));
}

sub Genome {
    my $me = shift;
    my $table = "genome";
    my $statement = qq"CREATE table $table (
id $me->{config}->{sql_id},
accession $me->{config}->{sql_accession},
gi_number $me->{config}->{sql_gi_number},
genename $me->{config}->{sql_genename},
locus text,
ontology_function text,
ontology_component text,
ontology_process text,
version int,
comment $me->{config}->{sql_comment},
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
lastupdate $me->{config}->{sql_timestamp},
INDEX(genename),
PRIMARY KEY (id))";
    return($me->Create_Do($table, $statement));
}

sub Import_Queue {
    my $me = shift;
    my $table = 'import_queue';
    my $statement = qq"CREATE TABLE $table (
id $me->{config}->{sql_id},
accession $me->{config}->{sql_accession},
PRIMARY KEY (id))";
    return($me->Create_Do($table, $statement));
}

sub Index_Stats {
    my $me = shift;
    my $table = "index_stats";
    my $statement = qq"CREATE table $table (
id $me->{config}->{sql_id},
species $me->{config}->{sql_species},
num_genome int,
num_mfe_entries int,
num_mfe_knotted int,
PRIMARY KEY (id))";
    return($me->Create_Do($table, $statement));
}

sub NumSlipsite {
    my $me = shift;
    my $table = "numslipsite";
    my $statement = qq"CREATE table $table (
id $me->{config}->{sql_id},
accession $me->{config}->{sql_accession},
num_slipsite int,
lastupdate $me->{config}->{sql_timestamp},
PRIMARY KEY (id))";
    return($me->Create_Do($table, $statement));
}

sub Species_Summary {
    my $me = shift;
    my $table = "species_summary";
    my $statement = qq"CREATE table $table (
id $me->{config}->{sql_id},
species $me->{config}->{sql_species},
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
    return($me->Create_Do($table, $statement));
}

sub Landscape {
    my $me = shift;
    my $table = shift;
    $table = 'landscape_virus' if ($table =~ /virus/);
    my $statement = qq"CREATE TABLE $table (
id $me->{config}->{sql_id},
genome_id int,
species $me->{config}->{sql_species},
accession $me->{config}->{sql_accession},
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
lastupdate $me->{config}->{sql_timestamp},
INDEX(genome_id),
INDEX(accession),
PRIMARY KEY(id))";
    return($me->Create_Do($table, $statement));
}

sub MFE {
    my $me = shift;
    my $table = shift;
    $table = 'mfe_virus' if ($table =~ /virus/);
    my $statement = qq"CREATE TABLE $table (
id $me->{config}->{sql_id},
genome_id int,
accession $me->{config}->{sql_accession},
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
lastupdate $me->{config}->{sql_timestamp},
INDEX(genome_id),
INDEX(accession),
PRIMARY KEY(id))";
    return($me->Create_Do($table, $statement));
}

sub MFE_Utr {
    my $me = shift;
    my $table = "mfe_utr";
    my $statement = qq"CREATE TABLE $table (
id $me->{config}->{sql_id},
genome_id int,
species $me->{config}->{sql_species},
accession $me->{config}->{sql_accession},
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
lastupdate $me->{config}->{sql_timestamp},
INDEX(genome_id),
INDEX(accession),
PRIMARY KEY(id))";
    return($me->Create_Do($table, $statement));
}

sub MicroRNA {
    my $me = shift;
    my $table = "microrna";
    my $statement = qq"CREATE TABLE $table (
id $me->{config}->{sql_id},
species $me->{config}->{sql_species},
micro_name text,
hairpin_accession $me->{config}->{sql_accession},
hairpin text,
mature_accession $me->{config}->{sql_accession},
mature text,
star_accession $me->{config}->{sql_accession},
mature_star text,
fivep_accession $me->{config}->{sql_accession},
mature_5p text,
threep_accession $me->{config}->{sql_accession},
mature_3p text,
PRIMARY KEY (id))";
    return($me->Create_Do($table, $statement));
}

sub Nosy {
    my $me = shift;
    my $table = "nosy";
    my $statement = qq"CREATE TABLE nosy (
ip char(15),
visited $me->{config}->{sql_timestamp},
PRIMARY KEY(ip))";
    return($me->Create_Do($table, $statement));
}

sub Overlap {
    my $me = shift;
    my $table = "overlap";
    my $statement = qq"CREATE table $table (
id $me->{config}->{sql_id},
genome_id int,
species $me->{config}->{sql_species},
accession $me->{config}->{sql_accession},
start int,
plus_length int,
plus_orf text,
minus_length int,
minus_orf text,
lastupdate $me->{config}->{sql_timestamp},
PRIMARY KEY (id))";
    return($me->Create_Do($table, $statement));
}

sub Queue {
    my $me = shift;
    my $table = shift;
    if (!defined($table)) {
	if (defined( $me->{config}->{queue_table})) {
	    $table = $me->{config}->{queue_table};
	}
	else {
	    $table = 'queue';
	}
    }
    my $statement = qq"CREATE TABLE $table (
id $me->{config}->{sql_id},
genome_id int,
checked_out bool,
checked_out_time timestamp default 0,
done bool,
done_time timestamp default 0,
PRIMARY KEY (id))";
    return($me->Create_Do($table, $statement));
}

sub Stats {
    my $me = shift;
    my $table = "stats";
    my $statement = qq"CREATE table $table (
id $me->{config}->{sql_id},
species $me->{config}->{sql_species},
seqlength int,
max_mfe float,
min_mfe float,
algorithm varchar(10),
num_sequences int,
slipsite char(7),
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
total_genes int,
genes_hits int,
genes_1mfe int,
genes_2mfe int,
genes_1z int,
genes_2z int,
genes_1both int,
genes_2both int,
genes_1mfe_knotted int,
genes_2mfe_knotted int,
genes_1both_knotted int,
genes_2both_knotted int,
PRIMARY KEY (id))";
    return($me->Create_Do($table, $statement));
}

sub Variations {
    my $me = shift;
    my $table = "variations";
    my $statement = qq"CREATE TABLE $table (
id $me->{config}->{sql_id},
dbSNP text,
accession $me->{config}->{sql_accession},
start int,
stop int,
complement int,
vars text,
frameshift char(1),
note text,
FULLTEXT(dbSNP),
INDEX(accession),
PRIMARY KEY(id))";
    return($me->Create_Do($table, $statement));
}

sub Wait {
    my $me = shift;
    my $table = "wait";
    my $statement = qq"CREATE table $table (wait int, primary key(wait))";
    return($me->Create_Do($table, $statement));
}

sub Tables {
    my $me = shift;
    $me->Create_Agree() if (!$me->Tablep("agree"));
    $me->Create_Boot("boot_saccharomyces_cerevisiae") if (!$me->Tablep("boot_saccharomyces_cerevisiae"));
    $me->Create_Errors() if (!$me->Tablep("errors"));
    $me->Create_Evaluate() if (!$me->Tablep("evaluate"));
    $me->Create_Gene_Info() if (!$me->Tablep("gene_info"));
    $me->Create_Genome() if (!$me->Tablep("genome"));
    $me->Create_Import_Queue() if (!$me->Tablep("import_queue"));
    $me->Create_Index_Stats() if (!$me->Tablep("index_stats"));
    $me->Create_Landscape("landscape_saccharomyces_cerevisiae") if (!$me->Tablep("landscape_saccharomyces_cerevisiae"));
    $me->Create_MFE("mfe_saccharomyces_cerevisiae") if (!$me->Tablep("mfe_saccharomyces_cerevisiae"));
    $me->Create_MFE_Utr() if (!$me->Tablep("mfe_utr"));
    $me->Create_Nosy() if (!$me->Tablep("nosy"));
    $me->Create_NumSlipsite() if (!$me->Tablep("numslipsite"));
    $me->Create_Overlap() if (!$me->Tablep("overlap"));
    $me->Create_Queue() if (!$me->Tablep("queue"));
    $me->Create_Stats() if (!$me->Tablep("stats"));
    $me->Create_Variations() if (!$me->Tablep("variations"));
    $me->Create_Wait() if (!$me->Tablep("wait"));
}

sub AUTOLOAD {
    my $me = shift;
    my $name = $AUTOLOAD;
    print "Unable to find the function: $name in PRFdb::Create\n";
    $name =~ s/.*://;   # strip fully-qualified portion
    if (@_) {
	return $me->{$name} = shift;
    } else {
	return $me->{$name};
    }
}

1;
