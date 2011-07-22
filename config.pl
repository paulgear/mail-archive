#!/usr/bin/perl -w
# perl fragment to hold configuration for mail-archive

# Regular expression to match subjects which should cause the email to be
# dropped instead of archived.
$config{'drop_subject_regex'}	= '\b[(\[]PERSONAL[)\]]\b';

# Mail from one of these domains is considered outgoing
$config{'localdomains'}		= ( 'localhost' );

# Magic header which will cause mail to be dropped
$config{'magic_header'}		= "X-MailArchive-Status";

# Regular expression to match project numbers - must contain () to provide $1
$config{'projnum-regex'}	= '\b(FN\d{6})\b';

# Regular expression to split project number into parts
$config{'projnum-split-regex'}	= '^FN(\d\d)(\d\d)(\d\d)$';

# Directories in which to search for folders matching project number -
# relative to the base directory specified on the mail-archive command line.
$config{'searchpath'}		= ( '/', '/files' );

1;	# file must return true - do not remove this line

