package RNAFolders;
use strict;
use IO::Handle;
use lib 'lib';
use PkParse;
use PRFdb qw / Callstack AddOpen RemoveFile /;
use File::Basename;
use vars qw($VERSION);
$VERSION='20120304';

sub new {
    my ($class, %args) = @_;
    my $me = bless {
	config => $args{config},
	file => $args{file},
	genome_id => $args{genome_id},
	species => $args{species},
	accession => $args{accession},
	start => $args{start},
	slippery => $args{slippery},
	sequence => $args{sequence},
    }, $class;
    return($me);
}


sub Make_ct {
    my ($me, %args) = @_;
    my @seq_array = split(//, $args{sequence});
    my @in_array = split(/\s+/, $args{output});
    my $num_bases = scalar(@seq_array);
    my $output_string = "$num_bases temporary_ct_file\n";
    foreach my $c (0 .. $#seq_array) {
	my $position = $c + 1;
	my $last = $c;
	my $next = $c+2;
	if (!defined($in_array[$c])) {  ## Why did I do this?
	    $output_string .= "$c $seq_array[$c] $last $next $seq_array[$c]\n";
	}
	elsif ($in_array[$c] eq '.') {
	    $output_string .= "$position $seq_array[$c] $last $next 0\n";
	}
	else {
	    my $bound_position = $in_array[$c] + 1;
	    $output_string .= "$position $seq_array[$c] $last $next $bound_position\n";
	}
    }
    $me->{ctseq} = $output_string;
    return($output_string);
}

sub Make_bpseq {
    my ($me, %args) = @_;
    my @seq_array = split(//, $args{sequence});
    my @in_array = split(/\s+/, $args{output});

    my $output_string = '';

    print STDERR "BPSEQ DEBUG: @seq_array\n@in_array\n" if ($args{debug});

    foreach my $c (0 .. $#seq_array) {
	if (!defined($in_array[$c])) {
	    $output_string .= "$c $seq_array[$c] 0\n";
	}
	elsif ($in_array[$c] eq '.') {
	    my $position = $c + 1;
	    $output_string .= "$position $seq_array[$c] 0\n";
	}
	else {
	    my $position = $c + 1;
	    my $bound_position = $in_array[$c] + 1;
	    $output_string .= "$position $seq_array[$c] $bound_position\n";
	}
    }
    $me->{bpseq} = $output_string;
    return($output_string);
}

sub Prepare {
    my ($me, %args) = @_;
    my $prog = $args{prog};
    my $inputfile = $me->{file};
    my $accession = $me->{accession};
    my $start = $me->{start};
    my $slipsite = Get_Slipsite_From_Input($inputfile);
    my $errorfile = qq"${inputfile}_${prog}.err";
    AddOpen($errorfile);
    my $seq = Get_Sequence_From_Input($inputfile);
    my $name = Get_Sequence_From_Input($inputfile, 'comment');
    my $ret = {
	start => $start,
	slipsite => $slipsite,
	knotp => 0,
	genome_id => $me->{genome_id},
	species => $me->{species},
	accession => $accession,
	sequence_name => $name,
	sequence => $seq,
	seqlength => length($seq),
    };
    return($ret);
}

## Compute_Energy generates Turner99 compatible MFEs
sub Compute_Energy {
    my ($me, %args) = @_;
    my $seq = $args{sequence};
    my $par = $args{parens};
    Callstack(die => 1, message => "Sequence ($seq) or parens ($par) undefined in Compute_Energy.") unless ($seq and $par);
    my $config = $me->{config};
    my $seqlen = length($seq);
    my $parlen = length($par);
    while ($seqlen > $parlen) {
	$par .= '.';
	$parlen = length($par);
    }
    while ($parlen > $seqlen) {
	$seq .= '.';
	$seqlen = length($seq);
    }
    $seq =~ s/\s+//g;
    $par =~ s/\s+//g;
    my $command_line = qq"cd $ENV{PRFDB_HOME}/bin && $ENV{PRFDB_HOME}/bin/computeEnergy -d $seq \"$par\"";
    print "Compute_Energy:
$command_line\n" if ($config->{debug});
    open(EVAL, "$command_line |") or Callstack(message => qq"computeEnergy failed: $!");
    my $value;
    while (my $line = <EVAL>) {
	chomp $line;
	next unless ($line =~ /^Energy1/);
	my ($crap, $fun) = split(/Energy2\s+=/, $line);
	$value = sprintf("%.1f", $fun);
    }
    close(EVAL);
    return($value);
}

sub Nupack {
    my $me = shift;
    $me->Nupack_NOPAIRS(@_);
}

sub Nupack_NOPAIRS {
    my ($me, %args) = @_;
    my $pseudo = $args{pseudo};
    my $config = $me->{config};
    my $inputfile = $me->{file};
    my $accession = $me->{accession};
    my $start = $me->{start};
    my $nupack = qq($config->{workdir}/$config->{exe_nupack});
    my $nupack_boot = qq($config->{workdir}/$config->{exe_nupack_boot});
    my $errorfile = qq(${inputfile}_nupacknopairs.err);
    AddOpen($errorfile);
    my $slipsite = Get_Slipsite_From_Input($inputfile);
    my $ret = {
	start => $start,
	slipsite => $slipsite,
	knotp => 0,
	genome_id => $me->{genome_id},
	species => $me->{species},
	accession => $me->{accession},
    };
    chdir($config->{workdir});
    my $command;
    Callstack(die => 1, message => qq"$config->{workdir}/dataS_G.dna is missing.") unless (-r "$config->{workdir}/dataS_G.dna");
    Callstack(die => 1, message => qq"$config->{workdir}/dataS_G.rna is missing.") unless (-r "$config->{workdir}/dataS_G.rna");

    if (defined($pseudo) and $pseudo eq 'nopseudo') {
	Callstack(die => 1, message => qq"$nupack_boot is missing.") unless (-r $nupack_boot);
	$command = qq($nupack_boot $inputfile 2>$errorfile);
    }
    else {
	warn("The nupack executable does not have 'nopairs' in its name") unless ($config->{exe_nupack} =~ /nopairs/);
	Callstack(die => 1, message => "$nupack is missing.") unless (-r $nupack);
	$command = qq($nupack $inputfile 2>$errorfile);
    }
    print "NUPACK_NOPAIRS: infile: $inputfile accession: $accession start: $start
command: $command\n" if ($config->{debug});
    my $nupack_pid = open(NU, "$command |") or Callstack(message => "RNAFolders::Nupack_NOPAIRS, Could not run nupack: $command $!");
    ## OPEN NU in Nupack_NOPAIRS
    my $count = 0;
    my @nupack_output = ();
    my $pairs = 0;
    my $nupack_output = '';
    while (my $line = <NU>) {
	$nupack_output .= $line;
	if ($line =~ /Error opening loop data file: dataS_G.rna/) {
	    Callstack(message => "RNAFolders::Nupack_NOPAIRS, Missing dataS_G.rna!");
	}
	$count++;
	## The first 15 lines of nupack output are worthless.
	next unless ($count > 14);
	chomp $line;
	if ($count == 15) {
	    my ($crap, $len) = split(/\ \=\ /, $line);
	    $ret->{seqlength} = $len;
	}
	elsif ($count == 17) {    ## Line 17 returns the input sequence
	    $ret->{sequence} = $line;
	}
	elsif ($line =~ /^\d+\s\d+$/) {
	    my ($fiveprime, $threeprime) = split(/\s+/, $line);
	    my $five = $fiveprime - 1;
	    my $three = $threeprime - 1;
	    $nupack_output[$three] = $five;
	    $nupack_output[$five] = $three;
	    $pairs++;
	    $count--;
	}
	elsif ($count == 18) {    ## Line 18 returns paren output
	    $ret->{parens} = $line;
	}
	elsif ($count == 19) {    ## Get the MFE here
	    my $tmp = $line;
	    $tmp =~ s/^mfe\ \=\ //g;
	    $tmp =~ s/\ kcal\/mol//g;
	    $ret->{mfe} = $tmp;
	}
	elsif ($count == 20) {    ## Is it a pseudoknot?
	    if ($line eq 'pseudoknotted!') {
		$ret->{knotp} = 1;
	    }
	    else {
		$ret->{knotp} = 0;
	    }
	}
    }    ## End of the line reading the nupack output.
    close(NU);
    ## CLOSE NU in Nupack_NOPAIRS
    my $nupack_return = $?;
    if ($nupack_return eq '35584') {
	Callstack(message => "Nupack error $command $! 35584");
	system("/bin/cat $inputfile");
    }
    if ($nupack_return eq '139') {
	Callstack(die => 1, message => "Nupack file permission error on out.pair/out.ene");
    }
    unless ($nupack_return eq '0' or $nupack_return eq '256') {
	  Callstack(die => 1, message => qq"Nupack Error running $command\n
Return: $nupack_return\n");
    }
    RemoveFile($errorfile);
    for my $c (0 .. $#nupack_output) {
	$nupack_output[$c] = '.' unless (defined $nupack_output[$c]);
    }
    my $nupack_output_string = '';
    foreach my $char (@nupack_output) { $nupack_output_string .= "$char "; }
    $ret->{output} = $nupack_output_string;
    $ret->{pairs}  = $pairs;
    if (!defined($ret->{output})) {
	Callstack(message => "Output is not defined for accession: $accession start: $start in RNAFolders");
    }
    if (!defined($ret->{pairs})) {
	Callstack(message => "Pairs is not defined for accession: $accession start: $start in RNAFolders");
    }

    my $parser;
    if (defined($config->{max_spaces})) {
	my $max_spaces = $config->{max_spaces};
	$parser = new PkParse(debug => $config->{debug}, max_spaces => $max_spaces);
    }
    else {
	$parser = new PkParse(debug => $config->{debug});
    }
    my $out = $parser->Unzip(\@nupack_output);
    my $new_struc = PkParse::ReBarcoder($out);
    my $barcode = PkParse::Condense($new_struc);
    my $parsed = '';
    foreach my $char (@{$out}) {
	$parsed .= $char . ' ';
    }
    $parsed = PkParse::ReOrder_Stems($parsed);
    $ret->{parsed} = $parsed;
    $ret->{barcode} = $barcode;
    chdir($ENV{PRFDB_HOME});
    if (!defined($ret->{sequence})) {
	Callstack();
	print STDERR "The full output from nupack was: $nupack_output\n";
	Callstack(message => "Sequence is not defined for accession: $accession start: $start in RNAFolders");
	$ret->{sequence} = $me->{sequence};
    }
    $ret->{sequence} = Sequence_T_U($ret->{sequence});
    return($ret);
}

sub ILM {
    my ($me, %args) = @_;
    ## ilm takes the mwm format as initial format.
    ## name :sequence (with u or t)
    ## Wow, ILM has some problems.
    my $config = $me->{config};
    my $ret = $me->Prepare(prog => 'ilm',);
    chdir($config->{workdir});
    my $mwm = $me->Make_MWM(sequence_name => $ret->{sequence_name}, sequence => $ret->{sequence},);
    my $hlx_command = qq"$ENV{PRFDB_HOME}/bin/xhlxplot $mwm > ${mwm}.matrix";
    AddOpen("${mwm}.matrix");
    my $ilm_command = qq"$ENV{PRFDB_HOME}/bin/ilm ${mwm}.matrix 2> ${mwm}.err 1> ${mwm}.bpseq";
    AddOpen("${mwm}.err");
    AddOpen("${mwm}.bpseq");
    print "TESTME: $hlx_command \n $ilm_command\n" if ($config->{debug});
    open(HLX, "$hlx_command |");
    close(HLX);
    open(ILM, "$ilm_command |");
    close(ILM);
    open(BP, "<${mwm}.bpseq");
    my @ilmout = ();
    while (my $line = <BP>) {
	next if ($line =~ /^\s+$/);
	next if ($line =~ /Final/);
	my ($fiveprime, $threeprime)  = split(/\s+/, $line);
	my $five = $fiveprime - 1;
	my $three = $threeprime - 1;
	if ($three == -1) {
	    $ilmout[$five] = '.';
	}
	else {
	    $ilmout[$five] = $three;
	}
    }
    close(BP);
    my $parser = new PkParse;
    my $out = $parser->Unzip(\@ilmout);
    my $new_struc = PkParse::ReBarcoder($out);
    my $barcode = PkParse::Condense($new_struc);
    my $parens = PkParse::MAKEBRACKETS(\@ilmout);
    my $mfe = $me->Compute_Energy(sequence => $ret->{sequence}, parens => $parens);
    print "DEBUG: $barcode\n$parens\n$mfe\n" if ($config->{debug});
    $ret->{mfe} = $mfe;
    $ret->{parens} = $parens;
    $ret->{barcode} = $barcode;
    return($ret);
}

sub Unafold {
    my ($me, %args) = @_;
    my $output = {};
    my $config = $me->{config};
    my $inputfile = $me->{file};
    my $accession = $me->{accession};
    my $start = $me->{start};
    my $slipsite = Get_Slipsite_From_Input($inputfile);
    my $ret = {
	start => $start,
	slipsite => $slipsite,
	genome_id => $me->{genome_id},
	species => $me->{species},
	accession => $me->{accession},
    };
    my $seq = Get_Sequence_From_Input($inputfile);
    $ret->{sequence} = Sequence_T_U($seq);
    $ret->{seqlength} = length($seq);
    my $command = qq"cd $config->{workdir} && $ENV{PRFDB_HOME}/bin/hybrid-ss-min $inputfile";
#    Callstack(message => "Running $command");
    my $unafold_pid = open(UNA, "$command |") or
	Callstack(message => "RNAFolders::Unafold, Could not run unafold: $command $!");
    while (my $l = <UNA>) {
	chomp $l;
    }
    my @output_files = ('run','dG','ct','37.plot','37.ext');
    my $input_filename = basename($inputfile);
    foreach my $f (@output_files) {
	my $output_filename = qq"$config->{workdir}/${input_filename}.$f";
	Callstack(die => 1, message => "Could not open $output_filename $!") unless (-r $output_filename);
	AddOpen($output_filename);
	if ($f eq 'dG') {
	    open(DG, "<$output_filename") or Callstack(message => "Could not open $output_filename $!");
	    while (my $line = <DG>) {
		chomp $line;
		next if ($line =~ /^\#/);
		my ($temp, $dg, $gas_constant) = split(/\S+/, $line);
		$ret->{mfe} = $dg;
	    }
	    close(DG);
	}
	elsif ($f eq 'ct') {
	    my $output_array = $me->CT_to_Output(inputfile => $output_filename);
	    my $output_string = "@{$output_array}";
	    $ret->{output} = $output_string;
	    my $parser = new PkParse(debug => $config->{debug},);
	    my @struct_array = @{$output_array};
	    my $out = $parser->Unzip(\@struct_array);
	    $ret->{parens} = PkParse::MAKEBRACKETS(\@struct_array);
	    my $new_struct = PkParse::ReBarcoder($out);
	    $ret->{barcode} = PkParse::Condense($new_struct);
	    my $parsed = '';
	    foreach my $char(@{$out}) {
		$parsed .= $char . ' ';
	    }
	    $ret->{parsed} = PkParse::ReOrder_Stems($parsed);
	}
	RemoveFile($output_filename);
    } ## End foreach output file

    ## Lets start by just figuring out the various command lines that unafold actually calls in the distribution unafold.pl
    # hybrid-ss with (--suffix DAT, --tmin mintemp, --tmax maxtemp, --NA sodium, --magnesium mag, --polymer, --allpairs, --circular, --nodangle, --simple, --traceback max)
    # hybrid-ss-min -- same options but --mfold=$p,$w,$max which default to 5,-1,undef

    ##  hybrid-ss runs one set for each temperature from -1 to 100 ish, while hybrid-ss-min by default only runs at 37C.

    # If the model is not 'PF' then run h-num.pl...
    # A file with the suffix .ss-count should be generated, run ss-count.pl on it
    ## Pipe the output of this ct-energy --suffix somethingsomething
    ## It prints some html!?  then runs ct-energy with the --suffix etc args again and |'s it to ct_energy-det.pl
    ## It performs some shenanigans to convert temperatures...
    ## Then prints it to the html

    ## On the other hand, if the model is 'PF'
    ## Run hybrid-plot-ng --temperature $temp --format png|jpeg|gif
    ## Perform some more shenanigans and run boxplot_ng

    ## Somewhere along the way, a bunch of _$fold.ct files were created...
    ## run $sirgraph on each one..

    ## ct2rnaml may be used to generate rnaml versions, that is nice
    return($ret);
}

## A quick note on the .ct file format...
#A CT (Connectivity Table) file contains secondary structure information for a sequence. These files are saved with a CT extension. When entering a structure to calculate the free energy, the following format must be followed.
#
#    Start of first line: number of bases in the sequence
#    End of first line: title of the structure
#    Each of the following lines provides information about a given base in the sequence. Each base has its own line, with these elements in order:
#        Base number: index n
#        Base (A, C, G, T, U, X)
#        Index n-1
#        Index n+1
#        Number of the base to which n is paired. No pairing is indicated by 0 (zero).
#        Natural numbering. RNAstructure ignores the actual value given in natural numbering, so it is easiest to repeat n here.#
#
#1The CT file may hold multiple structures for a single sequence. This is done by repeating the format for each structure without any blank lines between structures. 
sub CT_to_Output {
    my ($me, %args) = @_;
    my $filename = $args{inputfile};
    open(IN, "<$filename") or CallStack(message => "Could not open $filename $!");
    my @output = ();
    my $line_count = -1;
    while (my $line = <IN>) {
	chomp $line;
	$line_count++;
	if ($line_count == 0) {
#82      dG = -16.8      testme -- an example ct first line
	    my ($num_lines, @comment) = split(/\s+/, $line);
	    for my $c (0 .. ($num_lines - 1)) {
		$output[$c] = '.';
	    }
	}
	else { ## Not on the first line
	    my ($base_num, $base, $index, $next, $base_pair, $base_num_again, @base_pairs) = split(/\s+/, $line);
	    next if ($base_pair eq '0');
	    $output[$index] = ($base_pair - 1);
	}
    }  ## End of the while
# An example line
#base_n  base    index   next    bp
#1       A       0       2       0       1       0       0
    return(\@output);
}

sub BPSeq_to_Out {
    my $me = shift;
    
}

sub Vienna {
    my $me = shift;
    my $inputfile = $me->{file};
    my $accession = $me->{accession};
    my $start = $me->{start};
    my $config = $me->{config};
    if (!-r $inputfile) {
	Callstack(message => "Missing inputfile.");
	open(NEWIN, ">$inputfile");
	my $db = new PRFdb(config => $config);
	my $species = $db->MySelect("SELECT species FROM genome WHERE accession = ?", vars => [$accession], type => 'single');
	my $mfe_table = "mfe_$species";
	my $seq = $db->MySelect("SELECT slipsite, sequence FROM $mfe_table where accession = ?", vars => [$accession]);
	my $missing_slipsite = $seq->[0]->[0];
	my $missing_sequence = $seq->[0]->[1];
	print NEWIN ">$accession
${missing_slipsite}${missing_sequence}
";
	undef($db);
    }
    my $slipsite = Get_Slipsite_From_Input($inputfile);
    my $seq = Get_Sequence_From_Input($inputfile);
    if (!defined($seq)) {
	Callstack(message => "Sequence is not defined in Vienna");
    }
    my $errorfile = qq(${inputfile}_vienna.err);
    AddOpen($errorfile);
    my $ret = {
        start => $start,
        slipsite => $slipsite,
        genome_id => $me->{genome_id},
        species => $me->{species},
        accession => $me->{accession},
        sequence => $seq,
        seqlength => length($seq),
        mfe => undef,
    };
    chdir($config->{workdir});
    my $command = qq($config->{exe_rnafold} -noLP -noconv -noPS < $inputfile);
    print "Vienna: infile: $inputfile accession: $accession start: $start
command: $command\n" if ($config->{debug});
    open(VI, "$command |") or Callstack(message => "RNAFolders::Vienna, Could not run RNAfold: $command $!");
    my $counter = 0;
    WH: while (my $line = <VI>) {
	if ($line =~ /^\>/) {
	    next WH;
	}
	if ($line =~ /^$/) {
	    next WH;
	}
        $counter++;
	chomp $line;
	if ($counter == 1) {
	    $ret->{sequence} = $line;
	}
	elsif ($counter == 2) {
            my ($struct, $num) = split(/\s+\(\s*/, $line);
            if (!defined($num)) {
            }
            $num =~ s/\)//g;
            $ret->{parens} = $struct;
            $ret->{mfe} = $num;
        }
    } ## End the while
    close(VI);
    RemoveFile($errorfile);
    if (!defined($ret->{sequence})) {
	Callstack(message => "Sequence is not defined for accession: $accession start: $start in RNAFolders");
    }
    $ret->{sequence} = Sequence_T_U($ret->{sequence});
    my $output = $me->Parens_to_Output(sequence => $ret->{sequence} , parens => $ret->{parens});
    my $output_string = "@{$output}";
    $ret->{output} = $output_string;
    my $parser = new PkParse(debug => $config->{debug},);
    my @struct_array = split(/\s+/, $ret->{output});
    my $out = $parser->Unzip(\@struct_array);
    my $new_struct = PkParse::ReBarcoder($out);
    my $barcode = PkParse::Condense($new_struct);
    my $parsed = '';
    foreach my $char(@{$out}) {
	$parsed .= $char . ' ';
    }
    $parsed = PkParse::ReOrder_Stems($parsed);
    $ret->{parsed} = $parsed;
    $ret->{barcode} = $barcode;
    return($ret);
}

sub Parens_to_Output {
    my $me = shift;
    my %args = @_;
    my $sequence = $args{sequence};
    my $parens = $args{parens};
    my @seq = split(//, $sequence);
    my @par = split(//, $parens);
    my @output = ();
    for my $c (@par) {
	push(@output, '.');
    }
    my $finished = 0;
    LOOP: while ($finished == 0) {
	my $fivep = 0;
#	print "@par\n@output";
	foreach my $c (0 .. $#par) {
#	    print STDERR "TESTME: $c $par[$c]\n";
	    if ($par[$c] eq '(') {
		$fivep = $c;
	    } 
	    elsif ($par[$c] eq ')') {
		$output[$fivep] = $c;
		$output[$c] = $fivep;
		$par[$fivep] = '.';
		$par[$c] = '.';
		next LOOP;
	    }
	    if ($c == $#par) {
		$finished = 1;  ## This will break out of the while
	    }
	}
    }  ## End of the while.
    return(\@output);
}

sub Pknots {
    my $me = shift;
    my $pseudo = shift;
    my $inputfile = $me->{file};
    my $accession = $me->{accession};
    my $start = $me->{start};
    my $config = $me->{config};
    my $errorfile = qq(${inputfile}_pknots.err);
    AddOpen($errorfile);
    my $slipsite = Get_Slipsite_From_Input($inputfile);
    my $seq = Get_Sequence_From_Input($inputfile);
    my $ret = {
	start => $start,
	slipsite => $slipsite,
	knotp => 0,
	genome_id => $me->{genome_id},
	species => $me->{species},
	accession => $me->{accession},
	sequence => $seq,
	seqlength => length($seq),
    };
    chdir($config->{workdir});
    my $command;
    if (!-r $config->{exe_pknots}) {
	Callstack(die => 1, message => "pknots: $config->{exe_pknots} is missing.");
    }
    if (defined($pseudo) and $pseudo eq 'nopseudo') {
	$command = qq"$config->{exe_pknots} $inputfile 2>$errorfile";
    }
    else {
	$command = qq"$config->{exe_pknots} -k $inputfile 2>$errorfile";
    }
    print "PKNOTS: infile: $inputfile accession: $accession start: $start
command: $command\n" if ($config->{debug});
#    open(PK, "$command |") or Callstack(message => "RNAFolders::Pknots, Could not run pknots: $command");
    open(PK, "$command |");
    ## OPEN PK in Pknots
    my $counter = 0;
    my ($line_to_read, $crap) = undef;
    my $string = '';
    my $uninteresting = undef;
    my $parser;
    while (my $line = <PK>) {
	$counter++;
	chomp $line;
	### The NAM field prints out the name of the sequence
	### Which is set to the slippery site in RNAMotif
	if ($line =~ /^NAM/) {
	    ($crap, $ret->{slipsite}) = split(/NAM\s+/, $line);
	    $ret->{slipsite} =~ tr/actgTu/ACUGUU/;
	}
	elsif ($line =~ /^\s+\d+\s+[A-Z]+/) {
	    $line_to_read = $counter + 2;
	}
	elsif (defined($line_to_read) and $line_to_read == $counter) {
	    $line =~ s/^\s+//g;
	    $line =~ s/$/ /g;
	    $string .= $line;
	}
	elsif ($line =~ /\/mol\)\:\s+/) {
	    ($crap, $ret->{mfe}) = split(/\/mol\)\:\s+/, $line);
	}
	elsif ($line =~ /found\:\s+/) {
	    ($crap, $ret->{pairs}) = split(/found\:\s+/, $line);
	}
    }    ## For every line of pknots
    close(PK);
    ## CLOSE PK in Pknots
    my $pknots_return = $?;
    unless ($pknots_return eq '0' or $pknots_return eq '256' or $pknots_return eq '134' or $pknots_return eq '34304') {
	Callstack(message => "Pknots Error running $command $?");
    }
    RemoveFile($errorfile);
    $string =~ s/\s+/ /g;
    $ret->{output} = $string;
    if (defined($config->{max_spaces})) {
	my $max_spaces = $config->{max_spaces};
	$parser = new PkParse(debug => $config->{debug}, max_spaces => $max_spaces);
    }
    else {
	$parser = new PkParse(debug => $config->{debug});
    }
    my @struct_array = split(/\s+/, $string);
    my $out = $parser->Unzip(\@struct_array);
    my $new_struc = PkParse::ReBarcoder($out);
    my $barcode = PkParse::Condense($new_struc);
    my $parsed = '';
    foreach my $char (@{$out}) {
	$parsed .= $char . ' ';
    }
    $parsed = PkParse::ReOrder_Stems($parsed);
    $ret->{parsed} = $parsed;
    $ret->{barcode} = $barcode;
    $ret->{parens} = PkParse::MAKEBRACKETS(\@struct_array);
    if ($parser->{pseudoknot} == 0) {
	$ret->{knotp} = 0;
    }
    else {
	$ret->{knotp} = 1;
    }

    if ($ret->{parens} =~ /\{/) {
	$ret->{knotp} = 1;
    }
    chdir($ENV{PRFDB_HOME});
    if (!defined($ret->{sequence})) {
	Callstack(message => "Sequence is not defined in RNAFolders");
    }
    $ret->{sequence} = Sequence_T_U($ret->{sequence});
    return($ret);
}

sub Make_MWM {
    my $me = shift;
    my %args = @_;
    my $mwm_file = $me->{file};
    $mwm_file =~ s/\.fasta$/\.mwm/g;
    open(IN, ">$mwm_file");
    my $name = $args{sequence_name};
    $name =~ s/\s+//g;
    $name =~ s/\://g;
    print IN "$name :$args{sequence}\n";
    close(IN);
    AddOpen($mwm_file);
    return($mwm_file);
}

sub Get_Sequence_From_Input {
    my $inputfile = shift;
    my $comment = shift;
    open(SEQ, "<$inputfile");
    ## OPEN SEQ in Get_Sequence_From_Input
    my $seq;
    while (my $line = <SEQ>) {
	chomp $line;
	if ($line =~ /^\>/) {
	    if ($comment) {
		$line =~ s/^\>//g;
		close(SEQ);
		return($line);
	    }
	    else {
		next;
	    }
	}
	else {
	    $seq .= $line;
	}
    }
    close(SEQ);
    ## CLOSE SEQ in Get_Sequence_From_Input
    return($seq);
}

sub Get_Slipsite_From_Input {
    my $inputfile = shift;
    open(SLIP, "<$inputfile");
    ## OPEN SLIP in Get_Slipsite_From_Input
    my ($slipsite, $crap);
    while (my $line = <SLIP>) {
	chomp $line;
	if ($line =~ /^\>/) {
	    ($slipsite, $crap) = split(/ /, $line);
	    $slipsite =~ tr/actgTu/ACUGUU/;
	    $slipsite =~ s/\>//g;
	}
	else {
	    next;
	}
    }
    close(SLIP);
    ## CLOSE SLIP in Get_Slipsite_From_Input
    return($slipsite);
}

sub Pknots_Boot {
    ## The caller of this function is in Bootlace.pm and does not expect it to be
    ## In an OO fashion.
    my $inputfile = shift;
    my $accession = shift;
    my $start = shift;
    my $config = shift;
    my $errorfile = qq(${inputfile}_pknots.err);
    AddOpen($errorfile);
    ##  This expected for a bootlace include:
    ##  MFE, PAIRS
    my $ret = {
	accession => $accession,
	start => $start,
    };
    chdir($config->{workdir});
    my $command = qq($config->{exe_pknots} $inputfile 2>$errorfile);
    open(PK, "$command |") or Callstack(message => "RNAFolders::Pknots_Boot, Failed to run pknots: $command");
    ## OPEN PK in Pknots_Boot
    my $counter = 0;
    my ($line_to_read, $crap) = undef;
    my $string = '';
    my $uninteresting = undef;
    while (my $line = <PK>) {
	next if (defined($uninteresting));
	$counter++;
	chomp $line;
	if ($line =~ /^NAM/) {
	    my ($crap, $name ) = split( /NAM\s+/, $line);
	}
	elsif ($line =~ m/\/mol\)\:\s+/) {
	    ($crap, $ret->{mfe}) = split(/\/mol\)\:\s+/, $line);
	}
	elsif ($line =~ /found\:\s+/) {
	    ($crap, $ret->{pairs}) = split(/found\:\s+/, $line);
	    $uninteresting = 1;
	}
	elsif ($line =~ /^\s+\d+\s+[A-Z]+/) {
	    $line_to_read = $counter + 2;
	}
	elsif (defined($line_to_read) and $line_to_read == $counter) {
	    $line =~ s/^\s+//g;
	    $line =~ s/$/ /g;
	    $string .= $line;
	}
    }    ## For every line of pknots
    close(PK);
    ## CLOSE PK in Pknots_Boot
    my $pknots_return = $?;
    unless ($pknots_return eq '0' or $pknots_return eq '256' or $pknots_return eq '134' or $pknots_return eq '34304') {
	Callstack(message => "Pknots Error: $command");
    }
    RemoveFile($errorfile);
    return($ret);
}

sub Nupack_Boot {
    ## The caller of this function is in Bootlace.pm and does not expect it to be
    ## In an OO fashion.
    Nupack_Boot_NOPAIRS(@_);
}

sub Nupack_Boot_NOPAIRS {
    ## The caller of this function is in Bootlace.pm and does not expect it to be
    ## In an OO fashion.
    my $inputfile = shift;
    my $accession = shift;
    my $start = shift;
    my $config = shift;
    my $nupack = qq($config->{workdir}/$config->{exe_nupack});
    my $nupack_boot = qq($config->{workdir}/$config->{exe_nupack_boot});
    my $errorfile = qq(${inputfile}_nupack.err);
    AddOpen($errorfile);
    my $ret = {
	accession => $accession,
	start => $start,
    };
    chdir($config->{workdir});
    Callstack(die => 1, message => qq"$config->{workdir}/dataS_G.dna is missing.") unless (-r "$config->{workdir}/dataS_G.dna");
    Callstack(die => 1, message => qq"$config->{workdir}/dataS_G.rna is missing.") unless (-r "$config->{workdir}/dataS_G.rna");
    Callstack(die => 1, message => qq"$nupack_boot is missing.") unless (-r $nupack_boot);
    warn("The nupack executable does not have 'nopairs' in its name") unless ($config->{exe_nupack} =~ /nopairs/);
    my $command = qq($nupack_boot $inputfile 2>$errorfile);
    my @nupack_output;
    open(NU, "$command |") or Callstack(message => "RNAFolders::Nupack_Boot_NOPAIRS, Failed to run nupack:  $command");
    ## OPEN NU in Nupack_Boot_NOPAIRS
    my $counter = 0;
    my $pairs = 0;
    while (my $line = <NU>) {
	chomp $line;
	$counter++;
	if ($line =~ /^\d+\s\d+$/) {
	    $pairs++;
	    $counter--;
	}
	elsif ($counter == 19) {
	    my $tmp = $line;
	    $tmp =~ s/^mfe\ \=\ //g;
	    $tmp =~ s/\ kcal\/mol//g;
	    $ret->{mfe} = $tmp;
	}
	else {
	    next;
	}
    }    ## End of the output from nupack_boot
    close(NU);
    ## CLOSE NU in Nupack_Boot_NOPAIRS
    my $nupack_return = $?;
    if ($nupack_return eq '139') {
	Callstack(die => 1, message => "Nupack file permission error on out.pair/out.ene");
    }
    unless ($nupack_return eq '0' or $nupack_return eq '256') {
	Callstack(die => 1,message => "Nupack Error running $command: $!", $accession);
    }
    RemoveFile($errorfile);
    $ret->{pairs} = $pairs;
    return($ret);
}

sub Hotknots {
    my $me = shift;
    my $inputfile = $me->{file};
    my $accession = $me->{accession};
    my $start = $me->{start};
    my $config = $me->{config};
    my $errorfile = qq(${inputfile}_hotknots.err);
    AddOpen($errorfile);
    my $slipsite = Get_Slipsite_From_Input($inputfile);
    my $seq = Get_Sequence_From_Input($inputfile);
    my $ret = {
	start => $start,
	slipsite => $slipsite,
	knotp => 0,
	genome_id => $me->{genome_id},
	species => $me->{species},
	accession => $accession,
	sequence => $seq,
	seqlength => length($seq),
    };
    chdir($config->{workdir});
    my $seqname = $inputfile;
    $seqname =~ s/\.fasta//g;
    my $tempfile = $inputfile;
    if ($tempfile =~ m/\.fasta/) {
      $tempfile =~ s/\.fasta/\.seq/g;
    }
    else {
      $tempfile .= ".seq";
    }
    open(IN, ">$tempfile");
    print IN $seq;
    close(IN);
    my $command = qq"$config->{workdir}/$config->{exe_hotknots} -I $seqname -noPS -b";
    print "HotKnots: infile: $inputfile accession: $accession start: $start
command: $command\n" if ($config->{debug});
    open(HK, "$command |") or Callstack(message => "Problem with $command.");
    while(my $line = <HK>) {
#	print $line;
	$ret->{num_hotspots} = $line if ($line =~ /number of hotspots/);
    }
    close(HK);

    ## Check for output files.
    my $bpseqfile = "${seqname}0_RE.bpseq";
    my $ctfile = qq(${seqname}_RE.ct);
    unless (-r $bpseqfile) { ## if the Rivas/Eddy file does not exist, then use the suboptimals.
	$bpseqfile = "${seqname}0.bpseq";
	$ctfile = "${seqname}.ct";
    }

    AddOpen($bpseqfile);
    open(BPSEQ, "<$bpseqfile");
    $ret->{output} = '';
    $ret->{pairs} = 0;
    while (my $bps = <BPSEQ>) {
	my ($basenum, $base, $basepair) = split(/\s+/, $bps);
	if ($basepair =~ /\d+/) {
	    if ($basepair == 0) {
		$ret->{output} .= '. ';
	    }
	    elsif ($basepair > 0) {
		my $basepair_num = $basepair - 1;
		$ret->{output} .= "$basepair_num ";
		$ret->{pairs}++;
	    }
	    else {
		Callstack(die => 1, message => "Something is fubared.");
	    }
	}
	else {
	    Callstack(die => 1, message => "Something is fubared.");
	}
    }
    $ret->{pairs} = $ret->{pairs} / 2;
    close(BPSEQ);

    AddOpen($ctfile);
    open(GETMFE, "grep ENERGY $ctfile | head -1 |");
    while (my $getmfeline = <GETMFE>) {
	my ($null, $num, $ENERGY, $eq, $mfe, $crap) = split(/\s+/, $getmfeline);
	$ret->{mfe} = $mfe;
    }
    close(GETMFE);

    RemoveFile([$ctfile, $bpseqfile, $errorfile]);

    my $parser = new PkParse(debug => $config->{debug});
    my @struct_array = split(/\s+/, $ret->{output});
    my $out = $parser->Unzip(\@struct_array);
    my $new_struct = PkParse::ReBarcoder($out);
    my $barcode = PkParse::Condense($new_struct);
    my $parsed = '';
    foreach my $char (@{$out}) {
	$parsed .= $char . ' ';
    }
    $parsed = PkParse::ReOrder_Stems($parsed);
    $ret->{parsed} = $parsed;
    $ret->{barcode} = $barcode;
    $ret->{parens} = PkParse::MAKEBRACKETS(\@struct_array);
    if ($parser->{pseudoknot} == 0) {
	$ret->{knotp} = 0;
    }
    else {
	$ret->{knotp} = 1;
    }
    chdir($ENV{PRFDB_HOME});
    if (!defined($ret->{sequence})) {
	Callstack(message => "Sequence is not defined for accession: $accession start: $start\n");
    }
    $ret->{sequence} = Sequence_T_U($ret->{sequence});
    return($ret);
}

sub Hotknots_Boot {
    my $inputfile = shift;
    my $accession = shift;
    my $start = shift;
    my $config = shift;
    my $errorfile = qq(${inputfile}_hotknots.err);
    AddOpen($errorfile);
    my $slipsite = Get_Slipsite_From_Input($inputfile);
    my $seq = Get_Sequence_From_Input($inputfile);
    $seq = '' if (!defined($seq));
    my $ret = {
        start => $start,
        slipsite => $slipsite,
	knotp => 0,
        accession => $accession,
        sequence => $seq,
        seqlength => length($seq),
    };
    chdir($config->{workdir});
    my $seqname = $inputfile;
    $seqname =~ s/\.fasta//g;
    my $tempfile = $inputfile;
    $tempfile =~ s/\.fasta/\.seq/g;
    open(IN, ">$tempfile");
    print IN $seq;
    close(IN);
    my $command = qq($config->{workdir}/$config->{exe_hotknots} -I $seqname -noPS -b 2>$errorfile);
    print "Hotknots boot: infile: $inputfile accession: $accession start: $start
command: $command\n" if ($config->{debug});
    open(HK, "$command |");
    while(my $line = <HK>) {
        $ret->{num_hotspots} = $line if ($line =~ /number of hotspots/);
    }
    close(HK);
    my $bpseqfile = "${seqname}0_RE.bpseq";
    AddOpen($tempfile);
    AddOpen($bpseqfile);
    my $open_ret = open(BPSEQ, "<$bpseqfile");
    if (defined($open_ret)) {
	$ret->{output} = '';
	$ret->{pairs} = 0;
	while (my $bps = <BPSEQ>) {
	    my ($basenum, $base, $basepair) = split(/\s+/, $bps);
	    if ($basepair =~ /\d+/) {
		if ($basepair == 0) {
		    $ret->{output} .= '. ';
		}
		elsif ($basepair > 0) {
		    my $basepair_num = $basepair - 1;
		    $ret->{output} .= "$basepair_num ";
		    $ret->{pairs}++;
		}
		else {
		    Callstack(message => "The number of basepairs is negative?  $basepair");
		    last;
		}
	    }
	    else {
		Callstack(message => "The base pair is not a number: $basepair.");
		last;
	    }
	}
	$ret->{pairs} = $ret->{pairs} / 2;
	close(BPSEQ);
    } ## If we were able to open the CT file.
    my $ctfile = qq(${seqname}_RE.ct);
    AddOpen($ctfile);
    open(GETMFE, "grep ENERGY $ctfile | head -1 |");
    while (my $getmfeline = <GETMFE>) {
        my ($null, $num, $ENERGY, $eq, $mfe, $crap) = split(/\s+/, $getmfeline);
        $ret->{mfe} = $mfe;
    }
    close(GETMFE);

    RemoveFile([$ctfile, $bpseqfile, $errorfile, $tempfile]);
    my $parser = new PkParse(debug => $config->{debug});
    my @struct_array = split(/\s+/, $ret->{output});
    my $out = $parser->Unzip(\@struct_array);
    my $new_struct = PkParse::ReBarcoder($out);
    my $barcode = PkParse::Condense($new_struct);
    my $parsed = '';
    foreach my $char (@{$out}) {
	$parsed .= $char . ' ';
    }
    $parsed = PkParse::ReOrder_Stems($parsed);
    $ret->{parsed} = $parsed;
    $ret->{barcode} = $barcode;
    $ret->{parens} = PkParse::MAKEBRACKETS(\@struct_array);
    if ($parser->{pseudoknot} == 0) {
        $ret->{knotp} = 0;
    }
    else {
        $ret->{knotp} = 1;
    }
    chdir($ENV{PRFDB_HOME});
    $ret->{sequence} = Sequence_T_U($ret->{sequence});
    return($ret);
}

sub Sequence_T_U {
    my $sequence = shift;
    return(undef) if (!defined($sequence));
    $sequence =~ tr/T/U/;
    return($sequence);
}

1;
