package SubstMatrix;
use Carp;

=head1 NAME

SubstMatrix - An object oriented Perl interface to the amino acid
substitution matrices

=head1 SYNOPSIS

 use SubstMatrix;
 my $object = new SubstMatrix(matrix => 'pam250');
 my $matrix = $object->Read_Matrix();
 my $alanine2leucine = $matrix->{A}->{L};

=cut

=head1 Caveat

If anyone ever actually reads this, I suggest you take a look at both 'perldoc
SubstMatrix' as well as read the actual code.  perldoc will give you an idea of
what this peculiar markup language is doing, while reading the actual code will
get you a play by play commentary of what I was thinking while writing this...

=cut

=head2 The Constructor

new() is a common object oriented constructor in many languages.  A perl
'object' is defined via the 'Package' statement and through the call to 'bless.'
Package tells Perl that the code which follows is of a particular namespace.
Namespaces provide a way to separate segments of code; thus allowing larger and
more complex pieces of code.  How?  If one does not separate namespaces, then
one will have to keep track of any instance of variables like counters and make
sure that names like 'counter' are not used more than once.  Run 'perldoc -f
package'.  Bless is the enforcer for package.  When package tells the program
that a new namespace exists, bless actually fills it up.

=cut

sub new {
  my ($class, %args) = @_;

=head3   my ($class, %args) = @_;

What the hell does that mean?  As you may know, @_ is the 'default' array, which
is to say that it consists of the arguments fed to the function new.  $class
gets to be the first argument, and the hash %args gets the rest...  So when you
type: my $mat = new SubstMatrix(matrix=>'blosum40'); that is the same as typing
$mat = new(SubstMatrix, (matrix=>'blosum40')); so $class will be 'SubstMatrix'
and the args hash will be filled with one entry, which says the matrix is
'blosum40'

=cut

  my $me = bless
	{
	 matrix => 'blosum62',
	 matrix_file => undef,
	 }, $class;

=head3 bless $class

As I mentioned a moment ago, bless does the work of putting something in a new
namespace.  It is possible to bless _any_ datatype in perl, scalars, arrays,
hashes, formats, handles, or even regular expressions (which can lead to some
really bizarre possibilities).  bless takes the given piece of data and throws
it into the provided namespace ($class in this case), and returns a piece of
information in that namespace -- I called it $me in this code

=cut

  $me->{matrix} = $args{matrix} if (defined($args{matrix}));
  return($me);

=head3 filling up a class

Once you have defined a class, Perl allows one to fill it in any way.  Just make
sure to return the newly instantiated object.

=cut

}

=head2 Score_Word

Score Word is a snippet of code which shows a LOT of the ideas which may prove
useful for homework...
  my $score = $matrix->Score_Word('ABC');  ## Evaluates to 17 I think

=cut

sub Score_Word {  ## sub tells perl that everything from { to } is part of a new
                  ## function called (in this case) Score_Word
  my $me = shift;
  my $word = shift;

=head3 What the hell is up with this shift crap?

  my $me = shift;
  my $word = shift;
Please recall that @_ is the 'default,' then run 'perldoc -f shift.'  That is
correct, when you shift an array, you get from it the first element; but as a
nice side effect you also get an array with one less element.  When I do:
$matrix->Score_Word('abc'), the first arg to Score_Word is $matrix, which
evaluates to the name of the namespace in which $matrix lives; thus it may be
more appropriate to say my $class = shift...  Now @_ has only one element left
and I immediately shifted it away into $word.

=cut

  my $score = 0;
  $word =~ tr/a-z/A-Z/;
  my @wordlist = split(//, $word);
  my $MATRIX = $me->Read_Matrix();

=head3 Getting ready to score a word

  my $score = 0;
  $word =~ tr/a-z/A-Z/;
  my @wordlist = split(//, $word);
  my $MATRIX = $me->Read_Matrix();
First I made an initial score of 0, then I made certain that all the
characters of the provided word are in uppercase.  Finally I made an
array called wordlist which contains one element for every character
(split up by a null) in $word.  Finally fill up $MATRIX with the information
the appropriate substitution matrix.

=cut

  foreach my $char (@wordlist) {
	$score = $score + $MATRIX->{$char}->{$char};
  }

=head3 Count up the score

  foreach my $char (@wordlist) {
	$score = $score + $MATRIX->{$char}->{$char};
  }
When I read this, I think to myself 'for every character in the word list, the
score has added to it the lod score of that character substituted to itself.

=cut

  return($score);  ## Return the calculated score to the caller
}

=head1 Read_Matrx

Read Matrix is the most important function here.  It fills up a hash of hashes
in which each key is an amino acid and points to another hash.  Each key of this
second hash is in turn another amino acid which in turn points to the value of
the substitution matrix.  Thus it allows one to easily find the score for any
substitution from amino acid a to b like this: $matrix->{A}->{B};

=cut

sub Read_Matrix {
  my $me = shift;
  my $read_matrix = $me->{matrix};
  my %matrix = ();
  my ($vert_amino, @scores, @order);

=head3 setting up Read_Matrix

  my $read_matrix = $me->{matrix};
  my %matrix = ();
  my ($vert_amino, @scores, @order);
$read_matrix is the most interesting thing here.  $me as you know, is the
current instance of the SubstMatrix class.  When that instance was created, it
acquired a default matrix which may be overridden.  Since the class is itself a
hash reference, one may pull out information from it as shown above...

=cut

  my $SUBST_MATRICES = Read_Matrices();

=head3 A call to Read_Matrices

If you check out Read_Matrices, you will find it contains text which I cut and
pasted _directly_ from the ncbi provided matrices (should I credit them??) and
dumped those strings into a hash in which the keys are the names and the values
are the multiple space delimited tables.

=cut

  if (defined($SUBST_MATRICES->{$read_matrix})) {  ## This is little more than
	## an example of an if and the use of 'defined'
	open(TMP, ">/tmp/amino_matrix");
	print TMP "$SUBST_MATRICES->{$read_matrix}\n";
	close(TMP);
	$matrix_file = "/tmp/amino_matrix";

=head3 Some reminders from the first homework

	open(TMP, ">/tmp/amino_matrix");
	print TMP "$SUBST_MATRICES->{$read_matrix}\n";
	close(TMP);
	$matrix_file = "/tmp/amino_matrix";
the ">" character before /tmp/amino_matrix tells perl to open the file
explicitly for writing.  ">>" would open it for appending, and "<" for
reading.  Then print to that file the text of the amino acid substitution
matrix.  This is _entrirely_ the wrong way to handle the job I am doing, but
an excellent way to illustrate opening a file...

=cut

  }
  else {
	my @matrices = sort keys(%{$SUBST_MATRICES});  ## An example of sort!!
	croak("Matrix $read_matrix not known, choices include: @matrices. $!");
  }
  open(MATRIX, "<$matrix_file") or die "Stupid matrix. $!";	
 LOOP: while (<MATRIX>) {
	next if ($_ =~ /\#/);
 	if ($_ =~ /^\s/) {
	  my $tmp = $_;
	  $tmp =~ s/\s//g;
	  @order = split(//, $tmp);
	  next LOOP;
	}

=head3 we wrote, now read!

  open(MATRIX, "<$matrix_file") or die "Stupid matrix. $!";	
 LOOP: while (<MATRIX>) {
	next if ($_ =~ /\#/);
 	if ($_ =~ /^\s/) {
	  my $tmp = $_;
	  $tmp =~ s/\s//g;
	  @order = split(//, $tmp);
	  next LOOP;
	}
I opened the filehandle called MATRIX from the read only matrix file.
Then I made a labeled loop out of an iteration over every line of the matrix
file.  An interesting thing about perl: it makes a wonderful attempt at
semi-natural language processing.  Thus you can tell it to do something
before an if statement.  In this case the action is 'next,' in this case that
means to skip to the next line of the matrix file if the default variable (which
in this case is the line -- $_) has a # in it.  Now, if the matrix file starts
with (^ means the line starts with) spaces (\s means spaces), then make a
variable $tmp as a copy of $_ and perform a substitution upon that variable.
The substitution should be read as follows:  $tmp is bound to (=~) the
substitution (s/) of any space (\s) with nothing (//) globally (g) -- globally
means do it as many times as the test matches the line.  So, if a line starts
with some space, get rid of all the spaces in it... then make @order from the
split by nothing of what is left.  Then skip to the next line (next LOOP)
What is @order?  It contains the list of amino acids on the top of the matrix!

=cut

	else {
	  my $tmp = $_;
	  @scores = split(/\s+/, $tmp);
	  $vert_amino = shift @scores;
	}

=head3 read every other line

	  my $tmp = $_;
	  @scores = split(/\s+/, $tmp);
	  $vert_amino = shift @scores;
again I chose to copy $_ to $tmp, I am not sure why... then I made an array
@scores from the split by every instance of 1 or more (+) spaces (\s) of the
line ($tmp).  Then pull off the first element, which is the name of the row's
amino acid and save it as $vert_amino.

=cut

	for my $horiz_pos (0 .. $#order) {
	  $matrix{$vert_amino}{$order[$horiz_pos]} = $scores[$horiz_pos];
	}

=head3 one confusing line

	for my $horiz_pos (0 .. $#order) {
	  $matrix{$vert_amino}{$order[$horiz_pos]} = $scores[$horiz_pos];
	}
I read this as follows:  For every horizontal position in the list of amino
acids, fill a piece of %matrix with one key which is the name of the amino
acid I just saved a moment ago and another key which is the current position in
@order and set that to the score at that position.

=cut

  }  ## End while loop
  unlink($matrix_file);
  return(\%matrix);

=head3 clean up

  unlink($matrix_file);
  return(\%matrix);
unlink deletes the file. Then I returned a reference (\) to the hash I just
finished creating

=cut

}

sub Find_Word_in_Sentence {
  my $word = shift;
  my $sentence = shift;
  my @positions = ();  ## Start with a null list of matches
  my $start = -10;         ## Totally arbitrary
  while ($start != -1) { ## As long as start is not -1
	if ($start == -10) {
	  ## $start == -10 only on the first iteration
	  $start = index($sentence, $word);  ## On this first iteration, do a search
	  ## word in the sentence, $start gets set to that location by index() if
	  ## index doesn't find the word, it retuns -1 -- thus the condition of the
	  ## while() loop.
	}
	else {
	  $start = index($sentence, $word, $start + 1);  ## After that iteration,
	  ## do a search starting at the character immediately after the current
	  ## match
	  }

	push(@positions, $start) if ($start != -1);
	## Add the found position of the word in the sentence to the list of
	## positions as long as it is found
  }
  return(\@positions);
  ## and return the list of positions
}

sub Every_three_char_word {
  my $sentence = shift;
  my @sen = split(//, @{$sentence});
  my @wordlist = ();
  while (scalar(@sen) > 2) {
	my $first = shift @sen;
	my $second = $sen[0];
	my $third = $sen[1];
	my $word = $first . $second . $third;
	push(@wordlist, $word);
  }
  return(\@wordlist);
}

sub Read_Matrices {
  my $m =
  {
   blosum80 =>
qq(   A  R  N  D  C  Q  E  G  H  I  L  K  M  F  P  S  T  W  Y  V  B  Z  X  *
A  5 -2 -2 -2 -1 -1 -1  0 -2 -2 -2 -1 -1 -3 -1  1  0 -3 -2  0 -2 -1 -1 -6
R -2  6 -1 -2 -4  1 -1 -3  0 -3 -3  2 -2 -4 -2 -1 -1 -4 -3 -3 -2  0 -1 -6
N -2 -1  6  1 -3  0 -1 -1  0 -4 -4  0 -3 -4 -3  0  0 -4 -3 -4  4  0 -1 -6
D -2 -2  1  6 -4 -1  1 -2 -2 -4 -5 -1 -4 -4 -2 -1 -1 -6 -4 -4  4  1 -2 -6
C -1 -4 -3 -4  9 -4 -5 -4 -4 -2 -2 -4 -2 -3 -4 -2 -1 -3 -3 -1 -4 -4 -3 -6
Q -1  1  0 -1 -4  6  2 -2  1 -3 -3  1  0 -4 -2  0 -1 -3 -2 -3  0  3 -1 -6
E -1 -1 -1  1 -5  2  6 -3  0 -4 -4  1 -2 -4 -2  0 -1 -4 -3 -3  1  4 -1 -6
G  0 -3 -1 -2 -4 -2 -3  6 -3 -5 -4 -2 -4 -4 -3 -1 -2 -4 -4 -4 -1 -3 -2 -6
H -2  0  0 -2 -4  1  0 -3  8 -4 -3 -1 -2 -2 -3 -1 -2 -3  2 -4 -1  0 -2 -6
I -2 -3 -4 -4 -2 -3 -4 -5 -4  5  1 -3  1 -1 -4 -3 -1 -3 -2  3 -4 -4 -2 -6
L -2 -3 -4 -5 -2 -3 -4 -4 -3  1  4 -3  2  0 -3 -3 -2 -2 -2  1 -4 -3 -2 -6
K -1  2  0 -1 -4  1  1 -2 -1 -3 -3  5 -2 -4 -1 -1 -1 -4 -3 -3 -1  1 -1 -6
M -1 -2 -3 -4 -2  0 -2 -4 -2  1  2 -2  6  0 -3 -2 -1 -2 -2  1 -3 -2 -1 -6
F -3 -4 -4 -4 -3 -4 -4 -4 -2 -1  0 -4  0  6 -4 -3 -2  0  3 -1 -4 -4 -2 -6
P -1 -2 -3 -2 -4 -2 -2 -3 -3 -4 -3 -1 -3 -4  8 -1 -2 -5 -4 -3 -2 -2 -2 -6
S  1 -1  0 -1 -2  0  0 -1 -1 -3 -3 -1 -2 -3 -1  5  1 -4 -2 -2  0  0 -1 -6
T  0 -1  0 -1 -1 -1 -1 -2 -2 -1 -2 -1 -1 -2 -2  1  5 -4 -2  0 -1 -1 -1 -6
W -3 -4 -4 -6 -3 -3 -4 -4 -3 -3 -2 -4 -2  0 -5 -4 -4 11  2 -3 -5 -4 -3 -6
Y -2 -3 -3 -4 -3 -2 -3 -4  2 -2 -2 -3 -2  3 -4 -2 -2  2  7 -2 -3 -3 -2 -6
V  0 -3 -4 -4 -1 -3 -3 -4 -4  3  1 -3  1 -1 -3 -2  0 -3 -2  4 -4 -3 -1 -6
B -2 -2  4  4 -4  0  1 -1 -1 -4 -4 -1 -3 -4 -2  0 -1 -5 -3 -4  4  0 -2 -6
Z -1  0  0  1 -4  3  4 -3  0 -4 -3  1 -2 -4 -2  0 -1 -4 -3 -3  0  4 -1 -6
X -1 -1 -1 -2 -3 -1 -1 -2 -2 -2 -2 -1 -1 -2 -2 -1 -1 -3 -2 -1 -2 -1 -1 -6
* -6 -6 -6 -6 -6 -6 -6 -6 -6 -6 -6 -6 -6 -6 -6 -6 -6 -6 -6 -6 -6 -6 -6  1
),
   blosum45 =>
   qq(   A  R  N  D  C  Q  E  G  H  I  L  K  M  F  P  S  T  W  Y  V  B  Z  X  *
A  5 -2 -1 -2 -1 -1 -1  0 -2 -1 -1 -1 -1 -2 -1  1  0 -2 -2  0 -1 -1  0 -5
R -2  7  0 -1 -3  1  0 -2  0 -3 -2  3 -1 -2 -2 -1 -1 -2 -1 -2 -1  0 -1 -5
N -1  0  6  2 -2  0  0  0  1 -2 -3  0 -2 -2 -2  1  0 -4 -2 -3  4  0 -1 -5
D -2 -1  2  7 -3  0  2 -1  0 -4 -3  0 -3 -4 -1  0 -1 -4 -2 -3  5  1 -1 -5
C -1 -3 -2 -3 12 -3 -3 -3 -3 -3 -2 -3 -2 -2 -4 -1 -1 -5 -3 -1 -2 -3 -2 -5
Q -1  1  0  0 -3  6  2 -2  1 -2 -2  1  0 -4 -1  0 -1 -2 -1 -3  0  4 -1 -5
E -1  0  0  2 -3  2  6 -2  0 -3 -2  1 -2 -3  0  0 -1 -3 -2 -3  1  4 -1 -5
G  0 -2  0 -1 -3 -2 -2  7 -2 -4 -3 -2 -2 -3 -2  0 -2 -2 -3 -3 -1 -2 -1 -5
H -2  0  1  0 -3  1  0 -2 10 -3 -2 -1  0 -2 -2 -1 -2 -3  2 -3  0  0 -1 -5
I -1 -3 -2 -4 -3 -2 -3 -4 -3  5  2 -3  2  0 -2 -2 -1 -2  0  3 -3 -3 -1 -5
L -1 -2 -3 -3 -2 -2 -2 -3 -2  2  5 -3  2  1 -3 -3 -1 -2  0  1 -3 -2 -1 -5
K -1  3  0  0 -3  1  1 -2 -1 -3 -3  5 -1 -3 -1 -1 -1 -2 -1 -2  0  1 -1 -5
M -1 -1 -2 -3 -2  0 -2 -2  0  2  2 -1  6  0 -2 -2 -1 -2  0  1 -2 -1 -1 -5
F -2 -2 -2 -4 -2 -4 -3 -3 -2  0  1 -3  0  8 -3 -2 -1  1  3  0 -3 -3 -1 -5
P -1 -2 -2 -1 -4 -1  0 -2 -2 -2 -3 -1 -2 -3  9 -1 -1 -3 -3 -3 -2 -1 -1 -5
S  1 -1  1  0 -1  0  0  0 -1 -2 -3 -1 -2 -2 -1  4  2 -4 -2 -1  0  0  0 -5
T  0 -1  0 -1 -1 -1 -1 -2 -2 -1 -1 -1 -1 -1 -1  2  5 -3 -1  0  0 -1  0 -5
W -2 -2 -4 -4 -5 -2 -3 -2 -3 -2 -2 -2 -2  1 -3 -4 -3 15  3 -3 -4 -2 -2 -5
Y -2 -1 -2 -2 -3 -1 -2 -3  2  0  0 -1  0  3 -3 -2 -1  3  8 -1 -2 -2 -1 -5
V  0 -2 -3 -3 -1 -3 -3 -3 -3  3  1 -2  1  0 -3 -1  0 -3 -1  5 -3 -3 -1 -5
B -1 -1  4  5 -2  0  1 -1  0 -3 -3  0 -2 -3 -2  0  0 -4 -2 -3  4  2 -1 -5
Z -1  0  0  1 -3  4  4 -2  0 -3 -2  1 -1 -3 -1  0 -1 -2 -2 -3  2  4 -1 -5
X  0 -1 -1 -1 -2 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1  0  0 -2 -1 -1 -1 -1 -1 -5
* -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5  1
),
   blosum62 =>
   qq(   A  R  N  D  C  Q  E  G  H  I  L  K  M  F  P  S  T  W  Y  V  B  Z  X  *
A  4 -1 -2 -2  0 -1 -1  0 -2 -1 -1 -1 -1 -2 -1  1  0 -3 -2  0 -2 -1  0 -4
R -1  5  0 -2 -3  1  0 -2  0 -3 -2  2 -1 -3 -2 -1 -1 -3 -2 -3 -1  0 -1 -4
N -2  0  6  1 -3  0  0  0  1 -3 -3  0 -2 -3 -2  1  0 -4 -2 -3  3  0 -1 -4
D -2 -2  1  6 -3  0  2 -1 -1 -3 -4 -1 -3 -3 -1  0 -1 -4 -3 -3  4  1 -1 -4
C  0 -3 -3 -3  9 -3 -4 -3 -3 -1 -1 -3 -1 -2 -3 -1 -1 -2 -2 -1 -3 -3 -2 -4
Q -1  1  0  0 -3  5  2 -2  0 -3 -2  1  0 -3 -1  0 -1 -2 -1 -2  0  3 -1 -4
E -1  0  0  2 -4  2  5 -2  0 -3 -3  1 -2 -3 -1  0 -1 -3 -2 -2  1  4 -1 -4
G  0 -2  0 -1 -3 -2 -2  6 -2 -4 -4 -2 -3 -3 -2  0 -2 -2 -3 -3 -1 -2 -1 -4
H -2  0  1 -1 -3  0  0 -2  8 -3 -3 -1 -2 -1 -2 -1 -2 -2  2 -3  0  0 -1 -4
I -1 -3 -3 -3 -1 -3 -3 -4 -3  4  2 -3  1  0 -3 -2 -1 -3 -1  3 -3 -3 -1 -4
L -1 -2 -3 -4 -1 -2 -3 -4 -3  2  4 -2  2  0 -3 -2 -1 -2 -1  1 -4 -3 -1 -4
K -1  2  0 -1 -3  1  1 -2 -1 -3 -2  5 -1 -3 -1  0 -1 -3 -2 -2  0  1 -1 -4
M -1 -1 -2 -3 -1  0 -2 -3 -2  1  2 -1  5  0 -2 -1 -1 -1 -1  1 -3 -1 -1 -4
F -2 -3 -3 -3 -2 -3 -3 -3 -1  0  0 -3  0  6 -4 -2 -2  1  3 -1 -3 -3 -1 -4
P -1 -2 -2 -1 -3 -1 -1 -2 -2 -3 -3 -1 -2 -4  7 -1 -1 -4 -3 -2 -2 -1 -2 -4
S  1 -1  1  0 -1  0  0  0 -1 -2 -2  0 -1 -2 -1  4  1 -3 -2 -2  0  0  0 -4
T  0 -1  0 -1 -1 -1 -1 -2 -2 -1 -1 -1 -1 -2 -1  1  5 -2 -2  0 -1 -1  0 -4
W -3 -3 -4 -4 -2 -2 -3 -2 -2 -3 -2 -3 -1  1 -4 -3 -2 11  2 -3 -4 -3 -2 -4
Y -2 -2 -2 -3 -2 -1 -2 -3  2 -1 -1 -2 -1  3 -3 -2 -2  2  7 -1 -3 -2 -1 -4
V  0 -3 -3 -3 -1 -2 -2 -3 -3  3  1 -2  1 -1 -2 -2  0 -3 -1  4 -3 -2 -1 -4
B -2 -1  3  4 -3  0  1 -1  0 -3 -4  0 -3 -3 -2  0 -1 -4 -3 -3  4  1 -1 -4
Z -1  0  0  1 -3  3  4 -2  0 -3 -3  1 -1 -3 -1  0 -1 -3 -2 -2  1  4 -1 -4
X  0 -1 -1 -1 -2 -1 -1 -1 -1 -1 -1 -1 -1 -1 -2  0  0 -2 -1 -1 -1 -1 -1 -4
* -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4  1
),
   pam30 =>
   qq(    A   R   N   D   C   Q   E   G   H   I   L   K   M   F   P   S   T   W   Y   V   B   Z   X   *
A   6  -7  -4  -3  -6  -4  -2  -2  -7  -5  -6  -7  -5  -8  -2   0  -1 -13  -8  -2  -3  -3  -3 -17
R  -7   8  -6 -10  -8  -2  -9  -9  -2  -5  -8   0  -4  -9  -4  -3  -6  -2 -10  -8  -7  -4  -6 -17
N  -4  -6   8   2 -11  -3  -2  -3   0  -5  -7  -1  -9  -9  -6   0  -2  -8  -4  -8   6  -3  -3 -17
D  -3 -10   2   8 -14  -2   2  -3  -4  -7 -12  -4 -11 -15  -8  -4  -5 -15 -11  -8   6   1  -5 -17
C  -6  -8 -11 -14  10 -14 -14  -9  -7  -6 -15 -14 -13 -13  -8  -3  -8 -15  -4  -6 -12 -14  -9 -17
Q  -4  -2  -3  -2 -14   8   1  -7   1  -8  -5  -3  -4 -13  -3  -5  -5 -13 -12  -7  -3   6  -5 -17
E  -2  -9  -2   2 -14   1   8  -4  -5  -5  -9  -4  -7 -14  -5  -4  -6 -17  -8  -6   1   6  -5 -17
G  -2  -9  -3  -3  -9  -7  -4   6  -9 -11 -10  -7  -8  -9  -6  -2  -6 -15 -14  -5  -3  -5  -5 -17
H  -7  -2   0  -4  -7   1  -5  -9   9  -9  -6  -6 -10  -6  -4  -6  -7  -7  -3  -6  -1  -1  -5 -17
I  -5  -5  -5  -7  -6  -8  -5 -11  -9   8  -1  -6  -1  -2  -8  -7  -2 -14  -6   2  -6  -6  -5 -17
L  -6  -8  -7 -12 -15  -5  -9 -10  -6  -1   7  -8   1  -3  -7  -8  -7  -6  -7  -2  -9  -7  -6 -17
K  -7   0  -1  -4 -14  -3  -4  -7  -6  -6  -8   7  -2 -14  -6  -4  -3 -12  -9  -9  -2  -4  -5 -17
M  -5  -4  -9 -11 -13  -4  -7  -8 -10  -1   1  -2  11  -4  -8  -5  -4 -13 -11  -1 -10  -5  -5 -17
F  -8  -9  -9 -15 -13 -13 -14  -9  -6  -2  -3 -14  -4   9 -10  -6  -9  -4   2  -8 -10 -13  -8 -17
P  -2  -4  -6  -8  -8  -3  -5  -6  -4  -8  -7  -6  -8 -10   8  -2  -4 -14 -13  -6  -7  -4  -5 -17
S   0  -3   0  -4  -3  -5  -4  -2  -6  -7  -8  -4  -5  -6  -2   6   0  -5  -7  -6  -1  -5  -3 -17
T  -1  -6  -2  -5  -8  -5  -6  -6  -7  -2  -7  -3  -4  -9  -4   0   7 -13  -6  -3  -3  -6  -4 -17
W -13  -2  -8 -15 -15 -13 -17 -15  -7 -14  -6 -12 -13  -4 -14  -5 -13  13  -5 -15 -10 -14 -11 -17
Y  -8 -10  -4 -11  -4 -12  -8 -14  -3  -6  -7  -9 -11   2 -13  -7  -6  -5  10  -7  -6  -9  -7 -17
V  -2  -8  -8  -8  -6  -7  -6  -5  -6   2  -2  -9  -1  -8  -6  -6  -3 -15  -7   7  -8  -6  -5 -17
B  -3  -7   6   6 -12  -3   1  -3  -1  -6  -9  -2 -10 -10  -7  -1  -3 -10  -6  -8   6   0  -5 -17
Z  -3  -4  -3   1 -14   6   6  -5  -1  -6  -7  -4  -5 -13  -4  -5  -6 -14  -9  -6   0   6  -5 -17
X  -3  -6  -3  -5  -9  -5  -5  -5  -5  -5  -6  -5  -5  -8  -5  -3  -4 -11  -7  -5  -5  -5  -5 -17
* -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17   1
),
   pam70 =>
   qq(    A   R   N   D   C   Q   E   G   H   I   L   K   M   F   P   S   T   W   Y   V   B   Z   X   *
A   5  -4  -2  -1  -4  -2  -1   0  -4  -2  -4  -4  -3  -6   0   1   1  -9  -5  -1  -1  -1  -2 -11
R  -4   8  -3  -6  -5   0  -5  -6   0  -3  -6   2  -2  -7  -2  -1  -4   0  -7  -5  -4  -2  -3 -11
N  -2  -3   6   3  -7  -1   0  -1   1  -3  -5   0  -5  -6  -3   1   0  -6  -3  -5   5  -1  -2 -11
D  -1  -6   3   6  -9   0   3  -1  -1  -5  -8  -2  -7 -10  -4  -1  -2 -10  -7  -5   5   2  -3 -11
C  -4  -5  -7  -9   9  -9  -9  -6  -5  -4 -10  -9  -9  -8  -5  -1  -5 -11  -2  -4  -8  -9  -6 -11
Q  -2   0  -1   0  -9   7   2  -4   2  -5  -3  -1  -2  -9  -1  -3  -3  -8  -8  -4  -1   5  -2 -11
E  -1  -5   0   3  -9   2   6  -2  -2  -4  -6  -2  -4  -9  -3  -2  -3 -11  -6  -4   2   5  -3 -11
G   0  -6  -1  -1  -6  -4  -2   6  -6  -6  -7  -5  -6  -7  -3   0  -3 -10  -9  -3  -1  -3  -3 -11
H  -4   0   1  -1  -5   2  -2  -6   8  -6  -4  -3  -6  -4  -2  -3  -4  -5  -1  -4   0   1  -3 -11
I  -2  -3  -3  -5  -4  -5  -4  -6  -6   7   1  -4   1   0  -5  -4  -1  -9  -4   3  -4  -4  -3 -11
L  -4  -6  -5  -8 -10  -3  -6  -7  -4   1   6  -5   2  -1  -5  -6  -4  -4  -4   0  -6  -4  -4 -11
K  -4   2   0  -2  -9  -1  -2  -5  -3  -4  -5   6   0  -9  -4  -2  -1  -7  -7  -6  -1  -2  -3 -11
M  -3  -2  -5  -7  -9  -2  -4  -6  -6   1   2   0  10  -2  -5  -3  -2  -8  -7   0  -6  -3  -3 -11
F  -6  -7  -6 -10  -8  -9  -9  -7  -4   0  -1  -9  -2   8  -7  -4  -6  -2   4  -5  -7  -9  -5 -11
P   0  -2  -3  -4  -5  -1  -3  -3  -2  -5  -5  -4  -5  -7   7   0  -2  -9  -9  -3  -4  -2  -3 -11
S   1  -1   1  -1  -1  -3  -2   0  -3  -4  -6  -2  -3  -4   0   5   2  -3  -5  -3   0  -2  -1 -11
T   1  -4   0  -2  -5  -3  -3  -3  -4  -1  -4  -1  -2  -6  -2   2   6  -8  -4  -1  -1  -3  -2 -11
W  -9   0  -6 -10 -11  -8 -11 -10  -5  -9  -4  -7  -8  -2  -9  -3  -8  13  -3 -10  -7 -10  -7 -11
Y  -5  -7  -3  -7  -2  -8  -6  -9  -1  -4  -4  -7  -7   4  -9  -5  -4  -3   9  -5  -4  -7  -5 -11
V  -1  -5  -5  -5  -4  -4  -4  -3  -4   3   0  -6   0  -5  -3  -3  -1 -10  -5   6  -5  -4  -2 -11
B  -1  -4   5   5  -8  -1   2  -1   0  -4  -6  -1  -6  -7  -4   0  -1  -7  -4  -5   5   1  -2 -11
Z  -1  -2  -1   2  -9   5   5  -3   1  -4  -4  -2  -3  -9  -2  -2  -3 -10  -7  -4   1   5  -3 -11
X  -2  -3  -2  -3  -6  -2  -3  -3  -3  -3  -4  -3  -3  -5  -3  -1  -2  -7  -5  -2  -2  -3  -3 -11
* -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11   1
),
};
  return($m);
}

1;
