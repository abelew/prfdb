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

## Common SQL datatypes shared among many tables
# sql_id : serial
# sql_accession : varchar(40)
# sql_comment : text not null
# sql_genename : varchar(120)
# sql_gi_number : varchar(80)
# sql_species : varchar(80)
# sql_timestamp : TIMESTAMP ON UPDATE CURRENT_TIMESTAMP DEFAULT CURRENT TIMESTAMP

## Agree holds the degree of agreement among various
## predictions for a given sequence window
sub Agree {
    my $me = shift;
    my $table = "agree";
    my $statement = qq"CREATE table $table (
id $me->{config}->{sql_id},			/* Incrementing ID */
accession $me->{config}->{sql_accession},	/* Accession from genbank/SGD/etc */
start int,					/* Position of the first base of the PRF slippery site */
length int,					/* Length of the folding window (typically 50,75, or 100 bp) */
all_agree int,					/* Number of bases for which all predictions agree */
no_agree int,					/* Number of bases for which no predictions agree */
n_alone int,					/* Number of bases predicted by nupack only */
h_alone int,					/* Number of bases predicted by hotknots only */
p_alone int,					/* Number of bases predicted by pknots only */
hplusn int,					/* Number predicted bases shared by hotknots and nupack */
nplusp int,					/* Number predicted bases shared by nupack and pknots */
hplusp int,					/* Number predicted bases shared by hotknots and pknots */
hnp int,					/* Number predicted bases by all three but not shared */
PRIMARY KEY (id))";
    return($me->Create_Do($table, $statement));
}

## Boot holds the randomization data, and is split into
## one table for each species in the database
sub Boot {
    my $me = shift;
    my $table = shift;
    $table = 'boot_virus' if ($table =~ /virus/);
    my $statement = qq"CREATE TABLE $table (
id $me->{config}->{sql_id},			/* Incrementing ID */
genome_id bigint,				/* Primary ID from the genome table */
mfe_id int,					/* Primary ID from the mfe table */
species $me->{config}->{sql_species},		/* Species Name */
accession $me->{config}->{sql_accession},	/* Accession from ncbi/sgd/etc */
start int,					/* Position of the first base of the PRF signal */
seqlength int,					/* Sequence window length */
iterations int,					/* Number randomizations performed */
rand_method char(20),				/* Randomization method utilized */
mfe_method char(20),				/* Program used for MFE calculation */
mfe_mean float,					/* Mean of n randomizations */
mfe_sd float,					/* Standard deviation of n randomizations */
mfe_se float,					/* Standard error of n randomizations */
pairs_mean float,				/* Mean Number of base pairs predicted */
pairs_sd float,					/* Standard deviation of base pair predictions */
pairs_se float,					/* Standard error of base pair predictions */
mfe_values text,				/* Raw mfe values */
zscore float,					/* Z-score of MFE at mfe_id n vs randomizations */
lastupdate $me->{config}->{sql_timestamp},	/* timestamp */
INDEX(genome_id),
INDEX(mfe_id),
INDEX(accession),
PRIMARY KEY(id))";
    return($me->Create_Do($table, $statement));
}

## This table really isn't necessary any longer.
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

## Gene_info contains indexed text information for every
## accession for search functionality
sub Gene_Info {
   my $me = shift;
   my $table = "gene_info";
   my $statement = qq"CREATE table $table (
genome_id bigint,				/* Primary ID from the genome table */
accession $me->{config}->{sql_accession},	/* Accession from ncbi/sgd/etc */
species $me->{config}->{sql_species},		/* Species Name */
genename $me->{config}->{sql_genename},		/* Genename initially provided by SGD, may be deprecated */
comment $me->{config}->{sql_comment},		/* Comment initially provided by SGD, may be deprecated */
defline text not null,				/* Definition line initially provided by SGD */
publications text,				/* a list of pubmed IDs */
db_xrefs text,					/* a list of pubmed/etc cross references */
hgnc_id text,					/* The canonical gene name's id at genenames.org */
omim_id varchar(30),				/* Online Inheritence in Man ID */
hgnc_name text,					/* The canonical gene name at genenames.org */
gene_synonyms text,				/* a list of the gene names for this */
refseq_comment text,				/* the COMMENT field from refseq */
INDEX(accession),
FULLTEXT(comment),
FULLTEXT(defline),
FULLTEXT(genename),
PRIMARY KEY (genome_id))";
   my $ret = $me->MyExecute(statement => $statement,);
   my $insert_stmt = qq"INSERT IGNORE INTO gene_info (genome_id, accession, species, genename, comment, defline) SELECT id, accession, species, genename, comment, defline FROM genome";
   return($me->Create_Do($table, $statement));
}

## Genome contains the 'important' data for each accession
## raw sequence, start position etc.
## It also currently holds some of the data which has been
## moved to gene_info and should be cleaned.
sub Genome {
    my $me = shift;
    my $table = "genome";
    my $statement = qq"CREATE table $table (
id $me->{config}->{sql_id},
accession $me->{config}->{sql_accession},	/* Accession from ncbi/sgd/etc */
gi_number $me->{config}->{sql_gi_number},	/* GI number from ncbi, only used by PRFsnp, likely deprecated */
genename $me->{config}->{sql_genename},		/* Genename initially provided by SGD, may be deprecated */
locus text,					/* Description from SGD, move information to comment and drop this */
ontology_function text,				/* Store the GO ontology_function string */
ontology_component text,			/* Store the GO ontology_component string */
ontology_process text,				/* Store the GO ontology_process string */
version int,					/* NCBI version for the sequence, deprecated */
comment $me->{config}->{sql_comment},		/* Comment initially provided by SGD, may be deprecated */
defline blob not null,				/* Definition line initially provided by SGD */
mrna_seq longblob not null,			/* Raw mRNA sequence */
protein_seq text,				/* Translation from SeqMisc.pm */
orf_start int,					/* Position of the start of the ORF */
orf_stop int,					/* Position of the end of the ORF */
direction char(7) DEFAULT 'forward',		/* Direction, only relevant for viral sequences */
found_snp bool,					/* Does this (human only) gene have a SNP */
average_mfe text,				/* Average MFE */
snp_lastupdate TIMESTAMP DEFAULT '00:00:00',	/* Timestamp for SNPdata */
lastupdate $me->{config}->{sql_timestamp},	/* Timestamp */
INDEX(genename),
PRIMARY KEY (id))";
    return($me->Create_Do($table, $statement));
}

## Import queue is a queue of sequences to be folded
## in case of large import batches (like genbank)
sub Import_Queue {
    my $me = shift;
    my $table = 'import_queue';
    my $statement = qq"CREATE TABLE $table (
id $me->{config}->{sql_id},
accession $me->{config}->{sql_accession},
PRIMARY KEY (id))";
    return($me->Create_Do($table, $statement));
}

## Index_stats holds the general number of folds by genome
## Shown on the homepage
sub Index_Stats {
    my $me = shift;
    my $table = "index_stats";
    my $statement = qq"CREATE table $table (
id $me->{config}->{sql_id},
species $me->{config}->{sql_species},		/* Species name */
num_genome int,					/* How many genes? */
num_mfe_entries int,				/* How many predictions were performed? */
num_mfe_knotted int,				/* How many of these are predicted to form pseudoknots? */
PRIMARY KEY (id))";
    return($me->Create_Do($table, $statement));
}

## Numslipsites just counts the number of potential PRF signals
## found by rnamotif
## This replaces the once ridiculous rnamotif table with what is
## essentially a boolean to test against for each accession
sub NumSlipsite {
    my $me = shift;
    my $table = "numslipsite";
    my $statement = qq"CREATE table $table (
id $me->{config}->{sql_id},
accession $me->{config}->{sql_accession},	/* Accession from ncbi/sgd/etc */
num_slipsite int,				/* Count of potential PRF signals */
lastupdate $me->{config}->{sql_timestamp},	/* Timestamp */
PRIMARY KEY (id))";
    return($me->Create_Do($table, $statement));
}

sub Species_Summary {
    my $me = shift;
    my $table = "species_summary";
    my $statement = qq"CREATE table $table (
id $me->{config}->{sql_id},
species $me->{config}->{sql_species},		/* Species Name */
genes int,					/* How many genes for this species */
nupack_folds int,				/* Number nupack predictions */
pknots_folds int,				/* Number pknots predictions */
hotknots_folds int,				/* Number hotknots predictions */
nupack_pseudo int,				/* Nupack pseudoknot predictions */
pknots_pseudo int,				/* Pknots pseudoknot predictions */
hotknots_pseudo int,				/* Hotknots pseudoknot predictions */
nupack_sig int,					/* Number nupack 'significant' predictions */
pknots_sig int,					/* Number pknots 'significant' predictions */
hotknots_sig int,				/* Number hotknots 'significant' predictions */
PRIMARY KEY (id))";
    return($me->Create_Do($table, $statement));
}

sub Landscape {
    my $me = shift;
    my $table = shift;
    $table = 'landscape_virus' if ($table =~ /virus/);
    my $statement = qq"CREATE TABLE $table (
id $me->{config}->{sql_id},			/* Incrementing primary ID */
genome_id bigint,				/* Primary ID from the genome table */
species $me->{config}->{sql_species},		/* Species Name */
accession $me->{config}->{sql_accession},	/* Accession from ncbi/sgd/etc */
mfe_method char(10),				/* Program used for MFE calculation */
start int,					/* Position of the first base of the PRF signal */
seqlength int,					/* Sequence window length */
sequence text,					/* mRNA sequence tested */
output text,					/* Raw output from mfe_method */
parsed text,					/* Parsed output from mfe_method */
parens text,					/* Parens output from mfe_method, no longer strictly necessary */
mfe float,					/* MFE prediction from mfe_method */
pairs int,					/* Number of base pairs predicted for mfe_method */
knotp bool,					/* Is this prediction a pseudoknot? */
barcode text,					/* Shorthand code for the prediction */
lastupdate $me->{config}->{sql_timestamp},	/* Timestamp */
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
id $me->{config}->{sql_id},			/* Incrementing ID */
genome_id bigint,				/* Primary ID from the genome table */
accession $me->{config}->{sql_accession},	/* Accession from ncbi/sgd/etc */
mfe_method char(20),				/* Program used for MFE calculation */
start int,					/* Position of the first base of the PRF signal */
slipsite char(7),				/* Slippery heptamer bases */
seqlength int,					/* Sequence window length, usually 50,75,100 */
sequence text,					/* Sequence window */
output text,					/* Raw output from mfe_method */
parsed text,					/* Parsed output from mfe_method */
parens text,					/* Parens output from mfe_method, no longer strictly necessary */
mfe float,					/* MFE prediction from mfe_method */
pairs int,					/* Number base pairs predicted from mfe_method */
knotp bool,					/* Is this prediction a pseudoknot */
barcode text,					/* Shorthand code for the prediction */
compare_mfes varchar(30),			/* Measurement of the similarity of the predictions */
has_snp bool DEFAULT FALSE,			/* Boolean, does this have a snp */
bp_mstop int,					/* Boolean, does this have the end of the mRNA */
lastupdate $me->{config}->{sql_timestamp},	/* Timestamp */
INDEX(genome_id),
INDEX(accession),
PRIMARY KEY(id))";
    return($me->Create_Do($table, $statement));
}

## This table should be dropped, in fact I think it already has been.
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

## MicroRNAs from microrna.org
sub MicroRNA {
    my $me = shift;
    my $table = "microrna";
    my $statement = qq"CREATE TABLE $table (
id $me->{config}->{sql_id},			/* Incrementing primary ID */
species $me->{config}->{sql_species},		/* Species Name */
micro_name text,				/* MicroRNA name */
hairpin_accession $me->{config}->{sql_accession}, /* Accession of the miRNA */
hairpin text,					/* Raw sequence */
mature_accession $me->{config}->{sql_accession}, /* Accession of the matured miRNA */
mature text,					/* Raw mature sequence */
star_accession $me->{config}->{sql_accession},	/* Accession of the star isoform */
mature_star text,				/* Raw star isoform sequence */
fivep_accession $me->{config}->{sql_accession},	/* 5p isoform accession */
mature_5p text,					/* 5p isoform sequence */
threep_accession $me->{config}->{sql_accession},/* 3p isoform accession */
mature_3p text,					/* 3p isoform sequence */
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
id $me->{config}->{sql_id},			/* Incrementing ID */
genome_id bigint,				/* Primary ID from the genome table */
species $me->{config}->{sql_species},		/* Species Name */
accession $me->{config}->{sql_accession},	/* Accession from ncbi/sgd/etc */
start int,					/* Position of the first base of the PRF signal */
plus_length int,				/* Length of the +1 extension */
plus_orf text,					/* Amino acid sequence of the +1 extension */
minus_length int,				/* Length of the -1 sequence */
minus_orf text,					/* Amino acid sequence of the -1 extension */
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
id $me->{config}->{sql_id},			/* Incrementing primary ID */
genome_id bigint,				/* Primary ID from the genome table */
checked_out bool,				/* Has this sequence been checked out for analysis? */
checked_out_time timestamp default 0,		/* If so, when? */
done bool,					/* Has this sequence been completed? */
done_time timestamp default 0,			/* If so, when? */
PRIMARY KEY (id))";
    return($me->Create_Do($table, $statement));
}

sub Stats {
    my $me = shift;
    my $table = "stats";
    my $statement = qq"CREATE table $table (
id $me->{config}->{sql_id},			/* Incrementing primary ID */
species $me->{config}->{sql_species},		/* Species Name */
seqlength int,					/* Length of the folding window (typically 50,75, or 100 bp) */
max_mfe float,					/* Maximum observed mfe for this species */
min_mfe float,					/* Minimum observed mfe for this species */
mfe_method varchar(10),				/* Program used for MFE calculation */
num_sequences int,				/* Number of predictions for this species */
slipsite char(7),				/* Slippery heptamer sequence */
avg_mfe float,					/* Average observed mfe */
stddev_mfe float,				/* Standard deviation of mfes */
avg_pairs float,				/* Average observed base pairs */
stddev_pairs float,				/* Standard deviation of base pairs */
num_sequences_noknot int,			/* Number of sequences predicted without pseudoknot */
avg_mfe_noknot float,				/* Average mfe of the non-pseudoknot predictions */
stddev_mfe_noknot float,			/* Standard deviation of non-pseudoknot predictions */
avg_pairs_noknot float,				/* Average predicted base pairs of non-pseudoknots */
stddev_pairs_noknot float,			/* Standard deviation of base pairs of non-pseudoknots */
num_sequences_knotted int,			/* Number of sequences predicted with pseudoknots */
avg_mfe_knotted float,				/* Average mfe of pseudoknot predictions */
stddev_mfe_knotted float,			/* Standard deviation of pseudoknot mfe */
avg_pairs_knotted float,			/* Average base pairs of pseudoknot predictions */
stddev_pairs_knotted float,			/* Standard deviation of pseudoknot base pairs */
avg_zscore float,				/* Global average z-score */
stddev_zscore float,				/* Global standard deviation z-score */
total_genes int,				/* Number genes */
genes_hits int,					/* How many genes have predicitons */
genes_1mfe int,					/* How many genes have predictions falling > 1Z from mean */
genes_2mfe int,					/* How many have 2Z from mean */
genes_1z int,					/* How many have Zs 1Z from mean */
genes_2z int,					/* How many have Zs 2Z from mean */
genes_1both int,				/* How many have 1Z from both axes */
genes_2both int,				/* How many have 2Z from both axes */
genes_1mfe_knotted int,				/* Of the 1Z mfe, how many are pseudoknots */
genes_2mfe_knotted int,				/* Of the 2Z mfe, how many are pseudoknots */
genes_1both_knotted int,			/* Of the 1z both axes, how many are pseudoknots */
genes_2both_knotted int,			/* Of the 2z both axes, how many are pseudoknots */
PRIMARY KEY (id))";
    return($me->Create_Do($table, $statement));
}

sub Variations {
    my $me = shift;
    my $table = "variations";
    my $statement = qq"CREATE TABLE $table (
id $me->{config}->{sql_id},			/* Incrementing ID */
dbSNP text,					/* Text from ncbi dbsnp */
accession $me->{config}->{sql_accession},	/* Accession from genbank/SGD/etc */
start int,					/* Position of the first base of the PRF slippery site */
stop int,					/* Position of the last base of the PRF slippery site */
complement int,
vars text,					/* SNP identity */
frameshift char(1),				/* Is this a PRF signal? */
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
