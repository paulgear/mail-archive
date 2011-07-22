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

# Regular expression to match subjects which should cause the email to be
# dropped instead of archived.
$config{'drop-subject-regex'}	= '[[)]?\bPERSONAL\b[\])]?';

# Mail from one of these domains is considered outgoing
$config{'localdomains'}		= [ 'localhost' ];

# Magic header which will cause mail to be dropped
$config{'magic-header'}		= 'X-MailArchive-Status';

# Regular expression to match project numbers - must contain () to provide $1
$config{'projnum-regex'}	= '\b(FN\d{6})\b';

# Regular expression to split project number into parts
$config{'projnum-split-regex'}	= '^FN(\d\d)(\d\d)(\d\d)$';

# Limit on recursion into message parts
$config{'recursion-level'}	= 99;

# Directories in which to search for folders matching project number -
# relative to the base directory specified on the mail-archive command line.
$config{'searchpath'}		= [ '/', '/files' ];

# Flag: whether we should split the email into parts - default true.
# Only useful for debugging.
$config{'split'}		= 1;

1;	# file must return true - do not remove this line

