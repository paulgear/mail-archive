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
use File::Compare;
use File::Spec;
use Scalar::Util qw/tainted/;

use MailArchive::Config;
use MailArchive::Db;
use MailArchive::Email;
use MailArchive::Log;
use MailArchive::Util;

require "site.pl";

# find out whether file matches another file in the database
sub dedup_file ($$)
{
	my ($fullpath, $cksum) = @_;
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
			remove_file($check_file);
			next;
		}

		# next if the files are not identical
		next unless compare($check_file, $fullpath) == 0;

		# move the file aside
		unless (rename($fullpath, "$fullpath.tmp")) {
			# Hasn't worked, we'll just put up with no dedup
			warn "Cannot move aside $fullpath ($!)";
		}
		# hard link it to the matching file
		elsif (link($check_file, $fullpath)) {
			debug "Linked $fullpath to $check_file";
			warn "Cannot delete $fullpath.tmp ($!) - please delete manually"
				unless unlink("$fullpath.tmp") == 1;
		}
		else {
			# Hasn't worked, we'll just put up with no dedup
			warn "Cannot link $fullpath to $check_file ($!)";
			warn "Cannot move $fullpath.tmp to $fullpath ($!) - please rename manually"
				unless rename("$fullpath.tmp", $fullpath);
		}

		# we're done - no need to check against any more files
		last;
	}
	add_file($fullpath, $cksum);
}

# save the file and dedup
sub save_dedup_file ($$$$)
{
	my ($dir, $origfile, $content, $cksum) = @_;

	# replace slashes in file name
	my $file = $origfile;
	$file =~ s/\/+/ /g;
	if ($file ne $origfile) {
		debug "Using $file for filename instead of $origfile";
	}

	my $fullpath = File::Spec->catfile($dir, $file);
	if (-e $fullpath) {
		warn "File $fullpath already exists - skipping";
		return;
	}
	save_file($fullpath, $content);
	dedup_file($fullpath, $cksum);
}

# main email processor
sub process_email ($$$$$);
sub process_email ($$$$$)
{
	my ($basedir, $projnum, $body, $level, $subject_override) = @_;

	limit_recursion($level);

	# open parsed version of the email
	my $msg = Email::MIME->new($body);

	# dump message structure
	my $structure = $msg->debug_structure;
	chomp($structure);
	debug($structure);

	# get the message headers
	my $header = $msg->header(getconfig('status-header'));
	my $subject = $msg->header("Subject");
	my $origsubject = $subject;
	my $from = $msg->header("From");
	my $to = $msg->header("To");
	my $cc = $msg->header("Cc");

	# get message id, prune punctuation
	my $messageid = $msg->header("Message-Id");
	$messageid =~ s/^\s*<\s*//;
	$messageid =~ s/\s*>\s*$//;

	# Show subject
	debug "subject = $subject";

	# work out whether the message is incoming or outgoing
	my @fromaddr = Email::Address->parse($from);
	dump_email_addresses("fromaddr", @fromaddr);
	my $outgoing = is_local(@fromaddr);
	debug "outgoing = $outgoing";

	# get To: recpients
	my @toaddr = Email::Address->parse($to);
	dump_email_addresses("toaddr", @toaddr);

	# get Cc: recipients
	my @ccaddr = Email::Address->parse($cc);
	dump_email_addresses("ccaddr", @ccaddr);

	# recipients are the combination of To & Cc
	push @toaddr, @ccaddr;

	# validate project number
	$projnum = check_project_num($projnum, $subject_override, $subject);
	unless (defined $projnum) {
		if ($outgoing) {
			send_error($msg, "Project number not found in message", \@toaddr);
		}
		else {
			# Drop the message so that recipients aren't spammed for messages
			# outside their control.  Incoming messages may be flagged separately
			# via a procmail or mailfilter rule.
			debug "Dropping incoming message with no project number";
			exit 0;
		}
	}

	# remove noise from subject
	$subject = clean_subject($subject, $projnum);
	$origsubject = clean_subject($origsubject, $projnum);

	# put in a subject override if necessary
	if (getconfig('subject-override') && defined $subject_override) {
		unless ($subject_override =~ /^\s*$/) {
			$subject = $subject_override;
			debug "subject overridden with $subject";
		}
	}

	# search for project directory
	my $projdir = get_project_dir($basedir, $projnum);
	send_error($msg, "Project directory for $projnum not found", \@toaddr)
		unless (defined $projdir);
	error("Project directory $projdir tainted")
		if tainted($projdir);
	debug "Project directory is $projdir";

	# get the incoming/outgoing correspondence directory
	my $emaildir = get_project_email_dir($projdir, $outgoing);
	debug "emaildir = $emaildir";

	# parse the message, gather attachment names, determine maximum length
	my @parts = collect_parts($msg);
	debug "Found " . @parts . " usable parts in message";
	my $max = collect_names(@parts);
	debug "Maximum attachment name length is " . $max;

	# save the overall message checksum; we do this here to ensure it's available later no
	# matter what happens to the parts array
	my $checksum = $parts[0]->{'checksum'};
	debug "Message checksum $checksum";

	# check for duplicate message id
	debug "Checking for existing message id";
	my $row = check_message($messageid, $checksum, $projnum);
	if (defined $row) {
		if ($row->[1] eq $checksum) {
			debug "Dropping previously-seen message: $row->[0] $row->[2] $row->[3]";
			exit 0;
		}
		else {
			warning "Checksum mismatch on previously-seen message: $row->[0] $row->[2] $row->[3]";
			debug "... checksum was $row->[1] should be $checksum";
			debug "... This should never happen.  Continuing to process email.";
		}
	}

	# Check the length of the path - if it's too long, we can't shorten it so there's
	# nothing we can do but exit.  Leave enough room for the longest attachment name, 
	# two path separators, and a minimal email directory name (yymmdd nn).
	my $len = path_too_long($emaildir, $max + 11);
	if ($len) {
		error "Path to email directory ($emaildir) too long";
	}

	# use the other party as an identifier
	my @otherparty = $outgoing ? @toaddr : @fromaddr;
	dump_email_addresses "otherparty", @otherparty;

	# exclude archiver itself from outgoing
	@otherparty = grep { $_->address ne getconfig('archiver-email') } @otherparty;

	# Convert @otherparty from Email::Address to string.
	# Use real name if it's present, otherwise use the user part of the email address
	@otherparty = map { (defined $_->phrase && $_->phrase ne "") ? $_->phrase : $_->user } @otherparty;
	debug "otherparty (shortened): @otherparty";

	# remove quotes from names
	@otherparty = map { dequote($_) } @otherparty;
	debug "otherparty (no quotes): @otherparty";

	my $otherparty = join ",", @otherparty;
	debug "otherparty = $otherparty";

	# try to get the exact date of when we received the email
	my @received = $msg->header("Received");
	my $received = get_local_received_date(@received);

	# use the date, subject, and otherparty to create a unique directory name within the
	# correspondence directory
	my $datestring = defined $received ? datestring($received) : datestring();
	my $uniquefile = "$datestring ($otherparty) $subject";
	my $uniquebase = File::Spec->catfile($emaildir, $uniquefile);
	debug "uniquebase = ($uniquebase)";
	my $uniquedir = create_seq_directory($uniquebase, $max + 2);
	debug "uniquedir = ($uniquedir)";

	# remove duplicate parts
	my $count = $#parts;
	@parts = condense_parts(@parts);
	debug "dropped " . ($count - $#parts) . " duplicate parts";

	# remove whitespace parts
	$count = $#parts;
	@parts = grep { ! is_whitespace($_->{'part'}->body) } @parts;
	debug "dropped " . ($count - $#parts) . " whitespace parts";

	debug "smart-drop is " . getconfig('smart-drop');
	if (getconfig('smart-drop') && $outgoing && $toaddr[0]->address eq getconfig('archiver-email') && getconfig('split')) {
		debug "Processing only attached emails";

		# do not save the whole email or the attachments - only process attached emails
		@parts = grep { $_->{'part'}->content_type =~ /^message\// } @parts;
		debug "Found " . ($#parts + 1) . " message parts";
		@parts = grep { $_->{'level'} == 0 } @parts;
		debug "Found " . ($#parts + 1) . " parts at level 0";
		for my $p (@parts) {
			process_email($basedir, $projnum, $p->{'part'}->body_raw, $level + 1, $subject);
		}

		# clean up unneeded directory
		debug "Removing directory $uniquedir";
		debug "$uniquedir not removed: $!" unless rmdir $uniquedir;
		remove_message($messageid, $checksum, $projnum);
	}
	else {
		# save the parts (if split turned on)
		if (getconfig('split')) {
			@parts = grep { defined $_->{'name'} } @parts;
			for my $p (@parts) {
				debug "Saving part " . $p->{'name'};
				save_dedup_file($uniquedir, $p->{'name'}, $p->{'part'}->body, $p->{'checksum'});
			}
		}
		# save the whole file
		my $tmpsubj = length("$origsubject.eml") > $max ? "email.eml" : "$origsubject.eml";
		debug "Saving whole email ($tmpsubj), checksum " . $checksum;
		save_dedup_file($uniquedir, $tmpsubj, $body, $checksum);
	}

}

1;	# file must return true - do not remove this line
