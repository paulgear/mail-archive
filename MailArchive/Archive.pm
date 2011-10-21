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
#@EXPORT_OK   = qw(mysub1);
#%EXPORT_TAGS = ( DEFAULT => [qw(&mysub2)] );

# code dependencies
use Digest;
use File::Compare;
use File::Spec;
use Scalar::Util qw/tainted/;

use MailArchive::Config;
use MailArchive::Db;
use MailArchive::Email;
use MailArchive::Log;
use MailArchive::Util;

require "site.pl";

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

		# next if we didn't find a matching file
		next unless defined $check_file;

		# if the file in the database doesn't exist, remove the db entry
		unless (-e $check_file) {
			debug "Non-existent file $check_file in database - cleaning up";
			remove_file $check_file;
			next;
		}

		# next if the files are not identical
		next unless compare($check_file, $fullpath) == 0;

		# move the file aside
		unless (rename($fullpath, "$fullpath.tmp")) {
			warn "Cannot move aside $fullpath";
			# we're done - we'll just put up with no dedup
			last;
		}

		# hard link it to the matching file
		if (link($check_file, $fullpath)) {
			debug "Linked $fullpath to $check_file";
			warn "Cannot delete $fullpath.tmp ($!) - please delete manually"
				unless unlink("$fullpath.tmp") == 1;
			# we're done - no need to check against any more files
			last;
		}
		else {
			warn "Cannot link $fullpath to $check_file ($!)";
			rename("$fullpath.tmp", $fullpath)
				or warn "Cannot move back $fullpath ($!) - please rename manually";
		}
	}
	add_file($fullpath, $cksum);
}

# save the file and dedup
sub save_dedup_file ($$$)
{
	my ($file, $msg, $content) = @_;
	# FIXME: check path length here and push the error back up the stack
	save_file($file, $msg, $content);
	dedup_file($file, $content);
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
	save_dedup_file($fullpath, "message part file", $body);
}

# exit with error if we've passed the maximum recursion limit
sub limit_recursion ($)
{
	my $level = shift;
	my $max = getconfig('recursion-level');
	if ($level > $max) {
		error "Reached maximum recursion level ($max) in message";
	}
}

# prototypes for recursive functions
sub process_email ($$$$$);
sub process_part ($$$$$$$$$);

sub process_part ($$$$$$$$$)
{
	my ($basedir, $projnum, $dir, $part, $level, $prefix, $partnum, $subject, $smart_drop) = @_;

	limit_recursion($level);

	my $type = $part->content_type;
	$type = "text/plain" unless defined $type;
	my $filename = (defined $part->filename) ? $part->filename : $part->invent_filename($type);

	debug "part $prefix$partnum: type $type, name: $filename";
	if (scalar $part->subparts > 0) {
		# process any subparts
		my $subpartnum = 1;
		for my $subpart ($part->subparts) {
			process_part($basedir, $projnum, $dir, $subpart, $level + 1,
				"$prefix$partnum.", $subpartnum, $subject, $smart_drop);
		}
	}
	# TODO: work out whether there can be a body on a part with multiple subparts
	elsif ($type =~ /^message\//) {
		debug "processing attched message, type = $type";
		process_email($basedir, $projnum, $part->body_raw, $level + 1, $subject);
	}
	else {
		# save part if it's an attachment
		if (defined $part->filename or defined $part->header('Content-Disposition')) {
			if ($smart_drop) {
				debug "Ignoring attachment due to smart-drop";
			}
			else {
				save_part($dir, $filename, $part->body);
			}
		}
		else {
			debug "part $prefix$partnum is not an attachment - skipping";
		}
	}
}

# save every part of the given message
sub save_message ($$$$$$$)
{
	my ($basedir, $projnum, $dir, $msg, $level, $subject, $smart_drop) = @_;

	debug "smart_drop mode invoked" if $smart_drop;

	# TODO: Add processing of stats here

	# save the message headers to disk
	#save_part($dir, "headers$level.txt", concatenate_headers($msg->header_pairs()));

	#my $numparts = $msg->parts;
	my $structure = $msg->debug_structure;
	chomp($structure);
	debug($structure);

	# iterate through each message part
	my $partnum = 1;
	for my $part ($msg->parts) {
		process_part($basedir, $projnum, $dir, $part, $level, "", $partnum++, $subject, $smart_drop);
	}
}

# main email processor
sub process_email ($$$$$)
{
	my ($basedir, $projnum, $email, $level, $subject_override) = @_;

	limit_recursion($level);

	# open parsed version of the email
	my $msg = Email::MIME->new($email);

	# get the message headers
	my $header = $msg->header(getconfig('status-header'));
	my $subject = $msg->header("Subject");
	my $from = $msg->header("From");
	my $to = $msg->header("To");

	# Show subject
	debug "subject = $subject";

	# put in a subject override if necessary
	my $origsubject = $subject;
	if (getconfig('subject-override') && defined $subject_override) {
		unless ($subject_override =~ /^\s*$/) {
			$subject = $subject_override;
			debug "subject overridden with $subject";
		}
	}

	# work out whether the message is incoming or outgoing
	my @fromaddr = Email::Address->parse($from);
	dump_email_addresses "fromaddr", @fromaddr;
	my $outgoing = is_local(@fromaddr);
	debug "outgoing = $outgoing";

	# get primary recpient
	my @toaddr = Email::Address->parse($to);
	dump_email_addresses "toaddr", @toaddr;

	# validate project number
	$projnum = check_project_num(defined $projnum ? $projnum : $subject);
	send_error($msg, "Project number not found in message", $outgoing)
		unless (defined $projnum);

	# remove noise from subject
	$subject = clean_subject($subject, $projnum);
	$origsubject = clean_subject($origsubject, $projnum);

	# search for project directory
	my $projdir = get_project_dir($basedir, $projnum);
	send_error($msg, "Project directory for $projnum not found", $outgoing)
		unless (defined $projdir);
	error("Project directory $projdir tainted")
		if tainted($projdir);
	debug "Project directory is $projdir";

	# get the incoming/outgoing correspondence directory
	my $emaildir = get_project_email_dir($projdir, $outgoing);
	debug "emaildir = $emaildir";

	# check the length of the path
	my $len = path_too_long($emaildir);
	if ($len) {
		error "Path to email directory ($emaildir) too long";
	}

	# use the other party as an identifier
	my @otherparty = $outgoing ? @toaddr : @fromaddr;
	dump_email_addresses "otherparty", @otherparty;
	# Use real name if it's present, otherwise use the user part of the email address
	my $otherparty = join(",", map {defined $_->name ? $_->name : $_->user} @otherparty);
	debug "otherparty = $otherparty";

	# try to get the exact date of when we received the email
	my @received = $msg->header("Received");
	my $received = get_local_received_date(@received);

	# use the date, subject, and otherparty to create a unique directory name within the
	# correspondence directory
	my $datestring = defined $received ? datestring($received) : datestring();
	my $uniquefile = "$datestring ($otherparty) $subject";
	my $uniquebase = "$emaildir/$uniquefile";
	debug "uniquebase = ($uniquebase)";
	my $uniquedir = create_seq_directory($uniquebase);

	# check the length of the path
	$len = path_too_long($uniquedir);
	if ($len) {
		error "Path to directory ($uniquedir) too long";
	}

	if (getconfig('smart-drop') && $outgoing && $toaddr[0]->address eq getconfig('archiver-email') && getconfig('split')) {
		# do not save the whole email or the attachments if it's a smart drop - only process attached emails
		save_message($basedir, $projnum, $uniquedir, $msg, 1, $subject, 1);
		debug "Removing directory $uniquedir";
		debug "$uniquedir not removed: $!" unless rmdir $uniquedir;
	}
	else {
		# save the parts (if split turned on)
		save_message($basedir, $projnum, $uniquedir, $msg, 1, $subject, 0) if getconfig('split');
		# save the whole file
		save_dedup_file("$uniquedir/$origsubject.eml", "email archive file", $email);
	}
}

1;	# file must return true - do not remove this line

