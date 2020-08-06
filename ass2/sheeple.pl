#!/usr/bin/perl -w

# main function
sub main {
	# map to store our resulting file
	my @result = ();

	open (F, "<", "$ARGV[0]") or die $!;


	# main loop that reads the file and processes each line
	while (my $line = <F>) {
		chomp($line);
		$line = parseLine($line);

		# if the line can be skipped
		# shell if and while statements use 2 lines while in perl only 1 line is used
		if (skipLine($line)) {
			next;
		}

		# closes brackets
		# fi, done
		if (isClosingBracket($line)) {
			push (@result, formatLine($line, "}", 1));
			next;
		}

		if (isHeader($line)) {
			push (@result, "#!/usr/bin/perl -w\n");
			next;
		}

		# copy comments over
		if (isComment($line)) { 
			push (@result, "$line\n");
			next;
		} 

		# variable assignment
		if (my ($lhs, $rhs) = isAssign($line)) {
			if ($lhs and $rhs) {
				# handle $ assignments
				if ($rhs =~ /^\$/) {
					push(@result, formatLine($line,"\$$lhs = $rhs"));
				} else {
					push(@result, formatLine($line, "\$$lhs = \'$rhs\'"));
				}

				next;
			}
		}

		# buildin functions
		# exit read cd test expr echo
		if (my $output = isBuiltinFunction($line)) {
			push (@result, $output);
			next;
		}

		if (my ($iterator, $list) = isForLoop($line)) {
			if ($iterator and $list) {
				# construct the list
				$list = convertList($list);

				push (@result, formatLine($line, "foreach \$${iterator} \($list\) {", 1));
				next;
			}
		}

		if (my $condition = isWhileLoop($line)) {
			push(@result, formatLine($line, "while ($condition) {", 1));
			next;
		}


		if (my ($statement, $condition) = isIfStatement($line)) {
			if ($statement){
				if ($statement eq "else") {
					push (@result, formatLine($line, "} else {",1));
					next;
				}

				if ($condition) {
					$bracket = "} ";
					if ($statement eq "if") {
						$bracket = "";
					} else {
						$statement = "elsif";
					}

					push (@result, formatLine($line, "$bracket$statement $condition {", 1));
					next;
				}
			}
		}



		# if we reach here then the line should is untranslateable
		# use system() function isntead
		my $output = translateSystemCall($line);
		push(@result, $output);
	}

	close(F);

	open (OUT, ">", "out.pl") or die $!;
	foreach(@result) {
		print OUT "$_";
	}
	close(OUT);

	exit 0;
}

# converts all appropriate variables etc first
# $1 .. $9 -> $ARGV[0] .. $ARGV[9]
# $#, $@, $*
# test, `` and [condition]
sub parseLine {
	my $line = $_[0];

	# replace $#, $@ and $*
	$line =~ s/(\$\@)|(\"\$\@\")/\@ARGV/g;
	$line =~ s/(\$#)|(\"\$#\")/\$#ARGV/g;


	# $1..9
	while (1) {
		$line =~ /[^\\]\$([0-9])/;
		
		# no more replacements
		if (!$1) {
			last;
		} 

		$idx = $1 - 1;
		$regex = quotemeta $1;

		$line =~ s/\$$regex/\$ARGV[$idx]/;
	}


	# replace TEST keyword
	while (1) {
		$line =~ /.*test (.+)\s*$/;

		if (!$1) {
			last;
		}

		# replace the test section
		$condition = convertTestCondition($1);
		$regex = quotemeta $1;

		$line =~ s/test $regex/\($condition\)/;
	}


	# replace backticks ``
	# will just assume backticks are always used with expr
	while (1) {
		$line =~ /.*`expr (.+)`\s*$/;

		if (!$1) {
			last;
		}

		# replace the backticked section
		$expr = $1;
		$regex = quotemeta $1;

		$line =~ s/`expr $regex`/$expr/;
	}

	# replace [] conditions
	while (1) {
		$line =~ /^.*\[ (.+) \].*$/;

		if (!$1) {
			last;
		}

		# replace brackets with if condition
		$condition = convertTestCondition($1);
		$regex = quotemeta "$1";

		$line =~ s/\[ $regex \]/\($condition\)/;
	}

	return $line;
}



# checks if it is a header file
sub isHeader {
	return $_[0] =~ /^\s*#!\/bin\/(da){0,1}sh/;
}

# checks if a given line is a comment or purely whitespace
sub isComment {
	if ($_[0] eq "") {
		return 1;
	}

	return $_[0] =~ /^\s*#+/;
}

sub isWhileLoop {
	$_[0] =~ /^\s*while \((.+)\)/;
	return $1;
}

# checks if a line is an if statement
sub isIfStatement {
	if ($_[0] =~ /^\s*else/) {
		return "else", "";
	}

	$_[0] =~ /(^\s*(if)|(elif)) (\(.+\))/;
	return $1, $4;
}

# checks if a given line is assigning a variable
# returns left hand side and righthand side of the match
sub isAssign {
	$_[0] =~ /^\s*([_a-zA-Z]{1}[a-zA-Z_0-9]*)=(.+)\s*/;
	return $1, $2;
}

# checks if a line is a FOR loop
# format is "for <iterator> in <list>"
# returns <iterator> and <list>
sub isForLoop {
	$_[0] =~ /^\s*for (.+) in (.+)\s*$/;
	return $1, $2;
}

# checks if a line is a shell function that requires translation to perl
# exit read cd test expr echo
# returns the translated line
sub isBuiltinFunction {
	$line = $_[0];

	# exit
	if (isExit($line)) {
		return "$line;\n";
	}

	# read
	if (my $var = isRead($line)) {
		$line1 = formatLine($line, "$indent\$$var = <STDIN>");
		$line2 = formatLine($line, "chomp \$$var");

		return "$line1\n$line2"; 
	}

	# cd
	if (my $dir = isChangeDir($line)) {
		return formatLine($line, "chdir '$dir'");
	}

	# test 


	# expr

	# echo
	if (my $arguments = isPrint($line)) {
		$arguments = createPrintString($arguments);
		return formatLine($line, "print \"$arguments\"");
	}	
}

# constructs a string to print
# adds the appropriate escape to quotes
sub createPrintString {
	$string = $_[0];
	$newline = 1;

	# check for -n flag
	if ($string =~ s/^-n //) {
		$newline = 0;
	}

	# first remove the leading and trailing quotes if they exist
	$string =~ s/^((\')|(\"))|((\')|(\"))$//g;

	# the rest must be escaped
	$string =~ s/\"/\\\"/g;

	if ($newline) {
		$string = "$string\\n";
	}

	return "$string";
}

# skip the line
# ignores "do" and "then"
sub skipLine {
	# negative lookahead for "do" so we do not match "done"
	return $_[0] =~ /^\s*(do(?!ne))|(then)\s*$/;
}

# closes bracket on "done" and "fi"
sub isClosingBracket {
	return $_[0] =~ /^\s*(done)|(fi)\s*$/;
}

# checks if we are exiting
sub isExit {
	return $_[0] =~ /^\s*exit/;
}

# checks if we are changing directories
# returs the directory we are changing to
sub isChangeDir {
	$_[0] =~ /^\s*cd (.+)\s*$/;
	return $1;
}

# checks if a line is calling echo
# returns what is getting printed
sub isPrint {
	$_[0] =~ /^\s*echo (.*)\s*$/;
	return $1;
}


# checks if a line is calling read
# returns the variable we read into
sub isRead {
	$_[0] =~ /^\s*read (.+)\s*$/;
	return $1;
}

# returns required indentation for a line
sub getIndentation {
	$_[0] =~ /(^\s*)/;
	return $1;
}

# returns any comments at the end of a line
sub getComments {
	$_[0] =~ /^\s*(#.*$)/;
	return $1;
}

# returns the translated system('...') line
sub translateSystemCall {
	$indent = getIndentation($_[0]);
	$_[0] =~ /^\s*(.+)\s*$/;
	return "${indent}system \"$1\";\n";
}

# pad the converted line with indentation and trailing comments
sub formatLine {
	$indent = getIndentation($_[0]);
	$comments = getIndentation($_[0]);

	$semicolon = ";";
	if ($_[2]) {
		$semicolon = "";
	}

	return "${indent}${_[1]}${semicolon} $comments\n";
}

# create the appropriate list to iterate over
sub convertList {
	$list = $_[0];

	# remove trailing spaces
	$list =~ s/\s*$//g;

	# directory
	if ($list =~ /^\*/) {
		return "glob(\"$list\")";
	}

	# list of items.

	# replace spaces with "', '"
	$list =~ s/\s/\', \'/g;

	return "\'$list\'";	
}

# converts shell test keyword to perl logic
sub convertTestCondition {
	$test = $_[0];

	# x = y format
	if ($test =~ /(.+) (=|!=|<=>|<|>|<=|>=) (.+)\s*$/) {
		# check what the comparison is
		$operation = $2;
		$comparator = "";

		if ($operation eq "=") {
			$comparator = "eq";
		} elsif ($operation eq "!=") {
			$comparator = "ne" 
		} elsif ($operation eq "<=>") {
			$comparator = "cmp" 
		} elsif ($operation eq "<") {
			$comparator = "lt" 
		} elsif ($operation eq ">") {
			$comparator = "gt" 
		} elsif ($operation eq "<=") {
			$comparator = "le" 
		} elsif ($operation eq ">=") {
			$comparator = "ge" 
		} 

		return "\'$1\' $comparator \'$3\'";
	}


	# x <operator> y format. operation (eq|ne|lt|gt|le|ge|)
	if ($test =~ /(.+) -(eq|ne|cmp|lt|gt|le|ge) (.+)\s*$/) {
		$comparator = $2;
		$operator = "";

		if ($comparator eq "eq") {
			$operator = "=";
		} elsif ($comparator eq "ne") {
			$operator = "!=";
		} elsif ($comparator eq "cmp") {
			$operator = "<=>";
		} elsif ($comparator eq "lt") {
			$operator = "<";
		} elsif ($comparator eq "gt") {
			$operator = ">";
		} elsif ($comparator eq "le") {
			$operator = "<=";
		} elsif ($comparator eq "ge") {
			$operator = ">=";
		}

		return "$1 $operator $3";
	}

	# -r flag
	if ($test =~ /^-r (.+)\s*$/) {
		return "-r \'$1\'";
	}

	# -d flag
	if ($test =~ /^-d (.+)\s*$/) {
		return "-d \'$1\'";
	}

	return;
	# we shouldn't actually get here
}

main()