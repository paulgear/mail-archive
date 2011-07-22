#!/usr/bin/perl -w
#
# Message archiving routines for mail archiver
#
# Copyright (c) 2011 Lowenstein & Stumpo <http://www.lowstump.com.au/>
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Author:	Paul Gear <github@libertysys.com.au>
#

package MailArchive::Archive;

# module setup
use strict;
use warnings;
use Exporter;
use vars qw($VERSION @ISA @EXPORT); # @EXPORT_OK); %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(

	process_email

);
#@EXPORT_OK   = qw( init );

# code dependencies
use Digest;
use Email::Reply;
use Email::Sender::Simple qw(sendmail);
use File::Compare;
use File::Spec;
use MailArchive::Db;
use MailArchive::Email;
use MailArchive::Util;

my $digest;

sub init ()
{
	$digest = Digest->new("SHA-256");
}

# checksum file, find out whether it matches another file in the database
sub dedup_file ($$)
{
	init() unless $digest;

	my ($fullpath, $data) = @_;
	$digest->add($data);
	my $cksum = $digest->hexdigest;
	debug "checksum $cksum";

	for my $check_file (check_file($fullpath, $cksum)) {
		# If we have this exact file & checksum already in the db, do nothing.
		# This really shouldn't happen unless we've been deleting files without
		# cleaning up the database.
		return if $check_file eq $fullpath;

		# we didn't find a matching file
		next unless defined $check_file;

		# the file in the database doesn't exist
		next unless -e $check_file;

		# the files are not identical
		next unless compare($check_file, $fullpath) == 0;

		# move the file aside
		#debug "rename $fullpath -> $fullpath.tmp";
		rename($fullpath, "$fullpath.tmp")
			or error "Cannot move aside $fullpath";

		# hard link it to the matching file
		#debug "link $fullpath -> $check_file";
		if (link($check_file, $fullpath)) {
			#debug "unlink $fullpath.tmp";
			unlink("$fullpath.tmp")
				or warn "Cannot delete $fullpath.tmp ($!) - please delete manually";
			# we're done - don't check against any more files
			last;
		}
		else {
			warn "Cannot link $fullpath to $check_file ($!)";
			#debug "rename $fullpath.tmp -> $fullpath";
			rename("$fullpath.tmp", $fullpath)
				or warn "Cannot move back $fullpath ($!) - please rename manually";
		}
	}
	add_file($fullpath, $cksum);
}

# save the body of the given file part to disk
sub save_part ($$$)
{
	my ($dir, $filename, $body) = @_;
	if (is_whitespace($body)) {
		# don't save empty parts
		debug "Message part $filename empty - dropping";
		return;
	}
	my $fullpath = File::Spec->catfile($dir, $filename);
	error "File $fullpath already exists" if -e $fullpath;
	save_file($fullpath, "message part file", $body);
	dedup_file($fullpath, $body);
}

# exit with error if we've passed the maximum recursion limit
sub limit_recursion ($)
{
	my $level = shift;
	# FIXME: configurable limit
	if ($level > 99) {
		error "Reached maximum recursion level in message";
	}
}

# prototypes for recursive functions
sub process_email ($$$$);
sub process_part ($$$$$$$);

sub process_part ($$$$$$$)
{
	my ($basedir, $projnum, $dir, $part, $level, $prefix, $partnum) = @_;

	limit_recursion($level);

	my $type = $part->content_type;
	my $filename = (defined $part->filename) ? $part->filename : $part->invent_filename($type);

	debug "part $prefix$partnum: type $type, name: $filename";
	if (scalar $part->subparts > 0) {
		# process any subparts
		my $subpartnum = 1;
		for my $subpart ($part->subparts) {
			process_part($basedir, $projnum, $dir, $subpart, $level + 1,
				"$prefix$partnum.", $subpartnum);
		}
	}
	# TODO: work out whether there can be a body on a part with multiple subparts
	elsif ($type =~ /^message\//) {
		debug "processing attched message, type = $type";
		process_email($basedir, $projnum, $part->body_raw, $level + 1);
	}
	else {
		save_part($dir, $filename, $part->body);
	}
}

# save every part of the given message
sub save_message ($$$$$)
{
	my ($basedir, $projnum, $dir, $msg, $level) = @_;

	# TODO: Add processing of stats here

	# save the message headers to disk
	save_part($dir, "headers$level.txt", concatenate_headers($msg->header_pairs()));

	my $numparts = $msg->parts;
	debug $msg->debug_structure;

	# iterate through each message part
	my $partnum = 1;
	for my $part ($msg->parts) {
		process_part($basedir, $projnum, $dir, $part, $level, "", $partnum++);
	}
}

# send a reply to the given email
sub send_error ($$$)
{
	my $msg = shift;		# the email message to bounce
	my $diag = shift;		# message to send as a diagnostic
	my $outgoing = shift;		# whether the message is outgoing

	my $reply = reply
		to		=> $msg,
		from		=> getconfig('archiver-email'),
		attach		=> 1,
		body		=> <<__REPLY__;
Error archiving attached email:
$diag
__REPLY__
	$reply->header_set( To => getconfig('admin-email') ) if $outgoing;
	sendmail($reply);
	exit 0;
}

# main email processor
sub process_email ($$$$)
{
	my $basedir = shift;
	my $projnum = shift;
	my $email = shift;
	my $level = shift;

	limit_recursion($level);

	# open parsed version of the email
	my $msg = Email::MIME->new($email);

	# get the message headers
	my $magic = $msg->header(getconfig('magic-header'));
	my $subject = $msg->header("Subject");
	my $from = $msg->header("From");
	my $to = $msg->header("To");

	# check if we've already processed this message
	if (defined $magic) {
		debug "Dropping message, already processed: $magic";
		exit 0;
	}

	# check for any messages to drop
	my $check_drop = get_drop_flags($subject, $from, $to);
	if (defined $check_drop) {
		debug "Dropping email: $check_drop";
		exit 0;
	}

	# work out whether the message is incoming or outgoing
	my @fromaddr = Email::Address->parse($from);
	dump_email_address "fromaddr", $fromaddr[0];
	my $outgoing = is_outgoing(@fromaddr);

	# get primary recpient
	my @toaddr = Email::Address->parse($to);
	dump_email_addresses "toaddr", @toaddr;

	# Show subject
	debug "subject = $subject";

	# validate project number
	$projnum = check_project_num(defined $projnum ?  $projnum : $subject);
	unless (defined $projnum) {
		send_error($msg,
			"Project number not defined, and cannot find it in message subject",
			$outgoing);
	}

	# remove noise from subject
	$subject = clean_subject($subject, $projnum);

	# search for project directory
	my $projdir = get_project_dir($basedir, $projnum);
	error "Project directory for $projnum not found" unless defined $projdir;
	error "Project directory $projdir tainted" if tainted($projdir);
	debug "Project directory is $projdir";

	# get the incoming/outgoing correspondence directory
	my $emaildir = get_project_email_dir($projdir, $outgoing);
	debug "emaildir = $emaildir";

	# use the other party as an identifier
	my $otherparty;
	if ($outgoing) {
		$otherparty = join(" ", map {$_->name, $_->address} @toaddr);
	}
	else {
		$otherparty = $fromaddr[0]->name . " " . $fromaddr[0]->address;
	}
	debug "otherparty = $otherparty";

	# use the date, subject, and otherparty to create a unique directory name within the correspondence directory
	my $yyyymmdd = yyyymmdd();
	my $uniquebase = "$emaildir/$yyyymmdd $otherparty $subject";
	debug "uniquebase = ($uniquebase)";

	if (getconfig('split')) {
		# split into parts and process the message
		my $dir = create_seq_directory($uniquebase);
		save_message($basedir, $projnum, $dir, $msg, 1);
	}
	else {
		# save the whole file
		save_file(get_unique_filename($uniquebase), "email archive file", $email);
	}
}

1;	# file must return true - do not remove this line

