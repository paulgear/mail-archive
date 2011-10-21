#!/usr/bin/perl -w
# perl fragment to hold configuration for mail-archive

# Email address of mail-archive user
$config{'archiver-email'}	= 'archive@localhost';

# Email address of real human being we can email if there's a problem
$config{'admin-email'}		= 'root@localhost';

# Database connection string, username and password
$config{'dbconnect'}		= 'DBI:mysql:database=mailarchive';
$config{'dbuser'}		= 'mailarchive';
$config{'dbpass'}		= 'mailarchive';

# Mail from one of these domains is considered outgoing
$config{'localdomains'}		= [ 'localhost' ];

# Subject of emails from mail-archive
$config{'error-subject'}	= 'Mail Archive Error';

# Header used to identify status emails from mail-archive
$config{'status-header'}	= 'X-MailArchive-Status';

# Regular expression to match project numbers - must contain () to provide $1
$config{'projnum-regex'}	= '\b(FN\d{6})\b';

# Regular expression to split project number into parts
$config{'projnum-split-regex'}	= '^FN(\d\d)(\d\d)(\d\d)$';

# Limit on recursion into message parts
$config{'recursion-level'}	= 99;

# Directories in which to search for folders matching project number -
# relative to the base directory specified on the mail-archive command line.
$config{'searchpath'}		= [ '/', '/files' ];

# Flag: whether we should skip saving the whole email if it's sent directly to
# the archiver from a local address.  Requires split = 1.
$config{'smart-drop'}		= 0;

# Flag: whether we should split the email into parts - default true.
# Only useful for debugging.
$config{'split'}		= 1;

# Flag: whether we should override the subject of attached emails with the outer email's subject
# - defaults to true
$config{'subject-override'}	= 1;

1;	# file must return true - do not remove this line

