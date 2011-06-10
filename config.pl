#!/usr/bin/perl -w
# perl fragment to hold configuration for mail-archive

# mail from one of these domains is considered outgoing
@localdomains = (
	'localhost',
);

# regular expression to match project numbers - must contain () to provide $1
$projnum_regex = '\b(FN\d{6})\b';

# regular expression to split project number into parts
$projnum_split_regex = '^FN(\d\d)(\d\d)(\d\d)$';

# directories in which to search for folders matching project number -
# relative to the base directory specified on the mail-archive command line.
@searchpath = ( '/', '/files' );

# regular expression to match subjects which should cause the email to be dropped
$drop_subject_regex = '\b[(\[]PERSONAL[)\]]\b';

1;	# file must return true - do not remove this line

